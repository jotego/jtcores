/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

func TestResolveProfileDefaultsNumericSetnameAndOverride(t *testing.T) {
	root := t.TempDir()
	if e := os.MkdirAll(filepath.Join(root, "cores", "arcade", "cfg"), 0755); e != nil {
		t.Fatal(e)
	}
	global := filepath.Join(root, "defaults.yaml")
	if e := os.WriteFile(global, []byte("video: 4000\nstart-up: 500\n"), 0600); e != nil {
		t.Fatal(e)
	}
	local := filepath.Join(root, "cores", "arcade", "cfg", "reg.yaml")
	if e := os.WriteFile(local, []byte("1941:\n  inputs: ../game/b1.cab\n  video: 2200\n  dipsw: 7\n"), 0600); e != nil {
		t.Fatal(e)
	}
	profile, e := ResolveProfile(global, root, "arcade", "1941")
	if e != nil {
		t.Fatal(e)
	}
	if profile.Video != 2200 || profile.Startup != 500 || profile.Inputs != "../game/b1.cab" || profile.Options["dipsw"] != 7 {
		t.Fatalf("unexpected merged profile: %+v", profile)
	}
	neutral, e := ResolveProfile(global, root, "arcade", "unlisted")
	if e != nil {
		t.Fatal(e)
	}
	if neutral.Video != 4000 || neutral.Startup != 500 || neutral.Inputs != "" {
		t.Fatalf("unexpected neutral profile: %+v", neutral)
	}
}

func TestResolveProfileEmptyGameEntryUsesDefaults(t *testing.T) {
	root := t.TempDir()
	cores := filepath.Join(root, "cores", "fake", "cfg")
	if err := os.MkdirAll(cores, 0750); err != nil {
		t.Fatal(err)
	}
	global := filepath.Join(root, "global.yaml")
	local := filepath.Join(cores, "reg.yaml")
	if err := os.WriteFile(global, []byte("video: 4000\nstart-up: 500\n"), 0640); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(local, []byte("empty:\nempty_mapping: {}\nscalar: invalid\n"), 0640); err != nil {
		t.Fatal(err)
	}
	for _, set := range []string{"empty", "empty_mapping"} {
		p, err := ResolveProfile(global, root, "fake", set)
		if err != nil {
			t.Fatalf("empty entry %s: %v", set, err)
		}
		if p.Video != 4000 || p.Startup != 500 || p.Inputs != "" {
			t.Fatalf("empty entry %s did not use defaults: %+v", set, p)
		}
	}
	if _, err := ResolveProfile(global, root, "fake", "scalar"); err == nil || !strings.Contains(err.Error(), "must be a mapping") {
		t.Fatalf("non-mapping scalar must remain invalid, got %v", err)
	}
}

func TestReadCaptureSetAndCompareIgnoresStartup(t *testing.T) {
	ref := make_capture_fixture(t, []uint16{0x111, 0x222, 0x333, 0x444})
	candidate := make_capture_fixture(t, []uint16{0x111, 0x222, 0xabc, 0x444})
	refSet, e := ReadCaptureSet(ref, 400, 200, 100)
	if e != nil {
		t.Fatal(e)
	}
	candidateSet, e := ReadCaptureSet(candidate, 400, 200, 100)
	if e != nil {
		t.Fatal(e)
	}
	diffs, e := CompareCaptureSets(refSet, candidateSet, 200)
	if e != nil {
		t.Fatal(e)
	}
	if len(diffs) != 1 || diffs[0].Frame != 300 || diffs[0].Different != 1 || diffs[0].FirstPixel != 0 {
		t.Fatalf("unexpected differences: %+v", diffs)
	}
}

func TestReadCaptureSetRejectsLateAndIncompleteCapture(t *testing.T) {
	dir := make_capture_fixture(t, []uint16{1, 2})
	index := filepath.Join(dir, "index.jsonl")
	data, e := os.ReadFile(index)
	if e != nil {
		t.Fatal(e)
	}
	data = []byte(strings.Replace(string(data), `"actual":100`, `"actual":101`, 1))
	if e = os.WriteFile(index, data, 0600); e != nil {
		t.Fatal(e)
	}
	if _, e = ReadCaptureSet(dir, 200, 0, 100); e == nil || !strings.Contains(e.Error(), "arrived at frame") {
		t.Fatalf("expected late checkpoint error, got %v", e)
	}
}

func TestReadCaptureSetAllowsLateStartupCaptureAndFloorsSchedule(t *testing.T) {
	dir := make_capture_fixture(t, []uint16{0x100, 0x200, 0x300})
	index := filepath.Join(dir, "index.jsonl")
	data, e := os.ReadFile(index)
	if e != nil {
		t.Fatal(e)
	}
	data = []byte(strings.Replace(string(data), `"actual":100`, `"actual":101`, 1))
	if e = os.WriteFile(index, data, 0600); e != nil {
		t.Fatal(e)
	}
	if _, e = ReadCaptureSet(dir, 350, 100, 100); e != nil {
		t.Fatalf("late startup capture and floored schedule should validate: %v", e)
	}
}

func TestReadCaptureSetRejectsBareOrNonterminalCompleteMarker(t *testing.T) {
	dir := make_capture_fixture(t, []uint16{0x100, 0x200})
	index := filepath.Join(dir, "index.jsonl")
	data, e := os.ReadFile(index)
	if e != nil {
		t.Fatal(e)
	}
	bare := strings.Replace(string(data), `{"type":"complete","captures":2}`, `{"type":"complete"}`, 1)
	if e = os.WriteFile(index, []byte(bare), 0600); e != nil {
		t.Fatal(e)
	}
	if _, e = ReadCaptureSet(dir, 200, 0, 100); e == nil {
		t.Fatal("bare complete marker must be invalid")
	}
	data, e = os.ReadFile(index)
	if e != nil {
		t.Fatal(e)
	}
	data = append(data, []byte(`{"type":"capture"}`+"\n")...)
	if e = os.WriteFile(index, data, 0600); e != nil {
		t.Fatal(e)
	}
	if _, e = ReadCaptureSet(dir, 200, 0, 100); e == nil || !strings.Contains(e.Error(), "after complete marker") {
		t.Fatalf("expected nonterminal marker error, got %v", e)
	}
}

func TestCompleteBlackCaptureIsCollectedForDesignerReview(t *testing.T) {
	capture := make_capture_fixture(t, []uint16{0, 0})
	if _, err := ReadCaptureSet(capture, 200, 0, 100); err != nil { t.Fatalf("complete black transport rejected: %v", err) }
	game_root := t.TempDir()
	if err := PublishComplete(game_root, capture, New, nil); err != nil { t.Fatal(err) }
	entries, err := os.ReadDir(filepath.Join(game_root, "new")); if err != nil { t.Fatal(err) }
	if len(entries) != 2 { t.Fatalf("want2 collected black PNGs, got%d", len(entries)) }
	for _, entry := range entries { if entry.IsDir() || filepath.Ext(entry.Name()) != ".png" { t.Fatalf("non-PNG output %s", entry.Name()) } }
	if _, err = ReadCaptureSet(filepath.Join(game_root, "new"), 200, 0, 100); err != nil { t.Fatalf("complete black PNGs rejected: %v", err) }
	if _, err = os.Stat(filepath.Join(game_root, "ref")); !os.IsNotExist(err) { t.Fatal("collector created ref") }
}

func TestReplaceResultRecoversCrashAfterOldRename(t *testing.T) {
	root := t.TempDir()
	dest := filepath.Join(root, "fail")
	if e := os.MkdirAll(dest, 0750); e != nil {
		t.Fatal(e)
	}
	if e := os.WriteFile(filepath.Join(dest, "prior"), []byte("old"), 0600); e != nil {
		t.Fatal(e)
	}
	newCapture := filepath.Join(root, "candidate")
	if e := os.MkdirAll(newCapture, 0750); e != nil {
		t.Fatal(e)
	}
	if e := os.WriteFile(filepath.Join(newCapture, "current"), []byte("new"), 0600); e != nil {
		t.Fatal(e)
	}
	crash := errors.New("injected crash")
	if e := replace_dir_hook(newCapture, dest, func() error { return crash }); !errors.Is(e, crash) {
		t.Fatalf("got %v", e)
	}
	if _, e := os.Stat(dest); !os.IsNotExist(e) {
		t.Fatalf("expected rename window, got %v", e)
	}
	if e := recover_dir(dest); e != nil {
		t.Fatal(e)
	}
	old, e := os.ReadFile(filepath.Join(dest, "prior"))
	if e != nil || string(old) != "old" {
		t.Fatalf("old result not restored: %q %v", old, e)
	}
	if e := replace_dir(newCapture, dest); e != nil {
		t.Fatal(e)
	}
	current, e := os.ReadFile(filepath.Join(dest, "current"))
	if e != nil || string(current) != "new" {
		t.Fatalf("replacement missing: %q %v", current, e)
	}
}

func TestParseCaptureReportRequiresCompleteCABAndStrings(t *testing.T) {
	path := filepath.Join(t.TempDir(), "report.json")
	good := `{"firmware":"ATH1","frames":4000,"capture_every":100,"status":{"STATE":"3","INPUTS":"000000"}}`
	if e := os.WriteFile(path, []byte(good), 0600); e != nil {
		t.Fatal(e)
	}
	if _, e := ParseCaptureReport(path); e != nil {
		t.Fatal(e)
	}
	bad := strings.Replace(good, `"STATE":"3"`, `"STATE":"2"`, 1)
	if e := os.WriteFile(path, []byte(bad), 0600); e != nil {
		t.Fatal(e)
	}
	if _, e := ParseCaptureReport(path); e == nil {
		t.Fatal("running CAB must not validate as complete")
	}
	if e := os.WriteFile(path, []byte(strings.Replace(good, `"INPUTS":"000000"`, `"INPUTS":"000100"`, 1)), 0600); e != nil {
		t.Fatal(e)
	}
	if _, e := ParseCaptureReport(path); e == nil || !strings.Contains(e.Error(), "did not release inputs") {
		t.Fatalf("held inputs after completion must be rejected: %v", e)
	}
}

func TestOwnedCABPathsUsesFrozenHelperReportAndEarlySidecar(t *testing.T) {
	dir := t.TempDir()
	report := filepath.Join(dir, "cab-report.json")
	sidecar := `{"status":"uploading","remote_cab_dir":"/REG169_0123456789abcdef","remote_cab_path":"/REG169_0123456789abcdef/CAB0123456789abcdef.JTC","packed_sha256":"0123456789abcdef000000000000000000000000000000000000000000000000"}`
	if err := os.WriteFile(report+".upload.json", []byte(sidecar), 0600); err != nil {
		t.Fatal(err)
	}
	paths, err := ownedCABPaths(report)
	if err != nil {
		t.Fatal(err)
	}
	if len(paths) != 2 || paths[0] != "/REG169_0123456789abcdef/CAB0123456789abcdef.JTC" || paths[1] != "/REG169_0123456789abcdef" {
		t.Fatalf("unexpected early-failure cleanup ownership: %#v", paths)
	}
	if err := os.WriteFile(report, []byte(`{"remote_cab_dir":"/REG169_0123456789abcdef","remote_cab_path":"/REG169_0123456789abcdef/CAB0123456789abcdef.JTC","packed_sha256":"0123456789abcdef000000000000000000000000000000000000000000000000"}`), 0600); err != nil {
		t.Fatal(err)
	}
	paths, err = ownedCABPaths(report)
	if err != nil || len(paths) != 2 {
		t.Fatalf("final helper report path not accepted: %#v %v", paths, err)
	}
}

func TestOwnedCABPathsRejectsLegacyDigestRoot(t *testing.T) {
	if ownedRemotePath("/CAB0123456789abcdef.JTC") {
		t.Fatal("legacy digest-root CAB must never be considered owned")
	}
	if ownedRemotePath("/REG169_0123456789abcdef/other.JTC") {
		t.Fatal("unexpected CAB basename should not be considered owned")
	}
	if ownedRemotePath("/REG169_0123456789abcdef/CAB0123456789abcdef.JTC") == false {
		t.Fatal("frozen helper's namespaced CAB path must be recognized")
	}
}

func TestVideoCaptureOwnershipContract(t *testing.T) {
	if !validVideoRemoteDir("/video/higemaru/run_000184af_00000001") {
		t.Fatal("pilot video directory should be accepted")
	}
	if !ownedRemotePath("/video/higemaru/run_000184af_00000001") {
		t.Fatal("verified report video run should be eligible for owned cleanup")
	}
	for _, path := range []string{"/video/../run_000184af_00000001", "/video/game/run_bad", "/video/game/run_000184af_00000001/extra"} {
		if validVideoRemoteDir(path) {
			t.Fatalf("unsafe video directory accepted: %s", path)
		}
	}
	for _, name := range []string{"index.jsonl", "ROMPATH.TXT", "frame_000123.raw"} {
		if !ownedVideoFilename(name) {
			t.Fatalf("expected firmware video file %q to be owned", name)
		}
	}
	for _, name := range []string{"../index.jsonl", "unrelated.txt", "frame_bad.raw"} {
		if ownedVideoFilename(name) {
			t.Fatalf("unexpected video entry accepted: %q", name)
		}
	}
}

func TestLoadUploadDirectoryRemovalIsDeferredAndResumable(t *testing.T) {
	root := t.TempDir()
	logPath := filepath.Join(root, "curl.log")
	curl := filepath.Join(root, "curl")
	script := fmt.Sprintf("#!/bin/sh\nprintf '%%s\\n' \"$*\" >> %q\n", logPath)
	if err := os.WriteFile(curl, []byte(script), 0700); err != nil {
		t.Fatal(err)
	}
	ledger := filepath.Join(root, "state", "upload-directories.json")
	h := &FTPHardware{Host: "board", Curl: curl, PendingUploadDirsPath: ledger}
	dir := "/JTREG_0123456789abcdef01234567"
	if err := h.Cleanup([]string{dir + "/game.arc", dir}); err != nil {
		t.Fatal(err)
	}
	pendingData, err := os.ReadFile(ledger)
	if err != nil {
		t.Fatal(err)
	}
	var pending []string
	if err = json.Unmarshal(pendingData, &pending); err != nil || len(pending) != 1 || pending[0] != dir {
		t.Fatalf("deferred directory not persisted: %s err=%v", pendingData, err)
	}
	commands, err := os.ReadFile(logPath)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(commands), "RMD "+dir) {
		t.Fatalf("current ARC directory was removed immediately: %s", commands)
	}
	if err = h.cleanupPendingUploadDirs(); err != nil {
		t.Fatal(err)
	}
	pendingData, err = os.ReadFile(ledger)
	if err != nil {
		t.Fatal(err)
	}
	if err = json.Unmarshal(pendingData, &pending); err != nil || len(pending) != 0 {
		t.Fatalf("successful deferred cleanup was not recorded: %s err=%v", pendingData, err)
	}
	commands, err = os.ReadFile(logPath)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(commands), "RMD "+dir) {
		t.Fatalf("deferred cleanup was not attempted: %s", commands)
	}
}

func TestPNGOnlyCollectionAndDesignerPromotion(t *testing.T) {
	root := t.TempDir()
	capture := make_capture_fixture(t, []uint16{0x10, 0x20, 0x30})
	if err := PublishComplete(root, capture, New, GameMetadata{TestIdentity:"collection"}); err != nil { t.Fatal(err) }
	entries, err := os.ReadDir(filepath.Join(root,"new")); if err != nil { t.Fatal(err) }
	if len(entries)!=3 { t.Fatalf("got %d images",len(entries)) }
	for _, entry := range entries { if entry.IsDir() || filepath.Ext(entry.Name())!=".png" { t.Fatalf("non-PNG publication %s",entry.Name()) } }
	// This rename represents the designer's approval, outside the collector.
	if err = os.Rename(filepath.Join(root,"new"),filepath.Join(root,"ref")); err != nil { t.Fatal(err) }
	before, err := HashFiles(map[string]string{"frame":filepath.Join(root,"ref","frame_00000100.png")}); if err!=nil {t.Fatal(err)}
	if err = PublishComplete(root,capture,New,nil); err == nil { t.Fatal("new must refuse when reference exists") }
	if err = PublishComplete(root,capture,Fail,nil); err != nil {t.Fatal(err)}
	if err = PublishComplete(root,capture,Pass,nil); err != nil {t.Fatal(err)}
	after, _ := HashFiles(map[string]string{"frame":filepath.Join(root,"ref","frame_00000100.png")})
	if before!=after {t.Fatal("designer reference changed")}
	if _,err = os.Stat(filepath.Join(root,"fail")); !os.IsNotExist(err) {t.Fatalf("pass did not clear fail: %v",err)}
	reference,err := ReadCaptureSet(filepath.Join(root,"ref"),300,0,100); if err!=nil {t.Fatal(err)}
	candidate,err := ReadCaptureSet(capture,300,0,100); if err!=nil {t.Fatal(err)}
	diffs,err := CompareCaptureSets(reference,candidate,0); if err!=nil || len(diffs)!=0 {t.Fatalf("manual approved PNG comparison: %v %v",diffs,err)}
}

func TestTestDefinitionIncludesFirmwareAndCaptureToolIdentity(t *testing.T) {
	fixture := filepath.Join(t.TempDir(), "fixture")
	if e := os.WriteFile(fixture, []byte("fixture"), 0600); e != nil {
		t.Fatal(e)
	}
	profile := Profile{Setname: "game", Video: 4000, Startup: 500}
	base, e := TestDefinitionIdentityWithTools("core", "game", profile, nil, map[string]string{"arc": fixture}, "", "FW-A", "firmware-a", "tool-a", "rgb555")
	if e != nil {
		t.Fatal(e)
	}
	firmware, _ := TestDefinitionIdentityWithTools("core", "game", profile, nil, map[string]string{"arc": fixture}, "", "FW-A", "firmware-b", "tool-a", "rgb555")
	tool, _ := TestDefinitionIdentityWithTools("core", "game", profile, nil, map[string]string{"arc": fixture}, "", "FW-A", "firmware-a", "tool-b", "rgb555")
	if base == firmware || base == tool {
		t.Fatal("firmware or capture tool identity change was hidden")
	}
}

func TestTestDefinitionIncludesSourceCABAndPrefixBudget(t *testing.T) {
	root := t.TempDir()
	effective := filepath.Join(root, "effective.cab")
	source := filepath.Join(root, "reg.cab")
	for path, data := range map[string]string{effective: "effective script", source: "source script"} {
		if err := os.WriteFile(path, []byte(data), 0600); err != nil {
			t.Fatal(err)
		}
	}
	profile := Profile{Setname: "1942", Video: 1000, Startup: 500}
	base, err := TestDefinitionIdentityWithCapture("1942", "1942", profile, nil, nil, effective, "ATH261028", "fw-sha", "tools-sha", "rgb444", source, "prefix", 1000)
	if err != nil {
		t.Fatal(err)
	}
	budget, _ := TestDefinitionIdentityWithCapture("1942", "1942", profile, nil, nil, effective, "ATH261028", "fw-sha", "tools-sha", "rgb444", source, "prefix", 1200)
	mode, _ := TestDefinitionIdentityWithCapture("1942", "1942", profile, nil, nil, effective, "ATH261028", "fw-sha", "tools-sha", "rgb444", source, "strict", 1000)
	if base == budget || base == mode {
		t.Fatal("CAB budget or clip mode change did not change test identity")
	}
	if err = os.WriteFile(source, []byte("changed source"), 0600); err != nil {
		t.Fatal(err)
	}
	changedSource, _ := TestDefinitionIdentityWithCapture("1942", "1942", profile, nil, nil, effective, "ATH261028", "fw-sha", "tools-sha", "rgb444", source, "prefix", 1000)
	if base == changedSource {
		t.Fatal("source CAB content change did not change test identity")
	}
}

func TestWriteSummaryAndJUnitKeepOutcomesDistinct(t *testing.T) {
	dir := t.TempDir()
	summary := Summary{RunID: "run", Core: "mixed", Duration: time.Second, Games: []GameResult{
		{Core: "arcade", Setname: "pass", Outcome: Pass, Duration: time.Second},
		{Core: "arcade", Setname: "new", Outcome: New, Duration: time.Second},
		{Core: "arcade", Setname: "fail", Outcome: Fail, Message: "pixels differ"},
		{Core: "arcade", Setname: "error", Outcome: Error, Stage: "load", Message: "offline"},
		{Core: "arcade", Setname: "unsupported", Outcome: Unsupported},
		{Core: "arcade", Setname: "pending", Outcome: Pending},
	}}
	if e := WriteSummary(dir, summary); e != nil {
		t.Fatal(e)
	}
	data, e := os.ReadFile(filepath.Join(dir, "junit.xml"))
	if e != nil {
		t.Fatal(e)
	}
	xmlText := string(data)
	for _, want := range []string{`tests="5"`, `failures="1"`, `errors="1"`, `skipped="2"`, `classname="arcade"`, `missing approved reference`, `unsupported on SiDi128`} {
		if !strings.Contains(xmlText, want) {
			t.Fatalf("JUnit missing %q: %s", want, xmlText)
		}
	}
	if strings.Contains(xmlText, `name="pending"`) {
		t.Fatal("pending game must not be presented as executed")
	}
}

type fakeHardware struct {
	failLoad    bool
	failRun     string
	unavailable bool
	runs        int
}

func (f *fakeHardware) Load(g GameSpec) (LoadInfo, error) {
	if f.failLoad {
		return LoadInfo{}, errors.New("load failed")
	}
	return LoadInfo{}, nil
}
func (f *fakeHardware) Run(g GameSpec, cab, dir string) (RunInfo, error) {
	f.runs++
	if g.Setname == f.failRun {
		return RunInfo{}, errors.New("CAB failed")
	}
	return RunInfo{}, errors.New("unexpected fake run")
}
func (f *fakeHardware) Cleanup([]string) error { return nil }
func (f *fakeHardware) Healthy() error {
	if f.unavailable {
		return errors.New("MCU unreachable")
	}
	return nil
}

func makeBatch(t *testing.T, root string, hardware Hardware, games []GameSpec) *Batch {
	t.Helper()
	corePath := filepath.Join(root, "source")
	if e := os.MkdirAll(filepath.Join(corePath, "cores", "fake", "cfg"), 0750); e != nil {
		t.Fatal(e)
	}
	global := filepath.Join(root, "defaults.yaml")
	if e := os.WriteFile(global, []byte("video: 4000\nstart-up: 500\n"), 0600); e != nil {
		t.Fatal(e)
	}
	log, e := NewEventLog(filepath.Join(root, "data"), "run-attempt-1", "fake")
	if e != nil {
		t.Fatal(e)
	}
	t.Cleanup(func() { _ = log.Close() })
	statePath := filepath.Join(root, "state.json")
	return &Batch{Root: filepath.Join(root, "data"), CorePath: corePath, Core: "fake", RunID: "run-attempt-1", Build: BuildIdentity{RunID: "run", Attempt: "1", SHA: "abc"}, State: &State{RunID: "run-attempt-1", Build: BuildIdentity{RunID: "run", Attempt: "1", SHA: "abc"}, Core: "fake"}, StatePath: statePath, Log: log, Hardware: hardware, GlobalProfile: global, Games: games}
}

func TestBatchContinuesAfterGameSpecificFailure(t *testing.T) {
	root := t.TempDir()
	hardware := &fakeHardware{failRun: "broken"}
	batch := makeBatch(t, root, hardware, []GameSpec{{Setname: "broken"}, {Setname: "unsupported", Unsupported: true, UnsupportedReason: "target skip"}})
	if e := batch.Run(); e != nil {
		t.Fatal(e)
	}
	if batch.State.Games["broken"].Outcome != Error || batch.State.Games["unsupported"].Outcome != Unsupported || hardware.runs != 1 {
		t.Fatalf("unexpected isolation results %+v runs=%d", batch.State.Games, hardware.runs)
	}
}

func TestBatchRejectsNoncanonicalDIPSWOptionCase(t *testing.T) {
	root := t.TempDir()
	hardware := &fakeHardware{failLoad: true}
	batch := makeBatch(t, root, hardware, []GameSpec{{Setname: "casegame"}})
	profilePath := filepath.Join(batch.CorePath, "cores", batch.Core, "cfg", "reg.yaml")
	if err := os.WriteFile(profilePath, []byte("casegame:\n  DIPSW: 0x12\n"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := batch.Run(); err != nil {
		t.Fatal(err)
	}
	got := batch.State.Games["casegame"]
	if got.Outcome != Error || got.Stage != "profile" || !strings.Contains(got.Message, "supported spelling is dipsw") {
		t.Fatalf("noncanonical DIPSW was not rejected: %+v", got)
	}
	if hardware.failLoad == false {
		t.Fatal("unexpected mutation of fake hardware")
	}
}

func TestBatchLeavesGamesPendingOnBoardOutage(t *testing.T) {
	root := t.TempDir()
	hardware := &fakeHardware{failLoad: true, unavailable: true}
	batch := makeBatch(t, root, hardware, []GameSpec{{Setname: "one"}, {Setname: "two"}})
	if e := batch.Run(); e == nil || !strings.Contains(e.Error(), "board outage") {
		t.Fatalf("expected interrupted board error, got %v", e)
	}
	if batch.State.Games["one"].Outcome != Pending || batch.State.Games["two"].Outcome != Pending {
		t.Fatalf("outage should leave all unexecuted games pending: %+v", batch.State.Games)
	}
}

type retryHardware struct{ loaded, ran []string }

func (h *retryHardware) Load(g GameSpec) (LoadInfo, error) {
	h.loaded = append(h.loaded, g.Setname)
	return LoadInfo{}, nil
}
func (h *retryHardware) Run(g GameSpec, cab, dir string) (RunInfo, error) {
	h.ran = append(h.ran, g.Setname)
	return RunInfo{}, errors.New("test run stopped after proving retry selection")
}
func (h *retryHardware) Cleanup([]string) error { return nil }
func (h *retryHardware) Healthy() error         { return nil }

func TestRetryErrorsRefreshesOnlyErroredGameDefinition(t *testing.T) {
	root := t.TempDir()
	hardware := &retryHardware{}
	batch := makeBatch(t, root, hardware, nil)
	if err := os.WriteFile(batch.GlobalProfile, []byte("video: 300\nstart-up: 0\n"), 0600); err != nil {
		t.Fatal(err)
	}
	passGame := GameSpec{Setname: "passed", ARC: filepath.Join(root, "passed.arc")}
	if err := os.WriteFile(passGame.ARC, []byte("approved ARC"), 0600); err != nil {
		t.Fatal(err)
	}
	oldBroken := GameSpec{Setname: "repaired", PreparationError: "ROM missing"}
	newBroken := GameSpec{Setname: "repaired", PreparationError: ""}
	newBroken.ARC = filepath.Join(root, "repaired.arc")
	if err := os.WriteFile(newBroken.ARC, []byte("prepared ARC"), 0600); err != nil {
		t.Fatal(err)
	}
	batch.Games = []GameSpec{passGame, newBroken}
	oldGames := []GameSpec{passGame, oldBroken}
	oldBatch := *batch
	oldBatch.Games = oldGames
	oldAggregate, err := batchIdentity(&oldBatch)
	if err != nil {
		t.Fatal(err)
	}
	passID, err := gameSpecIdentity(batch, passGame)
	if err != nil {
		t.Fatal(err)
	}
	errorID, err := gameSpecIdentity(&oldBatch, oldBroken)
	if err != nil {
		t.Fatal(err)
	}
	batch.State.TestIdentity = oldAggregate
	// Discovery may enrich PR routing on resume without changing the tested
	// build or any fixture/test-definition identity.
	batch.Build.PR = 1689
	batch.State.Games = map[string]GameResult{
		"passed":   {Core: batch.Core, Setname: "passed", Outcome: Pass},
		"repaired": {Core: batch.Core, Setname: "repaired", Outcome: Pending},
	}
	capture := make_capture_fixture(t, []uint16{1, 2, 3})
	gameRoot := filepath.Join(batch.Root, batch.Core, "passed")
	profile, err := resolvedGameProfile(batch, passGame)
	if err != nil {
		t.Fatal(err)
	}
	definition, fixtureHashes, cabHash, sourceCABHash, err := currentReceiptDefinition(batch, passGame, profile, "RGB444")
	if err != nil {
		t.Fatal(err)
	}
	metadata := GameMetadata{TestIdentity: definition, Build: oldBatch.Build, Profile: profile, FixtureHashes: fixtureHashes, CABSHA256: cabHash, CABSourceSHA256: sourceCABHash, CABClipMode: "prefix", CABFrameBudget: profile.Video, CaptureFormat: "RGB444", Frames: profile.Video, Cadence: 100, Startup: profile.Startup}
	seed_receipt(t, batch, "passed", capture, metadata)
	if err := PublishComplete(gameRoot, capture, New, metadata); err != nil {
		t.Fatal(err)
	}
	if err := os.Rename(filepath.Join(gameRoot, "new"), filepath.Join(gameRoot, "ref")); err != nil {
		t.Fatal(err)
	}
	batch.State.Games["passed"] = GameResult{Core: batch.Core, Setname: "passed", Outcome: Pass, TestIdentity: definition}
	batch.RetryErrors = true
	if err := batch.Run(); err != nil {
		t.Fatal(err)
	}
	if len(hardware.loaded) != 1 || hardware.loaded[0] != "repaired" || len(hardware.ran) != 1 || hardware.ran[0] != "repaired" {
		t.Fatalf("retry should execute only repaired title; loads=%v runs=%v", hardware.loaded, hardware.ran)
	}
	if batch.State.Games["passed"].Outcome != Pass || batch.State.Games["repaired"].Outcome != Error {
		t.Fatalf("unexpected outcomes after retry: %+v", batch.State.Games)
	}
	if batch.State.GameSpecIdentities["repaired"] == errorID || batch.State.TestIdentity == oldAggregate || batch.State.GameSpecIdentities["passed"] != passID {
		t.Fatal("repaired per-game and aggregate identities were not refreshed")
	}
	if batch.State.Build.PR != 1689 {
		t.Fatalf("resumed build did not retain enriched PR provenance: %+v", batch.State.Build)
	}
}

func TestRetryErrorsRejectsChangedPassedFixture(t *testing.T) {
	root := t.TempDir()
	batch := makeBatch(t, root, &retryHardware{}, nil)
	if err := os.WriteFile(batch.GlobalProfile, []byte("video: 300\nstart-up: 0\n"), 0600); err != nil {
		t.Fatal(err)
	}
	arc := filepath.Join(root, "passed.arc")
	if err := os.WriteFile(arc, []byte("version one"), 0600); err != nil {
		t.Fatal(err)
	}
	game := GameSpec{Setname: "passed", ARC: arc}
	batch.Games = []GameSpec{game}
	oldAggregate, err := batchIdentity(batch)
	if err != nil {
		t.Fatal(err)
	}
	oldSpec, err := gameSpecIdentity(batch, game)
	if err != nil {
		t.Fatal(err)
	}
	batch.State.TestIdentity = oldAggregate
	batch.State.GameSpecIdentities = map[string]string{"passed": oldSpec}
	batch.State.Games = map[string]GameResult{"passed": {Core: batch.Core, Setname: "passed", Outcome: Pass}}
	if err = os.WriteFile(arc, []byte("version two"), 0600); err != nil {
		t.Fatal(err)
	}
	batch.RetryErrors = true
	if err = batch.Run(); err == nil || !strings.Contains(err.Error(), "finalized result") {
		t.Fatalf("changed passed fixture must fail closed, got %v", err)
	}
}

func TestLegacyStateMigrationRejectsChangedPassedFixture(t *testing.T) {
	root := t.TempDir()
	batch := makeBatch(t, root, &retryHardware{}, nil)
	if err := os.WriteFile(batch.GlobalProfile, []byte("video: 300\nstart-up: 0\n"), 0600); err != nil {
		t.Fatal(err)
	}
	arc := filepath.Join(root, "passed.arc")
	if err := os.WriteFile(arc, []byte("approved bytes"), 0600); err != nil {
		t.Fatal(err)
	}
	game := GameSpec{Setname: "passed", ARC: arc}
	batch.Games = []GameSpec{game}
	oldAggregate, err := batchIdentity(batch)
	if err != nil {
		t.Fatal(err)
	}
	profile, err := resolvedGameProfile(batch, game)
	if err != nil {
		t.Fatal(err)
	}
	definition, fixtureHashes, cabHash, sourceCABHash, err := currentReceiptDefinition(batch, game, profile, "RGB444")
	if err != nil {
		t.Fatal(err)
	}
	metadata := GameMetadata{Build: batch.Build, TestIdentity: definition, Profile: profile, FixtureHashes: fixtureHashes, CABSHA256: cabHash, CABSourceSHA256: sourceCABHash, CABClipMode: "prefix", CABFrameBudget: profile.Video, CaptureFormat: "RGB444", Frames: profile.Video, Cadence: 100, Startup: profile.Startup}
	gameRoot := filepath.Join(batch.Root, batch.Core, game.Setname)
	capture := make_capture_fixture(t, []uint16{1, 2, 3})
	receipt_metadata := metadata
	receipt_metadata.Build = batch.Build
	seed_receipt(t, batch, game.Setname, capture, receipt_metadata)
	if err := PublishComplete(gameRoot, capture, New, metadata); err != nil {
		t.Fatal(err)
	}
	if err := os.Rename(filepath.Join(gameRoot, "new"), filepath.Join(gameRoot, "ref")); err != nil {
		t.Fatal(err)
	}
	batch.State.TestIdentity = oldAggregate
	batch.State.Games = map[string]GameResult{"passed": {Core: batch.Core, Setname: game.Setname, Outcome: Pass, TestIdentity: definition}}
	if err = os.WriteFile(arc, []byte("changed bytes"), 0600); err != nil {
		t.Fatal(err)
	}
	batch.RetryErrors = true
	if err = batch.Run(); err == nil || !strings.Contains(err.Error(), "cannot prove finalized game passed unchanged") {
		t.Fatalf("legacy migration must reject changed passed fixture, got %v", err)
	}
	if len(batch.Hardware.(*retryHardware).loaded) != 0 {
		t.Fatal("changed passed game must fail before any hardware operation")
	}
}

func TestLegacyAggregateIdentityMigrationIsConservative(t *testing.T) {
	batch := &Batch{State: &State{TestIdentity: "old-aggregate", Games: map[string]GameResult{
		"broken": {Setname: "broken", Outcome: Error},
	}}, RetryErrors: true}
	if err := batch.reconcileGameSpecIdentities("new-aggregate", map[string]string{"broken": "new-spec"}); err != nil {
		t.Fatalf("retryable legacy error should migrate: %v", err)
	}
	if batch.State.GameSpecIdentities["broken"] != "new-spec" {
		t.Fatal("legacy retry migration did not backfill current per-game identity")
	}
	batch = &Batch{State: &State{TestIdentity: "old-aggregate", Games: map[string]GameResult{
		"passed": {Setname: "passed", Outcome: Pass},
	}}, RetryErrors: true, Games: []GameSpec{{Setname: "passed"}}}
	if err := batch.reconcileGameSpecIdentities("new-aggregate", map[string]string{"passed": "new-spec"}); err == nil || !strings.Contains(err.Error(), "legacy state cannot prove") {
		t.Fatalf("legacy aggregate mismatch with finalized result must fail closed, got %v", err)
	}
	batch = &Batch{State: &State{Games: map[string]GameResult{
		"passed": {Setname: "passed", Outcome: Pass},
	}}, Games: []GameSpec{{Setname: "passed"}}}
	if err := batch.reconcileGameSpecIdentities("new-aggregate", map[string]string{"passed": "new-spec"}); err == nil || !strings.Contains(err.Error(), "no aggregate identity") {
		t.Fatalf("legacy finalized state without an aggregate must fail closed, got %v", err)
	}
}

func TestLegacyMigrationRejectsRemovedStateGame(t *testing.T) {
	batch := &Batch{State: &State{TestIdentity: "old-aggregate", Games: map[string]GameResult{
		"removed-pass": {Setname: "removed-pass", Outcome: Pass},
		"kept":         {Setname: "kept", Outcome: Pending},
	}}, RetryErrors: true, Games: []GameSpec{{Setname: "kept"}}}
	if err := batch.reconcileGameSpecIdentities("new-aggregate", map[string]string{"kept": "same-spec"}); err == nil || !strings.Contains(err.Error(), "removed state game removed-pass") {
		t.Fatalf("removed legacy pass must block migration: %v", err)
	}
}

func TestLegacyPassMayUseOlderApprovedReference(t *testing.T) {
	root := t.TempDir()
	hardware := &retryHardware{}
	batch := makeBatch(t, root, hardware, nil)
	if err := os.WriteFile(batch.GlobalProfile, []byte("video: 300\nstart-up: 0\n"), 0600); err != nil {
		t.Fatal(err)
	}
	arc := filepath.Join(root, "game.arc")
	if err := os.WriteFile(arc, []byte("stable fixture"), 0600); err != nil {
		t.Fatal(err)
	}
	game := GameSpec{Setname: "historical", ARC: arc}
	batch.Games = []GameSpec{game}
	profile, err := resolvedGameProfile(batch, game)
	if err != nil {
		t.Fatal(err)
	}
	definition, fixtureHashes, cabHash, sourceCABHash, err := currentReceiptDefinition(batch, game, profile, "RGB444")
	if err != nil {
		t.Fatal(err)
	}
	oldBuild := BuildIdentity{RunID: "older-run", Attempt: "1", SHA: "old-sha"}
	metadata := GameMetadata{Build: oldBuild, TestIdentity: definition, Profile: profile, FixtureHashes: fixtureHashes, CABSHA256: cabHash, CABSourceSHA256: sourceCABHash, CABClipMode: "prefix", CABFrameBudget: profile.Video, CaptureFormat: "RGB444", Frames: profile.Video, Cadence: 100, Startup: profile.Startup}
	gameRoot := filepath.Join(batch.Root, batch.Core, game.Setname)
	capture := make_capture_fixture(t, []uint16{1, 2, 3})
	receipt_metadata := metadata
	receipt_metadata.Build = batch.Build
	seed_receipt(t, batch, game.Setname, capture, receipt_metadata)
	if err := PublishComplete(gameRoot, capture, New, metadata); err != nil {
		t.Fatal(err)
	}
	if err := os.Rename(filepath.Join(gameRoot, "new"), filepath.Join(gameRoot, "ref")); err != nil {
		t.Fatal(err)
	}
	identity, err := batchIdentity(batch)
	if err != nil {
		t.Fatal(err)
	}
	batch.State.TestIdentity = identity
	batch.State.Games = map[string]GameResult{"historical": {Core: batch.Core, Setname: game.Setname, Outcome: Pass, TestIdentity: definition}}
	if err = batch.Run(); err != nil {
		t.Fatal(err)
	}
	if len(hardware.loaded) != 0 || len(hardware.ran) != 0 || batch.State.GameSpecIdentities["historical"] == "" {
		t.Fatalf("historical approved pass was not safely migrated/skipped: loaded=%v ran=%v", hardware.loaded, hardware.ran)
	}
}

func TestFinalizedNewSurvivesPRProvenanceEnrichment(t *testing.T) {
	root := t.TempDir()
	batch := makeBatch(t, root, &retryHardware{}, []GameSpec{{Setname: "waiting"}})
	batch.Build.PR = 1689
	if err := os.WriteFile(batch.GlobalProfile, []byte("video: 300\nstart-up: 0\n"), 0600); err != nil {
		t.Fatal(err)
	}
	capture := make_capture_fixture(t, []uint16{1, 2, 3})
	gameRoot := filepath.Join(batch.Root, batch.Core, "waiting")
	metadata := GameMetadata{TestIdentity: "test-id", Build: BuildIdentity{RunID: batch.Build.RunID, Attempt: batch.Build.Attempt, SHA: batch.Build.SHA}}
	seed_receipt(t, batch, "waiting", capture, metadata)
	if err := PublishComplete(gameRoot, capture, New, metadata); err != nil {
		t.Fatal(err)
	}
	result := GameResult{Core: batch.Core, Setname: "waiting", Outcome: New, TestIdentity: "test-id"}
	if !batch.verifyFinalized(batch.Games[0], result) {
		t.Fatal("same build with newly resolved PR provenance should verify finalized capture")
	}
}

func TestInterruptedSummaryContainsWholeManifestButJUnitOnlyExecuted(t *testing.T) {
	cores := []CoreManifest{{Core: "first", Games: []GameSpec{{Setname: "done"}, {Setname: "pending-first"}}}, {Core: "later", Games: []GameSpec{{Setname: "unvisited"}}}}
	all := PendingInventory(cores)
	all = ReplaceCoreResults(all, "first", map[string]GameResult{
		"done": {Outcome: Error, Stage: "load", Message: "failed"},
	})
	seen := map[string]int{}
	for _, result := range all {
		seen[result.Core+"/"+result.Setname]++
	}
	if len(all) != 3 || seen["first/done"] != 1 || seen["first/pending-first"] != 1 || seen["later/unvisited"] != 1 {
		t.Fatalf("manifest tuples missing or duplicated: %+v", all)
	}
	if all[0].Outcome != Error || all[1].Outcome != Pending || all[2].Outcome != Pending {
		t.Fatalf("unexpected interrupted outcomes: %+v", all)
	}
	emptyCore := ReplaceCoreResults(PendingInventory(cores), "first", map[string]GameResult{})
	if len(emptyCore) != 3 {
		t.Fatalf("empty early state discarded manifest titles: %+v", emptyCore)
	}
	for _, result := range emptyCore {
		if result.Outcome != Pending {
			t.Fatalf("empty state should preserve pending result: %+v", result)
		}
	}
	dir := t.TempDir()
	if err := WriteSummary(dir, Summary{RunID: "interrupted", Core: "combined", Status: "interrupted", Games: all}); err != nil {
		t.Fatal(err)
	}
	junit, err := os.ReadFile(filepath.Join(dir, "junit.xml"))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(junit), `name="pending-first"`) || strings.Contains(string(junit), `name="unvisited"`) || !strings.Contains(string(junit), `name="done"`) {
		t.Fatalf("JUnit must include executed error and omit pending tests: %s", junit)
	}
}

func TestRestoreCampaignStartFromSummaryAndState(t *testing.T) {
	root := t.TempDir()
	build := BuildIdentity{RunID: "run", Attempt: "1", SHA: "abc"}
	fallback := time.Now().UTC()
	original := fallback.Add(-3 * time.Hour)
	summaryPath := filepath.Join(root, "summary.json")
	if err := os.WriteFile(summaryPath, mustJSON(t, Summary{Build: build, Started: original}), 0600); err != nil {
		t.Fatal(err)
	}
	enrichedBuild := build
	enrichedBuild.PR = 1689
	if got := RestoreCampaignStart(summaryPath, filepath.Join(root, "state"), enrichedBuild, fallback); !got.Equal(original) {
		t.Fatalf("summary start not restored: got %s want %s", got, original)
	}
	if err := os.Remove(summaryPath); err != nil {
		t.Fatal(err)
	}
	stateDir := filepath.Join(root, "state")
	if err := os.MkdirAll(stateDir, 0750); err != nil {
		t.Fatal(err)
	}
	gameStart := fallback.Add(-2 * time.Hour)
	state := &State{Build: build, Games: map[string]GameResult{"old": {Setname: "old", Outcome: Error, Started: gameStart}}}
	if err := WriteState(filepath.Join(stateDir, "core.json"), state); err != nil {
		t.Fatal(err)
	}
	if got := RestoreCampaignStart(summaryPath, stateDir, enrichedBuild, fallback); !got.Equal(gameStart) {
		t.Fatalf("state start not restored: got %s want %s", got, gameStart)
	}
}

func TestRestoreCampaignStartUsesVerifiedLaunchBeforePreparationSummary(t *testing.T) {
	root := t.TempDir()
	dataRoot := filepath.Join(root, "regression")
	runID := "40655576158-attempt-1"
	logDir := filepath.Join(dataRoot, "log", runID)
	if err := os.MkdirAll(logDir, 0750); err != nil {
		t.Fatal(err)
	}
	build := BuildIdentity{Repository: "jotego/jtcores", Workflow: "compile-all.yaml", RunID: "40655576158", Attempt: "1", SHA: "a405f1b955a06f10f75a5aafe2d7080d631e062e"}
	manifest := Manifest{RunID: runID, Build: build}
	manifestPath := filepath.Join(dataRoot, "log", runID, "manifest.json")
	if err := os.MkdirAll(filepath.Dir(manifestPath), 0750); err != nil {
		t.Fatal(err)
	}
	manifestData := mustJSON(t, manifest)
	if err := os.WriteFile(manifestPath, manifestData, 0600); err != nil {
		t.Fatal(err)
	}
	manifestHash, err := FileSHA256(manifestPath)
	if err != nil {
		t.Fatal(err)
	}
	launchStart := time.Date(2026, 10, 28, 22, 57, 24, 690000000, time.UTC)
	launch := map[string]any{
		"run_id":  runID,
		"process": map[string]any{"os_start_time_utc": launchStart.Format(time.RFC3339Nano)},
		"inputs":  map[string]any{"manifest": manifestPath, "manifest_sha256": manifestHash},
	}
	launchData := mustJSON(t, launch)
	if err := os.WriteFile(filepath.Join(logDir, "launch.json"), launchData, 0600); err != nil {
		t.Fatal(err)
	}
	// This mirrors command startup: authenticate and persist the launch-bound
	// manifest before automatic Prepare enriches its report routing metadata.
	launchStarts, err := SnapshotLaunchStarts(dataRoot, build.RunID)
	if err != nil {
		t.Fatal(err)
	}
	enrichedManifest := manifest
	enrichedManifest.Build.PR = 1689
	enrichedBytes, err := json.MarshalIndent(enrichedManifest, "", "  ")
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(manifestPath, append(enrichedBytes, '\n'), 0600); err != nil {
		t.Fatal(err)
	}
	summaryStart := launchStart.Add(7 * time.Minute)
	if err := os.WriteFile(filepath.Join(logDir, "summary.json"), mustJSON(t, Summary{Build: build, Started: summaryStart}), 0600); err != nil {
		t.Fatal(err)
	}
	// A later retry must continue using the immutable launch copy after the
	// primary manifest has changed.
	launchStarts, err = SnapshotLaunchStarts(dataRoot, build.RunID)
	if err != nil {
		t.Fatal(err)
	}
	enrichedBuild := enrichedManifest.Build
	fallback := summaryStart.Add(time.Hour)
	got := RestoreCampaignStart(filepath.Join(logDir, "summary.json"), filepath.Join(dataRoot, "log", runID, "state"), enrichedBuild, fallback, launchStarts)
	if !got.Equal(launchStart) {
		t.Fatalf("verified launch time should include preparation: got %s want %s", got, launchStart)
	}
	launch["inputs"].(map[string]any)["manifest_sha256"] = strings.Repeat("0", 64)
	if err := os.WriteFile(filepath.Join(logDir, "launch.json"), mustJSON(t, launch), 0600); err != nil {
		t.Fatal(err)
	}
	launchStarts, err = SnapshotLaunchStarts(dataRoot, build.RunID)
	if err == nil {
		t.Fatal("tampered launch digest should prevent startup snapshot")
	}
	got = RestoreCampaignStart(filepath.Join(logDir, "summary.json"), filepath.Join(dataRoot, "log", runID, "state"), enrichedBuild, fallback)
	if !got.Equal(summaryStart) {
		t.Fatalf("unverified launch record must be ignored: got %s want %s", got, summaryStart)
	}
}

func mustJSON(t *testing.T, value any) []byte {
	t.Helper()
	data, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	return data
}

func make_capture_fixture(t *testing.T, pixels []uint16) string {
	t.Helper()
	dir := t.TempDir()
	var index strings.Builder
	index.WriteString(`{"type":"run","count":` + jsonNumber(len(pixels)) + `,"width":2,"height":2}` + "\n")
	for i, pixel := range pixels {
		frame := (i + 1) * 100
		name := "frame_" + jsonNumber(frame) + ".raw"
		data := make([]byte, 12)
		binary.LittleEndian.PutUint16(data, 0x8002)
		binary.LittleEndian.PutUint16(data[2:], 2)
		binary.LittleEndian.PutUint16(data[4:], pixel)
		if pixel != 0 {
			binary.LittleEndian.PutUint16(data[6:], 1)
			binary.LittleEndian.PutUint16(data[8:], 2)
			binary.LittleEndian.PutUint16(data[10:], 3)
		}
		if e := os.WriteFile(filepath.Join(dir, name), data, 0600); e != nil {
			t.Fatal(e)
		}
		capture, _ := json.Marshal(CaptureRecord{Type: "capture", Requested: frame, Actual: frame, Image: name})
		index.Write(capture)
		index.WriteByte('\n')
	}
	index.WriteString(`{"type":"complete","captures":` + jsonNumber(len(pixels)) + `}` + "\n")
	if e := os.WriteFile(filepath.Join(dir, "index.jsonl"), []byte(index.String()), 0600); e != nil {
		t.Fatal(e)
	}
	return dir
}

func jsonNumber(value int) string { return strconv.Itoa(value) }

func seed_receipt(t *testing.T, batch *Batch, setname, capture string, metadata GameMetadata) {
	t.Helper()
	dir := batch.capture_receipt(setname)
	if err:=os.MkdirAll(dir,0750);err!=nil {t.Fatal(err)}
	if err:=export_png_frames(capture,dir);err!=nil {t.Fatal(err)}
	if err:=write_metadata(dir,metadata);err!=nil {t.Fatal(err)}
}

func TestRGB555PNGExpansionAndComparison(t *testing.T) {
	dir := t.TempDir()
	pixels := []uint16{0, (3<<10)|(7<<5)|15, 0x7fff, 1}
	data := make([]byte,12)
	binary.LittleEndian.PutUint16(data,0x8002)
	binary.LittleEndian.PutUint16(data[2:],2)
	for i,pixel := range pixels {binary.LittleEndian.PutUint16(data[4+i*2:],pixel)}
	if err:=os.WriteFile(filepath.Join(dir,"frame_00000100.raw"),data,0600);err!=nil {t.Fatal(err)}
	index := `{"type":"run","count":1,"width":2,"height":2}`+"\n"+`{"type":"capture","requested":100,"actual":100,"image":"frame_00000100.raw"}`+"\n"+`{"type":"complete","captures":1}`+"\n"
	if err:=os.WriteFile(filepath.Join(dir,"index.jsonl"),[]byte(index),0600);err!=nil {t.Fatal(err)}
	published := t.TempDir()
	if err:=export_png_frames(dir,published);err!=nil {t.Fatal(err)}
	decoded,err:=decode_capture_image(filepath.Join(published,"frame_00000100.png"));if err!=nil {t.Fatal(err)}
	if decoded.pixels[1] != 0x18397b {t.Fatalf("RGB555 expansion got %06x",decoded.pixels[1])}
	raw,err:=ReadCaptureSet(dir,100,0,100);if err!=nil {t.Fatal(err)}
	pngs,err:=ReadCaptureSet(published,100,0,100);if err!=nil {t.Fatal(err)}
	diffs,err:=CompareCaptureSets(raw,pngs,0);if err!=nil || len(diffs)!=0 {t.Fatalf("RAW/PNG differ: %v %v",diffs,err)}
}

func TestFinalizedCaptureDetectsChangedPublishedPNG(t *testing.T) {
	root:=t.TempDir()
	batch:=makeBatch(t,root,&retryHardware{},[]GameSpec{{Setname:"waiting"}})
	if err:=os.WriteFile(batch.GlobalProfile,[]byte("video: 300\nstart-up: 0\n"),0600);err!=nil {t.Fatal(err)}
	capture:=make_capture_fixture(t,[]uint16{1,2,3})
	metadata:=GameMetadata{TestIdentity:"definition",Build:batch.Build}
	seed_receipt(t,batch,"waiting",capture,metadata)
	game_root:=filepath.Join(batch.Root,batch.Core,"waiting")
	if err:=PublishComplete(game_root,capture,New,metadata);err!=nil {t.Fatal(err)}
	result:=GameResult{Outcome:New,TestIdentity:"definition"}
	if !batch.verifyFinalized(batch.Games[0],result) {t.Fatal("complete PNG receipt not accepted")}
	changed:=make_capture_fixture(t,[]uint16{4,5,6})
	if err:=PublishComplete(game_root,changed,New,metadata);err!=nil {t.Fatal(err)}
	if batch.verifyFinalized(batch.Games[0],result) {t.Fatal("changed PNG result incorrectly skipped on resume")}
}

func TestFinalizedPassKeepsStartupCutoff(t *testing.T) {
	root:=t.TempDir()
	batch:=makeBatch(t,root,&retryHardware{},[]GameSpec{{Setname:"passed"}})
	if err:=os.WriteFile(batch.GlobalProfile,[]byte("video: 300\nstart-up: 100\n"),0600);err!=nil {t.Fatal(err)}
	metadata:=GameMetadata{TestIdentity:"definition",Build:batch.Build}
	candidate:=make_capture_fixture(t,[]uint16{1,2,3})
	seed_receipt(t,batch,"passed",candidate,metadata)
	approved:=make_capture_fixture(t,[]uint16{4,2,3})
	game_root:=filepath.Join(batch.Root,batch.Core,"passed")
	if err:=PublishComplete(game_root,approved,New,metadata);err!=nil {t.Fatal(err)}
	if err:=os.Rename(filepath.Join(game_root,"new"),filepath.Join(game_root,"ref"));err!=nil {t.Fatal(err)}
	result:=GameResult{Outcome:Pass,TestIdentity:"definition"}
	if !batch.verifyFinalized(batch.Games[0],result) {t.Fatal("matching comparable frames must retain finalized pass despite startup differences")}
}

func TestConfigRejectsRetiredParallelWorkspaceOptions(t *testing.T) {
	for _, key := range []string{"build-cache","fixture-cache","rom-source-extra"} {
		path:=filepath.Join(t.TempDir(),"config.yaml")
		if err:=os.WriteFile(path,[]byte(key+": obsolete\n"),0600);err!=nil {t.Fatal(err)}
		if _,err:=ReadConfig(path);err==nil {t.Fatalf("obsolete %s configuration was silently accepted",key)}
	}
}
