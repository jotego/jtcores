/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"os"
	"strings"
)

const arc_framework_buttons_tail = `,Start,Coin,Core credits,Test,Service"`
const arc_legacy_buttons_tail = `,Start,Coin,Core credits"`

func normalize_arc_buttons_file(path string) error {
	arc, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	normalized, changed := normalize_arc_buttons(arc)
	if !changed {
		return nil
	}
	return os.WriteFile(path, normalized, 0)
}

func normalize_arc_buttons(arc []byte) ([]byte, bool) {
	lines := strings.SplitAfter(string(arc), "\n")
	changed := false
	for i, line := range lines {
		body := line
		ending := ""
		if strings.HasSuffix(body, "\n") {
			body = body[:len(body)-1]
			ending = "\n"
		}
		if strings.HasSuffix(body, "\r") {
			body = body[:len(body)-1]
			ending = "\r" + ending
		}
		if strings.HasPrefix(body, `BUTTONS="`) && strings.HasSuffix(body, arc_framework_buttons_tail) {
			body = strings.TrimSuffix(body, arc_framework_buttons_tail) + arc_legacy_buttons_tail
			lines[i] = body + ending
			changed = true
		}
	}
	return []byte(strings.Join(lines, "")), changed
}
