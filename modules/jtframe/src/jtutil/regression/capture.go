/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"bufio"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type CaptureRecord struct {
	Type      string `json:"type"`
	Requested int    `json:"requested"`
	Actual    int    `json:"actual"`
	Image     string `json:"image"`
}

type CaptureSet struct {
	Dir      string          `json:"dir"`
	Captures []CaptureRecord `json:"captures"`
	Width    int             `json:"width"`
	Height   int             `json:"height"`
	Format   string          `json:"format"`
}

type FrameDiff struct {
	Frame      int `json:"frame"`
	Different  int `json:"different_pixels"`
	FirstPixel int `json:"first_pixel"`
	Width      int `json:"width"`
	Height     int `json:"height"`
}

func json_number(value interface{}) (int, bool) {
	n, ok := value.(float64)
	if !ok || n != float64(int(n)) {
		return 0, false
	}
	return int(n), true
}

// ReadCaptureSet validates the firmware recording index and each referenced RAW.
func ReadCaptureSet(dir string, expectedFrames, startup, cadence int) (CaptureSet, error) {
	set := CaptureSet{Dir: dir}
	file, e := os.Open(filepath.Join(dir, "index.jsonl"))
	if e != nil {
		return set, e
	}
	defer file.Close()
	var captures []CaptureRecord
	complete := false
	started := false
	declaredCount, declaredWidth, declaredHeight, completeCount := 0, 0, 0, -1
	hasMeaningful := false
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 4096), 1<<20)
	for scanner.Scan() {
		var raw map[string]interface{}
		if e = json.Unmarshal(scanner.Bytes(), &raw); e != nil {
			return set, fmt.Errorf("invalid capture index JSON: %w", e)
		}
		typeName, _ := raw["type"].(string)
		if complete {
			return set, fmt.Errorf("capture index contains data after complete marker")
		}
		if !started {
			if typeName != "run" {
				return set, fmt.Errorf("capture index must begin with run metadata")
			}
			started = true
			declaredCount, _ = json_number(raw["count"])
			declaredWidth, _ = json_number(raw["width"])
			declaredHeight, _ = json_number(raw["height"])
			if declaredCount < 1 || declaredWidth < 1 || declaredHeight < 1 || declaredWidth > 512 || declaredHeight > 512 {
				return set, fmt.Errorf("capture run metadata has invalid count or geometry")
			}
			continue
		}
		if typeName == "capture" {
			var record CaptureRecord
			if e = json.Unmarshal(scanner.Bytes(), &record); e != nil {
				return set, e
			}
			captures = append(captures, record)
		} else if typeName == "complete" {
			completeCount, _ = json_number(raw["captures"])
			complete = true
		} else {
			return set, fmt.Errorf("unknown capture index record type %q", typeName)
		}
	}
	if e = scanner.Err(); e != nil {
		return set, e
	}
	if !complete || !started {
		return set, fmt.Errorf("capture set %s has no complete marker", dir)
	}
	if cadence <= 0 || expectedFrames <= 0 {
		return set, fmt.Errorf("invalid expected capture schedule")
	}
	wantCount := expectedFrames / cadence
	if wantCount == 0 {
		return set, fmt.Errorf("video duration %d has no %d-frame checkpoints", expectedFrames, cadence)
	}
	if len(captures) != wantCount {
		return set, fmt.Errorf("capture set has %d checkpoints; want %d", len(captures), wantCount)
	}
	if declaredCount != wantCount || completeCount != wantCount {
		return set, fmt.Errorf("capture index declares %d/%d checkpoints; want %d", declaredCount, completeCount, wantCount)
	}
	seen := make(map[int]bool)
	for _, capture := range captures {
		if capture.Requested < cadence || capture.Requested > expectedFrames || capture.Requested%cadence != 0 || seen[capture.Requested] {
			return set, fmt.Errorf("invalid or duplicate requested checkpoint %d", capture.Requested)
		}
		seen[capture.Requested] = true
		if capture.Actual < 1 {
			return set, fmt.Errorf("checkpoint requested at %d has invalid actual frame %d", capture.Requested, capture.Actual)
		}
		if capture.Requested > startup && capture.Actual != capture.Requested {
			return set, fmt.Errorf("checkpoint requested at %d arrived at frame %d", capture.Requested, capture.Actual)
		}
		if !safe_capture_name(capture.Image) {
			return set, fmt.Errorf("unsafe capture image name %q", capture.Image)
		}
		image, e := decode_raw(filepath.Join(dir, capture.Image))
		if e != nil {
			return set, fmt.Errorf("frame %d: %w", capture.Requested, e)
		}
		if set.Width == 0 {
			set.Width, set.Height, set.Format = image.width, image.height, image.format
		}
		if image.width != declaredWidth || image.height != declaredHeight {
			return set, fmt.Errorf("frame %d geometry differs from run metadata", capture.Requested)
		}
		if image.width != set.Width || image.height != set.Height || image.format != set.Format {
			return set, fmt.Errorf("frame %d geometry or pixel format changed", capture.Requested)
		}
		if capture.Requested > startup && image.meaningful {
			hasMeaningful = true
		}
	}
	if !hasMeaningful {
		return set, fmt.Errorf("capture set has no meaningful comparable frames after start-up frame %d", startup)
	}
	set.Captures = captures
	sort.Slice(set.Captures, func(i, j int) bool { return set.Captures[i].Requested < set.Captures[j].Requested })
	return set, nil
}

func safe_capture_name(name string) bool {
	return name != "" && filepath.Base(name) == name && strings.HasPrefix(name, "frame_") && strings.HasSuffix(name, ".raw")
}

type decodedImage struct {
	width, height int
	format        string
	pixels        []uint16
	meaningful    bool
}

func decode_raw(filename string) (decodedImage, error) {
	image := decodedImage{}
	data, e := os.ReadFile(filename)
	if e != nil {
		return image, e
	}
	if len(data) < 4 {
		return image, fmt.Errorf("truncated geometry header")
	}
	taggedWidth := binary.LittleEndian.Uint16(data)
	image.width = int(taggedWidth & 0x7fff)
	image.height = int(binary.LittleEndian.Uint16(data[2:]))
	rgb555 := taggedWidth&0x8000 != 0
	if image.width < 1 || image.width > 512 || image.height < 1 || image.height > 512 {
		return image, fmt.Errorf("invalid image geometry %dx%d", image.width, image.height)
	}
	if rgb555 {
		image.format = "rgb555"
	} else {
		image.format = "rgb444"
	}
	stride := (image.width*3 + 1) / 2
	if rgb555 {
		stride = image.width * 2
	}
	if len(data) != 4+stride*image.height {
		return image, fmt.Errorf("pixel data length is %d; want %d", len(data)-4, stride*image.height)
	}
	image.pixels = make([]uint16, image.width*image.height)
	for y := 0; y < image.height; y++ {
		row := data[4+y*stride : 4+(y+1)*stride]
		if rgb555 {
			for x := 0; x < image.width; x++ {
				pixel := binary.LittleEndian.Uint16(row[x*2:])
				if pixel&0x8000 != 0 {
					return image, fmt.Errorf("reserved RGB555 bit set at (%d,%d)", x, y)
				}
				image.pixels[y*image.width+x] = pixel
				if x+y > 0 && image.pixels[y*image.width+x] != image.pixels[0] {
					image.meaningful = true
				}
			}
		} else {
			if image.width%2 != 0 && row[len(row)-1]&15 != 0 {
				return image, fmt.Errorf("nonzero RGB444 odd-width padding at row %d", y)
			}
			for x := 0; x < image.width; x++ {
				at := x * 3 / 2
				pixel := uint16(row[at])<<8 | uint16(row[at+1])
				if x%2 == 0 {
					pixel >>= 4
				} else {
					pixel &= 0x0fff
				}
				image.pixels[y*image.width+x] = pixel
				if x+y > 0 && image.pixels[y*image.width+x] != image.pixels[0] {
					image.meaningful = true
				}
			}
		}
	}
	return image, nil
}

// CompareCaptureSets compares exact native pixels at complete comparable checkpoints.
func CompareCaptureSets(reference, candidate CaptureSet, startup int) ([]FrameDiff, error) {
	if reference.Width != candidate.Width || reference.Height != candidate.Height || reference.Format != candidate.Format {
		return nil, fmt.Errorf("reference and candidate geometry or pixel format differ")
	}
	refs := comparable_captures(reference, startup)
	candidates := comparable_captures(candidate, startup)
	if len(refs) == 0 || len(refs) != len(candidates) {
		return nil, fmt.Errorf("reference and candidate comparable checkpoint sets differ")
	}
	diffs := make([]FrameDiff, 0)
	for i, ref := range refs {
		got := candidates[i]
		if ref.Requested != got.Requested || ref.Actual != got.Actual {
			return nil, fmt.Errorf("reference/candidate checkpoint identities differ")
		}
		refImage, e := decode_raw(filepath.Join(reference.Dir, ref.Image))
		if e != nil {
			return nil, e
		}
		gotImage, e := decode_raw(filepath.Join(candidate.Dir, got.Image))
		if e != nil {
			return nil, e
		}
		diff := FrameDiff{Frame: ref.Requested, FirstPixel: -1, Width: reference.Width, Height: reference.Height}
		for pixel := range refImage.pixels {
			if refImage.pixels[pixel] != gotImage.pixels[pixel] {
				diff.Different++
				if diff.FirstPixel < 0 {
					diff.FirstPixel = pixel
				}
			}
		}
		if diff.Different > 0 {
			diffs = append(diffs, diff)
		}
	}
	return diffs, nil
}

func comparable_captures(set CaptureSet, startup int) []CaptureRecord {
	frames := make([]CaptureRecord, 0, len(set.Captures))
	for _, capture := range set.Captures {
		if capture.Requested > startup {
			frames = append(frames, capture)
		}
	}
	return frames
}
