/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"strings"
	"testing"
	"time"
)

type miSTerStatusReadCounter struct {
	MiSTerRemote
	path  string
	reads int
}

func (r *miSTerStatusReadCounter) File(ctx context.Context, path string, limit int64) ([]byte, bool, error) {
	if path == r.path {
		r.reads++
	}
	return r.MiSTerRemote.File(ctx, path, limit)
}

func TestMiSTerWaitCleanStopRequiresIntrinsicallyValidTerminalV2(t *testing.T) {
	fixture := newMiSTerCaptureV2Fixture(t)
	var valid miSTerCaptureStatusV2
	if err := decodeJSONValueFromBytes(fixture.status, &valid); err != nil {
		t.Fatal(err)
	}
	valid.State, valid.ScheduleState = "cancelled", "cancelled"

	cases := []struct {
		name string
		edit func(*miSTerCaptureStatusV2)
	}{
		{"valid terminal v2", func(*miSTerCaptureStatusV2) {}},
		{"v1 receipt label", func(v *miSTerCaptureStatusV2) { v.ReceiptProtocol = "jtframe-capture-image-v1" }},
		{"active state with cancelled schedule", func(v *miSTerCaptureStatusV2) { v.State = "copying" }},
		{"out of range checkpoint", func(v *miSTerCaptureStatusV2) { v.Checkpoint = 32768 }},
		{"index exceeds schedule", func(v *miSTerCaptureStatusV2) { v.ScheduleIndex = v.ScheduleCount + 1 }},
		{"copy exceeds bound", func(v *miSTerCaptureStatusV2) { v.CopiedBytes = 8<<20 + 1 }},
		{"nonzero checkpoint has zero hold", func(v *miSTerCaptureStatusV2) { v.MaxHoldMS = 0 }},
		{"nonzero checkpoint has short hold", func(v *miSTerCaptureStatusV2) { v.MaxHoldMS = 99 }},
		{"unknown state", func(v *miSTerCaptureStatusV2) { v.State = "future-state-v3" }},
		{"unknown schedule state", func(v *miSTerCaptureStatusV2) { v.ScheduleState = "future-schedule-v3" }},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			status := valid
			tc.edit(&status)
			err := waitCleanStopForStatus(t, status)
			if tc.name == "valid terminal v2" {
				if err != nil {
					t.Fatalf("valid terminal v2 cleanup status rejected: %v", err)
				}
			} else if err == nil {
				t.Fatal("invalid/nonterminal v2 status was trusted as cleanup confirmation")
			}
		})
	}

	initial := valid
	initial.State, initial.ScheduleState = "cab_arming", "waiting_first_arm"
	initial.Checkpoint, initial.MaxHoldMS = 0, 0
	initial.CleanupConfirmed = false
	if _, err := decodeLiveMiSTerCaptureStatus(marshalTestJSON(t, initial)); err != nil {
		t.Fatalf("valid initial checkpoint-zero/hold-zero status rejected: %v", err)
	}
	if err := waitCleanStopForStatus(t, initial); err == nil {
		t.Fatal("nonterminal initial checkpoint-zero/hold-zero status was treated as cleanup confirmation")
	}
}

func TestMiSTerLiveStatusAcceptsMainProducerStateLabelsWithCorrectTerminalProof(t *testing.T) {
	fixture := newMiSTerCaptureV2Fixture(t)
	var base miSTerCaptureStatusV2
	if err := decodeJSONValueFromBytes(fixture.status, &base); err != nil {
		t.Fatal(err)
	}
	active := base
	active.State, active.ScheduleState, active.CleanupConfirmed = "first_capture_arm_acknowledged", "running", true
	if _, err := decodeLiveMiSTerCaptureStatus(marshalTestJSON(t, active)); err != nil {
		t.Fatalf("Main's successful first-arm ACK state was rejected: %v", err)
	}
	if mainMiSTerCaptureOperationFailed(active.State) || terminalCaptureState(active.State, active.ScheduleState) || waitCleanStopForStatus(t, active) == nil {
		t.Fatal("first_capture_arm_acknowledged was treated as terminal cleanup proof")
	}
	diagnostic := base
	diagnostic.StatusWriteFailed = true
	if _, err := decodeLiveMiSTerCaptureStatus(marshalTestJSON(t, diagnostic)); err != nil {
		t.Fatalf("sticky status-write diagnostic invalidated otherwise valid live status: %v", err)
	}
	if err := waitCleanStopForStatus(t, diagnostic); err != nil {
		t.Fatalf("sticky status-write diagnostic invalidated clean terminal proof: %v", err)
	}

	// Main producer 5b4fb02167b18cdc7ec22cf3ce33ea6756f6bc42 emits these scheduled failure labels.
	errorStates := []string{
		"cab_failed_before_first_capture_arm", "cab_ended_before_first_capture_arm", "first_capture_arm_timeout",
		"capture_start_gate_rejected", "first_capture_arm_failed", "capture_target_failed", "capture_receipt_error",
		"capture_encoder_error", "capture_generation_changed", "cab_terminal_session_mismatch",
		"cab_terminal_receipt_invalid", "capture_playback_deadline_expired",
	}
	for _, state := range errorStates {
		t.Run(state, func(t *testing.T) {
			pending := base
			pending.State, pending.ScheduleState, pending.CleanupConfirmed = state, "cleanup_pending", false
			if _, err := decodeLiveMiSTerCaptureStatus(marshalTestJSON(t, pending)); err != nil {
				t.Fatalf("Main's pending cleanup state %q was rejected: %v", state, err)
			}
			if terminalCaptureState(pending.State, pending.ScheduleState) || waitCleanStopForStatus(t, pending) == nil {
				t.Fatalf("pending failure state %q was treated as clean terminal", state)
			}

			clean := pending
			clean.ScheduleState, clean.CleanupConfirmed = "error", true
			if _, err := decodeLiveMiSTerCaptureStatus(marshalTestJSON(t, clean)); err != nil {
				t.Fatalf("Main's cleaned terminal failure state %q was rejected: %v", state, err)
			}
			if !terminalCaptureState(clean.State, clean.ScheduleState) || waitCleanStopForStatus(t, clean) != nil {
				t.Fatalf("clean terminal failure state %q did not prove bounded cleanup", state)
			}
			withoutCleanup := clean
			withoutCleanup.CleanupConfirmed = false
			if waitCleanStopForStatus(t, withoutCleanup) == nil {
				t.Fatalf("failure state %q was accepted without clean confirmation", state)
			}
			reloadRequired := clean
			reloadRequired.ReloadRequired = true
			if waitCleanStopForStatus(t, reloadRequired) == nil {
				t.Fatalf("failure state %q was accepted while reload was required", state)
			}
			encoderBusy := clean
			encoderBusy.EncoderBusy = true
			if waitCleanStopForStatus(t, encoderBusy) == nil {
				t.Fatalf("failure state %q was accepted while the encoder was busy", state)
			}

			unclean := clean
			unclean.ScheduleState, unclean.CleanupConfirmed = "cleanup_unconfirmed", true
			if terminalCaptureState(unclean.State, unclean.ScheduleState) || waitCleanStopForStatus(t, unclean) == nil {
				t.Fatalf("failure state %q accepted cleanup_unconfirmed as a clean terminal", state)
			}
			contradictory := clean
			contradictory.ScheduleState = "complete"
			if terminalCaptureState(contradictory.State, contradictory.ScheduleState) || waitCleanStopForStatus(t, contradictory) == nil {
				t.Fatalf("failure state %q accepted a contradictory complete schedule", state)
			}
		})
	}

	future := base
	future.State = "future-status-v3"
	if _, err := decodeLiveMiSTerCaptureStatus(marshalTestJSON(t, future)); err == nil {
		t.Fatal("unknown future state label was accepted")
	}
}

func TestMiSTerCollectCaptureReportsMainOperationFailuresImmediately(t *testing.T) {
	states := []string{
		"error", "encode_error", "receipt_error", "deadline_expired", "reload_required", "first_capture_preflight_failed",
		"capture_target_late", "capture_arm_failed", "capture_session_error", "capture_manifest_publish_failed",
		"capture_recovery_required", "unsupported", "bridge_busy", "invalid_target", "start_failed", "encoder_busy",
		"capture_manifest_start_failed", "cab_session_start_failed", "cab_failed_before_first_capture_arm",
		"cab_ended_before_first_capture_arm", "first_capture_arm_timeout", "capture_start_gate_rejected",
		"first_capture_arm_failed", "capture_target_failed", "capture_receipt_error", "capture_encoder_error",
		"capture_generation_changed", "cab_terminal_session_mismatch", "cab_terminal_receipt_invalid",
		"capture_playback_deadline_expired",
	}
	for _, state := range states {
		t.Run(state, func(t *testing.T) {
			fixture := newMiSTerCaptureV2Fixture(t)
			var status miSTerCaptureStatusV2
			if err := decodeJSONValueFromBytes(fixture.status, &status); err != nil {
				t.Fatal(err)
			}
			status.State, status.ScheduleState = state, "cleanup_pending"
			status.CleanupConfirmed, status.ReloadRequired, status.Fault = false, false, 0
			const path = "/tmp/jtframe-capture-sess-v2.json"
			base := newFakeMiSTerRemote()
			base.files[path] = marshalTestJSON(t, status)
			remote := &miSTerStatusReadCounter{MiSTerRemote: base, path: path}
			now := time.Unix(0, 0)
			nowCalls, sleeps := 0, 0
			driver := &MiSTerSessionDriver{
				Config: MiSTerDriverConfig{CaptureTimeout: 10 * time.Millisecond, PollInterval: time.Millisecond},
				Remote: remote,
				Now:    func() time.Time { nowCalls++; return now.Add(time.Duration(nowCalls) * time.Millisecond) },
				Sleep:  func(context.Context, time.Duration) error { sleeps++; return nil },
			}
			_, err := driver.collectCapture(context.Background(), &miSTerActiveSession{key: fixture.expected.Attempt, statusPath: path}, t.TempDir())
			if err == nil || !strings.Contains(err.Error(), state) || strings.Contains(err.Error(), "acknowledgement timed out") ||
				remote.reads != 1 || sleeps != 0 {
				t.Fatalf("Main operation failure did not return promptly with its reason: err=%v status_reads=%d sleeps=%d", err, remote.reads, sleeps)
			}
			if err := waitCleanStopForStatus(t, status); err == nil {
				t.Fatal("cleanup_pending failure status was treated as clean terminal confirmation")
			}
		})
	}
}

func waitCleanStopForStatus(t *testing.T, status miSTerCaptureStatusV2) error {
	t.Helper()
	remote := newFakeMiSTerRemote()
	const statusPath = "/tmp/jtframe-capture-sess-v2.json"
	remote.files[statusPath] = marshalTestJSON(t, status)
	now := time.Unix(0, 0)
	calls := 0
	driver := &MiSTerSessionDriver{
		Config: MiSTerDriverConfig{CleanupTimeout: time.Millisecond, PollInterval: time.Millisecond},
		Remote: remote,
		Now:    func() time.Time { calls++; return now.Add(time.Duration(calls) * time.Millisecond) },
		Sleep:  func(context.Context, time.Duration) error { return nil },
	}
	active := &miSTerActiveSession{key: AttemptKey{SessionID: "sess-v2"}, statusPath: statusPath}
	return driver.waitCleanStop(context.Background(), active)
}
