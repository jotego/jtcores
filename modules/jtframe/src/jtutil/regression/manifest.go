/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"os"

	"gopkg.in/yaml.v2"
)

// Config contains portable paths and board connection settings. Secrets stay
// in the configured netrc file, not this YAML document.
type Config struct {
	Root              string   `yaml:"root"`
	Source            string   `yaml:"source"`
	Repository        string   `yaml:"repository"`
	ROMSource         string   `yaml:"rom-source"`
	BuildsDir         string   `yaml:"builds-dir"`
	BuildsSince       string   `yaml:"builds-since"`
	NoPublish         bool     `yaml:"-"`
	Host              string   `yaml:"host"`
	Netrc             string   `yaml:"netrc"`
	ControlHelper     string   `yaml:"control-helper"`
	CabPacker         string   `yaml:"cab-packer"`
	MRAConverter      string   `yaml:"mra-converter"`
	Curl              string   `yaml:"curl"`
	GlobalProfile     string   `yaml:"global-profile"`
	TimeoutSeconds    int      `yaml:"timeout-seconds"`
	Firmware          string   `yaml:"firmware"`
	FirmwareSHA256    string   `yaml:"firmware-sha256"`
	CaptureToolSHA256 string   `yaml:"capture-tool-sha256"`
	CabExporterSHA256 string   `yaml:"cab-exporter-sha256"`
}

func ReadConfig(filename string) (Config, error) {
	var config Config
	data, e := os.ReadFile(filename)
	if e != nil {
		return config, e
	}
	e = yaml.UnmarshalStrict(data, &config)
	return config, e
}

// Manifest is the immutable, build-specific inventory consumed by Batch.
type Manifest struct {
	RunID  string         `json:"run_id"`
	Build  BuildIdentity  `json:"build"`
	Source string         `json:"source"`
	ProjectSHA string      `json:"project_sha"`
	Cores  []CoreManifest `json:"cores"`
}

type CoreManifest struct {
	Core  string     `json:"core"`
	Games []GameSpec `json:"games"`
}
