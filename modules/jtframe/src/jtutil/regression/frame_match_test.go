/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"image"
	"image/color"
	"os"
	"testing"
	"time"
)

func TestMatchFramesOrderedUsesDistinctAscendingMatches(t *testing.T) {
	black := signature_test_frame(t, 0, color.RGBA{A: 255})
	white := signature_test_frame(t, 0, color.RGBA{R: 255, G: 255, B: 255, A: 255})
	got, err := MatchFramesOrdered([]FrameSignature{black, white, black}, []FrameSignature{
		with_frame(black, 10), with_frame(white, 20), with_frame(black, 30),
	})
	if err != nil {
		t.Fatal(err)
	}
	want := []int{10, 20, 30}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("match %d = %d, want %d", i, got[i], want[i])
		}
	}
}

func TestMatchFramesOrderedRejectsReuseAndGeometryMismatch(t *testing.T) {
	black := signature_test_frame(t, 0, color.RGBA{A: 255})
	if _, err := MatchFramesOrdered([]FrameSignature{black, black}, []FrameSignature{with_frame(black, 5)}); err == nil {
		t.Fatal("one MAME frame was reused for two FPGA frames")
	}
	wider := signature_test_frame_size(t, 0, 2, 1, color.RGBA{A: 255})
	if _, err := MatchFramesOrdered([]FrameSignature{black}, []FrameSignature{with_frame(wider, 5)}); err == nil {
		t.Fatal("different image geometry matched")
	}
}

func TestSignatureImageUsesDecodedPixelsAndGeometry(t *testing.T) {
	first := image.NewNRGBA(image.Rect(0, 0, 2, 1))
	first.Set(0, 0, color.NRGBA{R: 10, G: 20, B: 30, A: 255})
	first.Set(1, 0, color.NRGBA{R: 40, G: 50, B: 60, A: 255})
	second := image.NewRGBA(image.Rect(0, 0, 2, 1))
	second.Set(0, 0, color.RGBA{R: 10, G: 20, B: 30, A: 255})
	second.Set(1, 0, color.RGBA{R: 40, G: 50, B: 60, A: 255})
	a, err := SignatureImage(1, first)
	if err != nil {
		t.Fatal(err)
	}
	b, err := SignatureImage(2, second)
	if err != nil {
		t.Fatal(err)
	}
	if a.Pixels != b.Pixels {
		t.Fatal("equal decoded pixels produced different signatures")
	}
	b.Height = 2
	if _, err = MatchFramesOrdered([]FrameSignature{a}, []FrameSignature{b}); err == nil {
		t.Fatal("different geometry matched")
	}
}

func TestCapturePrecisionRGB555QuantizesMAMEButChecksFPGAExpansion(t *testing.T) {
	fpga := image.NewRGBA(image.Rect(0, 0, 3, 1))
	mame := image.NewRGBA(image.Rect(0, 0, 3, 1))
	fpga.SetRGBA(0, 0, color.RGBA{R: 123, G: 74, B: 181, A: 255})
	mame.SetRGBA(0, 0, color.RGBA{R: 124, G: 75, B: 180, A: 255})
	fpga.SetRGBA(1, 0, color.RGBA{R: 132, G: 41, B: 222, A: 255})
	mame.SetRGBA(1, 0, color.RGBA{R: 131, G: 40, B: 221, A: 255})
	fpga.SetRGBA(2, 0, color.RGBA{R: 0, G: 255, B: 57, A: 255})
	mame.SetRGBA(2, 0, color.RGBA{R: 1, G: 254, B: 58, A: 255})
	left, err := SignatureImageAtCapturePrecision(100, fpga, 5, true)
	if err != nil {
		t.Fatalf("valid FPGA RGB555 capture rejected: %v", err)
	}
	right, err := SignatureImageAtCapturePrecision(1, mame, 5, false)
	if err != nil {
		t.Fatal(err)
	}
	if left.Pixels != right.Pixels || !ImagesEqualAtCapturePrecision(fpga, mame, 5) {
		t.Fatal("MAME +/-1 RGB values that quantize to the same RGB555 codes did not match")
	}
	mame.SetRGBA(1, 0, color.RGBA{R: 140, G: 40, B: 221, A: 255})
	right, err = SignatureImageAtCapturePrecision(2, mame, 5, false)
	if err != nil {
		t.Fatal(err)
	}
	if left.Pixels == right.Pixels || ImagesEqualAtCapturePrecision(fpga, mame, 5) {
		t.Fatal("one RGB555 code difference at one pixel was accepted")
	}
}

func TestCapturePrecisionRGB444AndRejectsInvalidFPGAExpansion(t *testing.T) {
	fpga := image.NewRGBA(image.Rect(0, 0, 1, 1))
	mame := image.NewRGBA(image.Rect(0, 0, 1, 1))
	fpga.SetRGBA(0, 0, color.RGBA{R: 119, G: 34, B: 204, A: 255})
	mame.SetRGBA(0, 0, color.RGBA{R: 120, G: 35, B: 203, A: 255})
	left, err := SignatureImageAtCapturePrecision(100, fpga, 4, true)
	if err != nil {
		t.Fatalf("valid FPGA RGB444 capture rejected: %v", err)
	}
	right, err := SignatureImageAtCapturePrecision(1, mame, 4, false)
	if err != nil {
		t.Fatal(err)
	}
	if left.Pixels != right.Pixels || !ImagesEqualAtCapturePrecision(fpga, mame, 4) {
		t.Fatal("MAME values that quantize to the same RGB444 codes did not match")
	}
	fpga.SetRGBA(0, 0, color.RGBA{R: 118, G: 34, B: 204, A: 255})
	if _, err = SignatureImageAtCapturePrecision(100, fpga, 4, true); err == nil {
		t.Fatal("off-grid FPGA RGB444 capture was accepted")
	}
}

func TestCapturePrecisionUsesWireTruncationAtCodeBoundaries(t *testing.T) {
	for _, tc := range []struct {
		value uint8
		bits  int
		want  uint8
	}{{7, 5, 0}, {8, 5, 1}, {15, 4, 0}, {16, 4, 1}} {
		if got := quantizeCaptureChannel(tc.value, tc.bits); got != tc.want {
			t.Errorf("quantizeCaptureChannel(%d,%d) = %d, want %d", tc.value, tc.bits, got, tc.want)
		}
	}
}

func TestMameCapturePrecisionUsesSidi128CoreMacros(t *testing.T) {
	root := os.Getenv("JTROOT")
	for _, tc := range []struct {
		core string
		want int
	}{{"gng", 4}, {"s16", 5}, {"ajax", 5}} {
		got, err := mame_capture_precision(root, tc.core)
		if err != nil || got != tc.want {
			t.Errorf("%s capture precision = %d, %v; want %d", tc.core, got, err, tc.want)
		}
	}
}

func TestMameFrameTimeoutUsesRefreshRate(t *testing.T) {
	if got, want := MameFrameTimeout(4500, 50), 99*time.Second; got != want {
		t.Fatalf("timeout = %s, want %s", got, want)
	}
	if MameFrameTimeout(0, 60) != 0 || MameFrameTimeout(100, 0) != 0 {
		t.Fatal("invalid timeout inputs should return zero")
	}
}

func signature_test_frame(t *testing.T, frame int, value color.RGBA) FrameSignature {
	return signature_test_frame_size(t, frame, 1, 1, value)
}

func signature_test_frame_size(t *testing.T, frame, width, height int, value color.RGBA) FrameSignature {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, width, height))
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			img.SetRGBA(x, y, value)
		}
	}
	signature, err := SignatureImage(frame, img)
	if err != nil {
		t.Fatal(err)
	}
	return signature
}

func with_frame(signature FrameSignature, frame int) FrameSignature {
	signature.Frame = frame
	return signature
}
