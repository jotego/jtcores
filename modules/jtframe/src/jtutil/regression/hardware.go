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
	ControlHelper         string
	CabPacker             string
	CabCache              string
	JTFrame               string
	PendingUploadDirsPath string
	Curl                  string
	Netrc                 string
	Timeout               time.Duration
	Logger                func(string)
	core_dir string
	core_rbf_name string
	core_rbf_sha string
	core_rbf_ready bool
	core_rbf_owned bool
	core_releasing bool
}

func (h *FTPHardware) Load(game GameSpec) (info LoadInfo, load_error error) {
	if h.Host == "" { return info, fmt.Errorf("board host must be configured") }
	if len(game.ROMs)==0 { return info, fmt.Errorf("game %s needs ARC, RBF and at least one ROM file",game.Setname) }
	if h.Curl == "" { h.Curl = "curl" }
	paths := append([]string{game.ARC,game.RBF},game.ROMs...)
	seen := map[string]bool{}
	for _, path := range paths {
		name := filepath.Base(path)
		file, err := os.Stat(path)
		if err!=nil || !file.Mode().IsRegular() || file.Size()==0 { return info, fmt.Errorf("upload file is missing or empty: %s",name) }
		if !safeComponent(name) || seen[name] { return info, fmt.Errorf("unsafe or duplicate upload basename %q",name) }
		seen[name] = true
	}
	rbf_name := filepath.Base(game.RBF)
	if len(rbf_name)>32 { return info, fmt.Errorf("RBF basename exceeds firmware's 32-byte limit") }
	rbf_sha, err := FileSHA256(game.RBF)
	if err!=nil { return info, err }
	if h.core_releasing { return info, fmt.Errorf("previous core release is incomplete") }
	if h.core_dir!="" && (h.core_rbf_name!=rbf_name || h.core_rbf_sha!=rbf_sha) { return info, fmt.Errorf("active core RBF identity changed; release the core before loading another RBF") }
	if h.core_dir=="" {
		var nonce [12]byte
		if _,err=rand.Read(nonce[:]);err!=nil { return info, err }
		h.core_dir = "/JTREG_"+hex.EncodeToString(nonce[:])
		h.core_rbf_name,h.core_rbf_sha = rbf_name,rbf_sha
	}
	if err=h.queuePendingUploadDir(h.core_dir);err!=nil { return info, fmt.Errorf("record core namespace ownership: %w",err) }
	if h.core_rbf_ready {
		info.RBFReused = true
		info.Transfers = append(info.Transfers,TransferInfo{Name:rbf_name,Role:"rbf",Reused:true})
	} else {
		h.core_rbf_owned = true
		transfer, upload_error := h.upload_core_file(game.RBF,"rbf")
		info.Transfers = append(info.Transfers,transfer)
		if upload_error!=nil { return info, upload_error }
		verified_sha, hash_error := FileSHA256(game.RBF)
		if hash_error!=nil || verified_sha!=h.core_rbf_sha { return info, fmt.Errorf("RBF source changed during upload") }
		h.core_rbf_ready = true
	}
	uploads := h.gameUploadFiles(game)
	for _, upload := range uploads {
		info.RemoteFiles = append(info.RemoteFiles, upload.remote)
		transfer, upload_error := h.upload_file_to(upload.local, upload.role, upload.remote)
		info.Transfers = append(info.Transfers,transfer)
		if upload_error!=nil { return info, upload_error }
	}
	args := []string{"--silent","--show-error","--fail","--quote","SITE LOAD "+h.core_dir+"/"+filepath.Base(game.ARC)}
	args = h.ftp_credentials(args)
	args = append(args,"ftp://"+h.Host+"/")
	started := time.Now()
	out, err := h.run(h.Curl,args,10*time.Minute)
	info.SiteLoadDuration = time.Since(started)
	if err!=nil { return info, fmt.Errorf("FTP core load: %w: %s",err,out) }
	// Every game still gets SITE LOAD and a fresh FPGA configuration. Only its
	// network RBF transfer is shared; ARC and ROM files remain per-game owned.
	if err = h.cleanupPendingUploadDirs(); err!=nil && h.Logger!=nil { h.Logger("deferred upload cleanup will retry later: "+err.Error()) }
	return info,nil
}

func (h *FTPHardware) upload_core_file(path, role string) (TransferInfo,error) {
	return h.upload_file_to(path, role, h.core_dir+"/"+filepath.Base(path))
}

func (h *FTPHardware) upload_file_to(path, role, remote string) (TransferInfo,error) {
	info := TransferInfo{Name:filepath.Base(remote),Role:role}
	file,err := os.Stat(path)
	if err!=nil { info.Error=err.Error(); return info,err }
	info.Bytes = file.Size()
	if err=h.queuePendingUploadDir(remote);err!=nil { info.Error=err.Error();return info,fmt.Errorf("record upload ownership: %w",err) }
	args := []string{"--silent","--show-error","--fail","--ftp-create-dirs","--upload-file",path}
	args = h.ftp_credentials(args)
	args = append(args,"ftp://"+h.Host+remote)
	started := time.Now()
	out,err := h.run(h.Curl,args,2*time.Minute)
	info.Duration = time.Since(started)
	info.Uploaded = err==nil
	if err!=nil { info.Error=err.Error(); return info,fmt.Errorf("FTP upload %s: %w: %s",info.Name,err,out) }
	return info,nil
}

func (h *FTPHardware) ftp_credentials(args []string) []string {
	if h.Netrc!="" { return append(args,"--netrc-file",h.Netrc) }
	return append(args,"--netrc")
}

// ReleaseCore owns the shared RBF's lifetime. Directory removal is deferred
// until a successful load changes the firmware's current ARC directory.
func (h *FTPHardware) ReleaseCore() error {
	if h.core_dir=="" { return nil }
	h.core_rbf_ready = false
	h.core_releasing = true
	var failures []string
	if h.core_rbf_owned {
		if err:=h.Cleanup([]string{h.core_dir+"/"+h.core_rbf_name});err!=nil { failures=append(failures,err.Error()) } else { h.core_rbf_owned=false }
	}
	if err:=h.queuePendingUploadDir(h.core_dir);err!=nil { failures=append(failures,err.Error()) }
	if len(failures)>0 { return fmt.Errorf("release core upload: %s",strings.Join(failures,"; ")) }
	h.core_dir,h.core_rbf_name,h.core_rbf_sha = "","",""
	h.core_releasing = false
	return nil
}

func (h *FTPHardware) Run(game GameSpec, cab, captureDir string) (RunInfo, error) {
	if h.Host == "" || h.ControlHelper == "" {
		return RunInfo{}, fmt.Errorf("board host and ftp-control helper must be configured")
	}
	if h.CabPacker == "" {
		return RunInfo{}, fmt.Errorf("CAB packer must be configured in the project preparation cache")
	}
	if e := os.MkdirAll(captureDir, 0750); e != nil {
		return RunInfo{}, e
	}
	report := filepath.Join(filepath.Dir(captureDir), "ftp-report.json")
	args := []string{h.Host, "cab", cab, "--frames", fmt.Sprint(game.Profile.Video), "--cab-frame-budget", fmt.Sprint(game.Profile.Video), "--source-cab", game.SourceCAB,
		"--capture-every", "100", "--video-step", "16", "--report", report, "--video-dir", captureDir, "--cab-packer", h.CabPacker}
	args = append(args,"--first-frame",fmt.Sprint(firstCaptureFrame(game.Profile.Startup)))
	started := time.Now()
	out, e := h.run(h.ControlHelper, args, timeout_for_frames(game.Profile.Video, h.Timeout))
	if record_error := os.WriteFile(filepath.Join(filepath.Dir(captureDir), "helper-progress.log"), []byte(out), 0640); record_error != nil {
		if e == nil { e = record_error } else { e = fmt.Errorf("%w; record helper output: %v", e, record_error) }
	}
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
	listings := map[string][]string{}
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
		if e!=nil && ownedUploadFile(name) { if absent,check_error:=h.remote_load_path_absent(name,listings);check_error==nil && absent { e=nil } }
		if e != nil {
			failures = append(failures, name+": "+e.Error()+" "+out)
			if ownedUploadFile(name) {
				if queue_error:=h.queuePendingUploadDir(name);queue_error!=nil { failures=append(failures,"persist failed file deletion: "+queue_error.Error()) }
			}
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
	if !ownedLoadDir(name) && !ownedUploadFile(name) {
		return fmt.Errorf("invalid upload cleanup ownership path %q", name)
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
	if h.PendingUploadDirsPath=="" { return nil }
	data,err := os.ReadFile(h.PendingUploadDirsPath)
	if os.IsNotExist(err) { return nil }; if err!=nil { return err }
	var pending []string
	if err=json.Unmarshal(data,&pending);err!=nil { return fmt.Errorf("invalid pending upload cleanup ledger: %w",err) }
	failures := map[string]string{}
	active := map[string]bool{}
	removed_dirs := map[string]bool{}
	listings := map[string][]string{}
	for _,files := range []bool{true,false} {
		for _,name := range pending {
			is_file := ownedUploadFile(name)
			if !is_file && !ownedLoadDir(name) { failures[name]="unsafe path "+name;continue }
			if is_file!=files { continue }
			if name==h.core_dir || filepath.Dir(name)==h.core_dir { active[name]=true;continue }
			verb := "RMD ";if is_file { verb="DELE " }
			args:=h.ftp_credentials([]string{"--silent","--show-error","--fail","--quote",verb+name})
			out,call_error:=h.run(h.Curl,append(args,"ftp://"+h.Host+"/"),20*time.Second)
			if call_error!=nil { if absent,check_error:=h.remote_load_path_absent(name,listings);check_error==nil && absent { call_error=nil } }
			if call_error!=nil { failures[name]=call_error.Error()+" "+out } else if !is_file { removed_dirs[name]=true }
		}
	}
	remaining:=make([]string,0,len(pending))
	messages:=make([]string,0)
	for _,name:=range pending {
		if removed_dirs[filepath.Dir(name)] { continue }
		if active[name] { remaining=append(remaining,name);continue }
		if message,failed:=failures[name];failed { remaining=append(remaining,name);messages=append(messages,name+": "+message) }
	}
	if err=writePendingUploadDirs(h.PendingUploadDirsPath,remaining);err!=nil { messages=append(messages,"persist ledger: "+err.Error()) }
	if len(messages)>0 { return fmt.Errorf("%s",strings.Join(messages,"; ")) }
	return nil
}

// A failed delete is idempotent only when a successful parent listing proves
// absence. Permission, busy, transport, and listing errors remain failures.
func (h *FTPHardware) remote_load_path_absent(name string, listings map[string][]string) (bool,error) {
	parent := filepath.Dir(name)
	if parent!="/" {
		parent_missing,err:=h.remote_load_path_absent(parent,listings)
		if err!=nil || parent_missing { return parent_missing,err }
	}
	names,ok:=listings[parent]
	if !ok {
		args:=h.ftp_credentials([]string{"--silent","--show-error","--fail","--list-only"})
		out,err:=h.run(h.Curl,append(args,"ftp://"+h.Host+strings.TrimSuffix(parent,"/")+"/"),20*time.Second)
		if err!=nil { return false,err }
		for _,line:=range strings.Split(strings.TrimSuffix(out,"\n"),"\n") {
			entry:=strings.TrimSuffix(line,"\r")
			if entry=="" {continue}
			if filepath.Base(entry)!=entry || strings.ContainsAny(entry,"\\\x00") {return false,fmt.Errorf("invalid FTP name listing")}
			names=append(names,entry)
		}
		listings[parent]=names
	}
	for _,entry:=range names {if strings.EqualFold(entry,filepath.Base(name)) {return false,nil}}
	return true,nil
}

func ownedLoadFile(name string) bool {
	return ownedRemotePath(name) && ownedLoadDir(filepath.Dir(name))
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
	if ownedRemoteDir(name) || ownedVideoDir(name) || ownedRootRAM(name) {
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
	cmd.Env = append(os.Environ(), "PYTHONUNBUFFERED=1")
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
			return "", fmt.Errorf("CAB packer source and project preparation cache are required")
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
		return fmt.Errorf("CAB packer must be configured in project preparation cache")
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
	// The deadline covers upload, recording, and retrieval. Progress watchdogs
	// inside the helper remain responsible for detecting a stalled operation.
	if maximum <= 0 { maximum = 15*time.Minute }
	base := 2*time.Minute
	if maximum <= base { return maximum }
	if frames <= 0 { return base }
	per_frame := time.Second/10
	if uint64(frames) > uint64((maximum-base)/per_frame) { return maximum }
	return base + time.Duration(frames)*per_frame
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
