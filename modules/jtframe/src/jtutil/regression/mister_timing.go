/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"encoding/xml"
	"fmt"
	"io"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"

	"jotego/jtframe/cfgstr"
	"jotego/jtframe/macros"
)

var jtframeMacroMu sync.Mutex
var sourceEnvironmentMu sync.Mutex

// SourceCommitView exposes source-derived configuration at the selected
// workflow commit, even when the runner checkout is newer.
type SourceCommitView struct {
	Root       string
	FrameRoot  string
	Commit     string
	parent     string
	repository string
}

func OpenSourceCommitView(ctx context.Context, repository, commit string) (*SourceCommitView, error) {
	if ctx == nil || !isCommitSHA(commit) {
		return nil, fmt.Errorf("a full source commit SHA is required")
	}
	if out, err := exec.CommandContext(ctx, "git", "-C", repository, "cat-file", "-e", commit+"^{commit}").CombinedOutput(); err != nil {
		return nil, fmt.Errorf("selected source commit %s is unavailable: %s", commit, strings.TrimSpace(string(out)))
	}
	parent, err := os.MkdirTemp("", "jtutil-source-commit-")
	if err != nil {
		return nil, err
	}
	view := &SourceCommitView{Root: filepath.Join(parent, "jtcores"), Commit: commit, parent: parent, repository: repository}
	view.FrameRoot = filepath.Join(view.Root, "modules", "jtframe")
	cleanup := func(cause error) (*SourceCommitView, error) {
		_ = view.Close()
		return nil, cause
	}
	if out, err := exec.CommandContext(ctx, "git", "-C", repository, "worktree", "add", "--detach", view.Root, commit).CombinedOutput(); err != nil {
		return cleanup(fmt.Errorf("create source commit view: %s: %w", strings.TrimSpace(string(out)), err))
	}
	return view, nil
}

func (view *SourceCommitView) Close() error {
	if view == nil || view.parent == "" {
		return nil
	}
	var closeErr error
	if _, err := os.Stat(view.Root); err == nil {
		if out, removeErr := exec.Command("git", "-C", view.repository, "worktree", "remove", "--force", view.Root).CombinedOutput(); removeErr != nil && closeErr == nil {
			closeErr = fmt.Errorf("remove source commit view: %s: %w", strings.TrimSpace(string(out)), removeErr)
		}
	}
	if err := os.RemoveAll(view.parent); err != nil && closeErr == nil {
		closeErr = err
	}
	view.parent = ""
	return closeErr
}

func RequireSourceCommit(ctx context.Context, source, commit, core string) error {
	if ctx == nil || !isCommitSHA(commit) || !manualComponent(core) {
		return fmt.Errorf("source commit and core are required")
	}
	_, err := exec.CommandContext(ctx, "git", "-C", source, "cat-file", "-e", commit+"^{commit}").Output()
	if err != nil {
		return fmt.Errorf("selected source commit %s is unavailable: %w", commit, err)
	}
	return nil
}

func miSTerNativeStatusPath(setname string, version uint64) string {
	name := setname
	if version != 0 {
		name += "_v" + strconv.FormatUint(version, 10)
	}
	return filepath.Join(miSTerNativeConfigRoot, name+".CFG")
}

func MiSTerConfigVersion(source, core string) (uint64, error) {
	if !manualComponent(core) {
		return 0, fmt.Errorf("invalid MiSTer core")
	}
	var config string
	err := withSourceEnvironment(source, func() error {
		jtframeMacroMu.Lock()
		defer jtframeMacroMu.Unlock()
		var renderErr error
		config, renderErr = cfgstr.Render(core, "mister")
		return renderErr
	})
	if err != nil {
		return 0, fmt.Errorf("render %s MiSTer config string: %w", core, err)
	}
	return miSTerConfigVersion(config)
}

func miSTerConfigVersion(config string) (uint64, error) {
	version := uint64(0)
	for _, field := range strings.Split(config, ";") {
		if !strings.HasPrefix(field, "v") {
			continue
		}
		parts := strings.SplitN(field, ",", 3)
		if len(parts) < 2 {
			continue
		}
		value := parts[1]
		if len(value) > 2 {
			value = value[:2]
		}
		value = strings.TrimLeft(value, " \t\n\r\v\f")
		if value == "" {
			continue
		}
		if value[0] == '+' || value[0] == '-' {
			if len(value) == 1 || value[1] < '0' || value[1] > '9' {
				continue
			}
			value = value[:2]
		} else if value[0] < '0' || value[0] > '9' {
			continue
		} else if len(value) > 1 && (value[1] < '0' || value[1] > '9') {
			value = value[:1]
		}
		parsed, parseErr := strconv.ParseUint(value, 10, 32)
		if parseErr != nil || parsed == 0 {
			continue
		}
		version = parsed
	}
	return version, nil
}

// resolveJTFRAMEValue returns one effective macro from the selected core/target.
// JTFRAME's macros package has process-global state, so callers that resolve
// macros concurrently must use this shared lock through the helper.
func resolveJTFRAMEValue(source, core, target, key string) (string, error) {
	if !manualComponent(core) || target == "" || strings.TrimSpace(key) != key {
		return "", fmt.Errorf("invalid core, target or macro name")
	}
	if err := validateCoreMacroFile(source, core); err != nil { return "", err }
	var value string
	err := withSourceEnvironment(source, func() error {
		jtframeMacroMu.Lock()
		defer jtframeMacroMu.Unlock()
		macros.MakeMacros(core, target)
		value = macros.Get(key)
		return nil
	})
	if err != nil {
		return "", err
	}
	return value, nil
}

func validateCoreMacroFile(source, core string) error {
	if !manualComponent(core) { return fmt.Errorf("invalid core name %q", core) }
	macroPath := filepath.Join(source, "cores", core, "cfg", "macros.def")
	macroInfo, err := os.Stat(macroPath)
	if err != nil {
		return fmt.Errorf("read %s macros for %s: %w", filepath.Base(macroPath), core, err)
	}
	if !macroInfo.Mode().IsRegular() {
		return fmt.Errorf("%s macros for %s are not a regular file", filepath.Base(macroPath), core)
	}
	return nil
}

// miSTerTargetSkipped reports cores that produce no MiSTer capture build:
// JTFRAME_SKIP cores and cores whose macros drop JTFRAME_REGRESSION (for
// example, cores that use DDR for video all the time).
func miSTerTargetSkipped(source, core string) (bool, error) {
	if err := validateCoreMacroFile(source, core); err != nil { return false, err }
	var skipped bool
	err := withSourceEnvironment(source, func() error {
		jtframeMacroMu.Lock()
		defer jtframeMacroMu.Unlock()
		macros.MakeMacros(core, "mister")
		skipped = macros.IsSet("JTFRAME_SKIP") || !macros.IsSet(macros.JTFRAME_REGRESSION)
		return nil
	})
	return skipped, err
}

func withSourceEnvironment(source string, run func() error) error {
	if run == nil {
		return fmt.Errorf("source configuration callback is required")
	}
	frame := filepath.Join(source, "modules", "jtframe")
	if _, err := os.Stat(filepath.Join(frame, "target")); err != nil {
		return fmt.Errorf("source JTFRAME tree is unavailable: %w", err)
	}
	sourceEnvironmentMu.Lock()
	defer sourceEnvironmentMu.Unlock()
	keys := []string{"JTROOT", "JTFRAME", "CORES", "MODULES"}
	old := make(map[string]string, len(keys))
	present := make(map[string]bool, len(keys))
	for _, key := range keys {
		old[key], present[key] = os.LookupEnv(key)
	}
	defer func() {
		for _, key := range keys {
			if present[key] {
				_ = os.Setenv(key, old[key])
			} else {
				_ = os.Unsetenv(key)
			}
		}
	}()
	for key, value := range map[string]string{"JTROOT": source, "JTFRAME": frame, "CORES": filepath.Join(source, "cores"), "MODULES": filepath.Join(source, "modules")} {
		if err := os.Setenv(key, value); err != nil {
			return err
		}
	}
	return run()
}

// resolveMiSTerFrameRate prefers JTFRAME_RATE, falling back only when the
// macro is absent to the per-set MAME raster refresh in the pinned XML data.
func resolveMiSTerFrameRate(source, core, setname string) (uint32, string, error) {
	value, err := resolveJTFRAMEValue(source, core, "mister", "JTFRAME_RATE")
	if err != nil {
		return 0, "", err
	}
	if value != "" {
		rate, parseErr := strconv.ParseFloat(value, 64)
		if parseErr != nil || math.IsNaN(rate) || math.IsInf(rate, 0) || rate <= 0 || rate > 1000 {
			return 0, "", fmt.Errorf("invalid JTFRAME_RATE %q for %s", value, core)
		}
		milliHz := uint32(math.Floor(rate*1000 + 1e-9))
		if milliHz == 0 {
			return 0, "", fmt.Errorf("JTFRAME_RATE %q is below millihertz precision", value)
		}
		return milliHz, "JTFRAME_RATE", nil
	}
	rate, err := mameRefreshFromSource(source, setname)
	if err != nil {
		return 0, "", err
	}
	milliHz := uint32(math.Floor(rate*1000 + 1e-9))
	if milliHz == 0 {
		return 0, "", fmt.Errorf("MAME refresh for %s is below millihertz precision", setname)
	}
	return milliHz, "doc/mame.xml", nil
}

func mameRefreshFromSource(source, setname string) (float64, error) {
	for _, path := range []string{filepath.Join(source, "doc", "custom.xml"), filepath.Join(source, "doc", "mame.xml")} {
		refresh, found, err := mameMachineRefresh(path, setname)
		if err != nil && !os.IsNotExist(err) {
			return 0, err
		}
		if found {
			return refresh, nil
		}
	}
	return 0, fmt.Errorf("no raster refresh metadata found for %s in doc/custom.xml or doc/mame.xml", setname)
}

func mameMachineRefresh(path, setname string) (float64, bool, error) {
	file, err := os.Open(path)
	if err != nil {
		return 0, false, err
	}
	defer file.Close()
	decoder := xml.NewDecoder(file)
	for {
		token, decodeErr := decoder.Token()
		if decodeErr == io.EOF {
			return 0, false, nil
		}
		if decodeErr != nil {
			return 0, false, fmt.Errorf("parse MAME refresh metadata %s: %w", path, decodeErr)
		}
		start, ok := token.(xml.StartElement)
		if !ok || start.Name.Local != "machine" || attrValue(start.Attr, "name") != setname {
			continue
		}
		var machine struct {
			Displays []struct {
				Type    string `xml:"type,attr"`
				Refresh string `xml:"refresh,attr"`
			} `xml:"display"`
		}
		if err := decoder.DecodeElement(&machine, &start); err != nil {
			return 0, false, fmt.Errorf("decode MAME refresh metadata %s/%s: %w", path, setname, err)
		}
		var refresh float64
		for _, display := range machine.Displays {
			if display.Type == "vector" {
				continue
			}
			if refresh != 0 {
				return 0, false, fmt.Errorf("multiple raster displays for %s in %s", setname, path)
			}
			refresh, err = strconv.ParseFloat(display.Refresh, 64)
			if err != nil || math.IsNaN(refresh) || math.IsInf(refresh, 0) || refresh <= 0 || refresh > 1000 {
				return 0, false, fmt.Errorf("invalid raster refresh %q for %s in %s", display.Refresh, setname, path)
			}
		}
		return refresh, refresh > 0, nil
	}
}
