/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"bytes"
	"embed"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"hash/crc32"
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// The six compact JSON files are serialized by the actual capqual40 and
// Circus36 E914 hardware sessions. They contain metadata only, no game PNGs.
//
//go:embed testdata/mister_receipt/*/*.json
var mainReceiptGoldens embed.FS

type receiptGolden struct {
	name                 string
	sessionID            string
	coreDir              string
	planCRC, cabCRC      uint32
	packedSHA, packedHex string
	first, step, count   uint32
	width, height, pitch uint32
	firstSlot, stride    uint32
}

var receiptGoldens = []receiptGolden{
	// Bindings and geometry are from the frozen physical capqual40 run.
	{"capqual40", "capq224-cadence40-20261114", "capqual", 0xe316ed16, 0x7072ad54,
		"9d3165a4e4b712673f04c00045ee11be8414850f179651af0e1cc53c09c1f103",
		"4a5443414230320002000000a00f0000010000000000000054ad727020000000a00f000000002000ffff0f00",
		100, 100, 40, 321, 224, 1024, 1, miSTerSlotStride8},
	// Bindings and geometry are from the frozen Circus36 run.
	{"circus36", "circus-r1-20261114", "circusc", 0x2290527d, 0x3927480c,
		"d4b5e6955a44d4b5227f4ff82cf05429e5019b1b949ce35bf0a2b09c8759dde7",
		"4a5443414230310001000000a00f000001000000000000000c48273920000000a00f000000000000",
		500, 100, 36, 256, 224, 768, 2, miSTerSlotStride8},
}

type receiptFixture struct {
	expected MiSTerReceiptExpectation
	status   []byte
	manifest []byte
	files    MiSTerRetrievedFiles
	root     string
}

func TestMiSTerReceiptFrozenGoldenSessions(t *testing.T) {
	for _, golden := range receiptGoldens {
		t.Run(golden.name, func(t *testing.T) {
			fixture := newReceiptFixture(t, golden, false)
			got, err := ValidateMiSTerCapture(fixture.expected, fixture.status, fixture.manifest, fixture.files, fixture.root)
			if err != nil {
				t.Fatal(err)
			}
			if len(got.Images) != int(golden.count) || got.Epoch != 1 || got.PlanCRC32 != golden.planCRC ||
				got.PackedCABCRC32 != golden.cabCRC || got.Images[0].Checkpoint != golden.first ||
				got.Images[len(got.Images)-1].Checkpoint != 4000 || got.Images[0].Width != golden.width ||
				got.Images[0].Height != golden.height || got.Images[0].RowPitch != golden.pitch ||
				got.Images[0].DecodedRGBSHA256 == "" || got.Images[0].PNGFileSHA256 == "" {
				t.Fatalf("validated capture does not match %s frozen fields: %+v", golden.name, got)
			}
			firstPath := fixture.manifestRefPath(0)
			raw, err := DecodeMiSTerCaptureImageReceipt(fixture.files.ReceiptJSON[firstPath])
			if err != nil {
				t.Fatal(err)
			}
			wantMode, err := parseHex32(raw.Mode)
			if err != nil {
				t.Fatal(err)
			}
			wantCRC, err := parseHex32(raw.DescriptorCRC32)
			if err != nil {
				t.Fatal(err)
			}
			if got.Images[0].Mode != wantMode || got.Images[0].DescriptorCRC32 != wantCRC {
				t.Fatalf("validated descriptor metadata = mode %08x CRC %08x, want %08x/%08x", got.Images[0].Mode, got.Images[0].DescriptorCRC32, wantMode, wantCRC)
			}
		})
	}
}

func TestDecodeActualMainSessionGoldens(t *testing.T) {
	for _, golden := range []struct {
		name, dir, session string
		count              uint32
		planCRC, cabCRC    string
		first, last        uint32
		width, height      uint32
	}{
		{"capqual40", "capqual40", "capq224-cadence40-20261114", 40, "e316ed16", "7072ad54", 100, 4000, 321, 224},
		{"circus36", "circus36", "circus-r1-20261114", 36, "2290527d", "3927480c", 500, 4000, 256, 224},
	} {
		t.Run(golden.name, func(t *testing.T) {
			read := func(name string) []byte {
				data, err := mainReceiptGoldens.ReadFile(filepath.ToSlash(filepath.Join("testdata/mister_receipt", golden.dir, name)))
				if err != nil {
					t.Fatal(err)
				}
				return data
			}
			manifest, err := DecodeMiSTerCaptureManifest(read("manifest.json"))
			if err != nil {
				t.Fatal(err)
			}
			status, err := DecodeMiSTerCaptureStatus(read("status.json"))
			if err != nil {
				t.Fatal(err)
			}
			receipt, err := DecodeMiSTerCaptureImageReceipt(read("image-0001.json"))
			if err != nil {
				t.Fatal(err)
			}
			if manifest.SessionID != golden.session || manifest.ExpectedCount != golden.count ||
				manifest.CompletedCount != golden.count || manifest.PlanCRC32 != golden.planCRC ||
				manifest.PackedCABCRC32 != golden.cabCRC || manifest.PlannedCheckpoints[0] != golden.first ||
				manifest.PlannedCheckpoints[len(manifest.PlannedCheckpoints)-1] != golden.last ||
				status.SessionID != golden.session || status.CompletedCount != golden.count ||
				status.ScheduleCRC32 != golden.planCRC || status.PackedCABCRC32 != golden.cabCRC ||
				receipt.SessionID != golden.session || receipt.Width != golden.width || receipt.Height != golden.height ||
				receipt.Sequence != 1 || receipt.RequestedCheckpoint != golden.first {
				t.Fatalf("actual Main golden fields differ: manifest=%+v status=%+v receipt=%+v", manifest, status, receipt)
			}
		})
	}
}

func TestMiSTerReceiptStrictJSONShapes(t *testing.T) {
	fixture := newReceiptFixture(t, receiptGoldens[0], false)
	for _, tc := range []struct {
		name string
		data []byte
	}{
		{"duplicate", bytes.Replace(fixture.status, []byte(`"state":"complete"`), []byte(`"state":"complete","state":"complete"`), 1)},
		{"missing", bytes.Replace(fixture.status, []byte(`,"fault":0`), nil, 1)},
		{"wrong type", bytes.Replace(fixture.status, []byte(`"fault":0`), []byte(`"fault":"0"`), 1)},
		{"unknown", bytes.Replace(fixture.status, []byte(`{"protocol"`), []byte(`{"extra":true,"protocol"`), 1)},
		{"null", bytes.Replace(fixture.status, []byte(`"schedule_state":"complete"`), []byte(`"schedule_state":null`), 1)},
	} {
		t.Run("status_"+tc.name, func(t *testing.T) {
			if _, err := DecodeMiSTerCaptureStatus(tc.data); err == nil {
				t.Fatal("invalid status JSON accepted")
			}
		})
	}
	refPath := fmt.Sprintf("/tmp/jtframe-capture-%s-image-%08x.receipt.json", receiptGoldens[0].sessionID, uint32(1))
	receiptJSON := fixture.files.ReceiptJSON[refPath]
	for _, bad := range [][]byte{
		bytes.Replace(receiptJSON, []byte(`"png_size":`), []byte(`"extra":1,"png_size":`), 1),
		bytes.Replace(receiptJSON, []byte(`"release_confirmed":true`), []byte(`"release_confirmed":null`), 1),
		bytes.Replace(receiptJSON, []byte(`"sequence":1`), []byte(`"sequence":"1"`), 1),
	} {
		if _, err := DecodeMiSTerCaptureImageReceipt(bad); err == nil {
			t.Fatal("invalid image receipt JSON accepted")
		}
	}
	badManifest := bytes.Replace(fixture.manifest, []byte(`"cab_terminal":{"observed"`), []byte(`"cab_terminal":{"observed":true,"observed"`), 1)
	if _, err := DecodeMiSTerCaptureManifest(badManifest); err == nil {
		t.Fatal("duplicate nested manifest field accepted")
	}
}

func TestMiSTerReceiptRejectsAttemptAndManifestMismatches(t *testing.T) {
	for _, tc := range []struct {
		name string
		edit func(*receiptFixture)
	}{
		{"wrong session", func(f *receiptFixture) { f.expected.Attempt.SessionID = "other-session" }},
		{"wrong FPGA generation", func(f *receiptFixture) { f.expected.FPGAGeneration++ }},
		{"wrong plan CRC", func(f *receiptFixture) { f.expected.PlanCRC32++ }},
		{"wrong CAB CRC", func(f *receiptFixture) { f.expected.Prepared.CAB.PayloadCRC32++ }},
		{"stale manifest session", func(f *receiptFixture) {
			mutateManifest(t, f, func(m *MiSTerCaptureManifest) { m.SessionID = "stale" })
		}},
		{"manifest reordered", func(f *receiptFixture) {
			mutateManifest(t, f, func(m *MiSTerCaptureManifest) { m.Images[0], m.Images[1] = m.Images[1], m.Images[0] })
		}},
		{"manifest missing image", func(f *receiptFixture) {
			mutateManifest(t, f, func(m *MiSTerCaptureManifest) { m.Images = m.Images[:len(m.Images)-1]; m.CompletedCount-- })
		}},
		{"manifest duplicate image", func(f *receiptFixture) {
			mutateManifest(t, f, func(m *MiSTerCaptureManifest) { m.Images[1] = m.Images[0] })
		}},
		{"failed CAB terminal", func(f *receiptFixture) {
			mutateManifest(t, f, func(m *MiSTerCaptureManifest) { m.CABTerminal.Failed = true })
		}},
		{"wrong terminal frame count", func(f *receiptFixture) {
			mutateManifest(t, f, func(m *MiSTerCaptureManifest) { m.CABTerminal.Frames-- })
		}},
		{"terminal event counts all zero", func(f *receiptFixture) {
			mutateManifest(t, f, func(m *MiSTerCaptureManifest) {
				m.CABTerminal.EventsAccepted, m.CABTerminal.EventsApplied, m.CABTerminal.EventsTotal = 0, 0, 0
			})
		}},
		{"terminal event counts all two", func(f *receiptFixture) {
			mutateManifest(t, f, func(m *MiSTerCaptureManifest) {
				m.CABTerminal.EventsAccepted, m.CABTerminal.EventsApplied, m.CABTerminal.EventsTotal = 2, 2, 2
			})
		}},
		{"reload required", func(f *receiptFixture) { mutateStatus(t, f, func(s *MiSTerCaptureStatus) { s.ReloadRequired = true }) }},
		{"cleanup unconfirmed", func(f *receiptFixture) {
			mutateStatus(t, f, func(s *MiSTerCaptureStatus) { s.CleanupConfirmed = false })
		}},
		{"status write failure", func(f *receiptFixture) {
			mutateStatus(t, f, func(s *MiSTerCaptureStatus) { s.StatusWriteFailed = true })
		}},
		{"receipt write failure", func(f *receiptFixture) {
			mutateStatus(t, f, func(s *MiSTerCaptureStatus) { s.ReceiptWriteFailed = true })
		}},
		{"wrong terminal output", func(f *receiptFixture) {
			mutateStatus(t, f, func(s *MiSTerCaptureStatus) { s.Output = "/media/fat/screenshots/other.png" })
		}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			fixture := newReceiptFixture(t, receiptGoldens[0], false)
			tc.edit(&fixture)
			if _, err := ValidateMiSTerCapture(fixture.expected, fixture.status, fixture.manifest, fixture.files, fixture.root); err == nil {
				t.Fatal("mismatched attempt/session accepted")
			}
		})
	}
}

func TestMiSTerReceiptRejectsBadDescriptorAndLegacyHeader(t *testing.T) {
	for _, tc := range []struct {
		name string
		edit func(*MiSTerCaptureImageReceipt)
	}{
		{"descriptor CRC", func(r *MiSTerCaptureImageReceipt) { r.DescriptorCRC32 = "00000000" }},
		{"descriptor checkpoint", func(r *MiSTerCaptureImageReceipt) { r.DescriptorCheckpoint++ }},
		{"unsupported mode", func(r *MiSTerCaptureImageReceipt) { r.Mode = "00001d01" }},
		{"wrong pitch", func(r *MiSTerCaptureImageReceipt) { r.RowPitch-- }},
		{"slot base", func(r *MiSTerCaptureImageReceipt) { r.SlotBase = "21000000" }},
		{"slot stride", func(r *MiSTerCaptureImageReceipt) { r.SlotStride = 4096 }},
		{"header after mismatch", func(r *MiSTerCaptureImageReceipt) {
			header, _ := hex.DecodeString(r.HeaderAfterHex)
			header[16] ^= 1
			r.HeaderAfterHex = hex.EncodeToString(header)
			r.HeaderAfterCRC32 = fmt.Sprintf("%08x", crc32.ChecksumIEEE(header))
		}},
		{"header reserved legacy flag", func(r *MiSTerCaptureImageReceipt) {
			header, _ := hex.DecodeString(r.HeaderBeforeHex)
			binary.BigEndian.PutUint16(header[4:6], 1)
			r.HeaderBeforeHex = hex.EncodeToString(header)
			r.HeaderAfterHex = hex.EncodeToString(header)
			r.HeaderBeforeCRC32 = fmt.Sprintf("%08x", crc32.ChecksumIEEE(header))
			r.HeaderAfterCRC32 = r.HeaderBeforeCRC32
		}},
		{"zero output geometry", func(r *MiSTerCaptureImageReceipt) {
			header, _ := hex.DecodeString(r.HeaderBeforeHex)
			header[12], header[13] = 0, 0
			r.HeaderBeforeHex = hex.EncodeToString(header)
			r.HeaderAfterHex = hex.EncodeToString(header)
			r.HeaderBeforeCRC32 = fmt.Sprintf("%08x", crc32.ChecksumIEEE(header))
			r.HeaderAfterCRC32 = r.HeaderBeforeCRC32
		}},
		{"release missing", func(r *MiSTerCaptureImageReceipt) { r.ReleaseConfirmed = false }},
		{"write counter mismatch", func(r *MiSTerCaptureImageReceipt) { r.FinalIssued++ }},
	} {
		t.Run(tc.name, func(t *testing.T) {
			fixture := newReceiptFixture(t, receiptGoldens[0], false)
			mutateFirstReceipt(t, &fixture, tc.edit)
			if _, err := ValidateMiSTerCapture(fixture.expected, fixture.status, fixture.manifest, fixture.files, fixture.root); err == nil {
				t.Fatal("invalid image receipt accepted")
			}
		})
	}
}

func TestMiSTerReceiptPNGAndPathValidation(t *testing.T) {
	t.Run("same RGB different PNG encoding", func(t *testing.T) {
		fixture := newReceiptFixture(t, receiptGoldens[0], false)
		refPath := fixture.manifestRefPath(0)
		receipt, err := DecodeMiSTerCaptureImageReceipt(fixture.files.ReceiptJSON[refPath])
		if err != nil {
			t.Fatal(err)
		}
		local := fixture.files.PNGLocal[receipt.PNGPath]
		decoded, err := png.Decode(mustOpen(t, local))
		if err != nil {
			t.Fatal(err)
		}
		file, err := os.Create(local)
		if err != nil {
			t.Fatal(err)
		}
		if err := (&png.Encoder{CompressionLevel: png.BestSpeed}).Encode(file, decoded); err != nil {
			_ = file.Close()
			t.Fatal(err)
		}
		if err := file.Close(); err != nil {
			t.Fatal(err)
		}
		info, _ := os.Stat(local)
		receipt.PNGSize = uint64(info.Size())
		fixture.files.ReceiptJSON[refPath] = marshalTestJSON(t, receipt)
		writeFixtureReceipt(t, &fixture, refPath)
		validated, err := ValidateMiSTerCapture(fixture.expected, fixture.status, fixture.manifest, fixture.files, fixture.root)
		if err != nil {
			t.Fatal(err)
		}
		if validated.Images[0].DecodedRGBSHA256 == "" {
			t.Fatal("decoded RGB digest missing")
		}
	})
	t.Run("corrupt PNG and path escape", func(t *testing.T) {
		fixture := newReceiptFixture(t, receiptGoldens[0], false)
		refPath := fixture.manifestRefPath(0)
		receipt, _ := DecodeMiSTerCaptureImageReceipt(fixture.files.ReceiptJSON[refPath])
		local := fixture.files.PNGLocal[receipt.PNGPath]
		if err := os.WriteFile(local, []byte("not png"), 0600); err != nil {
			t.Fatal(err)
		}
		if _, err := ValidateMiSTerCapture(fixture.expected, fixture.status, fixture.manifest, fixture.files, fixture.root); err == nil {
			t.Fatal("corrupt PNG accepted")
		}
		fixture = newReceiptFixture(t, receiptGoldens[0], false)
		refPath = fixture.manifestRefPath(0)
		mutateFirstReceipt(t, &fixture, func(r *MiSTerCaptureImageReceipt) { r.PNGPath = "/media/fat/screenshots/../escape.png" })
		if _, err := ValidateMiSTerCapture(fixture.expected, fixture.status, fixture.manifest, fixture.files, fixture.root); err == nil {
			t.Fatal("traversal PNG path accepted")
		}
	})
	t.Run("alpha and oversized geometry", func(t *testing.T) {
		fixture := newReceiptFixture(t, receiptGoldens[0], false)
		path := fixture.manifestRefPath(0)
		receipt, _ := DecodeMiSTerCaptureImageReceipt(fixture.files.ReceiptJSON[path])
		local := fixture.files.PNGLocal[receipt.PNGPath]
		img, err := png.Decode(mustOpen(t, local))
		if err != nil {
			t.Fatal(err)
		}
		transparent := image.NewRGBA(img.Bounds())
		for y := 0; y < img.Bounds().Dy(); y++ {
			for x := 0; x < img.Bounds().Dx(); x++ {
				r, g, b, _ := img.At(x, y).RGBA()
				alpha := uint8(255)
				if x == 0 && y == 0 {
					alpha = 0
				}
				transparent.SetRGBA(x, y, color.RGBA{R: uint8(r >> 8), G: uint8(g >> 8), B: uint8(b >> 8), A: alpha})
			}
		}
		var encoded bytes.Buffer
		if err := png.Encode(&encoded, transparent); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(local, encoded.Bytes(), 0600); err != nil {
			t.Fatal(err)
		}
		receipt.PNGSize = uint64(encoded.Len())
		fixture.files.ReceiptJSON[path] = marshalTestJSON(t, receipt)
		writeFixtureReceipt(t, &fixture, path)
		if _, err := ValidateMiSTerCapture(fixture.expected, fixture.status, fixture.manifest, fixture.files, fixture.root); err == nil {
			t.Fatal("transparent PNG accepted")
		}
		fixture = newReceiptFixture(t, receiptGoldens[0], false)
		mutateFirstReceipt(t, &fixture, func(r *MiSTerCaptureImageReceipt) { r.Width = 4096 })
		if _, err := ValidateMiSTerCapture(fixture.expected, fixture.status, fixture.manifest, fixture.files, fixture.root); err == nil {
			t.Fatal("oversized descriptor geometry accepted")
		}
	})
	t.Run("symlink rejected", func(t *testing.T) {
		fixture := newReceiptFixture(t, receiptGoldens[0], false)
		refPath := fixture.manifestRefPath(0)
		receipt, _ := DecodeMiSTerCaptureImageReceipt(fixture.files.ReceiptJSON[refPath])
		local := fixture.files.PNGLocal[receipt.PNGPath]
		link := local + ".link"
		if err := os.Rename(local, link); err != nil {
			t.Fatal(err)
		}
		if err := os.Symlink(link, local); err != nil {
			t.Fatal(err)
		}
		if _, err := ValidateMiSTerCapture(fixture.expected, fixture.status, fixture.manifest, fixture.files, fixture.root); err == nil {
			t.Fatal("symlink PNG accepted")
		}
	})
	t.Run("extra local capture file", func(t *testing.T) {
		fixture := newReceiptFixture(t, receiptGoldens[0], false)
		if err := os.WriteFile(filepath.Join(fixture.root, "stale.png"), []byte("x"), 0600); err != nil {
			t.Fatal(err)
		}
		if _, err := ValidateMiSTerCapture(fixture.expected, fixture.status, fixture.manifest, fixture.files, fixture.root); err == nil {
			t.Fatal("extra local PNG accepted")
		}
	})
}

func TestMiSTerReceiptOptionalRawProof(t *testing.T) {
	golden := receiptGoldens[0]
	golden.count, golden.first, golden.step = 1, 100, 100
	fixture := newReceiptFixture(t, golden, true)
	if _, err := ValidateMiSTerCapture(fixture.expected, fixture.status, fixture.manifest, fixture.files, fixture.root); err != nil {
		t.Fatalf("valid optional raw proof rejected: %v", err)
	}
	for _, path := range fixture.files.RawRGBLocal {
		data, err := os.ReadFile(path)
		if err != nil {
			t.Fatal(err)
		}
		data[0] ^= 0xff
		if err := os.WriteFile(path, data, 0600); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := ValidateMiSTerCapture(fixture.expected, fixture.status, fixture.manifest, fixture.files, fixture.root); err == nil {
		t.Fatal("raw proof with pixels different from decoded PNG accepted")
	}
}

func TestMiSTerReceiptPixelPayloadReservesHeaderOffset(t *testing.T) {
	valid := receiptGoldens[0]
	valid.name, valid.count, valid.first, valid.step = "boundary-valid", 1, 100, 100
	valid.width, valid.height, valid.pitch, valid.firstSlot, valid.stride = 86, 4095, 512, 0, miSTerSlotStride2
	fixture := newReceiptFixture(t, valid, false)
	if _, err := ValidateMiSTerCapture(fixture.expected, fixture.status, fixture.manifest, fixture.files, fixture.root); err != nil {
		t.Fatalf("payload within stride-256 bound rejected: %v", err)
	}
	invalid := receiptGoldens[0]
	invalid.name, invalid.count, invalid.first, invalid.step = "boundary-overflow", 1, 100, 100
	invalid.width, invalid.height, invalid.pitch, invalid.firstSlot, invalid.stride = 321, 2048, 1024, 0, miSTerSlotStride2
	fixture = newReceiptFixture(t, invalid, false)
	if _, err := ValidateMiSTerCapture(fixture.expected, fixture.status, fixture.manifest, fixture.files, fixture.root); err == nil {
		t.Fatal("payload equal to slot stride accepted despite 256-byte header")
	}
}

func TestMiSTerReceiptMainScreenshotNaming(t *testing.T) {
	golden := receiptGoldens[0]
	golden.count, golden.first, golden.step = 1, 100, 100
	fixture := newReceiptFixture(t, golden, false)
	setFixtureScreenshotPath(t, &fixture, "/media/fat/screenshots/capqual/NODATE-cabcap_capq224-cadence40-20261114_00000001_00000064_00000001_0001.png")
	if _, err := ValidateMiSTerCapture(fixture.expected, fixture.status, fixture.manifest, fixture.files, fixture.root); err != nil {
		t.Fatalf("Main NODATE screenshot naming rejected: %v", err)
	}
	fixture = newReceiptFixture(t, golden, false)
	setFixtureScreenshotPath(t, &fixture, "/media/fat/screenshots/capqual/20261114_052158-cabcap_capq224-cadence40-20261114_00000001_00000064_00000001.png")
	if _, err := ValidateMiSTerCapture(fixture.expected, fixture.status, fixture.manifest, fixture.files, fixture.root); err != nil {
		t.Fatalf("Main timestamp screenshot naming rejected: %v", err)
	}
	fixture = newReceiptFixture(t, golden, false)
	setFixtureScreenshotPath(t, &fixture, "/media/fat/screenshots/user-family/holiday.png")
	if _, err := ValidateMiSTerCapture(fixture.expected, fixture.status, fixture.manifest, fixture.files, fixture.root); err == nil {
		t.Fatal("unrelated screenshot accepted with self-consistent local mapping/status")
	}
}

func newReceiptFixture(t *testing.T, golden receiptGolden, withProof bool) receiptFixture {
	t.Helper()
	root := t.TempDir()
	if err := os.Chmod(root, 0700); err != nil {
		t.Fatal(err)
	}
	prepared := preparedSessionFixture()
	prepared.CAB.PayloadCRC32 = golden.cabCRC
	prepared.CAB.PackedSHA256 = golden.packedSHA
	prepared.CAB.TotalFrames = 4000
	prepared.Checkpoints = make([]uint32, golden.count)
	for i := range prepared.Checkpoints {
		prepared.Checkpoints[i] = golden.first + uint32(i)*golden.step
	}
	key := AttemptKey{Board: "mister-test", SessionID: golden.sessionID, Nonce: "attempt-a"}
	packedCAB, err := hex.DecodeString(golden.packedHex)
	if err != nil {
		t.Fatal(err)
	}
	expected := MiSTerReceiptExpectation{Prepared: prepared, PackedCAB: packedCAB, Attempt: key, FPGAGeneration: 1,
		PlanCRC32: golden.planCRC, MaxHoldMS: 1000}
	manifest := MiSTerCaptureManifest{Protocol: "jtframe-capture-session-v1", Version: 1,
		SessionID: golden.sessionID, State: "complete", FPGAGeneration: 1,
		PlanCRC32: fmt.Sprintf("%08x", golden.planCRC), PackedCABCRC32: fmt.Sprintf("%08x", golden.cabCRC),
		Epoch: "00000001", PlanTotalFrames: 4000, ExpectedCount: golden.count,
		PlannedCheckpoints: append([]uint32(nil), prepared.Checkpoints...), CompletedCount: golden.count,
		CABTerminal: MiSTerCABTerminal{Observed: true, CleanupConfirmed: true, InputsNeutral: true,
			Epoch: 1, Frames: 4000, FramesTotal: 4000, EventsAccepted: 1, EventsApplied: 1, EventsTotal: 1}}
	files := MiSTerRetrievedFiles{ReceiptJSON: make(map[string][]byte), ReceiptLocal: make(map[string]string), PNGLocal: make(map[string]string)}
	if withProof {
		files.RawRGBLocal = make(map[string]string)
	}
	var lastPNG string
	var lastPayload uint32
	for index, checkpoint := range prepared.Checkpoints {
		sequence := uint32(index + 1)
		slot := (golden.firstSlot + uint32(index)) % 3
		width, height, pitch := golden.width, golden.height, golden.pitch
		payload := pitch * height
		stride := golden.stride
		base := uint32(0x20000000) + slot*stride
		mode := uint32(0x0c01) | slot<<8
		issued := uint32(100000 + index)
		descriptor := make([]byte, 64)
		copy(descriptor[:4], "JTC1")
		binary.LittleEndian.PutUint16(descriptor[4:6], 1)
		binary.LittleEndian.PutUint16(descriptor[6:8], 64)
		binary.LittleEndian.PutUint32(descriptor[8:12], 1)
		binary.LittleEndian.PutUint32(descriptor[12:16], sequence)
		binary.LittleEndian.PutUint32(descriptor[16:20], checkpoint)
		binary.LittleEndian.PutUint32(descriptor[20:24], checkpoint-1)
		binary.LittleEndian.PutUint32(descriptor[24:28], base)
		binary.LittleEndian.PutUint32(descriptor[28:32], stride)
		binary.LittleEndian.PutUint16(descriptor[32:34], uint16(width))
		binary.LittleEndian.PutUint16(descriptor[34:36], uint16(height))
		binary.LittleEndian.PutUint32(descriptor[36:40], pitch)
		binary.LittleEndian.PutUint32(descriptor[40:44], payload)
		binary.LittleEndian.PutUint32(descriptor[44:48], mode)
		binary.LittleEndian.PutUint32(descriptor[48:52], issued)
		binary.LittleEndian.PutUint32(descriptor[52:56], issued)
		descriptorCRC := crc32.ChecksumIEEE(descriptor[:56])
		binary.LittleEndian.PutUint32(descriptor[56:60], descriptorCRC)
		copy(descriptor[60:64], "RDY1")
		header := make([]byte, 256)
		header[0], header[1] = 1, 1
		binary.BigEndian.PutUint16(header[2:4], 256)
		binary.BigEndian.PutUint16(header[4:6], 0x0010) // Ordinary triple-buffer flag.
		binary.BigEndian.PutUint16(header[6:8], uint16(width))
		binary.BigEndian.PutUint16(header[8:10], uint16(height))
		binary.BigEndian.PutUint16(header[10:12], uint16(pitch))
		binary.BigEndian.PutUint16(header[12:14], 640) // Output geometry may differ from native.
		binary.BigEndian.PutUint16(header[14:16], 480)
		copy(header[192:], descriptor)
		headerCRC := crc32.ChecksumIEEE(header)
		imageReceipt := MiSTerCaptureImageReceipt{Protocol: "jtframe-capture-image-v1", SessionID: golden.sessionID,
			FPGAGeneration: 1, PlanCRC32: fmt.Sprintf("%08x", golden.planCRC), PackedCABCRC32: fmt.Sprintf("%08x", golden.cabCRC),
			Epoch: "00000001", Sequence: sequence, RequestedCheckpoint: checkpoint, ActualInterval: checkpoint - 1,
			ActualCheckpoint: checkpoint, DescriptorCheckpoint: checkpoint, Width: width, Height: height,
			RowPitch: pitch, PayloadBytes: payload, SlotBase: fmt.Sprintf("%08x", base), SlotStride: stride, Slot: slot,
			Mode: fmt.Sprintf("%08x", mode), DescriptorCRC32: fmt.Sprintf("%08x", descriptorCRC),
			HeaderBeforeCRC32: fmt.Sprintf("%08x", headerCRC), HeaderAfterCRC32: fmt.Sprintf("%08x", headerCRC),
			DescriptorBytesHex: hex.EncodeToString(descriptor), HeaderBeforeHex: hex.EncodeToString(header),
			HeaderAfterHex: hex.EncodeToString(header), FinalIssued: issued, FinalCompleted: issued,
			ReleaseConfirmed: true, PNGComplete: true,
			PNGPath: fmt.Sprintf("/media/fat/screenshots/%s/20261114_052158-cabcap_%s_%08x_%08x_%08x.png",
				golden.coreDir, golden.sessionID, uint32(1), checkpoint, sequence)}
		img := image.NewRGBA(image.Rect(0, 0, int(width), int(height)))
		for y := 0; y < int(height); y++ {
			for x := 0; x < int(width); x++ {
				img.SetRGBA(x, y, color.RGBA{R: uint8((x + int(sequence)) % 251), G: uint8((y*3 + int(sequence)) % 253), B: uint8((x + y + int(sequence)*7) % 255), A: 255})
			}
		}
		var encoded bytes.Buffer
		if err := png.Encode(&encoded, img); err != nil {
			t.Fatal(err)
		}
		imageReceipt.PNGSize = uint64(encoded.Len())
		localPNG := filepath.Join(root, CapturePNGLocalName(checkpoint))
		if err := os.WriteFile(localPNG, encoded.Bytes(), 0600); err != nil {
			t.Fatal(err)
		}
		files.PNGLocal[imageReceipt.PNGPath] = localPNG
		if withProof {
			imageReceipt.RawRGBPath = fmt.Sprintf("/tmp/jtframe-capture-proof-%s/%s-%08x-%08x.rgb", golden.name, golden.sessionID, uint32(1), sequence)
			imageReceipt.RawRGBSize = uint64(payload)
			raw := make([]byte, payload)
			for y := uint32(0); y < height; y++ {
				for x := uint32(0); x < width; x++ {
					pixel := img.RGBAAt(int(x), int(y))
					at := int(y*pitch + x*3)
					raw[at], raw[at+1], raw[at+2] = pixel.R, pixel.G, pixel.B
				}
			}
			localRaw := filepath.Join(root, fmt.Sprintf("proof_%08d.rgb", checkpoint))
			if err := os.WriteFile(localRaw, raw, 0600); err != nil {
				t.Fatal(err)
			}
			files.RawRGBLocal[imageReceipt.RawRGBPath] = localRaw
		}
		receiptPath := fmt.Sprintf("/tmp/jtframe-capture-%s-image-%08x.receipt.json", golden.sessionID, sequence)
		receiptJSON := marshalTestJSON(t, imageReceipt)
		files.ReceiptJSON[receiptPath] = receiptJSON
		localReceipt := filepath.Join(root, fmt.Sprintf("receipt_%08d.json", checkpoint))
		if err := os.WriteFile(localReceipt, receiptJSON, 0600); err != nil {
			t.Fatal(err)
		}
		files.ReceiptLocal[receiptPath] = localReceipt
		manifest.Images = append(manifest.Images, MiSTerCaptureReceiptRef{Sequence: sequence, Checkpoint: checkpoint,
			Epoch: "00000001", FPGAGeneration: 1, PlanCRC32: fmt.Sprintf("%08x", golden.planCRC),
			PackedCABCRC32: fmt.Sprintf("%08x", golden.cabCRC), ReceiptPath: receiptPath})
		lastPNG, lastPayload = imageReceipt.PNGPath, payload
	}
	status := MiSTerCaptureStatus{Protocol: "jtframe-capture-session-v1", SessionID: golden.sessionID, State: "complete",
		Epoch: "00000001", Sequence: fmt.Sprintf("%08x", golden.count), Checkpoint: prepared.Checkpoints[len(prepared.Checkpoints)-1],
		MaxHoldMS: 1000, CleanupConfirmed: true, CopiedBytes: uint64(lastPayload), Output: lastPNG, Scheduled: true,
		ScheduleCRC32: fmt.Sprintf("%08x", golden.planCRC), PackedCABCRC32: fmt.Sprintf("%08x", golden.cabCRC),
		ScheduleCount: golden.count, ScheduleIndex: golden.count, ScheduleState: "complete",
		ReceiptProtocol: "jtframe-capture-image-v1", ManifestPath: fmt.Sprintf("/tmp/jtframe-capture-%s.manifest.json", golden.sessionID),
		CompletedCount: golden.count}
	return receiptFixture{expected: expected, status: marshalTestJSON(t, status), manifest: marshalTestJSON(t, manifest), files: files, root: root}
}

func (f receiptFixture) manifestRefPath(index int) string {
	manifest, _ := DecodeMiSTerCaptureManifest(f.manifest)
	return manifest.Images[index].ReceiptPath
}

func mutateManifest(t *testing.T, fixture *receiptFixture, mutate func(*MiSTerCaptureManifest)) {
	t.Helper()
	manifest, err := DecodeMiSTerCaptureManifest(fixture.manifest)
	if err != nil {
		t.Fatal(err)
	}
	mutate(&manifest)
	fixture.manifest = marshalTestJSON(t, manifest)
}

func mutateStatus(t *testing.T, fixture *receiptFixture, mutate func(*MiSTerCaptureStatus)) {
	t.Helper()
	status, err := DecodeMiSTerCaptureStatus(fixture.status)
	if err != nil {
		t.Fatal(err)
	}
	mutate(&status)
	fixture.status = marshalTestJSON(t, status)
}

func mutateFirstReceipt(t *testing.T, fixture *receiptFixture, mutate func(*MiSTerCaptureImageReceipt)) {
	t.Helper()
	path := fixture.manifestRefPath(0)
	receipt, err := DecodeMiSTerCaptureImageReceipt(fixture.files.ReceiptJSON[path])
	if err != nil {
		t.Fatal(err)
	}
	mutate(&receipt)
	fixture.files.ReceiptJSON[path] = marshalTestJSON(t, receipt)
	writeFixtureReceipt(t, fixture, path)
}

func writeFixtureReceipt(t *testing.T, fixture *receiptFixture, remotePath string) {
	t.Helper()
	local := fixture.files.ReceiptLocal[remotePath]
	if err := os.WriteFile(local, fixture.files.ReceiptJSON[remotePath], 0600); err != nil {
		t.Fatal(err)
	}
}

func setFixtureScreenshotPath(t *testing.T, fixture *receiptFixture, newPath string) {
	t.Helper()
	remoteReceipt := fixture.manifestRefPath(0)
	receipt, err := DecodeMiSTerCaptureImageReceipt(fixture.files.ReceiptJSON[remoteReceipt])
	if err != nil {
		t.Fatal(err)
	}
	oldPath := receipt.PNGPath
	localPath := fixture.files.PNGLocal[oldPath]
	receipt.PNGPath = newPath
	fixture.files.ReceiptJSON[remoteReceipt] = marshalTestJSON(t, receipt)
	writeFixtureReceipt(t, fixture, remoteReceipt)
	delete(fixture.files.PNGLocal, oldPath)
	fixture.files.PNGLocal[newPath] = localPath
	mutateStatus(t, fixture, func(status *MiSTerCaptureStatus) { status.Output = newPath })
}

func marshalTestJSON(t *testing.T, value interface{}) []byte {
	t.Helper()
	data, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	return data
}

func mustOpen(t *testing.T, name string) *os.File {
	t.Helper()
	file, err := os.Open(name)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = file.Close() })
	return file
}

func TestCapturePNGLocalNameIsStable(t *testing.T) {
	if got := CapturePNGLocalName(4000); got != "frame_00004000.png" || strings.Contains(got, string(filepath.Separator)+"..") {
		t.Fatalf("unexpected deterministic name %q", got)
	}
}
