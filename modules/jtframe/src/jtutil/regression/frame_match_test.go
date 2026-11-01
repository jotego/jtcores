/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"image"
	"image/color"
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
