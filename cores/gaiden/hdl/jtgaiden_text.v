/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 2-1-2025 */

module jtgaiden_text(
    input               rst,
    input               clk,
    input               pxl_cen,

    input               hs,
    input               blankn,
    input               flip,
    input         [8:0] vdump,
    input         [8:0] hdump,
    input         [7:0] scr_x,
    input         [7:0] scr_y,

    // video RAM
    output       [11:1] ram_addr,
    input        [15:0] ram_dout,

    // ROM
    output              rom_cs,
    output       [15:2] rom_addr,
    input        [31:0] rom_data,
    input               rom_ok,

    output       [ 7:0] pxl
);

localparam [8:0] HOFFSET=1;
localparam       PXLW=8;

wire [10:0] code;
wire [ 3:0] pal;
wire [31:0] ram_full, sorted;
wire [ 7:0] pxl_nodly;

assign code = ram_full[16+:11];
assign pal  = ram_full[7:4];

jtframe_8x8x4_packed_msb u_conv(
    .raw    ( rom_data  ),
    .sorted ( sorted    )
);

jtframe_bram_burst u_txtburst(
    .clk    ( clk          ),
    .sel    ( ram_addr[11] ),
    .din16  ( ram_dout     ),
    .dout32 ( ram_full     )
);

jtframe_scroll #(.VA(10),.CW(11),.MAP_HW(8),.MAP_VW(8),.HJUMP(0)) u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .hs         ( hs        ),
    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .blankn     ( blankn    ),  // if !blankn there are no ROM requests
    .flip       ( flip      ),
    .scrx       ( scr_x     ),
    .scry       ( scr_y     ),

    .vram_addr  ( ram_addr[10:1] ),

    .code       ( code      ),
    .pal        ( pal       ),
    .hflip      ( flip      ),
    .vflip      ( 1'b0      ),

    .rom_addr   ( rom_addr  ),
    .rom_data   ( sorted    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),

    .pxl        ( pxl       )
);

endmodule