/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-5-2022 */

module jtpang_snd(
    input              clk,
    input              rst,
    input              fm_cen,  // 4 MHz
    input              pcm_cen, // 1 MHz

    // CPU interface
    input        [7:0] cpu_dout,
    input              wr_n,

    input              a0,
    input              fm_cs,

    output       [7:0] pcm_dout,
    input              pcm_cs,

    // ROM interface
    output      [17:0] rom_addr,
    input       [ 7:0] rom_data,
    input              rom_ok,

    output signed [15:0] fm,
    output signed [13:0] pcm
);

`ifndef NOSOUND

localparam [7:0] FM_GAIN  = 8'h10,
                 PCM_GAIN = 8'h0c;

wire signed [15:0] fm_snd;
wire signed [13:0] pcm_snd, pcm_raw;
wire               pcm_wrn;

assign pcm_wrn = wr_n | ~pcm_cs;


jt2413 u_jt2413 (
    .rst   ( rst        ),
    .clk   ( clk        ),
    .cen   ( fm_cen     ),
    .din   ( cpu_dout   ),
    .addr  ( a0         ),
    .cs_n  ( ~fm_cs     ),
    .wr_n  ( wr_n       ),
    .snd   ( fm         ),
    .sample(            )
);
/* verilator tracing_off */

jt6295 u_pcm (
    .rst     ( rst      ),
    .clk     ( clk      ),
    .cen     ( pcm_cen  ),
    .ss      ( 1'b1     ),
    .wrn     ( pcm_wrn  ),
    .din     ( cpu_dout ),
    .dout    ( pcm_dout ),
    .rom_addr( rom_addr ),
    .rom_data( rom_data ),
    .rom_ok  ( rom_ok   ),
    .sound   ( pcm      ),
    .sample  (          )
);

/* verilator tracing_on */
`else
assign pcm_dout = 8'd0;
assign rom_addr = 18'd0;
assign fm       = 16'sd0;
assign pcm      = 14'sd0;
`endif
endmodule
