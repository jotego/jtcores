/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"encoding/binary"
	"fmt"
	"hash/crc32"
)

const (
	capturePlanVersion    = uint16(2)
	capturePlanHeaderLen  = 16
	capturePlanEntryLen   = 8
	capturePlanCRCLen     = 4
	capturePlanMaxEntries = 1024
	capturePlanMinHoldMS  = 100
	capturePlanMaxHoldMS  = 2000
	misterCABHeaderLen    = 32
	misterCABMaxBytes     = 16 << 20
	misterCABMaxFrames    = 32767
)

// CapturePlanEntry is one native-frame checkpoint in a preloaded JTCP plan.
type CapturePlanEntry struct {
	Checkpoint uint32
	MaxHoldMS  uint32
}

// CapturePlan binds ordered checkpoints to the packed CAB payload CRC and
// declared frame budget that Main will validate before it arms the session.
type CapturePlan struct {
	PackedCABPayloadCRC32 uint32
	TotalFrames           uint32
	Entries               []CapturePlanEntry
}

// CapturePlanEntries returns the accepted Main schedule for a video profile.
func CapturePlanEntries(videoFrames, startupFrames, cadence, maxHoldMS int) ([]CapturePlanEntry, error) {
	if videoFrames <= 0 || videoFrames > misterCABMaxFrames {
		return nil, fmt.Errorf("capture plan frame budget must be in 1..%d", misterCABMaxFrames)
	}
	if startupFrames < 0 || startupFrames >= videoFrames {
		return nil, fmt.Errorf("capture plan startup frame must be in 0..videoFrames-1")
	}
	first := firstCaptureFrame(startupFrames)
	_, count, err := captureSchedule(videoFrames, cadence, first)
	if err != nil {
		return nil, err
	}
	if count < 1 || count > capturePlanMaxEntries {
		return nil, fmt.Errorf("capture schedule entry count must be in 1..%d", capturePlanMaxEntries)
	}
	if maxHoldMS < capturePlanMinHoldMS || maxHoldMS > capturePlanMaxHoldMS {
		return nil, fmt.Errorf("capture hold must be in %d..%d ms", capturePlanMinHoldMS, capturePlanMaxHoldMS)
	}
	entries := make([]CapturePlanEntry, 0, count)
	for index := 0; index < count; index++ {
		checkpoint := int64(first) + int64(index)*int64(cadence)
		if checkpoint > int64(videoFrames) {
			return nil, fmt.Errorf("capture schedule exceeds video frame budget")
		}
		entries = append(entries, CapturePlanEntry{Checkpoint: uint32(checkpoint), MaxHoldMS: uint32(maxHoldMS)})
	}
	return entries, nil
}

// EncodeCapturePlan encodes a JTCP v1 plan against the exact packed CAB. Its
// CRC binding is CRC32/IEEE of CAB bytes[32:], never the file/header CRC. A
// payload CRC of zero is a valid value and is compared without sentinel logic.
func EncodeCapturePlan(packedCAB []byte, entries []CapturePlanEntry) ([]byte, error) {
	cab, err := inspectPackedCAB(packedCAB)
	if err != nil {
		return nil, err
	}
	if len(entries) == 0 || len(entries) > capturePlanMaxEntries {
		return nil, fmt.Errorf("capture plan entry count must be in 1..%d", capturePlanMaxEntries)
	}
	previous := uint32(0)
	for _, entry := range entries {
		if entry.Checkpoint == 0 || entry.Checkpoint > misterCABMaxFrames || entry.Checkpoint <= previous || entry.Checkpoint > cab.totalFrames {
			return nil, fmt.Errorf("capture checkpoint %d must increase within 1..%d", entry.Checkpoint, cab.totalFrames)
		}
		if entry.MaxHoldMS < capturePlanMinHoldMS || entry.MaxHoldMS > capturePlanMaxHoldMS {
			return nil, fmt.Errorf("capture hold at checkpoint %d must be in %d..%d ms", entry.Checkpoint, capturePlanMinHoldMS, capturePlanMaxHoldMS)
		}
		previous = entry.Checkpoint
	}
	length := capturePlanHeaderLen + len(entries)*capturePlanEntryLen + capturePlanCRCLen
	encoded := make([]byte, length)
	copy(encoded[:4], "JTCP")
	binary.LittleEndian.PutUint16(encoded[4:6], capturePlanVersion)
	binary.LittleEndian.PutUint16(encoded[6:8], uint16(len(entries)))
	binary.LittleEndian.PutUint32(encoded[8:12], cab.payloadCRC32)
	binary.LittleEndian.PutUint32(encoded[12:16], cab.totalFrames)
	for index, entry := range entries {
		offset := capturePlanHeaderLen + index*capturePlanEntryLen
		binary.LittleEndian.PutUint32(encoded[offset:offset+4], entry.Checkpoint)
		binary.LittleEndian.PutUint32(encoded[offset+4:offset+8], entry.MaxHoldMS)
	}
	checksum := crc32.ChecksumIEEE(encoded[:length-capturePlanCRCLen])
	binary.LittleEndian.PutUint32(encoded[length-capturePlanCRCLen:], checksum)
	return encoded, nil
}

type packedCABHeader struct {
	version      uint32
	totalFrames  uint32
	payloadCRC32 uint32
}

func inspectPackedCAB(data []byte) (packedCABHeader, error) {
	var header packedCABHeader
	if len(data) < misterCABHeaderLen || len(data) > misterCABMaxBytes {
		return header, fmt.Errorf("packed CAB size must be in %d..%d bytes", misterCABHeaderLen, misterCABMaxBytes)
	}
	var recordBytes uint32
	switch string(data[:8]) {
	case "JTCAB01\x00":
		header.version, recordBytes = 1, 8
	case "JTCAB02\x00":
		header.version, recordBytes = 2, 12
	default:
		return header, fmt.Errorf("packed CAB magic must be JTCAB01 or JTCAB02")
	}
	if binary.LittleEndian.Uint32(data[8:12]) != header.version ||
		binary.LittleEndian.Uint32(data[28:32]) != misterCABHeaderLen {
		return header, fmt.Errorf("packed CAB version or header length is invalid")
	}
	header.totalFrames = binary.LittleEndian.Uint32(data[12:16])
	if header.totalFrames == 0 || header.totalFrames > misterCABMaxFrames {
		return header, fmt.Errorf("packed CAB frame budget must be in 1..%d", misterCABMaxFrames)
	}
	count := binary.LittleEndian.Uint32(data[16:20])
	dumps := binary.LittleEndian.Uint32(data[20:24])
	header.payloadCRC32 = binary.LittleEndian.Uint32(data[24:28])
	if count == 0 || count > header.totalFrames || dumps != 0 || uint64(misterCABHeaderLen)+uint64(count)*uint64(recordBytes) != uint64(len(data)) {
		return header, fmt.Errorf("packed CAB record count, dumps or exact length is invalid")
	}
	if crc32.ChecksumIEEE(data[misterCABHeaderLen:]) != header.payloadCRC32 {
		return header, fmt.Errorf("packed CAB payload CRC mismatch")
	}
	var frameSum uint64
	for index := uint32(0); index < count; index++ {
		offset := misterCABHeaderLen + int(index)*int(recordBytes)
		duration := binary.LittleEndian.Uint32(data[offset : offset+4])
		inputs := binary.LittleEndian.Uint32(data[offset+4 : offset+8])
		if duration == 0 {
			return header, fmt.Errorf("packed CAB contains a zero-duration event")
		}
		if header.version == 1 && inputs&^uint32(0x001fffff) != 0 {
			return header, fmt.Errorf("JTCAB01 event contains unsupported input bits")
		}
		if header.version == 2 && inputs&uint32(0xffc00000) != 0 {
			return header, fmt.Errorf("JTCAB02 event contains unsupported flags/input bits")
		}
		frameSum += uint64(duration)
		if frameSum > uint64(header.totalFrames) {
			return header, fmt.Errorf("packed CAB event durations exceed the frame budget")
		}
	}
	if frameSum != uint64(header.totalFrames) {
		return header, fmt.Errorf("packed CAB event durations do not match the frame budget")
	}
	return header, nil
}
