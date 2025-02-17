`ifndef JTFRAME_SIM_IODUMP /* verilator tracing_off */ `endif
jtframe_ioctl_dump #(
    {{- $first := true}}
    {{- range $k, $v := .Buses }}
    {{- if $first}}{{$first = false}}{{else}},{{end}}
    .DW{{$k}}( {{$v.DW}} ), .AW{{$k}}( {{$v.AW}} ){{end}}
) u_dump (
    .clk       ( clk        ),
    {{- range $k, $v := .Buses }}
    // dump {{$k}}
    .dout{{$k}}        ( {{$v.Dout}} ),
    .addr{{$k}}        ( {{$v.A}} ),
    .addr{{$k}}_mx     ( {{$v.Amx}} ),
    // restore
    .din{{$k}}         ( {{$v.Din}} ),
    .din{{$k}}_mx      ( {{with $v.Name}}{{.}}_dimx{{end}} ),
    .we{{$k}}          ( {{if eq $v.DW 8 }}{ 1'b0,{{ $v.We }} }{{else}}{{$v.We}}{{end}}),
    .we{{$k}}_mx       ( {{with $v.Name}}{{.}}_wemx{{end}} ),
    {{end }}
    .ioctl_addr ( ioctl_addr[23:0] ),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_aux  ( ioctl_aux ),
    .ioctl_wr   ( ioctl_wr  ),
`ifdef JTFRAME_IOCTL_RD
    .ioctl_din  ( ioctl_din ),
`else
    .ioctl_din  (           ),
`endif
    .ioctl_dout ( ioctl_dout)
);