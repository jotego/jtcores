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

package mem

import (
	"fmt"
	"math"
	"os"
	"strings"

	"jotego/jtframe/macros"
)

func find_div( fin, fout float64) (int, int) {
	best_n, best_d := 0.0, 0.0
	best := float64(fin)
	ratio := fout/fin

   	for d:=1.0; d<1024*64; d++ {
   		n := math.Round(ratio*d)
    	f := fin*n/d
        err := math.Abs(fout-f);
        if( err < best ) {
            best_n = n;
            best_d = d;
            best = err;
        }
    }
    return int(best_n), int(best_d)
}

func make_clocks( cfg *MemConfig ) {
	for base_clk, cen_entries := range cfg.Clocks {
		for k, cen_cfg := range cen_entries {
			cen_cfg.parse_settings(base_clk)
			cen_entries[k] = cen_cfg
		}
	}
}

func (cen_cfg *ClockCfg)parse_settings(base_clk string) {
	cen_cfg.set_name(base_clk)
	cen_cfg.set_output_string()

	cen_cfg.W = len(cen_cfg.Outputs)
	if cen_cfg.W == 0 {
		fmt.Printf("Error: no outputs specified for clock enable in mem.yaml")
		os.Exit(1)
	}
	cen_cfg.set_gate_signal()
	// Either the mul/div pair or the frequency may be specified
	cen_cfg.set_factors()
}

func (cen_cfg *ClockCfg)set_name(base_clk string) {
	mode96 := macros.IsSet("JTFRAME_SDRAM96")

	cen_cfg.ClkName = base_clk
	cen_cfg.ratio = 1.0
	if mode96 { // clk is 96MHz
		switch base_clk {
		case "clk24": cen_cfg.ratio = 0.25
		case "clk48": cen_cfg.ratio = 0.5
		case "clk96": cen_cfg.ratio = 1.0
		}
		if cen_cfg.ClkName == "clk96" { cen_cfg.ClkName = "clk" }
	} else { // clk is 48MHz
		switch base_clk {
		case "clk24": cen_cfg.ratio = 0.5
		case "clk48": cen_cfg.ratio = 1.0
		case "clk96": cen_cfg.ratio = 2.0
		}
		if cen_cfg.ClkName == "clk48" && !mode96 { cen_cfg.ClkName = "clk" }
	}
}

func (cen_cfg *ClockCfg)set_output_string() {
	cen_cfg.OutStr = ""
	first := true
	for j, s := range cen_cfg.Outputs {
		if !first {
			cen_cfg.OutStr = ", " + cen_cfg.OutStr
		}
		if strings.Index(s,"cen")==-1 {
			cen_cfg.Outputs[j] += "_cen"
			s = cen_cfg.Outputs[j]
		}
		cen_cfg.OutStr = s + cen_cfg.OutStr
		first = false
	}
}

func (cen_cfg *ClockCfg)set_gate_signal() {
	if len(cen_cfg.Gate)==0 {
		cen_cfg.Busy = "1'b0"
	} else {
		aux := make([]string,len(cen_cfg.Gate))
		for k, each := range cen_cfg.Gate {
			aux[k] = fmt.Sprintf("(%s_cs & ~%s_ok)", each, each)
		}
		cen_cfg.Busy = strings.Join(aux," | ")
	}
}

func (cen_cfg *ClockCfg)set_factors() {
	fmhz := macros.GetInt("JTFRAME_MCLK")
	cen_cfg.KHz = int(float64(fmhz)*cen_cfg.ratio/1000)
	max := func( a,b int ) int { if a>b { return a } else { return b } }

	if cen_cfg.Div==0 || cen_cfg.Mul==0 {
		if cen_cfg.Freq==0 {
			fmt.Printf("Error: neither the frequency nor the mul/div values were defined for clock %s\n", cen_cfg.ClkName )
			os.Exit(1)
		}
		cen_cfg.Mul, cen_cfg.Div = find_div( float64(fmhz)*cen_cfg.ratio, cen_cfg.Freq )
	}
	cen_cfg.WC = int( math.Ceil(math.Log2( float64(max( cen_cfg.Div, cen_cfg.Mul )) )))+1
	cen_cfg.Comment = fmt.Sprintf("%d = %d*%d/%d",int(int(float64(fmhz)*cen_cfg.ratio)*cen_cfg.Mul/cen_cfg.Div),int(float64(fmhz)*cen_cfg.ratio),cen_cfg.Mul,cen_cfg.Div)
	if cen_cfg.Div==0 || cen_cfg.Mul==0 {
		fmt.Printf("Cannot build clock enable signal %s\n",cen_cfg.OutStr)
		os.Exit(1)
	}
}