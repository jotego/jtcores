/*  This file is part of JTFRAME.
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

package ucode

import (
	"bytes"
	"fmt"
	"html/template"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"sort"
	"strings"

	// "text/template"

	// "github.com/Masterminds/sprig/v3"
	"github.com/Masterminds/sprig"
	"gopkg.in/yaml.v2"	// v3 skips blank entries in a sequence. That ruins idle ucode cycles in the YAML. Stick to v2
)

var Args struct{
	Report, Verbose, List, GTKWave bool
	Output string
}

var reVars, reSp, reDig *regexp.Regexp

type UcOp struct {
	Name   string            `yaml:"name"`
	Op     int               `yaml:"op"`
	Mask   int               `yaml:"mask"`
	Cycles int               `yaml:"cycles"`
	Ctl    map[string]string `yaml:"ctl"`
}

type UcRange struct{
	Name string `yaml:"name"`
	Values []string `yaml:"values"`
}

type UcChunk struct {
	Seq   []string `yaml:"seq"`	    // sequence of microcode instructions
	// Decoded OP instructions:
	Mnemo []string `yaml:"mnemo"`   // if mnemo!=nil, the UcOp.Op field is used as Start
	// Procedures:
	Name  string   `yaml:"name"`    // if name!="", this is a procedure and it uses the Start field
	Start int      `yaml:"start"`   // ucode address at which the procedure starts
	NoAuto bool	   `yaml:"no_auto"` // only for procedures: disables automatic address assignment
	Cycles int	   `yaml:"cycles"`  // used for procedures
	// Template procedures
	Range []UcRange `yaml:"range"` // it will generate all permutations using these variables
	// private
	cycles int
	local map[string]string			// local variables defined from the range
}

type UcDesc struct {
	Incs []string `yaml:"include"`
	Cfg struct {
		EntryLen int `yaml:"entry_len"`
		Entries  int `yaml:"entries"`
		CycleK   int `yaml:"cycle_factor"`
		Implicit bool `yaml:"implicit"`
		BusError string `yaml:"bus_error"`
		Latch    bool	`yaml:"latch_ucode"`
		IgnoreCycles bool `yaml:"ignore_cycles"`		// use to indicate that cycle information is still not ready and should not be used
		Auto struct { // Automatic assignment of start address to procedures
			Min int   // base address at which assignment starts
			Max int   // bits set to 1 can be used for automatic addressing
		} `yaml:"auto"`
	} `yaml:"config"`
	Constants map[string]string `yaml:"constants"`
	Ops    []UcOp    `yaml:"ops"`
	Chunks []UcChunk `yaml:"ucode"`
}

type UcParam struct {
	Name    string
	Values  []string
	Pos, Bw int
}

func (this *UcOp) Id() string {
	return fmt.Sprintf("%-5s:0x%02x", this.Name, this.Op)
}

func chunk2code( mnemok, up0, opk int, id string, proc bool, code []string, used map[string]bool, desc *UcDesc) int {
	upk := 0
	next_line:
	for _, each := range desc.Chunks[mnemok].Seq {
		if upk >= desc.Cfg.EntryLen {
			fmt.Printf("ucode for %s is longer than %d steps\n", id, desc.Cfg.EntryLen)
			os.Exit(1)
		}
		each = strings.ReplaceAll(each, ",", " ")
		tokens := strings.Fields(each)
		for k, _ := range tokens {
			for { // replace all parameter, allowing a variable to reference another one
				parms := reVars.FindAllStringSubmatch(tokens[k], -1)
				if parms == nil { break }
				for j, _ := range parms {
					if len(parms[j]) != 2 {
						fmt.Println("Don't know how to handle line", each)
						os.Exit(1)
					}
					val := ""
					fnd := false
					parmName := parms[j][1]
					if opk!=-1 {	// Mnemonic chunks will use the associated OP params
						val, fnd = desc.Ops[opk].Ctl[parmName]
					}
					if !fnd && desc.Chunks[mnemok].local!=nil {
						val, fnd = desc.Chunks[mnemok].local[parmName]
					}
					if !fnd { // look in global constants
						val, fnd = desc.Constants[parmName]
						if !fnd && (proc || !desc.Cfg.Implicit) {
							fmt.Printf("Cannot find ucode parameter %s while parsing %s\n", parms[j][1], id)
							if proc { fmt.Println("ucode procedures are limited to global constants and cannot use OP-specific parameter") }
							os.Exit(1)
						}
					} else {
						used[parms[j][1]] = true
					}
					tokens[k] = strings.ReplaceAll(tokens[k], "${"+parms[j][1]+"}", val)
				}
			}
			// Skip lines marked with ? if the condition is nil or 0, or if it does not match an equality
			opts := strings.Split(tokens[k],"?")
			if len(opts)!=1 {
				if len(opts)>2 {
					fmt.Printf("Don't know how to handle multiple ? in %s\n",tokens[k])
					os.Exit(1)
				}
				whole_line := opts[1]=="*"
				val := true
				eqs := strings.Split(opts[0],"=")
				if len(eqs)==2 && eqs[0]!=eqs[1] {
					val = false // mismatched equality
				}
				if len(eqs)==1 && (opts[0]=="" || opts[0] == "0") {
					val = false // null value or zero
				}
				if whole_line {
					if !val {
						continue next_line
					} else {
						tokens[k] = ""
					}

				} else {
					evals := strings.Split(opts[1],":")
					if val {
						tokens[k] = evals[0]
					} else if len(evals)==2 {
						tokens[k] = evals[1]
					} else {
						tokens[k] = ""
					}
				}
			}
			// Delete handling suffixes after variable replacement
			if strings.HasPrefix(tokens[k], "_") || strings.HasSuffix(tokens[k], "=") || strings.HasSuffix(tokens[k], "=0") {
				tokens[k] = ""
			}
			tokens[k] = strings.TrimSuffix(tokens[k], "=1")
			if reDig.MatchString(tokens[k]) {
				fmt.Printf("Variable replacement led to an invalid signal name: %s, while parsing %s\n\t%s\n", tokens[k], id, each)
				os.Exit(1)
			}
			if strings.Count(tokens[k], "_") > 1 {
				fmt.Printf("Only one _ is allowed in a signal name: %s, while parsing %s\n\t%s\n", tokens[k], id, each)
				os.Exit(1)
			}
		}
		if code[up0+upk] != "" {
			fmt.Printf("Duplicated ucode at uaddress %X,%X. While parsing %s\n", up0/desc.Cfg.EntryLen, upk, id)
			fmt.Printf("Existing code: %s\n", code[up0+upk])
			os.Exit(1)
		}
		// join all tokens and remove meaningless spaces
		code[up0+upk] = strings.ToUpper(reSp.ReplaceAllString(strings.TrimSpace(strings.Join(tokens, " ")), " "))
		upk++
	}
	return upk
}

func expand_entry(opk, mnemok int, code []string, desc *UcDesc) {
	used := make(map[string]bool) // used OP parameters. All parameters defined in the Op must be referenced to in the ucode template
	up0 := 0
	proc := false
	var id string
	if desc.Chunks[mnemok].Name!="" {
		up0 = desc.Chunks[mnemok].Start
		id = desc.Chunks[mnemok].Name
		proc = true
		if up0<0 {
			up0 = opk // used for copying a procedure to any location
					  // specify -1 in the YAML, and then it can be used
					  // as the bus_error procedure
			if up0<0 { return } // if opk was negative too, ignore the procedure
		}
	} else {
		up0 = desc.Ops[opk].Op
		id = desc.Ops[opk].Id()
		for each,_ := range desc.Ops[opk].Ctl {
			used[each]=false
		}
	}
	if desc.Cfg.Entries<=up0 {
		fmt.Printf("%s starts outside the allowed range (0-%d)\n", id, desc.Cfg.Entries-1)
	}
	up0 = up0 * desc.Cfg.EntryLen
	desc.Chunks[mnemok].cycles = chunk2code( mnemok, up0, opk, id, proc, code, used, desc )
	for k,v := range used {
		if !v {
			fmt.Printf("Unused parameter %s in OP %s\n", k, id)
			os.Exit(1)
		}
	}
}

func find_chunk(opName string, desc *UcDesc) int {
	ref := -1
	for k, chunk := range desc.Chunks {
		if slices.Contains(chunk.Mnemo, opName) {
			if ref != -1 {
				fmt.Printf("Duplicated entry for mnemonic %s\n", opName)
				os.Exit(1)
			}
			ref = k
		}
	}
	return ref
}

func find_proc(name string, desc *UcDesc) int {
	name = strings.ToUpper(name)
	for k, chunk := range desc.Chunks {
		if strings.ToUpper(chunk.Name) == name {
			return k
		}
	}
	return -1
}

func chunk_templates( desc *UcDesc) {
	new := make([]UcChunk,0)

	var local map[string]string
	var base UcChunk
	var vv []UcRange
	var rec func( string, int )

	rec = func( suffix string, i int) {
		if i==len(vv) {
			n := base
			n.Name += suffix
			n.local = make(map[string]string)
			for k,v := range local {
				n.local[k]=v
			}
			n.Range = nil
			new = append(new,n)
			return
		}
		j := 0
		for _, each := range vv[i].Values {
			local[vv[i].Name]=each
			rec(fmt.Sprintf("%s%X",suffix,j),i+1)
			j++
		}
	}
	// populate with the new procedures based on the templates
	for _, base = range desc.Chunks {
		local = make(map[string]string)
		if len(base.Range)>0 {
			if Args.Verbose { fmt.Printf("Expanding template for %s\n",base.Name) }
			vv = base.Range
			rec( "", 0 )
		} else {
			new=append(new,base)
		}
	}
	desc.Chunks=new
}

func expand_all(desc *UcDesc) []string {
	missing := 0
	op_dups := make(map[int]bool) // track duplicated OPs
	code := make([]string, desc.Cfg.Entries*desc.Cfg.EntryLen)
	syntax := regexp.MustCompile("[0-1a-zA-Z][0-9a-zA-Z]*")
	// expand ucode entries with no op associated
	for k, chunk := range desc.Chunks {
		if chunk.Name == "" {
			if chunk.Mnemo == nil || len(chunk.Mnemo) == 0 {
				fmt.Printf("dangling ucode chunk detected. Comment it out")
				os.Exit(1)
			}
			continue
		}
		expand_entry(-1, k, code, desc)
		if desc.Chunks[k].Start>=0 {
			if Args.Verbose { fmt.Printf("> %03X = %s (chunk)\n", desc.Chunks[k].Start, desc.Chunks[k].Name)}
			op_dups[desc.Chunks[k].Start]=true
		}
	}
	for opk, each := range desc.Ops {
		if _, found := op_dups[each.Op]; found {
			fmt.Printf("Duplicated entry for op=%X (while parsing %s)\n", each.Op, each.Name)
			os.Exit(1)
		}
		if Args.Verbose { fmt.Printf("> %03X = %s\n", each.Op, each.Name)}
		op_dups[each.Op] = true
		// Verify that all CTL signal names make sense
		for k,v := range each.Ctl {
			if v=="" { continue } // allow empty strings
			if !syntax.MatchString(k) {
				fmt.Printf("Bad control signal name %s in OP %X\n", k, each.Op)
				os.Exit(1)
			}
			if !syntax.MatchString(v) {
				fmt.Printf("Bad control values '%s' for signal %s in OP %X\n", v, k, each.Op)
				os.Exit(1)
			}
		}
		// Find a matching ucode chunk
		ref := find_chunk(each.Name, desc)
		if ref == -1 {
			fmt.Printf("Missing ucode for %s (0x%x)\n", each.Name, each.Op)
			missing++
			continue
		}
		expand_entry(opk, ref, code, desc)
		range_mask( desc.Cfg.Entries, each, func( opnx int) {
			src := each.Op*desc.Cfg.EntryLen
			op_dups[opnx]=true
			opnx = opnx*desc.Cfg.EntryLen
			if src==opnx { return }
			if Args.Verbose {
				fmt.Printf("Copying from %X (%s) to %X\n", src, each.Name, opnx)
			}
			for line:=0; line < desc.Cfg.EntryLen; line++ {
				code[opnx+line]=code[src+line]
			}
		})
	}
	// fill unused entries with the bus_error entry
	if desc.Cfg.BusError!="" {
		ref := find_proc(desc.Cfg.BusError, desc)
		if ref == -1 {
			fmt.Printf("Missing ucode for %s\n", desc.Cfg.BusError)
		} else {
			for k:=0; k<desc.Cfg.Entries; k++ {
				f, _ := op_dups[k]
				if f { continue }
				expand_entry(k, ref, code, desc)
				if Args.Verbose {
					fmt.Printf("%X filled as bus error\n",k)
				}
			}
		}
	}
	if missing>0 { fmt.Printf("%d instructions lack ucode sequence\n",missing)}
	return code
}

func calc_cycles(uaddr int, code []string, recurse bool, desc *UcDesc, was_ni *bool) int {
	re := regexp.MustCompile("([a-zA-Z][a-zA-Z0-9_]+)_JSR")
	ni := regexp.MustCompile(`\bNI|HALT\b`)
	sum := 0
	k0 := 0
	if was_ni == nil {
		aux := false
		was_ni = &aux
	}
	for k := uaddr; k < len(code) && !*was_ni; k++ {
		each := code[k]
		sum++
		k0++
		// fmt.Printf("%X %s\n",k,each)
		if ni.MatchString(each) {
			*was_ni = true
			break
		}
		jsr := re.FindStringSubmatch(each)
		if jsr != nil {
			if jsr[1] == "RET" {
				break
			}
			proc := find_proc(jsr[1], desc)
			if proc == -1 {
				fmt.Printf("Cannot find microcode procedure %s\n", jsr[1])
				os.Exit(1)
			}
			sub := calc_cycles(desc.Chunks[proc].Start*desc.Cfg.EntryLen, code, true, desc, was_ni)
			if recurse {
				sum+=sub
			}
		}
	}
	return sum
}

func fix_cycles(code []string, desc *UcDesc, verbose bool) {
	if verbose { fmt.Println("##### Cycle Count Analysis ######")}
	elen := desc.Cfg.EntryLen
	var ref, uaddr int
	fixone := func(op int) {
		total := calc_cycles(uaddr, code, true, desc, nil)  // including jsr calls
		main  := calc_cycles(uaddr, code, false, desc, nil) // only main body of the ucode chunk
		delta := ref - total
		if main+delta > elen {
			if verbose { fmt.Printf("%02X: (%d-%d-%d) %d ", op, ref, total,main, delta) }
			delta=elen-main
			if verbose { fmt.Printf("-> %d\n",delta) }
		}

		if delta>0 {
			for k:=main-1; k>=0;k-- {
				code[uaddr+k+delta]=code[uaddr+k]
			}
			for ;delta>0;delta-- {
				code[uaddr+delta]=""
			}
		}
	}
	for _, each := range desc.Chunks {
		if each.Name!="" && each.Cycles!=0 {
			ref = each.Cycles * desc.Cfg.CycleK
			uaddr = each.Start * elen
			fixone(each.Start)
		}
	}
	for _, each := range desc.Ops {
		ref = each.Cycles * desc.Cfg.CycleK
		uaddr = each.Op * elen
		fixone(each.Op)
	}
}

func report_cycles(code []string, desc *UcDesc, verbose bool) int {
	bad := 0
	header:=false
	for _, each := range desc.Ops {
		ref := each.Cycles * desc.Cfg.CycleK
		actual := calc_cycles(each.Op*desc.Cfg.EntryLen, code, true, desc, nil)
		if actual==ref && !Args.Verbose {
			continue
		}
		if !header && verbose {
			fmt.Println("  Op code  | Spec | Core |")
			fmt.Println("-----------|------|------|")
			header=true
		}
		if verbose { fmt.Printf("%08s |  %02d  |  %02d  | ", each.Id(), ref, actual) }
		if actual < ref {
			if verbose { fmt.Printf("<") }
			bad++
		}
		if actual > ref {
			if verbose { fmt.Printf(">") }
			bad++
		}
		if verbose { fmt.Println() }
	}
	if bad!=0 && verbose {
		fmt.Printf("Warning: %d instructions are not cycle-accurate\n",bad)
	}
	return bad
}

func list_unames(code []string) []string {
	used := make(map[string]bool)
	all := make([]string, 0, 128)
	for _, each := range code {
		tokens := strings.Split(each, " ")
		for _, tk := range tokens {
			if _, fnd := used[tk]; fnd {
				continue
			}
			used[tk] = true
			all = append(all, tk)
		}
	}
	// Sort by suffixes
	sort.Slice(all, func(i, j int) bool {
		i_ := strings.Index(all[i], "_")
		j_ := strings.Index(all[j], "_")
		if i == -1 && j_ != -1 {
			return true
		}
		if i != -1 && j_ == -1 {
			return false
		}
		if i == -1 && j == -1 {
			return all[i] < all[j]
		}
		isu := all[i][i_+1:]
		jsu := all[j][j_+1:]
		if isu == jsu {
			return all[i] < all[j]
		}
		return isu < jsu
	})
	return all
}

func make_params(unames []string) []UcParam {
	params := make([]UcParam, 0, 32)
next:
	for _, each := range unames {
		if each == "" {
			continue
		}
		tokens := strings.Split(each, "_")
		if len(tokens) == 1 {
			params = append(params, UcParam{Name: each})
			continue
		}
		for k, _ := range params {
			if tokens[1] == params[k].Name {
				if len(params[k].Values) == 0 {
					fmt.Printf("Signal name %s used with and without a suffix after a _ character\n", tokens[1])
					os.Exit(1)
				}
				params[k].Values = append(params[k].Values, tokens[0])
				continue next
			}
		}
		params = append(params, UcParam{Name: tokens[1], Values: []string{tokens[0]}})
	}
	// clean up the ones with only one value
	for k, _ := range params {
		if len(params[k].Values) == 1 {
			params[k].Name = params[k].Values[0] + "_" + params[k].Name
			params[k].Values = nil
		}
		sort.Strings(params[k].Values)
	}
	// assign a position in the ucode word
	t := 0
	for k, _ := range params {
		params[k].Pos = t
		params[k].Bw = int(math.Max(math.Ceil(math.Log2(float64(1+len(params[k].Values)))), 1))
		t += params[k].Bw
	}
	return params
}

func dump_uclist(fname string, EntryLen int, code []string) {
	f, _ := os.Create(fname + ".ucl")
	defer f.Close()
	for k, _ := range code {
		fmt.Fprintf(f, "%02X:%X - %s\n", k/EntryLen, k%EntryLen, strings.TrimSpace(code[k]))
	}
}

func encode(line string, params []UcParam) uint64 {
	var v uint64
next:
	for _, each := range strings.Fields(line) {
		for _, m := range params {
			if each == m.Name {
				v |= uint64(1) << m.Pos
				continue next
			}
			for k, prefix := range m.Values {
				if each == prefix+"_"+m.Name {
					v |= uint64(k+1) << m.Pos
					continue next
				}
			}
		}
		fmt.Printf("Cannot find macro for %s!\n", each)
		os.Exit(1)
	}
	return v
}

func dump_list(fname string, code []string, desc *UcDesc) {
	f, e := os.Create(fname + ".lst")
	defer f.Close()
	if e != nil {
		fmt.Println(e)
		os.Exit(1)
	}
	fs := fmt.Sprintf("%%0%dX\t%%s",int(math.Ceil(math.Log2(float64(len(code)))/4)))
	for k, each := range code {
		line := fmt.Sprintf(fs,k,each)
		if k & (desc.Cfg.EntryLen-1)==0 {
			k2 := k/desc.Cfg.EntryLen
			fnd := false
			for _, each := range desc.Ops {
				if k2&each.Mask==each.Op {
					line = fmt.Sprintf("%-48s; %s",line,each.Name)
					fnd = true
					break
				}
			}
			if !fnd {
				for _, each := range desc.Chunks {
					if k2==each.Start {
						line = fmt.Sprintf("%-48s; %s",line,each.Name)
						break
					}
				}
			}
		}
		fmt.Fprintln(f,line)
	}
}

func dump_gtkwave(params []UcParam) {
	for _, each := range params {
		if len(each.Values)<3 { continue }
		var s strings.Builder
		fs := fmt.Sprintf("%%0%dX %%s\n",int(math.Ceil(float64(each.Bw)/4.0)))
		for k,v := range each.Values {
			s.WriteString(fmt.Sprintf(fs,k+1,v))
		}
		os.WriteFile( each.Name+".st", []byte(s.String()), 0644 )
	}
}

func dump_ucode(fname string, params []UcParam, code []string) {
	dw := params[len(params)-1].Pos + params[len(params)-1].Bw
	if dw > 64 {
		fmt.Printf("Cannot encode more than 64 bits per line. %d required.\n", dw)
		os.Exit(1)
	}
	fs := fmt.Sprintf("%%0%db\n", dw)
	f, e := os.Create(fname + ".uc")
	defer f.Close()
	if e != nil {
		fmt.Println(e)
		os.Exit(1)
	}
	for _, each := range code {
		c := encode(each, params)
		fmt.Fprintf(f, fs, c)
	}
}

func dump_ucrom_vh(fname string, latch bool, lenentry, lenuc int, params []UcParam, chunks []UcChunk) (e error){
	context := struct {
		Dw, Aw int
		EntryLen int
		Rom	   string
		Latch  bool
		Ss     []UcParam
		Jsr    []UcChunk
	}{
		Dw: params[len(params)-1].Pos + params[len(params)-1].Bw,
		Aw: int(math.Ceil(math.Log2(float64(lenuc)))),
		EntryLen: lenentry,
		Rom: fname+".uc",
		Latch: latch,
		Ss: params,
		Jsr: make([]UcChunk,0,len(chunks)),
	}
	// Create JSR entries only for the defined params
	var jsr *UcParam
	for k, _ := range params {
		if params[k].Name=="JSR" {
			jsr = &params[k]
			break
		}
	}

	for _, chunk := range chunks {
		if chunk.Name=="" { continue }
		found := false
		name := strings.ToUpper(chunk.Name)
		for _, each := range jsr.Values {
			if each == name {
				found = true
				break
			}
		}
		if !found { continue }
		context.Jsr = append(context.Jsr, chunk)
	}

	tpath := filepath.Join(os.Getenv("JTFRAME"), "src", "jtframe", "ucode", "ucode.vh")
	t, e := template.New("ucode.vh").Funcs(sprig.FuncMap()).ParseFiles(tpath)
	if e!=nil { return e }
	var buffer bytes.Buffer
	e = t.Execute(&buffer, context)
	// Dump the file (even if there was an error)
	e2 := os.WriteFile(fname+".vh", buffer.Bytes(), 0644)
	if e2!=nil { return e2 } else { return e }
}

func dump_param_vh(fname string, params []UcParam, entrylen, entries int, chunks []UcChunk) (e error){
	context := struct {
		// values for bus signals
		Dw, Aw int
		Ss     []UcParam
		// entry points for chunks
		Tw     int
		Seqa   map[string]int
	}{
		Ss: params,
		Tw: int(math.Ceil(math.Log2(float64(entrylen*entries)))),
		Seqa: make(map[string]int),
	}
	// prepare entry points
	for _, each := range chunks {
		if each.Name=="" || each.Start<0 { continue }
		context.Seqa[each.Name] = each.Start*entrylen
	}
	// execute the template
	tpath := filepath.Join(os.Getenv("JTFRAME"), "src", "jtframe", "ucode", "ucparam.vh")
	t, e := template.New("ucparam.vh").Funcs(sprig.FuncMap()).ParseFiles(tpath)
	if e!=nil { return e }
	var buffer bytes.Buffer
	if e=t.Execute(&buffer, context); e!=nil { return e }
	// Dump the file
	os.WriteFile(fname+"_param.vh", buffer.Bytes(), 0644)
	return nil
}

func check_mnemos(desc *UcDesc, verbose bool) {
	free := check_duplicated(desc, verbose)
	chunk_templates( desc )		// expand the chunk templates
	assign_auto( desc, free, verbose )
	check_missing_mnemos(desc)
}

func assign_auto( desc *UcDesc, free []int, verbose bool ) {
	if desc.Cfg.Auto.Max<=desc.Cfg.Auto.Min { return } // automatic addressing is disabled
	var u int
	header := false
	for k, _ := range desc.Chunks {
		each := &desc.Chunks[k]
		if each.Name!="" && !each.NoAuto && each.Name!=desc.Cfg.BusError{
			var addr int
			for {
				if u>=len(free) {
					fmt.Printf("Run out of unused codes while trying to assign an address to %s\n",each.Name)
					os.Exit(1)
				}
				addr = free[u]
				u++
				if addr >= desc.Cfg.Auto.Min && addr <= desc.Cfg.Auto.Max { break }
			}
			each.Start = addr
			if verbose {
				if !header {
					header = true
					fmt.Printf("Autoplacement of procedures:\n")
				}
				fmt.Printf("%-12s placed at %02X\n",each.Name,addr)
			}
		}
	}
}

func range_mask( entries int, op UcOp, f func( int ) ) {
	step := 1
	for (step & op.Mask)!=0 {
		step = step<<1
	}
	mmax := 0
	for k:= 0; (1<<k)<entries; k++ {
		if ( (1<<k)&op.Mask)==0 { mmax = k }
	}
	mmax++
	// if verbose { fmt.Printf("%s (%X): Mask %X, step %X, Max %X\n", each.Name, each.Op, each.Mask, step, 1<<mmax) }
	for k:=0; k<(1<<mmax);k+=step { // ideally, it should skip some sections but this is fast enough anyway
		f( op.Op | (k&^op.Mask) )
	}
}

func check_duplicated(desc *UcDesc, verbose bool) (free []int) {
	// Duplicated chunks
	chnames := make(map[string]bool)
	for _,each := range desc.Chunks {
		if each.Name=="" { continue	}
		_, f := chnames[each.Name]
		if f {
			fmt.Printf("Duplicated ucode procedure with name %s. All names must be unique.\n",each.Name)
			os.Exit(1)
		}
		chnames[each.Name]=true
	}
	// Duplicated OPs
	entries := desc.Cfg.Entries
	used := make([]*UcOp,entries,entries)
	for opk, each := range desc.Ops {
		if each.Op>entries {
			fmt.Printf("Invalid OP code %X as it is larger than config.entries (%d)\n", each.Op, entries )
		}
		if each.Mask==0 || each.Mask>=entries {
			desc.Ops[opk].Mask = entries-1
			each.Mask = desc.Ops[opk].Mask
		}
		// scan all codes derived from the mask
		range_mask( entries, each, func( m int) {
			if used[m]==&desc.Ops[opk] { return }
			if used[m]!=nil {
				fmt.Printf("OP %X (for %s) duplicated. It was used by %s (%X)\n", m, each.Name, used[m].Name, used[m].Op)
				os.Exit(1)
			}
			if verbose {
				fmt.Printf("%X\n",m)
			}
			used[m] = &desc.Ops[opk]
		})
	}
	// return which OP values are not used
	free = make([]int,0,entries)
	for k,_ := range used {
		if used[k]== nil { free = append(free,k) }
	}
	return free
}

func check_missing_mnemos(desc *UcDesc) {
	missing := false
	for _, chunk := range desc.Chunks {
		next_chunk:
		for _,each := range chunk.Mnemo {
			for _,op := range desc.Ops {
				if each == op.Name { continue next_chunk }
			}
			fmt.Println("Missing OP definition for mnemonic",each)
			missing=true
		}
	}
	if missing { os.Exit(1) }
}

func read_yaml( fpath string ) UcDesc {
	var desc UcDesc
	// This code would detect mispelled fields. It requires yaml/v3, but
	// yaml/v3 skips blank lines in a sequence and that breaks (or makes cluttered) the ucode YAML file
	// var pass1 UcDesc
	// f,err := os.Open(fpath)
	// if err != nil {
	// 	fmt.Println(err)
	// 	os.Exit(1)
	// }
	// dec := yaml.NewDecoder(f)
	// dec.KnownFields(true)
	// err = dec.Decode(&pass1)
	// if err != nil {
	// 	fmt.Println(err)
	// 	os.Exit(1)
	// }
	// f.Close()
	// parse again
	buf, err := os.ReadFile(fpath)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	err = yaml.Unmarshal(buf,&desc)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	// Parse include files
	for _, each := range desc.Incs {
		fname := filepath.Join(filepath.Dir(fpath),each)
		inc := read_yaml(fname)
		// overwrite unset values with those in the include file
		if desc.Cfg.EntryLen==0  { desc.Cfg.EntryLen=inc.Cfg.EntryLen 	}
		if desc.Cfg.Entries==0 	 { desc.Cfg.Entries=inc.Cfg.Entries 	}
		if desc.Cfg.CycleK==0 	 { desc.Cfg.CycleK=inc.Cfg.CycleK 		}
		if desc.Cfg.BusError=="" { desc.Cfg.BusError=inc.Cfg.BusError 	}
		if len(inc.Ops)!=0 {
			fmt.Printf("Include file %s has an ops section. This is still not supported\n", each)
			os.Exit(1)
		}
		next_chunk:
		for k, _ := range inc.Chunks {
			if inc.Chunks[k].Name!="" {
				cur := find_proc( inc.Chunks[k].Name, &desc )
				if cur<0 {
					desc.Chunks = append(desc.Chunks,inc.Chunks[k]) // copy it
					continue next_chunk
				}
			}
			// Copy it if there is no definition for any of the OPs listed
			for _,opName := range inc.Chunks[k].Mnemo {
				cur := find_chunk( opName, &desc )
				if cur!=-1 { continue next_chunk }
			}
			desc.Chunks = append(desc.Chunks,inc.Chunks[k]) // copy it
		}
	}
	// expand $ values in parameters
	// parameters defined as foo: $ will become foo: foo
	for i,_ := range desc.Ops {
		for k,v := range desc.Ops[i].Ctl {
			if strings.TrimSpace(v)=="$" { desc.Ops[i].Ctl[k]=k }
		}
	}
	return desc
}

func Make(modname, fname string) (e error) {
	if Args.Output=="" { Args.Output=strings.TrimSuffix(fname,".yaml") }
	fpath := get_ucode_path(modname, fname)
	desc := read_yaml(fpath)
	if desc.Cfg.Entries <= 0 || desc.Cfg.EntryLen <= 0 {
		return fmt.Errorf("Set non-zero values for entry_len and entries in the config section")
	}
	// global variables used for regular expressions
	reVars = regexp.MustCompile(`\${([a-zA-Z][a-zA-Z0-9_]*?)}`)
	reSp = regexp.MustCompile(` +`)
	reDig = regexp.MustCompile(`\b[0-9]`)

	check_mnemos(&desc, Args.Verbose)
	code := expand_all(&desc)
	bad := 0
	if !desc.Cfg.IgnoreCycles {
		fix_cycles(code, &desc, Args.Verbose)
		bad = report_cycles( code, &desc, Args.Report )
	}
	params := make_params(list_unames(code)) // make parameter definitions for bus signals
	if Args.List {
		dump_list(Args.Output,code,&desc)
	}
	if Args.GTKWave {
		dump_gtkwave(params)
	}
	dump_ucode(Args.Output, params, code)
	e = dump_ucrom_vh(Args.Output, desc.Cfg.Latch, desc.Cfg.EntryLen, len(code), params, desc.Chunks)
	if e != nil { return e}
	e = dump_param_vh(Args.Output, params, desc.Cfg.EntryLen, desc.Cfg.Entries, desc.Chunks )
	if e != nil { return e}
	if bad != 0 && !Args.Report {
		fname = strings.TrimSuffix(fname, ".yaml")
		fmt.Printf("Warning: %d instructions are not cycle-accurate in %s/%s\n",bad,modname,fname)
		fmt.Printf("         See details with: jtframe ucode --report %s %s\n",modname, fname)
	}
	return nil
}

func get_ucode_path(module,file string) string {
	const ucode_folder="ucode"
	return filepath.Join(os.Getenv("MODULES"), module, ucode_folder, file)
}