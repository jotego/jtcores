{{- range $k, $v := .Clocks }}
    {{- range $v }}
    input {{ .OutStr }}, // {{ .Comment }} Hz {{ end }}
{{end}}
    // Audio channels
    {{if .Audio.Mute}}output mute,
    {{end}}{{ range .Audio.Channels }}{{ if .Name }}{{ if .Stereo }}output {{ if not .Unsigned }}signed {{end}}{{ data_range . }} {{.Name}}_l,
    output {{ if not .Unsigned }}signed {{end}}{{ data_range . }} {{.Name}}_r,{{ else }}
    output {{ if not .Unsigned }}signed {{end}}{{ data_range . }} {{.Name}},{{ end }}{{end}}{{if .Rc_en}}
    output {{if gt .Filters 1}}[{{sub .Filters 1}}:0] {{end}}{{.Name}}_rcen,{{end}}{{ end}}{{ if eq (len .Audio.Channels) 0 }}
    // Sound output
`ifndef JTFRAME_STEREO
    output  signed [15:0] snd,
`else
    output  signed [15:0] snd_left, snd_right,
`endif
    output          game_led,
    output          sample,
{{ end }}
    // Memory ports
    input   [21:0]  prog_addr,
    input   [ 7:0]  prog_data,
    input           prog_we,
    input   [ 1:0]  prog_ba,
    input   [25:0]  ioctl_addr,
`ifdef JTFRAME_PROM_START
    input           prom_we,
`endif
{{- if .Download.Post_addr }}
    output reg [21:0] post_addr,
{{end}}
{{- if .Download.Pre_addr }}
    output reg [25:0] pre_addr,
{{end}}
{{- if .Download.Post_data }}
    output reg [ 7:0] post_data,
{{end}}
`ifdef JTFRAME_HEADER
    input           header,
`endif
`ifdef JTFRAME_IOCTL_RD
    input           ioctl_ram,
    input           ioctl_wr,
    output   [ 7:0] ioctl_din,
    input    [ 7:0] ioctl_dout, `endif
    input           ioctl_cart,
    // Explicit ports
{{- range .Ports}}
    {{if .Input}}input{{else}}output{{end}}   {{if .MSB}}[{{.MSB}}:{{.LSB}}]{{end}} {{.Name}},{{end }}
    // Buses to BRAM
{{ range $cnt, $bus:=.BRAM -}}
    {{- if .Rw }}{{if not .Din}}output   {{ data_range . }} {{.Name}}_din,{{end}}{{end}}
    {{- if .Dual_port.Name }}
    {{ if not .Dual_port.We }}output   {{ if eq .Data_width 16 }}[ 1:0]{{else}}      {{end}} {{.Dual_port.Name}}_we, // Dual port for {{.Dual_port.Name}}
    {{end}}{{else}}
    {{end}}
{{- end}}
{{- $first := true -}}
{{- range .SDRAM.Banks}}
{{- range .Buses}}
    {{- if $first}}
    // Buses to SDRAM{{$first = false}}{{else}},
{{end}}
    input    {{ data_range . }} {{.Name}}_data,{{if not .Cs}}
    output          {{.Name}}_cs,{{end}}{{if not .Addr }}
    output   {{ addr_range . }} {{.Name}}_addr,{{end}}
{{- if .Rw }}
    output          {{.Name}}_we,{{ if not .Din}}
    output   {{ data_range . }} {{.Name}}_din,{{end }}{{if not .Dsn}}
    output   [ 1:0] {{.Name}}_dsn,{{end}}{{end }}
    input           {{.Name}}_ok{{end}}
{{- end}}
