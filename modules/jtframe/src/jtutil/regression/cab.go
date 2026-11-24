/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

// Reader for cabinet (.cab) input scripts. It follows the grammar of
// modules/jtframe/verilator/cabinet.cpp; both are checked against the
// golden vectors in modules/jtframe/verilator/tests/cabinet/vectors.

import (
	"fmt"
	"io"
	"os"
	"strings"
)

// CabCapturePeriod is the distance in frames between two captures
const CabCapturePeriod = 100

// CabMaxLines is the longest script accepted: the hardware frame counters
// are 15-bit. The C++ parser used by jtsim has no such limit.
const CabMaxLines = 32767

type CabRun struct {
	Frames    uint64
	Inputs    uint32
	DIPSW     uint32
	HasDIPSW  bool
	TracingOn bool
	Dump      bool
	Cheats    []string
}

type CabScript struct {
	Runs       []CabRun // loops expanded, equal neighbours merged
	Lines      uint64   // number of frames (CAB lines) in the script
	HasCapture bool
	Capture    uint64 // first frame to capture
}

// CabError is a parse error that names the cabinet line where it was found
type CabError struct {
	Line int
	Msg  string
}

func (e *CabError) Error() string {
	return fmt.Sprintf("%s at cabinet line %d", e.Msg, e.Line)
}

const cab_too_long = "cabinet script exceeds 32767 lines"

var cab_actions = map[string]uint32{
	"coin": 0x000001, "service": 0x000002, "1p": 0x000004, "2p": 0x000008,
	"right": 0x000010, "left": 0x000020, "down": 0x000040, "up": 0x000080,
	"b1": 0x000100, "b2": 0x000200, "b3": 0x000400, "test": 0x000800,
	"reset": 0x001000, "2coin": 0x002000, "2right": 0x004000, "2left": 0x008000,
	"2down": 0x010000, "2up": 0x020000, "2b1": 0x040000, "2b2": 0x080000,
	"2b3": 0x100000,
}

// ReadCab parses the cabinet script at path
func ReadCab(path string) (CabScript, error) {
	file, e := os.Open(path); if e != nil { return CabScript{}, e }
	defer file.Close()
	script, e := ParseCab(file); if e != nil { return script, fmt.Errorf("%s: %w", path, e) }
	return script, nil
}

// ParseCab parses a cabinet script. Errors are of type *CabError.
func ParseCab(input io.Reader) (CabScript, error) {
	data, e := io.ReadAll(input); if e != nil { return CabScript{}, e }
	parser := cab_parser{}
	e = parser.parse(string(data)); if e != nil { return CabScript{}, e }
	return parser.script, nil
}

// LastFrame is the index of the last CAB line, 0 for an empty script
func (s CabScript) LastFrame() uint64 {
	if s.Lines == 0 { return 0 }
	return s.Lines - 1
}

// CaptureFrames lists N, N+100, ... up to the last frame
func (s CabScript) CaptureFrames() []uint64 {
	if !s.HasCapture { return nil }
	var frames []uint64
	for k := s.Capture; k <= s.LastFrame(); k += CabCapturePeriod {
		frames = append(frames, k)
	}
	return frames
}

type cab_parser struct {
	script       CabScript
	line_no      int
	looping      bool
	loop         []CabRun
	loop_line    int
	statements   bool
	capture_line int
}

func (p *cab_parser) parse(text string) error {
	lines := strings.Split(text, "\n")
	if len(lines) > 0 && lines[len(lines)-1] == "" { lines = lines[:len(lines)-1] }
	for k, line := range lines {
		p.line_no = k + 1
		if comment := strings.IndexByte(line, '#'); comment >= 0 { line = line[:comment] }
		tokens := cab_words(line)
		if len(tokens) == 0 { continue }
		e := p.parse_line(tokens); if e != nil { return e }
	}
	if p.looping { return &CabError{p.loop_line, "cabinet script ends with an unclosed loop"} }
	if p.script.HasCapture && (p.script.Capture == 0 || p.script.Capture >= p.script.Lines) {
		return &CabError{p.capture_line, "capture frame must be between 1 and the last line index"}
	}
	return nil
}

func (p *cab_parser) fail(msg string) error {
	return &CabError{p.line_no, msg}
}

func (p *cab_parser) parse_line(tokens []string) error {
	keyword := cab_lower(tokens[0])
	switch keyword {
	case "capture":
		return p.parse_capture(tokens)
	case "loop":
		p.statements = true
		if len(tokens) != 1 || p.looping { return p.fail("invalid loop") }
		p.loop = nil
		p.looping = true
		p.loop_line = p.line_no
		return nil
	case "repeat":
		p.statements = true
		return p.parse_repeat(tokens)
	}
	p.statements = true
	current := p.script.Lines
	if p.looping { current += cab_run_count(p.loop) }
	repeats, start, absolute, e := p.duration(tokens, current); if e != nil { return e }
	frame, e := p.parse_frame(tokens[start:]); if e != nil { return e }
	if current+repeats > CabMaxLines { return p.fail(cab_too_long) }
	if absolute && repeats > 1 {
		p.append(CabRun{Frames: repeats - 1})
		repeats = 1
	}
	frame.Frames = repeats
	p.append(frame)
	return nil
}

func (p *cab_parser) parse_capture(tokens []string) error {
	if p.script.HasCapture { return p.fail("duplicate capture") }
	if p.statements { return p.fail("capture must come before any frame line or loop") }
	if len(tokens) != 2 { return p.fail("capture needs one frame number") }
	value, ok := cab_decimal(tokens[1]); if !ok { return p.fail("invalid capture frame") }
	p.script.HasCapture = true
	p.script.Capture = value
	p.capture_line = p.line_no
	return nil
}

func (p *cab_parser) parse_repeat(tokens []string) error {
	if !p.looping || len(tokens) != 2 { return p.fail("invalid repeat") }
	repeats, e := p.parse_number(tokens[1], "repeat count"); if e != nil { return e }
	if repeats == 0 { return p.fail("repeat count must be positive") }
	body_count := cab_run_count(p.loop)
	if p.script.Lines+body_count*repeats > CabMaxLines { return p.fail(cab_too_long) }
	p.looping = false
	body := p.loop
	p.loop = nil
	if len(body) == 1 {
		run := body[0]
		run.Frames *= repeats
		p.append(run)
		return nil
	}
	for k := uint64(0); k < repeats; k++ {
		for _, run := range body { p.append(run) }
	}
	return nil
}

// duration mirrors cabinet.cpp: =N is absolute, a leading number is a count
func (p *cab_parser) duration(tokens []string, current uint64) (uint64, int, bool, error) {
	first := tokens[0]
	if first[0] == '=' {
		final, e := p.parse_number(first[1:], "final frame"); if e != nil { return 0, 0, false, e }
		if final+1 < current { return 0, 0, false, p.fail("final frame is before the current frame") }
		return final - current + 1, 1, true, nil
	}
	value, negative, ok := c_strtoul(first, 0, true)
	if ok {
		if negative { return 0, 0, false, p.fail("negative frame count") }
		return value, 1, false, nil
	}
	return 1, 0, false, nil
}

func (p *cab_parser) parse_frame(tokens []string) (CabRun, error) {
	var frame CabRun
	for _, original := range tokens {
		token := cab_lower(original)
		switch {
		case strings.HasPrefix(token, "dipsw="):
			if frame.HasDIPSW { return frame, p.fail("duplicate dipsw entry") }
			value, e := p.parse_hex(token[6:], "dipsw value"); if e != nil { return frame, e }
			frame.DIPSW = value
			frame.HasDIPSW = true
		case strings.HasPrefix(token, "cheat="):
			name := token[6:]
			if !cab_identifier(name) { return frame, p.fail("invalid cheat name") }
			frame.Cheats = append(frame.Cheats, name)
		case token == "tracing_on":
			if frame.TracingOn { return frame, p.fail("duplicate tracing_on entry") }
			frame.TracingOn = true
		case token == "dump":
			if frame.Dump { return frame, p.fail("duplicate dump entry") }
			frame.Dump = true
		default:
			action, ok := cab_actions[token]
			if !ok { return frame, p.fail(fmt.Sprintf("unknown cabinet action '%s'", original)) }
			frame.Inputs |= action
		}
	}
	return frame, nil
}

func (p *cab_parser) parse_number(text, what string) (uint64, error) {
	if text == "" || text[0] == '-' { return 0, p.fail(what + " must be a non-negative number") }
	value, _, ok := c_strtoul(text, 0, false)
	if !ok || value > 0xffffffff { return 0, p.fail("cannot parse " + what + ": " + text) }
	return value, nil
}

func (p *cab_parser) parse_hex(text, what string) (uint32, error) {
	if text == "" || text[0] == '-' { return 0, p.fail(what + " must be a non-negative hexadecimal number") }
	value, _, ok := c_strtoul(text, 16, false)
	if !ok || value > 0xffffffff { return 0, p.fail("cannot parse " + what + ": " + text) }
	return uint32(value), nil
}

func (p *cab_parser) append(run CabRun) {
	if run.Frames == 0 { return }
	runs := &p.script.Runs
	if p.looping {
		runs = &p.loop
	} else {
		p.script.Lines += run.Frames
	}
	last := len(*runs) - 1
	if last >= 0 && cab_same_frame((*runs)[last], run) {
		(*runs)[last].Frames += run.Frames
		return
	}
	*runs = append(*runs, run)
}

func cab_run_count(runs []CabRun) uint64 {
	count := uint64(0)
	for _, run := range runs { count += run.Frames }
	return count
}

func cab_same_frame(a, b CabRun) bool {
	if a.Inputs != b.Inputs || a.DIPSW != b.DIPSW || a.HasDIPSW != b.HasDIPSW ||
		a.TracingOn != b.TracingOn || a.Dump != b.Dump || len(a.Cheats) != len(b.Cheats) {
		return false
	}
	for k := range a.Cheats {
		if a.Cheats[k] != b.Cheats[k] { return false }
	}
	return true
}

// cab_words splits on the characters that C isspace accepts
func cab_words(line string) []string {
	return strings.FieldsFunc(line, func(r rune) bool {
		return r == ' ' || r == '\t' || r == '\n' || r == '\v' || r == '\f' || r == '\r'
	})
}

func cab_lower(text string) string {
	result := []byte(text)
	for k, c := range result {
		if c >= 'A' && c <= 'Z' { result[k] = c + 'a' - 'A' }
	}
	return string(result)
}

func cab_identifier(text string) bool {
	if text == "" { return false }
	for _, c := range []byte(text) {
		ok := c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '_' || c == '-'
		if !ok { return false }
	}
	return true
}

func cab_decimal(text string) (uint64, bool) {
	if text == "" || len(text) > 19 { return 0, false }
	value := uint64(0)
	for _, c := range []byte(text) {
		if c < '0' || c > '9' { return 0, false }
		value = value*10 + uint64(c-'0')
	}
	return value, true
}

// c_strtoul follows C strtoul/strtol for a whole token: ok is false unless
// every character is consumed. signed selects strtol saturation.
func c_strtoul(text string, base int, signed bool) (value uint64, negative bool, ok bool) {
	s := text
	if s != "" && (s[0] == '+' || s[0] == '-') {
		negative = s[0] == '-'
		s = s[1:]
	}
	has_prefix := len(s) > 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X') && c_digit(s[2]) < 16
	if base == 0 {
		switch {
		case has_prefix: base = 16
		case s != "" && s[0] == '0': base = 8
		default: base = 10
		}
	}
	if base == 16 && has_prefix { s = s[2:] }
	if s == "" { return 0, false, false }
	overflow := false
	for _, c := range []byte(s) {
		digit := uint64(c_digit(c))
		if digit >= uint64(base) { return 0, false, false }
		if value > (^uint64(0)-digit)/uint64(base) { overflow = true }
		value = value*uint64(base) + digit
	}
	if signed {
		limit := uint64(1) << 63
		if !negative && (overflow || value >= limit) { value = limit - 1 }
		if negative && (overflow || value > limit) { value = limit }
		negative = negative && value != 0
		return value, negative, true
	}
	if overflow { value = ^uint64(0) }
	if negative { value = -value }
	return value, false, true
}

func c_digit(c byte) int {
	switch {
	case c >= '0' && c <= '9': return int(c - '0')
	case c >= 'a' && c <= 'z': return int(c-'a') + 10
	case c >= 'A' && c <= 'Z': return int(c-'A') + 10
	}
	return 99
}
