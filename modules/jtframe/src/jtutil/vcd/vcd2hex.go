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
	"fmt"
	"text/template"
	"os"
)

// Creates a hex file to be used in
// verilog and the accompanying verilog file
// to read it
func (this *LnFile) DumpHex(ss vcdData, fname string) (e error) {
	f, e := os.Create(fname + ".bin"); if e!=nil { return e }
	lines := 0
	tbw := 64
	outputs := make([]*VCDSignal, len(ss))
	k := 0
	for _, each := range ss {
		outputs[k] = each
		k++
		tbw += each.MSB - each.LSB + 1
	}
	var t0 uint64
	set_t0 := true
	for this.NextVCD(ss) {
		if set_t0 {
			t0 = this.time
			set_t0 = false
		}
		fmt.Fprintf(f, "%064b", (this.time-t0)/1000 ) // convert to ns
		for _, each := range outputs {
			fms := fmt.Sprintf("%%0%db", each.MSB-each.LSB+1)
			fmt.Fprintf(f, fms, each.Value)
		}
		fmt.Fprintf(f,"\n")
		lines++
	}
	f.Close()
	t := `module vcd_{{ .Name }}(
	input clk,
	{{ range .Outputs -}}
	output {{ if .MSB }}[{{.MSB}}:{{.LSB}}]{{ end }} {{ .Name }},
	{{ end }}output reg eof=0
);
	reg [{{.TBW}}-1:0] data[0:{{.Lines}}-1];
	wire [63:0] vcd_time;
	integer idx=0;

	initial $readmemb("{{.Name}}.bin",data);
	assign {vcd_time{{ range .Outputs }},{{.Name}}{{end}}} = data[idx];

	always @(posedge clk) begin
		if( !eof ) begin
			if( $time > vcd_time ) idx <= idx+1;
			if( idx=={{.Lines}}-1 ) begin
				eof <= 1;
				$display("{{.Name}} data completely parsed");
			end
		end
	end
endmodule
`
	info := struct {
		Name       string
		TBW, Lines int
		Outputs    []*VCDSignal
	}{
		Name:    fname,
		TBW:     tbw,
		Lines:   lines,
		Outputs: outputs,
	}
	f, e = os.Create(fname + ".v")
	defer f.Close()
	if e!=nil { return e }
	to, e := template.New(fname).Parse(t); if e!=nil { return e }
	return to.Execute(f, info)
}

func must(e error) {
	if e != nil {
		fmt.Println(e)
		os.Exit(1)
	}
}
