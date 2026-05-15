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

package mmr

import(
	"bytes"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"text/template"

	"gopkg.in/yaml.v2"
	"github.com/Masterminds/sprig/v3"	// more template functions
)

type mmr_gen struct {
	cfg []MMRdef
	converted []string
	corename, hdl_path string
	bits []int // location of bits used
}

type mmr_entry struct {
	Include MMRInclude `yaml:"include"`
	MMRdef `yaml:",inline"`
}

type MMRInclude struct {
	Core string
	Name interface{} `yaml:"name"`
}

type MMRdef struct {
	Name string
	Size int
	Regs []Register
	Read_only bool
	No_core_name bool `yaml:"no_core_name"`
	Dw int
	// Added by jtframe
	AMSB int
	Module string
	Seq []int
}

type Register struct {
	Name, Desc string
	Dw int
	At string
	Event string
	// Added by jtframe
	Chunks []Chunk
	EventCond string
}

type Chunk struct {
	Byte, Msb, Lsb int
}

const (
	event_none = "none"
	event_write = "write"
	event_any = "any"
	event_one = "one"
	event_zero = "zero"
)

type checker interface {
	check(bytenum,lsb,msb int)
}

func GetMMRPath( corename string ) (mmrpath string) {
	return filepath.Join(os.Getenv("CORES"),corename,"cfg","mmr.yaml")
}

func Generate( corename string, verbose bool ) (e error) {
	fname := GetMMRPath(corename)
	buf, e := os.ReadFile(fname); if e != nil { return e }
	var mmr = mmr_gen{
		corename: corename,
		hdl_path: filepath.Join(os.Getenv("CORES"), corename, "hdl"),
	}
	var entries []mmr_entry
	e = yaml.Unmarshal( buf, &entries ); if e != nil { return e }
	mmr.cfg, e = mmr.expand(entries, map[string]bool{})
	if e != nil { return e }
	sanity_check(mmr.cfg)
	e = mmr.generate(); if e != nil { return e }
	e = mmr.dump_all()
	return e
}

func (mmr *mmr_gen) expand(entries []mmr_entry, includes map[string]bool) (cfg []MMRdef, e error) {
	if includes[mmr.corename] {
		return nil, fmt.Errorf("Error: mmr include recursion detected for core %s", mmr.corename)
	}
	includes[mmr.corename] = true
	defer delete(includes, mmr.corename)

	for _, entry := range entries {
		if entry.Include.Core != "" {
			imported, e := mmr.loadImported(entry.Include, includes)
			if e != nil { return nil, e }
			cfg = append(cfg, imported...)
			continue
		}
		if entry.MMRdef.Name != "" {
			cfg = append(cfg, entry.MMRdef)
			continue
		}
	}
	return cfg,nil
}

func (mmr *mmr_gen) loadImported(include MMRInclude, includes map[string]bool) (cfg []MMRdef, e error) {
	core := strings.TrimSpace(include.Core)
	if core == "" {
		return nil, fmt.Errorf("Error: mmr include without core")
	}
	all, e := mmr.loadImportedFromCore(core, includes)
	if e != nil { return nil, e }
	names, e := importNames(include.Name)
	if e != nil {
		return nil, fmt.Errorf("Error: invalid mmr import name from %q: %w", core, e)
	}
	if len(names) == 0 {
		return all, nil
	}
	return mmr.selectImportedFrom(core, all, names)
}

func (mmr *mmr_gen) loadImportedFromCore(core string, includes map[string]bool) (cfg []MMRdef, e error) {
	mmr_path := GetMMRPath(core)
	buf, e := os.ReadFile(mmr_path)
	if e != nil {
		return nil, fmt.Errorf("Error: cannot read mmr from %q: %w", core, e)
	}

	var entries []mmr_entry
	if e = yaml.Unmarshal(buf, &entries); e != nil {
		return nil, fmt.Errorf("Error: cannot parse mmr from %q: %w", core, e)
	}
	imported := mmr_gen{
		corename: core,
	}
	return imported.expand(entries, includes)
}

func (mmr *mmr_gen) selectImportedFrom(core string, all []MMRdef, names []string) (cfg []MMRdef, e error) {
	pick := make(map[string]struct{}, len(names))
	for _, name := range names {
		pick[strings.TrimSpace(name)] = struct{}{}
	}
	cfg = make([]MMRdef,0,len(all))
	for _, each := range all {
		if _, ok := pick[each.Name]; ok {
			cfg = append(cfg, each)
			delete(pick, each.Name)
		}
	}
	if len(pick) != 0 {
		missing := make([]string,0,len(pick))
		for each := range pick {
			if each != "" {
				missing = append(missing, each)
			}
		}
		return nil, fmt.Errorf("Error: imported mmr from %q missing name(s): %s", core, strings.Join(missing, ", "))
	}
	return cfg, nil
}

func importNames(nameField interface{}) (names []string, e error) {
	switch t := nameField.(type) {
	case nil:
		return nil, nil
	case string:
		s := strings.TrimSpace(t)
		if s == "" { return nil, nil }
		return []string{s}, nil
	case []interface{}:
		names = make([]string,0,len(t))
		for _, each := range t {
			s, ok := each.(string)
			if !ok {
				return nil, fmt.Errorf("unsupported mmr import name list item %T", each)
			}
			s = strings.TrimSpace(s)
			if s == "" {
				continue
			}
			names = append(names, s)
		}
		return names,nil
	default:
		return nil, fmt.Errorf("unsupported mmr import name format %T", nameField)
	}
}

func (mmr *mmr_gen) generate() (e error) {
	mmr.converted=make([]string,len(mmr.cfg))
	for k, _ := range mmr.cfg {
		mmr.bits=make([]int,1024*8)
		if mmr.cfg[k].Dw==0 { mmr.cfg[k].Dw=8 }
		if mmr.cfg[k].No_core_name {
			mmr.cfg[k].Module=fmt.Sprintf("jt%s_mmr", mmr.cfg[k].Name )
		} else {
			mmr.cfg[k].Module=fmt.Sprintf("jt%s_%s_mmr",mmr.corename, mmr.cfg[k].Name )
		}
		mmr.cfg[k].AMSB=int(math.Ceil(math.Log2(float64(mmr.cfg[k].Size)))-1)
		mmr.cfg[k].Seq=make([]int,mmr.cfg[k].Size)
		for i:=0;i<mmr.cfg[k].Size;i++ { mmr.cfg[k].Seq[i]=i }
		for j, _ := range mmr.cfg[k].Regs {
			e = mmr.cfg[k].Regs[j].parse(mmr, mmr.cfg[k].Dw)
			if e!=nil { return e }
		}
		mmr.converted[k], e = mmr.cfg[k].convert()
		if e!= nil { return e }
	}
	return nil
}

func (mmr *mmr_gen) dump_all() (e error) {
	for k, _ := range mmr.cfg {
		e = mmr.dump(k)
		if e!=nil { return e }
	}
	return nil
}

func (reg *Register)parse(ck checker, bus_dw int) error {
	e := reg.parse_event(bus_dw); if e!=nil { return e }
	if reg.IsEvent() { return nil }
	return reg.parse_chunks(ck)
}

func (reg *Register)parse_event(bus_dw int) error {
	reg.Event = strings.TrimSpace(reg.Event)
	if reg.Event=="" { reg.Event=event_none }
	switch reg.Event {
	case event_none:
		return nil
	case event_write, event_any, event_one, event_zero:
	default:
		return fmt.Errorf("MMR register %s has invalid event %q",reg.Name,reg.Event)
	}
	byte_addr, bit, has_bit, e := reg.parse_event_location()
	if e!=nil { return e }
	if (reg.Event==event_one || reg.Event==event_zero) && !has_bit {
		return fmt.Errorf("MMR register %s event %s requires a bit-qualified location",reg.Name,reg.Event)
	}
	reg.EventCond = make_event_condition(reg.Event,bus_dw,byte_addr,bit)
	return nil
}

func (reg Register)IsEvent() bool {
	return reg.Event!="" && reg.Event!=event_none
}

func (reg *Register)parse_event_location() (byte_addr, bit int, has_bit bool, e error) {
	ss := strings.Split(reg.At,",")
	addr := strings.TrimSpace(ss[0])
	re := regexp.MustCompile(`^(0[xX][0-9A-Fa-f]+|0[0-7]+|\d+)(?:\[(0[xX][0-9A-Fa-f]+|0[0-7]+|\d+)(?::(0[xX][0-9A-Fa-f]+|0[0-7]+|\d+))?\])?$`)
	matches := re.FindStringSubmatch(addr)
	if len(matches)==0 {
		return 0,0,false,fmt.Errorf("Error: jtframe mmr cannot parse event location %s",addr)
	}
	a, e := strconv.ParseInt(matches[1],0,16)
	if e!=nil { return 0,0,false,fmt.Errorf("While parsing address for register %s, found %w",reg.Name,e) }
	byte_addr = int(a)
	if matches[2]=="" { return byte_addr,0,false,nil }
	if matches[3]!="" {
		return 0,0,false,fmt.Errorf("MMR register %s event location must select one bit",reg.Name)
	}
	a, e = strconv.ParseInt(matches[2],0,16)
	if e!=nil { return 0,0,false,fmt.Errorf("While parsing bit for register %s, found %w",reg.Name,e) }
	bit = int(a)
	if bit<0 || bit>7 {
		return 0,0,false,fmt.Errorf("MMR register %s event bit must be between 0 and 7",reg.Name)
	}
	return byte_addr,bit,true,nil
}

func make_event_condition(event string, bus_dw, byte_addr, bit int) string {
	var write_cond, access_cond string
	din_bit := bit
	if bus_dw==16 {
		lane := byte_addr & 1
		word_addr := byte_addr >> 1
		write_cond = fmt.Sprintf("cs && !rnw && addr=='d%d && !dsn[%d]",word_addr,lane)
		access_cond = fmt.Sprintf("cs && addr=='d%d && (rnw || !dsn[%d])",word_addr,lane)
		din_bit = bit+lane*8
	} else {
		write_cond = fmt.Sprintf("cs && !rnw && addr=='d%d",byte_addr)
		access_cond = fmt.Sprintf("cs && addr=='d%d",byte_addr)
	}
	switch event {
	case event_write:
		return write_cond
	case event_any:
		return access_cond
	case event_one:
		return fmt.Sprintf("%s && din[%d]==1'b1",write_cond,din_bit)
	case event_zero:
		return fmt.Sprintf("%s && din[%d]==1'b0",write_cond,din_bit)
	default:
		return ""
	}
}

func (reg *Register)first_address() string {
	ss := strings.Split(reg.At,",")
	bracket := strings.Index(ss[0],"[")
	if bracket!=-1 {
		return ss[0][0:bracket]
	} else {
		return ss[0]
	}
}

func (reg *Register)parse_chunks(ck checker) error {
	ss := strings.Split(reg.At,",")
	for j, _ := range ss {
		ss[j] = strings.TrimSpace(ss[j])
	}
	reg.Chunks = make([]Chunk,len(ss))
	for m, _ := range ss {
		aux := &reg.Chunks[m]
		var a int64
		// match a single number
		re := regexp.MustCompile(`^0[xX][0-9a-fA-F]+$|^0[0-7]+$|^\d+$`)
		if re.MatchString(ss[m]) {
			a, _ = strconv.ParseInt( ss[m], 0, 16 )
			aux.Byte = int(a)
			aux.Msb = 7
			aux.Lsb = 0
			// fmt.Printf("%s matched as single digit\n",ss[m])
			ck.check(aux.Byte,aux.Lsb,aux.Msb)
			continue
		}
		// match number[number]
		re = regexp.MustCompile(`(0[xX][0-9A-Fa-f]+|0[0-7]+|\d+)\[(0[xX][0-9A-Fa-f]+|0[0-7]+|\d+)\]`)
			matches := re.FindStringSubmatch(ss[m])
		if len(matches)==3 {
			a, _ = strconv.ParseInt( matches[1], 0, 16 )
			aux.Byte = int(a)
			a, _ = strconv.ParseInt( matches[2], 0, 16 )
			aux.Msb = int(a)
			aux.Lsb = aux.Msb
			ck.check(aux.Byte,aux.Lsb,aux.Msb)
			// fmt.Printf("%s matched as n[m]\n",ss[m])
			continue
		}
		// match number[number:number]
		re = regexp.MustCompile(`^(0[xX][0-9A-Fa-f]+|0[0-7]+|\d+)\[(0[xX][0-9A-Fa-f]+|0[0-7]+|\d+):(0[xX][0-9A-Fa-f]+|0[0-7]+|\d+)\]$`)
			matches = re.FindStringSubmatch(ss[m])
		if len(matches)==4 {
			a, _ = strconv.ParseInt( matches[1], 0, 16 )
			aux.Byte = int(a)
			a, _ = strconv.ParseInt( matches[2], 0, 16 )
			aux.Msb = int(a)
			a, _ = strconv.ParseInt( matches[3], 0, 16 )
			aux.Lsb = int(a)
			ck.check(aux.Byte,aux.Lsb,aux.Msb)
			// fmt.Printf("%s matched as n[m:l]\n",ss[m])
			continue
		}
		// Cannot parse it
		return fmt.Errorf("Error: jtframe mmr cannot parse location %s\n",ss[m])
	}
	return nil
}

func (mmr *mmr_gen)check(bytenum,lsb,msb int) {
	if bytenum>1024 {
		panic("jtframe mmr: Cannot allocate more than 1kB")
	}
	if msb<lsb {
		msg := fmt.Sprintf("jtframe mmr: Wrong MSB-LSB order, got %d->%d",lsb,msb)
		panic(msg)
	}
	if msb>7 {
		panic("jtframe mmr: MSB must be less than 8")
	}
	for i:=lsb;i<=msb;i++ {
		pos := bytenum<<3+i
		if mmr.bits[pos]==1 {
			msg := fmt.Sprintf("MMR bit %d of byte %d is already in use",i,bytenum)
			panic(msg)
		}
		mmr.bits[pos]=1
	}
}

func (cfg MMRdef) convert() (conv string, e error) {
	tpath := filepath.Join(os.Getenv("JTFRAME"), "hdl", "inc", "mmr.v")
	t,e := template.New("mmr.v").Funcs(sprig.FuncMap()).ParseFiles(tpath)
	if e!=nil { return "",e }
	var buffer bytes.Buffer
	e=t.Execute(&buffer, cfg)
	if e!=nil { return "",e }
	return buffer.String(),nil
}

func (mmr *mmr_gen) dump(k int) error {
	// Dump the file
	fname := fmt.Sprintf("%s.v",mmr.cfg[k].Module)
	outpath := filepath.Join(mmr.hdl_path,fname)
	return os.WriteFile(outpath, []byte(mmr.converted[k]), 0644)
}

func sanity_check( cfg []MMRdef ) {
	for _, each := range(cfg) {
		if each.Name=="" {
			fmt.Println("Error: MMR without name")
			os.Exit(1)
		}
		if each.Size<4 {
			fmt.Printf("Error: %s's MMR size is less than 4\n", each.Name)
			os.Exit(1)
		}
		if( len(each.Regs)==0 ) {
			fmt.Printf("Error: %s's MMR does not have any output", each.Name)
			os.Exit(1)
		}
		for _, reg := range each.Regs {
			if reg.Name=="" {
				fmt.Printf("Error: %s's MMR has unnamed registers\n", each.Name)
				os.Exit(1)
			}
			if reg.Dw == 0 && (reg.Event=="" || reg.Event==event_none) {
				fmt.Printf("Error: %s's MMR has register %s with no size\n", each.Name, reg.Name)
				os.Exit(1)
			}
			if reg.At=="" {
				fmt.Printf("Error: %s's MMR has register %s with no location\n", each.Name, reg.Name)
				os.Exit(1)
			}
		}
	}
}
