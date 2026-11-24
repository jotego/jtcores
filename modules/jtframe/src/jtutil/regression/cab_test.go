/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"
)

const cab_vectors = "../../../verilator/tests/cabinet/vectors"

// TestCabVectors runs the golden vectors shared with verilator/cabinet.cpp
func TestCabVectors(t *testing.T) {
	cabs, e := filepath.Glob(filepath.Join(cab_vectors, "*.cab")); if e != nil { t.Fatal(e) }
	if len(cabs) < 20 { t.Fatalf("too few golden vectors in %s", cab_vectors) }
	for _, cab := range cabs {
		expected, e := os.ReadFile(strings.TrimSuffix(cab, ".cab") + ".expect"); if e != nil { t.Fatal(e) }
		if got := describe_cab(cab); got != string(expected) {
			t.Errorf("%s: expected\n%sgot\n%s", cab, expected, got)
		}
	}
}

func describe_cab(path string) string {
	script, e := ReadCab(path)
	if e != nil {
		var cab_error *CabError
		if errors.As(e, &cab_error) { return fmt.Sprintf("error %d\n", cab_error.Line) }
		return e.Error()
	}
	var out strings.Builder
	capture := "-"
	if script.HasCapture { capture = fmt.Sprint(script.Capture) }
	fmt.Fprintf(&out, "capture %s\nframes %d\n", capture, script.Lines)
	for _, run := range script.Runs {
		dipsw, flags, cheats := "-", []byte("--"), "-"
		if run.HasDIPSW { dipsw = fmt.Sprintf("%x", run.DIPSW) }
		if run.TracingOn { flags[0] = 't' }
		if run.Dump { flags[1] = 'd' }
		if len(run.Cheats) > 0 { cheats = strings.Join(run.Cheats, ",") }
		fmt.Fprintf(&out, "%d %x %s %s %s\n", run.Frames, run.Inputs, dipsw, flags, cheats)
	}
	return out.String()
}

func TestCabCaptureFrames(t *testing.T) {
	script, e := ParseCab(strings.NewReader("capture 500\n=4000\n")); if e != nil { t.Fatal(e) }
	frames := script.CaptureFrames()
	if script.LastFrame() != 4000 || len(frames) != 36 || frames[0] != 500 || frames[35] != 4000 {
		t.Errorf("unexpected capture schedule %v (last frame %d)", frames, script.LastFrame())
	}
	script, e = ParseCab(strings.NewReader("capture 1\n=150\n")); if e != nil { t.Fatal(e) }
	if got := fmt.Sprint(script.CaptureFrames()); got != "[1 101]" { t.Errorf("capture frames %s", got) }
	script, e = ParseCab(strings.NewReader("=10\n")); if e != nil { t.Fatal(e) }
	if script.CaptureFrames() != nil { t.Error("a script without capture has no capture frames") }
}

func TestCabLineLimit(t *testing.T) {
	cases := []struct {
		text string
		line int
	}{
		{"=32766\n", 0},
		{"loop\ncoin\n1\nrepeat 16383\ncoin\n", 0},
		{"=32767\n", 1},
		{"coin\n32767\n", 2},
		{"loop\ncoin\nrepeat 100000000\n", 3},
		{"loop\ncoin\n1\nrepeat 20000\n", 4},
		{"loop\n9223372036854775807 coin\n9223372036854775807\nrepeat 2\n", 2},
	}
	for _, c := range cases {
		script, e := ParseCab(strings.NewReader(c.text))
		var cab_error *CabError
		switch {
		case c.line == 0 && e != nil: t.Errorf("%q: %v", c.text, e)
		case c.line == 0 && script.Lines != CabMaxLines: t.Errorf("%q: %d lines", c.text, script.Lines)
		case c.line != 0 && !errors.As(e, &cab_error): t.Errorf("%q: expected a CabError, got %v", c.text, e)
		case c.line != 0 && cab_error.Line != c.line: t.Errorf("%q: error at line %d, expected %d", c.text, cab_error.Line, c.line)
		}
	}
}

// TestRegCabFiles checks every cores/*/ver/*/reg.cab in the repository
func TestRegCabFiles(t *testing.T) {
	root := filepath.Join("..", "..", "..", "..", "..")
	files, e := filepath.Glob(filepath.Join(root, "cores", "*", "ver", "*", "reg.cab")); if e != nil { t.Fatal(e) }
	if len(files) == 0 { t.Fatalf("no reg.cab files found under %s", root) }
	sort.Strings(files)
	owners := make(map[string]string)
	for _, path := range files {
		setname := filepath.Base(filepath.Dir(path))
		if other, found := owners[setname]; found {
			t.Errorf("setname %s is used by %s and %s", setname, other, path)
		}
		owners[setname] = path
		script, e := ReadCab(path)
		if e != nil {
			t.Error(e)
			continue
		}
		if script.HasCapture { check_capture_cab(t, path, script) }
	}
}

func check_capture_cab(t *testing.T, path string, script CabScript) {
	if script.LastFrame() > 32766 { t.Errorf("%s: last index %d exceeds 32766", path, script.LastFrame()) }
	for _, run := range script.Runs {
		if len(run.Cheats) > 0 || run.TracingOn || run.Dump {
			t.Errorf("%s: cheat=, tracing_on and dump are not allowed with capture", path)
			return
		}
	}
}
