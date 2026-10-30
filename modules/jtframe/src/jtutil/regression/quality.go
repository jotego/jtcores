/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"bytes"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
)

var ocrErrorWord = regexp.MustCompile(`(?i)\bERROR\b`)

// Only post-startup checkpoints participate: boot screens do not prove that
// a game is running, and a single frame cannot establish a static sequence.
func captureQualityFailure(set CaptureSet, startup int) (string, error) {
	failure, ocrFailure, _, err := captureQuality(set, startup)
	if failure == "" {
		failure = ocrFailure
	}
	return failure, err
}

func captureQuality(set CaptureSet, startup int) (string, string, string, error) {
	ocrAvailable := true
	if _, err := exec.LookPath("tesseract"); err != nil {
		ocrAvailable = false
	}
	frames := comparable_captures(set, startup)
	allBlack, identical := true, true
	var first []uint32
	ocrFailure := ""
	for i, frame := range frames {
		decoded, err := decode_capture_image(filepath.Join(set.Dir, frame.Image))
		if err != nil {
			return "", "", "", err
		}
		frameBlack := true
		for _, pixel := range decoded.pixels {
			if pixel != 0 {
				allBlack = false
				frameBlack = false
				break
			}
		}
		if i == 0 {
			first = decoded.pixels
		} else if !slices.Equal(first, decoded.pixels) {
			identical = false
		}
		if ocrAvailable && !frameBlack && ocrFailure == "" {
			text, err := recognize_capture_text(decoded)
			if err != nil {
				return "", "", "", fmt.Errorf("OCR frame %d: %w", frame.Requested, err)
			}
			if ocrErrorWord.MatchString(text) {
				text = strings.Join(strings.Fields(text), " ")
				if len(text) > 160 {
					text = text[:160] + "..."
				}
				ocrFailure = fmt.Sprintf("OCR recognized ERROR in frame %d: %q", frame.Requested, text)
			}
		}
	}
	warning := qualityOCRWarning(ocrAvailable)
	if len(frames) > 0 && allBlack {
		return fmt.Sprintf("all %d post-start-up captures are black", len(frames)), ocrFailure, warning, nil
	}
	if len(frames) >= 2 && identical {
		return fmt.Sprintf("all %d post-start-up captures are pixel-identical", len(frames)), ocrFailure, warning, nil
	}
	return "", ocrFailure, warning, nil
}

func qualityOCRWarning(available bool) string {
	if available {
		return ""
	}
	return "tesseract OCR is unavailable; skipped ERROR text detection"
}

func recognize_capture_text(decoded decodedImage) (string, error) {
	frame := image.NewRGBA(image.Rect(0, 0, decoded.width, decoded.height))
	for i, pixel := range decoded.pixels {
		frame.SetRGBA(i%decoded.width, i/decoded.width, color.RGBA{uint8(pixel >> 16), uint8(pixel >> 8), uint8(pixel), 255})
	}
	var input bytes.Buffer
	if err := png.Encode(&input, frame); err != nil {
		return "", err
	}
	command := exec.Command("tesseract", "stdin", "stdout", "--psm", "11")
	command.Stdin = &input
	var output, diagnostic bytes.Buffer
	command.Stdout = &output
	command.Stderr = &diagnostic
	if err := command.Run(); err != nil {
		if diagnostic.Len() > 0 {
			return "", fmt.Errorf("tesseract failed: %w: %s", err, strings.TrimSpace(diagnostic.String()))
		}
		return "", fmt.Errorf("tesseract failed: %w", err)
	}
	return output.String(), nil
}

// Clear only selected-game result slots, including interrupted replacements;
// stale recovery files must not revive images from an earlier attempt.
func clearResultSlot(gameRoot, slot string) error {
	for _, suffix := range []string{"", ".old", ".staging"} {
		if err := os.RemoveAll(filepath.Join(gameRoot, slot) + suffix); err != nil {
			return err
		}
	}
	return nil
}
func clearResultSlots(gameRoot string) error {
	for _, slot := range []string{"new", "fail"} {
		if err := clearResultSlot(gameRoot, slot); err != nil {
			return err
		}
	}
	return nil
}
