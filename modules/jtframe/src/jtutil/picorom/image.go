/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-11-2026 */

package picorom

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// Sizes maps a size name to the PicoROM address mask. 64k ignores A16 and up,
// so the unit works even when those address inputs are not usable.
var Sizes = map[string]int{"64k": 0xFFFF, "128k": 0x1FFFF, "256k": 0x3FFFF}

const (
	rom_pause    = 3 * time.Second // jtkcpu contract: ROM disabled at least 3 s
	rom_capacity = 0x40000         // 32-pin units: 2 Mbit
)

func SizeNames() string {
	var n []string
	for k := range Sizes { n = append(n, k) }
	sort.Strings(n)
	return strings.Join(n, ", ")
}

func Sha(data []byte) string {
	s := sha256.Sum256(data)
	return hex.EncodeToString(s[:])
}

// PrepareImage checks an image against a size and pads it with 0xFF
func PrepareImage(data []byte, size string) ([]byte, error) {
	mask, ok := Sizes[size]; if !ok { return nil, fmt.Errorf("unknown size %q (use %s)", size, SizeNames()) }
	span := mask + 1
	if len(data) > rom_capacity {
		return nil, fmt.Errorf("image is %d bytes; a PicoROM holds %d", len(data), rom_capacity)
	}
	for k := span; k < len(data); k++ {
		if data[k] != 0xFF { return nil, fmt.Errorf("image has data at 0x%x, above the %s window", k, size) }
	}
	if len(data) < span { data = append(data, bytes.Repeat([]byte{0xFF}, span-len(data))...) }
	return data, nil
}

// Load writes an image into the unit's volatile memory and reads it all back.
// With the diagnostic firmware, ROM service is paused while writing.
func Load(name string, data []byte, size string) ([]byte, error) {
	l, e := Open(name); if e != nil { return nil, e }
	defer l.Close()
	paused := time.Time{}
	if _, e := l.Set("rom_enable", "0"); e == nil { paused = time.Now() }
	want := fmt.Sprintf("0x%08x", Sizes[size])
	got, e := l.Set("addr_mask", fmt.Sprintf("0x%x", Sizes[size])); if e != nil { return nil, e }
	if got != want { return nil, fmt.Errorf("%s did not accept addr_mask %s (got %s)", name, want, got) }
	e = l.Write(0, data); if e != nil { return nil, e }
	back, e := l.Read(0, len(data)); if e != nil { return nil, e }
	if !paused.IsZero() {
		time.Sleep(time.Until(paused.Add(rom_pause)))
		_, e = l.Set("rom_enable", "1"); if e != nil { return back, e }
	}
	return back, nil
}

// Download reads length bytes of the unit's current image
func Download(name string, length int) ([]byte, error) {
	l, e := Open(name); if e != nil { return nil, e }
	defer l.Close()
	return l.Read(0, length)
}

// Rename changes the unit's name, which the firmware keeps in flash.
// The unit reconnects to USB under the new name.
func Rename(old, new string) error {
	l, e := Open(old); if e != nil { return e }
	defer l.Close()
	got, e := l.Set("name", new); if e != nil { return e }
	if got != new { return fmt.Errorf("rename failed: the unit reports %q", got) }
	return nil
}

// MiniproRead reads the chip in the XGecu programmer without the chip-ID
// check (no 12 V on A9)
func MiniproRead(device, path string) ([]byte, error) {
	if device == "" { return nil, fmt.Errorf("programmer.minipro_device is not set in the lab file") }
	out, e := exec.Command("minipro", "-p", device, "-x", "-r", path).CombinedOutput()
	if e != nil { return nil, fmt.Errorf("minipro: %w\n%s", e, out) }
	return os.ReadFile(path)
}

// LoadJob loads the image file Path into unit Name
type LoadJob struct {
	Name string
	Path string
}

// LoadRow keeps the field names of the earlier picorom_load.py reports
type LoadRow struct {
	Name          string `json:"name"`
	Serial        string `json:"serial"`
	BuildConfig   string `json:"build_config"`
	Diag          string `json:"diag_version,omitempty"`
	Image         string `json:"image"`
	ImageSha      string `json:"image_sha256"`
	ReadbackSha   string `json:"usb_readback_sha256"`
	UsbMatch      bool   `json:"usb_match"`
	XgecuSha      string `json:"xgecu_sha256,omitempty"`
	XgecuMismatch *int   `json:"xgecu_mismatches,omitempty"`
}

type LoadReport struct {
	Time     string    `json:"time_utc"`
	Size     string    `json:"size"`
	AddrMask string    `json:"addr_mask"`
	Units    []LoadRow `json:"units"`
	Ok       bool      `json:"ok"`
	Dir      string    `json:"dir,omitempty"`
}

// LoadImages loads every job with full readback and writes outdir/report.json.
// The caller must make sure the PCB is off. With xgecu, the single unit sits
// in the programmer and is also read through its socket.
func LoadImages(lab *Lab, jobs []LoadJob, size, outdir string, xgecu bool) (*LoadReport, error) {
	mask, ok := Sizes[size]; if !ok { return nil, fmt.Errorf("unknown size %q (use %s)", size, SizeNames()) }
	if xgecu && len(jobs) != 1 { return nil, fmt.Errorf("the XGecu check reads one unit at a time") }
	rep := &LoadReport{Time: utc_now(), Size: size, AddrMask: fmt.Sprintf("0x%x", mask), Ok: true, Dir: outdir}
	e := os.MkdirAll(outdir, 0o775); if e != nil { return nil, e }
	for _, j := range jobs {
		row, e := load_one(lab, j, size, outdir, xgecu); if e != nil { return rep, fmt.Errorf("%s: %w", j.Name, e) }
		rep.Ok = rep.Ok && row.UsbMatch && (row.XgecuMismatch == nil || *row.XgecuMismatch == 0)
		rep.Units = append(rep.Units, row)
	}
	js, _ := json.MarshalIndent(rep, "", "  ")
	return rep, os.WriteFile(filepath.Join(outdir, "report.json"), append(js, '\n'), 0o664)
}

func load_one(lab *Lab, j LoadJob, size, outdir string, xgecu bool) (LoadRow, error) {
	u, e := FindUnit(lab, j.Name); if e != nil { return LoadRow{}, e }
	e = u.Usable(); if e != nil { return LoadRow{}, e }
	raw, e := os.ReadFile(j.Path); if e != nil { return LoadRow{}, e }
	data, e := PrepareImage(raw, size); if e != nil { return LoadRow{}, fmt.Errorf("%s: %w", j.Path, e) }
	abs, _ := filepath.Abs(j.Path)
	row := LoadRow{Name: u.Name, Serial: u.Serial, BuildConfig: u.BuildConfig, Diag: u.Diag, Image: abs, ImageSha: Sha(raw)}
	back, e := Load(u.Name, data, size); if e != nil { return row, e }
	row.ReadbackSha, row.UsbMatch = Sha(back), bytes.Equal(back, data)
	if !row.UsbMatch { os.WriteFile(filepath.Join(outdir, "readback-"+u.Name+".bin"), back, 0o664) }
	if xgecu {
		x, e := MiniproRead(lab.Programmer.MiniproDevice, filepath.Join(outdir, "xgecu-"+u.Name+".bin")); if e != nil { return row, e }
		// with A16 ignored the socket shows the lower half twice
		expect := data
		if span := Sizes[size] + 1; span < len(x) { expect = bytes.Repeat(data[:span], len(x)/span) }
		n := 0
		for k := range x { if k >= len(expect) || x[k] != expect[k] { n++ } }
		row.XgecuSha, row.XgecuMismatch = Sha(x), &n
	}
	return row, nil
}
