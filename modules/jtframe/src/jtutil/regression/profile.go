/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"gopkg.in/yaml.v2"
)

const DefaultVideoFrames = 4000
const DefaultStartupFrames = 500

// Profile describes the per-main-game hardware test definition.
type Profile struct {
	Setname string                 `json:"setname"`
	Video   int                    `json:"video"`
	Startup int                    `json:"start-up"`
	Inputs  string                 `json:"inputs,omitempty"`
	Options map[string]interface{} `json:"options,omitempty"`
}

// ResolveProfile merges the shared defaults and the exact setname entry.
// A game without an entry runs with neutral CAB inputs and default lengths.
func ResolveProfile(globalPath, corePath, core, setname string) (Profile, error) {
	profile := Profile{Setname: setname, Video: DefaultVideoFrames, Startup: DefaultStartupFrames,
		Options: make(map[string]interface{})}
	global, e := load_yaml_map(globalPath)
	if e != nil && !os.IsNotExist(e) {
		return profile, e
	}
	if e = apply_profile(&profile, global); e != nil {
		return profile, fmt.Errorf("%s: %w", globalPath, e)
	}
	localPath := filepath.Join(corePath, "cores", core, "cfg", "reg.yaml")
	local, e := load_yaml_map(localPath)
	if e != nil && !os.IsNotExist(e) {
		return profile, e
	}
	entry, found := lookup_yaml(local, setname)
	// An empty YAML game entry (for example `1942:`) documents the title
	// without overriding the shared profile. YAML v2 decodes it as nil.
	if found && entry != nil {
		values, ok := normalize_yaml_map(entry)
		if !ok {
			return profile, fmt.Errorf("%s: profile for %s must be a mapping", localPath, setname)
		}
		if e = apply_profile(&profile, values); e != nil {
			return profile, fmt.Errorf("%s: %w", localPath, e)
		}
	}
	if profile.Video <= 0 {
		return profile, fmt.Errorf("%s: video frame count must be positive", setname)
	}
	if profile.Startup < 0 || profile.Startup >= profile.Video {
		return profile, fmt.Errorf("%s: start-up must be at least zero and less than video (%d)", setname, profile.Video)
	}
	return profile, nil
}

// profileSkipExclusions reads the per-core reg.yaml selection flag. This is
// applied only while preparing a new inventory; frozen manifests remain
// authoritative so that historical runs and retries are unchanged.
func profileSkipExclusions(corePath string, tuples []InventoryTuple) (map[string]string, error) {
	excluded := make(map[string]string)
	profiles := make(map[string]map[string]interface{})
	for _, tuple := range tuples {
		values, ok := profiles[tuple.Core]
		if !ok {
			filename := filepath.Join(corePath, "cores", tuple.Core, "cfg", "reg.yaml")
			loaded, err := load_yaml_map(filename)
			if err != nil && !os.IsNotExist(err) {
				return nil, err
			}
			values = loaded
			profiles[tuple.Core] = values
		}
		entry, found := lookup_yaml(values, tuple.Setname)
		if !found || entry == nil {
			continue
		}
		fields, ok := normalize_yaml_map(entry)
		if !ok {
			return nil, fmt.Errorf("%s: profile for %s must be a mapping", filepath.Join(corePath, "cores", tuple.Core, "cfg", "reg.yaml"), tuple.Setname)
		}
		raw, found := fields["skip"]
		if !found {
			continue
		}
		skip, ok := raw.(bool)
		if !ok {
			return nil, fmt.Errorf("%s/%s: skip must be a boolean", tuple.Core, tuple.Setname)
		}
		if skip {
			excluded[tupleKey(tuple)] = "per-game reg.yaml skip: true"
		}
	}
	return excluded, nil
}

func load_yaml_map(filename string) (map[string]interface{}, error) {
	data, e := os.ReadFile(filename)
	if e != nil {
		return nil, e
	}
	var raw interface{}
	if e = yaml.Unmarshal(data, &raw); e != nil {
		return nil, fmt.Errorf("reading %s: %w", filename, e)
	}
	values, ok := normalize_yaml_map(raw)
	if !ok && raw != nil {
		return nil, fmt.Errorf("%s: expected a YAML mapping", filename)
	}
	return values, nil
}

func normalize_yaml_map(raw interface{}) (map[string]interface{}, bool) {
	result := make(map[string]interface{})
	switch values := raw.(type) {
	case map[interface{}]interface{}:
		for key, value := range values {
			result[fmt.Sprint(key)] = value
		}
		return result, true
	case map[string]interface{}:
		for key, value := range values {
			result[key] = value
		}
		return result, true
	default:
		return nil, false
	}
}

func lookup_yaml(values map[string]interface{}, key string) (interface{}, bool) {
	if value, ok := values[key]; ok {
		return value, true
	}
	// yaml.v2 decodes unquoted numeric keys as integer types.
	if number, e := strconv.Atoi(key); e == nil {
		if value, ok := values[strconv.Itoa(number)]; ok {
			return value, true
		}
	}
	return nil, false
}

func apply_profile(profile *Profile, values map[string]interface{}) error {
	for key, value := range values {
		switch strings.ToLower(key) {
		case "video":
			n, ok := yaml_int(value)
			if !ok {
				return fmt.Errorf("video must be an integer")
			}
			profile.Video = n
		case "start-up", "startup":
			n, ok := yaml_int(value)
			if !ok {
				return fmt.Errorf("start-up must be an integer")
			}
			profile.Startup = n
		case "inputs":
			text, ok := value.(string)
			if !ok {
				return fmt.Errorf("inputs must be a path string")
			}
			profile.Inputs = text
		default:
			profile.Options[key] = value
		}
	}
	return nil
}

func yaml_int(value interface{}) (int, bool) {
	switch number := value.(type) {
	case int:
		return number, true
	case int64:
		return int(number), true
	case uint64:
		return int(number), true
	case float64:
		if number == float64(int(number)) {
			return int(number), true
		}
	case string:
		parsed, e := strconv.Atoi(number)
		return parsed, e == nil
	}
	return 0, false
}

// A zero first-frame preserves the historic first checkpoint at one cadence.
func captureSchedule(frames, cadence, first int) (int, int, error) {
	if cadence <= 0 {
		return 0, 0, fmt.Errorf("invalid capture cadence")
	}
	if first == 0 {
		first = cadence
	}
	if first < cadence || first%cadence != 0 || first > frames/cadence*cadence {
		return 0, 0, fmt.Errorf("first-frame must be a multiple of %d between %d and the last video checkpoint", cadence, cadence)
	}
	return first, (frames/cadence - first/cadence) + 1, nil
}

// Capture starts at the first cadence checkpoint at or after start-up.
func firstCaptureFrame(startup int) int {
	if startup <= 100 {
		return 100
	}
	if startup%100 == 0 {
		return startup
	}
	if startup > int(^uint(0)>>1)-100 {
		return -1
	}
	return startup/100*100 + 100
}
