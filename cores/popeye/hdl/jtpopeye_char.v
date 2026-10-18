/* SPDX-FileCopyrightText: 2026 Chris Watson
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

    output reg        txtv,
    output     [ 3:0] txtc
);

wire [ 5:0] adv;
wire [ 9:0] cpu_a, vram_addr;
wire [ 7:0] code;
wire [ 3:0] pal;
wire [10:0] rom_addr;
wire [ 4:0] pxl;
wire        ddtwr, we5pr, we5s, dotck;

assign adv       = ~ad[5:0];
assign cpu_a     = { adv[5], ad[9:7], adv[4:3], ad[6], adv[2:0] };
assign ddtwr     = csv & memwr0;
assign we5pr     = ddtwr && ad[11:10]==2'd0;
assign we5s      = ddtwr && ad[11:10]==2'd1;
assign dotck     = cen10 & ~cen5;
assign char_addr = { 1'b1, rom_addr };
assign txtc      = pxl[4:1];

always @(posedge clk) txtv <= ~pxl[0] | vb;

jtframe_dual_ram #(.AW(10),.DW(8)) u_5pr(
    .clk0   ( clk       ),
    .data0  ( dd        ),
    .addr0  ( cpu_a     ),
    .we0    ( we5pr     ),
    .q0     (           ),
    .clk1   ( clk       ),
    .data1  ( 8'd0      ),
    .addr1  ( vram_addr ),
    .we1    ( 1'b0      ),
    .q1     ( code      )
);

jtframe_dual_ram #(.AW(10),.DW(4)) u_5s(
    .clk0   ( clk       ),
    .data0  ( dd[3:0]   ),
    .addr0  ( cpu_a     ),
    .we0    ( we5s      ),
    .q0     (           ),
    .clk1   ( clk       ),
    .data1  ( 4'd0      ),
    .addr1  ( vram_addr ),
    .we1    ( 1'b0      ),
    .q1     ( pal       )
);

jtframe_tilemap #(
    .CW         ( 8         ),
    .PW         ( 5         ),
    .BPP        ( 1         ),
    .HDUMPW     ( 8         ),
    .VDUMPW     ( 8         ),
    .FLIP_VDUMP ( 0         ),
    .XOR_HFLIP  ( 1         )
) u_tilemap(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( dotck     ),
    .vdump      ( v         ),
    .hdump      ( h_raw+8'd1),
    .blankn     ( ~hb       ),
    .flip       ( rv        ),
    .vram_addr  ( vram_addr ),
    .code       ( code      ),
    .pal        ( pal       ),
    .hflip      ( 1'b1      ),
    .vflip      ( 1'b0      ),
    .rom_addr   ( rom_addr  ),
    .rom_data   ( char_data ),
    .rom_cs     (           ),
    .rom_ok     ( ~hb       ),
    .pxl        ( pxl       )
);

endmodule
