/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"bytes"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"hash/crc32"
	"path"
	"path/filepath"
	"strings"
)

const miSTerCaptureProtocolV2 = "jtframe-capture-v2"

type miSTerCaptureStatusV2 struct {
	Protocol           string `json:"protocol"`
	SessionID          string `json:"session_id"`
	State              string `json:"state"`
	Checkpoint         uint32 `json:"checkpoint"`
	MaxHoldMS          uint32 `json:"max_hold_ms"`
	Fault              uint32 `json:"fault"`
	CleanupConfirmed   bool   `json:"cleanup_confirmed"`
	ReloadRequired     bool   `json:"reload_required"`
	StatusWriteFailed  bool   `json:"status_write_failed"`
	ReceiptWriteFailed bool   `json:"receipt_write_failed"`
	CopiedBytes        uint64 `json:"copied_bytes"`
	EncoderBusy        bool   `json:"encoder_busy"`
	Output             string `json:"output"`
	Scheduled          bool   `json:"scheduled"`
	ScheduleCRC32      string `json:"schedule_crc32"`
	PackedCABCRC32     string `json:"packed_cab_crc32"`
	ScheduleCount      uint32 `json:"schedule_count"`
	ScheduleIndex      uint32 `json:"schedule_index"`
	ScheduleState      string `json:"schedule_state"`
	CaptureProtocol    string `json:"capture_protocol"`
	ReceiptProtocol    string `json:"receipt_protocol"`
	ManifestPath       string `json:"manifest_path"`
	CompletedCount     uint32 `json:"completed_count"`
}

type miSTerCABProgressV2 struct {
	Protocol          string `json:"protocol"`
	Session           string `json:"session"`
	State             string `json:"state"`
	Reason            string `json:"reason"`
	Frame             uint32 `json:"frame"`
	FramesTotal       uint32 `json:"frames_total"`
	EventsAccepted    uint32 `json:"events_accepted"`
	EventsApplied     uint32 `json:"events_applied"`
	EventsTotal       uint32 `json:"events_total"`
	NextEvent         uint32 `json:"next_event"`
	FreeCredits       uint32 `json:"free_credits"`
	CleanupConfirmed  bool   `json:"cleanup_confirmed"`
	StatusWriteFailed bool   `json:"status_write_failed"`
	Error             string `json:"error"`
}

type miSTerCaptureReceiptRefV2 struct {
	Checkpoint     uint32 `json:"checkpoint"`
	FPGAGeneration uint32 `json:"fpga_generation"`
	PlanCRC32      string `json:"plan_crc32"`
	PackedCABCRC32 string `json:"packed_cab_crc32"`
	ReceiptPath    string `json:"receipt_path"`
}

type miSTerCaptureCABTerminalV2 struct {
	Observed         bool   `json:"observed"`
	Failed           bool   `json:"failed"`
	CleanupConfirmed bool   `json:"cleanup_confirmed"`
	InputsNeutral    bool   `json:"inputs_neutral"`
	Frames           uint32 `json:"frames"`
	FramesTotal      uint32 `json:"frames_total"`
	EventsAccepted   uint32 `json:"events_accepted"`
	EventsApplied    uint32 `json:"events_applied"`
	EventsTotal      uint32 `json:"events_total"`
}

type miSTerCaptureManifestV2 struct {
	Protocol           string                      `json:"protocol"`
	Version            uint32                      `json:"version"`
	CaptureProtocol    string                      `json:"capture_protocol"`
	SessionID          string                      `json:"session_id"`
	State              string                      `json:"state"`
	Reason             string                      `json:"reason"`
	FPGAGeneration     uint32                      `json:"fpga_generation"`
	PlanCRC32          string                      `json:"plan_crc32"`
	PackedCABCRC32     string                      `json:"packed_cab_crc32"`
	PlanTotalFrames    uint32                      `json:"plan_total_frames"`
	ExpectedCount      uint32                      `json:"expected_count"`
	PlannedCheckpoints []uint32                    `json:"planned_checkpoints"`
	CompletedCount     uint32                      `json:"completed_count"`
	Images             []miSTerCaptureReceiptRefV2 `json:"images"`
	CABTerminal        miSTerCaptureCABTerminalV2  `json:"cab_terminal"`
}

type miSTerCaptureImageReceiptV2 struct {
	Protocol             string `json:"protocol"`
	CaptureProtocol      string `json:"capture_protocol"`
	SessionID            string `json:"session_id"`
	FPGAGeneration       uint32 `json:"fpga_generation"`
	PlanCRC32            string `json:"plan_crc32"`
	PackedCABCRC32       string `json:"packed_cab_crc32"`
	RequestedCheckpoint  uint32 `json:"requested_checkpoint"`
	ActualInterval       uint32 `json:"actual_interval"`
	ActualCheckpoint     uint32 `json:"actual_checkpoint"`
	DescriptorCheckpoint uint32 `json:"descriptor_checkpoint"`
	Width                uint32 `json:"width"`
	Height               uint32 `json:"height"`
	RowPitch             uint32 `json:"row_pitch"`
	PayloadBytes         uint32 `json:"payload_bytes"`
	SlotBase             string `json:"slot_base"`
	SlotStride           uint32 `json:"slot_stride"`
	Slot                 uint32 `json:"slot"`
	Mode                 string `json:"mode"`
	DescriptorCRC32      string `json:"descriptor_crc32"`
	HeaderBeforeCRC32    string `json:"header_before_crc32"`
	HeaderAfterCRC32     string `json:"header_after_crc32"`
	DescriptorBytesHex   string `json:"descriptor_bytes_hex"`
	HeaderBeforeHex      string `json:"header_before_hex"`
	HeaderAfterHex       string `json:"header_after_hex"`
	FinalIssued          uint32 `json:"final_issued"`
	FinalCompleted       uint32 `json:"final_completed"`
	ReleaseConfirmed     bool   `json:"release_confirmed"`
	ReleaseAckFreshness  uint16 `json:"release_ack_freshness"`
	PNGComplete          bool   `json:"png_complete"`
	PNGPath              string `json:"png_path"`
	PNGSize              uint64 `json:"png_size"`
	RawRGBPath           string `json:"raw_rgb_path"`
	RawRGBSize           uint64 `json:"raw_rgb_size"`
}

var captureStatusV2Keys = []string{
	"protocol", "session_id", "state", "checkpoint", "max_hold_ms", "fault", "cleanup_confirmed",
	"reload_required", "status_write_failed", "receipt_write_failed", "copied_bytes", "encoder_busy", "output",
	"scheduled", "schedule_crc32", "packed_cab_crc32", "schedule_count", "schedule_index", "schedule_state",
	"capture_protocol", "receipt_protocol", "manifest_path", "completed_count",
}

var cabProgressV2Keys = []string{"protocol", "session", "state", "reason", "frame", "frames_total", "events_accepted", "events_applied", "events_total", "next_event", "free_credits", "cleanup_confirmed", "status_write_failed", "error"}

var captureManifestV2Keys = []string{
	"protocol", "version", "capture_protocol", "session_id", "state", "reason", "fpga_generation", "plan_crc32",
	"packed_cab_crc32", "plan_total_frames", "expected_count", "planned_checkpoints", "completed_count", "images", "cab_terminal",
}

var captureReceiptRefV2Keys = []string{"checkpoint", "fpga_generation", "plan_crc32", "packed_cab_crc32", "receipt_path"}
var captureCABTerminalV2Keys = []string{"observed", "failed", "cleanup_confirmed", "inputs_neutral", "frames", "frames_total", "events_accepted", "events_applied", "events_total"}
var captureImageV2Keys = []string{
	"protocol", "capture_protocol", "session_id", "fpga_generation", "plan_crc32", "packed_cab_crc32", "requested_checkpoint",
	"actual_interval", "actual_checkpoint", "descriptor_checkpoint", "width", "height", "row_pitch", "payload_bytes", "slot_base",
	"slot_stride", "slot", "mode", "descriptor_crc32", "header_before_crc32", "header_after_crc32", "descriptor_bytes_hex",
	"header_before_hex", "header_after_hex", "final_issued", "final_completed", "release_confirmed", "release_ack_freshness",
	"png_complete", "png_path", "png_size", "raw_rgb_path", "raw_rgb_size",
}

func decodeMiSTerCaptureStatusV2(data []byte) (miSTerCaptureStatusV2, error) {
	var v miSTerCaptureStatusV2
	if err := strictJSONDecode(data, maxCaptureStatusJSONBytes, captureStatusV2Keys, &v); err != nil {
		return v, err
	}
	return v, nil
}

// decodeLiveMiSTerCaptureStatus accepts only the protocol produced by the
// qualified live Main. Historical v1 status is handled by the read-only
// receipt decoder, never by a fresh capture, cancellation, or cleanup path.
func decodeLiveMiSTerCaptureStatus(data []byte) (MiSTerCaptureStatus, error) {
	v2, err := decodeMiSTerCaptureStatusV2(data)
	if err != nil {
		return MiSTerCaptureStatus{}, fmt.Errorf("decode live MiSTer v2 capture status: %w", err)
	}
	if err := validateLiveMiSTerCaptureStatusV2(v2); err != nil {
		return MiSTerCaptureStatus{}, err
	}
	return MiSTerCaptureStatus{
		Protocol: v2.Protocol, SessionID: v2.SessionID, State: v2.State, Checkpoint: v2.Checkpoint,
		MaxHoldMS: v2.MaxHoldMS, Fault: v2.Fault, CleanupConfirmed: v2.CleanupConfirmed,
		ReloadRequired: v2.ReloadRequired, StatusWriteFailed: v2.StatusWriteFailed,
		ReceiptWriteFailed: v2.ReceiptWriteFailed, CopiedBytes: v2.CopiedBytes,
		EncoderBusy: v2.EncoderBusy, Output: v2.Output, Scheduled: v2.Scheduled,
		ScheduleCRC32: v2.ScheduleCRC32, PackedCABCRC32: v2.PackedCABCRC32,
		ScheduleCount: v2.ScheduleCount, ScheduleIndex: v2.ScheduleIndex, ScheduleState: v2.ScheduleState,
		ReceiptProtocol: v2.ReceiptProtocol, ManifestPath: v2.ManifestPath, CompletedCount: v2.CompletedCount,
	}, nil
}

func validateLiveMiSTerCaptureStatusV2(v miSTerCaptureStatusV2) error {
	if v.Protocol != "jtframe-capture-session-v2" || v.CaptureProtocol != miSTerCaptureProtocolV2 ||
		v.ReceiptProtocol != "jtframe-capture-image-v2" {
		return fmt.Errorf("live MiSTer capture status does not identify the qualified v2 protocols")
	}
	if v.Checkpoint > 32767 || v.Fault > 13 || v.CopiedBytes > 8<<20 ||
		(v.Checkpoint == 0 && v.MaxHoldMS != 0) ||
		(v.Checkpoint != 0 && (v.MaxHoldMS < 100 || v.MaxHoldMS > 2000)) ||
		v.ScheduleCount > 32767 || v.ScheduleIndex > v.ScheduleCount || v.CompletedCount > v.ScheduleCount {
		return fmt.Errorf("live MiSTer capture status has out-of-range counters or hold duration")
	}
	if v.Scheduled {
		if v.ScheduleCount == 0 || v.ScheduleState == "" {
			return fmt.Errorf("scheduled MiSTer capture status has no schedule progress")
		}
	} else if v.ScheduleCount != 0 || v.ScheduleIndex != 0 || v.CompletedCount != 0 || v.ScheduleState != "" {
		return fmt.Errorf("unscheduled MiSTer capture status contains schedule progress")
	}
	if !knownMiSTerCaptureStatusState(v.State) || !knownMiSTerCaptureScheduleState(v.ScheduleState) {
		return fmt.Errorf("live MiSTer capture status has an unknown state")
	}
	return nil
}

func knownMiSTerCaptureStatusState(state string) bool {
	switch state {
	case "idle", "drain_wait", "arm_wait", "ready_wait", "copying", "release_wait", "queueing", "abort_pending", "abort_wait", "done", "complete", "error",
		"encoding", "image_complete", "encode_error", "receipt_error", "deadline_expired", "reload_required",
		"first_capture_preflight_failed", "capture_target_late", "capture_arm_failed", "capture_session_error", "capture_manifest_publish_failed",
		"capture_recovery_required", "interrupted", "unsupported", "bridge_busy", "invalid_target", "start_failed", "validating_plan",
		"encoder_busy", "capture_manifest_start_failed", "cab_session_start_failed", "cab_arming", "cancelled", "cleanup_unconfirmed", "rejected",
		"first_capture_arm_acknowledged", "cab_failed_before_first_capture_arm", "cab_ended_before_first_capture_arm",
		"first_capture_arm_timeout", "capture_start_gate_rejected", "first_capture_arm_failed", "capture_target_failed",
		"capture_receipt_error", "capture_encoder_error", "capture_generation_changed", "cab_terminal_session_mismatch",
		"cab_terminal_receipt_invalid", "capture_playback_deadline_expired":
		return true
	default:
		return false
	}
}

func knownMiSTerCaptureScheduleState(state string) bool {
	switch state {
	case "", "validating_cab", "blocked", "rejected", "waiting_first_arm", "first_arm_wait", "running", "cleanup_pending", "stopping_cab",
		"cancelled", "cleanup_unconfirmed", "error", "waiting_cab_complete", "complete", "cancelling_capture", "interrupted":
		return true
	default:
		return false
	}
}

func decodeMiSTerCaptureManifestV2(data []byte) (miSTerCaptureManifestV2, error) {
	var v miSTerCaptureManifestV2
	root, err := strictJSONValue(data, maxCaptureManifestBytes)
	if err != nil {
		return v, err
	}
	obj, ok := root.(map[string]interface{})
	if !ok {
		return v, fmt.Errorf("capture manifest v2 must be an object")
	}
	if err := requireJSONKeys(obj, captureManifestV2Keys); err != nil {
		return v, err
	}
	refs, ok := obj["images"].([]interface{})
	if !ok {
		return v, fmt.Errorf("manifest images must be an array")
	}
	for _, raw := range refs {
		ref, ok := raw.(map[string]interface{})
		if !ok {
			return v, fmt.Errorf("manifest image reference must be an object")
		}
		if err := requireJSONKeys(ref, captureReceiptRefV2Keys); err != nil {
			return v, err
		}
	}
	terminal, ok := obj["cab_terminal"].(map[string]interface{})
	if !ok {
		return v, fmt.Errorf("manifest CAB terminal must be an object")
	}
	if err := requireJSONKeys(terminal, captureCABTerminalV2Keys); err != nil {
		return v, err
	}
	if err := decodeJSONValue(root, &v); err != nil {
		return v, err
	}
	return v, nil
}

func decodeMiSTerCaptureImageReceiptV2(data []byte) (miSTerCaptureImageReceiptV2, error) {
	var v miSTerCaptureImageReceiptV2
	if err := strictJSONDecode(data, maxCaptureReceiptBytes, captureImageV2Keys, &v); err != nil {
		return v, err
	}
	return v, nil
}

func validateMiSTerCABStatusV2(data []byte, sessionID string, manifest miSTerCaptureManifestV2) error {
	var progress miSTerCABProgressV2
	if err := strictJSONDecode(data, 64<<10, cabProgressV2Keys, &progress); err != nil {
		return fmt.Errorf("decode CAB v2 progress: %w", err)
	}
	terminal := manifest.CABTerminal
	if progress.Protocol != "jtframe-cab-host-v2" || progress.Session != sessionID || progress.State != "done" ||
		!progress.CleanupConfirmed || progress.StatusWriteFailed || progress.Error != "" || progress.Frame != terminal.Frames ||
		progress.FramesTotal != terminal.FramesTotal || progress.EventsAccepted != terminal.EventsAccepted ||
		progress.EventsApplied != terminal.EventsApplied || progress.EventsTotal != terminal.EventsTotal {
		return fmt.Errorf("terminal CAB v2 progress does not match the clean capture manifest")
	}
	return nil
}

func captureProtocolFromJSON(data []byte, maxBytes int) (string, error) {
	value, err := strictJSONValue(data, maxBytes)
	if err != nil {
		return "", err
	}
	obj, ok := value.(map[string]interface{})
	if !ok {
		return "", fmt.Errorf("capture record must be an object")
	}
	protocol, ok := obj["protocol"].(string)
	if !ok {
		return "", fmt.Errorf("capture record protocol must be a string")
	}
	return protocol, nil
}

func validateMiSTerCaptureV2(expected MiSTerReceiptExpectation, statusJSON, manifestJSON []byte,
	files MiSTerRetrievedFiles, retrievalRoot string) (MiSTerValidatedCapture, error) {
	var result MiSTerValidatedCapture
	prepared := expected.Prepared
	if err := prepared.Validate(); err != nil {
		return result, fmt.Errorf("invalid prepared session: %w", err)
	}
	if !validCaptureSessionID(expected.Attempt.SessionID) || expected.Attempt.Board == "" || expected.Attempt.Nonce == "" ||
		expected.FPGAGeneration == 0 || expected.MaxHoldMS < capturePlanMinHoldMS || expected.MaxHoldMS > capturePlanMaxHoldMS {
		return result, fmt.Errorf("receipt expectation has incomplete attempt/generation/hold identity")
	}
	if len(prepared.Checkpoints) == 0 || len(prepared.Checkpoints) > capturePlanMaxEntries {
		return result, fmt.Errorf("prepared checkpoint count outside supported bound")
	}
	identity, err := prepared.PortableIdentity()
	if err != nil {
		return result, err
	}
	cabHeader, err := inspectPackedCAB(expected.PackedCAB)
	if err != nil {
		return result, fmt.Errorf("validate packed CAB input: %w", err)
	}
	cabEventCount := binary.LittleEndian.Uint32(expected.PackedCAB[16:20])
	packedSHA := sha256.Sum256(expected.PackedCAB)
	if hex.EncodeToString(packedSHA[:]) != prepared.CAB.PackedSHA256 || cabHeader.payloadCRC32 != prepared.CAB.PayloadCRC32 ||
		cabHeader.totalFrames != prepared.CAB.TotalFrames || cabEventCount == 0 || cabEventCount > cabHeader.totalFrames {
		return result, fmt.Errorf("prepared packed CAB bytes do not match their immutable identity")
	}
	status, err := decodeMiSTerCaptureStatusV2(statusJSON)
	if err != nil {
		return result, fmt.Errorf("decode MiSTer v2 status: %w", err)
	}
	manifest, err := decodeMiSTerCaptureManifestV2(manifestJSON)
	if err != nil {
		return result, fmt.Errorf("decode MiSTer v2 manifest: %w", err)
	}
	planCRC := fmt.Sprintf("%08x", expected.PlanCRC32)
	cabCRC := fmt.Sprintf("%08x", prepared.CAB.PayloadCRC32)
	count := len(prepared.Checkpoints)
	if status.Protocol != "jtframe-capture-session-v2" || status.CaptureProtocol != miSTerCaptureProtocolV2 ||
		status.ReceiptProtocol != "jtframe-capture-image-v2" || status.SessionID != expected.Attempt.SessionID || status.State != "complete" ||
		status.Fault != 0 || !status.CleanupConfirmed || status.ReloadRequired || status.StatusWriteFailed || status.ReceiptWriteFailed ||
		status.EncoderBusy || !status.Scheduled || status.ScheduleState != "complete" ||
		manifest.Protocol != "jtframe-capture-session-v2" || manifest.Version != 2 || manifest.CaptureProtocol != miSTerCaptureProtocolV2 ||
		manifest.SessionID != expected.Attempt.SessionID || manifest.State != "complete" || manifest.Reason != "" ||
		manifest.FPGAGeneration != expected.FPGAGeneration || manifest.PlanCRC32 != planCRC || manifest.PackedCABCRC32 != cabCRC ||
		manifest.PlanTotalFrames != prepared.CAB.TotalFrames || manifest.ExpectedCount != uint32(count) || manifest.CompletedCount != uint32(count) ||
		len(manifest.PlannedCheckpoints) != count || len(manifest.Images) != count {
		return result, fmt.Errorf("capture v2 status/manifest is not a clean complete session")
	}
	if status.ScheduleCRC32 != planCRC || status.PackedCABCRC32 != cabCRC ||
		status.ManifestPath != fmt.Sprintf("/tmp/jtframe-capture-%s.manifest.json", expected.Attempt.SessionID) ||
		status.ScheduleCount != uint32(count) || status.ScheduleIndex != uint32(count) || status.CompletedCount != uint32(count) ||
		status.Checkpoint != prepared.Checkpoints[count-1] || status.MaxHoldMS != expected.MaxHoldMS {
		return result, fmt.Errorf("v2 terminal status does not match the owned schedule")
	}
	terminal := manifest.CABTerminal
	if !terminal.Observed || terminal.Failed || !terminal.CleanupConfirmed || !terminal.InputsNeutral ||
		terminal.Frames != prepared.CAB.TotalFrames || terminal.FramesTotal != prepared.CAB.TotalFrames ||
		terminal.EventsAccepted != cabEventCount || terminal.EventsApplied != cabEventCount || terminal.EventsTotal != cabEventCount {
		return result, fmt.Errorf("v2 manifest has no clean matching CAB terminal")
	}
	if retrievalRoot == "" || len(files.ReceiptJSON) != count || len(files.ReceiptLocal) != count || len(files.PNGLocal) != count {
		return result, fmt.Errorf("retrieved v2 receipt/PNG file set does not match the complete plan")
	}
	root, err := canonicalRetrievalRoot(retrievalRoot)
	if err != nil {
		return result, err
	}
	if len(files.RawRGBLocal) != 0 && len(files.RawRGBLocal) != count {
		return result, fmt.Errorf("optional raw proof set is partial")
	}
	result = MiSTerValidatedCapture{PortableIdentity: identity, Attempt: expected.Attempt,
		FPGAGeneration: expected.FPGAGeneration, PlanCRC32: expected.PlanCRC32, PackedCABCRC32: prepared.CAB.PayloadCRC32,
		Images: make([]MiSTerValidatedImage, 0, count)}
	seenReceipts := make(map[string]bool, count)
	seenPNGs := make(map[string]bool, count)
	owned := make(map[string]bool, count*3)
	var geometry [3]uint32
	lastPNG, lastReceipt := "", miSTerCaptureImageReceiptV2{}
	for index, checkpoint := range prepared.Checkpoints {
		if checkpoint == 0 || checkpoint > prepared.CAB.TotalFrames || (index > 0 && checkpoint <= prepared.Checkpoints[index-1]) ||
			manifest.PlannedCheckpoints[index] != checkpoint {
			return result, fmt.Errorf("v2 checkpoint plan is missing, reordered or invalid")
		}
		ref := manifest.Images[index]
		wantPath := fmt.Sprintf("/tmp/jtframe-capture-%s-checkpoint-%05x.receipt.json", expected.Attempt.SessionID, checkpoint)
		if ref.Checkpoint != checkpoint || ref.FPGAGeneration != expected.FPGAGeneration || ref.PlanCRC32 != planCRC ||
			ref.PackedCABCRC32 != cabCRC || ref.ReceiptPath != wantPath || seenReceipts[ref.ReceiptPath] {
			return result, fmt.Errorf("v2 manifest image reference %d is missing or bound to another attempt", index)
		}
		seenReceipts[ref.ReceiptPath] = true
		receiptJSON, ok := files.ReceiptJSON[ref.ReceiptPath]
		if !ok {
			return result, fmt.Errorf("missing v2 receipt %s", ref.ReceiptPath)
		}
		localReceipt, ok := files.ReceiptLocal[ref.ReceiptPath]
		wantLocalReceipt := filepath.Join(root, fmt.Sprintf("receipt_%08d.json", checkpoint))
		if !ok || localReceipt != wantLocalReceipt {
			return result, fmt.Errorf("v2 receipt is not at its deterministic owned path")
		}
		owned[filepath.Base(wantLocalReceipt)] = true
		stored, err := readOwnedReceipt(root, localReceipt)
		if err != nil || !bytes.Equal(stored, receiptJSON) {
			return result, fmt.Errorf("v2 local receipt is unsafe or differs from retrieved bytes")
		}
		receipt, err := decodeMiSTerCaptureImageReceiptV2(receiptJSON)
		if err != nil {
			return result, fmt.Errorf("checkpoint %d: %w", checkpoint, err)
		}
		if err := validateMiSTerImageReceiptV2(receipt, expected, ref, checkpoint); err != nil {
			return result, fmt.Errorf("checkpoint %d: %w", checkpoint, err)
		}
		if index == 0 {
			geometry = [3]uint32{receipt.Width, receipt.Height, receipt.RowPitch}
		} else if geometry != [3]uint32{receipt.Width, receipt.Height, receipt.RowPitch} {
			return result, fmt.Errorf("checkpoint %d changed native image geometry", checkpoint)
		}
		if seenPNGs[receipt.PNGPath] {
			return result, fmt.Errorf("duplicate v2 PNG path")
		}
		seenPNGs[receipt.PNGPath] = true
		localPNG, ok := files.PNGLocal[receipt.PNGPath]
		wantLocalPNG := filepath.Join(root, CapturePNGLocalName(checkpoint))
		if !ok || localPNG != wantLocalPNG {
			return result, fmt.Errorf("checkpoint %d PNG is not at its deterministic owned path", checkpoint)
		}
		owned[filepath.Base(wantLocalPNG)] = true
		legacy := normalizeV2ImageReceipt(receipt)
		validatedImage, err := validateRetrievedPNG(root, localPNG, legacy)
		if err != nil {
			return result, fmt.Errorf("checkpoint %d: %w", checkpoint, err)
		}
		validatedImage.Sequence = 0
		if receipt.RawRGBPath != "" {
			localRaw, ok := files.RawRGBLocal[receipt.RawRGBPath]
			wantRaw := filepath.Join(root, fmt.Sprintf("proof_%08d.rgb", checkpoint))
			if !ok || localRaw != wantRaw {
				return result, fmt.Errorf("checkpoint %d raw proof path is not the deterministic owned path", checkpoint)
			}
			owned[filepath.Base(wantRaw)] = true
			if err := validateRawRGBProof(root, localRaw, legacy, validatedImage.DecodedRGBSHA256); err != nil {
				return result, fmt.Errorf("checkpoint %d: %w", checkpoint, err)
			}
		} else if receipt.RawRGBSize != 0 {
			return result, fmt.Errorf("checkpoint %d raw proof size has no path", checkpoint)
		}
		result.Images = append(result.Images, validatedImage)
		lastPNG, lastReceipt = receipt.PNGPath, receipt
	}
	if err := rejectUnexpectedCaptureFiles(root, owned); err != nil {
		return result, err
	}
	if len(files.RawRGBLocal) > 0 {
		for remote := range files.RawRGBLocal {
			found := false
			for _, ref := range manifest.Images {
				r, _ := decodeMiSTerCaptureImageReceiptV2(files.ReceiptJSON[ref.ReceiptPath])
				if r.RawRGBPath == remote && remote != "" {
					found = true
					break
				}
			}
			if !found {
				return result, fmt.Errorf("unexpected raw proof mapping")
			}
		}
	}
	if status.Output != lastPNG || status.CopiedBytes != uint64(lastReceipt.PayloadBytes) {
		return result, fmt.Errorf("v2 status output/payload does not match the last image")
	}
	result.CaptureProtocol = miSTerCaptureProtocolV2
	return result, nil
}

func validateMiSTerImageReceiptV2(r miSTerCaptureImageReceiptV2, expected MiSTerReceiptExpectation,
	ref miSTerCaptureReceiptRefV2, checkpoint uint32) error {
	planCRC, cabCRC := fmt.Sprintf("%08x", expected.PlanCRC32), fmt.Sprintf("%08x", expected.Prepared.CAB.PayloadCRC32)
	if r.Protocol != "jtframe-capture-image-v2" || r.CaptureProtocol != miSTerCaptureProtocolV2 || r.SessionID != expected.Attempt.SessionID ||
		r.FPGAGeneration != expected.FPGAGeneration || r.PlanCRC32 != planCRC || r.PackedCABCRC32 != cabCRC ||
		r.RequestedCheckpoint != checkpoint || r.ActualCheckpoint != checkpoint || r.DescriptorCheckpoint != checkpoint ||
		checkpoint == 0 || r.ActualInterval+1 != checkpoint || r.Width == 0 || r.Height == 0 || r.Width > 4095 || r.Height > 4095 ||
		r.ActualCheckpoint > expected.Prepared.CAB.TotalFrames || !r.ReleaseConfirmed || !r.PNGComplete || r.FinalIssued != r.FinalCompleted ||
		r.PNGSize == 0 || r.PNGSize > miSTerPNGMaxBytes ||
		ref.Checkpoint != checkpoint || ref.FPGAGeneration != r.FPGAGeneration || ref.PlanCRC32 != r.PlanCRC32 || ref.PackedCABCRC32 != r.PackedCABCRC32 {
		return fmt.Errorf("v2 image receipt is incomplete or belongs to another attempt")
	}
	if !validScheduledPNGPathV2(r.PNGPath, r.SessionID, checkpoint) {
		return fmt.Errorf("v2 PNG path is not bound to the session/checkpoint")
	}
	if r.RawRGBPath == "" {
		if r.RawRGBSize != 0 {
			return fmt.Errorf("raw proof size has no path")
		}
	} else {
		proofRoot := path.Dir(r.RawRGBPath)
		proofRootOK := proofRoot == "/tmp/jtframe-capture-proof" || strings.HasPrefix(proofRoot, "/tmp/jtframe-capture-proof-") || strings.HasPrefix(proofRoot, "/tmp/jtframe-capture-proof/")
		want := fmt.Sprintf("%s-%05x.rgb", r.SessionID, checkpoint)
		if !cleanRemotePath(r.RawRGBPath) || !proofRootOK || path.Base(r.RawRGBPath) != want || r.RawRGBSize == 0 || r.RawRGBSize != uint64(r.PayloadBytes) {
			return fmt.Errorf("v2 raw proof path/size is invalid")
		}
	}
	desc, err := decodeFixedHex(r.DescriptorBytesHex, 64)
	if err != nil {
		return fmt.Errorf("descriptor bytes: %w", err)
	}
	before, err := decodeFixedHex(r.HeaderBeforeHex, 256)
	if err != nil {
		return fmt.Errorf("header-before: %w", err)
	}
	after, err := decodeFixedHex(r.HeaderAfterHex, 256)
	if err != nil {
		return fmt.Errorf("header-after: %w", err)
	}
	dcrc, err := parseHex32(r.DescriptorCRC32)
	if err != nil || dcrc != crc32.ChecksumIEEE(desc[:56]) || binary.LittleEndian.Uint32(desc[56:60]) != dcrc {
		return fmt.Errorf("v2 descriptor CRC mismatch")
	}
	bcrc, err := parseHex32(r.HeaderBeforeCRC32)
	if err != nil || bcrc != crc32.ChecksumIEEE(before) {
		return fmt.Errorf("header-before CRC mismatch")
	}
	acrc, err := parseHex32(r.HeaderAfterCRC32)
	if err != nil || acrc != crc32.ChecksumIEEE(after) || !bytes.Equal(before, after) {
		return fmt.Errorf("stable header check failed")
	}
	if string(desc[:4]) != "JTC2" || binary.LittleEndian.Uint16(desc[4:6]) != 2 || binary.LittleEndian.Uint16(desc[6:8]) != 64 ||
		binary.LittleEndian.Uint16(desc[8:10]) != uint16(checkpoint) || binary.LittleEndian.Uint16(desc[10:12]) != uint16(checkpoint-1) ||
		!allZero(desc[44:56]) || string(desc[60:64]) != "RDY2" {
		return fmt.Errorf("v2 descriptor magic/version/checkpoint fields are invalid")
	}
	slotBase, err := parseHex32(r.SlotBase)
	if err != nil {
		return fmt.Errorf("invalid slot base")
	}
	mode, err := parseHex32(r.Mode)
	if err != nil {
		return fmt.Errorf("invalid capture mode")
	}
	if r.Slot > 2 || (r.SlotStride != miSTerSlotStride2 && r.SlotStride != miSTerSlotStride8) || slotBase != 0x20000000+r.Slot*r.SlotStride ||
		((mode>>8)&3) != r.Slot || mode&0xff != miSTerRGBMode || mode&(1<<10) == 0 || mode&(1<<11) == 0 || mode&(1<<12) != 0 || mode&0xffffe000 != 0 {
		return fmt.Errorf("unsupported v2 slot/mode")
	}
	rowPitch := ((uint64(r.Width)*3 + 255) / 256) * 256
	payload := uint64(r.RowPitch) * uint64(r.Height)
	if uint64(r.RowPitch) != rowPitch || payload != uint64(r.PayloadBytes) || r.SlotStride <= 256 || payload > uint64(r.SlotStride)-256 || r.RowPitch > r.SlotStride-256 {
		return fmt.Errorf("v2 RGB pitch/payload bounds invalid")
	}
	if binary.LittleEndian.Uint32(desc[12:16]) != slotBase || binary.LittleEndian.Uint32(desc[16:20]) != r.SlotStride ||
		binary.LittleEndian.Uint16(desc[20:22]) != uint16(r.Width) || binary.LittleEndian.Uint16(desc[22:24]) != uint16(r.Height) ||
		binary.LittleEndian.Uint32(desc[24:28]) != r.RowPitch || binary.LittleEndian.Uint32(desc[28:32]) != r.PayloadBytes ||
		binary.LittleEndian.Uint32(desc[32:36]) != mode || binary.LittleEndian.Uint32(desc[36:40]) != r.FinalIssued ||
		binary.LittleEndian.Uint32(desc[40:44]) != r.FinalCompleted {
		return fmt.Errorf("v2 descriptor fields disagree with receipt")
	}
	if before[0] != 1 || before[1] != 1 || binary.BigEndian.Uint16(before[2:4]) != 256 || binary.BigEndian.Uint16(before[4:6])&0x000f != 0 ||
		binary.BigEndian.Uint16(before[6:8]) != uint16(r.Width) || binary.BigEndian.Uint16(before[8:10]) != uint16(r.Height) ||
		binary.BigEndian.Uint16(before[10:12]) != uint16(r.RowPitch) || binary.BigEndian.Uint16(before[12:14]) == 0 ||
		binary.BigEndian.Uint16(before[14:16]) == 0 || binary.BigEndian.Uint16(before[12:14]) > 4095 || binary.BigEndian.Uint16(before[14:16]) > 4095 ||
		!bytes.Equal(before[192:256], desc) {
		return fmt.Errorf("v2 legacy header is invalid or does not embed descriptor")
	}
	return nil
}

func normalizeV2ImageReceipt(r miSTerCaptureImageReceiptV2) MiSTerCaptureImageReceipt {
	return MiSTerCaptureImageReceipt{Protocol: r.Protocol, SessionID: r.SessionID, FPGAGeneration: r.FPGAGeneration,
		PlanCRC32: r.PlanCRC32, PackedCABCRC32: r.PackedCABCRC32, RequestedCheckpoint: r.RequestedCheckpoint,
		ActualInterval: r.ActualInterval, ActualCheckpoint: r.ActualCheckpoint, DescriptorCheckpoint: r.DescriptorCheckpoint,
		Width: r.Width, Height: r.Height, RowPitch: r.RowPitch, PayloadBytes: r.PayloadBytes, SlotBase: r.SlotBase,
		SlotStride: r.SlotStride, Slot: r.Slot, Mode: r.Mode, DescriptorCRC32: r.DescriptorCRC32,
		HeaderBeforeCRC32: r.HeaderBeforeCRC32, HeaderAfterCRC32: r.HeaderAfterCRC32, DescriptorBytesHex: r.DescriptorBytesHex,
		HeaderBeforeHex: r.HeaderBeforeHex, HeaderAfterHex: r.HeaderAfterHex, FinalIssued: r.FinalIssued, FinalCompleted: r.FinalCompleted,
		ReleaseConfirmed: r.ReleaseConfirmed, PNGComplete: r.PNGComplete, PNGPath: r.PNGPath, PNGSize: r.PNGSize,
		RawRGBPath: r.RawRGBPath, RawRGBSize: r.RawRGBSize}
}

func validScheduledPNGPathV2(value, sessionID string, checkpoint uint32) bool {
	if !cleanRemotePath(value) || !strings.HasPrefix(value, "/media/fat/screenshots/") {
		return false
	}
	coreDir := path.Dir(value)
	if path.Dir(coreDir) != "/media/fat/screenshots" || path.Base(coreDir) == "" || path.Base(coreDir) == "." {
		return false
	}
	name := path.Base(value)
	basename := fmt.Sprintf("cabcap_%s_%04x", sessionID, checkpoint)
	if !strings.HasSuffix(name, ".png") {
		return false
	}
	return strings.Contains(name[:len(name)-4], basename)
}

func allZero(data []byte) bool {
	for _, value := range data {
		if value != 0 {
			return false
		}
	}
	return true
}
