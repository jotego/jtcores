package vcd

import (
	"fmt"
	"log"
	"slices"
	"strconv"
	"strings"
)

// keep making this class bigger as refactoring progress
type Comparator struct {
	alu_busy, str_busy, stack_busy *VCDSignal
	trace_seq, trace_valid         *VCDSignal
	kmax, mame_lookahead           int
	merge_window                   int
	table_width                    int
	color                          bool
	retry_step                     bool
	vcd                            *LnFile
	trace                          *TraceReader
	ignore                         boolSet
	last_missing                   *missingValue
	last_recovery                  recoveryResult
}

type mameSnapshot struct {
	line int
	data NameValue
}

type signalValue struct {
	value, value_hi uint64
}

type vcdSnapshot struct {
	line   int
	time   uint64
	alias  NameValue
	values map[*VCDSignal]signalValue
}

type syncCandidate struct {
	mame_index, vcd_index, vcd_end int
	merged                         bool
}

type missingValue struct {
	name  string
	value uint64
	line  int
}

type recoveryResult struct {
	found                    bool
	merged                   bool
	trace_line0, trace_line1 int
	vcd_line0, vcd_line1     int
	vcd_time0, vcd_time1     uint64
}

func NewComparator(ss VCDData, vcd *LnFile, trace *TraceReader) Comparator {
	var cmp Comparator
	cmp.alu_busy = ss.Get(find_similar("alu_busy", ss))
	cmp.str_busy = ss.Get(find_similar("str_busy", ss))
	cmp.stack_busy = ss.Get(find_similar("stack_busy", ss))
	cmp.trace_seq = find_optional_trace_signal(ss, "seq")
	cmp.trace_valid = find_optional_trace_signal(ss, "valid")
	cmp.kmax = 4
	cmp.mame_lookahead = 2
	cmp.merge_window = 2
	cmp.table_width = trace_table_width_default
	cmp.color = true
	cmp.vcd = vcd
	cmp.trace = trace
	return cmp
}

func find_optional_trace_signal(ss VCDData, name string) *VCDSignal {
	for _, each := range ss {
		vcd_name := strings.ToLower(each.Name)
		vcd_name = strings.TrimPrefix(vcd_name, "trace_")
		if vcd_name == name {
			return each
		}
	}
	return nil
}

func (cmp *Comparator) show_options() {
	fmt.Println("retry\t", cmp.retry_step)
	fmt.Println("kmax\t", cmp.kmax)
	fmt.Println("mame-lookahead\t", cmp.mame_lookahead)
	fmt.Println("merge-window\t", cmp.merge_window)
	fmt.Println("table-width\t", cmp.table_width)
	fmt.Println("color\t", cmp.color)
}

func (cmp *Comparator) set_option(name_value string) error {
	tokens := strings.Split(name_value, "=")
	name := tokens[0]
	if len(tokens) > 2 {
		return fmt.Errorf("Cannot parse assignment %s", name_value)
	}
	switch strings.ToLower(name) {
	case "retry":
		value, e := parse_bool_option(tokens)
		if e != nil {
			return fmt.Errorf("Cannot parse assignment %s", name_value)
		}
		cmp.retry_step = value
	case "color":
		value, e := parse_bool_option(tokens)
		if e != nil {
			return fmt.Errorf("Cannot parse assignment %s", name_value)
		}
		cmp.color = value
	case "mame-lookahead":
		return cmp.set_positive_int_option(name, tokens, &cmp.mame_lookahead, 1)
	case "vcd-lookahead", "kmax":
		return cmp.set_positive_int_option(name, tokens, &cmp.kmax, 2)
	case "merge-window":
		return cmp.set_positive_int_option(name, tokens, &cmp.merge_window, 1)
	case "table-width":
		return cmp.set_positive_int_option(name, tokens, &cmp.table_width, trace_table_width_min)
	default:
		return fmt.Errorf("Unknown option %s", name)
	}
	return nil
}

func parse_bool_option(tokens []string) (bool, error) {
	if len(tokens) == 1 {
		return true, nil
	}
	switch strings.ToLower(tokens[1]) {
	case "false", "0":
		return false, nil
	case "true", "1":
		return true, nil
	default:
		return false, fmt.Errorf("bad boolean")
	}
}

func (cmp *Comparator) set_positive_int_option(name string, tokens []string, dst *int, min int) error {
	if len(tokens) != 2 {
		return fmt.Errorf("Use option %s=<number>", name)
	}
	value, e := strconv.ParseUint(tokens[1], 0, 64)
	if e != nil {
		return fmt.Errorf("Cannot parse assignment %s=%s", name, tokens[1])
	}
	if int(value) < min {
		return fmt.Errorf("%s must be >= %d", name, min)
	}
	*dst = int(value)
	return nil
}

func (cmp *Comparator) searchDiff(sim_st *SimState, mame_st *MAMEState) {
	if mame_st.data == nil || len(mame_st.data) == 0 {
		first, ok := cmp.trace.Next()
		if !ok {
			fmt.Printf("Trace EOF\n")
			return
		}
		mame_st.data = first.Data
		mame_st.asm = first.Asm
	}
	var good bool
	tvcd := cmp.vcd.time
	var div_time uint64
main_loop:
	for {
		_, good = cmp.nxTraceChange(mame_st)
		if !good {
			break
		}
		div_time = cmp.vcd.time
		diff := cmp.diff(mame_st, "", false)
		if diff == 0 && mame_st.asm == "" {
			continue
		}
		if cmp.findSyncCandidate(sim_st, mame_st) {
			cmp.print_recovery()
			continue main_loop
		} else {
			good = false
			break
		}
	}
	fmt.Printf("+%s\n", formatTime(cmp.vcd.time-tvcd))
	// display the difference
	cmp.diff(mame_st, fmt.Sprintf("trace at %d - vcd time %s (diverged at %s)",
		cmp.trace.line, formatTime(cmp.vcd.time), formatTime(div_time)), true)
	cmp.print_missing()
}

func (cmp *Comparator) findSyncCandidate(sim_st *SimState, mame_st *MAMEState) bool {
	trace_line0 := cmp.trace.line
	trace_time0 := cmp.trace.time
	vcd0 := cmp.snapshot_vcd(sim_st, mame_st.alias)
	mame0 := mameSnapshot{line: trace_line0, data: copy_namevalue(mame_st.data)}
	mames := cmp.collect_mame_window(mame_st, mame0)
	vcds := cmp.collect_vcd_window(sim_st, mame_st.alias, vcd0)
	candidate, found := cmp.select_candidate(mame_st, mames, vcds)
	cmp.last_missing = cmp.find_missing_value(mame_st, mames, vcds)
	cmp.last_recovery = recoveryResult{}
	if !found {
		cmp.restore_mame(mame_st, mame0, trace_time0)
		cmp.restore_vcd(vcd0)
		return false
	}
	ms := mames[candidate.mame_index]
	vs := vcds[candidate.vcd_end]
	cmp.restore_mame(mame_st, ms, trace_time0)
	cmp.restore_vcd(vs)
	cmp.last_recovery = recoveryResult{
		found:       true,
		merged:      candidate.merged,
		trace_line0: trace_line0,
		trace_line1: ms.line,
		vcd_line0:   vcd0.line,
		vcd_line1:   vs.line,
		vcd_time0:   vcd0.time,
		vcd_time1:   vs.time,
	}
	return true
}

func (cmp *Comparator) collect_mame_window(mame_st *MAMEState, first mameSnapshot) []mameSnapshot {
	mames := []mameSnapshot{first}
	for k := 0; k < cmp.mame_lookahead; k++ {
		_, ok := cmp.nxTraceChange(mame_st)
		if !ok {
			break
		}
		mames = append(mames, mameSnapshot{line: cmp.trace.line, data: copy_namevalue(mame_st.data)})
	}
	return mames
}

func (cmp *Comparator) collect_vcd_window(sim_st *SimState, mame_alias mameAlias, first vcdSnapshot) []vcdSnapshot {
	vcds := []vcdSnapshot{first}
	for k := 0; k < cmp.kmax; k++ {
		_, ok := cmp.nxVCDChange(sim_st, mame_alias)
		if !ok {
			break
		}
		vcds = append(vcds, cmp.snapshot_vcd(sim_st, mame_alias))
	}
	return vcds
}

func (cmp *Comparator) select_candidate(mame_st *MAMEState, mames []mameSnapshot, vcds []vcdSnapshot) (syncCandidate, bool) {
	for mi, ms := range mames {
		for vi, vs := range vcds {
			if cmp.snapshot_diff(mame_st, ms.data, vs.alias) == 0 {
				return syncCandidate{mame_index: mi, vcd_index: vi, vcd_end: vi}, true
			}
		}
	}
	for mi, ms := range mames {
		for vi := range vcds {
			last := vi + cmp.merge_window
			if last > len(vcds) {
				last = len(vcds)
			}
			for ve := vi + 1; ve < last; ve++ {
				if cmp.merged_match(mame_st, ms.data, vcds[vi:ve+1]) {
					return syncCandidate{mame_index: mi, vcd_index: vi, vcd_end: ve, merged: true}, true
				}
			}
		}
	}
	return syncCandidate{}, false
}

func (cmp *Comparator) snapshot_diff(mame_st *MAMEState, data, alias_values NameValue) int {
	d := 0
	for name, value := range data {
		if !cmp.compare_name(mame_st, name, value, alias_values) {
			d++
		}
	}
	return d
}

func (cmp *Comparator) merged_match(mame_st *MAMEState, data NameValue, vcds []vcdSnapshot) bool {
	for name, value := range data {
		if cmp.skip_name(mame_st, name) {
			continue
		}
		found := false
		for _, vs := range vcds {
			if cmp.value_matches(mame_st, name, value, vs.alias) {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}
	return true
}

func (cmp *Comparator) compare_name(mame_st *MAMEState, name string, value uint64, alias_values NameValue) bool {
	if cmp.skip_name(mame_st, name) {
		return true
	}
	return cmp.value_matches(mame_st, name, value, alias_values)
}

func (cmp *Comparator) skip_name(mame_st *MAMEState, name string) bool {
	if name == "PC" || cmp.ignore.IsSet(name) {
		return true
	}
	p, _ := mame_st.alias[name]
	return p == nil
}

func (cmp *Comparator) value_matches(mame_st *MAMEState, name string, value uint64, alias_values NameValue) bool {
	vcd_value, found := alias_values[name]
	if !found {
		return false
	}
	mask, _ := mame_st.mask[name]
	return (vcd_value | mask) == (value | mask)
}

func (cmp *Comparator) find_missing_value(mame_st *MAMEState, mames []mameSnapshot, vcds []vcdSnapshot) *missingValue {
	for _, ms := range mames {
		names := sorted_names(ms.data)
		for _, name := range names {
			if cmp.skip_name(mame_st, name) {
				continue
			}
			found := false
			for _, vs := range vcds {
				if cmp.value_matches(mame_st, name, ms.data[name], vs.alias) {
					found = true
					break
				}
			}
			if !found {
				return &missingValue{name: name, value: ms.data[name], line: ms.line}
			}
		}
	}
	return nil
}

func (cmp *Comparator) snapshot_vcd(sim_st *SimState, mame_alias mameAlias) vcdSnapshot {
	values := make(map[*VCDSignal]signalValue, len(sim_st.data))
	for _, sig := range sim_st.data {
		values[sig] = signalValue{value: sig.Value, value_hi: sig.ValueHi}
	}
	alias_values := make(NameValue, len(mame_alias))
	for name, sig := range mame_alias {
		if sig != nil {
			alias_values[name] = sig.FullValue()
		}
	}
	return vcdSnapshot{line: cmp.vcd.line, time: cmp.vcd.time, alias: alias_values, values: values}
}

func (cmp *Comparator) restore_mame(mame_st *MAMEState, snap mameSnapshot, time uint64) {
	mame_st.data = copy_namevalue(snap.data)
	mame_st.asm = ""
	if cmp.trace.line != snap.line {
		cmp.trace.RewindTo(snap.line, time)
		cmp.trace.previous = copy_namevalue(snap.data)
	}
	cmp.trace.time = time
}

func (cmp *Comparator) restore_vcd(snap vcdSnapshot) {
	for sig, value := range snap.values {
		sig.Value = value.value
		sig.ValueHi = value.value_hi
	}
	if cmp.vcd.line != snap.line {
		cmp.vcd.RewindTo(snap.line, snap.time)
	}
	cmp.vcd.time = snap.time
}

func (cmp *Comparator) print_recovery() {
	if !Verbose || !cmp.last_recovery.found {
		return
	}
	match_type := "exact"
	if cmp.last_recovery.merged {
		match_type = "merged"
	}
	fmt.Printf("Trace recovered by %s match: MAME +%d lines, VCD +%d lines (%s)\n",
		match_type,
		cmp.last_recovery.trace_line1-cmp.last_recovery.trace_line0,
		cmp.last_recovery.vcd_line1-cmp.last_recovery.vcd_line0,
		formatTime(cmp.last_recovery.vcd_time1-cmp.last_recovery.vcd_time0))
}

func (cmp *Comparator) print_missing() {
	if cmp.last_missing == nil {
		return
	}
	fmt.Printf("MAME value not found in VCD look-ahead: %s=%X at trace line %d\n",
		cmp.last_missing.name, cmp.last_missing.value, cmp.last_missing.line)
}

func copy_namevalue(src NameValue) NameValue {
	dst := make(NameValue, len(src))
	for name, value := range src {
		dst[name] = value
	}
	return dst
}

func sorted_names(data NameValue) []string {
	names := make([]string, 0, len(data))
	for name := range data {
		names = append(names, name)
	}
	slices.Sort(names)
	return names
}

func (cmp *Comparator) matchTrace(sim_st *SimState,
	mame_st *MAMEState, mame_alias mameAlias) bool {
	var good, matched bool
	total_lines := 0
	time0 := cmp.trace.time
	for {
		lines := 0
		lines, good = cmp.nxVCDChange(sim_st, mame_alias)
		total_lines += lines
		matched = cmp.diff(mame_st, "", false) == 0
		if !good || matched {
			break
		}
	}
	// display the difference
	if !matched {
		fmt.Printf("Impossible to match VCD to MAME")
		cmp.diff(mame_st, fmt.Sprintf("sim at time %d", cmp.trace.time), true)
	} else {
		time1 := cmp.trace.time
		delta := time1 - time0
		fmt.Printf("MAME trace matched by advancing the VCD by %d lines (%s)\n",
			total_lines, formatTime(delta))
	}
	return matched
}

func (cmp *Comparator) nxVCDChange(sim_st *SimState, mame_alias mameAlias) (int, bool) {
	l0 := cmp.vcd.line
	changed := false
	trace_event := cmp.trace_seq != nil || cmp.trace_valid != nil
	irq_bsy := sim_st.data.Get("TOP.game_test.u_game.u_game.u_main.u_cpu.u_ctrl.u_ucode.irq_bsy")
	was_irq := irq_bsy != nil && irq_bsy.Value != 0
	was_stack := cmp.stack_busy != nil && cmp.stack_busy.Value != 0
	was_alu := cmp.alu_busy != nil && cmp.alu_busy.Value != 0
	was_str := cmp.str_busy != nil && cmp.str_busy.Value != 0
	for cmp.vcd.Scan() {
		txt := cmp.vcd.Text()
		if txt[0] == '#' {
			cmp.vcd.time, _ = strconv.ParseUint(txt[1:], 10, 64)
			if changed {
				break
			} else {
				continue
			}
		}
		parsed := parseValue(txt)
		if !parsed.ok {
			continue
		}
		assign(parsed, sim_st.data)
		p, _ := sim_st.data[parsed.alias]
		if p == nil {
			log.Fatal("Error: bad pointer to VCDSignal\n")
		}
		// Skip busy sections
		if cmp.alu_busy != nil && cmp.alu_busy.Value == 1 {
			was_alu = true
			continue
		} else if was_alu {
			changed = true
			break
		}
		if cmp.str_busy != nil && cmp.str_busy.Value == 1 {
			was_str = true
			continue
		} else if was_str {
			changed = true
			break
		}
		if cmp.stack_busy != nil && cmp.stack_busy.Value == 1 {
			was_stack = true
			continue
		} else if was_stack {
			changed = true
			break
		}
		if irq_bsy != nil && irq_bsy.Value == 1 {
			if !was_irq {
				was_irq = true
				fmt.Println("VCD enters IRQ")
			}
			continue // fly over the interrupt
		} else if was_irq {
			changed = true
			break
		}
		if trace_event {
			if p == cmp.trace_seq {
				changed = true
			} else if p == cmp.trace_valid && p.Value != 0 {
				changed = true
			}
			continue
		}
		for name, v := range mame_alias {
			if cmp.ignore.IsSet(name) {
				continue
			}
			if p == v {
				changed = true
				// fmt.Printf("%s=%X\n",p.FullName(),p.Value)
				break
			}
		}
	}
	if !changed {
		fmt.Printf("Reached EOF of VCD file after ")
	}
	return cmp.vcd.line - l0, changed
}

func (cmp *Comparator) nxTraceChange(mame_st *MAMEState) (NameValue, bool) {
	for {
		next, ok := cmp.trace.Next()
		if !ok {
			fmt.Printf("Trace EOF")
			return mame_st.data, false
		}
		old := mame_st.data
		if old == nil {
			old = make(NameValue)
		}
		mame_st.data = next.Data
		mame_st.asm = next.Asm
		if next.Asm != "" {
			return mame_st.data, true
		}
		for name := range mame_st.alias {
			if mame_st.data[name] != old[name] {
				return mame_st.data, true
			}
		}
	}
}

func (cmp *Comparator) matchVCD(sim_st *SimState, mame_st *MAMEState) bool {
	if mame_st.data == nil || len(mame_st.data) == 0 {
		first, ok := cmp.trace.Next()
		if !ok {
			fmt.Printf("Trace EOF\n")
			return false
		}
		mame_st.data = first.Data
		mame_st.asm = first.Asm
	}
	line0 := cmp.trace.line
	var good, matched bool
	for {
		mame_st.data, good = cmp.nxTraceChange(mame_st)
		matched = cmp.diff(mame_st, "", false) == 0
		if !good || matched {
			break
		}
	}
	// display the difference
	if !matched {
		fmt.Printf("Impossible to match MAME to VCD")
		cmp.diff(mame_st, fmt.Sprintf("trace at %d", cmp.trace.line), true)
	} else {
		fmt.Printf("VCD matched by advancing MAME trace(+ %d lines)\n", cmp.trace.line-line0)
	}
	return matched
}

func (cmp *Comparator) diff(st *MAMEState, context string, verbose bool) int {
	d := 0
	var diffs []string
	for name, value := range st.data {
		if name == "PC" {
			continue
		}
		p, _ := st.alias[name]
		if p == nil {
			continue
		}
		toignore := cmp.ignore.IsSet(name)
		mask, _ := st.mask[name]
		equal := (p.FullValue() | mask) == (value | mask)
		if equal && toignore {
			cmp.ignore.Remove(name)
			fmt.Printf("%s taken out of the ignore list\n", name)
		}
		if !equal && !toignore {
			if verbose {
				if diffs == nil {
					diffs = make([]string, 0, 1)
				}
				diffs = append(diffs, name)
			}
			d++
		}
		if p.Name == "irq_bsy" && p.Value == 1 {
			return 0
		}
	}
	if verbose && diffs != nil {
		if context != "" {
			fmt.Println(context)
		}
		fmt.Println("\t     MAME  -   SIM")
		slices.Sort(diffs)
		for _, name := range diffs {
			p, _ := st.alias[name]
			if p == nil {
				continue
			}
			fmt.Printf("\t%-4s %4X <-> %4X (%s.%s)\n", name, st.data[name], p.FullValue(), p.Scope, p.Name)
		}
	}
	return d
}
