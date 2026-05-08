package vcd

import (
	"strconv"
	"strings"
)

type TraceRow struct {
	line int
	time uint64
	Asm  string
	Data NameValue
}

type TraceReader struct {
	*LnFile
	header   []string
	previous NameValue
}

func NewTraceReader() *TraceReader {
	return &TraceReader{}
}

func (tr *TraceReader) Header() []string {
	return tr.header
}

func NewTraceReaderFromFile(fname string) *TraceReader {
	tr := NewTraceReader()
	tr.Open(fname)
	return tr
}

func (tr *TraceReader) Open(fname string) {
	tr.LnFile = &LnFile{}
	tr.LnFile.Open(fname)
	tr.header = nil
	tr.previous = nil
}

func (tr *TraceReader) Next() (TraceRow, bool) {
	for tr.Scan() {
		row, ok := tr.parseLine(tr.Text())
		if !ok {
			continue
		}
		row.line = tr.line
		row.time = tr.time
		return row, true
	}
	return TraceRow{}, false
}

func (tr *TraceReader) parseLine(line string) (TraceRow, bool) {
	line = strings.TrimSpace(line)
	if line == "" {
		return TraceRow{}, false
	}

	if asm, ok := tr.parseInterrupt(line); ok {
		if tr.previous == nil {
			return TraceRow{}, false
		}
		return TraceRow{Asm: asm, Data: copy_namevalue(tr.previous)}, true
	}

	if tr.header == nil {
		if tr.parseHeader(line) {
			return TraceRow{}, false
		}
	}
	if len(tr.header) == 0 {
		return TraceRow{}, false
	}

	data, asm, ok := tr.parseDataLine(line)
	if !ok {
		return TraceRow{}, false
	}
	tr.previous = copy_namevalue(data)
	return TraceRow{Asm: asm, Data: data}, true
}

func (tr *TraceReader) parseHeader(line string) bool {
	if !strings.Contains(line, ",") || strings.Contains(line, "=") {
		return false
	}
	columns := strings.Split(line, ",")
	header := make([]string, 0, len(columns))
	for _, col := range columns {
		col = strings.TrimSpace(col)
		if col == "" {
			return false
		}
		header = append(header, col)
	}
	if len(header) <= 1 {
		return false
	}
	tr.header = header
	return true
}

func (tr *TraceReader) parseDataLine(line string) (NameValue, string, bool) {
	values := strings.SplitN(line, ",", len(tr.header)+1)
	if len(values) != len(tr.header) && len(values) != len(tr.header)+1 {
		return nil, "", false
	}
	data := make(NameValue, len(tr.header))
	for k, field := range values[:len(tr.header)] {
		parsed, ok := parseTraceHex(field)
		if !ok {
			return nil, "", false
		}
		data[tr.header[k]] = parsed
	}
	if len(values) == len(tr.header)+1 {
		return data, normalize_asm_field(values[len(tr.header)]), true
	}
	return data, "", true
}

func normalize_asm_field(text string) string {
	text = strings.TrimSpace(text)
	k := strings.Index(text, ":")
	if k == -1 {
		return text
	}
	prefix := strings.TrimSpace(text[:k])
	if !is_hex_word(prefix) {
		return text
	}
	return strings.TrimSpace(text[k+1:])
}

func is_hex_word(text string) bool {
	if text == "" {
		return false
	}
	for _, ch := range text {
		if !((ch >= '0' && ch <= '9') || (ch >= 'A' && ch <= 'F') || (ch >= 'a' && ch <= 'f')) {
			return false
		}
	}
	return true
}

func (tr *TraceReader) parseInterrupt(line string) (string, bool) {
	if !strings.HasPrefix(line, "(") || !strings.HasSuffix(line, ")") {
		return "", false
	}
	inner := strings.TrimSpace(line[1 : len(line)-1])
	if inner == "" {
		return "", false
	}
	lower := strings.ToLower(inner)
	if !strings.Contains(lower, "interrupt") && !strings.Contains(lower, "irq") {
		return "", false
	}
	if strings.HasPrefix(lower, "interrupted at") {
		inner = strings.TrimSpace(inner[len("interrupted at"):])
		if k := strings.Index(inner, ","); k != -1 {
			inner = inner[k+1:]
		}
	}
	inner = strings.TrimSpace(inner)
	if inner == "" {
		return "", false
	}
	return inner, true
}

func parseTraceHex(text string) (uint64, bool) {
	text = strings.TrimSpace(text)
	if text == "" {
		return 0, false
	}
	value, err := strconv.ParseUint(text, 16, 64)
	return value, err == nil
}
