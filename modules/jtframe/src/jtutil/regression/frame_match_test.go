/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"fmt"
	"image"
	"image/color"
	"os"
	"path/filepath"
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
	a, err := SignatureImageAtCapturePrecision(1, first, 8)
	if err != nil {
		t.Fatal(err)
	}
	b, err := SignatureImageAtCapturePrecision(2, second, 8)
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

func TestCapturePrecisionRGB555IgnoresUncapturedLowBits(t *testing.T) {
	fpga := image.NewRGBA(image.Rect(0, 0, 3, 1))
	mame := image.NewRGBA(image.Rect(0, 0, 3, 1))
	fpga.SetRGBA(0, 0, color.RGBA{R: 123, G: 74, B: 181, A: 255})
	mame.SetRGBA(0, 0, color.RGBA{R: 124, G: 75, B: 180, A: 255})
	fpga.SetRGBA(1, 0, color.RGBA{R: 132, G: 41, B: 222, A: 255})
	mame.SetRGBA(1, 0, color.RGBA{R: 131, G: 40, B: 221, A: 255})
	fpga.SetRGBA(2, 0, color.RGBA{R: 0, G: 255, B: 57, A: 255})
	mame.SetRGBA(2, 0, color.RGBA{R: 1, G: 254, B: 58, A: 255})
	left, err := SignatureImageAtCapturePrecision(100, fpga, 5)
	if err != nil {
		t.Fatalf("valid FPGA RGB555 capture rejected: %v", err)
	}
	right, err := SignatureImageAtCapturePrecision(1, mame, 5)
	if err != nil {
		t.Fatal(err)
	}
	if left.Pixels != right.Pixels || !ImagesEqualAtCapturePrecision(fpga, mame, 5) {
		t.Fatal("MAME +/-1 RGB values that quantize to the same RGB555 codes did not match")
	}
	mame.SetRGBA(1, 0, color.RGBA{R: 140, G: 40, B: 221, A: 255})
	right, err = SignatureImageAtCapturePrecision(2, mame, 5)
	if err != nil {
		t.Fatal(err)
	}
	if left.Pixels == right.Pixels || ImagesEqualAtCapturePrecision(fpga, mame, 5) {
		t.Fatal("one RGB555 code difference at one pixel was accepted")
	}
}

func TestCapturePrecisionRGB444IgnoresUncapturedLowBits(t *testing.T) {
	fpga := image.NewRGBA(image.Rect(0, 0, 1, 1))
	mame := image.NewRGBA(image.Rect(0, 0, 1, 1))
	fpga.SetRGBA(0, 0, color.RGBA{R: 119, G: 34, B: 204, A: 255})
	mame.SetRGBA(0, 0, color.RGBA{R: 120, G: 35, B: 203, A: 255})
	left, err := SignatureImageAtCapturePrecision(100, fpga, 4)
	if err != nil {
		t.Fatalf("valid FPGA RGB444 capture rejected: %v", err)
	}
	right, err := SignatureImageAtCapturePrecision(1, mame, 4)
	if err != nil {
		t.Fatal(err)
	}
	if left.Pixels != right.Pixels || !ImagesEqualAtCapturePrecision(fpga, mame, 4) {
		t.Fatal("MAME values that quantize to the same RGB444 codes did not match")
	}
	fpga.SetRGBA(0, 0, color.RGBA{R: 118, G: 34, B: 204, A: 255})
	left2, err := SignatureImageAtCapturePrecision(100, fpga, 4)
	if err != nil || left2.Pixels != left.Pixels {
		t.Fatalf("RGB888 low-bit variation changed the native RGB444 code: %v", err)
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

// test_jtroot is $JTROOT or the checkout that holds this package
func test_jtroot(t *testing.T) string {
	root := os.Getenv("JTROOT")
	if root == "" {
		root, _ = filepath.Abs("../../../../..")
	}
	if _, e := os.Stat(filepath.Join(root, "cores", "gng", "cfg", "macros.def")); e != nil {
		t.Skip("no jtcores checkout:", e)
	}
	return root
}

func TestCoreColorwUsesMiSTerMacros(t *testing.T) {
	root := test_jtroot(t)
	for _, key := range []string{"JTROOT", "JTFRAME", "CORES", "MODULES"} {
		t.Setenv(key, os.Getenv(key))
	}
	for core, want := range map[string]int{"blkout": 4, "s16": 5, "shanon": 6, "ajax": 8} {
		if got, e := core_colorw(root, core); e != nil || got != want {
			t.Errorf("%s JTFRAME_COLORW = %d, %v; want %d", core, got, e, want)
		}
	}
	if _, e := core_colorw(root, "nosuchcore"); e == nil {
		t.Error("a missing core was accepted")
	}
}

func TestNativeColorPrecisionIgnoresOnlyUncapturedLowBits(t *testing.T) {
	for bits := 1; bits <= 8; bits++ {
		t.Run(fmt.Sprint(bits), func(t *testing.T) {
			max := uint8((1 << bits) - 1)
			base := color.RGBA{R: max << (8 - bits), G: (max / 2) << (8 - bits), B: 0x80, A: 255}
			mame := color.RGBA{R: base.R | lowBitMask(bits), G: base.G | lowBitMask(bits), B: base.B | lowBitMask(bits), A: 255}
			left := image.NewRGBA(image.Rect(0, 0, 2, 2))
			right := image.NewRGBA(image.Rect(0, 0, 2, 2))
			for y := 0; y < 2; y++ {
				for x := 0; x < 2; x++ {
					left.SetRGBA(x, y, base)
					right.SetRGBA(x, y, mame)
				}
			}
			a, err := SignatureImageAtCapturePrecision(1, left, bits)
			if err != nil { t.Fatal(err) }
			b, err := SignatureImageAtCapturePrecision(2, right, bits)
			if err != nil { t.Fatal(err) }
			if a.Pixels != b.Pixels || !ImagesEqualAtCapturePrecision(left, right, bits) {
				t.Fatal("differences confined to unrepresented RGB888 low bits did not match")
			}
			right.SetRGBA(0, 0, color.RGBA{R: base.R - uint8(1<<(8-bits)), G: base.G, B: base.B, A: 255})
			c, err := SignatureImageAtCapturePrecision(3, right, bits)
			if err != nil { t.Fatal(err) }
			if a.Pixels == c.Pixels || ImagesEqualAtCapturePrecision(left, right, bits) {
				t.Fatal("difference in a represented native color bit was accepted")
			}
		})
	}
	img := image.NewRGBA(image.Rect(0, 0, 1, 1))
	for _, bits := range []int{0, 9} {
		if _, err := SignatureImageAtCapturePrecision(1, img, bits); err == nil {
			t.Errorf("invalid native precision %d accepted", bits)
		}
		if ImagesEqualAtCapturePrecision(img, img, bits) {
			t.Errorf("invalid native precision %d compared equal", bits)
		}
	}
}

func lowBitMask(bits int) uint8 {
	if bits >= 8 { return 0 }
	return uint8((1 << (8-bits)) - 1)
}

func TestMameFrameTimeoutUsesRefreshRate(t *testing.T) {
	if got, want := MameFrameTimeout(4500, 50), 99*time.Second; got != want {
		t.Fatalf("timeout = %s, want %s", got, want)
	}
	if MameFrameTimeout(0, 60) != 0 || MameFrameTimeout(100, 0) != 0 {
		t.Fatal("invalid timeout inputs should return zero")
	}
	if got := MameFrameTimeout(17940, 60); got != 5*time.Minute {
		t.Fatalf("near-cap MAME wall timeout = %s, want 5m cap", got)
	}
}

func TestMameComparisonFrameLimitStaysInsideVisibleStartupBypass(t *testing.T) {
	for _, tc := range []struct {
		name       string
		checkpoint int
		rate       float64
		wantFrames int
		wantSecs   int
		wantErr    bool
	}{
		{name: "short capture retains search grace", checkpoint: 100, rate: 60, wantFrames: 600, wantSecs: 10},
		{name: "near five minute cap retains all frames", checkpoint: 17440, rate: 60, wantFrames: 17940, wantSecs: 299},
		{name: "over five minute cap fails instead of truncating", checkpoint: 17441, rate: 60, wantErr: true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			frames, seconds, err := mame_comparison_frame_limit(tc.checkpoint, tc.rate)
			if tc.wantErr {
				if err == nil { t.Fatalf("frame limit = %d for %d frames at %gHz; want error", frames, tc.checkpoint, tc.rate) }
				return
			}
			if err != nil || frames != tc.wantFrames || seconds != tc.wantSecs {
				t.Fatalf("frame limit = %d frames, %d seconds, %v; want %d frames, %d seconds", frames, seconds, err, tc.wantFrames, tc.wantSecs)
			}
		})
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
	signature, err := SignatureImageAtCapturePrecision(frame, img, 8)
	if err != nil {
		t.Fatal(err)
	}
	return signature
}

func with_frame(signature FrameSignature, frame int) FrameSignature {
	signature.Frame = frame
	return signature
}
