/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

type GameSpec struct {
	Setname             string               `json:"setname"`
	ARC                 string               `json:"arc"`
	ROMs                []string             `json:"roms"`
	RBF                 string               `json:"rbf"`
	Unsupported         bool                 `json:"unsupported,omitempty"`
	UnsupportedReason   string               `json:"unsupported_reason,omitempty"`
	PreparationError    string               `json:"preparation_error,omitempty"`
	PreparationWarnings []PreparationWarning `json:"preparation_warnings,omitempty"`
	Profile             Profile              `json:"profile"`
	CAB                 string               `json:"cab,omitempty"`
	SourceCAB           string               `json:"-"`
}

type Hardware interface {
	Load(GameSpec) (LoadInfo, error)
	Run(GameSpec, string, string) (RunInfo, error) // CAB, capture output directory
	Cleanup([]string) error
}
type BoardHealth interface{ Healthy() error }
type LoadInfo struct {
	Firmware    string   `json:"firmware"`
	RemoteFiles []string `json:"remote_files"`
	Transfers []TransferInfo `json:"transfers,omitempty"`
	RBFReused bool `json:"rbf_reused"`
	SiteLoadDuration time.Duration `json:"site_load_duration_ns"`
}

type TransferInfo struct {
	Name string `json:"name"`
	Role string `json:"role"`
	Bytes int64 `json:"bytes"`
	Duration time.Duration `json:"duration_ns"`
	Uploaded bool `json:"uploaded"`
	Reused bool `json:"reused,omitempty"`
	Error string `json:"error,omitempty"`
}
type RunInfo struct {
	Report         string        `json:"report"`
	CaptureDir     string        `json:"capture_dir"`
	Duration       time.Duration `json:"duration"`
	RemoteFiles    []string      `json:"remote_files,omitempty"`
	RemoteVideoDir string        `json:"remote_video_dir,omitempty"`
}

type GameMetadata struct {
	Build               BuildIdentity        `json:"build"`
	ProjectSHA          string               `json:"project_sha"`
	TestIdentity        string               `json:"test_identity"`
	Profile             Profile              `json:"profile"`
	CABSHA256           string               `json:"cab_sha256,omitempty"`
	CABSourceSHA256     string               `json:"cab_source_sha256,omitempty"`
	CABClipMode         string               `json:"cab_clip_mode"`
	CABFrameBudget      int                  `json:"cab_frame_budget"`
	RBF                 string               `json:"rbf"`
	RBFHash             string               `json:"rbf_sha256"`
	ROMs                []string             `json:"roms"`
	ARC                 string               `json:"arc"`
	FixtureHashes       map[string]string    `json:"fixture_sha256"`
	Firmware            string               `json:"firmware"`
	FirmwareSHA256      string               `json:"firmware_sha256"`
	CaptureToolSHA256   string               `json:"capture_tool_sha256"`
	CaptureReport       json.RawMessage      `json:"capture_report,omitempty"`
	CaptureFormat       string               `json:"capture_format"`
	Frames              int                  `json:"frames"`
	Cadence             int                  `json:"cadence"`
	Startup             int                  `json:"start-up"`
	PreparationWarnings []PreparationWarning `json:"preparation_warnings,omitempty"`
}

// PreparationWarning records a reviewed, post-emission jtframe diagnostic
// whose generated fixture has been independently proven against the source
// and selected build artifact. Unknown command failures remain errors.
type PreparationWarning struct {
	Code       string                  `json:"code"`
	Message    string                  `json:"message"`
	Command    string                  `json:"command"`
	ExitStatus string                  `json:"exit_status"`
	Diagnostic string                  `json:"diagnostic"`
}

type Batch struct {
	Root              string
	CorePath          string
	Core              string
	RunID             string
	Build             BuildIdentity
	ProjectSHA        string
	State             *State
	StatePath         string
	Log               *EventLog
	Hardware          Hardware
	GlobalProfile     string
	Games             []GameSpec
	Firmware          string
	FirmwareSHA256    string
	CaptureToolSHA256 string
	RetryErrors       bool
	Resume bool
	read_only_receipts bool
}

func (b *Batch) Run() error {
	for _,result:=range b.State.Games {if result.RecordError!="" {b.Resume=true;break}}
	identity, e := batchIdentity(b)
	if e != nil {
		return e
	}
	transition,e:=b.read_firmware_transition()
	if e!=nil {return e}
	historical_games:=make(map[string]bool)
	specIdentities := make(map[string]string, len(b.Games))
	for _, game := range b.Games {
		specID, err := gameSpecIdentity(b, game)
		if err != nil {
			return fmt.Errorf("identify %s: %w", game.Setname, err)
		}
		specID,historical,err:=b.transitioned_game_identity(transition,game,specID)
		if err!=nil {return fmt.Errorf("verify firmware transition for %s: %w",game.Setname,err)}
		historical_games[game.Setname]=historical
		specIdentities[game.Setname] = specID
	}
	if b.State.Core != "" && b.State.Core != b.Core {
		return fmt.Errorf("resume state core %s does not match requested core %s", b.State.Core, b.Core)
	}
	if b.State.Build.RunID != "" && !sameResumeBuild(b.State.Build, b.Build) {
		return fmt.Errorf("resume state build identity does not match selected build")
	}
	if err := b.reconcileGameSpecIdentities(identity, specIdentities); err != nil {
		return err
	}
	b.State.Core, b.State.Build, b.State.TestIdentity = b.Core, b.Build, identity
	if b.State.Games == nil {
		b.State.Games = make(map[string]GameResult)
	}
	for _, game := range b.Games {
		if _, ok := b.State.Games[game.Setname]; !ok {
			b.State.Games[game.Setname] = GameResult{Core: b.Core, Setname: game.Setname, Outcome: Pending}
		}
	}
	for _, game := range b.Games {
		old := b.State.Games[game.Setname]
		if old.Outcome == Pending || old.Outcome == Error && b.RetryErrors {
			_ = os.RemoveAll(filepath.Join(b.CorePath, ".cache", "jtutil-regression", "work", b.RunID, b.Core, game.Setname))
		}
	}
	if e := b.persist_state(); e != nil {
		return fmt.Errorf("persist initial pending state: %w", e)
	}
	for _, game := range b.Games {
		if old, ok := b.State.Games[game.Setname]; ok && (old.Outcome == Pass || old.Outcome == New || old.Outcome == Fail || old.Outcome == Unsupported || old.Outcome == Error && !b.RetryErrors) {
			verifier:=b
			if historical_games[game.Setname] {verifier=b.historical_firmware_batch(transition)}
			if old.RecordError!="" {copy:=*verifier;copy.read_only_receipts=true;verifier=&copy}
			if verifier.verifyFinalized(game, old) {
				if old.RecordError!="" {if err:=b.recover_record_error(game,old);err!=nil {return err}}
				continue
			}
			if old.RecordError!="" {return fmt.Errorf("cannot recover journal for unverified finalized capture %s: %s",game.Setname,old.RecordError)}
			if historical_games[game.Setname] {return fmt.Errorf("historical firmware capture changed during resume: %s",game.Setname)}
		}
		if e := b.Log.Write(Event{Setname: game.Setname, Stage: "game-start", Outcome: Pending, Fields: map[string]any{"run_id": b.RunID, "core": b.Core}}); e != nil {
			return fmt.Errorf("record start for %s: %w", game.Setname, e)
		}
		result := b.runGame(game)
		result.Core = b.Core
		if result.Stage == "board" {
			b.State.Games[game.Setname] = GameResult{Core: b.Core, Setname: game.Setname, Outcome: Pending}
			if e := b.Log.Write(Event{Stage: "board", Outcome: Error, Message: result.Message}); e != nil {
				return e
			}
			if e := b.persist_state(); e != nil {
				return fmt.Errorf("persist interrupted batch: %w", e)
			}
			return fmt.Errorf("batch interrupted by board outage: %s", result.Message)
		}
		b.State.Games[game.Setname] = result
		if e := b.Log.Write(Event{Setname: game.Setname, Stage: "game-complete", Outcome: result.Outcome, Message: result.Message, Fields: map[string]any{"stage": result.Stage, "duration_ns": result.Duration, "test_identity": result.TestIdentity}}); e != nil {
			result.RecordError = e.Error()
			b.State.Games[game.Setname] = result
		}
		if e := b.persist_state(); e != nil {
			return fmt.Errorf("persist result for %s: %w", game.Setname, e)
		}
		if result.RecordError != "" {
			return fmt.Errorf("persist event for %s: %s", game.Setname, result.RecordError)
		}
	}
	return nil
}

// reconcileGameSpecIdentities allows an explicit retry to refresh only pending
// or errored game definitions. Finalized games remain bound to the exact
// fixture/profile snapshot recorded when they ran.
func (b *Batch) reconcileGameSpecIdentities(aggregate string, current map[string]string) error {
	currentNames := make(map[string]bool, len(current))
	for setname := range current {
		currentNames[setname] = true
	}
	for setname := range b.State.Games {
		if !currentNames[setname] {
			return fmt.Errorf("resume inventory removed state game %s", setname)
		}
	}
	previous := b.State.GameSpecIdentities
	if len(previous) == 0 {
		// Older state files had one aggregate identity. Backfill per-game
		// fingerprints only after each finalized outcome is independently
		// verified against its complete stored capture and fixture receipts.
		if b.State.TestIdentity == "" && len(b.State.Games) > 0 && !onlyRetryableGames(b.State.Games) {
			return fmt.Errorf("resume state has finalized results but no aggregate identity; refusing unsafe migration")
		}
		if b.State.TestIdentity != "" && b.State.TestIdentity != aggregate && !b.RetryErrors {
			return fmt.Errorf("resume state aggregate identity changed; use --retry-errors to refresh pending/error definitions")
		}
		for _, game := range b.Games {
			result, exists := b.State.Games[game.Setname]
			if !exists || result.Outcome == Pending || result.Outcome == Error {
				continue
			}
			if !b.legacyFinalizedMatches(game, result) {
				return fmt.Errorf("legacy state cannot prove finalized game %s unchanged", game.Setname)
			}
		}
		b.State.GameSpecIdentities = current
		return nil
	}
	for setname, next := range current {
		old, exists := previous[setname]
		if !exists {
			if result, hasResult := b.State.Games[setname]; hasResult && !(b.RetryErrors && (result.Outcome == Pending || result.Outcome == Error)) {
				return fmt.Errorf("resume state has no per-game identity for finalized game %s", setname)
			}
			b.State.GameSpecIdentities[setname] = next
			continue
		}
		if old == next {
			continue
		}
		result, hasResult := b.State.Games[setname]
		if b.RetryErrors && (!hasResult || result.Outcome == Pending || result.Outcome == Error) {
			b.State.GameSpecIdentities[setname] = next
			continue
		}
		return fmt.Errorf("resume definition for %s changed after a finalized result; only pending/error games may change with --retry-errors", setname)
	}
	for setname := range previous {
		if _, exists := current[setname]; !exists {
			return fmt.Errorf("resume inventory removed game %s", setname)
		}
	}
	return nil
}

func onlyRetryableGames(games map[string]GameResult) bool {
	for _, result := range games {
		if result.Outcome != Pending && result.Outcome != Error {
			return false
		}
	}
	return true
}

func (b *Batch) legacyFinalizedMatches(game GameSpec, result GameResult) bool {
	if result.Outcome == Unsupported {
		message := game.UnsupportedReason
		if message == "" {
			message = "known unsupported on SiDi128"
		}
		return game.Unsupported && result.Stage == "inventory" && result.Message == message
	}
	if result.Outcome != Pass && result.Outcome != New && result.Outcome != Fail {
		return false
	}
	if !b.verifyFinalized(game, result) {
		return false
	}
	resultDir := b.capture_receipt(game.Setname)
	var metadata GameMetadata
	var err error
	if result.Outcome == Pass {
		metadata, err = read_metadata(resultDir)
	} else {
		metadata, err = read_metadata(resultDir)
	}
	if err != nil || metadata.TestIdentity == "" || metadata.TestIdentity != result.TestIdentity || result.Outcome != Pass && !sameResumeBuild(metadata.Build, b.Build) {
		return false
	}
	profile, err := resolvedGameProfile(b, game)
	if err != nil || !sameJSONValue(metadata.Profile, profile) || metadata.FirmwareSHA256 != b.FirmwareSHA256 || metadata.CaptureToolSHA256 != b.CaptureToolSHA256 || metadata.CABClipMode != "prefix" || metadata.CABFrameBudget != profile.Video || metadata.Frames != profile.Video || metadata.Cadence != 100 || metadata.Startup != profile.Startup {
		return false
	}
	if b.Firmware != "" && metadata.Firmware != b.Firmware {
		return false
	}
	definition, fixtureHashes, cabHash, sourceCABHash, err := currentReceiptDefinition(b, game, profile, metadata.CaptureFormat)
	if err != nil || definition != metadata.TestIdentity || !sameJSONValue(metadata.FixtureHashes, fixtureHashes) || metadata.CABSHA256 != cabHash || metadata.CABSourceSHA256 != sourceCABHash {
		return false
	}
	if game.RBF != "" {
		rbfHash, err := file_sha256(game.RBF)
		if err != nil || !strings.EqualFold(rbfHash, metadata.RBFHash) {
			return false
		}
	}
	return true
}

func resolvedGameProfile(b *Batch, game GameSpec) (Profile, error) {
	profile, err := ResolveProfile(b.GlobalProfile, b.CorePath, b.Core, game.Setname)
	if err != nil {
		return Profile{}, err
	}
	if game.Profile.Video != 0 {
		profile.Video = game.Profile.Video
	}
	if game.Profile.Startup != 0 {
		profile.Startup = game.Profile.Startup
	}
	if game.Profile.Inputs != "" {
		profile.Inputs = game.Profile.Inputs
	}
	if game.Profile.Options != nil {
		for key, value := range game.Profile.Options {
			profile.Options[key] = value
		}
	}
	return profile, nil
}

func currentReceiptDefinition(b *Batch, game GameSpec, profile Profile, captureFormat string) (string, map[string]string, string, string, error) {
	workRoot := filepath.Join(b.CorePath, ".cache", "jtutil-regression", "work", b.RunID)
	if err := os.MkdirAll(workRoot, 0750); err != nil {
		return "", nil, "", "", err
	}
	tempDir, err := os.MkdirTemp(workRoot, "legacy-receipt-")
	if err != nil {
		return "", nil, "", "", err
	}
	defer os.RemoveAll(tempDir)
	cab := game.CAB
	if cab == "" && profile.Inputs != "" {
		cab = profile.Inputs
	}
	if cab != "" && !filepath.IsAbs(cab) {
		cab = filepath.Join(b.CorePath, "cores", b.Core, "ver", game.Setname, cab)
	}
	if cab == "" {
		cab = filepath.Join(tempDir, "neutral.cab")
		if err = os.WriteFile(cab, []byte(fmt.Sprintf("%d\n", profile.Video)), 0600); err != nil {
			return "", nil, "", "", err
		}
	}
	sourceCAB := cab
	effectiveCAB := cab
	if dip, ok := profile.Options["dipsw"]; ok {
		value := fmt.Sprint(dip)
		parsed, parseErr := strconv.ParseUint(strings.TrimPrefix(strings.ToLower(value), "0x"), 16, 32)
		if parseErr != nil {
			return "", nil, "", "", fmt.Errorf("invalid dipsw in stored test definition")
		}
		contents, readErr := os.ReadFile(cab)
		if readErr != nil {
			return "", nil, "", "", readErr
		}
		effectiveCAB = filepath.Join(tempDir, "effective.cab")
		if err = os.WriteFile(effectiveCAB, []byte("dipsw="+strconv.FormatUint(parsed, 16)+"\n"+string(contents)), 0600); err != nil {
			return "", nil, "", "", err
		}
	}
	roms := make(map[string]string, len(game.ROMs))
	for _, filename := range game.ROMs {
		roms[filepath.Base(filename)] = filename
	}
	definition, err := TestDefinitionIdentityWithCapture(b.Core, game.Setname, profile, roms,
		map[string]string{filepath.Base(game.ARC): game.ARC}, effectiveCAB, b.Firmware, b.FirmwareSHA256,
		b.CaptureToolSHA256, captureFormat, sourceCAB, "prefix", profile.Video)
	if err != nil {
		return "", nil, "", "", err
	}
	fixtureHashes := make(map[string]string, len(roms)+len(game.ROMs)+3)
	fixtures := map[string]string{
		"arc/" + filepath.Base(game.ARC):           game.ARC,
		"cab/input/" + filepath.Base(effectiveCAB): effectiveCAB,
		"cab/source/" + filepath.Base(sourceCAB):   sourceCAB,
	}
	for _, filename := range game.ROMs {
		fixtures["rom/"+filepath.Base(filename)] = filename
	}
	for name, filename := range fixtures {
		hash, hashErr := file_sha256(filename)
		if hashErr != nil {
			return "", nil, "", "", hashErr
		}
		fixtureHashes[name] = hash
	}
	cabHash, err := file_sha256(effectiveCAB)
	if err != nil {
		return "", nil, "", "", err
	}
	sourceCABHash, err := file_sha256(sourceCAB)
	if err != nil {
		return "", nil, "", "", err
	}
	return definition, fixtureHashes, cabHash, sourceCABHash, nil
}

func sameJSONValue(a, b any) bool {
	left, errA := json.Marshal(a)
	right, errB := json.Marshal(b)
	return errA == nil && errB == nil && string(left) == string(right)
}

func gameSpecIdentity(b *Batch, game GameSpec) (string, error) {
	files := make(map[string]string)
	paths := append([]string{game.ARC, game.RBF}, game.ROMs...)
	paths = append(paths, game.CAB, game.SourceCAB)
	for _, filename := range paths {
		if filename == "" {
			continue
		}
		abs, err := filepath.Abs(filename)
		if err != nil {
			return "", err
		}
		if _, err = os.Stat(abs); err == nil {
			files[abs] = abs
		} else if !os.IsNotExist(err) {
			return "", err
		}
	}
	fileHash, err := HashFiles(files)
	if err != nil {
		return "", err
	}
	profileFiles := map[string]string{}
	for _, filename := range []string{b.GlobalProfile, filepath.Join(b.CorePath, "cores", b.Core, "cfg", "reg.yaml")} {
		if filename == "" {
			continue
		}
		if _, err := os.Stat(filename); err == nil {
			profileFiles[filename] = filename
		} else if !os.IsNotExist(err) {
			return "", err
		}
	}
	profileHash, err := HashFiles(profileFiles)
	if err != nil {
		return "", err
	}
	payload, err := json.Marshal(struct {
		Core, RunID                                 string
		Build                                       BuildIdentity
		Firmware, FirmwareSHA256, CaptureToolSHA256 string
		Game                                        GameSpec
		FixtureHash, ProfileHash                    string
	}{b.Core, b.Build.RunID, definitionBuild(b.Build), b.Firmware, b.FirmwareSHA256, b.CaptureToolSHA256, game, fileHash, profileHash})
	if err != nil {
		return "", err
	}
	sum := sha256.Sum256(payload)
	return hex.EncodeToString(sum[:]), nil
}

func batchIdentity(b *Batch) (string, error) {
	files := map[string]string{}
	for _, filename := range []string{b.GlobalProfile, filepath.Join(b.CorePath, "cores", b.Core, "cfg", "reg.yaml")} {
		if filename != "" {
			if _, e := os.Stat(filename); e == nil {
				files[filename] = filename
			} else if !os.IsNotExist(e) {
				return "", e
			}
		}
	}
	for _, game := range b.Games {
		for _, filename := range append(append([]string{game.ARC, game.RBF}, game.ROMs...), game.CAB) {
			if filename != "" {
				if _, e := os.Stat(filename); e == nil {
					files[filename] = filename
				} else if !os.IsNotExist(e) {
					return "", e
				}
			}
		}
	}
	fileHash, e := HashFiles(files)
	if e != nil {
		return "", e
	}
	data, e := json.Marshal(struct {
		Core              string
		Build             BuildIdentity
		Firmware          string
		FirmwareSHA256    string
		CaptureToolSHA256 string
		Games             []GameSpec
		Files             string
	}{b.Core, definitionBuild(b.Build), b.Firmware, b.FirmwareSHA256, b.CaptureToolSHA256, b.Games, fileHash})
	if e != nil {
		return "", e
	}
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:]), nil
}

func definitionBuild(build BuildIdentity) BuildIdentity {
	// PR association enriches report routing, not the immutable test definition.
	build.PR = 0
	return build
}

func sameResumeBuild(previous, current BuildIdentity) bool {
	oldPR, newPR := previous.PR, current.PR
	previous.PR, current.PR = 0, 0
	return previous == current && (oldPR == newPR || oldPR == 0 && newPR > 0)
}

func (b *Batch) runGame(game GameSpec) (result GameResult) {
	started := time.Now().UTC()
	result = GameResult{Core: b.Core, Setname: game.Setname, Outcome: Error, Started: started, Attention: true}
	var recordErr error
	finish := func() GameResult {
		result.Finished = time.Now().UTC()
		result.Duration = result.Finished.Sub(started)
		if recordErr != nil {
			result.RecordError = recordErr.Error()
		}
		return result
	}
	log := func(stage string, outcome Outcome, message string, fields any) {
		if recordErr == nil {
			recordErr = b.Log.Write(Event{Setname: game.Setname, Stage: stage, Outcome: outcome, Message: message, Fields: fields})
		}
	}
	if !safeComponent(game.Setname) {
		result.Stage = "inventory"
		result.Message = "unsafe setname"
		log(result.Stage, Error, result.Message, nil)
		return finish()
	}
	if err := clearResultSlots(filepath.Join(b.Root,b.Core,game.Setname)); err != nil {
		result.Stage="publish"; result.Message="clear previous capture slots: "+err.Error(); log(result.Stage,Error,result.Message,nil); return finish()
	}
	if game.Unsupported {
		result.Outcome = Unsupported
		result.Attention = false
		result.Stage = "inventory"
		result.Message = game.UnsupportedReason
		if result.Message == "" {
			result.Message = "known unsupported on SiDi128"
		}
		log(result.Stage, result.Outcome, result.Message, nil)
		return finish()
	}
	if game.PreparationError != "" {
		result.Stage = "prepare"
		result.Message = game.PreparationError
		log(result.Stage, Error, result.Message, game)
		return finish()
	}
	for _, warning := range game.PreparationWarnings {
		log("prepare_warning", "", warning.Message, warning)
	}
	if recordErr != nil {
		result.Stage = "prepare_warning"
		result.Message = "could not record preparation warning: " + recordErr.Error()
		return finish()
	}
	profile, e := ResolveProfile(b.GlobalProfile, b.CorePath, b.Core, game.Setname)
	if e != nil {
		result.Stage = "profile"
		result.Message = e.Error()
		log(result.Stage, Error, result.Message, nil)
		return finish()
	}
	if game.Profile.Video != 0 {
		profile.Video = game.Profile.Video
	}
	if game.Profile.Startup != 0 {
		profile.Startup = game.Profile.Startup
	}
	if game.Profile.Inputs != "" {
		profile.Inputs = game.Profile.Inputs
	}
	if game.Profile.Options != nil {
		for k, v := range game.Profile.Options {
			profile.Options[k] = v
		}
	}
	game.Profile = profile
	_, _, scheduleErr := captureSchedule(profile.Video,100,firstCaptureFrame(profile.Startup))
	if profile.Video <= 0 || profile.Startup < 0 || profile.Startup >= profile.Video || scheduleErr != nil {
		result.Stage = "profile"
		result.Message = "invalid frame/start-up profile"
		log(result.Stage, Error, result.Message, nil)
		return finish()
	}
	if profile.Inputs != "" && game.CAB == "" {
		result.Stage = "profile"
		result.Message = "configured CAB input was not resolved"
		log(result.Stage, Error, result.Message, nil)
		return finish()
	}
	if profile.Video/100 <= profile.Startup/100 {
		result.Stage = "profile"
		result.Message = "profile yields no comparable 100-frame checkpoints after start-up"
		log(result.Stage, Error, result.Message, nil)
		return finish()
	}
	for key := range profile.Options {
		if key != "dipsw" {
			result.Stage = "profile"
			result.Message = fmt.Sprintf("regression cannot apply configured option %q; supported spelling is dipsw", key)
			log(result.Stage, Error, result.Message, profile.Options)
			return finish()
		}
	}
	if e = os.MkdirAll(filepath.Join(b.CorePath, ".cache", "jtutil-regression", "work", b.RunID, b.Core, game.Setname), 0750); e != nil {
		result.Stage = "prepare"
		result.Message = e.Error()
		log(result.Stage, Error, result.Message, nil)
		return finish()
	}
	work := filepath.Join(b.CorePath, ".cache", "jtutil-regression", "work", b.RunID, b.Core, game.Setname)
	defer func() {
		if err := persist_helper_diagnostics(work, filepath.Join(b.Root,"log",b.RunID,b.Core,game.Setname,"helper")); err != nil {
			if result.RecordError!="" { result.RecordError += "; " }
			result.RecordError += fmt.Sprintf("preserve helper diagnostics: %v",err)
		}
		_ = os.RemoveAll(work)
	}()
	cab := game.CAB
	if cab == "" && profile.Inputs != "" {
		cab = profile.Inputs
	}
	if cab != "" && !filepath.IsAbs(cab) {
		cab = filepath.Join(b.CorePath, "cores", b.Core, "ver", game.Setname, cab)
	}
	if cab != "" {
		if _, e = os.Stat(cab); e != nil {
			result.Stage = "prepare"
			result.Message = "configured CAB unavailable: " + e.Error()
			log(result.Stage, Error, result.Message, map[string]string{"cab": cab})
			return finish()
		}
	}
	if cab == "" {
		cab = filepath.Join(work, "neutral.cab")
		if e = os.WriteFile(cab, []byte(fmt.Sprintf("%d\n", profile.Video)), 0600); e != nil {
			result.Stage = "prepare"
			result.Message = e.Error()
			log(result.Stage, Error, result.Message, nil)
			return finish()
		}
	}
	sourceCAB := cab
	game.SourceCAB = sourceCAB
	sourceCABHash, e := file_sha256(sourceCAB)
	if e != nil {
		result.Stage = "identity"
		result.Message = e.Error()
		log(result.Stage, Error, result.Message, map[string]string{"source_cab": sourceCAB})
		return finish()
	}
	if dip, ok := profile.Options["dipsw"]; ok {
		value := fmt.Sprint(dip)
		if parsed, err := strconv.ParseUint(strings.TrimPrefix(strings.ToLower(value), "0x"), 16, 32); err != nil {
			result.Stage = "profile"
			result.Message = "dipsw must be a hexadecimal 32-bit value"
			log(result.Stage, Error, result.Message, dip)
			return finish()
		} else {
			value = strconv.FormatUint(parsed, 16)
		}
		original, err := os.ReadFile(cab)
		if err != nil {
			result.Stage = "prepare"
			result.Message = err.Error()
			log(result.Stage, Error, result.Message, nil)
			return finish()
		}
		cab = filepath.Join(work, "effective.cab")
		if err = os.WriteFile(cab, []byte("dipsw="+value+"\n"+string(original)), 0600); err != nil {
			result.Stage = "prepare"
			result.Message = err.Error()
			return finish()
		}
	}
	load, e := b.Hardware.Load(game)
	if e != nil {
		if len(load.RemoteFiles) > 0 {
			_ = b.Hardware.Cleanup(load.RemoteFiles)
		}
		if health, ok := b.Hardware.(BoardHealth); ok && health.Healthy() != nil {
			result.Stage = "board"
			result.Message = "board unavailable after load failure: " + e.Error()
			log(result.Stage, Error, result.Message, load)
			return finish()
		}
		result.Stage = "load"
		result.Message = e.Error()
		log(result.Stage, Error, result.Message, load)
		return finish()
	}
	remoteFiles := append([]string(nil), load.RemoteFiles...)
	cleanupDone := false
	defer func() {
		if e := func() error {
			if cleanupDone {
				return nil
			}
			return b.Hardware.Cleanup(remoteFiles)
		}(); e != nil {
			result.Stage = "cleanup"
			result.Outcome = Error
			result.Attention = true
			if result.Message != "" {
				result.Message += "; "
			}
			result.Message += e.Error()
			if health, ok := b.Hardware.(BoardHealth); ok && health.Healthy() != nil {
				result.Stage = "board"
			}
			log("cleanup", Error, e.Error(), nil)
		}
		if recordErr != nil {
			result.RecordError = recordErr.Error()
		}
	}()
	log("load", "", "ARC loaded", load)
	run, e := b.Hardware.Run(game, cab, filepath.Join(work, "capture"))
	remoteFiles = append(remoteFiles, run.RemoteFiles...)
	if e != nil {
		if health, ok := b.Hardware.(BoardHealth); ok && health.Healthy() != nil {
			result.Stage = "board"
			result.Message = "board unavailable after capture failure: " + e.Error()
			log(result.Stage, Error, result.Message, run)
			return finish()
		}
		result.Stage = "execute"
		result.Message = e.Error()
		log(result.Stage, Error, result.Message, run)
		return finish()
	}
	log("capture", "", "capture command completed", run)
	candidate, e := ReadCaptureSet(run.CaptureDir, profile.Video, profile.Startup, 100, firstCaptureFrame(profile.Startup))
	if e != nil {
		result.Stage = "validate"
		result.Message = e.Error()
		log(result.Stage, Error, result.Message, run)
		return finish()
	}
	if run.RemoteVideoDir != "" {
		remoteFiles = append(remoteFiles, run.RemoteVideoDir)
	}
	var cabHash string
	if cab != "" {
		cabHash, e = file_sha256(cab)
		if e != nil {
			result.Stage = "identity"
			result.Message = e.Error()
			return finish()
		}
	}
	report, e := ParseCaptureReport(run.Report)
	if e != nil {
		result.Stage = "capture-report"
		result.Message = e.Error()
		log(result.Stage, Error, result.Message, nil)
		return finish()
	}
	if retrieved, ok := report["video_retrieved"].(bool); !ok || !retrieved {
		result.Stage = "capture-report"
		result.Message = "capture report does not confirm verified video retrieval"
		log(result.Stage, Error, result.Message, report)
		return finish()
	}
	remoteVideoDir, ok := report["video_remote_dir"].(string)
	if !ok || !validVideoRemoteDir(remoteVideoDir) {
		result.Stage = "capture-report"
		result.Message = "capture report is missing a valid remote video run directory"
		log(result.Stage, Error, result.Message, report)
		return finish()
	}
	localVideoDir, ok := report["video_local_dir"].(string)
	if !ok || filepath.Clean(localVideoDir) != filepath.Clean(run.CaptureDir) {
		result.Stage = "capture-report"
		result.Message = "capture report local video directory does not match the validated capture set"
		log(result.Stage, Error, result.Message, report)
		return finish()
	}
	remoteCAB, ok := report["remote_cab_path"].(string)
	if !ok || !ownedRemotePath(remoteCAB) || !containsString(run.RemoteFiles, remoteCAB) {
		result.Stage = "capture-report"
		result.Message = "capture report CAB upload path is missing or does not match run-owned cleanup metadata"
		log(result.Stage, Error, result.Message, report)
		return finish()
	}
	if n, ok := report["frames"].(float64); !ok || int(n) != profile.Video {
		result.Stage = "capture-report"
		result.Message = "CAB report frame count does not match profile"
		log(result.Stage, Error, result.Message, report)
		return finish()
	}
	status, ok := report["status"].(map[string]any)
	if !ok {
		result.Stage = "capture-report"
		result.Message = "CAB report has no final firmware status snapshot"
		log(result.Stage, Error, result.Message, report)
		return finish()
	}
	actualFrame, frameErr := strconv.Atoi(fmt.Sprint(status["FRAME"]))
	actualTotal, totalErr := strconv.Atoi(fmt.Sprint(status["TOTAL"]))
	if frameErr != nil || totalErr != nil || actualFrame != profile.Video || actualTotal != profile.Video {
		result.Stage = "capture-report"
		result.Message = fmt.Sprintf("firmware CAB counters are %v/%v; expected %d/%d", status["FRAME"], status["TOTAL"], profile.Video, profile.Video)
		log(result.Stage, Error, result.Message, report)
		return finish()
	}
	if mode, ok := report["cab_clip_mode"].(string); !ok || mode != "prefix" {
		result.Stage = "capture-report"
		result.Message = "CAB report does not confirm profile-prefix clipping"
		log(result.Stage, Error, result.Message, report)
		return finish()
	}
	if n, ok := report["cab_frame_budget"].(float64); !ok || int(n) != profile.Video {
		result.Stage = "capture-report"
		result.Message = "CAB report frame budget does not match profile"
		log(result.Stage, Error, result.Message, report)
		return finish()
	}
	if report["cab_source_sha256"] != sourceCABHash {
		result.Stage = "capture-report"
		result.Message = "CAB report source script hash does not match configured source"
		log(result.Stage, Error, result.Message, report)
		return finish()
	}
	if n, ok := report["capture_every"].(float64); !ok || int(n) != 100 {
		result.Stage = "capture-report"
		result.Message = "capture report cadence is not 100 frames"
		log(result.Stage, Error, result.Message, report)
		return finish()
	}
	if n, ok := report["first_frame"].(float64); !ok || n != float64(firstCaptureFrame(profile.Startup)) {
		result.Stage="capture-report"
		result.Message="capture report first frame does not match start-up"
		log(result.Stage,Error,result.Message,report)
		return finish()
	}
	if report["timebase"] != "native-game-with-validated-video-pauses" {
		result.Stage = "capture-report"
		result.Message = "capture report has unexpected CAB/video timebase"
		log(result.Stage, Error, result.Message, report)
		return finish()
	}
	if report["cab_sha256"] != cabHash {
		result.Stage = "capture-report"
		result.Message = "capture report CAB hash does not match executed script"
		log(result.Stage, Error, result.Message, report)
		return finish()
	}
	if digest, ok := report["packed_sha256"].(string); !ok || len(digest) != 64 {
		result.Stage = "capture-report"
		result.Message = "capture report is missing packed CAB identity"
		log(result.Stage, Error, result.Message, report)
		return finish()
	}
	firmware := load.Firmware
	if value, ok := report["firmware"].(string); ok && value != "" {
		firmware = value
	}
	if firmware == "" {
		result.Stage = "identity"
		result.Message = "capture report has no firmware identity"
		log(result.Stage, Error, result.Message, report)
		return finish()
	}
	if e = b.Hardware.Cleanup(remoteFiles); e != nil {
		cleanupDone = true
		result.Stage = "cleanup"
		result.Message = e.Error()
		log(result.Stage, Error, result.Message, nil)
		if health, ok := b.Hardware.(BoardHealth); ok && health.Healthy() != nil {
			result.Stage = "board"
		}
		return finish()
	}
	cleanupDone = true
	if b.Firmware != "" && firmware != b.Firmware {
		result.Stage = "identity"
		result.Message = fmt.Sprintf("board firmware %q does not match configured firmware %q", firmware, b.Firmware)
		log(result.Stage, Error, result.Message, report)
		return finish()
	}
	if b.FirmwareSHA256 == "" || b.CaptureToolSHA256 == "" {
		result.Stage = "identity"
		result.Message = "firmware binary and capture client SHA256 identities must be configured"
		log(result.Stage, Error, result.Message, nil)
		return finish()
	}
	roms := make(map[string]string, len(game.ROMs))
	for _, filename := range game.ROMs {
		roms[filepath.Base(filename)] = filename
	}
	definition, e := TestDefinitionIdentityWithCapture(b.Core, game.Setname, profile, roms, map[string]string{filepath.Base(game.ARC): game.ARC}, cab, firmware, b.FirmwareSHA256, b.CaptureToolSHA256, candidate.Format, sourceCAB, "prefix", profile.Video)
	if e != nil {
		result.Stage = "identity"
		result.Message = e.Error()
		log(result.Stage, Error, result.Message, nil)
		return finish()
	}
	metadata := GameMetadata{Build: b.Build, ProjectSHA: b.ProjectSHA, TestIdentity: definition, Profile: profile, CABSHA256: cabHash, CABSourceSHA256: sourceCABHash, CABClipMode: "prefix", CABFrameBudget: profile.Video, RBF: game.RBF, ROMs: game.ROMs, ARC: game.ARC, Firmware: firmware, FirmwareSHA256: b.FirmwareSHA256, CaptureToolSHA256: b.CaptureToolSHA256, CaptureFormat: candidate.Format, Frames: profile.Video, Cadence: 100, Startup: profile.Startup, PreparationWarnings: append([]PreparationWarning(nil), game.PreparationWarnings...)}
	metadata.RBFHash, e = file_sha256(game.RBF)
	if e != nil {
		result.Stage = "identity"
		result.Message = e.Error()
		return finish()
	}
	metadata.FixtureHashes = make(map[string]string)
	fixtures := []struct{ key, path string }{{"arc/" + filepath.Base(game.ARC), game.ARC}, {"cab/input/" + filepath.Base(cab), cab}, {"cab/source/" + filepath.Base(sourceCAB), sourceCAB}}
	for _, filename := range game.ROMs {
		fixtures = append(fixtures, struct{ key, path string }{"rom/" + filepath.Base(filename), filename})
	}
	for _, fixture := range fixtures {
		filename := fixture.path
		hash, err := file_sha256(filename)
		if err != nil {
			result.Stage = "identity"
			result.Message = err.Error()
			return finish()
		}
		metadata.FixtureHashes[fixture.key] = hash
	}
	if run.Report != "" {
		raw, _ := os.ReadFile(run.Report)
		metadata.CaptureReport = raw
	}
	gameRoot := filepath.Join(b.Root, b.Core, game.Setname)
	ref := filepath.Join(gameRoot, "ref")
	receipt := b.capture_receipt(game.Setname)
	if e = os.RemoveAll(receipt); e == nil { e = os.MkdirAll(receipt, 0750) }
	if e == nil { e = write_capture_receipt(receipt, candidate) }
	if e == nil { e = write_metadata(receipt, metadata) }
	if e == nil { e = copyFile(filepath.Join(run.CaptureDir, "index.jsonl"), filepath.Join(receipt, "transport-index.jsonl")) }
	if e != nil { result.Stage = "record"; result.Message = e.Error(); return finish() }
	qualityFailure, qualityErr := captureQualityFailure(candidate,profile.Startup)
	if qualityErr != nil { result.Stage="quality"; result.Message=qualityErr.Error(); log(result.Stage,Error,result.Message,nil); return finish() }
	if qualityFailure != "" {
		if e = PublishComplete(gameRoot,run.CaptureDir,Fail,metadata); e != nil { result.Stage="publish"; result.Message=e.Error(); return finish() }
		result.Outcome=Fail; result.TestIdentity=definition; result.Stage="quality"; result.Message=qualityFailure
		log(result.Stage,Fail,result.Message,nil)
		return finish()
	}
	if _, e = os.Stat(ref); os.IsNotExist(e) {
		if e = PublishComplete(gameRoot, run.CaptureDir, New, metadata); e != nil {
			result.Stage = "publish"
			result.Message = e.Error()
			return finish()
		}
		result.Outcome = New
		result.Stage = "reference"
		result.Message = "no approved reference"
		result.Attention = true
		log(result.Stage, result.Outcome, result.Message, metadata)
		result.TestIdentity = definition
		return finish()
	} else if e != nil {
		result.Stage = "reference"
		result.Message = e.Error()
		log(result.Stage, Error, result.Message, nil)
		return finish()
	}
	reference, e := readHistoricalCaptureSet(ref, profile.Video, profile.Startup, 100)
	if e != nil {
		result.Stage = "reference"
		result.Message = "approved reference invalid: " + e.Error()
		log(result.Stage, Error, result.Message, nil)
		return finish()
	}
	diffs, e := CompareCaptureSets(reference, candidate, profile.Startup)
	if e != nil {
		result.Stage = "compare"
		result.Message = e.Error()
		log(result.Stage, Error, result.Message, nil)
		return finish()
	}
	if len(diffs) > 0 {
		diffData, _ := json.MarshalIndent(map[string]any{"candidate_test_identity": definition, "frames": diffs}, "", "  ")
		if e = os.WriteFile(filepath.Join(receipt, "comparison.json"), append(diffData, '\n'), 0640); e != nil {
			result.Stage = "publish"
			result.Message = e.Error()
			return finish()
		}
		if e = PublishComplete(gameRoot, run.CaptureDir, Fail, metadata); e != nil {
			result.Stage = "publish"
			result.Message = e.Error()
			return finish()
		}
		result.Outcome = Fail
		result.TestIdentity = definition
		result.Stage = "compare"
		result.Message = fmt.Sprintf("%d comparable checkpoints differ", len(diffs))
		log(result.Stage, Fail, result.Message, diffs)
	} else {
		if e = PublishComplete(gameRoot, run.CaptureDir, Pass, metadata); e != nil {
			result.Stage = "publish"
			result.Message = e.Error()
			return finish()
		}
		result.Outcome = Pass
		result.TestIdentity = definition
		result.Stage = "compare"
		result.Attention = false
		result.Message = "all comparable checkpoints match exactly"
		log(result.Stage, Pass, result.Message, nil)
	}
	return finish()
}

func validVideoRemoteDir(path string) bool {
	parts := strings.Split(path, "/")
	// Canonical FTP path: /video/<core>/run_<8hex>_<8hex>.
	return len(parts) == 4 && parts[0] == "" && parts[1] == "video" && safeComponent(parts[2]) && validVideoRunName(parts[3])
}

func validVideoRunName(name string) bool {
	if len(name) != len("run_")+8+1+8 || !strings.HasPrefix(name, "run_") || name[12] != '_' {
		return false
	}
	for _, c := range name[4:] {
		if !(c >= '0' && c <= '9' || c >= 'a' && c <= 'f' || c == '_') {
			return false
		}
	}
	return true
}

func containsString(list []string, value string) bool {
	for _, item := range list {
		if item == value {
			return true
		}
	}
	return false
}

func (b *Batch) capture_receipt(setname string) string {
	return filepath.Join(b.Root, "log", b.RunID, b.Core, setname, "capture")
}

func (b *Batch) verifyFinalized(game GameSpec, result GameResult) bool {
	if result.Outcome == Error || result.Outcome == Unsupported { return true }
	receipt := b.capture_receipt(game.Setname)
	meta, e := read_metadata(receipt)
	if e != nil || meta.TestIdentity == "" || !sameResumeBuild(meta.Build, b.Build) || meta.TestIdentity != result.TestIdentity { return false }
	profile, e := resolvedGameProfile(b, game)
	if e != nil { return false }
	hashes, legacy, e := read_capture_receipt(receipt, profile, meta.CaptureFormat)
	if e != nil { return false }
	slot := string(result.Outcome)
	if result.Outcome == Pass { slot = "ref" }
	published_dir := filepath.Join(b.Root, b.Core, game.Setname, slot)
	if result.Outcome == New {
		if _, stat_error := os.Stat(published_dir); os.IsNotExist(stat_error) { published_dir = filepath.Join(b.Root, b.Core, game.Setname, "ref") }
	}
	published, e := readHistoricalCaptureSet(published_dir, profile.Video, profile.Startup, 100)
	if e != nil { return false }
	cutoff := 0
	if result.Outcome == Pass { cutoff = profile.Startup }
	if !receipt_matches_pngs(hashes, published, cutoff) { return false }
	if result.Outcome == Fail && result.Stage == "quality" {
		message, qualityErr := captureQualityFailure(published,profile.Startup)
		if qualityErr != nil || message == "" || message != result.Message { return false }
	}
	if b.read_only_receipts {return true}
	if legacy { if e = save_capture_receipt(receipt, hashes); e != nil { return false } }
	return remove_legacy_receipt_pngs(receipt, hashes) == nil
}

func read_metadata(dir string) (GameMetadata, error) {
	var metadata GameMetadata
	data, e := os.ReadFile(filepath.Join(dir, "metadata.json"))
	if e != nil {
		return metadata, e
	}
	e = json.Unmarshal(data, &metadata)
	return metadata, e
}

// Retain only named helper text/JSON artifacts before transient images and CAB
// files are discarded, including on failed or timed-out executions.
func persist_helper_diagnostics(work, destination string) error {
	for _, name := range []string{"helper-progress.log","ftp-report.json","ftp-report.json.upload.json"} {
		path := filepath.Join(work,name)
		info, err := os.Lstat(path)
		if os.IsNotExist(err) { continue }; if err != nil { return err }
		if !info.Mode().IsRegular() { return fmt.Errorf("helper diagnostic is not a regular file: %s",name) }
		if err = os.MkdirAll(destination,0750); err != nil { return err }
		if err = copyFile(path,filepath.Join(destination,name)); err != nil { return err }
	}
	return nil
}
