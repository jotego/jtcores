package ucode

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"

	// "text/template"

	// "github.com/Masterminds/sprig/v3"
	"gopkg.in/yaml.v2"
)

type UcOp struct {
	Name   string            `yaml:"name"`
	Op     int               `yaml:"op"`
	Cycles int               `yaml:"cycles"`
	Ctl    map[string]string `yaml:"ctl"`
}

type UcChunk struct {
	Name  string   `yaml:"name"`
	Start int      `yaml:"start"`
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

func (this *UcOp)Id() string {
	return fmt.Sprintf("%-5s:0x%02x",this.Name,this.Op)
}

func expand_entry(opk, mnemok int, code []string, desc *UcDesc) {
	reVars := regexp.MustCompile(`\${([a-zA-Z][a-zA-Z0-9_]*?)}`)
	up0 := 0
	upk := 0
	proc := false
	var id string
	if desc.Chunks[mnemok].Mnemo == nil || len(desc.Chunks[mnemok].Mnemo) == 0 {
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
		each = strings.ReplaceAll(each,",", " ")
		re := regexp.MustCompile(`\s+`)
		each = strings.TrimSpace(re.ReplaceAllString(each, " "))
		tokens := strings.Split(each, " ")
		for k, _ := range tokens {
			vars := reVars.FindAllStringSubmatch(tokens[k], -1)
			if vars == nil {
				continue
			}
			if proc {
				fmt.Printf("ucode procedures cannot use variables, such as %s\n",vars[0][0])
				os.Exit(1)
			}
			for j, _ := range vars {
				if len(vars[j]) != 2 {
					fmt.Println("Don't know how to handle line", each)
					os.Exit(1)
				}
				val,_ := desc.Ops[opk].Ctl[vars[j][1]]
				tokens[k] = strings.ReplaceAll(tokens[k], "${"+vars[j][1]+"}", val)
			}
			// Skip lines marked with ? if the condition is nil or 0
			if option := strings.Index(tokens[k],"?"); option>=0 {
				if len(tokens[k][option+1:])==0 || tokens[k][option+1:option+2]=="0" {
					continue next_line
				}
				tokens[k]=""
			}
			// Delete handling suffixes after variable replacement
			if strings.HasPrefix(tokens[k],"_") || strings.HasSuffix(tokens[k],"=") { tokens[k]="" }
			tokens[k] = strings.TrimSuffix(tokens[k],"=1")
		}
		if code[up0+upk] != "" {
			fmt.Printf("Duplicated ucode at uaddress %X-%X. While parsing %s\n",up0,upk,id)
			os.Exit(1)
		}
		code[up0+upk] = strings.Join(tokens, " ")
		upk++
	}
	desc.Chunks[mnemok].cycles=upk
}

func find_chunk( opName string, desc *UcDesc ) int {
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

func find_proc( name string, desc *UcDesc ) int {
	for k, chunk := range desc.Chunks {
		if chunk.Name == name { return k }
	}
	return -1
}

func expand_all(desc *UcDesc) []string {
	op_dups := make(map[int]bool) // track duplicated OPs
	code := make([]string, desc.Cfg.Entries*desc.Cfg.EntryLen)
	// expand ucode entries with no op associated
	for k, chunk := range desc.Chunks {
		if chunk.Name=="" {
			if chunk.Mnemo==nil || len(chunk.Mnemo)==0 {
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
		ref := find_chunk( each.Name, desc )
		if ref == -1 {
			fmt.Printf("Missing ucode for %s (0x%x)\n", each.Name, each.Op)
			continue
		}
		expand_entry(opk, ref, code, desc)
	}
	return code
}

func calc_cycles( uaddr int, code []string, desc *UcDesc ) int {
	re := regexp.MustCompile("([a-zA-Z][a-zA-Z0-9_]+)_jsr")
	ni := regexp.MustCompile(`\bni\b`)
	sum := 0
	k0 := 0
	for k := uaddr; k<len(code);k++ {
		each := code[k]
		sum++
		k0++

		if ni.MatchString(each) {
			sum++
			break
		}
		jsr := re.FindStringSubmatch(each)
		if jsr!=nil {
			if jsr[1]=="ret" {
				sum++
				break
			}
			proc := find_proc( jsr[1], desc )
			if proc==-1 {
				fmt.Printf("Cannot find microcode procedure %s\n",jsr[1])
				os.Exit(1)
			}
			sum += calc_cycles( desc.Chunks[proc].Start*desc.Cfg.EntryLen, code, desc )
		}
	}
	return sum
}

func fix_cycles( code []string, desc *UcDesc ) {
	for _, each := range desc.Ops {
		ref := each.Cycles*desc.Cfg.CycleK
		uaddr := each.Op*desc.Cfg.EntryLen
		actual := calc_cycles( uaddr, code, desc )
		delta := ref-actual
		if delta>0 {
			clean := true
			for k:=uaddr+desc.Cfg.EntryLen+delta; delta<0; delta++ {
				if code[k]!="" {
					clean = false
					break
				}
				k++
			}
			if clean {
				delta = ref-actual
				for k:=desc.Cfg.EntryLen-1; k>=delta; k-- { code[uaddr+k] = code[uaddr+k-delta] }
				for k:=0; k<delta; k++ { code[uaddr+k]="" }
			}
		}
	}
}

func report_cycles( code []string, desc *UcDesc ) {
	fmt.Println("  Op code  |Spec| uC |")
	fmt.Println("-----------|----|----|")
	for _, each := range desc.Ops {
		ref := each.Cycles*desc.Cfg.CycleK
		actual := calc_cycles( each.Op*desc.Cfg.EntryLen, code, desc )
		fmt.Printf("%08s | %02d | %02d | ", each.Id(), ref, actual )
		if actual<ref { fmt.Printf("<") }
		if actual>ref { fmt.Printf(">") }
		fmt.Println()
	}
}

func Make(modname, fname string) {
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
	code := expand_all(&desc)
	fix_cycles( code, &desc)
	report_cycles( code, &desc)

	f, _ := os.Create( fname+".uc")
	defer f.Close()
	for k, _ := range code {
		fmt.Fprintf(f, "%02X:%X - %s\n", k/desc.Cfg.EntryLen, k%desc.Cfg.EntryLen, strings.TrimSpace(code[k]))
	}
}
