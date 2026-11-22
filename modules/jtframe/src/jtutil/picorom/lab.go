/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-11-2026 */

package picorom

// Laboratory configuration: $JOTEGO/picorom.yaml. Everything specific to one
// lab (owned units, power switch, programmer, network quirks) lives there,
// never in the repository.

import (
	"fmt"
	"os"
	"path/filepath"

	"gopkg.in/yaml.v2"
)

type LabUnit struct {
	Name     string `yaml:"name"     json:"name"`
	Pins     int    `yaml:"pins"     json:"pins,omitempty"`
	Note     string `yaml:"note"     json:"note,omitempty"`
	Disabled string `yaml:"disabled" json:"disabled,omitempty"` // reason; the unit is never loaded
}

type LabPower struct {
	Type      string `yaml:"type"`      // shelly-gen2 or manual (default)
	Url       string `yaml:"url"`
	Id        string `yaml:"id"`        // expected device id, checked before every switch
	Switch    int    `yaml:"switch"`
	Interface string `yaml:"interface"` // optional network interface for the HTTP requests
}

type LabProgrammer struct {
	MiniproDevice string `yaml:"minipro_device"`
}

type Lab struct {
	Path       string             `yaml:"-"`
	Units      map[string]LabUnit `yaml:"units"` // key: USB chip serial
	Power      LabPower           `yaml:"power"`
	Programmer LabProgrammer      `yaml:"programmer"`
}

// DefaultLabPath is $JOTEGO/picorom.yaml
func DefaultLabPath() (string, error) {
	jotego := os.Getenv("JOTEGO")
	if jotego == "" {
		return "", fmt.Errorf("JOTEGO is not set: the lab configuration is $JOTEGO/picorom.yaml (or use --lab)")
	}
	return filepath.Join(jotego, "picorom.yaml"), nil
}

// LoadLab reads the lab file. A missing file gives an empty lab: units are
// then only known by their USB names and power switching is manual.
func LoadLab(path string) (*Lab, error) {
	lab := &Lab{Path: path}
	data, e := os.ReadFile(path)
	if os.IsNotExist(e) { return lab, nil }
	if e != nil { return nil, e }
	e = yaml.UnmarshalStrict(data, lab); if e != nil { return nil, fmt.Errorf("%s: %w", path, e) }
	return lab, nil
}

// Unit returns the lab entry for a USB chip serial
func (lab *Lab) Unit(serial string) (LabUnit, bool) {
	u, ok := lab.Units[serial]
	return u, ok
}
