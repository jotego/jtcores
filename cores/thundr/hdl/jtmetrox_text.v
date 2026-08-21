/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-5-2025 */

module jtmetrox_text(
    input               rst,
    input               clk, pxl_cen,
    input               flip,
    input        [ 8:0] hdump, vdump,

    output       [10:1] vram_addr,
    input        [15:0] vram_dout,

    output              rom_cs,
    output       [12:1] rom_addr,
    input        [15:0] rom_data,
    input               rom_ok,

    output       [ 8:0] pxl
);

localparam [8:0] HOFFSET=9'o110-9'o2, VOFFSET=9'o20+9'o1;


wire [31:0] sorted;
wire [10:0] pre_pxl;
wire [10:1] vram_prea;
wire [ 8:0] code, hadj, vadj;
wire [ 6:0] pal;
wire [ 2:0] code_msb;
wire        blankn = hdump>=9'o60 && hdump<9'o550, border;

assign pal    = vram_dout[14:8];
assign code   = {vram_dout[15],vram_dout[7:0]};
assign pxl    = {pre_pxl[10:4],pre_pxl[1:0]};
assign hadj   = hdump - HOFFSET;
assign vadj   = vdump - VOFFSET;
assign border = hadj[8];
assign sorted = {16'd0,
    rom_data[15-:4], rom_data[7-:4],
    rom_data[ 8+:4], rom_data[0+:4]
};
assign vram_addr = border ? {vram_prea[5:1],vram_prea[10-:5]} : vram_prea;

jtframe_tilemap #(.PW(4+7),.CW(9)) u_scroll (
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .vdump      ( vadj          ),
    .hdump      ( hadj          ),
    .blankn     ( blankn        ),
    .flip       ( flip          ),
    .vram_addr  ( vram_prea     ),
    .code       ( code          ),
    .pal        ( pal           ),
    .hflip      ( 1'b0          ),
    .vflip      ( 1'b0          ),
    .rom_addr   ( rom_addr      ),
    .rom_data   ( sorted        ),
    .rom_cs     ( rom_cs        ),
    .rom_ok     ( rom_ok        ),
    .pxl        ( pre_pxl       )
);

endmodule