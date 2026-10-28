/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// FTPHardware drives the documented #166 helpers. All process calls have
// bounded deadlines; the caller supplies a host/credential file from config.
type FTPHardware struct {
	Host                  string
	LoadHelper            string
	ControlHelper         string
	CabPacker             string
	CabCache              string
	JTFrame               string
	PendingUploadDirsPath string
	Curl                  string
	Netrc                 string
	Timeout               time.Duration
	Logger                func(string)
}

func (h *FTPHardware) Load(game GameSpec) (LoadInfo, error) {
	if h.Host == "" {
		return LoadInfo{}, fmt.Errorf("board host must be configured")
	}
	paths := append([]string{game.ARC, game.RBF}, game.ROMs...)
	if len(paths) < 3 {
		return LoadInfo{}, fmt.Errorf("game %s needs ARC, RBF and at least one ROM file", game.Setname)
	}
	if h.Curl == "" {
		h.Curl = "curl"
	}
	var nonce [12]byte
	if _, e := rand.Read(nonce[:]); e != nil {
		return LoadInfo{}, e
	}
	dir := "JTREG_" + hex.EncodeToString(nonce[:])
	remote := make([]string, 0, len(paths)+1)
	for _, filename := range paths {
		base := filepath.Base(filename)
		remotePath := "/" + dir + "/" + base
		remote = append(remote, remotePath)
		args := []string{"--silent", "--show-error", "--fail", "--ftp-create-dirs", "--upload-file", filename}
		if h.Netrc != "" {
			args = append(args, "--netrc-file", h.Netrc)
		} else {
			args = append(args, "--netrc")
		}
		args = append(args, "ftp://"+h.Host+remotePath)
		out, e := h.run(h.Curl, args, 2*time.Minute)
		if e != nil {
			remote = append(remote, "/"+dir)
			return LoadInfo{RemoteFiles: remote}, fmt.Errorf("FTP upload %s: %w: %s", base, e, out)
		}
	}
	remote = append(remote, "/"+dir)
	args := []string{"--silent", "--show-error", "--fail", "--quote", "SITE LOAD /" + dir + "/" + filepath.Base(game.ARC)}
	if h.Netrc != "" {
		args = append(args, "--netrc-file", h.Netrc)
	} else {
		args = append(args, "--netrc")
	}
	args = append(args, "ftp://"+h.Host+"/")
	out, e := h.run(h.Curl, args, 10*time.Minute)
	if e != nil {
		return LoadInfo{RemoteFiles: remote}, fmt.Errorf("FTP core load: %w: %s", e, out)
	}
	// Firmware sets FatFs' current directory to the just-loaded ARC's parent.
	// Only after this successful load may older upload namespaces be removed.
	if err := h.cleanupPendingUploadDirs(); err != nil && h.Logger != nil {
		h.Logger("deferred upload directory cleanup will retry later: " + err.Error())
	}
	return LoadInfo{RemoteFiles: remote}, nil
}

func (h *FTPHardware) Run(game GameSpec, cab, captureDir string) (RunInfo, error) {
	if h.Host == "" || h.ControlHelper == "" {
		return RunInfo{}, fmt.Errorf("board host and ftp-control helper must be configured")
	}
	if h.CabPacker == "" {
		return RunInfo{}, fmt.Errorf("CAB packer must be configured under the regression cache")
	}
	if e := os.MkdirAll(captureDir, 0750); e != nil {
		return RunInfo{}, e
	}
	report := filepath.Join(filepath.Dir(captureDir), "ftp-report.json")
	args := []string{h.Host, "cab", cab, "--frames", fmt.Sprint(game.Profile.Video), "--cab-frame-budget", fmt.Sprint(game.Profile.Video), "--source-cab", game.SourceCAB,
		"--capture-every", "100", "--video-step", "16", "--report", report, "--video-dir", captureDir, "--cab-packer", h.CabPacker}
	started := time.Now()
	out, e := h.run(h.ControlHelper, args, timeout_for_frames(game.Profile.Video, h.Timeout))
	remote, ownershipErr := ownedCABPaths(report)
	if e != nil {
		return RunInfo{Report: report, CaptureDir: captureDir, Duration: time.Since(started), RemoteFiles: remote}, fmt.Errorf("CAB/video execution: %w: %s", e, out)
	}
	if ownershipErr != nil {
		return RunInfo{Report: report, CaptureDir: captureDir, Duration: time.Since(started), RemoteFiles: remote}, ownershipErr
	}
	if len(remote) < 2 {
		return RunInfo{Report: report, CaptureDir: captureDir, Duration: time.Since(started)}, fmt.Errorf("capture helper completed without explicit run-owned CAB upload metadata")
	}
	// The helper creates a run_* child under the selected video-dir.
	entries, e := os.ReadDir(captureDir)
	if e != nil {
		return RunInfo{}, e
	}
	var runDir string
	for _, entry := range entries {
		if entry.IsDir() && strings.HasPrefix(entry.Name(), "run_") {
			if runDir != "" {
				return RunInfo{}, fmt.Errorf("multiple capture runs in %s", captureDir)
			}
			runDir = filepath.Join(captureDir, entry.Name())
		}
	}
	if runDir == "" {
		return RunInfo{Report: report, Duration: time.Since(started)}, fmt.Errorf("capture client produced no run directory")
	}
	var remoteVideoDir string
	if raw, readErr := os.ReadFile(report); readErr == nil {
		var parsed map[string]any
		if json.Unmarshal(raw, &parsed) == nil {
			if retrieved, ok := parsed["video_retrieved"].(bool); ok && retrieved {
				if videoDir, ok := parsed["video_remote_dir"].(string); ok && ownedVideoDir(videoDir) {
					remoteVideoDir = videoDir
				}
			}
		}
	}
	return RunInfo{Report: report, CaptureDir: runDir, Duration: time.Since(started), RemoteFiles: remote, RemoteVideoDir: remoteVideoDir}, nil
}

func (h *FTPHardware) Cleanup(remote []string) error {
	if len(remote) == 0 {
		return nil
	}
	if h.Curl == "" {
		h.Curl = "curl"
	}
	var failures []string
	owned := make([]string, 0, len(remote))
	for _, name := range remote {
		if !ownedRemotePath(name) {
			failures = append(failures, "unsafe remote path "+name)
			continue
		}
		owned = append(owned, name)
	}
	for _, name := range owned {
		if ownedRemoteDir(name) || ownedVideoDir(name) {
			continue
		}
		args := []string{"--silent", "--show-error", "--fail", "--quote", "DELE " + name}
		if h.Netrc != "" {
			args = append(args, "--netrc-file", h.Netrc)
		} else {
			args = append(args, "--netrc")
		}
		args = append(args, "ftp://"+h.Host+"/")
		out, e := h.run(h.Curl, args, 20*time.Second)
		if e != nil {
			failures = append(failures, name+": "+e.Error()+" "+out)
		}
	}
	for _, name := range owned {
		if ownedLoadDir(name) {
			if err := h.queuePendingUploadDir(name); err != nil {
				failures = append(failures, name+": cannot persist deferred cleanup: "+err.Error())
			}
			continue
		}
		if ownedVideoDir(name) {
			if e := h.cleanupVideoDir(name); e != nil {
				failures = append(failures, name+": "+e.Error())
			}
			continue
		}
		if !ownedRemoteDir(name) {
			continue
		}
		args := []string{"--silent", "--show-error", "--fail", "--quote", "RMD " + name}
		if h.Netrc != "" {
			args = append(args, "--netrc-file", h.Netrc)
		} else {
			args = append(args, "--netrc")
		}
		args = append(args, "ftp://"+h.Host+"/")
		out, e := h.run(h.Curl, args, 20*time.Second)
		if e != nil {
			failures = append(failures, name+": "+e.Error()+" "+out)
		}
	}
	if len(failures) > 0 {
		return fmt.Errorf("FTP cleanup: %s", strings.Join(failures, "; "))
	}
	return nil
}

func (h *FTPHardware) queuePendingUploadDir(name string) error {
	if !ownedLoadDir(name) {
		return fmt.Errorf("invalid upload directory ownership path %q", name)
	}
	if h.PendingUploadDirsPath == "" {
		return fmt.Errorf("pending upload directory ledger is not configured")
	}
	var pending []string
	if data, err := os.ReadFile(h.PendingUploadDirsPath); err == nil {
		if err = json.Unmarshal(data, &pending); err != nil {
			return fmt.Errorf("invalid pending upload directory ledger: %w", err)
		}
	} else if !os.IsNotExist(err) {
		return err
	}
	for _, existing := range pending {
		if existing == name {
			return nil
		}
	}
	pending = append(pending, name)
	return writePendingUploadDirs(h.PendingUploadDirsPath, pending)
}

func (h *FTPHardware) cleanupPendingUploadDirs() error {
	if h.PendingUploadDirsPath == "" {
		return nil
	}
	data, err := os.ReadFile(h.PendingUploadDirsPath)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	var pending []string
	if err = json.Unmarshal(data, &pending); err != nil {
		return fmt.Errorf("invalid pending upload directory ledger: %w", err)
	}
	remaining := make([]string, 0, len(pending))
	var failures []string
	for _, name := range pending {
		if !ownedLoadDir(name) {
			failures = append(failures, "unsafe path "+name)
			remaining = append(remaining, name)
			continue
		}
		args := []string{"--silent", "--show-error", "--fail", "--quote", "RMD " + name}
		if h.Netrc != "" {
			args = append(args, "--netrc-file", h.Netrc)
		} else {
			args = append(args, "--netrc")
		}
		args = append(args, "ftp://"+h.Host+"/")
		out, callErr := h.run(h.Curl, args, 20*time.Second)
		if callErr != nil {
			failures = append(failures, name+": "+callErr.Error()+" "+out)
			remaining = append(remaining, name)
		}
	}
	if err = writePendingUploadDirs(h.PendingUploadDirsPath, remaining); err != nil {
		failures = append(failures, "persist ledger: "+err.Error())
	}
	if len(failures) != 0 {
		return fmt.Errorf("%s", strings.Join(failures, "; "))
	}
	return nil
}

func writePendingUploadDirs(filename string, pending []string) error {
	if err := os.MkdirAll(filepath.Dir(filename), 0750); err != nil {
		return err
	}
	data, err := json.MarshalIndent(pending, "", "  ")
	if err != nil {
		return err
	}
	return atomic_write(filename, append(data, '\n'), 0640)
}

func ownedRemotePath(name string) bool {
	if strings.Contains(name, "..") || strings.Contains(name, "\\") || strings.ContainsAny(name, "\r\n\x00") {
		return false
	}
	if ownedRemoteDir(name) || ownedVideoDir(name) {
		return true
	}
	parts := strings.Split(name, "/")
	if len(parts) != 3 || parts[0] != "" {
		return false
	}
	if ownedCABDir("/" + parts[1]) {
		return ownedCABBasename(parts[2])
	}
	return ownedLoadDir("/"+parts[1]) && parts[2] != "" && filepath.Base(parts[2]) == parts[2]
}

func ownedRemoteDir(name string) bool {
	return ownedCABDir(name) || ownedLoadDir(name)
}

func ownedCABDir(name string) bool {
	if strings.Count(name, "/") != 1 || !strings.HasPrefix(name, "/REG169_") || len(name) != len("/REG169_")+16 {
		return false
	}
	for _, c := range name[len("/REG169_"):] {
		if !(c >= '0' && c <= '9' || c >= 'a' && c <= 'f') {
			return false
		}
	}
	return true
}

func ownedLoadDir(name string) bool {
	if strings.Count(name, "/") != 1 || !strings.HasPrefix(name, "/JTREG_") || len(name) != len("/JTREG_")+24 {
		return false
	}
	for _, c := range name[len("/JTREG_"):] {
		if !(c >= '0' && c <= '9' || c >= 'a' && c <= 'f') {
			return false
		}
	}
	return true
}

func ownedVideoDir(name string) bool {
	parts := strings.Split(name, "/")
	return len(parts) == 4 && parts[0] == "" && parts[1] == "video" && safeComponent(parts[2]) && validVideoRunName(parts[3])
}

func (h *FTPHardware) cleanupVideoDir(dir string) error {
	listArgs := []string{"--silent", "--show-error", "--fail", "--list-only"}
	if h.Netrc != "" {
		listArgs = append(listArgs, "--netrc-file", h.Netrc)
	} else {
		listArgs = append(listArgs, "--netrc")
	}
	listArgs = append(listArgs, "ftp://"+h.Host+dir+"/")
	listing, err := h.run(h.Curl, listArgs, 30*time.Second)
	if err != nil {
		return fmt.Errorf("list run-owned video directory: %w: %s", err, listing)
	}
	for _, line := range strings.Split(listing, "\n") {
		name := strings.TrimSpace(line)
		if name == "" {
			continue
		}
		if !ownedVideoFilename(name) {
			return fmt.Errorf("unexpected file in run-owned video directory: %q", name)
		}
		args := []string{"--silent", "--show-error", "--fail", "--quote", "DELE " + dir + "/" + name}
		if h.Netrc != "" {
			args = append(args, "--netrc-file", h.Netrc)
		} else {
			args = append(args, "--netrc")
		}
		args = append(args, "ftp://"+h.Host+"/")
		if out, e := h.run(h.Curl, args, 20*time.Second); e != nil {
			return fmt.Errorf("delete video file %s: %w: %s", name, e, out)
		}
	}
	args := []string{"--silent", "--show-error", "--fail", "--quote", "RMD " + dir}
	if h.Netrc != "" {
		args = append(args, "--netrc-file", h.Netrc)
	} else {
		args = append(args, "--netrc")
	}
	args = append(args, "ftp://"+h.Host+"/")
	if out, e := h.run(h.Curl, args, 20*time.Second); e != nil {
		return fmt.Errorf("remove video directory: %w: %s", e, out)
	}
	return nil
}

func ownedVideoFilename(name string) bool {
	if name == "index.jsonl" || name == "ROMPATH.TXT" {
		return true
	}
	if !strings.HasPrefix(name, "frame_") || !strings.HasSuffix(name, ".raw") {
		return false
	}
	frame := strings.TrimSuffix(strings.TrimPrefix(name, "frame_"), ".raw")
	if frame == "" {
		return false
	}
	for _, c := range frame {
		if c < '0' || c > '9' {
			return false
		}
	}
	return filepath.Base(name) == name
}

func ownedCABBasename(name string) bool {
	if len(name) != len("CAB")+16+len(".JTC") || !strings.HasPrefix(name, "CAB") || !strings.HasSuffix(name, ".JTC") {
		return false
	}
	for _, c := range name[3:19] {
		if !(c >= '0' && c <= '9' || c >= 'a' && c <= 'f') {
			return false
		}
	}
	return true
}

// ownedCABPaths reads both the helper's pre-upload sidecar and final report.
// The sidecar is deliberately consulted first because it is written before
// STOR, so partial runs can still clean exactly the unique path they claimed.
func ownedCABPaths(reportPath string) ([]string, error) {
	paths := make([]string, 0, 2)
	var contractErr error
	byDir := make(map[string]string)
	for _, filename := range []string{reportPath + ".upload.json", reportPath} {
		data, err := os.ReadFile(filename)
		if err != nil {
			if !os.IsNotExist(err) {
				contractErr = err
			}
			continue
		}
		var payload map[string]any
		if err = json.Unmarshal(data, &payload); err != nil {
			contractErr = fmt.Errorf("invalid CAB ownership metadata %s: %w", filename, err)
			continue
		}
		dir, _ := payload["remote_cab_dir"].(string)
		path, _ := payload["remote_cab_path"].(string)
		if dir == "" && path == "" {
			continue
		}
		if !ownedCABDir(dir) || !ownedRemotePath(path) || filepath.Dir(path) != dir || !ownedCABBasename(filepath.Base(path)) {
			contractErr = fmt.Errorf("unsafe or incomplete CAB ownership metadata in %s", filename)
			continue
		}
		digest, ok := payload["packed_sha256"].(string)
		if !ok || len(digest) != 64 || !strings.HasPrefix(digest, filepath.Base(path)[3:19]) {
			contractErr = fmt.Errorf("CAB path digest does not match packed content metadata in %s", filename)
			continue
		}
		if prior, exists := byDir[dir]; exists && prior != path {
			contractErr = fmt.Errorf("CAB ownership metadata disagrees about upload path in %s", filename)
			continue
		}
		byDir[dir] = path
		paths = append(paths, path, dir)
	}
	unique := paths[:0]
	seen := make(map[string]bool)
	for _, path := range paths {
		if !seen[path] {
			seen[path] = true
			unique = append(unique, path)
		}
	}
	if contractErr != nil {
		return unique, contractErr
	}
	return unique, nil
}

func (h *FTPHardware) run(program string, args []string, timeout time.Duration) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	cmd := exec.CommandContext(ctx, program, args...)
	cmd.Env = os.Environ()
	if h.Netrc != "" {
		cmd.Env = append(cmd.Env, "FTP_NETRC="+h.Netrc)
	}
	if h.CabCache != "" {
		cmd.Env = append(cmd.Env, "JTFRAME_CAB_CACHE="+h.CabCache)
	}
	if h.JTFrame != "" {
		cmd.Env = append(cmd.Env, "JTFRAME="+h.JTFrame)
	}
	var output bytes.Buffer
	cmd.Stdout = &output
	cmd.Stderr = &output
	e := cmd.Run()
	if ctx.Err() == context.DeadlineExceeded {
		return output.String(), fmt.Errorf("timed out after %s", timeout)
	}
	if e != nil {
		return output.String(), e
	}
	if h.Logger != nil && output.Len() > 0 {
		h.Logger(output.String())
	}
	return output.String(), nil
}

// PrepareCabPacker builds the source-pinned native exporter into the regression
// cache and returns its content digest for the test-definition identity.
func (h *FTPHardware) PrepareCabPacker(sourceRoot string) (string, error) {
	if h.CabPacker == "" {
		return "", fmt.Errorf("CAB packer executable must be configured")
	}
	if filepath.Base(h.CabPacker) == "jtframe-cab-pack" {
		if h.CabCache == "" || h.JTFrame == "" || sourceRoot == "" {
			return "", fmt.Errorf("CAB packer source and regression cache are required")
		}
		if err := os.MkdirAll(h.CabCache, 0750); err != nil {
			return "", err
		}
		out, err := h.run(h.CabPacker, nil, 2*time.Minute)
		if err == nil || !strings.Contains(out, "usage: jtframe-cab-pack") {
			return "", fmt.Errorf("could not prepare CAB exporter: %v: %s", err, out)
		}
		exporter := filepath.Join(h.CabCache, "cabinet_pack")
		if !regularNonempty(exporter) {
			return "", fmt.Errorf("CAB exporter was not built at %s", exporter)
		}
		h.CabPacker = exporter // invoke the pinned binary directly after its build
	}
	if !regularNonempty(h.CabPacker) {
		return "", fmt.Errorf("CAB exporter is unavailable: %s", h.CabPacker)
	}
	return fileSHA256(h.CabPacker)
}

func (h *FTPHardware) Healthy() error {
	if h.ControlHelper == "" {
		return fmt.Errorf("ftp-control helper is not configured")
	}
	var last error
	for i := 0; i < 2; i++ {
		if _, e := h.run(h.ControlHelper, []string{h.Host, "status"}, 10*time.Second); e == nil {
			return nil
		} else {
			last = e
			time.Sleep(time.Second)
		}
	}
	return last
}

func (h *FTPHardware) Preflight() error {
	if h.Host == "" {
		return fmt.Errorf("board host must be configured")
	}
	if h.ControlHelper == "" {
		return fmt.Errorf("ftp-control helper must be configured")
	}
	if h.CabPacker == "" {
		return fmt.Errorf("CAB packer must be configured under regression cache")
	}
	if info, e := os.Stat(h.ControlHelper); e != nil || !info.Mode().IsRegular() {
		return fmt.Errorf("ftp-control helper is unavailable: %s", h.ControlHelper)
	}
	if info, e := os.Stat(h.CabPacker); e != nil || !info.Mode().IsRegular() || info.Mode()&0111 == 0 {
		return fmt.Errorf("CAB packer is unavailable or not executable: %s", h.CabPacker)
	}
	curl := h.Curl
	if curl == "" {
		curl = "curl"
	}
	if _, e := exec.LookPath(curl); e != nil {
		return fmt.Errorf("curl is unavailable: %w", e)
	}
	if h.Netrc != "" {
		info, e := os.Stat(h.Netrc)
		if e != nil || !info.Mode().IsRegular() {
			return fmt.Errorf("netrc credentials file is unavailable: %s", h.Netrc)
		}
		if info.Mode().Perm()&0077 != 0 {
			return fmt.Errorf("netrc file permissions must be 0600: %s", h.Netrc)
		}
	}
	return h.Healthy()
}

func timeout_for_frames(frames int, maximum time.Duration) time.Duration {
	// Estimate 20 frames/second; hard-bound an operation to five minutes.
	computed := time.Duration(frames) * time.Second / 20
	if computed < 2*time.Minute {
		computed = 2 * time.Minute
	}
	if maximum > 0 && computed > maximum {
		return maximum
	}
	if computed > 5*time.Minute {
		return 5 * time.Minute
	}
	return computed
}

func ParseCaptureReport(filename string) (map[string]any, error) {
	data, e := os.ReadFile(filename)
	if e != nil {
		return nil, e
	}
	var report map[string]any
	if e = json.Unmarshal(data, &report); e != nil {
		return nil, fmt.Errorf("invalid FTP capture report: %w", e)
	}
	switch status := report["status"].(type) {
	case map[string]any:
		if fmt.Sprint(status["STATE"]) != "3" {
			return nil, fmt.Errorf("FTP CAB report did not complete (state %v)", status["STATE"])
		}
		if !zeroStatusInputs(status["INPUTS"]) {
			return nil, fmt.Errorf("FTP CAB completion did not release inputs (INPUTS=%v)", status["INPUTS"])
		}
	case string:
		if status != "complete" && status != "success" {
			return nil, fmt.Errorf("FTP capture report status is %q", status)
		}
	default:
		return nil, fmt.Errorf("FTP capture report has invalid status %T", report["status"])
	}
	return report, nil
}

func zeroStatusInputs(value any) bool {
	switch v := value.(type) {
	case string:
		n, err := strconv.ParseUint(strings.TrimPrefix(strings.ToLower(v), "0x"), 16, 32)
		return err == nil && n == 0
	case float64:
		return v == 0
	case int:
		return v == 0
	default:
		return false
	}
}
