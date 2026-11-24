/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
)

const (
	maxCaptureStatusJSONBytes = 64 << 10
	maxCaptureManifestBytes   = 2 << 20
	maxCaptureReceiptBytes    = 16 << 10
)

// MiSTerCaptureStatus is the exact jtframe-capture-session-v1 status schema
// emitted by accepted Main. Hexadecimal epochs and sequences remain strings
// on the wire; the status has no numeric version field.
type MiSTerCaptureStatus struct {
	Protocol           string `json:"protocol"`
	SessionID          string `json:"session_id"`
	State              string `json:"state"`
	Epoch              string `json:"epoch"`
	Sequence           string `json:"sequence"`
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
	ReceiptProtocol    string `json:"receipt_protocol"`
	ManifestPath       string `json:"manifest_path"`
	CompletedCount     uint32 `json:"completed_count"`
}

// MiSTerCABTerminal is the nested terminal snapshot in a complete manifest.
type MiSTerCABTerminal struct {
	Observed         bool   `json:"observed"`
	Failed           bool   `json:"failed"`
	CleanupConfirmed bool   `json:"cleanup_confirmed"`
	InputsNeutral    bool   `json:"inputs_neutral"`
	Epoch            uint32 `json:"epoch"`
	Frames           uint32 `json:"frames"`
	FramesTotal      uint32 `json:"frames_total"`
	EventsAccepted   uint32 `json:"events_accepted"`
	EventsApplied    uint32 `json:"events_applied"`
	EventsTotal      uint32 `json:"events_total"`
}

// MiSTerCaptureReceiptRef binds one ordered sequence/checkpoint to its
// immutable Main receipt path. Main serializes epoch/CRCs as lowercase hex.
type MiSTerCaptureReceiptRef struct {
	Sequence       uint32 `json:"sequence"`
	Checkpoint     uint32 `json:"checkpoint"`
	Epoch          string `json:"epoch"`
	FPGAGeneration uint32 `json:"fpga_generation"`
	PlanCRC32      string `json:"plan_crc32"`
	PackedCABCRC32 string `json:"packed_cab_crc32"`
	ReceiptPath    string `json:"receipt_path"`
}

// MiSTerCaptureManifest is the exact versioned session manifest emitted by
// CabCaptureReceiptStore. It is distinct from the unversioned progress status.
type MiSTerCaptureManifest struct {
	Protocol           string                    `json:"protocol"`
	Version            uint32                    `json:"version"`
	SessionID          string                    `json:"session_id"`
	State              string                    `json:"state"`
	Reason             string                    `json:"reason"`
	FPGAGeneration     uint32                    `json:"fpga_generation"`
	PlanCRC32          string                    `json:"plan_crc32"`
	PackedCABCRC32     string                    `json:"packed_cab_crc32"`
	Epoch              string                    `json:"epoch"`
	PlanTotalFrames    uint32                    `json:"plan_total_frames"`
	ExpectedCount      uint32                    `json:"expected_count"`
	PlannedCheckpoints []uint32                  `json:"planned_checkpoints"`
	CompletedCount     uint32                    `json:"completed_count"`
	Images             []MiSTerCaptureReceiptRef `json:"images"`
	CABTerminal        MiSTerCABTerminal         `json:"cab_terminal"`
}

var captureStatusKeys = []string{
	"protocol", "session_id", "state", "epoch", "sequence", "checkpoint", "max_hold_ms", "fault",
	"cleanup_confirmed", "reload_required", "status_write_failed", "receipt_write_failed", "copied_bytes",
	"encoder_busy", "output", "scheduled", "schedule_crc32", "packed_cab_crc32", "schedule_count",
	"schedule_index", "schedule_state", "receipt_protocol", "manifest_path", "completed_count",
}

var captureManifestKeys = []string{
	"protocol", "version", "session_id", "state", "reason", "fpga_generation", "plan_crc32",
	"packed_cab_crc32", "epoch", "plan_total_frames", "expected_count", "planned_checkpoints",
	"completed_count", "images", "cab_terminal",
}

var captureReceiptRefKeys = []string{
	"sequence", "checkpoint", "epoch", "fpga_generation", "plan_crc32", "packed_cab_crc32", "receipt_path",
}

var captureCABTerminalKeys = []string{
	"observed", "failed", "cleanup_confirmed", "inputs_neutral", "epoch", "frames", "frames_total",
	"events_accepted", "events_applied", "events_total",
}

// DecodeMiSTerCaptureStatus rejects duplicate keys, nulls, missing or unknown
// fields, incorrect JSON types, and oversized input before returning a status.
func DecodeMiSTerCaptureStatus(data []byte) (MiSTerCaptureStatus, error) {
	var status MiSTerCaptureStatus
	if err := strictJSONDecode(data, maxCaptureStatusJSONBytes, captureStatusKeys, &status); err != nil {
		return status, fmt.Errorf("decode MiSTer capture status: %w", err)
	}
	return status, nil
}

// DecodeMiSTerCaptureManifest validates the complete E914 manifest shape,
// including required nested terminal and image-reference fields.
func DecodeMiSTerCaptureManifest(data []byte) (MiSTerCaptureManifest, error) {
	var manifest MiSTerCaptureManifest
	root, err := strictJSONValue(data, maxCaptureManifestBytes)
	if err != nil {
		return manifest, fmt.Errorf("decode MiSTer capture manifest: %w", err)
	}
	object, ok := root.(map[string]interface{})
	if !ok {
		return manifest, fmt.Errorf("capture manifest must be a JSON object")
	}
	if err := requireJSONKeys(object, captureManifestKeys); err != nil {
		return manifest, fmt.Errorf("capture manifest: %w", err)
	}
	terminal, ok := object["cab_terminal"].(map[string]interface{})
	if !ok {
		return manifest, fmt.Errorf("capture manifest cab_terminal must be an object")
	}
	if err := requireJSONKeys(terminal, captureCABTerminalKeys); err != nil {
		return manifest, fmt.Errorf("capture manifest cab_terminal: %w", err)
	}
	images, ok := object["images"].([]interface{})
	if !ok {
		return manifest, fmt.Errorf("capture manifest images must be an array")
	}
	for index, image := range images {
		ref, ok := image.(map[string]interface{})
		if !ok {
			return manifest, fmt.Errorf("capture manifest images[%d] must be an object", index)
		}
		if err := requireJSONKeys(ref, captureReceiptRefKeys); err != nil {
			return manifest, fmt.Errorf("capture manifest images[%d]: %w", index, err)
		}
	}
	if err := decodeJSONValue(root, &manifest); err != nil {
		return manifest, fmt.Errorf("decode MiSTer capture manifest fields: %w", err)
	}
	return manifest, nil
}

func strictJSONDecode(data []byte, maxBytes int, keys []string, target interface{}) error {
	root, err := strictJSONValue(data, maxBytes)
	if err != nil {
		return err
	}
	object, ok := root.(map[string]interface{})
	if !ok {
		return fmt.Errorf("JSON root must be an object")
	}
	if err := requireJSONKeys(object, keys); err != nil {
		return err
	}
	return decodeJSONValue(root, target)
}

func strictJSONValue(data []byte, maxBytes int) (interface{}, error) {
	if len(data) == 0 || len(data) > maxBytes {
		return nil, fmt.Errorf("JSON size must be in 1..%d bytes", maxBytes)
	}
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.UseNumber()
	value, err := readUniqueJSONValue(decoder)
	if err != nil {
		return nil, err
	}
	if _, err := decoder.Token(); err != io.EOF {
		if err == nil {
			return nil, fmt.Errorf("trailing JSON value")
		}
		return nil, fmt.Errorf("trailing JSON data: %w", err)
	}
	return value, nil
}

func readUniqueJSONValue(decoder *json.Decoder) (interface{}, error) {
	token, err := decoder.Token()
	if err != nil {
		return nil, err
	}
	if delimiter, ok := token.(json.Delim); ok {
		switch delimiter {
		case '{':
			object := make(map[string]interface{})
			for decoder.More() {
				keyToken, err := decoder.Token()
				if err != nil {
					return nil, err
				}
				key, ok := keyToken.(string)
				if !ok {
					return nil, fmt.Errorf("object key is not a string")
				}
				if _, duplicate := object[key]; duplicate {
					return nil, fmt.Errorf("duplicate JSON key %q", key)
				}
				value, err := readUniqueJSONValue(decoder)
				if err != nil {
					return nil, err
				}
				object[key] = value
			}
			end, err := decoder.Token()
			if err != nil || end != json.Delim('}') {
				return nil, fmt.Errorf("unterminated JSON object")
			}
			return object, nil
		case '[':
			array := make([]interface{}, 0)
			for decoder.More() {
				value, err := readUniqueJSONValue(decoder)
				if err != nil {
					return nil, err
				}
				array = append(array, value)
			}
			end, err := decoder.Token()
			if err != nil || end != json.Delim(']') {
				return nil, fmt.Errorf("unterminated JSON array")
			}
			return array, nil
		default:
			return nil, fmt.Errorf("unexpected JSON delimiter %q", delimiter)
		}
	}
	if token == nil {
		return nil, fmt.Errorf("JSON null is not allowed")
	}
	return token, nil
}

func requireJSONKeys(object map[string]interface{}, required []string) error {
	if len(object) != len(required) {
		return fmt.Errorf("field count is %d, want exactly %d", len(object), len(required))
	}
	for _, key := range required {
		if _, exists := object[key]; !exists {
			return fmt.Errorf("missing required field %q", key)
		}
	}
	return nil
}

func decodeJSONValue(value interface{}, target interface{}) error {
	encoded, err := json.Marshal(value)
	if err != nil {
		return err
	}
	decoder := json.NewDecoder(bytes.NewReader(encoded))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return err
	}
	return nil
}
