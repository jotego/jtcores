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
    Date: 29-3-2025 */

module jt{{ .Core }}_header(
    input            clk,
                     header, prog_we,
    {{ range .Names }}
    output reg {{ if ne .Msb 0 }}[{{.Msb}}:0]{{else}}     {{ end }} {{.Name}}=0,
    {{- end }}
    input      [2:0] prog_addr,
    input      [7:0] prog_data
);

always @(posedge clk) begin{{ range .Registers }}
    if( header && prog_addr[2:0]=={{.Offset}} && prog_we )
        {{.Name}} <= prog_data{{.Index}};{{ end }}
end

endmodule
