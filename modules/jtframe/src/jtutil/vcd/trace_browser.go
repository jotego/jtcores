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
	in          *os.File
	out         io.Writer
}

type trace_browser_key int

const (
	trace_browser_key_unknown trace_browser_key = iota
	trace_browser_key_exit
	trace_browser_key_left
	trace_browser_key_right
	trace_browser_key_home
	trace_browser_key_page_up
	trace_browser_key_page_down
)

func new_trace_browser(trace *TraceReader, color bool, table_width int, in *os.File, out io.Writer) *trace_browser {
	return &trace_browser{trace: trace, color: color, table_width: table_width, in: in, out: out}
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
	fmt.Fprint(tb.out, "\033[2J\033[H")
	fmt.Fprint(tb.out, raw_terminal_text(new_trace_display(tb.trace, tb.color, tb.table_width).render_at(tb.offset)))
	fmt.Fprint(tb.out, "\r\n")
	fmt.Fprint(tb.out, "Left/Right: line  PageUp/PageDown: page  Home: current  Esc/Enter: exit")
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
	case trace_browser_key_right:
		tb.offset++
	case trace_browser_key_home:
		tb.offset = 0
	case trace_browser_key_page_up:
		tb.offset -= 5
	case trace_browser_key_page_down:
		tb.offset += 5
	default:
		return false
	}
	tb.redraw()
	return false
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
