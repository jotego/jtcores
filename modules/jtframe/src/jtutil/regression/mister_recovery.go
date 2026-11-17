/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"time"
)

const maxMiSTerRecoveryReceiptBytes = 4096

// MiSTerCaptureRecoveryReceipt is Main's separate, immutable recovery proof.
// It is never inferred from capture status or from CAPS read by the host.
type MiSTerCaptureRecoveryReceipt struct {
	Protocol              string   `json:"protocol"`
	Version               uint32   `json:"version"`
	RecoveryID            string   `json:"recovery_id"`
	MainPID               int      `json:"main_pid"`
	Success               bool     `json:"success"`
	Reason                string   `json:"reason"`
	ReloadRequired        bool     `json:"reload_required"`
	FPGAGeneration        uint32   `json:"fpga_generation"`
	FullRBFWitness        bool     `json:"full_rbf_witness"`
	LocalCleanupConfirmed bool     `json:"local_cleanup_confirmed"`
	EncoderBusy           bool     `json:"encoder_busy"`
	ScheduleActive        bool     `json:"schedule_active"`
	CaptureActive         bool     `json:"capture_active"`
	CABActive             bool     `json:"cab_active"`
	CAPSRead              bool     `json:"caps_read"`
	CAPSValid             bool     `json:"caps_valid"`
	CAPSWords             []uint16 `json:"caps_words"`
}

var miSTerRecoveryReceiptKeys = []string{
	"protocol", "version", "recovery_id", "main_pid", "success", "reason", "reload_required",
	"fpga_generation", "full_rbf_witness", "local_cleanup_confirmed", "encoder_busy", "schedule_active",
	"capture_active", "cab_active", "caps_read", "caps_valid", "caps_words",
}

func DecodeMiSTerCaptureRecoveryReceipt(data []byte) (MiSTerCaptureRecoveryReceipt, error) {
	var receipt MiSTerCaptureRecoveryReceipt
	if err := strictJSONDecode(data, maxMiSTerRecoveryReceiptBytes, miSTerRecoveryReceiptKeys, &receipt); err != nil {
		return receipt, fmt.Errorf("decode Main capture recovery receipt: %w", err)
	}
	if receipt.Protocol != "jtframe-capture-recovery-v1" || receipt.Version != 1 || !validRecoveryID(receipt.RecoveryID) ||
		receipt.MainPID <= 0 || !validMiSTerRecoveryReason(receipt.Reason) || len(receipt.CAPSWords) != 8 {
		return receipt, fmt.Errorf("Main recovery receipt identity or bounds are invalid")
	}
	for _, word := range receipt.CAPSWords {
		if word > 0xffff {
			return receipt, fmt.Errorf("Main recovery CAPS word exceeds 16 bits")
		}
	}
	if receipt.Success {
		if receipt.FPGAGeneration == 0 {
			return receipt, fmt.Errorf("successful Main recovery has no process-local RBF generation")
		}
		if receipt.Reason != "recovered" && receipt.Reason != "already_clean" {
			return receipt, fmt.Errorf("successful Main recovery has a failure reason")
		}
		if receipt.ReloadRequired || !receipt.FullRBFWitness || !receipt.LocalCleanupConfirmed || receipt.EncoderBusy ||
			receipt.ScheduleActive || receipt.CaptureActive || receipt.CABActive || !receipt.CAPSRead || !receipt.CAPSValid ||
			!miSTerRecoveryCAPSIdle(receipt.CAPSWords) {
			return receipt, fmt.Errorf("successful Main recovery receipt has contradictory cleanup evidence")
		}
	} else if receipt.Reason == "recovered" || receipt.Reason == "already_clean" {
		return receipt, fmt.Errorf("failed Main recovery has a success reason")
	}
	return receipt, nil
}

func validMiSTerRecoveryReason(reason string) bool {
	switch reason {
	case "recovered", "already_clean", "no_full_rbf_witness", "newer_full_rbf_required", "cab_busy", "capture_busy",
		"schedule_busy", "encoder_busy", "caps_unavailable", "caps_invalid", "caps_not_idle", "local_cleanup_failed":
		return true
	}
	return false
}

func miSTerRecoveryCAPSIdle(words []uint16) bool {
	if len(words) != 8 || words[0] != 0xca50 || words[1] != 2 || words[2] != 64 || words[5] != 0 || words[7] != 0 {
		return false
	}
	flags := words[3]
	return flags&^uint16(0x0010) == 0
}

func validRecoveryID(value string) bool {
	if len(value) < 1 || len(value) > 48 {
		return false
	}
	for _, r := range value {
		if !(r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || r == '_' || r == '-') {
			return false
		}
	}
	return true
}

func newMiSTerRecoveryID() (string, error) {
	var nonce [16]byte
	if _, err := rand.Read(nonce[:]); err != nil {
		return "", fmt.Errorf("generate fresh recovery identifier: %w", err)
	}
	return hex.EncodeToString(nonce[:]), nil
}

func miSTerRecoveryReceiptPath(id string) string {
	return "/tmp/jtframe-capture-recovery-" + id + ".json"
}

type miSTerCaptureRecoveryEvidence struct {
	ID      string
	Path    string
	Raw     []byte
	Receipt MiSTerCaptureRecoveryReceipt
}

func (d *MiSTerSessionDriver) requestCaptureRecovery(ctx context.Context, expected MiSTerBoardSnapshot) (MiSTerCaptureRecoveryReceipt, error) {
	evidence, err := d.requestCaptureRecoveryEvidence(ctx, expected, nil)
	if err != nil {
		return MiSTerCaptureRecoveryReceipt{}, err
	}
	if !evidence.Receipt.Success {
		return evidence.Receipt, fmt.Errorf("Main recovery receipt did not confirm cleanup")
	}
	return evidence.Receipt, nil
}

func (d *MiSTerSessionDriver) requestCaptureRecoveryEvidence(ctx context.Context, expected MiSTerBoardSnapshot, beforeSend func(string, string) error) (miSTerCaptureRecoveryEvidence, error) {
	id, err := newMiSTerRecoveryID()
	if err != nil {
		return miSTerCaptureRecoveryEvidence{}, err
	}
	receiptPath := miSTerRecoveryReceiptPath(id)
	if _, exists, probeErr := d.Remote.File(ctx, receiptPath, maxMiSTerRecoveryReceiptBytes); probeErr != nil || exists {
		if probeErr != nil {
			return miSTerCaptureRecoveryEvidence{}, fmt.Errorf("check fresh recovery receipt path: %w", probeErr)
		}
		return miSTerCaptureRecoveryEvidence{}, fmt.Errorf("fresh recovery receipt path already exists")
	}
	if beforeSend != nil {
		if err = beforeSend(id, receiptPath); err != nil {
			return miSTerCaptureRecoveryEvidence{}, fmt.Errorf("persist recovery request intent: %w", err)
		}
	}
	command := []byte("cab_capture_recover " + id + "\n")
	if err = d.Remote.WriteFIFO(ctx, command, d.Config.CommandTimeout); err != nil {
		return miSTerCaptureRecoveryEvidence{}, fmt.Errorf("send explicit Main recovery request: %w", err)
	}
	now := d.Now
	if now == nil {
		now = time.Now
	}
	sleep := d.Sleep
	if sleep == nil {
		sleep = contextSleep
	}
	deadline := now().Add(d.Config.CleanupTimeout)
	for {
		if err = ctx.Err(); err != nil {
			return miSTerCaptureRecoveryEvidence{}, err
		}
		data, exists, readErr := d.Remote.File(ctx, receiptPath, maxMiSTerRecoveryReceiptBytes)
		if readErr == nil && exists {
			receipt, decodeErr := DecodeMiSTerCaptureRecoveryReceipt(data)
			if decodeErr != nil {
				return miSTerCaptureRecoveryEvidence{ID: id, Path: receiptPath, Raw: append([]byte(nil), data...)}, decodeErr
			}
			if receipt.RecoveryID != id || receipt.MainPID != expected.MainPID {
				return miSTerCaptureRecoveryEvidence{ID: id, Path: receiptPath, Raw: append([]byte(nil), data...), Receipt: receipt}, fmt.Errorf("Main recovery receipt does not prove this fresh process and request")
			}
			// Generation is process-local and may reset to 1 on every Main exec;
			// bind it to the exact PID and argv produced by the normal full load.
			current, probeErr := d.Remote.Probe(ctx)
			if probeErr != nil || current.MainPID != expected.MainPID || current.MainExePath != expected.MainExePath ||
				current.MainSHA256 != expected.MainSHA256 ||
				current.ArgvRBF != expected.ArgvRBF || current.ArgvMRA != expected.ArgvMRA || current.FPGAState != "operating" ||
				!bridgesEnabled(current.BridgeStates, d.Config.ExpectedBridgeCount) {
				return miSTerCaptureRecoveryEvidence{ID: id, Path: receiptPath, Raw: append([]byte(nil), data...), Receipt: receipt}, fmt.Errorf("Main process changed while recovery was being verified")
			}
			return miSTerCaptureRecoveryEvidence{ID: id, Path: receiptPath, Raw: append([]byte(nil), data...), Receipt: receipt}, nil
		}
		if now().After(deadline) {
			return miSTerCaptureRecoveryEvidence{}, fmt.Errorf("Main recovery receipt timed out; quarantine retained")
		}
		if err = sleep(ctx, d.pollInterval()); err != nil {
			return miSTerCaptureRecoveryEvidence{}, fmt.Errorf("wait for Main recovery receipt: %w", err)
		}
	}
}
