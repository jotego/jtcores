{{ if (len .Jsr) -}}
reg jsr_en;
reg [{{ sub .Aw 1}}:0] jsr_ua, jsr_ret, uaddr;
{{- end }}

{{ range .Ss }}{{ if (ne .Bw 1) }}// wire [{{ sub .Bw 1 }}:0] {{ lower .Name }}_sel;
{{end}}{{ end }}
{{ range .Ss }}{{ if (eq .Bw 1) }}// wire       {{ lower .Name }};
{{end}}{{ end }}
reg  [{{ sub .Dw 1 }}:0] ucode_rom[0:2**{{.Aw}}-1];
{{ if .Latch }}reg  {{else}}wire {{end}}[{{ sub .Dw 1 }}:0] ucode_data;

initial begin
    $readmemb("{{.Rom}}",ucode_rom);
end

{{ if .Latch }}always @(posedge clk) if(!cen) ucode_data = ucode_rom[uaddr];{{- else -}}
               assign ucode_data = ucode_rom[uaddr];{{ end }}

{{ range .Ss }}{{ if (eq .Bw 1) }}assign {{ lower .Name | printf "%-11s" }}= ucode_data[{{ printf "%2d" .Pos }}+:{{ .Bw }}];
{{end}}{{- end }}
{{- range .Ss }}{{ if (ne .Bw 1) }}assign {{ lower .Name | printf "%s_sel" | printf "%-11s" }}= ucode_data[{{ printf "%2d" .Pos }}+:{{ .Bw }}];
{{end}}{{- end }}

{{- $aw := .Aw }}
{{- $entryLen := .EntryLen }}
{{ with .Jsr }}
always @* begin
    case( jsr_sel ){{ range . }}{{ if .Name }}
        {{ printf "%s_JSR:" .Name | printf "%-12s" | upper }} begin jsr_en=1; jsr_ua = {{ printf "%d" $aw }}'{{ printf "h%02X*" .Start}}{{printf "%d" $aw}}'d{{ $entryLen }}; end {{ end -}}{{ end }}
        RET_JSR:     begin jsr_en=1; jsr_ua = jsr_ret; end
        default:     begin jsr_en=0; jsr_ua = 'h00; end
    endcase
end
{{ end }}