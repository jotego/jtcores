package mem

import (
	"fmt"
	"math"
	"os"
	"strconv"
	"strings"
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

func make_clocks( macros map[string]string, cfg *MemConfig ) {
	defined := func( key string ) bool {
		_ ,e := macros[key]
		return e
	}
	max := func( a,b int ) int { if a>b { return a } else { return b } }

	mode96 := defined("JTFRAME_SDRAM96") || defined("JTFRAME_CLK96")
	aux, _ := macros["JTFRAME_MCLK"]
	fmhz, _ := strconv.Atoi(aux)
	fmhz *= 1000

	for key, list := range cfg.Clocks {
		for k, v := range list {
			v.ClkName = key
			ratio := 1.0
			if mode96 { // clk is 96MHz
				switch key {
				case "clk6":  ratio = 0.125
				case "clk24": ratio = 0.25
				case "clk48": ratio = 0.5
				case "clk96": ratio = 1.0
				}
				if v.ClkName == "clk96" { v.ClkName = "clk" }
			} else { // clk is 48MHz
				switch key {
				case "clk6":  ratio = 0.25
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