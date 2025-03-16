{{ define "prom_dwnld.v" -}}
{{- $local_addr := (printf "%s%s" .Name "_waddr") -}}
{{- $local_we   := (printf "%s%s" .Name "_we")    -}}
{{- $local_dd   := (printf "%s%s" .Name "_dd")    -}}
{{- $local_subd := (printf "%s%s" $local_dd (data_range .)) -}}
// {{.Name}} PROM
wire [ 7:0]{{$local_dd}};
wire {{addr_range .}}{{$local_addr}};
wire       {{$local_we}};

jtframe_ioctl_range #(
    .AW({{.Addr_width}}),
    .OFFSET(JTFRAME_PROM_START+{{ printf "'h%X" .PROM_offset}})
) u_range_{{.Name}}(
    .clk        ( clk                ),
    .addr       ( raw_addr           ),
    .addr_rel   ( {{printf "%-18s" $local_addr}} ),
    .en         ( prog_we            ),
    .inrange    ( {{printf "%-18s" $local_we}} ),
    .din        ( raw_data[7:0]      ),
    .dout       ( {{printf "%-18s" $local_dd}} )
);

jtframe_prom #(
    .DW({{.Data_width}}),
    .AW({{.Addr_width}}){{ if .Sim_file }},
    .SIMFILE("{{.Name}}.bin"){{end}}
) u_prom_{{.Name}}(
    .clk        ( clk                ),
    .cen        ( 1'b1               ),
    .data       ( {{ printf "%-18s" $local_subd}} ),
    .rd_addr    ( {{ printf "%-18s" .Addr}} ),
    .wr_addr    ( {{ printf "%-18s" $local_addr }} ),
    .we         ( {{ printf "%-18s" $local_we }} ),
    .q          ( {{ printf "%-18s" .Dout}} )
);
{{ end }}