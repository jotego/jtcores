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

type Chunk struct {
	Byte, Msb, Lsb int
}

type Register struct {
	Name, Desc string
	Dw int
	At string
	Wr_event bool
	// Added by jtframe
	Chunks []Chunk
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

func convert( corename, hdl_path string, cfg MMRdef ) (e error) {
	tpath := filepath.Join(os.Getenv("JTFRAME"), "hdl", "inc", "mmr.v")
	t,e := template.New("mmr.v").Funcs(sprig.FuncMap()).ParseFiles(tpath)
	if e!=nil { return e }
	var buffer bytes.Buffer
	if e=t.Execute(&buffer, cfg); e!=nil { return e }
	// Dump the file
	fname := fmt.Sprintf("%s.v",cfg.Module)
	outpath := filepath.Join(hdl_path,fname)
	return os.WriteFile(outpath, buffer.Bytes(), 0644)
}

func GetMMRPath( corename string ) (mmrpath string) {
	return filepath.Join(os.Getenv("CORES"),corename,"cfg","mmr.yaml")
}

func Generate( corename string, verbose bool ) (e error) {
	fname := GetMMRPath(corename)
	buf, e := os.ReadFile(fname); if e != nil { return e }
	var cfg []MMRdef
	e = yaml.Unmarshal( buf, &cfg ); if e != nil { return e }
	sanity_check(cfg)
	hdl_path := filepath.Join(os.Getenv("CORES"), corename, "hdl")
	for k, _ := range cfg {
		if cfg[k].No_core_name {
			cfg[k].Module=fmt.Sprintf("jt%s_mmr", cfg[k].Name )
		} else {
			cfg[k].Module=fmt.Sprintf("jt%s_%s_mmr",corename, cfg[k].Name )
		}
		cfg[k].AMSB=int(math.Ceil(math.Log2(float64(cfg[k].Size)))-1)
		cfg[k].Seq=make([]int,cfg[k].Size)
		for i:=0;i<cfg[k].Size;i++ { cfg[k].Seq[i]=i }
		for j, _ := range cfg[k].Regs {
			ss := strings.Split(cfg[k].Regs[j].At,",")
			for j, _ := range ss {
				ss[j] = strings.TrimSpace(ss[j])
			}
			cfg[k].Regs[j].Chunks = make([]Chunk,len(ss))
			for m, _ := range ss {
				aux := &cfg[k].Regs[j].Chunks[m]
				var a int64
				// match a single number
				re := regexp.MustCompile(`^0[xX][0-9a-fA-F]+$|^0[0-7]+$|^\d+$`)
				if re.MatchString(ss[m]) {
					a, _ = strconv.ParseInt( ss[m], 0, 16 )
					aux.Byte = int(a)
					aux.Msb = 7
					aux.Lsb = 0
					// fmt.Printf("%s matched as single digit\n",ss[m])
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
					// fmt.Printf("%s matched as n[m:l]\n",ss[m])
					continue
				}
				// Cannot parse it
				return fmt.Errorf("Error: jtframe mmr cannot parse location %s\n",ss[m])

			}
		}
		e = convert(corename,hdl_path,cfg[k]); if e!= nil { return e }
	}
	return nil
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
			if reg.Dw == 0 {
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
