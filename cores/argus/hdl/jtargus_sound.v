module jtargus_sound(
    input             rst,
    input             clk,
    input             cen5,
    input             cen1p5,

    input      [ 7:0] snd_latch,

    output     [15:0] snd_addr,
    input      [ 7:0] snd_data,
    output reg        snd_cs,
    input             snd_ok,

    output signed [15:0] fm,
    output     [ 9:0] psg,
    output     [ 7:0] st_dout
);

wire [15:0] A;
wire [ 7:0] cpu_dout, ram_dout, ym_dout;
reg  [ 7:0] cpu_din;
wire        mreq_n, iorq_n, rd_n, wr_n, rfsh_n;
wire        ym_cs, ram_cs, latch_cs, int_n;
reg         rst_n;

assign snd_addr = A;
assign ram_cs   = !mreq_n && rfsh_n && A>=16'h8000 && A<=16'h87ff;
assign latch_cs = !mreq_n && rfsh_n && A==16'hc000;
assign ym_cs    = !iorq_n && !A[7] && (A[1:0]==2'b00 || A[1:0]==2'b01);
assign st_dout  = { int_n, ym_cs, latch_cs, snd_latch[4:0] };

always @* begin
    snd_cs = !rst && !mreq_n && rfsh_n && A[15]==1'b0;
    cpu_din =
        ym_cs    ? ym_dout   :
        snd_cs   ? snd_data   :
        ram_cs   ? ram_dout   :
        latch_cs ? snd_latch  :
        8'hff;
end

always @(posedge clk) rst_n <= ~rst;

jtframe_sysz80 #(.RAM_AW(11),.RECOVERY(1)) u_cpu(
    .rst_n      ( rst_n    ),
    .clk        ( clk      ),
    .cen        ( cen5     ),
    .cpu_cen    (          ),
    .int_n      ( int_n    ),
    .nmi_n      ( 1'b1     ),
    .busrq_n    ( 1'b1     ),
    .m1_n       (          ),
    .mreq_n     ( mreq_n   ),
    .iorq_n     ( iorq_n   ),
    .rd_n       ( rd_n     ),
    .wr_n       ( wr_n     ),
    .rfsh_n     ( rfsh_n   ),
    .halt_n     (          ),
    .busak_n    (          ),
    .A          ( A        ),
    .cpu_din    ( cpu_din  ),
    .cpu_dout   ( cpu_dout ),
    .ram_dout   ( ram_dout ),
    .ram_cs     ( ram_cs   ),
    .rom_cs     ( snd_cs   ),
    .rom_ok     ( snd_ok   )
);

jt03 #(.YM2203_LUMPED(1)) u_ym2203(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen1p5    ),
    .din        ( cpu_dout  ),
    .dout       ( ym_dout   ),
    .addr       ( A[0]      ),
    .cs_n       ( ~ym_cs    ),
    .wr_n       ( wr_n      ),
    .psg_snd    ( psg       ),
    .fm_snd     ( fm        ),
    .snd_sample (           ),
    .irq_n      ( int_n     ),

    .IOA_oe     (           ),
    .IOB_oe     (           ),
    .IOA_in     ( 8'd0      ),
    .IOB_in     ( 8'd0      ),
    .IOA_out    (           ),
    .IOB_out    (           ),
    .psg_A      (           ),
    .psg_B      (           ),
    .psg_C      (           ),
    .snd        (           ),
    .debug_view (           )
);

endmodule
