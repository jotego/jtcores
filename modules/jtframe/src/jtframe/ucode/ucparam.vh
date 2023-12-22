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

// Control signals
{{- range .Ss }}{{ if (ne .Bw 1)}}
localparam [{{ sub .Bw 1 }}:0] // {{ .Name }}
{{- $bw := .Bw -}}
{{- $busName := .Name -}}
{{- $first := true }}
{{- range $k,$v := .Values}}
    {{- if (not $first) }},{{ end }}
    {{ printf "%s_%s" $v $busName | printf "%12s" | upper }} = {{ $bw }}'d{{ add $k 1 }}
    {{- $first = false -}}
{{- end }};
{{ end }}{{ end }}
// entry points for ucode procedures
{{- $tw := .Tw -}}
{{- range $k,$v := .Seqa }}
localparam {{ printf "%s%s" $k "_SEQA" | upper | printf "%-20s" }} = {{ $tw }}'h{{ printf "%X" $v }};
{{- end }}