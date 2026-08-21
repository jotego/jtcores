/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-3-2025 */

module jt{{ .Core }}_header(
    input            clk,
                     header, prog_we,
    {{ range .Names }}
    output reg {{ if ne .Msb 0 }}[{{.Msb}}:0]{{else}}     {{ end }} {{.Name}}=0,
    {{- end }}
    input      [{{.AddrMSB}}:0] prog_addr,
    input      [7:0] prog_data
);

always @(posedge clk) begin{{ range .Registers }}
    if( header && prog_addr[{{$.AddrMSB}}:0]=={{.Offset}} && prog_we )
        {{.Name}} <= prog_data{{.Index}};{{ end }}
end

endmodule
