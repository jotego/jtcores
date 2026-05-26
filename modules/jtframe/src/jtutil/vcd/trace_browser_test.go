package vcd

import (
	"bufio"
	"io"
	"strings"
	"testing"
)

func Test_trace_browser_keys_move_window_offset(t *testing.T) {
	tb := new_trace_browser(nil, false, trace_table_width_default, nil, io.Discard)
	if tb.selected_row != 0 {
		t.Fatalf("selected row=%d want 0", tb.selected_row)
	}
	if tb.handle_key(trace_browser_key_left) {
		t.Fatal("left should not exit")
	}
	if tb.offset != -1 {
		t.Fatalf("left offset=%d want -1", tb.offset)
	}
	tb.handle_key(trace_browser_key_right)
	if tb.offset != 0 {
		t.Fatalf("right offset=%d want 0", tb.offset)
	}
	tb.handle_key(trace_browser_key_page_up)
	if tb.offset != -5 {
		t.Fatalf("page up offset=%d want -5", tb.offset)
	}
	tb.handle_key(trace_browser_key_page_down)
	if tb.offset != 0 {
		t.Fatalf("page down offset=%d want 0", tb.offset)
	}
	tb.handle_key(trace_browser_key_left)
	tb.handle_key(trace_browser_key_home)
	if tb.offset != 0 {
		t.Fatalf("home offset=%d want 0", tb.offset)
	}
	if !tb.handle_key(trace_browser_key_exit) {
		t.Fatal("exit key should exit")
	}
}

func Test_trace_browser_reads_buffered_escape_sequences(t *testing.T) {
	tb := new_trace_browser(nil, false, trace_table_width_default, nil, io.Discard)
	if got := tb.read_escape_key(buffered_reader("[D")); got != trace_browser_key_left {
		t.Fatalf("left sequence decoded as %d", got)
	}
	if got := tb.read_escape_key(buffered_reader("[C")); got != trace_browser_key_right {
		t.Fatalf("right sequence decoded as %d", got)
	}
	if got := tb.read_escape_key(buffered_reader("[A")); got != trace_browser_key_up {
		t.Fatalf("up sequence decoded as %d", got)
	}
	if got := tb.read_escape_key(buffered_reader("[B")); got != trace_browser_key_down {
		t.Fatalf("down sequence decoded as %d", got)
	}
	if got := tb.read_escape_key(buffered_reader("[H")); got != trace_browser_key_home {
		t.Fatalf("home sequence decoded as %d", got)
	}
	if got := tb.read_escape_key(buffered_reader("[5~")); got != trace_browser_key_page_up {
		t.Fatalf("page up sequence decoded as %d", got)
	}
	if got := tb.read_escape_key(buffered_reader("[6~")); got != trace_browser_key_page_down {
		t.Fatalf("page down sequence decoded as %d", got)
	}
}

func Test_trace_browser_selected_row_moves_and_clamps(t *testing.T) {
	trace := open_test_trace(t, []string{
		"PC,R0",
		"1,0",
		"2,1",
		"3,2",
	})
	defer trace.Close()
	tb := new_trace_browser(trace, false, trace_table_width_default, nil, io.Discard)
	if tb.selected_row != 0 {
		t.Fatalf("selected row=%d want 0", tb.selected_row)
	}
	tb.handle_key(trace_browser_key_up)
	if tb.selected_row != 0 {
		t.Fatalf("up from top row should stay, selected row=%d", tb.selected_row)
	}
	max_rows := tb.visible_rows()
	if max_rows == 0 {
		t.Fatal("no rows visible")
	}
	tb.selected_row = max_rows - 1
	tb.handle_key(trace_browser_key_down)
	if tb.selected_row != max_rows-1 {
		t.Fatalf("down from bottom row should stay, selected row=%d want %d", tb.selected_row, max_rows-1)
	}
}

func Test_trace_browser_selected_row_clamps_after_offset_change(t *testing.T) {
	trace := open_test_trace(t, []string{
		"PC,R0",
		"1,0",
		"2,1",
		"3,2",
		"4,3",
	})
	defer trace.Close()
	tb := new_trace_browser(trace, false, trace_table_width_default, nil, io.Discard)
	tb.selected_row = 1
	tb.offset = 100
	tb.handle_key(trace_browser_key_left)
	if tb.selected_row != 0 {
		t.Fatalf("selected row should clamp after offset change, got %d want 0", tb.selected_row)
	}
}

func Test_raw_terminal_text_uses_crlf(t *testing.T) {
	got := raw_terminal_text("a\nb\n")
	if got != "a\r\nb\r\n" {
		t.Fatalf("raw terminal text=%q", got)
	}
}

func buffered_reader(text string) *bufio.Reader {
	reader := bufio.NewReader(strings.NewReader(text))
	reader.Peek(1)
	return reader
}
