/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"crypto/sha256"
	"encoding/binary"
	"hash/crc32"
	"testing"
)

func TestCapturePlanDefaultAndGolden(t *testing.T) {
	entries, err := CapturePlanEntries(4000, 500, 100, 1000)
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 36 || entries[0].Checkpoint != 500 || entries[35].Checkpoint != 4000 {
		t.Fatalf("default schedule = %d entries, first=%d last=%d", len(entries), entries[0].Checkpoint, entries[len(entries)-1].Checkpoint)
	}
	cab := testPackedCAB(t, 2, make([]byte, 12))
	encoded, err := EncodeCapturePlan(cab, entries)
	if err != nil {
		t.Fatal(err)
	}
	if len(encoded) != 308 {
		t.Fatalf("default JTCP length = %d, want 308", len(encoded))
	}
	if string(encoded[:4]) != "JTCP" || binary.LittleEndian.Uint16(encoded[4:6]) != 2 ||
		binary.LittleEndian.Uint16(encoded[6:8]) != 36 || binary.LittleEndian.Uint32(encoded[12:16]) != 4000 {
		t.Fatalf("unexpected JTCP header: %x", encoded[:16])
	}
	if got := binary.LittleEndian.Uint32(encoded[16:20]); got != 500 {
		t.Fatalf("first checkpoint = %d", got)
	}
	if got := binary.LittleEndian.Uint32(encoded[16+35*8 : 16+35*8+4]); got != 4000 {
		t.Fatalf("last checkpoint = %d", got)
	}
	if got, want := crc32.ChecksumIEEE(encoded[:len(encoded)-4]), binary.LittleEndian.Uint32(encoded[len(encoded)-4:]); got != want {
		t.Fatalf("JTCP CRC = %08x, want %08x", want, got)
	}
	// Independent golden for the JTCP v2 fields shared with Main.
	if got := sha256.Sum256(encoded); got != [32]byte{0x58, 0xb4, 0x31, 0xa8, 0x45, 0xe1, 0x25, 0x75, 0xa6, 0x74, 0xb5, 0xd0, 0x81, 0xf8, 0xb7, 0x2b, 0xb7, 0x34, 0x17, 0x3c, 0x81, 0x04, 0xae, 0x4f, 0x4e, 0x0e, 0x76, 0xf3, 0x1d, 0xbf, 0xfa, 0xac} {
		t.Fatalf("default plan SHA256=%x, update Main v2 golden", got)
	}
}

func TestCapturePlanAcceptsFortyAndMaximumEntries(t *testing.T) {
	forty, err := CapturePlanEntries(4000, 0, 100, 1000)
	if err != nil {
		t.Fatal(err)
	}
	if len(forty) != 40 || forty[0].Checkpoint != 100 || forty[39].Checkpoint != 4000 {
		t.Fatalf("zero-startup 40-capture schedule = %d entries, %d..%d", len(forty), forty[0].Checkpoint, forty[len(forty)-1].Checkpoint)
	}
	fortyCAB := testPackedCAB(t, 2, make([]byte, 40*12), 4000)
	if _, err := EncodeCapturePlan(fortyCAB, forty); err != nil {
		t.Fatalf("40-entry cadence plan rejected: %v", err)
	}
	for _, count := range []int{40, 1024} {
		entries := make([]CapturePlanEntry, count)
		frames := uint32(count)
		cab := testPackedCAB(t, 2, make([]byte, count*12), frames)
		for i := range entries {
			entries[i] = CapturePlanEntry{Checkpoint: uint32(i + 1), MaxHoldMS: 100}
		}
		got, err := EncodeCapturePlan(cab, entries)
		if err != nil {
			t.Fatalf("count %d: %v", count, err)
		}
		if want := 20 + count*8; len(got) != want {
			t.Fatalf("count %d encoded length=%d, want %d", count, len(got), want)
		}
	}
}

func TestCapturePlanPayloadCRCBindingAndZero(t *testing.T) {
	entries := []CapturePlanEntry{{Checkpoint: 1, MaxHoldMS: 100}}
	cab := testPackedCAB(t, 1, make([]byte, 8), 1)
	encoded, err := EncodeCapturePlan(cab, entries)
	if err != nil {
		t.Fatal(err)
	}
	payloadCRC := crc32.ChecksumIEEE(cab[misterCABHeaderLen:])
	if got := binary.LittleEndian.Uint32(encoded[8:12]); got != payloadCRC {
		t.Fatalf("plan binds CRC %08x, payload CRC is %08x", got, payloadCRC)
	}
	fileCRC := crc32.ChecksumIEEE(cab)
	if payloadCRC == fileCRC {
		t.Fatal("test fixture must distinguish payload CRC from whole-file CRC")
	}
	if got := binary.LittleEndian.Uint32(encoded[8:12]); got == fileCRC {
		t.Fatal("plan incorrectly bound whole-file CRC")
	}
	zeroPayload := crcZeroPayload([]byte{1, 0, 0, 0, 0, 0, 0, 0})
	if got := crc32.ChecksumIEEE(zeroPayload); got != 0 {
		t.Fatalf("zero-CRC fixture CRC=%08x", got)
	}
	zeroCAB := testPackedCAB(t, 2, zeroPayload, 1)
	zeroPlan, err := EncodeCapturePlan(zeroCAB, entries)
	if err != nil {
		t.Fatalf("valid zero payload CRC rejected: %v", err)
	}
	if got := binary.LittleEndian.Uint32(zeroPlan[8:12]); got != 0 {
		t.Fatalf("zero payload CRC encoded as %08x", got)
	}
}

func TestCapturePlanRejectsInvalidCABAndEntries(t *testing.T) {
	cab := testPackedCAB(t, 2, make([]byte, 24), 4000)
	valid := []CapturePlanEntry{{Checkpoint: 100, MaxHoldMS: 1000}}
	mutations := []struct {
		name string
		edit func([]byte) []byte
	}{
		{"bad magic", func(b []byte) []byte { b[0] = 'X'; return b }},
		{"bad version", func(b []byte) []byte { binary.LittleEndian.PutUint32(b[8:12], 1); return b }},
		{"bad header length", func(b []byte) []byte { binary.LittleEndian.PutUint32(b[28:32], 31); return b }},
		{"bad payload crc", func(b []byte) []byte { b[32] ^= 1; return b }},
		{"trailing byte", func(b []byte) []byte { return append(b, 0) }},
		{"truncated record", func(b []byte) []byte { return b[:len(b)-1] }},
		{"dumps present", func(b []byte) []byte { binary.LittleEndian.PutUint32(b[20:24], 1); return b }},
		{"record count mismatch", func(b []byte) []byte { binary.LittleEndian.PutUint32(b[16:20], 1); return b }},
	}
	for _, tc := range mutations {
		t.Run(tc.name, func(t *testing.T) {
			bad := tc.edit(append([]byte(nil), cab...))
			if _, err := EncodeCapturePlan(bad, valid); err == nil {
				t.Fatal("invalid CAB accepted")
			}
		})
	}
	badEntries := []struct {
		name string
		edit func([]CapturePlanEntry)
	}{
		{"zero checkpoint", func(e []CapturePlanEntry) { e[0].Checkpoint = 0 }},
		{"checkpoint beyond budget", func(e []CapturePlanEntry) { e[0].Checkpoint = 4001 }},
		{"hold below minimum", func(e []CapturePlanEntry) { e[0].MaxHoldMS = 99 }},
		{"hold above maximum", func(e []CapturePlanEntry) { e[0].MaxHoldMS = 2001 }},
	}
	for _, tc := range badEntries {
		t.Run(tc.name, func(t *testing.T) {
			entries := append([]CapturePlanEntry(nil), valid...)
			tc.edit(entries)
			if _, err := EncodeCapturePlan(cab, entries); err == nil {
				t.Fatal("invalid entry accepted")
			}
		})
	}
	if _, err := EncodeCapturePlan(cab, nil); err == nil {
		t.Fatal("empty plan accepted")
	}
	maxCAB := testPackedCAB(t, 1, make([]byte, 8), misterCABMaxFrames)
	maxPlan, err := EncodeCapturePlan(maxCAB, []CapturePlanEntry{{Checkpoint: misterCABMaxFrames, MaxHoldMS: 100}})
	if err != nil { t.Fatalf("checkpoint 32767 rejected: %v", err) }
	if _, err := EncodeCapturePlan(testPackedCAB(t, 1, make([]byte, 8), misterCABMaxFrames+1), []CapturePlanEntry{{Checkpoint: misterCABMaxFrames, MaxHoldMS: 100}}); err == nil {
		t.Fatal("32768-frame CAB budget accepted")
	}
	if _, err := EncodeCapturePlan(maxCAB, []CapturePlanEntry{{Checkpoint: misterCABMaxFrames+1, MaxHoldMS: 100}}); err == nil {
		t.Fatal("checkpoint 32768 accepted")
	}
	if got := binary.LittleEndian.Uint16(maxPlan[4:6]); got != 2 { t.Fatalf("max plan version=%d", got) }
	tooMany := make([]CapturePlanEntry, 1025)
	if _, err := EncodeCapturePlan(cab, tooMany); err == nil {
		t.Fatal("1025 entries accepted")
	}
	if _, err := CapturePlanEntries(4000, 500, 100, 99); err == nil {
		t.Fatal("invalid default schedule hold accepted")
	}
	if _, err := CapturePlanEntries(4000, -1, 100, 1000); err == nil {
		t.Fatal("negative startup accepted")
	}
}

func TestCapturePlanRejectsCABSemanticsMainRejects(t *testing.T) {
	mutatePayload := func(version uint32, frames uint32, edit func([]byte)) []byte {
		stride := 8
		if version == 2 {
			stride = 12
		}
		payload := make([]byte, stride*2)
		cab := testPackedCAB(t, version, payload, frames)
		edit(cab)
		binary.LittleEndian.PutUint32(cab[24:28], crc32.ChecksumIEEE(cab[misterCABHeaderLen:]))
		return cab
	}
	valid := []CapturePlanEntry{{Checkpoint: 1, MaxHoldMS: 100}}
	invalid := []struct {
		name    string
		version uint32
		frames  uint32
		edit    func([]byte)
	}{
		{"zero duration", 1, 2, func(b []byte) { binary.LittleEndian.PutUint32(b[32:36], 0) }},
		{"duration sum short", 1, 2, func(b []byte) {
			binary.LittleEndian.PutUint32(b[32:36], 1)
			binary.LittleEndian.PutUint32(b[40:44], 0)
		}},
		{"duration sum long", 1, 2, func(b []byte) {
			binary.LittleEndian.PutUint32(b[32:36], 3)
			binary.LittleEndian.PutUint32(b[40:44], 1)
		}},
		{"record count exceeds frames", 2, 1, func(b []byte) {}},
		{"JTCAB01 reserved input bit", 1, 2, func(b []byte) { binary.LittleEndian.PutUint32(b[36:40], 1<<21) }},
		{"JTCAB02 reserved flag bit", 2, 2, func(b []byte) { binary.LittleEndian.PutUint32(b[36:40], 1<<22) }},
		{"JTCAB02 reserved high bit", 2, 2, func(b []byte) { binary.LittleEndian.PutUint32(b[36:40], 1<<31) }},
	}
	for _, tc := range invalid {
		t.Run(tc.name, func(t *testing.T) {
			cab := mutatePayload(tc.version, tc.frames, tc.edit)
			if _, err := EncodeCapturePlan(cab, valid); err == nil {
				t.Fatal("packed CAB rejected by Main was accepted")
			}
		})
	}
	// JTCAB02 bit21 is the supported DIP-stream marker and remains valid.
	dip := testPackedCAB(t, 2, make([]byte, 12), 1)
	binary.LittleEndian.PutUint32(dip[36:40], 1<<21)
	binary.LittleEndian.PutUint32(dip[24:28], crc32.ChecksumIEEE(dip[misterCABHeaderLen:]))
	if _, err := EncodeCapturePlan(dip, valid); err != nil {
		t.Fatalf("supported JTCAB02 DIP marker rejected: %v", err)
	}
}

func TestCapturePlanScheduleBoundBeforeAllocation(t *testing.T) {
	for _, tc := range []struct {
		name                  string
		frames, startup, step int
	}{
		{"1949 entries", 2048, 0, 1},
		{"large budget", misterCABMaxFrames, 0, 1},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if entries, err := CapturePlanEntries(tc.frames, tc.startup, tc.step, 1000); err == nil {
				t.Fatalf("oversized schedule returned %d entries", len(entries))
			}
		})
	}
}

func testPackedCAB(t *testing.T, version uint32, payload []byte, frames ...uint32) []byte {
	t.Helper()
	frameCount := uint32(4000)
	if len(frames) > 0 {
		frameCount = frames[0]
	}
	stride := uint32(8)
	magic := "JTCAB01\x00"
	if version == 2 {
		stride, magic = 12, "JTCAB02\x00"
	}
	if len(payload)%int(stride) != 0 {
		t.Fatalf("test payload length %d is not divisible by stride %d", len(payload), stride)
	}
	count := uint32(len(payload)) / stride
	if count == 0 {
		count = 1
		payload = make([]byte, stride)
		binary.LittleEndian.PutUint32(payload[:4], frameCount)
	}
	for index := uint32(0); index < count; index++ {
		duration := frameCount / count
		if index < frameCount%count {
			duration++
		}
		binary.LittleEndian.PutUint32(payload[int(index*stride):int(index*stride+4)], duration)
	}
	data := make([]byte, misterCABHeaderLen+len(payload))
	copy(data[:8], magic)
	binary.LittleEndian.PutUint32(data[8:12], version)
	binary.LittleEndian.PutUint32(data[12:16], frameCount)
	binary.LittleEndian.PutUint32(data[16:20], count)
	binary.LittleEndian.PutUint32(data[24:28], crc32.ChecksumIEEE(payload))
	binary.LittleEndian.PutUint32(data[28:32], misterCABHeaderLen)
	copy(data[misterCABHeaderLen:], payload)
	return data
}

func crcZeroPayload(prefix []byte) []byte {
	base := append(append([]byte(nil), prefix...), 0, 0, 0, 0)
	baseCRC := crc32.ChecksumIEEE(base)
	columns := make([]uint32, 32)
	for bit := 0; bit < 32; bit++ {
		probe := append([]byte(nil), base...)
		probe[len(probe)-1-bit/8] ^= byte(1 << uint(bit%8))
		columns[bit] = crc32.ChecksumIEEE(probe) ^ baseCRC
	}
	target := baseCRC
	rows := make([]uint64, 32)
	for outputBit := 0; outputBit < 32; outputBit++ {
		var row uint64
		for inputBit, column := range columns {
			if column&(1<<uint(outputBit)) != 0 {
				row |= 1 << uint(inputBit)
			}
		}
		if target&(1<<uint(outputBit)) != 0 {
			row |= 1 << 32
		}
		rows[outputBit] = row
	}
	pivotForColumn := make([]int, 32)
	for i := range pivotForColumn {
		pivotForColumn[i] = -1
	}
	pivotRow := 0
	for column := 0; column < 32; column++ {
		selected := -1
		for row := pivotRow; row < 32; row++ {
			if rows[row]&(1<<uint(column)) != 0 {
				selected = row
				break
			}
		}
		if selected < 0 {
			continue
		}
		rows[pivotRow], rows[selected] = rows[selected], rows[pivotRow]
		for row := 0; row < 32; row++ {
			if row != pivotRow && rows[row]&(1<<uint(column)) != 0 {
				rows[row] ^= rows[pivotRow]
			}
		}
		pivotForColumn[column] = pivotRow
		pivotRow++
	}
	var solution uint32
	for column, row := range pivotForColumn {
		if row >= 0 && rows[row]&(1<<32) != 0 {
			solution |= 1 << uint(column)
		}
	}
	for bit := 0; bit < 32; bit++ {
		if solution&(1<<uint(bit)) != 0 {
			base[len(base)-1-bit/8] ^= byte(1 << uint(bit%8))
		}
	}
	return base
}
