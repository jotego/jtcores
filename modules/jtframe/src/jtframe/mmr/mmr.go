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

type MMRdef struct {
	Name string
	Size int
	Regs []Register
	Read_only bool
	No_core_name bool `yaml:"no_core_name"`
	// Added by jtframe
	AMSB int
	Module string
	Seq []int
}

type Register struct {
	Name, Desc string
	Dw int
	At string
	Wr_event bool
	// Added by jtframe
	Chunks []Chunk
	Wr_addr string
}

type Chunk struct {
	Byte, Msb, Lsb int
}

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
	e = yaml.Unmarshal( buf, &mmr.cfg ); if e != nil { return e }
	sanity_check(mmr.cfg)
	e = mmr.generate(); if e != nil { return e }
	e = mmr.dump_all()
	return e
}

func (mmr *mmr_gen) generate() (e error) {
	mmr.converted=make([]string,len(mmr.cfg))
	for k, _ := range mmr.cfg {
		mmr.bits=make([]int,1024*8)
		if mmr.cfg[k].No_core_name {
			mmr.cfg[k].Module=fmt.Sprintf("jt%s_mmr", mmr.cfg[k].Name )
		} else {
			mmr.cfg[k].Module=fmt.Sprintf("jt%s_%s_mmr",mmr.corename, mmr.cfg[k].Name )
		}
		mmr.cfg[k].AMSB=int(math.Ceil(math.Log2(float64(mmr.cfg[k].Size)))-1)
		mmr.cfg[k].Seq=make([]int,mmr.cfg[k].Size)
		for i:=0;i<mmr.cfg[k].Size;i++ { mmr.cfg[k].Seq[i]=i }
		for j, _ := range mmr.cfg[k].Regs {
			e = mmr.cfg[k].Regs[j].parse(mmr)
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

func (reg *Register)parse(ck checker) error {
	reg.parse_wr_event()
	return reg.parse_chunks(ck)
}

func (reg *Register)parse_wr_event() error {
	as_int, e := strconv.ParseInt(reg.first_address(),0,16)
	if e!=nil { return fmt.Errorf("While parsing address for register %s, found %w",reg.Name,e) }
	reg.Wr_addr = fmt.Sprintf("'d%d", as_int )
	return nil
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
	is_write_event_only := reg.Wr_event && reg.Dw==0
	if is_write_event_only { return nil }

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
		re = regexp.MustCompile(`(^[0-9A-Fa-f]+|^0[0-7]+|^\d+)\[([0-9A-Fa-f]+|0[0-7]+|\d+):([0-9A-Fa-f]+|0[0-7]+|\d+)\]$`)
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
			if reg.Dw == 0 && !reg.Wr_event {
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
