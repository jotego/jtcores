/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-11-2026 */

package picorom

import (
	"fmt"
	"strings"
)

// Unit describes a connected PicoROM: what it reports and what the lab knows
type Unit struct {
	UsbDevice
	BuildConfig string  `json:"build_config"`
	BuildVer    string  `json:"build_version,omitempty"`
	Diag        string  `json:"diag_version,omitempty"`
	AddrMask    string  `json:"addr_mask"`
	RomEnable   string  `json:"rom_enable,omitempty"`
	Recorder    bool    `json:"recorder"` // event recorder (diagnostic firmware)
	Lab         *LabUnit `json:"lab,omitempty"`
}

// Usable reports why a unit must not be loaded, or nil
func (u Unit) Usable() error {
	if u.Lab != nil && u.Lab.Disabled != "" {
		return fmt.Errorf("%s is disabled in the lab file: %s", u.Name, u.Lab.Disabled)
	}
	return nil
}

// Units lists the connected PicoROMs with their parameters
func Units(lab *Lab) ([]Unit, error) {
	devs, e := ListUsb(); if e != nil { return nil, e }
	all := []Unit{}
	for _, d := range devs {
		u, e := Inspect(d, lab); if e != nil { return nil, fmt.Errorf("%s: %w", d.Name, e) }
		all = append(all, u)
	}
	return all, nil
}

func Inspect(d UsbDevice, lab *Lab) (Unit, error) {
	u := Unit{UsbDevice: d}
	if lu, ok := lab.Unit(d.Serial); ok { u.Lab = &lu }
	l, e := OpenDevice(d); if e != nil { return u, e }
	defer l.Close()
	u.BuildConfig, e = l.Get("build_config"); if e != nil { return u, e }
	u.AddrMask, e = l.Get("addr_mask"); if e != nil { return u, e }
	u.BuildVer, _ = l.Get("build_version")
	u.Diag, _ = l.Get("diag_version")
	u.RomEnable, _ = l.Get("rom_enable")
	u.Recorder = strings.HasPrefix(u.Diag, "jtkcpu")
	return u, nil
}

// FindUnit returns the connected unit with the given USB name
func FindUnit(lab *Lab, name string) (Unit, error) {
	devs, e := ListUsb(); if e != nil { return Unit{}, e }
	var names []string
	for _, d := range devs {
		if d.Name == name { return Inspect(d, lab) }
		names = append(names, d.Name)
	}
	if len(names) == 0 { return Unit{}, fmt.Errorf("%s is not connected: no PicoROM found on USB", name) }
	return Unit{}, fmt.Errorf("%s is not connected. Found: %s", name, strings.Join(names, ", "))
}
