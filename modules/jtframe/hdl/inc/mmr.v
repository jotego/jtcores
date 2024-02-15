/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-10-2023 */

module {{ .Module }}(
    input             rst,
    input             clk,

    input             cs,
    input       [{{.AMSB}}:0] addr,
    input             rnw,
    input       [7:0] din, {{ if not .Read_only }}
    output reg  [7:0] dout, {{- end }}
    {{ range .Regs }}
    output {{if .Wr_event }}reg{{ end }}   {{if eq .Dw 1}}    {{else}}[{{ .Dw }}-1:0]{{end}} {{ .Name }},
    {{- end }}

    // IOCTL dump
    input      [{{.AMSB}}:0] ioctl_addr,
    output reg [ 7:0] ioctl_din,
    // Debug
    input      [ 7:0] debug_bus,
    output reg [ 7:0] st_dout
);

parameter SIMFILE="rest.bin",
          SEEK=0;

localparam SIZE={{.Size}};

reg  [ 7:0] mmr[0:SIZE-1];
integer     i;
{{ range .Regs }}{{ if not .Wr_event }}
assign {{.Name}} = { {{ range .Chunks }}
    mmr[{{.Byte}}][{{if eq .Msb .Lsb}}{{.Msb}}{{else}}{{.Msb}}:{{.Lsb}}{{end}}],
{{- end }} {0{1'b0}}  // finish off without a comma
    };
{{end}}{{ end }}

always @(posedge clk, posedge rst) begin
    if( rst ) begin
    `ifndef SIMULATION
        // no mechanism for default values yet
        {{- range .Seq }}
        mmr[{{ . }}] <= 0;
        {{- end }}
    `else
        for(i=0;i<SIZE;i++) mmr[i] <= mmr_init[i];
    `endif {{ range .Regs }}{{ if .Wr_event }}
    {{.Name}} <= 0; {{ end }}{{- end }}{{ if not .Read_only }}
    dout <= 0; {{- end }}
    end else begin{{ range .Regs }}{{ if .Wr_event }}
        {{.Name}} <= 0; {{ end }}{{- end }}{{ if not .Read_only }}
        dout      <= mmr[addr];{{- end }}
        st_dout   <= mmr[debug_bus[{{.AMSB}}:0]];
        ioctl_din <= mmr[ioctl_addr];
        if( cs & ~rnw ) begin
            mmr[addr]<=din;{{ range .Regs }}{{ if .Wr_event }}
            {{.Name}} <= 1; {{ end }}{{- end }}
        end
    end
end

`ifdef SIMULATION
/* verilator tracing_off */
integer f, fcnt, err;
reg [7:0] mmr_init[0:SIZE-1];
initial begin
    f=$fopen("rest.bin","rb");
    err=$fseek(f,SEEK,0);
    if( f!=0 && err!=0 ) begin
        $display("Cannot seek file rest.bin to offset 0x%0X (%0d)",SEEK,SEEK);
    end
    if( f!=0 ) begin
        fcnt=$fread(mmr_init,f);
        $display("INFO: Read %d bytes for %m.mmr from offset %0d",fcnt,SEEK);
        if( fcnt!=SIZE ) begin
            $display("WARNING: Missing %d bytes for %m.mmr",SIZE-fcnt);
        end
    end
    $fclose(f);
end
`endif

endmodule
