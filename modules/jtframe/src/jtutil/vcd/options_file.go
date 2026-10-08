package vcd

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

const jtutil_config_name = ".jtutil.toml"
const trace_options_section = "trace.options"
const trace_session_section = "trace.session"

type traceSessionState struct {
	SavedAt    int64
	VcdFile    string
	CsvFile    string
	VcdLine    int
	CsvLine    int
	VcdTime    uint64
	CsvTime    uint64
	VcdModTime int64
	CsvModTime int64
}

func (cmp *Comparator) load_options(fname string) error {
	data, e := os.ReadFile(fname)
	if os.IsNotExist(e) {
		return nil
	}
	if e != nil {
		return fmt.Errorf("Cannot read %s: %w", fname, e)
	}
	options, e := parse_section(string(data), trace_options_section)
	if e != nil {
		return fmt.Errorf("Cannot parse %s: %w", fname, e)
	}
	for name, value := range options {
		option, e := format_loaded_option(name, value)
		if e != nil {
			return fmt.Errorf("Cannot apply %s: %w", name, e)
		}
		e = cmp.set_option(option)
		if e != nil {
			return fmt.Errorf("Cannot apply %s: %w", option, e)
		}
	}
	return nil
}

func load_trace_session(fname string) (traceSessionState, bool, error) {
	var state traceSessionState
	data, e := os.ReadFile(fname)
	if os.IsNotExist(e) {
		return state, false, nil
	}
	if e != nil {
		return state, false, fmt.Errorf("Cannot read %s: %w", fname, e)
	}
	values, e := parse_section(string(data), trace_session_section)
	if e != nil {
		return state, false, fmt.Errorf("Cannot parse %s: %w", fname, e)
	}
	if len(values) == 0 {
		return state, false, nil
	}
	for name, value := range values {
		switch name {
		case "saved_at":
			if value == "" {
				state.SavedAt = 0
				continue
			}
			parsed, e := parse_int64("saved_at", value)
			if e != nil {
				return state, false, e
			}
			state.SavedAt = parsed
		case "vcd_file":
			state.VcdFile = value
		case "csv_file":
			state.CsvFile = value
		case "vcd_line":
			parsed, e := parse_int("vcd_line", value)
			if e != nil {
				return state, false, e
			}
			state.VcdLine = parsed
		case "csv_line":
			parsed, e := parse_int("csv_line", value)
			if e != nil {
				return state, false, e
			}
			state.CsvLine = parsed
		case "vcd_time":
			parsed, e := parse_uint("vcd_time", value)
			if e != nil {
				return state, false, e
			}
			state.VcdTime = parsed
		case "csv_time":
			parsed, e := parse_uint("csv_time", value)
			if e != nil {
				return state, false, e
			}
			state.CsvTime = parsed
		case "vcd_mtime_ns":
			if value == "" {
				state.VcdModTime = 0
				continue
			}
			parsed, e := parse_int64("vcd_mtime_ns", value)
			if e != nil {
				return state, false, e
			}
			state.VcdModTime = parsed
		case "csv_mtime_ns":
			if value == "" {
				state.CsvModTime = 0
				continue
			}
			parsed, e := parse_int64("csv_mtime_ns", value)
			if e != nil {
				return state, false, e
			}
			state.CsvModTime = parsed
		default:
			return state, false, fmt.Errorf("unknown session value %s", name)
		}
	}
	if state.VcdFile == "" || state.CsvFile == "" {
		return state, false, fmt.Errorf("session is incomplete in %s", fname)
	}
	return state, true, nil
}

func save_trace_session(fname string, state traceSessionState) error {
	data, e := os.ReadFile(fname)
	if e != nil && !os.IsNotExist(e) {
		return fmt.Errorf("Cannot read %s: %w", fname, e)
	}
	updated := replaceSection(string(data), trace_session_section, state.format_session())
	e = os.WriteFile(fname, []byte(updated), 0664)
	if e != nil {
		return fmt.Errorf("Cannot write %s: %w", fname, e)
	}
	return nil
}

func (cmp *Comparator) save_options(fname string) error {
	data, e := os.ReadFile(fname)
	if e != nil && !os.IsNotExist(e) {
		return fmt.Errorf("Cannot read %s: %w", fname, e)
	}
	updated := replace_options_section(string(data), cmp.format_options())
	e = os.WriteFile(fname, []byte(updated), 0664)
	if e != nil {
		return fmt.Errorf("Cannot write %s: %w", fname, e)
	}
	return nil
}

func parse_section(data, section string) (map[string]string, error) {
	values := make(map[string]string, 4)
	in_section := false
	for line_no, line := range strings.Split(data, "\n") {
		line = strings.TrimSpace(strip_comment(line))
		if line == "" {
			continue
		}
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			in_section = strings.TrimSpace(line[1:len(line)-1]) == section
			continue
		}
		if !in_section {
			continue
		}
		name, value, found := strings.Cut(line, "=")
		if !found {
			return nil, fmt.Errorf("line %d is not an assignment", line_no+1)
		}
		name = strings.TrimSpace(name)
		value = strings.TrimSpace(value)
		value = strings.Trim(value, "\"'")
		values[name] = value
	}
	return values, nil
}

func parse_uint(name, value string) (uint64, error) {
	parsed, e := strconv.ParseUint(value, 0, 64)
	if e != nil {
		return 0, fmt.Errorf("cannot parse %s=%s", name, value)
	}
	return parsed, nil
}

func parse_int(name, value string) (int, error) {
	parsed, e := strconv.Atoi(value)
	if e != nil {
		return 0, fmt.Errorf("cannot parse %s=%s", name, value)
	}
	return parsed, nil
}

func parse_int64(name, value string) (int64, error) {
	parsed, e := strconv.ParseInt(value, 0, 64)
	if e != nil {
		return 0, fmt.Errorf("cannot parse %s=%s", name, value)
	}
	return parsed, nil
}

func (state traceSessionState) format_session() string {
	var b strings.Builder
	b.WriteString("[")
	b.WriteString(trace_session_section)
	b.WriteString("]\n")
	b.WriteString("saved_at = ")
	b.WriteString(strconv.FormatInt(state.SavedAt, 10))
	b.WriteString("\n")
	b.WriteString("vcd_file = ")
	b.WriteString(strconv.Quote(state.VcdFile))
	b.WriteString("\n")
	b.WriteString("csv_file = ")
	b.WriteString(strconv.Quote(state.CsvFile))
	b.WriteString("\n")
	b.WriteString("vcd_line = ")
	b.WriteString(strconv.Itoa(state.VcdLine))
	b.WriteString("\n")
	b.WriteString("csv_line = ")
	b.WriteString(strconv.Itoa(state.CsvLine))
	b.WriteString("\n")
	b.WriteString("vcd_time = ")
	b.WriteString(strconv.FormatUint(state.VcdTime, 10))
	b.WriteString("\n")
	b.WriteString("csv_time = ")
	b.WriteString(strconv.FormatUint(state.CsvTime, 10))
	b.WriteString("\n")
	b.WriteString("vcd_mtime_ns = ")
	b.WriteString(strconv.FormatInt(state.VcdModTime, 10))
	b.WriteString("\n")
	b.WriteString("csv_mtime_ns = ")
	b.WriteString(strconv.FormatInt(state.CsvModTime, 10))
	b.WriteString("\n")
	return b.String()
}

func parse_options_file(data string) ([]string, error) {
	options := make([]string, 0, 4)
	section_values, e := parse_section(data, trace_options_section)
	if e != nil {
		return nil, e
	}
	for name, value := range section_values {
		option, e := format_loaded_option(name, value)
		if e != nil {
			return nil, e
		}
		options = append(options, option)
	}
	return options, nil
}

func strip_comment(line string) string {
	if k := strings.Index(line, "#"); k != -1 {
		return line[0:k]
	}
	return line
}

func format_loaded_option(name, value string) (string, error) {
	name = strings.Trim(name, "\"'")
	value = strings.Trim(value, "\"'")
	switch name {
	case "retry", "color":
		parsed, e := strconv.ParseBool(value)
		if e != nil {
			return "", e
		}
		value = strconv.FormatBool(parsed)
	case "kmax", "vcd-lookahead", "mame-lookahead", "merge-window", "table-width":
		_, e := strconv.ParseUint(value, 0, 64)
		if e != nil {
			return "", e
		}
	default:
		return "", fmt.Errorf("unknown option %s", name)
	}
	return name + "=" + value, nil
}

func (cmp *Comparator) format_options() string {
	var b strings.Builder
	b.WriteString("[")
	b.WriteString(trace_options_section)
	b.WriteString("]\n")
	b.WriteString("retry = ")
	b.WriteString(strconv.FormatBool(cmp.retry_step))
	b.WriteString("\n")
	b.WriteString("vcd-lookahead = ")
	b.WriteString(strconv.Itoa(cmp.kmax))
	b.WriteString("\n")
	b.WriteString("mame-lookahead = ")
	b.WriteString(strconv.Itoa(cmp.mame_lookahead))
	b.WriteString("\n")
	b.WriteString("merge-window = ")
	b.WriteString(strconv.Itoa(cmp.merge_window))
	b.WriteString("\n")
	b.WriteString("table-width = ")
	b.WriteString(strconv.Itoa(cmp.table_width))
	b.WriteString("\n")
	b.WriteString("color = ")
	b.WriteString(strconv.FormatBool(cmp.color))
	b.WriteString("\n")
	return b.String()
}

func replaceSection(data, section_name, section string) string {
	data = strings.ReplaceAll(data, "\r\n", "\n")
	if strings.TrimSpace(data) == "" {
		return section
	}
	lines := strings.Split(data, "\n")
	start := -1
	end := len(lines)
	for k, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "[") && strings.HasSuffix(trimmed, "]") {
			if trimmed == "["+section_name+"]" {
				start = k
				continue
			}
			if start != -1 {
				end = k
				break
			}
		}
	}
	if start == -1 {
		prefix := strings.TrimRight(data, "\n")
		if prefix != "" {
			return prefix + "\n\n" + section
		}
		return section
	}
	replacement := strings.Split(strings.TrimRight(section, "\n"), "\n")
	out := append([]string{}, lines[:start]...)
	out = append(out, replacement...)
	out = append(out, lines[end:]...)
	return strings.TrimRight(strings.Join(out, "\n"), "\n") + "\n"
}

func replace_options_section(data, section string) string {
	return replaceSection(data, trace_options_section, section)
}

func formatSessionSavedAt(stamp int64) string {
	if stamp == 0 {
		return "(unknown)"
	}
	return time.Unix(0, stamp).Format(time.RFC3339Nano)
}
