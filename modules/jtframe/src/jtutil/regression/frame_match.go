/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"crypto/sha256"
	"encoding/binary"
	"fmt"
	"image"
)

// FrameSignature is the geometry and decoded-pixel identity of one capture.
type FrameSignature struct {
	Frame  int
	Width  int
	Height int
	Pixels [32]byte
}

// SignatureImage hashes canonical decoded RGBA pixels, independent of PNG
// compression, palette representation, or row stride.
func SignatureImage(frame int, img image.Image) (FrameSignature, error) {
	bounds := img.Bounds()
	w, h := bounds.Dx(), bounds.Dy()
	if w <= 0 || h <= 0 {
		return FrameSignature{}, fmt.Errorf("invalid image dimensions %dx%d", w, h)
	}
	hash := sha256.New()
	var dimensions [8]byte
	binary.LittleEndian.PutUint32(dimensions[0:4], uint32(w))
	binary.LittleEndian.PutUint32(dimensions[4:8], uint32(h))
	_, _ = hash.Write(dimensions[:])
	var pixel [3]byte
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			r, g, b, a := img.At(x, y).RGBA()
			if a != 0xffff {
				return FrameSignature{}, fmt.Errorf("image contains non-opaque pixels")
			}
			pixel[0], pixel[1], pixel[2] = byte(r>>8), byte(g>>8), byte(b>>8)
			_, _ = hash.Write(pixel[:])
		}
	}
	var digest [32]byte
	copy(digest[:], hash.Sum(nil))
	return FrameSignature{Frame: frame, Width: w, Height: h, Pixels: digest}, nil
}

// ImagesEqualRGB confirms the full decoded pixels after a signature match.
func ImagesEqualRGB(left, right image.Image) bool {
	a, b := left.Bounds(), right.Bounds()
	if a.Dx() != b.Dx() || a.Dy() != b.Dy() {
		return false
	}
	for y := 0; y < a.Dy(); y++ {
		for x := 0; x < a.Dx(); x++ {
			lr, lg, lb, la := left.At(a.Min.X+x, a.Min.Y+y).RGBA()
			rr, rg, rb, ra := right.At(b.Min.X+x, b.Min.Y+y).RGBA()
			if la != 0xffff || ra != 0xffff || lr != rr || lg != rg || lb != rb {
				return false
			}
		}
	}
	return true
}

// MatchFramesOrdered maps each FPGA capture to the earliest later MAME frame
// with identical geometry and decoded pixels. Reusing a MAME frame is rejected.
func MatchFramesOrdered(reference, candidates []FrameSignature) ([]int, error) {
	by_signature := make(map[frameKey][]int)
	last_candidate := -1
	for _, candidate := range candidates {
		if candidate.Frame < 0 || candidate.Width <= 0 || candidate.Height <= 0 {
			return nil, fmt.Errorf("invalid MAME frame signature at frame %d", candidate.Frame)
		}
		if candidate.Frame <= last_candidate {
			return nil, fmt.Errorf("MAME frame numbers must be strictly increasing")
		}
		last_candidate = candidate.Frame
		key := frameKey{candidate.Width, candidate.Height, candidate.Pixels}
		by_signature[key] = append(by_signature[key], candidate.Frame)
	}
	matched := make([]int, 0, len(reference))
	last := -1
	for _, frame := range reference {
		key := frameKey{frame.Width, frame.Height, frame.Pixels}
		frames := by_signature[key]
		index := upper_frame(frames, last)
		if index == len(frames) {
			return nil, fmt.Errorf("no later MAME frame matches FPGA frame %d", frame.Frame)
		}
		last = frames[index]
		matched = append(matched, last)
	}
	return matched, nil
}

type frameKey struct {
	width, height int
	pixels        [32]byte
}

func upper_frame(frames []int, value int) int {
	lo, hi := 0, len(frames)
	for lo < hi {
		mid := lo + (hi-lo)/2
		if frames[mid] <= value {
			lo = mid + 1
		} else {
			hi = mid
		}
	}
	return lo
}
