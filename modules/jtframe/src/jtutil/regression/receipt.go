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
	"strings"
)

// A receipt retains capture identity, never another copy of its images.
type capture_receipt_data struct {
	Schema int `json:"schema"`
	Width int `json:"width"`
	Height int `json:"height"`
	Format string `json:"native_format"`
	Frames []capture_frame_receipt `json:"frames"`
}

type capture_frame_receipt struct {
	Requested int `json:"requested"`
	Actual int `json:"actual"`
	RGBSHA256 string `json:"rgb_sha256"`
	LegacyRequestOnlyName bool `json:"legacy_request_only_name,omitempty"`
}

func write_capture_receipt(dir string, set CaptureSet) error {
	receipt, err := make_capture_receipt(set)
	if err != nil { return err }
	return save_capture_receipt(dir, receipt)
}

func make_capture_receipt(set CaptureSet) (capture_receipt_data, error) {
	receipt := capture_receipt_data{Schema: 1, Width: set.Width, Height: set.Height, Format: strings.ToLower(set.Format)}
	for _, frame := range set.Captures {
		decoded, err := decode_capture_image(filepath.Join(set.Dir, frame.Image))
		if err != nil { return receipt, err }
		if decoded.width != receipt.Width || decoded.height != receipt.Height { return receipt, fmt.Errorf("receipt geometry changed") }
		legacy_name := false
		if requested, actual, parse_error := parse_png_capture_name(frame.Image); parse_error==nil && requested==frame.Requested && actual==requested && frame.Actual!=requested { legacy_name = true }
		receipt.Frames = append(receipt.Frames, capture_frame_receipt{Requested: frame.Requested, Actual: frame.Actual, RGBSHA256: decoded_rgb_sha256(decoded), LegacyRequestOnlyName: legacy_name})
	}
	return receipt, nil
}

// The canonical byte stream is row-major R,G,B bytes after native pixel
// expansion. Geometry and native format are bound by the receipt and metadata.
func decoded_rgb_sha256(frame decodedImage) string {
	data := make([]byte, len(frame.pixels)*3)
	for i, pixel := range frame.pixels { data[i*3], data[i*3+1], data[i*3+2] = byte(pixel>>16), byte(pixel>>8), byte(pixel) }
	hash := sha256.Sum256(data)
	return hex.EncodeToString(hash[:])
}

func save_capture_receipt(dir string, receipt capture_receipt_data) error {
	data, err := json.MarshalIndent(receipt, "", "  ")
	if err != nil { return err }
	return atomic_write(filepath.Join(dir, "frames.json"), append(data, '\n'), 0640)
}

func read_capture_receipt(dir string, profile Profile, native_format string) (capture_receipt_data, bool, error) {
	var receipt capture_receipt_data
	data, err := os.ReadFile(filepath.Join(dir, "frames.json"))
	legacy := os.IsNotExist(err)
	if legacy {
		set, read_error := read_png_capture_set(dir, profile.Video, profile.Startup, 100)
		if read_error != nil { return receipt, true, read_error }
		if read_error = restore_transport_timing(dir, &set); read_error != nil { return receipt, true, read_error }
		set.Format = strings.ToLower(native_format)
		receipt, err = make_capture_receipt(set)
	} else if err == nil { err = json.Unmarshal(data, &receipt) }
	if err != nil { return receipt, legacy, err }
	if err = validate_capture_receipt(receipt, profile, native_format); err != nil { return receipt, legacy, err }
	return receipt, legacy, nil
}

func validate_capture_receipt(receipt capture_receipt_data, profile Profile, native_format string) error {
	if receipt.Schema != 1 || receipt.Width<1 || receipt.Width>512 || receipt.Height<1 || receipt.Height>512 || receipt.Format != strings.ToLower(native_format) || receipt.Format != "rgb444" && receipt.Format != "rgb555" {
		return fmt.Errorf("invalid capture receipt geometry or native format")
	}
	if profile.Video<100 || len(receipt.Frames) != profile.Video/100 { return fmt.Errorf("capture receipt checkpoint count differs") }
	seen := map[int]bool{}
	for _, frame := range receipt.Frames {
		if frame.Requested<100 || frame.Requested>profile.Video || frame.Requested%100!=0 || seen[frame.Requested] || frame.Actual<1 || frame.Requested>profile.Startup && frame.Actual!=frame.Requested { return fmt.Errorf("invalid capture receipt checkpoint") }
		seen[frame.Requested] = true
		if frame.LegacyRequestOnlyName && (frame.Requested>profile.Startup || frame.Actual==frame.Requested) { return fmt.Errorf("invalid legacy startup filename receipt") }
		hash, err := hex.DecodeString(frame.RGBSHA256)
		if err != nil || len(hash)!=sha256.Size { return fmt.Errorf("invalid capture receipt RGB digest") }
	}
	return nil
}

// Legacy receipts retained PNG copies plus the original transport index. The
// index restores actual startup timing that canonical PNG names cannot carry.
func restore_transport_timing(dir string, set *CaptureSet) error {
	data, err := os.ReadFile(filepath.Join(dir, "transport-index.jsonl"))
	if err != nil { return err }
	actual := map[int]int{}
	started, complete := false, false
	for _, line := range strings.Split(strings.TrimSpace(string(data)), "\n") {
		var record struct {
			Type string `json:"type"`
			Requested int `json:"requested"`
			Actual int `json:"actual"`
			Count int `json:"count"`
			Captures int `json:"captures"`
			Width int `json:"width"`
			Height int `json:"height"`
		}
		if err = json.Unmarshal([]byte(line), &record); err != nil { return err }
		if complete { return fmt.Errorf("legacy transport index has data after completion") }
		switch record.Type {
		case "run":
			if started || record.Count!=len(set.Captures) || record.Width!=set.Width || record.Height!=set.Height { return fmt.Errorf("legacy transport geometry or count differs") }
			started = true
		case "capture":
			if !started || record.Actual<1 || actual[record.Requested]!=0 { return fmt.Errorf("invalid legacy transport checkpoint") }
			actual[record.Requested] = record.Actual
		case "complete":
			if !started || record.Captures!=len(set.Captures) { return fmt.Errorf("invalid legacy transport completion") }
			complete = true
		default: return fmt.Errorf("invalid legacy transport record")
		}
	}
	if !complete || len(actual)!=len(set.Captures) { return fmt.Errorf("incomplete legacy transport index") }
	for i := range set.Captures {
		value := actual[set.Captures[i].Requested]
		if value<1 { return fmt.Errorf("legacy transport checkpoint missing") }
		set.Captures[i].Actual = value
	}
	return nil
}

func receipt_matches_pngs(receipt capture_receipt_data, set CaptureSet, startup int) bool {
	if receipt.Width!=set.Width || receipt.Height!=set.Height || len(receipt.Frames)!=len(set.Captures) { return false }
	hashes := map[int]capture_frame_receipt{}
	for _, frame := range receipt.Frames { hashes[frame.Requested] = frame }
	for _, frame := range set.Captures {
		if frame.Requested<=startup { continue }
		expected := hashes[frame.Requested]
		if frame.Actual!=expected.Actual && !(expected.LegacyRequestOnlyName && frame.Actual==frame.Requested && frame.Image==png_capture_name(frame.Requested,frame.Requested)) { return false }
		decoded, err := decode_capture_image(filepath.Join(set.Dir, frame.Image))
		if err!=nil || decoded_rgb_sha256(decoded)!=expected.RGBSHA256 { return false }
	}
	return true
}

// Delete old duplicate images only after every remaining file is independently
// matched to the durable JSON receipt. A partially completed cleanup can retry.
func remove_legacy_receipt_pngs(dir string, receipt capture_receipt_data) error {
	files, err := filepath.Glob(filepath.Join(dir, "frame_*.png"))
	if err != nil { return err }
	hashes := map[string]string{}
	for _, frame := range receipt.Frames { hashes[png_capture_name(frame.Requested, frame.Actual)] = frame.RGBSHA256; hashes[png_capture_name(frame.Requested, frame.Requested)] = frame.RGBSHA256 }
	for _, path := range files {
		info, stat_error := os.Lstat(path)
		if stat_error!=nil { return stat_error }
		if !info.Mode().IsRegular() { return fmt.Errorf("legacy receipt PNG is not a regular file") }
		decoded, read_error := decode_capture_image(path)
		if read_error!=nil { return read_error }
		if decoded.width!=receipt.Width || decoded.height!=receipt.Height || decoded_rgb_sha256(decoded)!=hashes[filepath.Base(path)] { return fmt.Errorf("legacy receipt PNG does not match its digest") }
	}
	for _, path := range files { if err = os.Remove(path); err != nil { return err } }
	return nil
}
