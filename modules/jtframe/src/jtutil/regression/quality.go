/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"fmt"
	"os"
	"path/filepath"
	"slices"
)

// Only post-startup checkpoints participate: boot screens do not prove that
// a game is running, and a single frame cannot establish a static sequence.
func captureQualityFailure(set CaptureSet, startup int) (string, error) {
	frames := comparable_captures(set, startup)
	allBlack, identical := true, true
	var first []uint32
	for i, frame := range frames {
		decoded, err := decode_capture_image(filepath.Join(set.Dir, frame.Image))
		if err != nil {
			return "", err
		}
		for _, pixel := range decoded.pixels {
			if pixel != 0 {
				allBlack = false
				break
			}
		}
		if i == 0 {
			first = decoded.pixels
		} else if !slices.Equal(first, decoded.pixels) {
			identical = false
		}
	}
	if len(frames) > 0 && allBlack {
		return fmt.Sprintf("all %d post-start-up captures are black", len(frames)), nil
	}
	if len(frames) >= 2 && identical {
		return fmt.Sprintf("all %d post-start-up captures are pixel-identical", len(frames)), nil
	}
	return "", nil
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
