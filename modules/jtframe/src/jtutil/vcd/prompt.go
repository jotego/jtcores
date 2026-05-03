/*  This file is part of JTCORES.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Date: 4-1-2025 */

package vcd

import (
	"bufio"
	"fmt"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/PaesslerAG/gval"
	"golang.org/x/term"

	"jtutil/prompt"
)

// VCDPrompt provides an interactive shell for comparing VCD and MAME trace data.
const CMD_HELP = `
a,alias             links a MAME variable name with a signal name in the VCD
                    alias mame-name=vcd-name        declares an alias
                    alias clear                     deletes all aliases
                    alias -foo                      deletes the alias "foo"
c,concat,cat        concat two signals: concat main-signal appended-signal
b,browse            browse MAME trace values with cursor keys
d,diff              show differences between MAME and simulation at current time
ds,display          display simulation signals at current time
dt,display-trace    display MAME trace values around current time
f,frame #number     advances the simulation upto the given frame
g,go                compare MAME and simulation until a discrepancy cannot be resolved
?,help              produces this help screen
                    See man jtutil-trace for detailed command and signal notes.
h,hierarchy         shows the signal hierarchy in the simulation
i,ignore foo boo    ignores the given MAME variables in comparison. Shows the
                    list of ignored variables if called without names
s,scope             prints current scope or sets a new scope
kmax [newmax]       sets the maximum number of VCD cycles to advance before the
                    comparison is deemed bad.
save                saves current VCD/CSV offsets for session restore
restore              restores the last saved VCD/CSV offsets from .jtutil.toml
mask name FF        sets bit masks for signals. Bits set at 1 will be ignored.
match-vcd           advances the MAME trace until it matches the VCD data
match-trace         advances the VCD stream until it matches the MAME trace data
mt,mt-trace foo     advances the MAME trace until the given condition is met
                    start hex numbers with $ for comparison
mv,mv-vcd foo       advances the VCD stream until the given condition is met
o,option foo        sets processing options
    foo[=false/true]
    retry               when a difference is found, a step-trace is executed
                        if there are no differences, the comparison continues
    mame-lookahead=n    MAME states to search while recovering a mismatch
    vcd-lookahead=n     VCD states to search while recovering a mismatch
    merge-window=n      adjacent VCD states allowed to satisfy one MAME state
    color               highlights trace display changes
    table-width=n       trace display/browse table width (default 120)
    Options are saved in .jtutil.toml in the current folder
p,print             evaluates an expression. Use to test conditions
q,quit              quits the program
r,reset             rewinds VCD and trace inputs to the initial comparison point
.,source foo        executes the commands in the given file
s,step              forwards simulation by one relevant change
set vcd-name=value  alters the value of a simulation signal
st,step-trace       forwards MAME trace by one relevant change`

type VCDPrompt struct {
	vcd              *LnFile
	trace            *TraceReader
	ss               VCDData
	mameAlias        mameAlias
	tokens           []string
	mame_st          *MAMEState
	fses             *os.File
	scn              prompt.Source
	sources          []prompt.Source
	cmp              Comparator
	simState         *SimState
	scope            string
	hier             *Hierarchy
	pcName           string
	reset_vcd        vcdSnapshot
	reset_trace_line int
	reset_trace_time uint64
}

// NewVCDPrompt returns a configured VCDPrompt for the supplied VCD/trace input.
func NewVCDPrompt(vcd *LnFile, trace *TraceReader, ss VCDData, mame_alias mameAlias) *VCDPrompt {
	return &VCDPrompt{
		vcd:       vcd,
		trace:     trace,
		ss:        ss,
		mameAlias: mame_alias,
	}
}

// Run starts the interactive REPL used to inspect and step through VCD/trace sync.
func (p *VCDPrompt) Run() {
	fses, e := os.Create("trace.ses") // echo all session commands to a file
	defer fses.Close()
	must(e)
	// Read from stdin initially
	p.sources = make([]prompt.Source, 1)
	if term.IsTerminal(int(os.Stdin.Fd())) {
		p.sources[0] = prompt.NewPromptSource(prompt.NewTerminal(os.Stdin, os.Stdout, "> "))
	} else {
		p.sources[0] = prompt.NewScannerSource(bufio.NewScanner(os.Stdin), nil)
	}
	p.fses = fses
	p.scn = p.sources[len(p.sources)-1]
	p.pcName = find_similar("pc", p.ss)
	p.cmp = NewComparator(p.ss, p.vcd, p.trace)
	if e := p.cmp.load_options(jtutil_config_name); e != nil {
		fmt.Println(e)
	}

	p.scope = p.findCommonScope()
	fmt.Printf("At scope %s\n", p.scope)
	p.hier = GenerateHierarchy(p.ss)
	p.mame_st = &MAMEState{alias: p.mameAlias, mask: make(NameValue)}
	p.simState = &SimState{data: p.ss}
	p.cmp.ignore = *newBoolSet(p.mame_st)
	p.set_reset_point()
	p.promptLoop()
	fmt.Println()
}

func (p *VCDPrompt) promptLoop() {
	for {
		lt, ok, err := p.scn.ReadLine()
		if err != nil {
			fmt.Println(err)
			break
		}
		if !ok {
			if len(p.sources) > 1 {
				if e := p.scn.Close(); e != nil {
					fmt.Println(e)
				}
				p.sources = p.sources[0 : len(p.sources)-1]
				p.scn = p.sources[len(p.sources)-1]
				continue
			}
			break
		}
		fmt.Fprintln(p.fses, lt)
		if k := strings.Index(lt, "#"); k != -1 {
			lt = lt[0:k]
		}
		p.tokens = strings.Fields(lt)
		if len(p.tokens) == 0 {
			continue
		}
		if p.scn != p.sources[0] {
			fmt.Println(">", lt)
		} // echo if we are parsing a file
		if p.handle_command() {
			continue
		}
		return
	}
	fmt.Println()
}

func (p *VCDPrompt) handle_command() bool {
	switch p.tokens[0] {
	case "g", "go":
		p.cmp.searchDiff(p.simState, p.mame_st)
	case "ds", "display":
		{
			p.display()
		}
	case "d", "diff":
		p.cmd_diff()
	case "dt", "display-trace":
		p.display_trace()
	case "b", "browse":
		p.browse_trace()
	case "a", "alias":
		p.aliasCmd()
	case "c", "concat":
		return p.concatCmd()
	case "f", "frame":
		{
			if len(p.tokens) != 2 {
				fmt.Println("Wrong arguments. Use frame <number>")
				return true
			}
			limit, _ := strconv.ParseUint(p.tokens[1], 0, 64)
			p.mvFrame(limit)
		}
	case "h", "hierarchy":
		{
			fmt.Printf("VCD at line %d (time %d ns)\n", p.vcd.line, p.vcd.time/1000)
			p.hier.Dump("")
		}
	case "i", "ignore":
		return p.ignoreCmd()
	case "kmax":
		return p.kmaxCmd()
	case "mask":
		return p.maskCmd()
	case "q", "quit":
		return false
	case "r", "reset":
		p.resetCmd()
	case "scope":
		return p.scopeCmd()
	case "o", "option":
		return p.optionCmd()
	case "save":
		return p.saveSession()
	case "restore":
		return p.restoreSession()
	case "p", "print":
		return p.printCmd()
	case "set":
		return p.setCmd()
	case ".", "source":
		return p.sourceCmd()
	case "s", "step":
		{
			p.cmp.nxVCDChange(p.simState, p.mame_st.alias)
			p.cmd_diff()
		}
	case "st", "step-trace":
		{
			old_data := p.mame_st.data
			var good bool
			p.mame_st.data, good = p.cmp.nxTraceChange(p.mame_st)
			if good {
				p.mame_st.data.showDiff(old_data)
				p.cmd_diff()
			}
		}
	case "mv", "mv-vcd":
		{
			if len(p.tokens) == 1 {
				fmt.Printf("Use mvvcd signal=value")
				return true
			}
			expr := replaceHex(strings.Join(p.tokens[1:], ""))
			fmt.Println(expr)
			p.mvVCD(expr)
		}
	case "mt", "mv-trace":
		return p.mvTraceCmd()
	case "match-vcd":
		{ // moves the trace until it matches the VCD data
			if len(p.tokens) != 1 {
				fmt.Printf("match-vcd does not take arguments\n")
				return true
			}
			p.cmp.matchVCD(p.simState, p.mame_st)
		}
	case "match-trace":
		{ // moves the VCD until it matches MAME data
			if len(p.tokens) != 1 {
				fmt.Printf("match-trace does not take arguments\n")
				return true
			}
			p.cmp.matchTrace(p.simState, p.mame_st, p.mameAlias)
		}
	case "?", "help":
		fmt.Println(CMD_HELP)
	default:
		fmt.Println("Unknown command ", p.tokens[0])
	}
	return true
}

func (p *VCDPrompt) concatCmd() bool {
	if len(p.tokens) != 3 {
		fmt.Println("Wrong arguments. Use cat main-signal appended-signal")
		return true
	}

	p1 := p.ss.Get(p.tokens[1])
	p2 := p.ss.Get(p.tokens[2])
	if p1 == nil {
		fmt.Printf("Cannot find %s\n", p.tokens[1])
		return true
	}
	if p2 == nil {
		fmt.Printf("Cannot find %s\n", p.tokens[2])
		return true
	}
	p1.Concat.p = p2
	p1.Concat.at = p1.MSB + 1
	return true
}

func (p *VCDPrompt) ignoreCmd() bool {
	if p.mame_st.data == nil || len(p.mame_st.data) == 0 {
		fmt.Printf("Start running a trace first\n")
		return true
	}
	if len(p.tokens) == 1 {
		p.cmp.ignore.Dump()
	} else {
		p.cmp.ignore.Update(p.tokens[1:]...)
	}
	return true
}

func (p *VCDPrompt) kmaxCmd() bool {
	if len(p.tokens) == 1 {
		fmt.Printf("KMAX=%d\n", p.cmp.kmax)
		return true
	}
	if len(p.tokens) != 2 {
		fmt.Println("Wrong arguments. Use kmax <number>")
		return true
	}
	aux, _ := strconv.ParseUint(p.tokens[1], 0, 64)
	p.cmp.kmax = int(aux)
	if p.cmp.kmax < 2 {
		fmt.Printf("Setting KMAX to minimum (2)")
		p.cmp.kmax = 2
	}
	p.save_options()
	return true
}

func (p *VCDPrompt) maskCmd() bool {
	if len(p.tokens) == 1 {
		if len(p.mame_st.mask) == 0 {
			fmt.Println("No masks defined")
		} else {
			for k, v := range p.mame_st.mask {
				fmt.Printf("%-10s %02X\n", k, v)
			}
		}
		return true
	}
	if len(p.tokens) != 3 {
		fmt.Println("Wrong arguments. Use mask <signal name> <hex mask>")
		fmt.Println("Use mask without arguments to show the current mask set")
		return true
	}
	mask, e := strconv.ParseUint(p.tokens[2], 16, 64)
	if e != nil {
		fmt.Println(e)
		return true
	}
	name := p.tokens[1]
	_, found := p.mame_st.data[name]
	if !found {
		fmt.Printf("Signal %s not found in MAME trace\n", name)
		return true
	}
	p.mame_st.mask[name] = mask
	return true
}

func (p *VCDPrompt) scopeCmd() bool {
	switch len(p.tokens) {
	case 1:
		fmt.Println(p.scope)
	case 2:
		{
			p.scope = p.tokens[1]
			fmt.Println(p.scope)
		}
	default:
		fmt.Println("Wrong number of arguments")
	}
	return true
}

func (p *VCDPrompt) optionCmd() bool {
	if len(p.tokens) == 1 {
		p.cmp.show_options()
		return true
	}
	if len(p.tokens) > 2 {
		fmt.Println("Too many options. Use: option foo[=true/false]")
		return true
	}
	e := p.cmp.set_option(p.tokens[1])
	p.print_error(e)
	if e == nil {
		p.save_options()
	}
	return true
}

func (p *VCDPrompt) save_options() {
	e := p.cmp.save_options(jtutil_config_name)
	if e != nil {
		fmt.Println(e)
	}
}

func (p *VCDPrompt) saveSession() bool {
	if p.vcd == nil || p.trace == nil {
		fmt.Println("Missing input files")
		return true
	}
	vcdModTime, e := file_mod_time(p.vcd.fname)
	if e != nil {
		fmt.Println(e)
		return true
	}
	traceModTime, e := file_mod_time(p.trace.fname)
	if e != nil {
		fmt.Println(e)
		return true
	}
	state := traceSessionState{
		SavedAt:    time.Now().UnixNano(),
		VcdFile:    p.vcd.fname,
		CsvFile:    p.trace.fname,
		VcdLine:    p.vcd.line,
		CsvLine:    p.trace.line,
		VcdTime:    p.vcd.time,
		CsvTime:    p.trace.time,
		VcdModTime: vcdModTime,
		CsvModTime: traceModTime,
	}
	e = save_trace_session(jtutil_config_name, state)
	if e != nil {
		fmt.Println(e)
		return true
	}
	fmt.Printf("Session saved to %s (%s)\n", jtutil_config_name, formatSessionSavedAt(state.SavedAt))
	return true
}

func (p *VCDPrompt) restoreSession() bool {
	state, found, e := load_trace_session(jtutil_config_name)
	if e != nil {
		fmt.Println(e)
		return true
	}
	if !found {
		fmt.Println("No saved session in", jtutil_config_name)
		return true
	}
	p.warn_session_file_changes(state)
	if e := p.restoreVCDSession(state); e != nil {
		fmt.Println(e)
		return true
	}
	if e := p.restoreTraceSession(state); e != nil {
		fmt.Println(e)
		return true
	}
	p.set_reset_point()
	p.cmp.last_missing = nil
	p.cmp.last_recovery = recoveryResult{}
	if state.SavedAt == 0 {
		fmt.Println("Session restored")
	} else {
		fmt.Printf("Session restored (%s)\n", formatSessionSavedAt(state.SavedAt))
	}
	return true
}

func file_mod_time(fname string) (int64, error) {
	info, e := os.Stat(fname)
	if e != nil {
		return 0, e
	}
	return info.ModTime().UnixNano(), nil
}

func (p *VCDPrompt) warn_session_file_changes(state traceSessionState) {
	if state.VcdFile != p.vcd.fname {
		fmt.Printf("WARNING: saved VCD file %s differs from current %s\n", state.VcdFile, p.vcd.fname)
	}
	if state.CsvFile != p.trace.fname {
		fmt.Printf("WARNING: saved CSV file %s differs from current %s\n", state.CsvFile, p.trace.fname)
	}
	if state.VcdModTime != 0 {
		current, e := file_mod_time(state.VcdFile)
		if e != nil {
			fmt.Printf("WARNING: cannot check VCD modification time: %v\n", e)
		} else if current != state.VcdModTime {
			fmt.Printf("WARNING: VCD file changed since session save: %s -> %s\n",
				formatSessionSavedAt(state.VcdModTime),
				formatSessionSavedAt(current))
		}
	}
	if state.CsvModTime != 0 {
		current, e := file_mod_time(state.CsvFile)
		if e != nil {
			fmt.Printf("WARNING: cannot check CSV modification time: %v\n", e)
		} else if current != state.CsvModTime {
			fmt.Printf("WARNING: CSV file changed since session save: %s -> %s\n",
				formatSessionSavedAt(state.CsvModTime),
				formatSessionSavedAt(current))
		}
	}
}

func (p *VCDPrompt) restoreVCDSession(state traceSessionState) error {
	if !p.vcd.RewindTo(0, 0) {
		return fmt.Errorf("Cannot rewind VCD to line 0")
	}
	for p.vcd.line < state.VcdLine {
		if !p.vcd.Scan() {
			return fmt.Errorf("Cannot restore VCD to line %d", state.VcdLine)
		}
		line := p.vcd.Text()
		if line == "" {
			continue
		}
		if line[0] == '#' {
			timeStamp, e := strconv.ParseUint(line[1:], 10, 64)
			if e == nil {
				p.vcd.time = timeStamp
			}
			continue
		}
		parsed := parseValue(line)
		if parsed.ok {
			assign(parsed, p.simState.data)
		}
	}
	p.vcd.time = state.VcdTime
	return nil
}

func (p *VCDPrompt) restoreTraceSession(state traceSessionState) error {
	if !p.trace.RewindTo(state.CsvLine, state.CsvTime) {
		return fmt.Errorf("Cannot restore CSV to line %d", state.CsvLine)
	}
	if state.CsvLine <= 1 {
		p.mame_st.data = nil
		p.mame_st.asm = ""
		p.trace.previous = nil
		p.trace.time = state.CsvTime
		return nil
	}
	row, ok := p.trace.parseLine(p.trace.Text())
	if !ok {
		return fmt.Errorf("Cannot restore trace line %d", state.CsvLine)
	}
	p.trace.previous = copy_namevalue(row.Data)
	p.mame_st.data = copy_namevalue(row.Data)
	p.mame_st.asm = row.Asm
	p.trace.time = state.CsvTime
	return nil
}

func (p *VCDPrompt) set_reset_point() {
	p.reset_vcd = p.cmp.snapshot_vcd(p.simState, p.mameAlias)
	p.reset_trace_line = p.trace.line
	p.reset_trace_time = p.trace.time
}

func (p *VCDPrompt) resetCmd() {
	p.cmp.restore_vcd(p.reset_vcd)
	p.trace.RewindTo(p.reset_trace_line, p.reset_trace_time)
	p.trace.time = p.reset_trace_time
	p.mame_st.data = nil
	p.mame_st.asm = ""
	p.cmp.last_missing = nil
	p.cmp.last_recovery = recoveryResult{}
	fmt.Println("Trace comparison reset")
}

func (p *VCDPrompt) mvTrace(expr string) bool {
	l0 := p.trace.line
	old_data := p.mame_st.data
	if p.mame_st.data == nil || len(p.mame_st.data) == 0 {
		first, ok := p.trace.Next()
		if !ok {
			fmt.Println("Trace EOF")
			return false
		}
		p.mame_st.data = first.Data
		p.mame_st.asm = first.Asm
	}
	for {
		p.mame_st.data["line"] = uint64(p.trace.line)
		v, e := gval.Evaluate(expr, p.mame_st.data)
		if e != nil {
			fmt.Println(e)
			break
		}
		f, fe := v.(bool)
		if fe {
			if f {
				fmt.Printf("Moved by %d lines\n", p.trace.line-l0)
				p.mame_st.data.showDiff(old_data)
				break
			}
		} else {
			fmt.Printf("Not a boolean expression\n")
			break
		}
		next, ok := p.trace.Next()
		if !ok {
			fmt.Println("Trace EOF")
			return false
		}
		p.mame_st.data = next.Data
		p.mame_st.asm = next.Asm
	}
	delete(p.mame_st.data, "line")
	return true
}

func (p *VCDPrompt) mvFrame(limit uint64) {
	var frame *VCDSignal
	for _, each := range p.simState.data {
		if each.Name == "frame_cnt" {
			frame = each
			break
		}
	}
	if p.simState.data == nil {
		fmt.Printf("frame_cnt signal not found in VCD\n")
		return
	}
	for frame.Value < limit && p.vcd.NextVCD(p.simState.data) {
	}
}

func (p *VCDPrompt) mvVCD(expr string) bool {
	t0 := p.vcd.time
	newline := false
	for {
		valueMap := HierValues(p.hier)
		valueMap["line"] = uint64(p.vcd.line)
		valueMap["time"] = p.vcd.time
		// add signals in scope
		if p.scope != "" {
			for _, each := range p.simState.data {
				if each.Scope == p.scope {
					valueMap[each.Name] = each.Value
				}
			}
		}
		v, e := gval.Evaluate(expr, valueMap)
		if e != nil {
			fmt.Println(e)
			break
		}
		f, fe := v.(bool)
		if fe {
			if f {
				if newline {
					fmt.Println()
				}
				fmt.Printf("+ %s\n", formatTime(p.vcd.time-t0))
				return true
			}
		} else {
			fmt.Printf("Not a boolean expression")
			return false
		}
		if !p.vcd.NextVCD(p.simState.data) {
			break
		}
		if p.vcd.time-t0 > 1000000000 { // 1ms
			fmt.Print(".")
			t0 = p.vcd.time
			newline = true
		}
	}
	if newline {
		fmt.Println()
	}
	fmt.Println("condition not found")
	return false
}

func (p *VCDPrompt) findCommonScope() string {
	scope := ""
	var tokens []string
	first := true
	for _, each := range p.ss {
		if first {
			scope = each.Scope
			if scope == "" {
				return ""
			}
			tokens = strings.Split(scope, ".")
			first = false
			continue
		}
		matched := false
		for k := len(tokens); k != 0; k-- {
			check := strings.Join(tokens[0:k], ".")
			check_len := len(check)
			if strings.HasPrefix(each.Scope, check) &&
				(len(each.Scope) == check_len ||
					(len(each.Scope) > check_len && each.Scope[check_len] == '.')) {
				scope = check
				tokens = strings.Split(scope, ".")
				matched = true
				break
			}
		}
		if !matched {
			return ""
		}
	}
	return scope
}

// t must be MAME-name=VCD-name
func (p *VCDPrompt) parseAlias(t []string) {
main_loop:
	for _, each := range t {
		if each[0] == '-' {
			// remove the alias
			delete(p.mame_st.alias, each[1:])
			continue
		}
		tokens := strings.Split(each, "=")
		if len(tokens) == 0 {
			continue
		}
		vcd_name := tokens[0]
		if len(tokens) == 2 {
			vcd_name = tokens[1]
		}
		for _, s := range p.ss {
			if s.Scope+"."+s.Name == vcd_name {
				p.mame_st.alias[tokens[0]] = s
				continue main_loop
			}
			if s.Name == vcd_name {
				p.mame_st.alias[tokens[0]] = s
			}
		}
		fmt.Printf("Cannot find VCD signal for %s\n", tokens[0])
	}
}

// display all signals, or only the ones with partial string matches in p.tokens[1:]
func (p *VCDPrompt) display() {
	fmt.Printf("Trace at line %d - VCD at line %d (time %s)\n",
		p.trace.line, p.vcd.line, formatTime(p.vcd.time))
	sorted := make([]struct {
		full string
		p    *VCDSignal
	}, len(p.simState.data))
	k := 0
	for _, each := range p.simState.data {
		sorted[k].p = each
		sorted[k].full = each.FullName()
		k++
	}
	sort.Slice(sorted, func(i, j int) bool { return strings.Compare(sorted[i].full, sorted[j].full) < 0 })
	var t []string
	if len(p.tokens) > 1 {
		t = p.tokens[1:]
	}
	for _, each := range sorted {
		print := t == nil
		if !print {
			for _, k := range t {
				if strings.Index(each.full, k) != -1 {
					print = true
					break
				}
			}
		}
		if print {
			each.p.Dump()
		}
	}
}

func (p *VCDPrompt) printCmd() bool {
	valueMap := HierValues(p.hier)
	expr := replaceHex(strings.Join(p.tokens[1:], ""))
	v, e := gval.Evaluate(expr, valueMap)
	if e != nil {
		fmt.Println(e)
		return true
	}
	fmt.Printf("%s=%X\n", expr, v)
	return true
}

func (p *VCDPrompt) setCmd() bool {
	if len(p.tokens) == 1 {
		fmt.Println("Use set vcd-name=value ...")
		return true
	}
	for k := 1; k < len(p.tokens); k++ {
		setSignal(p.tokens[k], p.hier)
	}
	return true
}

func (p *VCDPrompt) sourceCmd() bool {
	if len(p.tokens) == 1 {
		fmt.Println("Use `source filename`")
		return true
	}
	f, e := os.Open(p.tokens[1])
	if e != nil {
		fmt.Println(e)
		return true
	}
	p.scn = prompt.NewScannerSource(bufio.NewScanner(f), f)
	p.sources = append(p.sources, p.scn)
	return true
}

func (p *VCDPrompt) mvTraceCmd() bool {
	if len(p.tokens) == 1 {
		fmt.Printf("Use mvtrace signal=value")
		return true
	}
	expr := replaceHex(strings.Join(p.tokens[1:], ""))
	fmt.Println(expr)
	if !p.mvTrace(expr) {
		return false
	} // EOF
	return true
}

func (p *VCDPrompt) cmd_diff() {
	if p.cmp.diff(p.mame_st, fmt.Sprintf("trace at %d - vcd time %s", p.trace.line, formatTime(p.vcd.time)), true) == 0 {
		fmt.Printf("No differences\n")
	} else {
		extra := func(m, s, f string) {
			mame_pc, _ := p.mame_st.data[m]
			sig := p.ss.Get(s)
			var vcd_pc uint64
			if sig != nil {
				vcd_pc = sig.Value
			}
			if mame_pc != 0 || vcd_pc != 0 {
				fmt.Printf("\t%s="+f+" <-> "+f+"\n", m, mame_pc, vcd_pc)
			}
		}
		extra("PC", p.pcName, "%X")
		extra("frame_cnt", "TOP.game_test.frame_cnt", "'d%d")
	}
}

func (p *VCDPrompt) aliasCmd() {
	if len(p.tokens) == 1 {
		for k, each := range p.mame_st.alias {
			fmt.Printf("%s -> %s.%s\n", k, each.Scope, each.Name)
		}
		fmt.Printf("\nUse alias clear to delete all aliases\n")
		fmt.Printf("Use alias mame-name=vcd-name to declare a new alias")
		fmt.Printf("Use alias -name to delete one alias\n")
		return
	}
	if p.tokens[1] == "clear" {
		p.mame_st.alias = make(mameAlias)
	} else {
		p.parseAlias(p.tokens[1:])
	}
}

func (p *VCDPrompt) display_trace() {
	new_trace_display(p.trace, p.cmp.color, p.cmp.table_width).print()
}

func (p *VCDPrompt) browse_trace() {
	new_trace_browser(p.trace, p.cmp.color, p.cmp.table_width, os.Stdin, os.Stdout).run()
}

func (p *VCDPrompt) print_error(e error) {
	if e == nil {
		return
	}
	fmt.Println(e)
}
