/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type miSTerQualificationEvidence struct {
	Schema          int               `json:"schema"`
	Target          string            `json:"target"`
	Generation      string            `json:"generation"`
	Convention      CaptureConvention `json:"convention"`
	QualificationID string            `json:"qualification_id"`
	MainSHA256      string            `json:"main_sha256"`
	Qualified       bool              `json:"qualified"`
}

// ReadMiSTerQualification verifies the machine-readable reviewed evidence
// against the selected strict config. A nonempty evidence path or ID alone
// never qualifies a capture lane.
func ReadMiSTerQualification(cfg Config) (CaptureQualification, error) {
	var result CaptureQualification
	if cfg.CaptureContract == nil {
		return result, fmt.Errorf("MiSTer capture-contract is missing")
	}
	if err := cfg.ValidateMiSTer(); err != nil {
		return result, err
	}
	filename := cfg.CaptureContract.QualificationEvidence
	if strings.HasPrefix(filename, "~/") {
		home, err := os.UserHomeDir()
		if err != nil {
			return result, err
		}
		filename = filepath.Join(home, strings.TrimPrefix(filename, "~/"))
	}
	info, err := os.Lstat(filename)
	if err != nil || !info.Mode().IsRegular() || info.Mode()&os.ModeSymlink != 0 || info.Size() < 1 || info.Size() > 1<<20 {
		return result, fmt.Errorf("MiSTer qualification evidence must be a bounded regular file")
	}
	data, err := os.ReadFile(filename)
	if err != nil {
		return result, err
	}
	var evidence miSTerQualificationEvidence
	decoder := json.NewDecoder(strings.NewReader(string(data)))
	decoder.DisallowUnknownFields()
	if err = decoder.Decode(&evidence); err != nil {
		return result, fmt.Errorf("decode MiSTer qualification evidence: %w", err)
	}
	var trailing any
	if err = decoder.Decode(&trailing); err != io.EOF {
		return result, fmt.Errorf("MiSTer qualification evidence has trailing JSON")
	}
	contract := cfg.CaptureContract
	if evidence.Schema != 1 || evidence.Target != "mister" || !evidence.Qualified || evidence.Generation != contract.Generation || evidence.Convention != contract.Convention || evidence.QualificationID != contract.QualificationID || evidence.MainSHA256 != contract.MainSHA256 {
		return result, fmt.Errorf("MiSTer qualification evidence does not exactly match configured generation, convention, ID and Main hash")
	}
	return CaptureQualification{Target: evidence.Target, Generation: evidence.Generation, Convention: evidence.Convention, QualificationID: evidence.QualificationID, Qualified: true}, nil
}

// BuildMiSTerPoolBoards constructs one private transport/driver per configured
// board. Session inputs are routed by portable identity and never stored in
// the shared progress log.
func BuildMiSTerPoolBoards(cfg Config, prepared []MiSTerPreparedGame, dataRoot string) ([]PoolBoard, error) {
	if err := cfg.ValidateMiSTerRun(); err != nil {
		return nil, err
	}
	// Validate every projected board driver before persisting any prepared CAB.
	// This uses the driver's own local validation rules, so config and runtime
	// bounds cannot drift and no worker can dispatch with an invalid deadline.
	drivers := make(map[BoardKey]*MiSTerSessionDriver, len(cfg.Boards))
	for _, board := range cfg.Boards {
		driver, err := newMiSTerPoolDriver(cfg, board, dataRoot)
		if err != nil {
			return nil, err
		}
		drivers[BoardKey(board.ID)] = driver
	}
	inputsByBoard := make(map[BoardKey]map[string]MiSTerSessionInputs, len(cfg.Boards))
	for _, item := range prepared {
		identity, err := item.Job.Session.PortableIdentity()
		if err != nil {
			return nil, err
		}
		if item.Spec.MisterAssets == nil {
			return nil, fmt.Errorf("prepared game %s/%s has no typed MiSTer assets", item.Job.Session.Core, item.Job.Session.Setname)
		}
		stem := "jt224-" + item.Job.Session.RBF.SHA256[:24]
		cabPath, err := writeMiSTerInputCAB(dataRoot, identity, item.PackedCAB, item.Job.Session.CAB.PackedSHA256)
		if err != nil {
			return nil, err
		}
		input := MiSTerSessionInputs{FixturePaths: map[FixtureRole]string{
			FixtureOriginalMRA: item.Spec.MisterAssets.OriginalMRA.Path,
			FixtureLaunchMRA:   item.Spec.MisterAssets.LaunchMRA.Path,
			FixtureRBF:         item.Spec.RBF,
		}, PackedCABPath: cabPath, NativeStatusPath: item.Spec.MisterAssets.NativeStatus.NativeStatusPath,
			RBFStem: stem, ExpectedCoreName: item.Job.Session.Setname, ExpectedRBFName: item.Job.Session.Core}
		for _, fixture := range item.Job.Session.Fixtures {
			var path string
			for _, asset := range append(append([]MiSTerAssetFile(nil), item.Spec.MisterAssets.ROMArchives...), item.Spec.MisterAssets.DefaultRAM...) {
				if asset.Role == fixture.Role && asset.SHA256 == fixture.SHA256 {
					if path != "" {
						return nil, miSTerGameInputError(fmt.Errorf("prepared fixture mapping is ambiguous for %s/%s", fixture.Role, fixture.SHA256))
					}
					path = asset.Path
				}
			}
			if path == "" {
				return nil, fmt.Errorf("prepared fixture mapping is missing for %s/%s", fixture.Role, fixture.SHA256)
			}
			input.FixtureFiles = append(input.FixtureFiles, MiSTerFixtureFile{Role: fixture.Role, SHA256: fixture.SHA256, Path: path})
		}
		for _, board := range cfg.Boards {
			key := BoardKey(board.ID)
			attempt := AttemptKey{Board: key, SessionID: item.Job.SessionID, Nonce: item.Job.Nonce}
			if err := drivers[key].ValidatePreparedAttempt(attempt, item.Job.Session, input); err != nil {
				return nil, fmt.Errorf("validate MiSTer runtime inputs for %s/%s on board %s: %w", item.Job.Session.Core, item.Job.Session.Setname, board.ID, err)
			}
			if inputsByBoard[key] == nil {
				inputsByBoard[key] = make(map[string]MiSTerSessionInputs)
			}
			inputsByBoard[key][identity] = input
		}
	}
	boards := make([]PoolBoard, 0, len(cfg.Boards))
	for _, board := range cfg.Boards {
		key := BoardKey(board.ID)
		adapter := &miSTerSessionInputRouter{driver: drivers[key], inputs: inputsByBoard[key]}
		boards = append(boards, PoolBoard{Key: key, Host: board.Host, Driver: adapter})
	}
	return boards, nil
}

func newMiSTerPoolDriver(cfg Config, board MiSTerBoardConfig, dataRoot string) (*MiSTerSessionDriver, error) {
	if board.RemoteStagingRoot != "/media/fat/_Arcade" {
		return nil, fmt.Errorf("board %s remote-staging-root must be /media/fat/_Arcade for the current driver", board.ID)
	}
	sshConfig := expandExternalPath(board.SSHConfig)
	info, err := os.Lstat(sshConfig)
	if err != nil || !info.Mode().IsRegular() || info.Mode()&os.ModeSymlink != 0 {
		return nil, fmt.Errorf("board %s SSH config must resolve to a regular external file", board.ID)
	}
	identityFile := expandExternalPath(board.IdentityFile)
	if identityFile != "" {
		identityInfo, statErr := os.Lstat(identityFile)
		if statErr != nil || !identityInfo.Mode().IsRegular() || identityInfo.Mode()&os.ModeSymlink != 0 {
			return nil, fmt.Errorf("board %s identity file must resolve to a regular external file", board.ID)
		}
	}
	stateDir := filepath.Join(dataRoot, "log", ".mister-state", board.ID)
	workspaceDir := filepath.Join(dataRoot, "log", ".mister-workspaces", board.ID)
	remote := MiSTerSSHRemote{Config: MiSTerSSHConfig{Host: board.Host, User: board.User, Port: 22,
		IdentityFile: identityFile, SSH: "ssh", SCP: "scp", SSHPass: "sshpass",
		PasswordEnv: externalPasswordVariable(board.ID), Timeout: time.Duration(cfg.CaptureContract.CommandTimeoutSeconds) * time.Second},
		Runner: MiSTerSSHConfigRunner{Base: MiSTerExecRunner{}, Path: sshConfig}}
	driver := &MiSTerSessionDriver{Config: MiSTerDriverConfig{BoardKey: BoardKey(board.ID), HostName: board.Host,
		MainSHA256: cfg.CaptureContract.MainSHA256, MainINIPath: "/media/fat/MiSTer.ini", LocalStateDir: stateDir,
		WorkspaceDir: workspaceDir, CommandTimeout: time.Duration(cfg.CaptureContract.CommandTimeoutSeconds) * time.Second,
		LoadTimeout: time.Duration(cfg.CaptureContract.LoadTimeoutSeconds) * time.Second, CaptureTimeout: time.Duration(cfg.CaptureContract.CaptureTimeoutSeconds) * time.Second,
		CleanupTimeout: time.Duration(cfg.CaptureContract.CleanupTimeoutSeconds) * time.Second, MaxHoldMS: cfg.CaptureContract.MaxHoldMS,
		ExpectedBridgeCount: cfg.CaptureContract.ExpectedBridgeCount}, Remote: remote}
	if err = driver.ValidateLocalConfig(); err != nil {
		return nil, fmt.Errorf("board %s local MiSTer driver config: %w", board.ID, err)
	}
	if err = ensureNoSymlinkPath(dataRoot, stateDir); err != nil {
		return nil, err
	}
	if err = ensureNoSymlinkPath(dataRoot, workspaceDir); err != nil {
		return nil, err
	}
	return driver, nil
}

func writeMiSTerInputCAB(dataRoot, portableID string, packed []byte, expectedSHA string) (string, error) {
	if !isSHA256Hex(portableID) || !isSHA256Hex(expectedSHA) || len(packed) == 0 {
		return "", fmt.Errorf("MiSTer packed CAB identity is incomplete")
	}
	digest := sha256.Sum256(packed)
	if hex.EncodeToString(digest[:]) != expectedSHA {
		return "", fmt.Errorf("MiSTer packed CAB bytes do not match their prepared digest")
	}
	root := filepath.Join(dataRoot, "log", ".mister-inputs")
	if err := os.MkdirAll(root, 0700); err != nil {
		return "", err
	}
	if err := ensureNoSymlinkPath(dataRoot, root); err != nil {
		return "", err
	}
	filename := filepath.Join(root, portableID+".jtcab")
	if info, err := os.Lstat(filename); err == nil {
		if !info.Mode().IsRegular() || info.Mode()&os.ModeSymlink != 0 {
			return "", fmt.Errorf("existing private MiSTer CAB path is not a regular file")
		}
		data, readErr := os.ReadFile(filename)
		if readErr != nil {
			return "", readErr
		}
		if !bytes.Equal(data, packed) {
			return "", fmt.Errorf("existing private MiSTer CAB path has different bytes")
		}
		return filename, nil
	} else if !os.IsNotExist(err) {
		return "", err
	}
	file, err := os.OpenFile(filename, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return "", err
	}
	_, writeErr := file.Write(packed)
	syncErr := file.Sync()
	closeErr := file.Close()
	if err = errors.Join(writeErr, syncErr, closeErr); err != nil {
		_ = os.Remove(filename)
		return "", err
	}
	return filename, nil
}

func expandExternalPath(value string) string {
	if strings.HasPrefix(value, "~/") {
		if home, err := os.UserHomeDir(); err == nil {
			return filepath.Join(home, strings.TrimPrefix(value, "~/"))
		}
	}
	return value
}

func externalPasswordVariable(boardID string) string {
	var result strings.Builder
	result.WriteString("JTFRAME_MISTER_")
	for _, r := range strings.ToUpper(boardID) {
		if r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' {
			result.WriteRune(r)
		} else {
			result.WriteByte('_')
		}
	}
	result.WriteString("_SSHPASS")
	name := result.String()
	if os.Getenv(name) == "" {
		return ""
	}
	return name
}

type miSTerSessionInputRouter struct {
	driver *MiSTerSessionDriver
	inputs map[string]MiSTerSessionInputs
}

func (r *miSTerSessionInputRouter) Capture(ctx context.Context, key AttemptKey, prepared PreparedSession) (SessionCapture, error) {
	identity, err := prepared.PortableIdentity()
	if err != nil {
		return SessionCapture{}, err
	}
	input, ok := r.inputs[identity]
	if !ok {
		return SessionCapture{}, fmt.Errorf("board has no immutable MiSTer input mapping for this prepared session")
	}
	return r.driver.CapturePrepared(ctx, key, prepared, input)
}

func (r *miSTerSessionInputRouter) Cancel(ctx context.Context, key AttemptKey) error {
	return r.driver.Cancel(ctx, key)
}

func (r *miSTerSessionInputRouter) Reconcile(ctx context.Context, key AttemptKey) (SessionCleanup, error) {
	return r.driver.Reconcile(ctx, key)
}

func (r *miSTerSessionInputRouter) Healthy(ctx context.Context) error {
	return r.driver.Healthy(ctx)
}

func newMiSTerJobTokens() (string, string, error) {
	var random [24]byte
	if _, err := rand.Read(random[:]); err != nil {
		return "", "", err
	}
	return "mister-" + hex.EncodeToString(random[:8]), hex.EncodeToString(random[8:]), nil
}
