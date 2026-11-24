/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-11-2026 */

package picorom

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDecodeBusState(t *testing.T) {
	// samples seen on the Thunder Hoop PCB: CPU stuck on 0xFFFFF0 (A1-A16 = 0xfff8)
	b, a, e := DecodeBusState("0030fff8,ff,1,0030fff8")
	if e != nil { t.Fatal(e) }
	if b.Address != 0xfff8 || b.Selected() || a.CEn != 1 || a.OEn != 1 { t.Errorf("decoded %+v %+v", b, a) }
	b, _, _ = DecodeBusState("000001f6,4e,0,000001f6")
	if !b.Selected() || b.Address != 0x1f6 { t.Errorf("a selected read decoded as %+v", b) }
	if _, _, e := DecodeBusState("0030fff8,ff"); e == nil { t.Error("short bus_state accepted") }
}

func TestPrepareImage(t *testing.T) {
	half := bytes.Repeat([]byte{0x12}, 0x10000)
	img := append(append([]byte{}, half...), bytes.Repeat([]byte{0xFF}, 0x10000)...)
	got, e := PrepareImage(img, "64k")
	if e != nil || len(got) != 0x20000 { t.Fatalf("64k image with a blank upper half: %v %d", e, len(got)) }
	img[0x10000] = 0
	if _, e := PrepareImage(img, "64k"); e == nil { t.Error("data above 64 KiB accepted in 64k mode") }
	got, e = PrepareImage(half[:100], "128k")
	if e != nil || len(got) != 0x20000 || got[200] != 0xFF { t.Errorf("short image not padded: %v %d", e, len(got)) }
	if _, e := PrepareImage(half, "32k"); e == nil { t.Error("unknown size accepted") }
}

func TestLab(t *testing.T) {
	dir := t.TempDir()
	lab, e := LoadLab(filepath.Join(dir, "none.yaml"))
	if e != nil || len(lab.Units) != 0 { t.Fatalf("a missing lab file must give an empty lab: %v", e) }
	p, _ := NewPower(lab)
	if _, ok := p.(*manual_power); !ok { t.Error("no power section must give manual power") }
	path := filepath.Join(dir, "picorom.yaml")
	os.WriteFile(path, []byte(`units:
  E662505347335333: {name: green, pins: 32, disabled: "pin 2 shorted"}
power: {type: shelly-gen2, url: "http://192.0.2.1", id: plug, interface: wlo1}
`), 0o664)
	lab, e = LoadLab(path)
	if e != nil { t.Fatal(e) }
	u := Unit{UsbDevice: UsbDevice{Name: "green", Serial: "E662505347335333"}}
	lu, _ := lab.Unit(u.Serial)
	u.Lab = &lu
	if e := u.Usable(); e == nil || !strings.Contains(e.Error(), "pin 2") { t.Errorf("disabled unit usable: %v", e) }
	p, e = NewPower(lab)
	if e != nil || !strings.Contains(p.Describe(), "via wlo1") { t.Errorf("shelly power: %v %s", e, p.Describe()) }
	os.WriteFile(path, []byte("unit: {}\n"), 0o664)
	if _, e := LoadLab(path); e == nil { t.Error("unknown lab keys must be rejected") }
}

// Switching off must not depend on the identity check and must retry
func TestShellyOff(t *testing.T) {
	sets, output := 0, true
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/rpc/Shelly.GetDeviceInfo": fmt.Fprint(w, `{"id":"other-device"}`)
		case "/rpc/Switch.GetStatus": fmt.Fprintf(w, `{"output":%v,"apower":0}`, output)
		case "/rpc/Switch.Set":
			sets++
			if sets == 1 { http.Error(w, "busy", 500); return }
			var req struct{ On bool `json:"on"` }
			json.NewDecoder(r.Body).Decode(&req)
			output = req.On
			fmt.Fprint(w, `{"was_on":true}`)
		}
	}))
	defer srv.Close()
	p := new_shelly(LabPower{Url: srv.URL, Id: "plug"})
	st, e := p.Set(false)
	if e != nil || !st.IsOff() || sets != 2 { t.Fatalf("off: %v %+v after %d requests", e, st, sets) }
	if _, e := p.Set(true); e == nil || !strings.Contains(e.Error(), "unexpected device") {
		t.Errorf("switching on an unexpected device must fail: %v", e)
	}
	if output { t.Error("the unexpected device was switched on") }
}
