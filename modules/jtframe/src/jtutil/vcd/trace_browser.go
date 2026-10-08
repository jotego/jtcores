package vcd

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strings"

	"golang.org/x/sys/unix"
	"golang.org/x/term"
)

type trace_browser struct {
	trace       *TraceReader
	color       bool
	table_width int
	offset      int
	selected_row int
	in          *os.File
	out         io.Writer
}

type trace_browser_key int

const (
	trace_browser_key_unknown trace_browser_key = iota
	trace_browser_key_exit
	trace_browser_key_left
	trace_browser_key_right
	trace_browser_key_up
	trace_browser_key_down
	trace_browser_key_home
	trace_browser_key_page_up
	trace_browser_key_page_down
)

func new_trace_browser(trace *TraceReader, color bool, table_width int, in *os.File, out io.Writer) *trace_browser {
	return &trace_browser{trace: trace, color: color, table_width: table_width, selected_row: 0, in: in, out: out}
}

func (tb *trace_browser) run() {
	if tb.in == nil || !term.IsTerminal(int(tb.in.Fd())) {
		fmt.Fprintln(tb.out, "Browse mode requires terminal input")
		return
	}
	old_state, e := term.MakeRaw(int(tb.in.Fd()))
	if e != nil {
		fmt.Fprintln(tb.out, e)
		return
	}
	defer term.Restore(int(tb.in.Fd()), old_state)
	fmt.Fprint(tb.out, "\033[?1049h\033[?25l")
	defer func() {
		fmt.Fprint(tb.out, "\033[?25h\033[?1049l")
	}()
	fmt.Fprint(tb.out, "\033[H\033[2J")
	reader := bufio.NewReader(tb.in)
	tb.redraw()
	for {
		key := tb.read_key(reader)
		if tb.handle_key(key) {
			fmt.Fprint(tb.out, "\r\n")
			return
		}
	}
}

func (tb *trace_browser) redraw() {
	text := new_trace_display(tb.trace, tb.color, tb.table_width).render_at_selected(tb.offset, tb.selected_row)
	lines := strings.Split(strings.TrimSuffix(text, "\n"), "\n")
	var b strings.Builder
	b.WriteString("\033[H")
	for _, line := range lines {
		b.WriteString("\033[2K")
		b.WriteString(line)
		b.WriteString("\n")
	}
	b.WriteString("\033[2K")
	b.WriteString("Up/Down: row  Left/Right: line  PageUp/PageDown: page  Home: current  Esc/Enter: exit\n")
	b.WriteString("\033[J")
	fmt.Fprint(tb.out, raw_terminal_text(b.String()))
}

func raw_terminal_text(text string) string {
	return strings.ReplaceAll(text, "\n", "\r\n")
}

func (tb *trace_browser) handle_key(key trace_browser_key) bool {
	switch key {
	case trace_browser_key_exit:
		return true
	case trace_browser_key_left:
		tb.offset--
		tb.clamp_selected_row()
	case trace_browser_key_up:
		tb.selected_row--
		tb.clamp_selected_row()
	case trace_browser_key_right:
		tb.offset++
		tb.clamp_selected_row()
	case trace_browser_key_down:
		tb.selected_row++
		tb.clamp_selected_row()
	case trace_browser_key_home:
		tb.offset = 0
		tb.clamp_selected_row()
	case trace_browser_key_page_up:
		tb.offset -= 5
		tb.clamp_selected_row()
	case trace_browser_key_page_down:
		tb.offset += 5
		tb.clamp_selected_row()
	default:
		return false
	}
	tb.redraw()
	return false
}

func (tb *trace_browser) visible_rows() int {
	if tb.trace == nil {
		return 0
	}
	return new_trace_display(tb.trace, tb.color, tb.table_width).visible_row_count(tb.offset)
}

func (tb *trace_browser) clamp_selected_row() {
	max_rows := tb.visible_rows()
	if max_rows <= 0 {
		tb.selected_row = 0
		return
	}
	if tb.selected_row < 0 {
		tb.selected_row = 0
		return
	}
	if tb.selected_row > max_rows-1 {
		tb.selected_row = max_rows - 1
	}
}

func (tb *trace_browser) read_key(reader *bufio.Reader) trace_browser_key {
	ch, e := reader.ReadByte()
	if e != nil {
		return trace_browser_key_exit
	}
	switch ch {
	case '\r', '\n':
		return trace_browser_key_exit
	case '\x1b':
		return tb.read_escape_key(reader)
	default:
		return trace_browser_key_unknown
	}
}

func (tb *trace_browser) read_escape_key(reader *bufio.Reader) trace_browser_key {
	if reader.Buffered() == 0 && !tb.input_ready() {
		return trace_browser_key_exit
	}
	ch, e := reader.ReadByte()
	if e != nil || ch != '[' {
		return trace_browser_key_exit
	}
	seq, ok := tb.read_csi_sequence(reader)
	if !ok {
		return trace_browser_key_unknown
	}
	switch seq {
	case "A":
		return trace_browser_key_up
	case "B":
		return trace_browser_key_down
	case "D":
		return trace_browser_key_left
	case "C":
		return trace_browser_key_right
	case "H", "1~", "7~":
		return trace_browser_key_home
	case "5~":
		return trace_browser_key_page_up
	case "6~":
		return trace_browser_key_page_down
	default:
		return trace_browser_key_unknown
	}
}

func (tb *trace_browser) read_csi_sequence(reader *bufio.Reader) (string, bool) {
	seq := make([]byte, 0, 8)
	for {
		ch, e := reader.ReadByte()
		if e != nil {
			return "", false
		}
		seq = append(seq, ch)
		if ch >= 'A' && ch <= 'Z' || ch >= 'a' && ch <= 'z' || ch == '~' {
			return string(seq), true
		}
		if len(seq) > 12 {
			return "", false
		}
	}
}

func (tb *trace_browser) input_ready() bool {
	if tb.in == nil {
		return false
	}
	fd := int(tb.in.Fd())
	var readfds unix.FdSet
	readfds.Set(fd)
	timeout := unix.Timeval{Usec: 30000}
	ready, e := unix.Select(fd+1, &readfds, nil, nil, &timeout)
	return e == nil && ready > 0
}
