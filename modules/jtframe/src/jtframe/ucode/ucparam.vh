/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: {{ now | date "02-01-2006" }} */

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