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
    Date: {{ now | date "02-01-2006" }} */

module {{ .Modname }}_ucode({{ range .Ss }}
    output {{ if (ne .Bw 1) }}[{{ sub .Bw 1 }}:0]{{else}}     {{ end }} {{ .Name }},{{ end }}
    input  [{{ sub .Aw 1 }}:0] seqa // sequencer address
);

reg [{{ sub .Dw 1 }}:0] data;
{{- range .Ss }}
assign {{ printf "%14s" .Name}}{{ if (ne .Bw 1) }}[{{ sub .Bw 1 }}:0]{{else}}     {{ end }}=data[{{ .Pos }}+:{{ .Bw }}];
{{- end }}

always @* begin
    {{ $dw := .Dw -}}
    case( seqa ){{ range $k, $v := .Data }}
        {{ $k }}: data = {{ $dw }}'h{{ printf "%X" $v }};{{ end }}
        default: data = 0;
    endcase
end

endmodule