package vcd

import (
	"fmt"
	"text/template"
	"os"
)

// Creates a hex file to be used in
// verilog and the accompanying verilog file
// to read it
func (this *LnFile) DumpHex(ss vcdData, fname string) {
	f, err := os.Create(fname + ".bin")
	must(err)
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
	f, err = os.Create(fname + ".v")
	must(err)
	defer f.Close()
	to := template.Must(template.New(fname).Parse(t))
	to.Execute(f, info)
}

func must(e error) {
	if e != nil {
		fmt.Println(e)
		os.Exit(1)
	}
}
