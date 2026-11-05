/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"context"
	"encoding/binary"
	"fmt"
	"hash/crc32"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

const mameCabHeaderBytes = 32
const mameCabMaxBytes = 64 << 20

type MameCabRun struct {
	Frames   uint32
	Inputs   uint32
	DIPSW    uint32
	HasDIPSW bool
	Dump     bool
}

type MameCabScript struct {
	Version uint32
	Frames  uint32
	Runs    []MameCabRun
}

// ReadMameCab reads the CAB exporter format without expanding repeated frames.
func ReadMameCab(filename string, expectedFrames int) (MameCabScript, error) {
	var script MameCabScript
	file, err := os.Open(filename)
	if err != nil {
		return script, err
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil {
		return script, err
	}
	if !info.Mode().IsRegular() || info.Size() < mameCabHeaderBytes || info.Size() > mameCabMaxBytes {
		return script, fmt.Errorf("invalid CAB export size %d", info.Size())
	}
	data := make([]byte, info.Size())
	if _, err = io.ReadFull(file, data); err != nil {
		return script, err
	}
	magicVersion := map[string]uint32{"JTCAB01\x00": 1, "JTCAB02\x00": 2, "JTCAB03\x00": 3}
	version, ok := magicVersion[string(data[:8])]
	if !ok {
		return script, fmt.Errorf("invalid CAB export magic")
	}
	read32 := func(offset int) uint32 { return binary.LittleEndian.Uint32(data[offset : offset+4]) }
	if read32(8) != version || read32(28) != mameCabHeaderBytes {
		return script, fmt.Errorf("unsupported CAB export header")
	}
	frames, count, dumps, checksum := read32(12), read32(16), read32(20), read32(24)
	if expectedFrames <= 0 || uint64(frames) != uint64(expectedFrames) {
		return script, fmt.Errorf("CAB export frame budget %d does not match profile video %d", frames, expectedFrames)
	}
	stride := 8
	if version > 1 {
		stride = 12
	}
	if count == 0 || uint64(mameCabHeaderBytes)+uint64(count)*uint64(stride) != uint64(len(data)) {
		return script, fmt.Errorf("invalid CAB export record count")
	}
	if crc32.ChecksumIEEE(data[mameCabHeaderBytes:]) != checksum {
		return script, fmt.Errorf("CAB export CRC mismatch")
	}
	script = MameCabScript{Version: version, Frames: frames, Runs: make([]MameCabRun, 0, count)}
	var total, dumpTotal uint64
	for i := uint32(0); i < count; i++ {
		offset := mameCabHeaderBytes + int(i)*stride
		duration, encoded := read32(offset), read32(offset+4)
		if duration == 0 || encoded&^uint32(0x007fffff) != 0 {
			return MameCabScript{}, fmt.Errorf("invalid CAB export record %d", i)
		}
		hasDIPSW, dump := encoded&0x00200000 != 0, encoded&0x00400000 != 0
		inputs := encoded & 0x001fffff
		if version == 1 && hasDIPSW || version < 3 && dump {
			return MameCabScript{}, fmt.Errorf("CAB export record %d uses a feature absent from version %d", i, version)
		}
		dipsw := uint32(0)
		if version > 1 {
			dipsw = read32(offset + 8)
		}
		script.Runs = append(script.Runs, MameCabRun{Frames: duration, Inputs: inputs, DIPSW: dipsw, HasDIPSW: hasDIPSW, Dump: dump})
		total += uint64(duration)
		if dump {
			dumpTotal += uint64(duration)
		}
	}
	if total != uint64(frames) || dumpTotal != uint64(dumps) {
		return MameCabScript{}, fmt.Errorf("CAB export run totals do not match header")
	}
	return script, nil
}

func prepare_mame_cab(ctx context.Context, candidate mame_candidate, packer, work string) (MameCabScript, error) {
	profile := candidate.profile
	var script MameCabScript
	if profile.Video <= 0 {
		return script, fmt.Errorf("profile video frame count must be positive")
	}
	if profile.Video > 0x7fffffff {
		return script, fmt.Errorf("profile video frame count exceeds CAB exporter limit")
	}
	for key := range profile.Options {
		if key != "dipsw" {
			return script, fmt.Errorf("unsupported regression profile option %q", key)
		}
	}
	if candidate.cab_source == "" {
		if _, has_dipsw := profile.Options["dipsw"]; !has_dipsw {
			return MameCabScript{Version: 1, Frames: uint32(profile.Video), Runs: []MameCabRun{{Frames: uint32(profile.Video)}}}, nil
		}
	}
	if packer == "" {
		return script, fmt.Errorf("CAB exporter is unavailable for selected inputs")
	}
	input_path := filepath.Join(work, "profile-inputs.cab")
	output_path := filepath.Join(work, "profile-inputs.jtcab")
	input := fmt.Sprintf("%d\n", profile.Video)
	if candidate.cab_source != "" {
		digest, err := file_sha256(candidate.cab_source)
		if err != nil || digest != candidate.cab_digest {
			return script, fmt.Errorf("selected CAB input changed after profile resolution")
		}
		data, err := os.ReadFile(candidate.cab_source)
		if err != nil {
			return script, fmt.Errorf("read selected CAB %s: %w", candidate.cab_source, err)
		}
		input = string(data)
	}
	if raw, ok := profile.Options["dipsw"]; ok {
		value := strings.TrimPrefix(strings.ToLower(fmt.Sprint(raw)), "0x")
		dipsw, err := strconv.ParseUint(value, 16, 32)
		if err != nil {
			return script, fmt.Errorf("profile dipsw must be a hexadecimal 32-bit value")
		}
		input = fmt.Sprintf("dipsw=%x\n", dipsw) + input
	}
	if err := os.WriteFile(input_path, []byte(input), 0600); err != nil {
		return script, err
	}
	command := exec.CommandContext(ctx, packer, input_path, output_path, "--frame-budget", strconv.Itoa(profile.Video))
	if output, err := command.CombinedOutput(); err != nil {
		return script, fmt.Errorf("export selected CAB inputs: %w: %s", err, strings.TrimSpace(string(output)))
	}
	script, err := ReadMameCab(output_path, profile.Video)
	if err != nil {
		return script, err
	}
	for _, run := range script.Runs {
		if run.Dump {
			return MameCabScript{}, fmt.Errorf("CAB dump actions are unsupported by MAME frame validation")
		}
		if run.HasDIPSW {
			return MameCabScript{}, fmt.Errorf("CAB DIP switch actions are not mapped for MAME frame validation")
		}
		if run.Inputs&0x001000 != 0 {
			return MameCabScript{}, fmt.Errorf("CAB reset actions are not mapped for MAME frame validation")
		}
	}
	return script, nil
}

func build_mame_cab_packer(ctx context.Context, source string) (string, error) {
	frame := filepath.Join(source, "modules", "jtframe")
	wrapper := filepath.Join(frame, "bin", "jtframe-cab-pack")
	packer := filepath.Join(frame, "bin", "cabinet_pack")
	build_ctx, cancel := context.WithTimeout(ctx, 2*time.Minute)
	defer cancel()
	command := exec.CommandContext(build_ctx, wrapper, "--build")
	command.Env = append(os.Environ(), "JTFRAME="+frame)
	output, err := command.CombinedOutput()
	if build_ctx.Err() == context.DeadlineExceeded {
		return "", fmt.Errorf("build CAB exporter timed out after 2m: %s", strings.TrimSpace(string(output)))
	}
	if err != nil {
		return "", fmt.Errorf("build CAB exporter: %w: %s", err, strings.TrimSpace(string(output)))
	}
	info, err := os.Stat(packer)
	if err != nil || !info.Mode().IsRegular() || info.Mode()&0111 == 0 {
		return "", fmt.Errorf("CAB exporter is unavailable or not executable: %s", packer)
	}
	return packer, nil
}
