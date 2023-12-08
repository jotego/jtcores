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
	"gopkg.in/yaml.v2"
)

var Args struct{
	Report bool
	Output string
}

type UcOp struct {
	Name   string            `yaml:"name"`
	Op     int               `yaml:"op"`
	Cycles int               `yaml:"cycles"`
	Ctl    map[string]string `yaml:"ctl"`
}

type UcChunk struct {
	Name  string   `yaml:"name"`
	Start int      `yaml:"start"`
	Cycles int	   `yaml:"cycles"` // used for procedures
	Mnemo []string `yaml:"mnemo"`
	Seq   []string `yaml:"seq"`
	// private
	cycles int
}

type UcDesc struct {
	Cfg struct {
		EntryLen int `yaml:"entry_len"`
		Entries  int `yaml:"entries"`
		CycleK   int `yaml:"cycle_factor"`
	} `yaml:"config"`
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

func expand_entry(opk, mnemok int, code []string, desc *UcDesc) {
	reVars := regexp.MustCompile(`\${([a-zA-Z][a-zA-Z0-9_]*?)}`)
	reSp := regexp.MustCompile(` +`)
	reDig := regexp.MustCompile(`\b[0-9]`)
	up0 := 0
	upk := 0
	proc := false
	var id string
	if desc.Chunks[mnemok].Name!="" {
		up0 = desc.Chunks[mnemok].Start
		id = desc.Chunks[mnemok].Name
		proc = true
	} else {
		up0 = desc.Ops[opk].Op
		id = desc.Ops[opk].Id()
	}
	up0 = up0 * desc.Cfg.EntryLen
next_line:
	for _, each := range desc.Chunks[mnemok].Seq {
		if upk >= desc.Cfg.EntryLen {
			fmt.Printf("ucode for %s is longer than %d steps\n", id, desc.Cfg.EntryLen)
			os.Exit(1)
		}
		each = strings.ReplaceAll(each, ",", " ")
		tokens := strings.Fields(each)
		for k, _ := range tokens {
			vars := reVars.FindAllStringSubmatch(tokens[k], -1)
			if vars == nil {
				continue
			}
			if proc {
				fmt.Printf("ucode procedures cannot use variables, such as %s\n", vars[0][0])
				os.Exit(1)
			}
			for j, _ := range vars {
				if len(vars[j]) != 2 {
					fmt.Println("Don't know how to handle line", each)
					os.Exit(1)
				}
				val, _ := desc.Ops[opk].Ctl[vars[j][1]]
				tokens[k] = strings.ReplaceAll(tokens[k], "${"+vars[j][1]+"}", val)
			}
			// Skip lines marked with ? if the condition is nil or 0
			if option := strings.Index(tokens[k], "?"); option >= 0 {
				if len(tokens[k][option+1:]) == 0 || tokens[k][option+1:option+2] == "0" {
					continue next_line
				}
				tokens[k] = ""
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
			fmt.Printf("Duplicated ucode at uaddress %X-%X. While parsing %s\n", up0, upk, id)
			os.Exit(1)
		}
		// join all tokens and remove meaningless spaces
		code[up0+upk] = strings.ToUpper(reSp.ReplaceAllString(strings.TrimSpace(strings.Join(tokens, " ")), " "))
		upk++
	}
	desc.Chunks[mnemok].cycles = upk
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

func expand_all(desc *UcDesc) []string {
	op_dups := make(map[int]bool) // track duplicated OPs
	code := make([]string, desc.Cfg.Entries*desc.Cfg.EntryLen)
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
	}
	for opk, each := range desc.Ops {
		if _, found := op_dups[each.Op]; found {
			fmt.Printf("Duplicated entry for op=%X\n", each.Op)
			os.Exit(1)
		}
		op_dups[each.Op] = true
		// Find a matching ucode chunk
		ref := find_chunk(each.Name, desc)
		if ref == -1 {
			fmt.Printf("Missing ucode for %s (0x%x)\n", each.Name, each.Op)
			continue
		}
		expand_entry(opk, ref, code, desc)
	}
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

func fix_cycles(code []string, desc *UcDesc) {
	elen := desc.Cfg.EntryLen
	var ref, uaddr int
	fixone := func(op int) {
		actual := calc_cycles(uaddr, code, true, desc, nil)
		main := calc_cycles(uaddr, code, false, desc, nil)
		delta := ref - actual
		if main+delta > elen {
			fmt.Printf("%02X: (%d-%d-%d) %d ", op, ref, actual,main, delta)
			delta=elen-main
			fmt.Printf("-> %d\n",delta)
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

func report_cycles(code []string, desc *UcDesc) {
	bad := 0
	header:=false
	for _, each := range desc.Ops {
		ref := each.Cycles * desc.Cfg.CycleK
		actual := calc_cycles(each.Op*desc.Cfg.EntryLen, code, true, desc, nil)
		if actual==ref {
			continue
		}
		if !header {
			fmt.Println("  Op code  |Spec| uC |")
			fmt.Println("-----------|----|----|")
			header=true
		}
		fmt.Printf("%08s | %02d | %02d | ", each.Id(), ref, actual)
		if actual < ref {
			fmt.Printf("<")
			bad++
		}
		if actual > ref {
			fmt.Printf(">")
			bad++
		}
		fmt.Println()
	}
	if bad!=0 {
		fmt.Printf("%d instructions are not accurate\n",bad)
	}
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

func dump_ucrom_vh(fname string, lenentry, lenuc int, params []UcParam, chunks []UcChunk) {
	context := struct {
		Dw, Aw int
		EntryLen int
		Rom	   string
		Ss     []UcParam
		Jsr    []UcChunk
	}{
		Dw: params[len(params)-1].Pos + params[len(params)-1].Bw,
		Aw: int(math.Ceil(math.Log2(float64(lenuc)))),
		EntryLen: lenentry,
		Rom: fname+".uc",
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
	t := template.Must(template.New("ucode.vh").Funcs(sprig.FuncMap()).ParseFiles(tpath))
	var buffer bytes.Buffer
	t.Execute(&buffer, context)
	// Dump the file
	os.WriteFile(fname+".vh", buffer.Bytes(), 0644)
}

func dump_param_vh(fname string, params []UcParam) {
	context := struct {
		Dw, Aw int
		Ss     []UcParam
	}{
		Ss: params,
	}
	tpath := filepath.Join(os.Getenv("JTFRAME"), "src", "jtframe", "ucode", "ucparam.vh")
	t := template.Must(template.New("ucparam.vh").Funcs(sprig.FuncMap()).ParseFiles(tpath))
	var buffer bytes.Buffer
	t.Execute(&buffer, context)
	// Dump the file
	os.WriteFile(fname+"_param.vh", buffer.Bytes(), 0644)
}

func check_mnemos(desc *UcDesc) {
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

func Make(modname, fname string) {
	if Args.Output=="" { Args.Output=strings.TrimSuffix(fname,".yaml") }
	fpath := filepath.Join(os.Getenv("MODULES"), modname, "hdl", fname)
	buf, err := os.ReadFile(fpath)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	var desc UcDesc
	err = yaml.Unmarshal(buf, &desc)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	if desc.Cfg.Entries <= 0 || desc.Cfg.EntryLen <= 0 {
		fmt.Println("Set non-zero values for entry_len and entries in the config section")
		os.Exit(1)
	}
	check_mnemos(&desc)
	code := expand_all(&desc)
	fix_cycles(code, &desc)
	if Args.Report { report_cycles( code, &desc) }
	params := make_params(list_unames(code))
	fname = strings.TrimSuffix(fname, ".yaml")
	dump_ucode(Args.Output, params, code)
	dump_ucrom_vh(Args.Output, desc.Cfg.EntryLen, len(code), params, desc.Chunks)
	dump_param_vh(Args.Output, params )
}
