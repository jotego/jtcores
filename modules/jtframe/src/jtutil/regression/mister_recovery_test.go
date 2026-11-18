/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func validRecoveryReceipt(id string, pid int) MiSTerCaptureRecoveryReceipt {
	return MiSTerCaptureRecoveryReceipt{Protocol: "jtframe-capture-recovery-v1", Version: 1,
		RecoveryID: id, MainPID: pid, Success: true, Reason: "recovered", FPGAGeneration: 1,
		FullRBFWitness: true, LocalCleanupConfirmed: true, CAPSRead: true, CAPSValid: true,
		CAPSWords: []uint16{0xca50, 2, 64, 0, 0, 0, 0, 0}}
}

func unsupportedProgramReceipt(id string, pid int) MiSTerCaptureRecoveryReceipt {
	r := validRecoveryReceipt(id, pid)
	r.Success = false
	r.Reason = "caps_invalid"
	r.ReloadRequired = true
	r.CAPSValid = false
	r.LocalCleanupConfirmed = false
	r.CAPSWords[0] = 0xca50
	return r
}

func TestMiSTerOriginalProgramWitnessAcceptsCapsInvalidOnlyAsProgramEvidence(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
	liveStatus, err := decodeMiSTerCaptureStatusV2(remote.startFiles["/tmp/jtframe-capture-"+key.SessionID+".json"])
	if err != nil || liveStatus.CaptureProtocol != miSTerCaptureProtocolV2 {
		t.Fatalf("live capture fixture is not Main v2: status=%+v err=%v", liveStatus, err)
	}
	remote.originalProgramReceipt = func(id string, snapshot MiSTerBoardSnapshot) []byte {
		return marshalRecoveryReceipt(t, unsupportedProgramReceipt(id, snapshot.MainPID))
	}
	result, err := driver.CapturePrepared(context.Background(), key, prepared, inputs)
	if err != nil || !result.Cleanup.Confirmed {
		t.Fatalf("caps_invalid full-program witness was not accepted for restore cleanup: cleanup=%+v err=%v", result.Cleanup, err)
	}
	var evidencePath string
	for name := range localStateFiles(t, driver.Config.LocalStateDir) {
		if strings.Contains(name, "restore-witness-") {
			evidencePath = name
		}
	}
	if evidencePath == "" {
		t.Fatal("original-program raw receipt was not retained as private evidence")
	}
	data, err := os.ReadFile(evidencePath)
	if err != nil {
		t.Fatal(err)
	}
	var witness miSTerOriginalProgramWitness
	if err = json.Unmarshal(data, &witness); err != nil {
		t.Fatal(err)
	}
	raw, err := base64.StdEncoding.DecodeString(witness.ReceiptRawBase64)
	if err != nil || digestBytes(raw) != witness.ReceiptSHA256 {
		t.Fatalf("retained original receipt bytes/hash differ: %v", err)
	}
	receipt, err := DecodeMiSTerCaptureRecoveryReceipt(raw)
	if err != nil || receipt.Success || receipt.Reason != "caps_invalid" || !receipt.FullRBFWitness || receipt.FPGAGeneration == 0 || witness.ReceiptSuccess {
		t.Fatalf("program-only evidence was confused with successful capture cleanup: witness=%+v receipt=%+v err=%v", witness, receipt, err)
	}
	if witness.ExpectedSnapshot.MainPID != receipt.MainPID || !originalLoaderMatches(witness.ExpectedSnapshot, miSTerBoardLedger{OriginalLoaderKind: "mra", OriginalRBFArgv: witness.ExpectedRBFArgv, OriginalMRAPath: witness.ExpectedMRAArgv}) {
		t.Fatalf("retained receipt is not tied to the exact original loader snapshot: %+v", witness.ExpectedSnapshot)
	}
}

func localStateFiles(t *testing.T, directory string) map[string][]byte {
	t.Helper()
	entries, err := os.ReadDir(directory)
	if err != nil {
		t.Fatal(err)
	}
	files := make(map[string][]byte)
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		data, readErr := os.ReadFile(filepath.Join(directory, entry.Name()))
		if readErr != nil {
			t.Fatal(readErr)
		}
		files[filepath.Join(directory, entry.Name())] = data
	}
	return files
}

func TestMiSTerOriginalProgramWitnessRejectsUnprovenRestoreAndRetainsQuarantine(t *testing.T) {
	for _, test := range []struct {
		name          string
		mutate        func(string, MiSTerBoardSnapshot) []byte
		mutateProcess func(*fakeMiSTerRemote)
	}{
		{"ordinary restart without full-RBF event", func(id string, s MiSTerBoardSnapshot) []byte {
			r := validRecoveryReceipt(id, s.MainPID)
			r.Success = false
			r.Reason = "no_full_rbf_witness"
			r.FPGAGeneration = 0
			r.FullRBFWitness = false
			return marshalRecoveryReceipt(t, r)
		}, nil},
		{"missing full-RBF witness", func(id string, s MiSTerBoardSnapshot) []byte {
			r := unsupportedProgramReceipt(id, s.MainPID)
			r.FullRBFWitness = false
			return marshalRecoveryReceipt(t, r)
		}, nil},
		{"zero generation", func(id string, s MiSTerBoardSnapshot) []byte {
			r := unsupportedProgramReceipt(id, s.MainPID)
			r.FPGAGeneration = 0
			return marshalRecoveryReceipt(t, r)
		}, nil},
		{"unrelated Main failure", func(id string, s MiSTerBoardSnapshot) []byte {
			r := unsupportedProgramReceipt(id, s.MainPID)
			r.Reason = "local_cleanup_failed"
			return marshalRecoveryReceipt(t, r)
		}, nil},
		{"stale receipt ID", func(_ string, s MiSTerBoardSnapshot) []byte {
			return marshalRecoveryReceipt(t, unsupportedProgramReceipt("stale-id", s.MainPID))
		}, nil},
		{"wrong event PID", func(id string, _ MiSTerBoardSnapshot) []byte {
			return marshalRecoveryReceipt(t, unsupportedProgramReceipt(id, 999))
		}, nil},
		{"process argv changed after receipt", func(id string, s MiSTerBoardSnapshot) []byte {
			return marshalRecoveryReceipt(t, unsupportedProgramReceipt(id, s.MainPID))
		}, func(r *fakeMiSTerRemote) {
			if r.originalLoaded {
				r.probe.ArgvMRA = "/media/fat/_Arcade/other.mra"
			}
		}},
		{"process executable changed after receipt", func(id string, s MiSTerBoardSnapshot) []byte {
			return marshalRecoveryReceipt(t, unsupportedProgramReceipt(id, s.MainPID))
		}, func(r *fakeMiSTerRemote) {
			if r.originalLoaded {
				r.probe.MainExePath = "/tmp/other-Main"
			}
		}},
	} {
		t.Run(test.name, func(t *testing.T) {
			remote := newFakeMiSTerRemote()
			driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
			remote.originalProgramReceipt = test.mutate
			if test.mutateProcess != nil {
				remote.afterRecovery = test.mutateProcess
			}
			result, err := driver.CapturePrepared(context.Background(), key, prepared, inputs)
			if err == nil || result.Cleanup.Confirmed {
				t.Fatalf("unproven original program was reported clean: result=%+v err=%v", result.Cleanup, err)
			}
			ledger, readErr := readMiSTerLedger(driver.ledgerName())
			if readErr != nil || ledger.State != "quarantined" || len(ledger.OriginalProgramWitnesses) != 1 || ledger.OriginalProgramWitnesses[0].ReceiptRawBase64 == "" {
				t.Fatalf("unproven original program did not retain raw receipt/quarantine: ledger=%+v err=%v", ledger, readErr)
			}
			if _, exists := remote.files[ledger.RemoteLock]; !exists {
				t.Fatal("unproven original program released the remote board lease")
			}
		})
	}
}

func marshalRecoveryReceipt(t *testing.T, receipt MiSTerCaptureRecoveryReceipt) []byte {
	t.Helper()
	data, err := json.Marshal(receipt)
	if err != nil {
		t.Fatal(err)
	}
	return data
}

func TestDecodeMiSTerCaptureRecoveryReceiptRequiresConsistentCleanProof(t *testing.T) {
	valid := validRecoveryReceipt("fresh-id_1", 123)
	if _, err := DecodeMiSTerCaptureRecoveryReceipt(marshalRecoveryReceipt(t, valid)); err != nil {
		t.Fatalf("valid clean receipt rejected: %v", err)
	}
	tests := []struct {
		name   string
		mutate func(*MiSTerCaptureRecoveryReceipt)
	}{
		{"zero generation", func(r *MiSTerCaptureRecoveryReceipt) { r.FPGAGeneration = 0 }},
		{"missing full program witness", func(r *MiSTerCaptureRecoveryReceipt) { r.FullRBFWitness = false }},
		{"reload required", func(r *MiSTerCaptureRecoveryReceipt) { r.ReloadRequired = true }},
		{"local cleanup absent", func(r *MiSTerCaptureRecoveryReceipt) { r.LocalCleanupConfirmed = false }},
		{"encoder busy", func(r *MiSTerCaptureRecoveryReceipt) { r.EncoderBusy = true }},
		{"schedule active", func(r *MiSTerCaptureRecoveryReceipt) { r.ScheduleActive = true }},
		{"capture active", func(r *MiSTerCaptureRecoveryReceipt) { r.CaptureActive = true }},
		{"CAB active", func(r *MiSTerCaptureRecoveryReceipt) { r.CABActive = true }},
		{"CAPS unread", func(r *MiSTerCaptureRecoveryReceipt) { r.CAPSRead = false }},
		{"CAPS invalid", func(r *MiSTerCaptureRecoveryReceipt) { r.CAPSValid = false }},
		{"CAPS busy", func(r *MiSTerCaptureRecoveryReceipt) { r.CAPSWords[3] = 1 }},
		{"CAPS armed", func(r *MiSTerCaptureRecoveryReceipt) { r.CAPSWords[3] = 2 }},
		{"CAPS ready", func(r *MiSTerCaptureRecoveryReceipt) { r.CAPSWords[3] = 4 }},
		{"CAPS draining", func(r *MiSTerCaptureRecoveryReceipt) { r.CAPSWords[3] = 0x20 }},
		{"CAPS fault code without flag", func(r *MiSTerCaptureRecoveryReceipt) { r.CAPSWords[3] = 0x0100 }},
		{"bad CAPS magic", func(r *MiSTerCaptureRecoveryReceipt) { r.CAPSWords[0] = 0 }},
		{"contradictory reason", func(r *MiSTerCaptureRecoveryReceipt) { r.Reason = "caps_not_idle" }},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			receipt := valid
			receipt.CAPSWords = append([]uint16(nil), valid.CAPSWords...)
			test.mutate(&receipt)
			if _, err := DecodeMiSTerCaptureRecoveryReceipt(marshalRecoveryReceipt(t, receipt)); err == nil {
				t.Fatal("contradictory success proof accepted")
			}
		})
	}
	for _, data := range [][]byte{
		[]byte(`{"protocol":"jtframe-capture-recovery-v1","protocol":"jtframe-capture-recovery-v1"}`),
		append(marshalRecoveryReceipt(t, valid), []byte(` {}`)...),
		[]byte(strings.Repeat("x", maxMiSTerRecoveryReceiptBytes+1)),
	} {
		if _, err := DecodeMiSTerCaptureRecoveryReceipt(data); err == nil {
			t.Fatal("duplicate, trailing, or oversized recovery receipt accepted")
		}
	}
}

func TestMiSTerRecoveryCAPSUsesV2WireAndReservedWords(t *testing.T) {
	valid := validRecoveryReceipt("fresh-id-v2", 123)
	valid.CAPSWords[3] = 0x40
	if _, err := DecodeMiSTerCaptureRecoveryReceipt(marshalRecoveryReceipt(t, valid)); err != nil { t.Fatalf("idle checksum-format CAPS rejected: %v", err) }
	valid.CAPSWords[3] = 0
	valid.CAPSWords[4] = 0xffff
	valid.CAPSWords[6] = 0xfffe
	if _, err := DecodeMiSTerCaptureRecoveryReceipt(marshalRecoveryReceipt(t, valid)); err != nil {
		t.Fatalf("v2 CAPS with fresh counters and zero reserved words rejected: %v", err)
	}
	valid.CAPSWords[3] = 0x0010
	if _, err := DecodeMiSTerCaptureRecoveryReceipt(marshalRecoveryReceipt(t, valid)); err != nil {
		t.Fatalf("v2 CAPS with the remaining clean flag rejected: %v", err)
	}
	for _, test := range []struct {
		name   string
		mutate func(*MiSTerCaptureRecoveryReceipt)
	}{
		{"legacy CAPS version", func(r *MiSTerCaptureRecoveryReceipt) { r.CAPSWords[1] = 1 }},
		{"reserved word five", func(r *MiSTerCaptureRecoveryReceipt) { r.CAPSWords[5] = 1 }},
		{"reserved word seven", func(r *MiSTerCaptureRecoveryReceipt) { r.CAPSWords[7] = 1 }},
		{"busy flag", func(r *MiSTerCaptureRecoveryReceipt) { r.CAPSWords[3] = 1 }},
		{"fault flag", func(r *MiSTerCaptureRecoveryReceipt) { r.CAPSWords[3] = 0x0100 }},
	} {
		t.Run(test.name, func(t *testing.T) {
			receipt := validRecoveryReceipt("fresh-id-v2", 123)
			test.mutate(&receipt)
			if _, err := DecodeMiSTerCaptureRecoveryReceipt(marshalRecoveryReceipt(t, receipt)); err == nil {
				t.Fatal("unsupported or malformed CAPS wire accepted")
			}
		})
	}
}

func TestMiSTerRecoveryEnvelopeVersionRemainsV1(t *testing.T) {
	receipt := validRecoveryReceipt("fresh-id-v2", 123)
	receipt.Version = 2
	if _, err := DecodeMiSTerCaptureRecoveryReceipt(marshalRecoveryReceipt(t, receipt)); err == nil {
		t.Fatal("changed recovery envelope version accepted")
	}
}

func TestMiSTerRecoveryCommandUsesFreshIDAndActualImmutablePath(t *testing.T) {
	remote := newFakeMiSTerRemote()
	remote.probe = MiSTerBoardSnapshot{MainPID: 123, MainExePath: "/media/fat/Main", MainSHA256: strings.Repeat("a", 64),
		ArgvRBF: "/media/fat/_Arcade/cores/jtcap.rbf", ArgvMRA: "/media/fat/_Arcade/jtcap.mra", FPGAState: "operating",
		BridgeStates: map[string]string{"/sys/class/fpga_bridge/br0/state": "enabled"}}
	driver := &MiSTerSessionDriver{Remote: remote, Config: MiSTerDriverConfig{ExpectedBridgeCount: 1,
		CommandTimeout: time.Second, CleanupTimeout: 20 * time.Millisecond, PollInterval: time.Millisecond}}
	remote.recoveryReceipt = func(id string, snapshot MiSTerBoardSnapshot) []byte {
		return marshalRecoveryReceipt(t, validRecoveryReceipt(id, snapshot.MainPID))
	}
	receipt, err := driver.requestCaptureRecovery(context.Background(), remote.probe)
	if err != nil {
		t.Fatal(err)
	}
	if !receipt.Success || len(remote.fifos) != 1 || !strings.HasPrefix(string(remote.fifos[0]), "cab_capture_recover ") ||
		strings.Contains(string(remote.fifos[0]), ".json") || strings.Contains(string(remote.fifos[0]), "/") {
		t.Fatalf("recovery request was not one pathless command: fifo=%q receipt=%+v", remote.fifos, receipt)
	}
	id := strings.TrimSpace(strings.TrimPrefix(string(remote.fifos[0]), "cab_capture_recover "))
	if id != receipt.RecoveryID || !validRecoveryID(id) {
		t.Fatalf("command ID and immutable receipt differ: command=%q receipt=%q", id, receipt.RecoveryID)
	}
	if _, exists := remote.files[miSTerRecoveryReceiptPath(id)]; !exists {
		t.Fatal("Main recovery result was not read from its exact owned path")
	}
}

func TestMiSTerRecoveryRejectsStaleOrUntrustedReceiptAndKeepsQuarantine(t *testing.T) {
	mutations := []struct {
		name   string
		mutate func(string, MiSTerBoardSnapshot) []byte
	}{
		{"stale id", func(_ string, snapshot MiSTerBoardSnapshot) []byte {
			return marshalRecoveryReceipt(t, validRecoveryReceipt("old-id", snapshot.MainPID))
		}},
		{"wrong main pid", func(id string, _ MiSTerBoardSnapshot) []byte {
			return marshalRecoveryReceipt(t, validRecoveryReceipt(id, 999))
		}},
		{"missing full witness", func(id string, snapshot MiSTerBoardSnapshot) []byte {
			r := validRecoveryReceipt(id, snapshot.MainPID)
			r.FullRBFWitness = false
			return marshalRecoveryReceipt(t, r)
		}},
		{"dirty CAPS", func(id string, snapshot MiSTerBoardSnapshot) []byte {
			r := validRecoveryReceipt(id, snapshot.MainPID)
			r.CAPSWords[3] = 1
			return marshalRecoveryReceipt(t, r)
		}},
		{"unconfirmed cleanup", func(id string, snapshot MiSTerBoardSnapshot) []byte {
			r := validRecoveryReceipt(id, snapshot.MainPID)
			r.LocalCleanupConfirmed = false
			return marshalRecoveryReceipt(t, r)
		}},
	}
	for _, test := range mutations {
		t.Run(test.name, func(t *testing.T) {
			remote := newFakeMiSTerRemote()
			remote.probe = MiSTerBoardSnapshot{MainPID: 123, MainExePath: "/media/fat/Main", MainSHA256: strings.Repeat("a", 64),
				ArgvRBF: "/media/fat/_Arcade/cores/jtcap.rbf", ArgvMRA: "/media/fat/_Arcade/jtcap.mra", FPGAState: "operating",
				BridgeStates: map[string]string{"/sys/class/fpga_bridge/br0/state": "enabled"}}
			driver := &MiSTerSessionDriver{Remote: remote, Config: MiSTerDriverConfig{ExpectedBridgeCount: 1,
				CommandTimeout: time.Second, CleanupTimeout: 20 * time.Millisecond, PollInterval: time.Millisecond}}
			remote.recoveryReceipt = test.mutate
			if _, err := driver.requestCaptureRecovery(context.Background(), remote.probe); err == nil {
				t.Fatal("untrusted recovery receipt accepted")
			}
			if len(remote.fifos) != 1 || !strings.HasPrefix(string(remote.fifos[0]), "cab_capture_recover ") {
				t.Fatalf("unexpected gameplay/control command after recovery failure: %q", remote.fifos)
			}
		})
	}
}

func TestMiSTerRecoveryTimeoutAndFIFOFailureFailClosed(t *testing.T) {
	for _, mode := range []string{"receipt timeout", "SSH receipt read timeout", "FIFO failure"} {
		t.Run(mode, func(t *testing.T) {
			remote := newFakeMiSTerRemote()
			remote.probe = MiSTerBoardSnapshot{MainPID: 123, MainExePath: "/media/fat/Main", MainSHA256: strings.Repeat("a", 64),
				ArgvRBF: "/media/fat/_Arcade/cores/jtcap.rbf", ArgvMRA: "/media/fat/_Arcade/jtcap.mra", FPGAState: "operating",
				BridgeStates: map[string]string{"/sys/class/fpga_bridge/br0/state": "enabled"}}
			driver := &MiSTerSessionDriver{Remote: remote, Config: MiSTerDriverConfig{ExpectedBridgeCount: 1,
				CommandTimeout: time.Millisecond, CleanupTimeout: 3 * time.Millisecond, PollInterval: time.Millisecond}}
			remote.recoveryHold = true
			if mode == "FIFO failure" {
				remote.recoveryWriteErr = true
			} else if mode == "SSH receipt read timeout" {
				remote.recoveryHold = false
				remote.recoveryReadErr = true
				remote.recoveryReceipt = func(id string, snapshot MiSTerBoardSnapshot) []byte {
					return marshalRecoveryReceipt(t, validRecoveryReceipt(id, snapshot.MainPID))
				}
			}
			_, err := driver.requestCaptureRecovery(context.Background(), remote.probe)
			if err == nil {
				t.Fatal("recovery without receipt/FIFO acknowledgement was accepted")
			}
			if mode == "receipt timeout" && remote.recoveryWrites != 1 {
				t.Fatalf("timeout retry count=%d, want one command", remote.recoveryWrites)
			}
		})
	}
}

func TestMiSTerReconcileUsesExplicitRecoveryInsteadOfOldSessionStatus(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
	driver.Config.CaptureTimeout = 3 * time.Millisecond
	driver.Config.CleanupTimeout = 30 * time.Millisecond
	remote.withholdStatus = true
	remote.failStop = true
	capture, err := driver.CapturePrepared(context.Background(), key, prepared, inputs)
	if err == nil || capture.Cleanup.Confirmed {
		t.Fatalf("expected an unconfirmed original session and quarantine, got %+v err=%v", capture.Cleanup, err)
	}
	ledger, err := readMiSTerLedger(driver.ledgerName())
	if err != nil || ledger.State != "quarantined" {
		t.Fatalf("capture did not retain a quarantine ledger: %+v %v", ledger, err)
	}
	remote.failStop = false
	remote.loadRBFName = "JTFLSTORY" // RBFNAME cache is diagnostic; argv and staged hashes identify the full load.
	remote.recoveryReceipt = func(id string, snapshot MiSTerBoardSnapshot) []byte {
		return marshalRecoveryReceipt(t, validRecoveryReceipt(id, snapshot.MainPID))
	}
	oldStatus := []byte(`{"protocol":"stale-or-failed-old-capture"}`)
	remote.files[ledger.StatusPath] = append([]byte(nil), oldStatus...)
	cleanup, err := driver.Reconcile(context.Background(), key)
	if err != nil || !cleanup.Confirmed {
		t.Fatalf("fresh explicit recovery did not reconcile the retained attempt: %+v %v", cleanup, err)
	}
	if string(remote.files[ledger.StatusPath]) != string(oldStatus) {
		t.Fatal("recovery changed the immutable old capture status")
	}
	recoveryCommands := 0
	recoverySeen := false
	for _, record := range remote.fifos {
		text := string(record)
		if strings.HasPrefix(text, "cab_capture_recover ") {
			recoveryCommands++
			recoverySeen = true
		}
		if recoverySeen && strings.HasPrefix(text, "cab_session_start ") {
			t.Fatal("reconciliation used gameplay/session start as a recovery probe")
		}
	}
	if recoveryCommands != 2 {
		t.Fatalf("reconciliation sent %d explicit recovery commands, want candidate cleanup and original program witness: %q", recoveryCommands, remote.fifos)
	}
	loadCommands := 0
	for _, record := range remote.fifos {
		if strings.HasPrefix(string(record), "load_core ") {
			loadCommands++
		}
	}
	if loadCommands != 3 || !strings.HasPrefix(string(remote.fifos[len(remote.fifos)-3]), "cab_capture_recover ") ||
		!strings.HasPrefix(string(remote.fifos[len(remote.fifos)-2]), "load_core ") ||
		!strings.HasPrefix(string(remote.fifos[len(remote.fifos)-1]), "cab_capture_recover ") {
		t.Fatalf("recovery was not candidate full-load/receipt then exact restore/program receipt: %q", remote.fifos)
	}
	if _, exists := remote.files[ledger.RemoteLock]; exists {
		t.Fatal("successful exact recovery/restoration left its owned remote lock")
	}
}

func TestMiSTerReconcileRequiresOriginalProgrammingWitness(t *testing.T) {
	remote := newFakeMiSTerRemote()
	driver, prepared, inputs, key, _ := fakeMiSTerDriverFixture(t, remote)
	driver.Config.CaptureTimeout = 3 * time.Millisecond
	driver.Config.CleanupTimeout = 30 * time.Millisecond
	remote.withholdStatus = true
	remote.failStop = true
	result, err := driver.CapturePrepared(context.Background(), key, prepared, inputs)
	if err == nil || result.Cleanup.Confirmed {
		t.Fatalf("expected pre-existing quarantined attempt: %+v %v", result.Cleanup, err)
	}
	ledger, err := readMiSTerLedger(driver.ledgerName())
	if err != nil || ledger.State != "quarantined" {
		t.Fatalf("capture did not retain quarantine: %+v %v", ledger, err)
	}
	remote.failStop = false
	remote.recoveryReceipt = func(id string, snapshot MiSTerBoardSnapshot) []byte {
		return marshalRecoveryReceipt(t, validRecoveryReceipt(id, snapshot.MainPID))
	}
	remote.originalProgramReceipt = func(id string, snapshot MiSTerBoardSnapshot) []byte {
		r := unsupportedProgramReceipt(id, snapshot.MainPID)
		r.FPGAGeneration = 0
		return marshalRecoveryReceipt(t, r)
	}
	cleanup, err := driver.Reconcile(context.Background(), key)
	if err == nil || cleanup.Confirmed {
		t.Fatalf("Reconcile accepted a restored argv without an authentic program witness: %+v %v", cleanup, err)
	}
	ledger, err = readMiSTerLedger(driver.ledgerName())
	if err != nil || ledger.State != "quarantined" || len(ledger.OriginalProgramWitnesses) == 0 {
		t.Fatalf("Reconcile failure did not retain its original-program receipt/quarantine: %+v %v", ledger, err)
	}
	if _, exists := remote.files[ledger.RemoteLock]; !exists {
		t.Fatal("Reconcile released the board lease without the original programming witness")
	}
}
