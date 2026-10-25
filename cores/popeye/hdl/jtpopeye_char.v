/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 12-10-2026 */

module jtpopeye_char(
    input             rst,
    input             clk,
    input             cen10,
    input             cen5,

    input      [11:0] ad,
    input      [ 7:0] dd,
    input             csv,
    input             memwr0,

    input      [ 7:0] h_raw,
    input             hb,
    input      [ 7:0] v,
    input             vb,
    input             rv,

    output     [11:0] char_addr,
    input      [ 7:0] char_data,

    output     [ 9:0] text_addr,
    output     [ 9:0] text_cpu_addr,
    output            text_we,
    output            color_we,
    input      [ 7:0] text_dout,
    input      [ 7:0] color_dout,

    output reg        txtv,
    output     [ 3:0] txtc
);

wire [ 5:0] adv;
wire [10:0] rom_addr;
wire [ 4:0] pxl;
wire        ddtwr, dotck, blankn;

assign adv       = ~ad[5:0];
assign text_cpu_addr     = { adv[5], ad[9:7], adv[4:3], ad[6], adv[2:0] };
assign ddtwr     = csv & memwr0;
assign text_we     = ddtwr && ad[11:10]==2'd0;
assign color_we      = ddtwr && ad[11:10]==2'd1;
assign dotck     = cen10 & ~cen5;
assign char_addr = { 1'b1, rom_addr };
assign txtc      = pxl[4:1];

always @(posedge clk) txtv <= ~pxl[0] | vb;

assign blankn = ~hb;

jtframe_tilemap #(
    .CW         ( 8         ),
    .PW         ( 5         ),
    .BPP        ( 1         ),
    .HDUMPW     ( 8         ),
    .HDUMP_OFFSET(-1         ),
    .VDUMPW     ( 8         ),
    .FLIP_VDUMP ( 0         ),
    .XOR_HFLIP  ( 1         )
) u_tilemap(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( dotck     ),
    .vdump      ( v         ),
    .hdump      ( h_raw     ),
    .blankn     ( blankn    ),
    .flip       ( rv        ),
    .vram_addr  ( text_addr ),
    .code       ( text_dout ),
    .pal        ( color_dout[3:0] ),
    .hflip      ( 1'b1      ),
    .vflip      ( 1'b0      ),
    .rom_addr   ( rom_addr  ),
    .rom_data   ( char_data ),
    .rom_cs     (           ),
    .rom_ok     ( blankn    ),
    .pxl        ( pxl       )
);

endmodule
