package vcd

import (
	"fmt"
	"sort"
	"strings"
)

const trace_display_red = "\033[31m"
const trace_display_underline = "\033[4m"
const trace_display_reset = "\033[0m"
const trace_table_width_default = 120
const trace_table_width_min = 40

type trace_display struct {
	trace       *TraceReader
	color       bool
	table_width int
}

type trace_display_entry struct {
	offset int
	asm    string
	data   NameValue
}

type trace_display_cell struct {
	raw string
}

type trace_display_row struct {
	label     string
	cells     []trace_display_cell
	highlight bool
	selected  bool
}

func new_trace_display(trace *TraceReader, color bool, table_width int) *trace_display {
	if table_width <= 0 {
		table_width = trace_table_width_default
	}
	return &trace_display{trace: trace, color: color, table_width: table_width}
}

func (td *trace_display) print() {
	fmt.Print(td.render())
}

func (td *trace_display) render() string {
	return td.render_at(0)
}

func (td *trace_display) render_at(center_offset int) string {
	return td.render_at_selected(center_offset, -1)
}

func (td *trace_display) render_at_selected(center_offset int, selected_row int) string {
	if td.trace == nil {
		return "No trace file\n"
	}
	current_line := td.trace.line
	entries := td.collect_entries(center_offset)
	if len(entries) == 0 {
		return fmt.Sprintf("At line %d:\n\nNo register content in line\n", current_line)
	}
	names := td.sorted_names(entries)
	if len(names) == 0 {
		return fmt.Sprintf("At line %d:\n\nNo register content in line\nLine: '%s'\n",
			current_line, td.trace.Text())
	}
	var b strings.Builder
	fmt.Fprintf(&b, "At line %d:\n\n", current_line)
	rows := []trace_display_row{
		{label: "Trace", cells: td.header_cells(entries)},
		{label: "ASM COD", cells: td.asm_cells(entries)},
	}
	for _, name := range names {
		rows = append(rows, trace_display_row{label: name, cells: td.value_cells(name, entries), highlight: true})
	}
	if selected_row >= 0 && selected_row < len(rows) {
		rows[selected_row].selected = true
	}
	label_width := td.label_width(rows)
	column_width := td.column_width(rows, label_width, len(entries))
	for _, row := range rows {
		td.write_row(&b, row, label_width, column_width)
	}
	return b.String()
}

func (td *trace_display) visible_row_count(center_offset int) int {
	if td.trace == nil {
		return 0
	}
	entries := td.collect_entries(center_offset)
	if len(entries) == 0 {
		return 0
	}
	names := td.sorted_names(entries)
	if len(names) == 0 {
		return 0
	}
	return 2 + len(names)
}

func (td *trace_display) collect_entries(center_offset int) []trace_display_entry {
	current_line := td.trace.line
	current_time := td.trace.time
	start_line := current_line + center_offset - 3
	if start_line < 1 {
		start_line = 1
	}
	defer td.trace.RewindTo(current_line, current_time)
	if !td.trace.RewindTo(start_line, current_time) {
		return nil
	}
	entries := make([]trace_display_entry, 0, 5)
	last_line := start_line + 5
	for {
		if td.trace.line > last_line {
			break
		}
		row, ok := td.trace.Next()
		if !ok {
			break
		}
		entries = append(entries, trace_display_entry{
			offset: td.trace.line - current_line,
			asm:    row.Asm,
			data:   row.Data,
		})
		if td.trace.line >= last_line {
			break
		}
	}
	return entries
}

func (td *trace_display) sorted_names(entries []trace_display_entry) []string {
	seen := make(map[string]bool)
	for _, entry := range entries {
		for name := range entry.data {
			seen[name] = true
		}
	}
	names := make([]string, 0, len(seen))
	for name := range seen {
		names = append(names, name)
	}
	sort.Slice(names, func(i, j int) bool { return compare_register_name(names[i], names[j]) })
	if pc_at := pc_name_index(names); pc_at > 0 {
		pc_name := names[pc_at]
		copy(names[1:pc_at+1], names[0:pc_at])
		names[0] = pc_name
	}
	return names
}

func compare_register_name(a, b string) bool {
	pa, na, oka := split_alpha_num_suffix(a)
	pb, nb, okb := split_alpha_num_suffix(b)
	if oka && okb {
		if pa != pb {
			return strings.Compare(pa, pb) < 0
		}
		if na != nb {
			return na < nb
		}
	}
	return strings.Compare(a, b) < 0
}

func split_alpha_num_suffix(name string) (string, int, bool) {
	end := len(name)
	for end > 0 {
		ch := name[end-1]
		if ch < '0' || ch > '9' {
			break
		}
		end--
	}
	if end == 0 || end == len(name) {
		return "", 0, false
	}
	for i := 0; i < end; i++ {
		ch := name[i]
		if !(ch >= 'A' && ch <= 'Z' || ch >= 'a' && ch <= 'z') {
			return "", 0, false
		}
	}
	num := 0
	for _, ch := range []byte(name[end:]) {
		num = num*10 + int(ch-'0')
	}
	return name[:end], num, true
}

func pc_name_index(names []string) int {
	for k, name := range names {
		if strings.EqualFold(name, "PC") {
			return k
		}
	}
	return -1
}

func (td *trace_display) header_cells(entries []trace_display_entry) []trace_display_cell {
	cells := make([]trace_display_cell, len(entries))
	for k, entry := range entries {
		if entry.offset == 0 {
			cells[k].raw = "Current"
		} else {
			cells[k].raw = fmt.Sprintf("%+d", entry.offset)
		}
	}
	return cells
}

func (td *trace_display) asm_cells(entries []trace_display_entry) []trace_display_cell {
	cells := make([]trace_display_cell, len(entries))
	for k, entry := range entries {
		cells[k].raw = normalize_display_asm(entry.asm)
	}
	return cells
}

func normalize_display_asm(asm string) string {
	return strings.Join(strings.Fields(asm), " ")
}

func (td *trace_display) value_cells(name string, entries []trace_display_entry) []trace_display_cell {
	cells := make([]trace_display_cell, len(entries))
	for k, entry := range entries {
		value, ok := entry.data[name]
		if !ok {
			continue
		}
		if name == "frame_cnt" {
			cells[k].raw = fmt.Sprintf("%d", value)
		} else {
			cells[k].raw = fmt.Sprintf("0x%X", value)
		}
	}
	return cells
}

func (td *trace_display) write_row(b *strings.Builder, row trace_display_row, label_width, column_width int) {
	if row.selected && td.color {
		b.WriteString(trace_display_underline)
	}
	fmt.Fprintf(b, "%-*s |", label_width, row.label)
	for k, cell := range row.cells {
		cell_text := truncate_cell(cell.raw, column_width)
		text := fmt.Sprintf(" %-*s |", column_width, cell_text)
		if row.highlight && td.color && k > 0 && cell.raw != "" && cell.raw != row.cells[k-1].raw {
			if row.selected {
				text = " " + trace_display_red + fmt.Sprintf("%-*s", column_width, cell_text) +
					trace_display_underline + " |"
			} else {
				text = " " + trace_display_red + fmt.Sprintf("%-*s", column_width, cell_text) +
					trace_display_reset + " |"
			}
		}
		b.WriteString(text)
	}
	if row.selected && td.color {
		b.WriteString(trace_display_reset)
	}
	b.WriteString("\n")
}

func (td *trace_display) label_width(rows []trace_display_row) int {
	width := len("frame_cnt")
	for _, row := range rows {
		if len(row.label) > width {
			width = len(row.label)
		}
	}
	if width < len("frame_cnt") {
		width = len("frame_cnt")
	}
	return width
}

func (td *trace_display) column_width(rows []trace_display_row, label_width, cell_count int) int {
	width := len("Current")
	for _, row := range rows {
		for _, cell := range row.cells {
			if len(cell.raw) > width {
				width = len(cell.raw)
			}
		}
	}
	if max_width := td.max_column_width(label_width, cell_count); width > max_width {
		width = max_width
	}
	return width
}

func (td *trace_display) max_column_width(label_width, cell_count int) int {
	if cell_count <= 0 {
		return len("Current")
	}
	overhead := label_width + 2 + cell_count*3
	width := (td.table_width - overhead) / cell_count
	if width < 1 {
		width = 1
	}
	return width
}

func truncate_cell(text string, width int) string {
	if width <= 0 || len(text) <= width {
		return text
	}
	if width > 3 {
		return text[:width-3] + "..."
	}
	return text[:width]
}
