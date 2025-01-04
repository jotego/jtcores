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

	"github.com/jotego/jtframe/macros"
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
	max := func( a,b int ) int { if a>b { return a } else { return b } }

	mode96 := macros.IsSet("JTFRAME_SDRAM96") || macros.IsSet("JTFRAME_CLK96")
	fmhz := macros.GetInt("JTFRAME_MCLK")

	for key, list := range cfg.Clocks {
		for k, v := range list {
			v.ClkName = key
			ratio := 1.0
			if mode96 { // clk is 96MHz
				switch key {
				case "clk24": ratio = 0.25
				case "clk48": ratio = 0.5
				case "clk96": ratio = 1.0
				}
				if v.ClkName == "clk96" { v.ClkName = "clk" }
			} else { // clk is 48MHz
				switch key {
				case "clk24": ratio = 0.5
				case "clk48": ratio = 1.0
				case "clk96": ratio = 2.0
				}
				if v.ClkName == "clk48" { v.ClkName = "clk" }
			}
			v.KHz = int(float64(fmhz)*ratio/1000)
			v.OutStr = ""
			first := true
			for j, s := range v.Outputs {
				if !first {
					v.OutStr = ", " + v.OutStr
				}
				if strings.Index(s,"cen")==-1 {
					v.Outputs[j] += "_cen"
					s = v.Outputs[j]
				}
				v.OutStr = s + v.OutStr
				first = false
			}
			v.W = len(v.Outputs)
			if v.W == 0 {
				fmt.Printf("Error: no outputs specified for clock enable in mem.yaml")
				os.Exit(1)
			}
			// Build the gate signal
			if len(v.Gate)==0 {
				v.Busy = "1'b0"
			} else {
				aux := make([]string,len(v.Gate))
				for k, each := range v.Gate {
					aux[k] = fmt.Sprintf("(%s_cs & ~%s_ok)", each, each)
				}
				v.Busy = strings.Join(aux," | ")
			}
			// Either the mul/div pair or the frequency may be specified
			if v.Div==0 || v.Mul==0 {
				if v.Freq==0 {
					fmt.Printf("Error: neither the frequency nor the mul/div values were defined for clock %s\n", key )
					os.Exit(1)
				}
				v.Mul, v.Div = find_div( float64(fmhz)*ratio, v.Freq )
			}
			v.WC = int( math.Ceil(math.Log2( float64(max( v.Div, v.Mul )) )))+1
			v.Comment = fmt.Sprintf("%d = %d*%d/%d",int(int(float64(fmhz)*ratio)*v.Mul/v.Div),int(float64(fmhz)*ratio),v.Mul,v.Div)
			list[k] = v
		}
	}
}