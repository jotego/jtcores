/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-11-2026 */

package picorom

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"os"
	"syscall"
	"time"

	"golang.org/x/sys/unix"
	"golang.org/x/term"
)

// PowerState is what the switch reports. On is nil when unknown.
type PowerState struct {
	On     *bool    `json:"on"`
	Watts  *float64 `json:"watts,omitempty"`
	Device string   `json:"device,omitempty"`
	Time   string   `json:"utc"`
}

func (s PowerState) IsOff() bool { return s.On != nil && !*s.On }

// Power controls the PCB supply
type Power interface {
	Status() (PowerState, error)
	Set(on bool) (PowerState, error)
	Describe() string
}

// NewPower builds the switch described in the lab file
func NewPower(lab *Lab) (Power, error) {
	switch lab.Power.Type {
	case "", "manual": return &manual_power{}, nil
	case "shelly-gen2": return new_shelly(lab.Power), nil
	}
	return nil, fmt.Errorf("unknown power type %q in %s (use shelly-gen2 or manual)", lab.Power.Type, lab.Path)
}

func utc_now() string { return time.Now().UTC().Format("20060102T150405Z") }

// Shelly Gen2+ local RPC (Switch.GetStatus / Switch.Set)
type shelly struct {
	cfg    LabPower
	client *http.Client
}

func new_shelly(cfg LabPower) *shelly {
	dialer := &net.Dialer{Timeout: 3 * time.Second}
	if cfg.Interface != "" {
		dialer.Control = func(network, address string, c syscall.RawConn) error {
			var err error
			e := c.Control(func(fd uintptr) {
				err = unix.SetsockoptString(int(fd), unix.SOL_SOCKET, unix.SO_BINDTODEVICE, cfg.Interface)
			})
			if e != nil { return e }
			return err
		}
	}
	tr := &http.Transport{DialContext: dialer.DialContext}
	return &shelly{cfg: cfg, client: &http.Client{Transport: tr, Timeout: 4 * time.Second}}
}

func (s *shelly) Describe() string {
	d := fmt.Sprintf("Shelly %s at %s", s.cfg.Id, s.cfg.Url)
	if s.cfg.Interface != "" { d += " via " + s.cfg.Interface }
	return d
}

func (s *shelly) rpc(path string, body any, out any) error {
	var rd *bytes.Reader
	method := "GET"
	if body != nil {
		data, _ := json.Marshal(body)
		rd, method = bytes.NewReader(data), "POST"
	}
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
	defer cancel()
	var req *http.Request
	var e error
	if rd != nil {
		req, e = http.NewRequestWithContext(ctx, method, s.cfg.Url+path, rd)
	} else {
		req, e = http.NewRequestWithContext(ctx, method, s.cfg.Url+path, nil)
	}
	if e != nil { return e }
	if body != nil { req.Header.Set("Content-Type", "application/json") }
	resp, e := s.client.Do(req); if e != nil { return fmt.Errorf("%s: %w", s.Describe(), e) }
	defer resp.Body.Close()
	if resp.StatusCode != 200 { return fmt.Errorf("%s: HTTP %d for %s", s.Describe(), resp.StatusCode, path) }
	return json.NewDecoder(resp.Body).Decode(out)
}

func (s *shelly) Status() (PowerState, error) {
	var dev struct{ Id string `json:"id"` }
	e := s.rpc("/rpc/Shelly.GetDeviceInfo", nil, &dev); if e != nil { return PowerState{}, e }
	if s.cfg.Id != "" && dev.Id != s.cfg.Id {
		return PowerState{}, fmt.Errorf("unexpected device %q at %s (lab file expects %q)", dev.Id, s.cfg.Url, s.cfg.Id)
	}
	st, e := s.relay(); if e != nil { return st, e }
	st.Device = dev.Id
	return st, nil
}

// relay reads the switch state without the identity check
func (s *shelly) relay() (PowerState, error) {
	var st struct {
		Output *bool    `json:"output"`
		Apower *float64 `json:"apower"`
	}
	e := s.rpc(fmt.Sprintf("/rpc/Switch.GetStatus?id=%d", s.cfg.Switch), nil, &st); if e != nil { return PowerState{}, e }
	if st.Output == nil { return PowerState{}, errors.New("switch status without output field") }
	return PowerState{On: st.Output, Watts: st.Apower, Time: utc_now()}, nil
}

// Set checks the device identity before switching on. Switching off skips
// that check and retries, so a network glitch cannot leave the PCB powered.
func (s *shelly) Set(on bool) (PowerState, error) {
	tries := 1
	if on {
		_, e := s.Status(); if e != nil { return PowerState{}, e }
	} else { tries = 5 }
	var st PowerState
	var e error
	for k := 0; k < tries; k++ {
		if k > 0 { time.Sleep(500 * time.Millisecond) }
		var ack map[string]any
		e = s.rpc("/rpc/Switch.Set", map[string]any{"id": s.cfg.Switch, "on": on}, &ack); if e != nil { continue }
		st, e = s.relay(); if e != nil { continue }
		if *st.On == on { return st, nil }
		e = fmt.Errorf("%s did not switch %s", s.Describe(), on_off(on))
	}
	return st, e
}

func on_off(on bool) string {
	if on { return "on" }
	return "off"
}

// Manual power: the person at the bench switches the supply
type manual_power struct{}

func (m *manual_power) Describe() string { return "manual power switch (no switch in the lab file)" }

func (m *manual_power) Status() (PowerState, error) { return PowerState{Time: utc_now()}, nil }

func (m *manual_power) Set(on bool) (PowerState, error) {
	if !term.IsTerminal(int(os.Stdin.Fd())) {
		return PowerState{}, fmt.Errorf("switch the PCB %s by hand: no power switch is configured and there is no terminal to confirm", on_off(on))
	}
	fmt.Fprintf(os.Stderr, "Switch the PCB %s now, then press Enter: ", on_off(on))
	bufio.NewReader(os.Stdin).ReadString('\n')
	v := on
	return PowerState{On: &v, Time: utc_now()}, nil
}
