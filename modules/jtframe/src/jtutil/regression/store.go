/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"time"
)

var ErrBoardBusy = errors.New("another regression batch holds the board lock")

type State struct {
	RunID              string                `json:"run_id"`
	Build              BuildIdentity         `json:"build"`
	Core               string                `json:"core"`
	TestIdentity       string                `json:"test_identity"`
	GameSpecIdentities map[string]string     `json:"game_spec_identities,omitempty"`
	Games              map[string]GameResult `json:"games"`
	Publication        map[string]any        `json:"publication,omitempty"`
	Updated            time.Time             `json:"updated"`
}

// AcquireLock holds the regression board lock until the returned file is closed.
func AcquireLock(root string, existing ...bool) (*os.File, error) {
	if len(existing)==0 || !existing[0] {
		if e:=os.MkdirAll(filepath.Join(root,"log"),0750);e!=nil{return nil,e}
	}
	f, e := os.OpenFile(filepath.Join(root, "log", "lock"), os.O_CREATE|os.O_RDWR, 0640)
	if e != nil {
		return nil, e
	}
	if e = syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); e != nil {
		f.Close()
		if errors.Is(e, syscall.EWOULDBLOCK) { return nil, ErrBoardBusy }
		return nil, e
	}
	return f, nil
}

func ReleaseLock(lock *os.File) error {
	if lock == nil {
		return nil
	}
	_ = syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)
	return lock.Close()
}

func ReadState(filename string) (*State, error) {
	data, e := os.ReadFile(filename)
	if e != nil {
		return nil, e
	}
	var state State
	if e = json.Unmarshal(data, &state); e != nil {
		return nil, fmt.Errorf("invalid resume state: %w", e)
	}
	if state.Games == nil {
		state.Games = make(map[string]GameResult)
	}
	return &state, nil
}

func WriteState(filename string, state *State) error {
	state.Updated = time.Now().UTC()
	data, e := json.MarshalIndent(state, "", "  ")
	if e != nil {
		return e
	}
	return atomic_write(filename, append(data, '\n'), 0640)
}

// HashFiles returns a stable digest over named fixture contents.
func HashFiles(files map[string]string) (string, error) {
	keys := make([]string, 0, len(files))
	for name := range files {
		keys = append(keys, name)
	}
	// Insertion sort keeps this package dependency free.
	for i := 1; i < len(keys); i++ {
		for j := i; j > 0 && keys[j] < keys[j-1]; j-- {
			keys[j], keys[j-1] = keys[j-1], keys[j]
		}
	}
	h := sha256.New()
	for _, name := range keys {
		f, e := os.Open(files[name])
		if e != nil {
			return "", e
		}
		if _, e = io.WriteString(h, name+"\x00"); e == nil {
			_, e = io.Copy(h, f)
		}
		f.Close()
		if e != nil {
			return "", e
		}
		_, _ = io.WriteString(h, "\x00")
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

func FileSHA256(filename string) (string, error) {
	f, e := os.Open(filename)
	if e != nil {
		return "", e
	}
	defer f.Close()
	h := sha256.New()
	if _, e = io.Copy(h, f); e != nil {
		return "", e
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

func file_sha256(filename string) (string, error) { return FileSHA256(filename) }

func TestDefinitionIdentity(core, setname string, profile Profile, romFiles, arcFiles map[string]string, cabPath, firmware, captureFormat string) (string, error) {
	return TestDefinitionIdentityWithTools(core, setname, profile, romFiles, arcFiles, cabPath, firmware, "", "", captureFormat)
}

func TestDefinitionIdentityWithTools(core, setname string, profile Profile, romFiles, arcFiles map[string]string, cabPath, firmware, firmwareSHA, captureToolSHA, captureFormat string) (string, error) {
	return TestDefinitionIdentityWithCapture(core, setname, profile, romFiles, arcFiles, cabPath, firmware, firmwareSHA, captureToolSHA, captureFormat, cabPath, "strict", 0)
}

func TestDefinitionIdentityWithCapture(core, setname string, profile Profile, romFiles, arcFiles map[string]string, cabPath, firmware, firmwareSHA, captureToolSHA, captureFormat, sourceCABPath, clipMode string, frameBudget int) (string, error) {
	fixtures := make(map[string]string, len(romFiles)+len(arcFiles)+1)
	for k, v := range romFiles {
		fixtures["rom/"+k] = v
	}
	for k, v := range arcFiles {
		fixtures["arc/"+k] = v
	}
	if cabPath != "" {
		fixtures["cab/input/"+filepath.Base(cabPath)] = cabPath
	}
	if sourceCABPath != "" {
		fixtures["cab/source/"+filepath.Base(sourceCABPath)] = sourceCABPath
	}
	fixtureHash, e := HashFiles(fixtures)
	if e != nil {
		return "", e
	}
	identity := struct {
		Core           string  `json:"core"`
		Setname        string  `json:"setname"`
		Profile        Profile `json:"profile"`
		FixtureHash    string  `json:"fixture_sha256"`
		Firmware       string  `json:"firmware"`
		FirmwareSHA    string  `json:"firmware_sha256"`
		CaptureToolSHA string  `json:"capture_tool_sha256"`
		Format         string  `json:"capture_format"`
		CABClipMode    string  `json:"cab_clip_mode"`
		CABFrameBudget int     `json:"cab_frame_budget"`
	}{core, setname, profile, fixtureHash, firmware, firmwareSHA, captureToolSHA, captureFormat, clipMode, frameBudget}
	data, e := json.Marshal(identity)
	if e != nil {
		return "", e
	}
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:]), nil
}

// PublishComplete replaces the current result slot and removes stale siblings.
// Designer-approved ref images are never modified.
func PublishComplete(gameRoot, sourceDir string, outcome Outcome, metadata any) error {
	if outcome != New && outcome != Fail && outcome != Pass {
		return fmt.Errorf("cannot publish incomplete outcome %q", outcome)
	}
	if e := os.MkdirAll(gameRoot, 0750); e != nil {
		return e
	}
	png_dir, e := os.MkdirTemp(filepath.Dir(sourceDir), "png-")
	if e != nil { return e }
	defer os.RemoveAll(png_dir)
	if e = export_png_frames(sourceDir, png_dir); e != nil { return e }
	switch outcome {
	case New:
		if _, e := os.Stat(filepath.Join(gameRoot, "ref")); os.IsNotExist(e) {
			if e := clearResultSlot(gameRoot,"fail"); e != nil { return e }
			return replace_dir(png_dir, filepath.Join(gameRoot, "new"))
		}
		return fmt.Errorf("approved ref exists; refusing to publish new")
	case Fail:
		if e := clearResultSlot(gameRoot,"new"); e != nil { return e }
		return replace_dir(png_dir, filepath.Join(gameRoot, "fail"))
	case Pass:
		return clearResultSlots(gameRoot)
	}
	return nil
}

func write_metadata(dir string, metadata any) error {
	if metadata == nil {
		return nil
	}
	data, e := json.MarshalIndent(metadata, "", "  ")
	if e != nil {
		return e
	}
	return atomic_write(filepath.Join(dir, "metadata.json"), append(data, '\n'), 0640)
}

func replace_dir(source, destination string) error {
	return replace_dir_hook(source, destination, nil)
}

func replace_dir_hook(source, destination string, afterOld func() error) error {
	parent := filepath.Dir(destination)
	if e := os.MkdirAll(parent, 0750); e != nil {
		return e
	}
	if e := recover_dir(destination); e != nil {
		return e
	}
	staging := destination + ".staging"
	_ = os.RemoveAll(staging)
	if e := copy_tree(source, staging); e != nil {
		_ = os.RemoveAll(staging)
		return e
	}
	old := destination + ".old"
	_ = os.RemoveAll(old)
	if _, e := os.Stat(destination); e == nil {
		if e = os.Rename(destination, old); e != nil {
			return e
		}
		if afterOld != nil {
			return afterOld()
		}
	}
	if e := os.Rename(staging, destination); e != nil {
		_ = os.Rename(old, destination)
		return e
	}
	return os.RemoveAll(old)
}

// recover_dir restores the last complete destination after interruption in
// the two-rename replacement window. The run state is not finalized until the
// replacement returns, so an old directory is always safe to restore.
func recover_dir(destination string) error {
	old, staging := destination+".old", destination+".staging"
	if _, e := os.Stat(destination); e == nil {
		_ = os.RemoveAll(old)
		_ = os.RemoveAll(staging)
		return nil
	} else if !os.IsNotExist(e) {
		return e
	}
	if _, e := os.Stat(old); e == nil {
		if e = os.Rename(old, destination); e != nil {
			return e
		}
		_ = os.RemoveAll(staging)
		return nil
	} else if !os.IsNotExist(e) {
		return e
	}
	if _, e := os.Stat(staging); e == nil {
		return os.Rename(staging, destination)
	} else if !os.IsNotExist(e) {
		return e
	}
	return nil
}

func copy_tree(source, destination string) error {
	return filepath.Walk(source, func(name string, info os.FileInfo, e error) error {
		if e != nil {
			return e
		}
		rel, e := filepath.Rel(source, name)
		if e != nil {
			return e
		}
		target := filepath.Join(destination, rel)
		if info.IsDir() {
			return os.MkdirAll(target, 0750)
		}
		if !info.Mode().IsRegular() {
			return fmt.Errorf("unsupported result file %s", name)
		}
		in, e := os.Open(name)
		if e != nil {
			return e
		}
		defer in.Close()
		out, e := os.OpenFile(target, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0640)
		if e != nil {
			return e
		}
		_, e = io.Copy(out, in)
		if e == nil {
			e = out.Sync()
		}
		closeErr := out.Close()
		if e != nil {
			return e
		}
		return closeErr
	})
}

func safeComponent(value string) bool {
	return value != "" && !strings.ContainsAny(value, "/\\") && value != "." && value != ".."
}
