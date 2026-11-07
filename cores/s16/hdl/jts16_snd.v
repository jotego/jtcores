/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 16-3-2021 */

module jts16_snd(
    input                rst,
    input                clk,

    input                cen_fm,    // 4MHz
    input                cen_fm2,   // 2MHz
    input                cen_pcm,   // 6MHz

    input         [ 7:0] latch,
    input                irqn,
    output               ack,
    // ROM
    output        [14:0] rom_addr,
    output    reg        rom_cs,
    input         [ 7:0] rom_data,
    input                rom_ok,

    // PROM
    input         [ 9:0] prog_addr,
    input                prom_we,
    input         [ 7:0] prog_data,

    // ADPCM ROM
    output        [16:0] pcm_addr,
    output               pcm_cs,
    input         [ 7:0] pcm_data,
    input                pcm_ok,

    // Sound output
    output signed [15:0] fm_l, fm_r,
    output signed [ 7:0] pcm
);
`ifndef NOSOUND
wire [15:0] A;
reg         fm_cs, latch_cs, ram_cs;
wire        mreq_n, rfsh_n, iorq_n, int_n, nmi_n;
wire        WRn;
reg  [ 7:0] din, pcm_cmd;
reg         rom_ok2;
wire        rom_good, cmd_cs;
wire [ 7:0] dout, fm_dout, ram_dout, pcm_snd;
wire        pcm_irqn, pcm_rstn,
            wr_n, rd_n;

assign rom_good = rom_ok2 & rom_ok;
assign rom_addr = A[14:0];
assign ack      = latch_cs;
assign cmd_cs   = !iorq_n && A[7:6]==2 && !wr_n; // 80

always @(*) begin
    latch_cs = (!mreq_n && rfsh_n && A[15:12]==4'he && A[11]) // e800
             || (!iorq_n &&  A[7:6]==3);

    fm_cs    = !iorq_n && A[7:6]==0;
end

always @(posedge clk) begin
    ram_cs   <=  !mreq_n && rfsh_n && &A[15:11];
    rom_cs   <=  !mreq_n && rfsh_n && !A[15];
    rom_ok2  <= rom_ok;
    if( cmd_cs ) pcm_cmd <= dout;

    din      <= rom_cs   ? rom_data : (
                ram_cs   ? ram_dout : (
                fm_cs    ? fm_dout  : (
                latch_cs ? latch    : (
                    8'hff ))));
end

jtframe_ff u_ff(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .din    ( 1'b1      ),
    .q      (           ),
    .qn     ( nmi_n     ),
    .set    ( 1'b0      ),    // active high
    .clr    ( latch_cs  ),    // active high
    .sigedge( ~irqn     ) // signal whose edge will trigger the FF
);

jtframe_sysz80 #(.RAM_AW(11)) u_cpu(
    .rst_n      ( ~rst        ),
    .clk        ( clk         ),
    .cen        ( cen_fm      ),
    .cpu_cen    (             ),
    .int_n      ( int_n       ),
    .nmi_n      ( nmi_n       ),
    .busrq_n    ( 1'b1        ),
    .m1_n       (             ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     ( rfsh_n      ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .cpu_din    ( din         ),
    .cpu_dout   ( dout        ),
    .ram_dout   ( ram_dout    ),
    // manage access to ROM data from SDRAM
    .ram_cs     ( ram_cs      ),
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_good    )
);

//
//  YM2151 output port
//
//  D1 = /RESET line on 7751
//  D0 = /IRQ line on 7751
//

jt51 u_jt51(
    .rst        ( rst       ), // reset
    .clk        ( clk       ), // main clock
    .cen        ( cen_fm    ),
    .cen_p1     ( cen_fm2   ),
    .cs_n       ( !fm_cs    ), // chip select
    .wr_n       ( wr_n      ), // write
    .a0         ( A[0]      ),
    .din        ( dout      ), // data in
    .dout       ( fm_dout   ), // data out
    .ct1        ( pcm_rstn  ),
    .ct2        ( pcm_irqn  ),
    .irq_n      ( int_n     ),  // I do not synchronize this signal
    // Low resolution output (same as real chip)
    .sample     (           ), // marks new output sample
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_l      ),
    .xright     ( fm_r      )
);

jts16_pcm u_pcm(
    .rst        ( rst       ), // reset
    .clk        ( clk       ), // main clock
    .soft_rstn  ( pcm_rstn  ),

    .cen_pcm    ( cen_pcm   ),   // 6 MHz

    .ctrl       ( pcm_cmd   ),
    .irqn       ( pcm_irqn  ),
    // PROM
    .prog_addr  ( prog_addr ),
    .prom_we    ( prom_we   ),
    .prog_data  ( prog_data ),

    // PCM ROM
    .pcm_addr   ( pcm_addr  ),
    .pcm_cs     ( pcm_cs    ),
    .pcm_data   ( pcm_data  ),
    .pcm_ok     ( pcm_ok    ),
    // Sound output
    .snd        ( pcm       )
);
`else
assign  ack      = 0;
assign  rom_addr = 0;
assign  pcm_addr = 0;
assign  pcm_cs   = 0;
assign  fm_l     = 0;
assign  fm_r     = 0;
assign  pcm      = 0;
initial rom_cs   = 0;
`endif
endmodule
