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
	"image/png"
	"io"
	"os"
	"path"
	"path/filepath"
	"strings"
)

const (
	miSTerPNGMaxBytes = 16 << 20
	miSTerRGBMode     = uint32(1)
	miSTerSlotStride2 = uint32(0x00200000)
	miSTerSlotStride8 = uint32(0x00800000)
)

// MiSTerCaptureImageReceipt matches the complete jtframe-capture-image-v1
// JSON object written by accepted Main. No transport-local hash or release
// acknowledgement field is inferred here.
type MiSTerCaptureImageReceipt struct {
	Protocol             string `json:"protocol"`
	SessionID            string `json:"session_id"`
	FPGAGeneration       uint32 `json:"fpga_generation"`
	PlanCRC32            string `json:"plan_crc32"`
	PackedCABCRC32       string `json:"packed_cab_crc32"`
	Epoch                string `json:"epoch"`
	Sequence             uint32 `json:"sequence"`
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
	PNGComplete          bool   `json:"png_complete"`
	PNGPath              string `json:"png_path"`
	PNGSize              uint64 `json:"png_size"`
	RawRGBPath           string `json:"raw_rgb_path"`
	RawRGBSize           uint64 `json:"raw_rgb_size"`
}

var captureImageReceiptKeys = []string{
	"protocol", "session_id", "fpga_generation", "plan_crc32", "packed_cab_crc32", "epoch", "sequence",
	"requested_checkpoint", "actual_interval", "actual_checkpoint", "descriptor_checkpoint", "width", "height",
	"row_pitch", "payload_bytes", "slot_base", "slot_stride", "slot", "mode", "descriptor_crc32",
	"header_before_crc32", "header_after_crc32", "descriptor_bytes_hex", "header_before_hex", "header_after_hex",
	"final_issued", "final_completed", "release_confirmed", "png_complete", "png_path", "png_size",
	"raw_rgb_path", "raw_rgb_size",
}

// DecodeMiSTerCaptureImageReceipt strictly decodes a Main image receipt.
func DecodeMiSTerCaptureImageReceipt(data []byte) (MiSTerCaptureImageReceipt, error) {
	var receipt MiSTerCaptureImageReceipt
	if err := strictJSONDecode(data, maxCaptureReceiptBytes, captureImageReceiptKeys, &receipt); err != nil {
		return receipt, fmt.Errorf("decode MiSTer image receipt: %w", err)
	}
	return receipt, nil
}

// MiSTerReceiptExpectation binds wire facts to immutable host-owned inputs.
// PlanCRC32 and FPGAGeneration come from the staged/verified attempt; MaxHoldMS
// is the plan hold used for every checkpoint in this initial contract.
type MiSTerReceiptExpectation struct {
	Prepared       PreparedSession
	PackedCAB      []byte // Exact bytes whose SHA/CRC/event count are bound by Prepared.CAB.
	Attempt        AttemptKey
	FPGAGeneration uint32
	PlanCRC32      uint32
	MaxHoldMS      uint32
	RequireCaptureV2 bool // Live board sessions require v2; false is reserved for read-only v1 history validation.
}

// MiSTerRetrievedFiles associates exact remote names with owned local paths.
// PNG files are staged as frame_%08d.png under the supplied retrieval root.
// Raw RGB is optional and used only for qualification proof.
type MiSTerRetrievedFiles struct {
	ReceiptJSON  map[string][]byte
	ReceiptLocal map[string]string
	PNGLocal     map[string]string
	RawRGBLocal  map[string]string
}

type MiSTerValidatedImage struct {
	Sequence         uint32
	Checkpoint       uint32
	Width            uint32
	Height           uint32
	RowPitch         uint32
	Slot             uint32
	Mode             uint32
	DescriptorCRC32  uint32
	PNGPath          string
	PNGSize          uint64
	PNGFileSHA256    string
	DecodedRGBSHA256 string
}

type MiSTerValidatedCapture struct {
	PortableIdentity string
	Attempt          AttemptKey
	FPGAGeneration   uint32
	PlanCRC32        uint32
	PackedCABCRC32   uint32
	CaptureProtocol  string
	Epoch            uint32
	Images           []MiSTerValidatedImage
}

// CapturePNGLocalName is the deterministic, path-safe local name for a
// checkpoint. It intentionally ignores the remote screenshot basename.
func CapturePNGLocalName(checkpoint uint32) string {
	return fmt.Sprintf("frame_%08d.png", checkpoint)
}

// ValidateMiSTerCapture validates a completed Main session, every immutable
// frame receipt, the identical native headers/descriptors, and retrieved PNGs.
// It performs no network or board I/O.
func ValidateMiSTerCapture(expected MiSTerReceiptExpectation, statusJSON, manifestJSON []byte,
	files MiSTerRetrievedFiles, retrievalRoot string) (MiSTerValidatedCapture, error) {
	protocol, err := captureProtocolFromJSON(statusJSON, maxCaptureStatusJSONBytes)
	if err != nil {
		return MiSTerValidatedCapture{}, fmt.Errorf("decode MiSTer capture status protocol: %w", err)
	}
	if protocol == "jtframe-capture-session-v2" {
		return validateMiSTerCaptureV2(expected, statusJSON, manifestJSON, files, retrievalRoot)
	}
	if protocol != "jtframe-capture-session-v1" {
		return MiSTerValidatedCapture{}, fmt.Errorf("unsupported MiSTer capture status protocol %q", protocol)
	}
	if expected.RequireCaptureV2 {
		return MiSTerValidatedCapture{}, fmt.Errorf("live MiSTer capture requires session-v2; v1 is read-only historical data")
	}
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
	cabEventCount := binary.LittleEndian.Uint32(expected.PackedCAB[16:20]) // Framing is validated above.
	packedSHA := sha256.Sum256(expected.PackedCAB)
	if hex.EncodeToString(packedSHA[:]) != prepared.CAB.PackedSHA256 ||
		cabHeader.payloadCRC32 != prepared.CAB.PayloadCRC32 || cabHeader.totalFrames != prepared.CAB.TotalFrames ||
		cabEventCount == 0 || cabEventCount > cabHeader.totalFrames {
		return result, fmt.Errorf("prepared packed CAB bytes do not match their immutable identity")
	}
	status, err := DecodeMiSTerCaptureStatus(statusJSON)
	if err != nil {
		return result, err
	}
	manifest, err := DecodeMiSTerCaptureManifest(manifestJSON)
	if err != nil {
		return result, err
	}
	planCRC := fmt.Sprintf("%08x", expected.PlanCRC32)
	cabCRC := fmt.Sprintf("%08x", prepared.CAB.PayloadCRC32)
	if err := validateMiSTerSessionStatus(status, manifest, expected, planCRC, cabCRC, cabEventCount); err != nil {
		return result, err
	}
	if retrievalRoot == "" || len(files.ReceiptJSON) != len(prepared.Checkpoints) ||
		len(files.ReceiptLocal) != len(prepared.Checkpoints) ||
		len(files.PNGLocal) != len(prepared.Checkpoints) {
		return result, fmt.Errorf("retrieved receipt/PNG file set does not match the complete plan")
	}
	root, err := canonicalRetrievalRoot(retrievalRoot)
	if err != nil {
		return result, err
	}
	if len(files.RawRGBLocal) != 0 && len(files.RawRGBLocal) != len(prepared.Checkpoints) {
		return result, fmt.Errorf("optional raw proof set is partial")
	}
	result = MiSTerValidatedCapture{PortableIdentity: identity, Attempt: expected.Attempt,
		FPGAGeneration: expected.FPGAGeneration, PlanCRC32: expected.PlanCRC32,
		PackedCABCRC32: prepared.CAB.PayloadCRC32, Epoch: mustHex32(manifest.Epoch),
		Images: make([]MiSTerValidatedImage, 0, len(prepared.Checkpoints))}
	seenReceiptPaths := make(map[string]bool, len(prepared.Checkpoints))
	seenPNGPaths := make(map[string]bool, len(prepared.Checkpoints))
	ownedLocalNames := make(map[string]bool, len(prepared.Checkpoints)*3)
	var geometry [3]uint32
	lastPNGPath := ""
	lastPayloadBytes := uint64(0)
	for index, checkpoint := range prepared.Checkpoints {
		ref := manifest.Images[index]
		wantSequence := uint32(index + 1)
		wantReceiptPath := fmt.Sprintf("/tmp/jtframe-capture-%s-image-%08x.receipt.json", expected.Attempt.SessionID, wantSequence)
		if ref.Sequence != wantSequence || ref.Checkpoint != checkpoint || ref.Epoch != manifest.Epoch ||
			ref.FPGAGeneration != expected.FPGAGeneration || ref.PlanCRC32 != planCRC || ref.PackedCABCRC32 != cabCRC ||
			ref.ReceiptPath != wantReceiptPath || seenReceiptPaths[ref.ReceiptPath] {
			return result, fmt.Errorf("manifest image reference %d is missing, reordered or bound to another attempt", index)
		}
		seenReceiptPaths[ref.ReceiptPath] = true
		receiptJSON, ok := files.ReceiptJSON[ref.ReceiptPath]
		if !ok {
			return result, fmt.Errorf("missing receipt file %s", ref.ReceiptPath)
		}
		localReceipt, ok := files.ReceiptLocal[ref.ReceiptPath]
		wantLocalReceipt := filepath.Join(root, fmt.Sprintf("receipt_%08d.json", checkpoint))
		if !ok || localReceipt != wantLocalReceipt {
			return result, fmt.Errorf("checkpoint %d receipt is not at its deterministic owned path", checkpoint)
		}
		ownedLocalNames[filepath.Base(wantLocalReceipt)] = true
		storedReceipt, err := readOwnedReceipt(root, localReceipt)
		if err != nil || !bytes.Equal(storedReceipt, receiptJSON) {
			return result, fmt.Errorf("checkpoint %d local receipt is missing, unsafe or differs from retrieved bytes", checkpoint)
		}
		receipt, err := DecodeMiSTerCaptureImageReceipt(receiptJSON)
		if err != nil {
			return result, fmt.Errorf("checkpoint %d: %w", checkpoint, err)
		}
		if err := validateMiSTerImageReceipt(receipt, expected, manifest, ref, checkpoint, wantSequence); err != nil {
			return result, fmt.Errorf("checkpoint %d: %w", checkpoint, err)
		}
		if index == 0 {
			geometry = [3]uint32{receipt.Width, receipt.Height, receipt.RowPitch}
		} else if geometry != [3]uint32{receipt.Width, receipt.Height, receipt.RowPitch} {
			return result, fmt.Errorf("checkpoint %d changed native image geometry/pitch", checkpoint)
		}
		if seenPNGPaths[receipt.PNGPath] {
			return result, fmt.Errorf("duplicate PNG path %q", receipt.PNGPath)
		}
		seenPNGPaths[receipt.PNGPath] = true
		lastPNGPath = receipt.PNGPath
		lastPayloadBytes = uint64(receipt.PayloadBytes)
		localPNG, ok := files.PNGLocal[receipt.PNGPath]
		if !ok {
			return result, fmt.Errorf("missing retrieved PNG for checkpoint %d", checkpoint)
		}
		wantLocal := filepath.Join(root, CapturePNGLocalName(checkpoint))
		if localPNG != wantLocal {
			return result, fmt.Errorf("checkpoint %d local PNG path is not the deterministic owned path", checkpoint)
		}
		ownedLocalNames[filepath.Base(wantLocal)] = true
		validatedImage, err := validateRetrievedPNG(root, localPNG, receipt)
		if err != nil {
			return result, fmt.Errorf("checkpoint %d: %w", checkpoint, err)
		}
		if receipt.RawRGBPath != "" {
			localRaw, ok := files.RawRGBLocal[receipt.RawRGBPath]
			if !ok {
				return result, fmt.Errorf("checkpoint %d missing optional raw RGB proof", checkpoint)
			}
			wantRaw := filepath.Join(root, fmt.Sprintf("proof_%08d.rgb", checkpoint))
			if localRaw != wantRaw {
				return result, fmt.Errorf("checkpoint %d raw proof path is not the deterministic owned path", checkpoint)
			}
			ownedLocalNames[filepath.Base(wantRaw)] = true
			if err := validateRawRGBProof(root, localRaw, receipt, validatedImage.DecodedRGBSHA256); err != nil {
				return result, fmt.Errorf("checkpoint %d: %w", checkpoint, err)
			}
		} else if receipt.RawRGBSize != 0 {
			return result, fmt.Errorf("checkpoint %d has raw proof size without a path", checkpoint)
		}
		result.Images = append(result.Images, validatedImage)
	}
	if err := rejectUnexpectedCaptureFiles(root, ownedLocalNames); err != nil {
		return result, err
	}
	if len(files.RawRGBLocal) > 0 {
		for remote := range files.RawRGBLocal {
			found := false
			for _, ref := range manifest.Images {
				receipt, _ := DecodeMiSTerCaptureImageReceipt(files.ReceiptJSON[ref.ReceiptPath])
				if receipt.RawRGBPath == remote && remote != "" {
					found = true
					break
				}
			}
			if !found {
				return result, fmt.Errorf("unexpected raw proof file mapping %q", remote)
			}
		}
	}
	if status.Output != lastPNGPath || status.CopiedBytes != lastPayloadBytes {
		return result, fmt.Errorf("terminal status output/payload does not match the last durable image")
	}
	return result, nil
}

func validateMiSTerSessionStatus(status MiSTerCaptureStatus, manifest MiSTerCaptureManifest,
	expected MiSTerReceiptExpectation, planCRC, cabCRC string, cabEventCount uint32) error {
	count := len(expected.Prepared.Checkpoints)
	if status.Protocol != "jtframe-capture-session-v1" || status.SessionID != expected.Attempt.SessionID ||
		status.State != "complete" || status.Fault != 0 || !status.CleanupConfirmed || status.ReloadRequired ||
		status.StatusWriteFailed || status.ReceiptWriteFailed || status.EncoderBusy || !status.Scheduled ||
		status.ScheduleState != "complete" || status.ReceiptProtocol != "jtframe-capture-image-v1" {
		return fmt.Errorf("capture status is not a clean complete session")
	}
	if manifest.Protocol != "jtframe-capture-session-v1" || manifest.Version != 1 ||
		manifest.SessionID != expected.Attempt.SessionID || manifest.State != "complete" || manifest.Reason != "" ||
		manifest.FPGAGeneration != expected.FPGAGeneration || manifest.PlanCRC32 != planCRC ||
		manifest.PackedCABCRC32 != cabCRC || manifest.PlanTotalFrames != expected.Prepared.CAB.TotalFrames ||
		manifest.ExpectedCount != uint32(count) || manifest.CompletedCount != uint32(count) ||
		len(manifest.PlannedCheckpoints) != count || len(manifest.Images) != count {
		return fmt.Errorf("capture manifest identity, plan or completion count mismatch")
	}
	epoch, err := parseHex32(manifest.Epoch)
	if err != nil || epoch == 0 || status.Epoch != manifest.Epoch {
		return fmt.Errorf("capture status/manifest epoch is invalid or inconsistent")
	}
	if status.ScheduleCRC32 != planCRC || status.PackedCABCRC32 != cabCRC || status.ManifestPath != fmt.Sprintf("/tmp/jtframe-capture-%s.manifest.json", expected.Attempt.SessionID) ||
		status.ScheduleCount != uint32(count) || status.ScheduleIndex != uint32(count) || status.CompletedCount != uint32(count) ||
		status.Checkpoint != expected.Prepared.Checkpoints[count-1] || status.MaxHoldMS != expected.MaxHoldMS {
		return fmt.Errorf("capture terminal status does not match the owned schedule")
	}
	sequence, err := parseHex32(status.Sequence)
	if err != nil || sequence != uint32(count) {
		return fmt.Errorf("capture terminal status sequence is invalid")
	}
	terminal := manifest.CABTerminal
	if !terminal.Observed || terminal.Failed || !terminal.CleanupConfirmed || !terminal.InputsNeutral ||
		terminal.Epoch != epoch || terminal.Frames != expected.Prepared.CAB.TotalFrames ||
		terminal.FramesTotal != expected.Prepared.CAB.TotalFrames ||
		cabEventCount == 0 || terminal.EventsAccepted != cabEventCount ||
		terminal.EventsApplied != cabEventCount || terminal.EventsTotal != cabEventCount {
		return fmt.Errorf("manifest has no clean matching CAB terminal")
	}
	for index, checkpoint := range expected.Prepared.Checkpoints {
		if checkpoint == 0 || checkpoint > expected.Prepared.CAB.TotalFrames ||
			(index > 0 && checkpoint <= expected.Prepared.Checkpoints[index-1]) ||
			manifest.PlannedCheckpoints[index] != checkpoint {
			return fmt.Errorf("manifest planned checkpoints are missing, reordered or invalid")
		}
	}
	return nil
}

func validateMiSTerImageReceipt(receipt MiSTerCaptureImageReceipt, expected MiSTerReceiptExpectation,
	manifest MiSTerCaptureManifest, ref MiSTerCaptureReceiptRef, checkpoint, sequence uint32) error {
	planCRC := fmt.Sprintf("%08x", expected.PlanCRC32)
	cabCRC := fmt.Sprintf("%08x", expected.Prepared.CAB.PayloadCRC32)
	epoch, err := parseHex32(manifest.Epoch)
	if err != nil {
		return err
	}
	receiptEpoch, err := parseHex32(receipt.Epoch)
	if err != nil || receiptEpoch != epoch {
		return fmt.Errorf("image receipt epoch mismatch")
	}
	if receipt.Protocol != "jtframe-capture-image-v1" || receipt.SessionID != expected.Attempt.SessionID ||
		receipt.FPGAGeneration != expected.FPGAGeneration || receipt.PlanCRC32 != planCRC ||
		receipt.PackedCABCRC32 != cabCRC || receipt.Sequence != sequence ||
		receipt.RequestedCheckpoint != checkpoint || receipt.ActualCheckpoint != checkpoint ||
		receipt.DescriptorCheckpoint != checkpoint || checkpoint == 0 || receipt.ActualInterval+1 != checkpoint ||
		receipt.Width == 0 || receipt.Height == 0 || receipt.Width > 4095 || receipt.Height > 4095 ||
		receipt.ActualCheckpoint > expected.Prepared.CAB.TotalFrames || !receipt.ReleaseConfirmed || !receipt.PNGComplete ||
		receipt.FinalIssued != receipt.FinalCompleted || receipt.PNGSize == 0 || receipt.PNGSize > miSTerPNGMaxBytes {
		return fmt.Errorf("image receipt is incomplete or belongs to another attempt")
	}
	if ref.Sequence != sequence || ref.Checkpoint != checkpoint || ref.Epoch != receipt.Epoch ||
		ref.FPGAGeneration != receipt.FPGAGeneration || ref.PlanCRC32 != receipt.PlanCRC32 ||
		ref.PackedCABCRC32 != receipt.PackedCABCRC32 {
		return fmt.Errorf("manifest reference and image receipt disagree")
	}
	if err := validateReceiptPaths(receipt, expected.Attempt.SessionID); err != nil {
		return err
	}
	descriptor, err := decodeFixedHex(receipt.DescriptorBytesHex, 64)
	if err != nil {
		return fmt.Errorf("descriptor bytes: %w", err)
	}
	headerBefore, err := decodeFixedHex(receipt.HeaderBeforeHex, 256)
	if err != nil {
		return fmt.Errorf("header-before: %w", err)
	}
	headerAfter, err := decodeFixedHex(receipt.HeaderAfterHex, 256)
	if err != nil {
		return fmt.Errorf("header-after: %w", err)
	}
	descriptorCRC, err := parseHex32(receipt.DescriptorCRC32)
	if err != nil || descriptorCRC != crc32.ChecksumIEEE(descriptor[:56]) || binary.LittleEndian.Uint32(descriptor[56:60]) != descriptorCRC {
		return fmt.Errorf("descriptor CRC mismatch")
	}
	beforeCRC, err := parseHex32(receipt.HeaderBeforeCRC32)
	if err != nil || beforeCRC != crc32.ChecksumIEEE(headerBefore) {
		return fmt.Errorf("header-before CRC mismatch")
	}
	afterCRC, err := parseHex32(receipt.HeaderAfterCRC32)
	if err != nil || afterCRC != crc32.ChecksumIEEE(headerAfter) || !bytes.Equal(headerBefore, headerAfter) {
		return fmt.Errorf("header-after CRC or stable-header comparison failed")
	}
	if string(descriptor[:4]) != "JTC1" || binary.LittleEndian.Uint16(descriptor[4:6]) != 1 ||
		binary.LittleEndian.Uint16(descriptor[6:8]) != 64 || binary.LittleEndian.Uint32(descriptor[8:12]) != epoch ||
		binary.LittleEndian.Uint32(descriptor[12:16]) != sequence ||
		binary.LittleEndian.Uint32(descriptor[16:20]) != checkpoint ||
		binary.LittleEndian.Uint32(descriptor[20:24]) != receipt.ActualInterval {
		return fmt.Errorf("descriptor magic/version/epoch/sequence/checkpoint mismatch")
	}
	slotBase, err := parseHex32(receipt.SlotBase)
	if err != nil {
		return fmt.Errorf("invalid slot base")
	}
	mode, err := parseHex32(receipt.Mode)
	if err != nil {
		return fmt.Errorf("invalid capture mode")
	}
	if receipt.Slot > 2 || (receipt.SlotStride != miSTerSlotStride2 && receipt.SlotStride != miSTerSlotStride8) ||
		slotBase != 0x20000000+receipt.Slot*receipt.SlotStride ||
		((mode>>8)&3) != receipt.Slot || mode&0xff != miSTerRGBMode || mode&(1<<10) == 0 || mode&(1<<11) == 0 ||
		mode&(1<<12) != 0 || mode&0xffffe000 != 0 {
		return fmt.Errorf("unsupported slot base/stride or native capture mode")
	}
	rowPitch := ((uint64(receipt.Width)*3 + 255) / 256) * 256
	payload := uint64(receipt.RowPitch) * uint64(receipt.Height)
	if uint64(receipt.RowPitch) != rowPitch || payload != uint64(receipt.PayloadBytes) ||
		receipt.SlotStride <= 256 || payload > uint64(receipt.SlotStride)-256 ||
		receipt.RowPitch > receipt.SlotStride-256 {
		return fmt.Errorf("invalid production RGB888 pitch/payload bounds")
	}
	if binary.LittleEndian.Uint32(descriptor[24:28]) != slotBase ||
		binary.LittleEndian.Uint32(descriptor[28:32]) != receipt.SlotStride ||
		binary.LittleEndian.Uint16(descriptor[32:34]) != uint16(receipt.Width) ||
		binary.LittleEndian.Uint16(descriptor[34:36]) != uint16(receipt.Height) ||
		binary.LittleEndian.Uint32(descriptor[36:40]) != receipt.RowPitch ||
		binary.LittleEndian.Uint32(descriptor[40:44]) != receipt.PayloadBytes ||
		binary.LittleEndian.Uint32(descriptor[44:48]) != mode ||
		binary.LittleEndian.Uint32(descriptor[48:52]) != receipt.FinalIssued ||
		binary.LittleEndian.Uint32(descriptor[52:56]) != receipt.FinalCompleted || string(descriptor[60:64]) != "RDY1" {
		return fmt.Errorf("descriptor fields/commit tag disagree with receipt")
	}
	if headerBefore[0] != 1 || headerBefore[1] != 1 || binary.BigEndian.Uint16(headerBefore[2:4]) != 256 ||
		binary.BigEndian.Uint16(headerBefore[4:6])&0x000f != 0 ||
		binary.BigEndian.Uint16(headerBefore[6:8]) != uint16(receipt.Width) ||
		binary.BigEndian.Uint16(headerBefore[8:10]) != uint16(receipt.Height) ||
		binary.BigEndian.Uint16(headerBefore[10:12]) != uint16(receipt.RowPitch) ||
		binary.BigEndian.Uint16(headerBefore[12:14]) == 0 || binary.BigEndian.Uint16(headerBefore[14:16]) == 0 ||
		binary.BigEndian.Uint16(headerBefore[12:14]) > 4095 || binary.BigEndian.Uint16(headerBefore[14:16]) > 4095 ||
		!bytes.Equal(headerBefore[192:256], descriptor) {
		return fmt.Errorf("legacy header is invalid or does not embed the descriptor")
	}
	return nil
}

func validateReceiptPaths(receipt MiSTerCaptureImageReceipt, sessionID string) error {
	if !validScheduledPNGPath(receipt.PNGPath, sessionID, mustHex32(receipt.Epoch),
		receipt.ActualCheckpoint, receipt.Sequence) {
		return fmt.Errorf("PNG path is not the Main-generated name for this scheduled image")
	}
	if receipt.RawRGBPath == "" {
		if receipt.RawRGBSize != 0 {
			return fmt.Errorf("raw proof size is set without a path")
		}
	} else {
		epoch, err := parseHex32(receipt.Epoch)
		wantName := fmt.Sprintf("%s-%08x-%08x.rgb", sessionID, epoch, receipt.Sequence)
		proofRoot := path.Dir(receipt.RawRGBPath)
		proofPrefixOK := proofRoot == "/tmp/jtframe-capture-proof" ||
			strings.HasPrefix(proofRoot, "/tmp/jtframe-capture-proof-") ||
			strings.HasPrefix(proofRoot, "/tmp/jtframe-capture-proof/")
		if !cleanRemotePath(receipt.RawRGBPath) || !proofPrefixOK ||
			path.Base(receipt.RawRGBPath) != wantName || err != nil || receipt.RawRGBSize == 0 ||
			receipt.RawRGBSize != uint64(receipt.PayloadBytes) {
			return fmt.Errorf("optional raw proof path/size is invalid")
		}
	}
	return nil
}

func validScheduledPNGPath(value, sessionID string, epoch, checkpoint, sequence uint32) bool {
	if !cleanRemotePath(value) || !strings.HasPrefix(value, "/media/fat/screenshots/") {
		return false
	}
	coreDir := path.Dir(value)
	if path.Dir(coreDir) != "/media/fat/screenshots" || path.Base(coreDir) == "" || path.Base(coreDir) == "." {
		return false
	}
	name := path.Base(value)
	basename := fmt.Sprintf("cabcap_%s_%08x_%08x_%08x", sessionID, epoch, checkpoint, sequence)
	if strings.HasPrefix(name, "NODATE-") {
		prefix := "NODATE-" + basename + "_"
		if !strings.HasPrefix(name, prefix) || !strings.HasSuffix(name, ".png") || len(name) != len(prefix)+4+4 {
			return false
		}
		return decimalDigits(name[len(prefix) : len(prefix)+4])
	}
	const timestampPrefixLength = 16 // YYYYMMDD_HHMMSS-
	if len(name) != timestampPrefixLength+len(basename)+4 || name[timestampPrefixLength:] != basename+".png" {
		return false
	}
	return len(name) > 15 && decimalDigits(name[:8]) && name[8] == '_' && decimalDigits(name[9:15]) && name[15] == '-'
}

func decimalDigits(value string) bool {
	if value == "" {
		return false
	}
	for _, char := range value {
		if char < '0' || char > '9' {
			return false
		}
	}
	return true
}

func cleanRemotePath(value string) bool {
	if value == "" || !path.IsAbs(value) || path.Clean(value) != value || strings.ContainsRune(value, '\\') {
		return false
	}
	for _, part := range strings.Split(value, "/") {
		if part == "." || part == ".." {
			return false
		}
	}
	for _, char := range value {
		if char < 0x20 || char == 0x7f {
			return false
		}
	}
	return true
}

func canonicalRetrievalRoot(root string) (string, error) {
	if !filepath.IsAbs(root) {
		return "", fmt.Errorf("retrieval root must be absolute")
	}
	abs, err := filepath.Abs(root)
	if err != nil {
		return "", err
	}
	abs = filepath.Clean(abs)
	info, err := os.Lstat(abs)
	if err != nil || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return "", fmt.Errorf("retrieval root must be an existing non-symlink directory")
	}
	resolved, err := filepath.EvalSymlinks(abs)
	if err != nil || filepath.Clean(resolved) != filepath.Clean(abs) {
		return "", fmt.Errorf("retrieval root is not canonical")
	}
	return resolved, nil
}

func validateRetrievedPNG(root, localPath string, receipt MiSTerCaptureImageReceipt) (MiSTerValidatedImage, error) {
	var result MiSTerValidatedImage
	mode, err := parseHex32(receipt.Mode)
	if err != nil {
		return result, fmt.Errorf("invalid capture mode metadata")
	}
	descriptorCRC, err := parseHex32(receipt.DescriptorCRC32)
	if err != nil {
		return result, fmt.Errorf("invalid descriptor CRC metadata")
	}
	data, err := readOwnedRegularFile(root, localPath, int64(receipt.PNGSize), miSTerPNGMaxBytes)
	if err != nil {
		return result, err
	}
	config, err := png.DecodeConfig(bytes.NewReader(data))
	if err != nil || config.Width != int(receipt.Width) || config.Height != int(receipt.Height) {
		return result, fmt.Errorf("PNG dimensions do not match the validated descriptor")
	}
	decoded, err := png.Decode(bytes.NewReader(data))
	if err != nil || decoded.Bounds().Dx() != int(receipt.Width) || decoded.Bounds().Dy() != int(receipt.Height) {
		return result, fmt.Errorf("PNG decode failed or dimensions changed")
	}
	rgb := make([]byte, 0, int(receipt.Width*receipt.Height*3))
	for y := 0; y < int(receipt.Height); y++ {
		for x := 0; x < int(receipt.Width); x++ {
			r, g, b, a := decoded.At(x, y).RGBA()
			if a != 0xffff {
				return result, fmt.Errorf("PNG has non-opaque alpha at (%d,%d)", x, y)
			}
			rgb = append(rgb, byte(r>>8), byte(g>>8), byte(b>>8))
		}
	}
	pngDigest := sha256.Sum256(data)
	rgbDigest := sha256.Sum256(rgb)
	result = MiSTerValidatedImage{Sequence: receipt.Sequence, Checkpoint: receipt.RequestedCheckpoint,
		Width: receipt.Width, Height: receipt.Height, RowPitch: receipt.RowPitch, Slot: receipt.Slot,
		Mode: mode, DescriptorCRC32: descriptorCRC,
		PNGPath: receipt.PNGPath, PNGSize: receipt.PNGSize, PNGFileSHA256: hex.EncodeToString(pngDigest[:]),
		DecodedRGBSHA256: hex.EncodeToString(rgbDigest[:])}
	return result, nil
}

func validateRawRGBProof(root, localPath string, receipt MiSTerCaptureImageReceipt, decodedRGBSHA string) error {
	raw, err := readOwnedRegularFile(root, localPath, int64(receipt.RawRGBSize), 8<<20)
	if err != nil {
		return err
	}
	pngRGB := make([]byte, 0, int(receipt.Width*receipt.Height*3))
	for y := uint32(0); y < receipt.Height; y++ {
		row := raw[int(y*receipt.RowPitch):int(y*receipt.RowPitch+receipt.Width*3)]
		pngRGB = append(pngRGB, row...)
	}
	digest := sha256.Sum256(pngRGB)
	if hex.EncodeToString(digest[:]) != decodedRGBSHA {
		return fmt.Errorf("optional raw RGB visible pixels differ from decoded PNG")
	}
	return nil
}

func readOwnedRegularFile(root, localPath string, expectedSize int64, maxSize int64) ([]byte, error) {
	if filepath.Dir(localPath) != root || expectedSize <= 0 || expectedSize > maxSize {
		return nil, fmt.Errorf("retrieved file path or size is outside the owned bounds")
	}
	before, err := os.Lstat(localPath)
	if err != nil || !before.Mode().IsRegular() || before.Mode()&os.ModeSymlink != 0 || before.Size() != expectedSize {
		return nil, fmt.Errorf("retrieved file is missing, unsafe or has the wrong size")
	}
	resolved, err := filepath.EvalSymlinks(localPath)
	if err != nil || resolved != localPath {
		return nil, fmt.Errorf("retrieved file path escapes the owned root")
	}
	file, err := os.Open(localPath)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	after, err := file.Stat()
	if err != nil || !after.Mode().IsRegular() || !os.SameFile(before, after) || after.Size() != expectedSize {
		return nil, fmt.Errorf("retrieved file changed while opening")
	}
	data, err := io.ReadAll(io.LimitReader(file, maxSize+1))
	if err != nil {
		return nil, err
	}
	if int64(len(data)) != expectedSize || int64(len(data)) > maxSize {
		return nil, fmt.Errorf("retrieved file length changed while reading")
	}
	return data, nil
}

func readOwnedReceipt(root, localPath string) ([]byte, error) {
	info, err := os.Lstat(localPath)
	if err != nil || info.Size() <= 0 || info.Size() > maxCaptureReceiptBytes {
		return nil, fmt.Errorf("receipt file missing or outside the size bound")
	}
	return readOwnedRegularFile(root, localPath, info.Size(), maxCaptureReceiptBytes)
}

func rejectUnexpectedCaptureFiles(root string, expected map[string]bool) error {
	entries, err := os.ReadDir(root)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		name := entry.Name()
		if !(strings.HasSuffix(name, ".png") || strings.HasSuffix(name, ".json") || strings.HasSuffix(name, ".rgb")) {
			continue
		}
		if !expected[name] {
			return fmt.Errorf("unexpected retrieved capture file %q", name)
		}
		info, err := os.Lstat(filepath.Join(root, name))
		if err != nil || !info.Mode().IsRegular() || info.Mode()&os.ModeSymlink != 0 {
			return fmt.Errorf("retrieved capture file %q is not a regular owned file", name)
		}
	}
	return nil
}

func decodeFixedHex(value string, size int) ([]byte, error) {
	if len(value) != size*2 || strings.ToLower(value) != value {
		return nil, fmt.Errorf("expected %d lowercase hexadecimal bytes", size)
	}
	decoded, err := hex.DecodeString(value)
	if err != nil || len(decoded) != size {
		return nil, fmt.Errorf("invalid fixed-length hexadecimal data")
	}
	return decoded, nil
}

func parseHex32(value string) (uint32, error) {
	if len(value) != 8 || strings.ToLower(value) != value {
		return 0, fmt.Errorf("expected eight lowercase hexadecimal digits")
	}
	data, err := hex.DecodeString(value)
	if err != nil || len(data) != 4 {
		return 0, fmt.Errorf("invalid 32-bit hexadecimal value")
	}
	return binary.BigEndian.Uint32(data), nil
}

func mustHex32(value string) uint32 {
	parsed, _ := parseHex32(value)
	return parsed
}

func validCaptureSessionID(value string) bool {
	if value == "" || len(value) > 48 {
		return false
	}
	for _, char := range value {
		if !(char >= 'a' && char <= 'z' || char >= 'A' && char <= 'Z' ||
			char >= '0' && char <= '9' || char == '_' || char == '-') {
			return false
		}
	}
	return true
}
