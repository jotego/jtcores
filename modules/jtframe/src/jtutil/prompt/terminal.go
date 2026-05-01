package prompt

import (
	"bufio"
	"errors"
	"fmt"
	"io"
	"os"
	"strings"
	"unicode"

	"golang.org/x/term"
)

// Terminal reads interactive lines with readline-style editing support.
type Terminal struct {
	in          *os.File
	out         *os.File
	prompt      string
	history     []string
	historyPos  int
	pendingLine string
	killBuffer  string
}

// NewTerminal creates a terminal prompt reader using the provided input/output.
func NewTerminal(in, out *os.File, prompt string) *Terminal {
	return &Terminal{
		in:         in,
		out:        out,
		prompt:     prompt,
		historyPos: 0,
	}
}

// ReadLine reads one editable command line from terminal input.
func (t *Terminal) ReadLine() (string, bool, error) {
	reader := bufio.NewReader(t.in)
	fmt.Fprint(t.out, t.prompt)
	oldState, err := term.MakeRaw(int(t.in.Fd()))
	if err != nil {
		return "", false, err
	}
	defer term.Restore(int(t.in.Fd()), oldState)
	t.historyPos = len(t.history)
	t.pendingLine = ""
	buffer := []rune{}
	cursor := 0

	for {
		ch, _, err := reader.ReadRune()
		if err != nil {
			fmt.Fprint(t.out, "\r\n")
			if errors.Is(err, io.EOF) {
				return "", false, nil
			}
			return "", false, err
		}
		done := t.processKey(reader, ch, &buffer, &cursor)
		if done == readContinue {
			continue
		}
		if done == readLineOk {
			line := string(buffer)
			t.historyPos = len(t.history)
			t.pendingLine = ""
			return line, true, nil
		}
		return "", false, nil
	}
}

type readState int

const (
	readContinue readState = iota
	readLineOk
	readLineEOFOrCancel
)

func (t *Terminal) processKey(reader *bufio.Reader, ch rune, buffer *[]rune, cursor *int) readState {
	switch ch {
	case '\r', '\n':
		return t.handleLineBreak(*buffer)
	case '\x03': // Ctrl+C
		return t.handleCtrlC()
	case '\x04': // Ctrl+D
		return t.handleCtrlD(*buffer)
	case '\x7f', '\b':
		return t.handleBackspace(buffer, cursor)
	case '\x1b':
		t.handleEscape(reader, buffer, cursor)
		return readContinue
	case '\x15': // Ctrl+U
		return t.handleCtrlU(buffer, cursor)
	case '\x17': // Ctrl+W
		return t.handleCtrlW(buffer, cursor)
	case '\x0c': // Ctrl+L
		return t.handleCtrlL(buffer, cursor)
	case '\x01': // Ctrl+A
		return t.handleCtrlA(buffer, cursor)
	case '\x05': // Ctrl+E
		return t.handleCtrlE(buffer, cursor)
	case '\x0b': // Ctrl+K
		return t.handleCtrlK(buffer, cursor)
	case '\x19': // Ctrl+Y
		return t.handleCtrlY(buffer, cursor)
	default:
		if ch < 0x20 {
			return readContinue
		}
		return t.handleInput(ch, buffer, cursor)
	}
	return readContinue
}

func (t *Terminal) handleLineBreak(buffer []rune) readState {
	fmt.Fprint(t.out, "\r\n")
	t.historyPush(string(buffer))
	return readLineOk
}

func (t *Terminal) handleCtrlC() readState {
	fmt.Fprint(t.out, "\r\n")
	return readLineEOFOrCancel
}

func (t *Terminal) handleCtrlD(buffer []rune) readState {
	if len(buffer) == 0 {
		fmt.Fprint(t.out, "\r\n")
		return readLineEOFOrCancel
	}
	return readContinue
}

func (t *Terminal) handleBackspace(buffer *[]rune, cursor *int) readState {
	if *cursor > 0 {
		*cursor--
		*buffer = append((*buffer)[:*cursor], (*buffer)[*cursor+1:]...)
		t.redraw(*buffer, *cursor)
	}
	return readContinue
}

func (t *Terminal) handleCtrlU(buffer *[]rune, cursor *int) readState {
	*buffer = []rune{}
	*cursor = 0
	t.redraw(*buffer, *cursor)
	return readContinue
}

func (t *Terminal) handleCtrlW(buffer *[]rune, cursor *int) readState {
	if *cursor > 0 {
		var newCursor int
		*buffer, newCursor = t.deleteWordBeforeCursor(*buffer, *cursor)
		*cursor = newCursor
		t.redraw(*buffer, *cursor)
	}
	return readContinue
}

func (t *Terminal) handleCtrlA(buffer *[]rune, cursor *int) readState {
	*cursor = 0
	t.redraw(*buffer, *cursor)
	return readContinue
}

func (t *Terminal) handleCtrlE(buffer *[]rune, cursor *int) readState {
	*cursor = len(*buffer)
	t.redraw(*buffer, *cursor)
	return readContinue
}

func (t *Terminal) handleCtrlK(buffer *[]rune, cursor *int) readState {
	if *cursor < len(*buffer) {
		t.killBuffer = string((*buffer)[*cursor:])
		*buffer = (*buffer)[:*cursor]
	} else {
		t.killBuffer = ""
	}
	t.redraw(*buffer, *cursor)
	return readContinue
}

func (t *Terminal) handleCtrlY(buffer *[]rune, cursor *int) readState {
	if t.killBuffer == "" {
		return readContinue
	}
	kill := []rune(t.killBuffer)
	*buffer = append((*buffer)[:*cursor], append(kill, (*buffer)[*cursor:]...)...)
	*cursor += len(kill)
	t.redraw(*buffer, *cursor)
	return readContinue
}

func (t *Terminal) handleCtrlL(buffer *[]rune, cursor *int) readState {
	t.clearScreen()
	t.redraw(*buffer, *cursor)
	return readContinue
}

func (t *Terminal) handleInput(ch rune, buffer *[]rune, cursor *int) readState {
	*buffer = append(*buffer, 0)
	copy((*buffer)[*cursor+1:], (*buffer)[*cursor:])
	(*buffer)[*cursor] = ch
	*cursor++
	t.redraw(*buffer, *cursor)
	return readContinue
}

// Close restores terminal state and frees reader resources.
// Close releases prompt reader resources.
func (t *Terminal) Close() error {
	return nil
}

func (t *Terminal) handleEscape(reader *bufio.Reader, buffer *[]rune, cursor *int) {
	ch, _, err := reader.ReadRune()
	if err != nil {
		return
	}
	if ch != '[' {
		t.handleLegacyEscape(ch, buffer, cursor)
		return
	}
	seq, ok := t.readEscapeSequence(reader)
	if !ok {
		return
	}
	t.handleCSIEscape(seq, buffer, cursor)
}

func (t *Terminal) readEscapeSequence(reader *bufio.Reader) (string, bool) {
	ch, _, err := reader.ReadRune()
	if err != nil {
		return "", false
	}

	seq := make([]rune, 0, 8)
	for {
		seq = append(seq, ch)
		if ch >= 'A' && ch <= 'Z' || ch >= 'a' && ch <= 'z' || ch == '~' {
			break
		}
		if len(seq) > 12 {
			return "", false
		}
		ch, _, err = reader.ReadRune()
		if err != nil {
			return "", false
		}
	}

	return string(seq), true
}

func (t *Terminal) handleLegacyEscape(ch rune, buffer *[]rune, cursor *int) bool {
	switch ch {
	case 'b':
		*cursor = t.moveWordLeft(*buffer, *cursor)
	case 'f':
		*cursor = t.moveWordRight(*buffer, *cursor)
	case 'd':
		*buffer = t.deleteWordAfterCursor(*buffer, *cursor)
	case '\x7f':
		*buffer, *cursor = t.deleteWordBeforeCursor(*buffer, *cursor)
	default:
		return false
	}
	t.redraw(*buffer, *cursor)
	return true
}

func (t *Terminal) handleCSIEscape(seq string, buffer *[]rune, cursor *int) {
	switch seq {
	case "A": // up
		t.handleHistoryUp(buffer, cursor)
	case "B": // down
		t.handleHistoryDown(buffer, cursor)
	case "C": // right
		if *cursor < len(*buffer) {
			*cursor++
		}
		t.redraw(*buffer, *cursor)
	case "D": // left
		if *cursor > 0 {
			*cursor--
		}
		t.redraw(*buffer, *cursor)
	case "1;3D", "1;9D", "1;5D", "5D": // alt/ctrl+left
		*cursor = t.moveWordLeft(*buffer, *cursor)
		t.redraw(*buffer, *cursor)
	case "1;3C", "1;9C", "1;5C", "5C": // alt/ctrl+right
		*cursor = t.moveWordRight(*buffer, *cursor)
		t.redraw(*buffer, *cursor)
	case "1~", "7~": // home
		*cursor = 0
		t.redraw(*buffer, *cursor)
	case "4~", "8~": // end
		*cursor = len(*buffer)
		t.redraw(*buffer, *cursor)
	case "H": // home in some terminals
		*cursor = 0
		t.redraw(*buffer, *cursor)
	case "F": // end in some terminals
		*cursor = len(*buffer)
		t.redraw(*buffer, *cursor)
	case "3;3~", "3;5~", "3;6~": // alt/ctrl(+shift) delete / delete word
		*buffer = t.deleteWordAfterCursor(*buffer, *cursor)
		t.redraw(*buffer, *cursor)
	case "3~": // delete
		if *cursor < len(*buffer) {
			*buffer = append((*buffer)[:*cursor], (*buffer)[*cursor+1:]...)
		}
		t.redraw(*buffer, *cursor)
	}
}

func (t *Terminal) historyPush(line string) {
	line = strings.TrimSpace(line)
	if line == "" {
		return
	}
	if len(t.history) > 0 && t.history[len(t.history)-1] == line {
		return
	}
	t.history = append(t.history, line)
}

func (t *Terminal) redraw(buffer []rune, cursor int) {
	fmt.Fprint(t.out, "\r\033[2K")
	fmt.Fprint(t.out, t.prompt, string(buffer))
	if cursor <= 0 {
		fmt.Fprint(t.out, "\r")
		fmt.Fprint(t.out, t.prompt)
		return
	}
	fmt.Fprint(t.out, "\r\033[", len(t.prompt)+cursor, "C")
}

func (t *Terminal) clearScreen() {
	fmt.Fprint(t.out, "\033[2J\033[H")
}

func (t *Terminal) isWordBoundary(p []rune, pos int) bool {
	if pos < 0 || pos >= len(p) {
		return true
	}
	return unicode.IsSpace(p[pos])
}

func (t *Terminal) moveWordLeft(buffer []rune, cursor int) int {
	i := cursor
	for i > 0 && t.isWordBoundary(buffer, i-1) {
		i--
	}
	for i > 0 && !t.isWordBoundary(buffer, i-1) {
		i--
	}
	return i
}

func (t *Terminal) moveWordRight(buffer []rune, cursor int) int {
	i := cursor
	for i < len(buffer) && t.isWordBoundary(buffer, i) {
		i++
	}
	for i < len(buffer) && !t.isWordBoundary(buffer, i) {
		i++
	}
	return i
}

func (t *Terminal) deleteWordBeforeCursor(buffer []rune, cursor int) ([]rune, int) {
	i := cursor
	for i > 0 && unicode.IsSpace(buffer[i-1]) {
		i--
	}
	for i > 0 && !unicode.IsSpace(buffer[i-1]) {
		i--
	}
	return append(buffer[:i], buffer[cursor:]...), i
}

func (t *Terminal) deleteWordAfterCursor(buffer []rune, cursor int) []rune {
	i := cursor
	for i < len(buffer) && unicode.IsSpace(buffer[i]) {
		i++
	}
	for i < len(buffer) && !unicode.IsSpace(buffer[i]) {
		i++
	}
	return append(buffer[:cursor], buffer[i:]...)
}

func (t *Terminal) handleHistoryUp(buffer *[]rune, cursor *int) {
	if t.historyPos <= 0 {
		return
	}
	if t.historyPos == len(t.history) {
		t.pendingLine = string(*buffer)
	}
	t.historyPos--
	*buffer = []rune(t.history[t.historyPos])
	*cursor = len(*buffer)
	t.redraw(*buffer, *cursor)
}

func (t *Terminal) handleHistoryDown(buffer *[]rune, cursor *int) {
	if t.historyPos >= len(t.history) {
		return
	}
	t.historyPos++
	if t.historyPos == len(t.history) {
		*buffer = []rune(t.pendingLine)
	} else {
		*buffer = []rune(t.history[t.historyPos])
	}
	*cursor = len(*buffer)
	t.redraw(*buffer, *cursor)
}
