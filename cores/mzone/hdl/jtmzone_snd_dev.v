// SPDX-License-Identifier: GPL-3.0-or-later

module jtmzone_snd_dev(
    input               rst,
    input               clk,
    input               LVBL,
    input       [ 8:0] hdump,
    input               intsnd,

    // Sound CPU bus
    output      [15:0]  A,
    input       [ 7:0]  cpu_din,
    output      [ 7:0]  cpu_dout,
    output              mreq_n,
    output              rd_n,
    output              wr_n,
    output              rfsh_n,
    input               rom_cs,
    input               rom_ok,
    input               shared_cs,

    // Board decoder strobes, qualified by the CPU write signal
    input               latch_cs,
    input               mcu_irq_cs,
    input               mcu_wdog_cs,

    // AY readback
    output      [ 7:0]  ay_dout,
    output              ay_rd,

    // 8039 ROM
    output      [11:0]  mcu_rom_addr,
    output              mcu_rom_cs,
    input       [ 7:0]  mcu_rom_data,
    input               mcu_rom_ok,

    // Sound output
    output       [7:0] psg0a, psg0b, psg0c,
    output       [3:0] psg0a_rcen, psg0b_rcen, psg0c_rcen,
    output       [7:0] dac
);

wire        [ 7:0] ay_iob, ay_oa;
wire        [ 7:0] ay_a8, ay_b8, ay_c8;
wire        [ 7:0] dac_status;
wire        [ 1:0] cpu_cen_v, dac_cen_v;
wire                cpu_cen, ay_cen, dac_cen, irq_rst, snmi_n;
wire                wdog_reset_n, snmi_set_n;
wire                shared_busy, cpu_rom_cs;
wire                ay_wr_addr, ay_wr_data;
wire                snd_irq;
wire                m1_n, iorq_n;
`ifdef NOSOUND
reg         [ 7:0] fast_timer;
`endif

`ifndef NOSOUND
assign psg0a = ay_a8;
assign psg0b = ay_b8;
assign psg0c = ay_c8;
// JTFRAME selects one pair of RC poles with a one-hot enable.
// Port B bit pairs select 10nF, 220nF, or both (230nF).
assign psg0a_rcen = 4'b0001 << ay_iob[1:0];
assign psg0b_rcen = 4'b0001 << ay_iob[3:2];
assign psg0c_rcen = 4'b0001 << ay_iob[5:4];
`else
assign psg0a         = 8'd0;
assign psg0b         = 8'd0;
assign psg0c         = 8'd0;
assign psg0a_rcen    = 4'b0001;
assign psg0b_rcen    = 4'b0001;
assign psg0c_rcen    = 4'b0001;
assign dac          = 8'd0;
assign mcu_rom_addr = 12'd0;
assign mcu_rom_cs   = 1'b0;
assign dac_cen      = 1'b0;
assign dac_status   = { fast_timer[7:4], 4'd0 };
assign ay_dout      = dac_status;
assign ay_iob       = 8'd0;
`endif

`ifdef MZONE_Z80_NO_WAIT
assign shared_busy = 1'b0;
assign cpu_rom_cs  = 1'b0;
`else
// Stall shared RAM accesses only during the busy horizontal phase.
// OR with shared_cs would prevent the CPU from completing the access.
assign shared_busy = shared_cs && hdump[1];
assign cpu_rom_cs  = rom_cs;
`endif
assign wdog_reset_n = ~mcu_wdog_cs;
assign snmi_set_n   = ~rst & (wdog_reset_n | A[0]);

// PCB Z80 clock is 18.432 MHz / 6 = 3.072 MHz. Divide the
// approximately 24.576 MHz sound clock by eight to match it.
jtframe_frac_cen #(.W(2),.WC(8)) u_cpu_cen(
    .clk    ( clk       ),
    .n      ( 8'd1      ),
    .m      ( 8'd8      ),
    .cen    ( cpu_cen_v ),
    .cenb   (           )
);

jtframe_cen3p57 #(.CLK24(1)) u_ay_cen(
    .clk      ( clk      ),
    .cen_3p57 (          ),
    .cen_1p78 ( ay_cen   )
);

`ifndef NOSOUND
jtframe_frac_cen #(.W(2),.WC(8)) u_dac_cen(
    .clk    ( clk       ),
    .n      ( 8'd7      ),  // close to 14.31818 MHz / 2 from the 24 MHz sound clock
    .m      ( 8'd24     ),
    .cen    ( dac_cen_v ),
    .cenb   (           )
);
`endif

assign cpu_cen = cpu_cen_v[0];
`ifndef NOSOUND
assign dac_cen = dac_cen_v[0];
`endif

`ifdef NOSOUND
always @(posedge clk) begin
    if( rst ) begin
        fast_timer  <= 8'd0;
    end else begin
        if( ay_cen ) fast_timer <= fast_timer + 8'd1;
    end
end
`endif

jtframe_ff u_irq(
    .rst      ( rst         ),
    .clk      ( clk         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        ( snd_irq     ),
    .qn       (             ),
    .set      ( 1'b0        ),
    .clr      ( irq_rst     ),
    .sigedge  ( ~LVBL       )
);

assign ay_oa      = dac_status;
assign ay_rd      = !iorq_n && !rd_n && (A[1:0] <= 2'd2);
assign ay_wr_addr = !iorq_n && !wr_n && (A[1:0] == 2'd0);
assign ay_wr_data = !iorq_n && !wr_n && (A[1:0] == 2'd2);

// LS74 ~RST = (~SIORQ | ~SM1) & ~RESET, converted to active-high reset.
assign irq_rst = rst | (!iorq_n && !m1_n);

jtframe_ff u_snmi(
    .rst      ( rst         ),
    .clk      ( clk         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( snmi_n      ),
    .set      ( ~snmi_set_n ),
    .clr      ( 1'b0        ),
    .sigedge  ( intsnd      )
);

// Use JTFRAME's registered ROM wait handling with the external shared RAM.
// Do not recover lost clock enables: preserve stalls rather than catching up.
jtframe_z80_devwait #(.RECOVERY(0)) u_cpu(
    .rst_n      ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cpu_cen   ),
    .cpu_cen    (           ),
    .rom_cs     ( cpu_rom_cs ),
    .rom_ok     ( rom_ok    ),
    .dev_busy   ( shared_busy ),
    .int_n      ( ~snd_irq  ),
    .nmi_n      ( snmi_n    ),
    .busrq_n    ( 1'b1      ),
    .m1_n       ( m1_n      ),
    .mreq_n     ( mreq_n    ),
    .iorq_n     ( iorq_n    ),
    .rd_n       ( rd_n      ),
    .wr_n       ( wr_n      ),
    .rfsh_n     ( rfsh_n    ),
    .halt_n     (           ),
    .busak_n    (           ),
    .A          ( A         ),
    .din        ( cpu_din   ),
    .dout       ( cpu_dout  )
);

`ifndef NOSOUND
jt49_bus u_ay(
    .rst_n      ( ~rst                    ),
    .clk        ( clk                     ),
    .clk_en     ( ay_cen                  ),
    .bdir       ( ay_wr_addr | ay_wr_data ),
    .bc1        ( ay_wr_addr | ay_rd      ),
    .din        ( cpu_dout                ),
    .sel        ( 1'b1                    ),
    .dout       ( ay_dout                 ),
    .sound      (                         ),
    .sample     (                         ),
    .IOA_in     ( ay_oa                   ),
    .IOA_out    (                         ),
    .IOA_oe     (                         ),
    .IOB_in     ( 8'd0                    ),
    .IOB_out    ( ay_iob                  ),
    .IOB_oe     (                         ),
    .A          ( ay_a8                   ),
    .B          ( ay_b8                   ),
    .C          ( ay_c8                   )
);

// B4 8039 DAC MCU
jtmzone_mcu u_b4(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( dac_cen       ),
    .din        ( cpu_dout      ),
    .latch_cs   ( latch_cs      ),
    .irq_cs     ( mcu_irq_cs    ),
    .status     ( dac_status    ),
    .rom_addr   ( mcu_rom_addr  ),
    .rom_cs     ( mcu_rom_cs    ),
    .rom_data   ( mcu_rom_data  ),
    .rom_ok     ( mcu_rom_ok    ),
    .dac        ( dac           )
);
`endif

endmodule
