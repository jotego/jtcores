{{ if .Channels }}`ifndef NOSOUND
`ifdef VERILATOR_KEEP_AUDIO /* verilator tracing_on */ `else /* verilator tracing_off */ `endif
{{- $ch0 := (index .Channels 0) -}}
{{- $ch1 := (index .Channels 1) -}}
{{- $ch2 := (index .Channels 2) -}}
{{- $ch3 := (index .Channels 3) -}}
{{- $ch4 := (index .Channels 4) -}}
{{- $ch5 := (index .Channels 5) }}{{ if not .Mute }}
assign mute=0;{{end}}
{{ if (len .PCB) }}
wire [7:0] g0,g1,g2,g3,g4,g5;
jtframe_gainmux #( {{ range $k,$pcb := .PCB }}{{ if ne $k 0 }},{{- end}}
    .GAME{{$k}}({{.Gaincfg}}){{end}}
) u_gainmux(
    .clk    ( clk         ),
    .sel    ( pcb_id[2:0] ),
    .g0     ( g0          ),
    .g1     ( g1          ),
    .g2     ( g2          ),
    .g3     ( g3          ),
    .g4     ( g4          ),
    .g5     ( g5          )
);
{{ end }}
jtframe_rcmix #(
    {{ if $ch0.Name }}.W0({{$ch0.Data_width}}),{{end}}{{ if $ch1.Name }}
    .W1({{$ch1.Data_width}}),{{end}}{{ if $ch2.Name }}
    .W2({{$ch2.Data_width}}),{{end}}{{ if $ch3.Name }}
    .W3({{$ch3.Data_width}}),{{end}}{{ if $ch4.Name }}
    .W4({{$ch4.Data_width}}),{{end}}{{ if $ch5.Name }}
    .W5({{$ch5.Data_width}}),{{end}}{{ with $ch0.Firhex}}
    .FIR0("{{$ch0.Firhex}}"),{{end}}{{ with $ch1.Firhex}}
    .FIR1("{{$ch1.Firhex}}"),{{end}}{{ with $ch2.Firhex}}
    .FIR2("{{$ch2.Firhex}}"),{{end}}{{ with $ch3.Firhex}}
    .FIR3("{{$ch3.Firhex}}"),{{end}}{{ with $ch4.Firhex}}
    .FIR4("{{$ch4.Firhex}}"),{{end}}{{ with $ch5.Firhex}}
    .FIR5("{{$ch5.Firhex}}"),{{end}}
    .STEREO0( {{if $ch0.Stereo }}1{{else}}0{{end}}),
    .STEREO1( {{if $ch1.Stereo }}1{{else}}0{{end}}),
    .STEREO2( {{if $ch2.Stereo }}1{{else}}0{{end}}),
    .STEREO3( {{if $ch3.Stereo }}1{{else}}0{{end}}),
    .STEREO4( {{if $ch4.Stereo }}1{{else}}0{{end}}),
    .STEREO5( {{if $ch5.Stereo }}1{{else}}0{{end}}),
    .DCRM0  ( {{if $ch0.DCrm   }}1{{else}}0{{end}}),
    .DCRM1  ( {{if $ch1.DCrm   }}1{{else}}0{{end}}),
    .DCRM2  ( {{if $ch2.DCrm   }}1{{else}}0{{end}}),
    .DCRM3  ( {{if $ch3.DCrm   }}1{{else}}0{{end}}),
    .DCRM4  ( {{if $ch4.DCrm   }}1{{else}}0{{end}}),
    .DCRM5  ( {{if $ch5.DCrm   }}1{{else}}0{{end}}),
    .STEREO ( {{if .Stereo}}     1{{else}}0{{end}}),
    // Fractional cen for 192kHz
    .FRACW( {{ .FracW }}), .FRACN({{.FracN}}), .FRACM({{.FracM}})
) u_rcmix(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .mute   ( mute      ),
    .sample ( sample    ),
    .ch_en  ( snd_en    ),
    .gpole  ( {{ .GlobalPole }} ), {{ if ne .GlobalFcut 0 }} // {{ .GlobalFcut }} Hz {{ end }}
    .ch0    ( {{ if $ch0.Name }}{{ if $ch0.Stereo }}{ {{$ch0.Name}}_l,{{$ch0.Name}}_r }{{ else }}{{ $ch0.Name }}{{end}}{{else}}16'd0{{end}} ),
    .ch1    ( {{ if $ch1.Name }}{{ if $ch1.Stereo }}{ {{$ch1.Name}}_l,{{$ch1.Name}}_r }{{ else }}{{ $ch1.Name }}{{end}}{{else}}16'd0{{end}} ),
    .ch2    ( {{ if $ch2.Name }}{{ if $ch2.Stereo }}{ {{$ch2.Name}}_l,{{$ch2.Name}}_r }{{ else }}{{ $ch2.Name }}{{end}}{{else}}16'd0{{end}} ),
    .ch3    ( {{ if $ch3.Name }}{{ if $ch3.Stereo }}{ {{$ch3.Name}}_l,{{$ch3.Name}}_r }{{ else }}{{ $ch3.Name }}{{end}}{{else}}16'd0{{end}} ),
    .ch4    ( {{ if $ch4.Name }}{{ if $ch4.Stereo }}{ {{$ch4.Name}}_l,{{$ch4.Name}}_r }{{ else }}{{ $ch4.Name }}{{end}}{{else}}16'd0{{end}} ),
    .ch5    ( {{ if $ch5.Name }}{{ if $ch5.Stereo }}{ {{$ch5.Name}}_l,{{$ch5.Name}}_r }{{ else }}{{ $ch5.Name }}{{end}}{{else}}16'd0{{end}} ),
    .p0     ( {{ if $ch0.Pole }}{{$ch0.Pole}}{{else}}30'h0{{end}}), {{if $ch0.Name }}// {{ index $ch0.Fcut 0}} Hz, {{ index $ch0.Fcut 1 }} Hz {{end}}
    .p1     ( {{ if $ch1.Pole }}{{$ch1.Pole}}{{else}}30'h0{{end}}), {{if $ch1.Name }}// {{ index $ch1.Fcut 0}} Hz, {{ index $ch1.Fcut 1 }} Hz {{end}}
    .p2     ( {{ if $ch2.Pole }}{{$ch2.Pole}}{{else}}30'h0{{end}}), {{if $ch2.Name }}// {{ index $ch2.Fcut 0}} Hz, {{ index $ch2.Fcut 1 }} Hz {{end}}
    .p3     ( {{ if $ch3.Pole }}{{$ch3.Pole}}{{else}}30'h0{{end}}), {{if $ch3.Name }}// {{ index $ch3.Fcut 0}} Hz, {{ index $ch3.Fcut 1 }} Hz {{end}}
    .p4     ( {{ if $ch4.Pole }}{{$ch4.Pole}}{{else}}30'h0{{end}}), {{if $ch4.Name }}// {{ index $ch4.Fcut 0}} Hz, {{ index $ch4.Fcut 1 }} Hz {{end}}
    .p5     ( {{ if $ch5.Pole }}{{$ch5.Pole}}{{else}}30'h0{{end}}), {{if $ch5.Name }}// {{ index $ch5.Fcut 0}} Hz, {{ index $ch5.Fcut 1 }} Hz {{end}}
    {{- if (len .PCB) }}
    .g0     ( g0        ),
    .g1     ( g1        ),
    .g2     ( g2        ),
    .g3     ( g3        ),
    .g4     ( g4        ),
    .g5     ( g5        ),{{else}}
    {{- if .Rsum_feedback_res}}
    // Active summing network. Opamp feedback resistor {{.Rsum}} {{end}}
    .g0     ( {{ $ch0.Gain }} ), // {{ gain2dec $ch0.Gain }} {{with $ch0.Name}} {{.}}{{end}}
    .g1     ( {{ $ch1.Gain }} ), // {{ gain2dec $ch1.Gain }} {{with $ch1.Name}} {{.}}{{end}}
    .g2     ( {{ $ch2.Gain }} ), // {{ gain2dec $ch2.Gain }} {{with $ch2.Name}} {{.}}{{end}}
    .g3     ( {{ $ch3.Gain }} ), // {{ gain2dec $ch3.Gain }} {{with $ch3.Name}} {{.}}{{end}}
    .g4     ( {{ $ch4.Gain }} ), // {{ gain2dec $ch4.Gain }} {{with $ch4.Name}} {{.}}{{end}}
    .g5     ( {{ $ch5.Gain }} ), // {{ gain2dec $ch5.Gain }} {{with $ch5.Name}} {{.}}{{end}}{{end}}
    .gain   ( snd_vol   ),
    .mixed  ({{ if .Stereo }}{ snd_left, snd_right}{{else}} snd       {{end}}),
    .peak   ( snd_peak  ),
    .vu     ( snd_vu    )
);
`else
assign {{ if .Stereo }}{ snd_left, snd_right}{{else}}snd{{end}}=0;
assign snd_vu   = 0;
assign snd_peak = 0;
wire ncs;
jtframe_frac_cen #(.WC({{ .FracW }})) u_cen192(
    .clk    ( clk       ),
    .n      ( {{.FracN}} ),
    .m      ( {{.FracM}} ),
    .cen    ( {  ncs,sample }  ), // sample is always 192 kHz
    .cenb   (                  )
);
`endif{{ else }}
assign snd_vu   = 0;
assign snd_peak = 0;
{{ end }}