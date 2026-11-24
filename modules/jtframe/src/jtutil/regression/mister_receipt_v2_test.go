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
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"testing"
)

func TestMiSTerCaptureV2ValidatedMarkerComesFromCompleteReceipts(t *testing.T) {
	f := newMiSTerCaptureV2Fixture(t)
	got, err := ValidateMiSTerCapture(f.expected, f.status, f.manifest, f.files, f.root)
	if err != nil {
		t.Fatal(err)
	}
	if got.CaptureProtocol != miSTerCaptureProtocolV2 || got.Epoch != 0 || len(got.Images) != 1 ||
		got.Images[0].Sequence != 0 || got.Images[0].Checkpoint != 1 || got.Images[0].PNGFileSHA256 == "" {
		t.Fatalf("v2 normalized capture kept legacy identity or lost marker: %+v", got)
	}

	var receipt miSTerCaptureImageReceiptV2
	if err := decodeJSONValueFromBytes(f.files.ReceiptJSON["/tmp/jtframe-capture-sess-v2-checkpoint-00001.receipt.json"], &receipt); err != nil {
		t.Fatal(err)
	}
	receipt.CaptureProtocol = ""
	f.files.ReceiptJSON["/tmp/jtframe-capture-sess-v2-checkpoint-00001.receipt.json"] = marshalTestJSON(t, receipt)
	local := f.files.ReceiptLocal["/tmp/jtframe-capture-sess-v2-checkpoint-00001.receipt.json"]
	if err := os.WriteFile(local, f.files.ReceiptJSON["/tmp/jtframe-capture-sess-v2-checkpoint-00001.receipt.json"], 0600); err != nil {
		t.Fatal(err)
	}
	if got, err := ValidateMiSTerCapture(f.expected, f.status, f.manifest, f.files, f.root); err == nil || got.CaptureProtocol != "" {
		t.Fatal("receipt without a source-validated v2 marker was accepted")
	}
}

func TestMiSTerCaptureV2RejectsV1AndBadCheckpointMapping(t *testing.T) {
	legacy := newReceiptFixture(t, receiptGoldens[1], false)
	legacy.expected.RequireCaptureV2 = true
	if _, err := ValidateMiSTerCapture(legacy.expected, legacy.status, legacy.manifest, legacy.files, legacy.root); err == nil {
		t.Fatal("live capture accepted a completed v1 historical receipt")
	}
	f := newMiSTerCaptureV2Fixture(t)
	var receipt miSTerCaptureImageReceiptV2
	path := "/tmp/jtframe-capture-sess-v2-checkpoint-00001.receipt.json"
	if err := decodeJSONValueFromBytes(f.files.ReceiptJSON[path], &receipt); err != nil {
		t.Fatal(err)
	}
	desc, err := hex.DecodeString(receipt.DescriptorBytesHex)
	if err != nil {
		t.Fatal(err)
	}
	binary.LittleEndian.PutUint16(desc[10:12], 1) // checkpoint 1 must name interval 0
	crc := crc32.ChecksumIEEE(desc[:56])
	binary.LittleEndian.PutUint32(desc[56:60], crc)
	receipt.DescriptorBytesHex = hex.EncodeToString(desc)
	receipt.DescriptorCRC32 = fmt.Sprintf("%08x", crc)
	header, err := hex.DecodeString(receipt.HeaderBeforeHex)
	if err != nil {
		t.Fatal(err)
	}
	copy(header[192:256], desc)
	headerCRC := crc32.ChecksumIEEE(header)
	receipt.HeaderBeforeHex, receipt.HeaderAfterHex = hex.EncodeToString(header), hex.EncodeToString(header)
	receipt.HeaderBeforeCRC32, receipt.HeaderAfterCRC32 = fmt.Sprintf("%08x", headerCRC), fmt.Sprintf("%08x", headerCRC)
	if err := validateMiSTerImageReceiptV2(receipt, f.expected, miSTerCaptureReceiptRefV2{Checkpoint: 1,
		FPGAGeneration: 1, PlanCRC32: "00001234", PackedCABCRC32: fmt.Sprintf("%08x", f.expected.Prepared.CAB.PayloadCRC32)}, 1); err == nil {
		t.Fatal("mismatched requested-checkpoint/interval descriptor accepted")
	}
	if _, err := decodeMiSTerCaptureStatusV2([]byte(`{"protocol":"jtframe-capture-session-v1"}`)); err == nil {
		t.Fatal("v1 status was accepted by the strict v2 decoder")
	}
}

func TestMiSTerLiveStatusRequiresExactV2Labels(t *testing.T) {
	f := newMiSTerCaptureV2Fixture(t)
	if _, err := decodeLiveMiSTerCaptureStatus(f.status); err != nil {
		t.Fatalf("valid live v2 status rejected: %v", err)
	}
	mutations := []struct {
		name string
		edit func(*miSTerCaptureStatusV2)
	}{
		{"missing session protocol", func(v *miSTerCaptureStatusV2) { v.Protocol = "" }},
		{"future session protocol", func(v *miSTerCaptureStatusV2) { v.Protocol = "jtframe-capture-session-v3" }},
		{"v1 capture protocol", func(v *miSTerCaptureStatusV2) { v.CaptureProtocol = "jtframe-capture-v1" }},
		{"missing capture protocol", func(v *miSTerCaptureStatusV2) { v.CaptureProtocol = "" }},
		{"v1 receipt protocol", func(v *miSTerCaptureStatusV2) { v.ReceiptProtocol = "jtframe-capture-image-v1" }},
		{"future receipt protocol", func(v *miSTerCaptureStatusV2) { v.ReceiptProtocol = "jtframe-capture-image-v3" }},
		{"checkpoint high bit", func(v *miSTerCaptureStatusV2) { v.Checkpoint = 32768 }},
		{"index exceeds schedule", func(v *miSTerCaptureStatusV2) { v.ScheduleIndex = v.ScheduleCount + 1 }},
		{"completed exceeds schedule", func(v *miSTerCaptureStatusV2) { v.CompletedCount = v.ScheduleCount + 1 }},
		{"hold exceeds limit", func(v *miSTerCaptureStatusV2) { v.MaxHoldMS = 2001 }},
		{"copied bytes exceed bound", func(v *miSTerCaptureStatusV2) { v.CopiedBytes = 8<<20 + 1 }},
		{"unknown state", func(v *miSTerCaptureStatusV2) { v.State = "future-state" }},
		{"unknown schedule state", func(v *miSTerCaptureStatusV2) { v.ScheduleState = "future-schedule-state" }},
	}
	for _, tc := range mutations {
		t.Run(tc.name, func(t *testing.T) {
			var status miSTerCaptureStatusV2
			if err := decodeJSONValueFromBytes(f.status, &status); err != nil {
				t.Fatal(err)
			}
			tc.edit(&status)
			if _, err := decodeLiveMiSTerCaptureStatus(marshalTestJSON(t, status)); err == nil {
				t.Fatalf("accepted status with %s", tc.name)
			}
		})
	}
	var initial miSTerCaptureStatusV2
	if err := decodeJSONValueFromBytes(f.status, &initial); err != nil {
		t.Fatal(err)
	}
	initial.State, initial.Checkpoint, initial.MaxHoldMS = "idle", 0, 0
	initial.Scheduled, initial.ScheduleCRC32, initial.PackedCABCRC32 = false, "00000000", "00000000"
	initial.ScheduleCount, initial.ScheduleIndex, initial.CompletedCount = 0, 0, 0
	initial.ScheduleState, initial.ManifestPath = "", ""
	initial.CopiedBytes, initial.Output, initial.CleanupConfirmed = 0, "", false
	if _, err := decodeLiveMiSTerCaptureStatus(marshalTestJSON(t, initial)); err != nil {
		t.Fatalf("legitimate initial v2 status rejected: %v", err)
	}
	if terminalCaptureState("copying", "cancelled") {
		t.Fatal("active copying state combined with cancelled schedule was trusted as terminal cleanup")
	}
	if terminalCaptureState("cancelled", "running") || !terminalCaptureState("cancelled", "cancelled") {
		t.Fatal("capture and schedule terminal states were not required to agree")
	}
}

func TestMiSTerCaptureV2OptionalRawProofMatchesOwnedFilename(t *testing.T) {
	f := newMiSTerCaptureV2Fixture(t)
	const receiptPath = "/tmp/jtframe-capture-sess-v2-checkpoint-00001.receipt.json"
	var receipt miSTerCaptureImageReceiptV2
	if err := decodeJSONValueFromBytes(f.files.ReceiptJSON[receiptPath], &receipt); err != nil {
		t.Fatal(err)
	}
	receipt.RawRGBPath = "/tmp/jtframe-capture-proof-sess-v2/sess-v2-00001.rgb"
	receipt.RawRGBSize = uint64(receipt.PayloadBytes)
	rawPath := filepath.Join(f.root, "proof_00000001.rgb")
	pngFile, err := os.Open(f.files.PNGLocal[receipt.PNGPath])
	if err != nil {
		t.Fatal(err)
	}
	decoded, err := png.Decode(pngFile)
	_ = pngFile.Close()
	if err != nil {
		t.Fatal(err)
	}
	raw := make([]byte, 0, receipt.RawRGBSize)
	for y := 0; y < decoded.Bounds().Dy(); y++ {
		for x := 0; x < decoded.Bounds().Dx(); x++ {
			pixel := color.RGBAModel.Convert(decoded.At(x, y)).(color.RGBA)
			raw = append(raw, pixel.R, pixel.G, pixel.B)
		}
	}
	if err := os.WriteFile(rawPath, raw, 0600); err != nil {
		t.Fatal(err)
	}
	receiptJSON := marshalTestJSON(t, receipt)
	if err := os.WriteFile(f.files.ReceiptLocal[receiptPath], receiptJSON, 0600); err != nil {
		t.Fatal(err)
	}
	f.files.ReceiptJSON[receiptPath] = receiptJSON
	f.files.RawRGBLocal = map[string]string{receipt.RawRGBPath: rawPath}
	if _, err := ValidateMiSTerCapture(f.expected, f.status, f.manifest, f.files, f.root); err != nil {
		t.Fatalf("valid producer-named optional raw proof rejected: %v", err)
	}
	raw[0] ^= 0xff
	if err := os.WriteFile(rawPath, raw, 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := ValidateMiSTerCapture(f.expected, f.status, f.manifest, f.files, f.root); err == nil {
		t.Fatal("tampered optional raw proof was accepted")
	}
}

type miSTerCaptureV2Fixture struct {
	expected         MiSTerReceiptExpectation
	status, manifest []byte
	files            MiSTerRetrievedFiles
	root             string
}

func newMiSTerCaptureV2Fixture(t *testing.T) miSTerCaptureV2Fixture {
	t.Helper()
	root := t.TempDir()
	if err := os.Chmod(root, 0700); err != nil {
		t.Fatal(err)
	}
	packedCAB := testPackedCAB(t, 1, make([]byte, 8), 4)
	sha := sha256.Sum256(packedCAB)
	prepared := preparedSessionFixture()
	prepared.Profile.Video, prepared.Profile.Startup = 4, 0
	prepared.CAB.TotalFrames = 4
	prepared.CAB.PayloadCRC32 = binary.LittleEndian.Uint32(packedCAB[24:28])
	prepared.CAB.PackedSHA256 = hex.EncodeToString(sha[:])
	prepared.Checkpoints = []uint32{1}
	key := AttemptKey{Board: "mister-test", SessionID: "sess-v2", Nonce: "attempt-v2"}
	expected := MiSTerReceiptExpectation{Prepared: prepared, PackedCAB: packedCAB, Attempt: key,
		FPGAGeneration: 1, PlanCRC32: 0x1234, MaxHoldMS: 1000}
	const width, height, pitch, stride, slot = uint32(256), uint32(224), uint32(768), miSTerSlotStride2, uint32(0)
	const base, mode, issued = uint32(0x20000000), uint32(0x0c01), uint32(99)
	const payload = pitch * height
	descriptor := make([]byte, 64)
	copy(descriptor[:4], "JTC2")
	binary.LittleEndian.PutUint16(descriptor[4:6], 2)
	binary.LittleEndian.PutUint16(descriptor[6:8], 64)
	binary.LittleEndian.PutUint16(descriptor[8:10], 1)
	binary.LittleEndian.PutUint16(descriptor[10:12], 0)
	binary.LittleEndian.PutUint32(descriptor[12:16], base)
	binary.LittleEndian.PutUint32(descriptor[16:20], stride)
	binary.LittleEndian.PutUint16(descriptor[20:22], uint16(width))
	binary.LittleEndian.PutUint16(descriptor[22:24], uint16(height))
	binary.LittleEndian.PutUint32(descriptor[24:28], pitch)
	binary.LittleEndian.PutUint32(descriptor[28:32], payload)
	binary.LittleEndian.PutUint32(descriptor[32:36], mode)
	binary.LittleEndian.PutUint32(descriptor[36:40], issued)
	binary.LittleEndian.PutUint32(descriptor[40:44], issued)
	descriptorCRC := crc32.ChecksumIEEE(descriptor[:56])
	binary.LittleEndian.PutUint32(descriptor[56:60], descriptorCRC)
	copy(descriptor[60:64], "RDY2")
	header := make([]byte, 256)
	header[0], header[1] = 1, 1
	binary.BigEndian.PutUint16(header[2:4], 256)
	binary.BigEndian.PutUint16(header[4:6], 0x0010)
	binary.BigEndian.PutUint16(header[6:8], uint16(width))
	binary.BigEndian.PutUint16(header[8:10], uint16(height))
	binary.BigEndian.PutUint16(header[10:12], uint16(pitch))
	binary.BigEndian.PutUint16(header[12:14], 640)
	binary.BigEndian.PutUint16(header[14:16], 480)
	copy(header[192:], descriptor)
	headerCRC := crc32.ChecksumIEEE(header)
	pngPath := "/media/fat/screenshots/circusc/20261115_123456-cabcap_sess-v2_0001.png"
	r := miSTerCaptureImageReceiptV2{Protocol: "jtframe-capture-image-v2", CaptureProtocol: miSTerCaptureProtocolV2,
		SessionID: "sess-v2", FPGAGeneration: 1, PlanCRC32: "00001234", PackedCABCRC32: fmt.Sprintf("%08x", prepared.CAB.PayloadCRC32),
		RequestedCheckpoint: 1, ActualInterval: 0, ActualCheckpoint: 1, DescriptorCheckpoint: 1, Width: width, Height: height,
		RowPitch: pitch, PayloadBytes: payload, SlotBase: fmt.Sprintf("%08x", base), SlotStride: stride, Slot: slot,
		Mode: fmt.Sprintf("%08x", mode), DescriptorCRC32: fmt.Sprintf("%08x", descriptorCRC),
		HeaderBeforeCRC32: fmt.Sprintf("%08x", headerCRC), HeaderAfterCRC32: fmt.Sprintf("%08x", headerCRC),
		DescriptorBytesHex: hex.EncodeToString(descriptor), HeaderBeforeHex: hex.EncodeToString(header), HeaderAfterHex: hex.EncodeToString(header),
		FinalIssued: issued, FinalCompleted: issued, ReleaseConfirmed: true, ReleaseAckFreshness: 1,
		PNGComplete: true, PNGPath: pngPath, RawRGBPath: "", RawRGBSize: 0}
	img := image.NewRGBA(image.Rect(0, 0, int(width), int(height)))
	for y := 0; y < int(height); y++ {
		for x := 0; x < int(width); x++ {
			img.SetRGBA(x, y, color.RGBA{R: uint8(x), G: uint8(y), B: uint8(x + y), A: 255})
		}
	}
	var pngData bytes.Buffer
	if err := png.Encode(&pngData, img); err != nil {
		t.Fatal(err)
	}
	r.PNGSize = uint64(pngData.Len())
	localPNG := filepath.Join(root, CapturePNGLocalName(1))
	if err := os.WriteFile(localPNG, pngData.Bytes(), 0600); err != nil {
		t.Fatal(err)
	}
	localReceipt := filepath.Join(root, "receipt_00000001.json")
	receiptPath := "/tmp/jtframe-capture-sess-v2-checkpoint-00001.receipt.json"
	receiptJSON := marshalTestJSON(t, r)
	if err := os.WriteFile(localReceipt, receiptJSON, 0600); err != nil {
		t.Fatal(err)
	}
	manifest := miSTerCaptureManifestV2{Protocol: "jtframe-capture-session-v2", Version: 2, CaptureProtocol: miSTerCaptureProtocolV2,
		SessionID: "sess-v2", State: "complete", FPGAGeneration: 1, PlanCRC32: "00001234",
		PackedCABCRC32: fmt.Sprintf("%08x", prepared.CAB.PayloadCRC32), PlanTotalFrames: 4, ExpectedCount: 1,
		PlannedCheckpoints: []uint32{1}, CompletedCount: 1,
		Images: []miSTerCaptureReceiptRefV2{{Checkpoint: 1, FPGAGeneration: 1, PlanCRC32: "00001234",
			PackedCABCRC32: fmt.Sprintf("%08x", prepared.CAB.PayloadCRC32), ReceiptPath: receiptPath}},
		CABTerminal: miSTerCaptureCABTerminalV2{Observed: true, CleanupConfirmed: true, InputsNeutral: true,
			Frames: 4, FramesTotal: 4, EventsAccepted: 1, EventsApplied: 1, EventsTotal: 1}}
	status := miSTerCaptureStatusV2{Protocol: "jtframe-capture-session-v2", SessionID: "sess-v2", State: "complete",
		Checkpoint: 1, MaxHoldMS: 1000, CleanupConfirmed: true, CopiedBytes: uint64(payload), Output: pngPath,
		Scheduled: true, ScheduleCRC32: "00001234", PackedCABCRC32: fmt.Sprintf("%08x", prepared.CAB.PayloadCRC32),
		ScheduleCount: 1, ScheduleIndex: 1, ScheduleState: "complete", CaptureProtocol: miSTerCaptureProtocolV2,
		ReceiptProtocol: "jtframe-capture-image-v2", ManifestPath: "/tmp/jtframe-capture-sess-v2.manifest.json", CompletedCount: 1}
	files := MiSTerRetrievedFiles{ReceiptJSON: map[string][]byte{receiptPath: receiptJSON},
		ReceiptLocal: map[string]string{receiptPath: localReceipt}, PNGLocal: map[string]string{pngPath: localPNG}}
	return miSTerCaptureV2Fixture{expected: expected, status: marshalTestJSON(t, status), manifest: marshalTestJSON(t, manifest), files: files, root: root}
}

func decodeJSONValueFromBytes(data []byte, target interface{}) error {
	value, err := strictJSONValue(data, maxCaptureReceiptBytes)
	if err != nil {
		return err
	}
	return decodeJSONValue(value, target)
}

func newMiSTerCaptureV3Fixture(t *testing.T) (miSTerCaptureV2Fixture, miSTerCaptureImageReceiptV2, miSTerCaptureReceiptRefV2) {
	t.Helper()
	f := newMiSTerCaptureV2Fixture(t)
	var status miSTerCaptureStatusV2
	if err := decodeJSONValueFromBytes(f.status, &status); err != nil { t.Fatal(err) }
	status.CaptureProtocol, status.ReceiptProtocol = miSTerCaptureProtocolV3, "jtframe-capture-image-v3"
	f.status = marshalTestJSON(t, status)
	var manifest miSTerCaptureManifestV2
	if err := decodeJSONValueFromBytes(f.manifest, &manifest); err != nil { t.Fatal(err) }
	manifest.CaptureProtocol = miSTerCaptureProtocolV3
	f.manifest = marshalTestJSON(t, manifest)
	ref := manifest.Images[0]
	var r miSTerCaptureImageReceiptV2
	if err := decodeJSONValueFromBytes(f.files.ReceiptJSON[ref.ReceiptPath], &r); err != nil { t.Fatal(err) }
	r.Protocol, r.CaptureProtocol = "jtframe-capture-image-v3", miSTerCaptureProtocolV3
	r.PixelChecksum = "1234abcd"
	r.PixelChecksumAlgorithm = "gfw1"
	r.PostCopyCAPS = []uint16{0xca50, 2, 64, 0x46, 9, 0, 7, 0}
	r.ReadyCAPS = append([]uint16(nil), r.PostCopyCAPS...)
	r.ReleaseAckFreshness = 10
	r.BurstCount = 1+r.PayloadBytes/256
	desc, err := hex.DecodeString(r.DescriptorBytesHex); if err != nil { t.Fatal(err) }
	binary.LittleEndian.PutUint32(desc[36:40], r.BurstCount)
	binary.LittleEndian.PutUint32(desc[40:44], 0x31574647)
	binary.LittleEndian.PutUint32(desc[44:48], 0x1234abcd)
	crc := crc32.ChecksumIEEE(desc[:56]); binary.LittleEndian.PutUint32(desc[56:60], crc)
	r.DescriptorCRC32, r.DescriptorBytesHex = fmt.Sprintf("%08x", crc), hex.EncodeToString(desc)
	writeMiSTerV3TestReceipt(t, &f, ref, r, false)
	return f, r, ref
}

func writeMiSTerV3TestReceipt(t *testing.T, f *miSTerCaptureV2Fixture, ref miSTerCaptureReceiptRefV2, r miSTerCaptureImageReceiptV2, addHeader bool) {
	t.Helper()
	raw := marshalTestJSON(t, r)
	var obj map[string]interface{}
	if err := decodeJSONValueFromBytes(raw, &obj); err != nil { t.Fatal(err) }
	for _, key := range []string{"header_before_crc32", "header_after_crc32", "header_before_hex", "header_after_hex", "final_issued", "final_completed"} { delete(obj, key) }
	if addHeader { obj["header_before_hex"] = "" }
	raw = marshalTestJSON(t, obj)
	f.files.ReceiptJSON[ref.ReceiptPath] = raw
	if err := os.WriteFile(f.files.ReceiptLocal[ref.ReceiptPath], raw, 0600); err != nil { t.Fatal(err) }
}

func TestMiSTerCaptureV3ChecksumAndCAPSProof(t *testing.T) {
	f, r, ref := newMiSTerCaptureV3Fixture(t)
	writeReceipt := func(r miSTerCaptureImageReceiptV2, addHeader bool) { writeMiSTerV3TestReceipt(t, &f, ref, r, addHeader) }
	got, err := ValidateMiSTerCapture(f.expected, f.status, f.manifest, f.files, f.root)
	if err != nil || got.CaptureProtocol != miSTerCaptureProtocolV3 { t.Fatalf("valid v3 capture: %+v %v", got, err) }
	for _, tc := range []struct{name string; mutate func(*miSTerCaptureImageReceiptV2)}{
		{"checksum", func(v *miSTerCaptureImageReceiptV2) { v.PixelChecksum = "1234abce" }},
		{"CAPS ready", func(v *miSTerCaptureImageReceiptV2) { v.PostCopyCAPS[3] = 0x42 }},
		{"CAPS result", func(v *miSTerCaptureImageReceiptV2) { v.PostCopyCAPS = v.PostCopyCAPS[:7] }},
		{"result freshness changed", func(v *miSTerCaptureImageReceiptV2) { v.PostCopyCAPS[6]++ }},
		{"release freshness", func(v *miSTerCaptureImageReceiptV2) { v.ReleaseAckFreshness++ }},
		{"burst count", func(v *miSTerCaptureImageReceiptV2) { v.BurstCount++ }},
		{"algorithm", func(v *miSTerCaptureImageReceiptV2) { v.PixelChecksumAlgorithm = "sum32" }},
	} {
		t.Run(tc.name, func(t *testing.T) {
			bad := r; bad.PostCopyCAPS = append([]uint16(nil), r.PostCopyCAPS...); tc.mutate(&bad)
			writeReceipt(bad, false)
			if _, err := ValidateMiSTerCapture(f.expected, f.status, f.manifest, f.files, f.root); err == nil { t.Fatal("invalid v3 proof accepted") }
		})
	}
	writeReceipt(r, true)
	if _, err := ValidateMiSTerCapture(f.expected, f.status, f.manifest, f.files, f.root); err == nil { t.Fatal("v3 receipt accepted fabricated header field") }
}

func TestMiSTerGFW1VectorsAndPermutations(t *testing.T) {
	words := []uint32{0x80000000, 0x80000001, 0x40000003, 0x11223344}
	raw := make([]byte, 4*len(words))
	for i, word := range words { binary.LittleEndian.PutUint32(raw[4*i:], word) }
	if got := miSTerGFW1(raw); got != 0x90a23354 { t.Fatalf("four words = %08x", got) }
	for i := range words { binary.LittleEndian.PutUint32(raw[4*i:], words[len(words)-1-i]) }
	if got := miSTerGFW1(raw); got != 0x09119a2e { t.Fatalf("reversed words = %08x", got) }
	raw = make([]byte, 1024)
	for i := uint32(0); i < 256; i++ { binary.LittleEndian.PutUint32(raw[4*i:], 0x9e3779b9*i+0x01020304) }
	if got := miSTerGFW1(raw); got != 0x85c41297 { t.Fatalf("normal = %08x", got) }
	for i := 0; i < 256; i++ { raw[i], raw[256+i] = raw[256+i], raw[i] }
	if got := miSTerGFW1(raw); got != 0x7ead5021 { t.Fatalf("swapped bursts = %08x", got) }
	for i := 0; i < 256; i++ { raw[i], raw[256+i] = raw[256+i], raw[i] }
	for i := 0; i < 512; i++ { raw[i], raw[512+i] = raw[512+i], raw[i] }
	if got := miSTerGFW1(raw); got != 0xe69f5929 { t.Fatalf("swapped rows = %08x", got) }
}

func TestMiSTerV3RejectsProvisionalUntaggedDescriptor(t *testing.T) {
	f, receipt, ref := newMiSTerCaptureV3Fixture(t)
	desc, err := hex.DecodeString(receipt.DescriptorBytesHex); if err != nil { t.Fatal(err) }
	binary.LittleEndian.PutUint32(desc[40:44], receipt.BurstCount)
	crc := crc32.ChecksumIEEE(desc[:56]); binary.LittleEndian.PutUint32(desc[56:60], crc)
	receipt.DescriptorBytesHex, receipt.DescriptorCRC32 = hex.EncodeToString(desc), fmt.Sprintf("%08x", crc)
	writeMiSTerV3TestReceipt(t, &f, ref, receipt, false)
	if _, err = ValidateMiSTerCapture(f.expected, f.status, f.manifest, f.files, f.root); err == nil { t.Fatal("untagged provisional descriptor accepted") }
	valid, _, ref := newMiSTerCaptureV3Fixture(t)
	var object map[string]interface{}
	if err = decodeJSONValueFromBytes(valid.files.ReceiptJSON[ref.ReceiptPath], &object); err != nil { t.Fatal(err) }
	object["final_completed"] = 673
	if _, err = decodeMiSTerCaptureImageReceiptV2(marshalTestJSON(t, object)); err == nil { t.Fatal("v3 receipt accepted provisional completed-count field") }
}

func TestMiSTerV3OptionalRawProofRecomputesGFW1(t *testing.T) {
	f, receipt, ref := newMiSTerCaptureV3Fixture(t)
	imageFile, err := os.Open(f.files.PNGLocal[receipt.PNGPath]); if err != nil { t.Fatal(err) }
	img, err := png.Decode(imageFile); _ = imageFile.Close(); if err != nil { t.Fatal(err) }
	raw := make([]byte, receipt.PayloadBytes)
	for y := 0; y < int(receipt.Height); y++ {
		for x := 0; x < int(receipt.Width); x++ {
			p := color.RGBAModel.Convert(img.At(x, y)).(color.RGBA)
			offset := y*int(receipt.RowPitch)+x*3
			raw[offset], raw[offset+1], raw[offset+2] = p.R, p.G, p.B
		}
	}
	receipt.RawRGBPath = "/tmp/jtframe-capture-proof-sess-v2/sess-v2-00001.rgb"
	receipt.RawRGBSize = uint64(len(raw))
	local := filepath.Join(f.root, "proof_00000001.rgb")
	if err = os.WriteFile(local, raw, 0600); err != nil { t.Fatal(err) }
	f.files.RawRGBLocal = map[string]string{receipt.RawRGBPath: local}
	desc, err := hex.DecodeString(receipt.DescriptorBytesHex); if err != nil { t.Fatal(err) }
	setChecksum := func(checksum uint32) {
		binary.LittleEndian.PutUint32(desc[44:48], checksum)
		crc := crc32.ChecksumIEEE(desc[:56]); binary.LittleEndian.PutUint32(desc[56:60], crc)
		receipt.PixelChecksum, receipt.DescriptorCRC32 = fmt.Sprintf("%08x", checksum), fmt.Sprintf("%08x", crc)
		receipt.DescriptorBytesHex = hex.EncodeToString(desc)
		writeMiSTerV3TestReceipt(t, &f, ref, receipt, false)
	}
	checksum := miSTerGFW1(raw)
	setChecksum(checksum)
	if _, err = ValidateMiSTerCapture(f.expected, f.status, f.manifest, f.files, f.root); err != nil { t.Fatalf("valid raw GFW1 rejected: %v", err) }
	setChecksum(checksum ^ 1)
	if _, err = ValidateMiSTerCapture(f.expected, f.status, f.manifest, f.files, f.root); err == nil { t.Fatal("raw proof accepted matching but false descriptor and receipt checksums") }
}

func TestMiSTerV3CoreDDRSlot(t *testing.T) {
	f, r, ref := newMiSTerCaptureV3Fixture(t)
	withSlot := func(base, mode uint32) miSTerCaptureImageReceiptV2 {
		v := r
		desc, err := hex.DecodeString(r.DescriptorBytesHex)
		if err != nil { t.Fatal(err) }
		binary.LittleEndian.PutUint32(desc[12:16], base)
		binary.LittleEndian.PutUint32(desc[32:36], mode)
		crc := crc32.ChecksumIEEE(desc[:56])
		binary.LittleEndian.PutUint32(desc[56:60], crc)
		v.SlotBase, v.Mode = fmt.Sprintf("%08x", base), fmt.Sprintf("%08x", mode)
		v.DescriptorCRC32, v.DescriptorBytesHex = fmt.Sprintf("%08x", crc), hex.EncodeToString(desc)
		return v
	}
	writeMiSTerV3TestReceipt(t, &f, ref, withSlot(miSTerCoreSlotBase, 0x2c01), false)
	if _, err := ValidateMiSTerCapture(f.expected, f.status, f.manifest, f.files, f.root); err != nil {
		t.Fatalf("core DDR slot rejected: %v", err)
	}
	for _, tc := range []struct {
		name       string
		base, mode uint32
	}{
		{"core mode at scaler base", miSTerScalerBase, 0x2c01},
		{"core base without core mode", miSTerCoreSlotBase, 0x0c01},
		{"reserved mode bit", miSTerCoreSlotBase, 0x6c01},
	} {
		t.Run(tc.name, func(t *testing.T) {
			writeMiSTerV3TestReceipt(t, &f, ref, withSlot(tc.base, tc.mode), false)
			if _, err := ValidateMiSTerCapture(f.expected, f.status, f.manifest, f.files, f.root); err == nil {
				t.Fatal("invalid core slot accepted")
			}
		})
	}
}
