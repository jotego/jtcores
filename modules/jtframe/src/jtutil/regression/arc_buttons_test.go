/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func Test_normalize_arc_buttons(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		want    string
		changed bool
	}{
		{
			name:    "framework tail",
			input:   "[ARC]\nNAME=MVSC\nBUTTONS=\"Punch,Start,Coin,Core credits,Test,Service\"\nOTHER=unchanged\n",
			want:    "[ARC]\nNAME=MVSC\nBUTTONS=\"Punch,Start,Coin,Core credits\"\nOTHER=unchanged\n",
			changed: true,
		},
		{
			name:    "CRLF and preserve unrelated fields",
			input:   "[ARC]\r\nBUTTONS=\"Punch,Start,Coin,Core credits,Test,Service\"\r\nDEFAULT=\"A,Start,Select,L2,R2,L3\"\r\n",
			want:    "[ARC]\r\nBUTTONS=\"Punch,Start,Coin,Core credits\"\r\nDEFAULT=\"A,Start,Select,L2,R2,L3\"\r\n",
			changed: true,
		},
		{
			name:  "nonmatching tail",
			input: "BUTTONS=\"Punch,Start,Coin,Core credits,Test,Service,Extra\"\n",
			want:  "BUTTONS=\"Punch,Start,Coin,Core credits,Test,Service,Extra\"\n",
		},
		{
			name:  "unrelated labels",
			input: "BUTTONS=\"Action,Test,Service\"\n",
			want:  "BUTTONS=\"Action,Test,Service\"\n",
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got, changed := normalize_arc_buttons([]byte(test.input))
			if string(got) != test.want || changed != test.changed {
				t.Fatalf("normalize = (%q,%t), want (%q,%t)", got, changed, test.want, test.changed)
			}
			if !changed {
				return
			}
			got_again, changed_again := normalize_arc_buttons(got)
			if string(got_again) != test.want || changed_again {
				t.Fatalf("second normalization = (%q,%t), want unchanged", got_again, changed_again)
			}
		})
	}
}

func Test_normalize_arc_buttons_file_does_not_change_input_on_no_match(t *testing.T) {
	path := filepath.Join(t.TempDir(), "game.arc")
	original := []byte("BUTTONS=\"Action,Test,Service\"\n")
	if err := os.WriteFile(path, original, 0600); err != nil {
		t.Fatal(err)
	}
	if err := normalize_arc_buttons_file(path); err != nil {
		t.Fatal(err)
	}
	got, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != string(original) {
		t.Fatalf("file changed on nonmatch: %q", got)
	}
}

func Test_jtbin2sd_arc_edit_matches_regression_normalizer(t *testing.T) {
	_, test_file, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("cannot locate ARC normalizer test file")
	}
	script_path := filepath.Join(filepath.Dir(test_file), "..", "..", "..", "bin", "jtbin2sd")
	script, err := os.ReadFile(script_path)
	if err != nil {
		t.Fatal(err)
	}
	const command_prefix = "sed -E -i '"
	var expression string
	for _, line := range strings.Split(string(script), "\n") {
		start := strings.Index(line, command_prefix)
		if start < 0 {
			continue
		}
		start += len(command_prefix)
		end := strings.Index(line[start:], "'")
		if end < 0 {
			t.Fatalf("unterminated sed expression in %s", script_path)
		}
		expression = line[start : start+end]
		break
	}
	if expression == "" {
		t.Fatalf("missing ARC button suffix rule in %s", script_path)
	}
	for _, input := range []string{
		"[ARC]\r\nBUTTONS=\"Punch,Start,Coin,Core credits,Test,Service\"\r\nDEFAULT=\"A,Start,Select,L2,R2,L3\"\r\n",
		"BUTTONS=\"Punch,Start,Coin,Core credits,Test,Service,Extra\"\n",
		"BUTTONS=\"Action,Test,Service\"\n",
	} {
		path := filepath.Join(t.TempDir(), "fixture.arc")
		if err := os.WriteFile(path, []byte(input), 0600); err != nil {
			t.Fatal(err)
		}
		go_output, _ := normalize_arc_buttons([]byte(input))
		sed_output, err := exec.Command("sed", "-E", expression, path).Output()
		if err != nil {
			t.Fatal(err)
		}
		if string(sed_output) != string(go_output) {
			t.Fatalf("jtbin2sd sed output differs from Go normalizer:\nscript: %q\nGo: %q", sed_output, go_output)
		}
		if err := os.WriteFile(path, sed_output, 0600); err != nil {
			t.Fatal(err)
		}
		second, err := exec.Command("sed", "-E", expression, path).Output()
		if err != nil || string(second) != string(sed_output) {
			t.Fatalf("jtbin2sd edit is not idempotent: %q (%v)", second, err)
		}
	}
}
