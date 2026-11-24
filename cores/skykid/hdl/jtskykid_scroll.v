/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 27-9-2026 */

module jtskykid_scroll(
    input               rst, clk, pxl_cen, hs, flip, rot,
    input        [ 8:0] hdump, vdump,
    input        [ 8:0] scrx,
    input        [ 7:0] scry,

    output       [10:0] vram_addr,
    input        [15:0] vram_dout,

    output              rom_cs,
    output       [12:1] rom_addr,
    input        [15:0] rom_data,
    input               rom_ok,

    output       [ 6:0] pal,
    output       [ 1:0] pxl
);

wire [8:0] hos = rot ? 9'd133 : 9'd21;
wire [8:0] sx  = flip ? hos-{scrx[8:1],~scrx[0]} : scrx-hos;
wire [7:0] sy  = flip ? 8'd247-scry : scry+8'd9;
wire [3:0] npx;

assign pxl = npx[1:0];

jtframe_scroll #(
    .CW         ( 9         ),
    .PW         ( 11        ),
    .VA         ( 11        ),
    .MAP_HW     ( 9         ),
    .MAP_VW     ( 8         ),
    .XOR_HFLIP  ( 1         ),
    .FLIP_HW    ( 9         )
) u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .blankn     ( 1'b1      ),
    .flip       ( flip^rot  ),
    .scrx       ( sx        ),
    .scry       ( sy        ),
    .vram_addr  ( vram_addr ),
    .code       ( {vram_dout[8],vram_dout[7:0]} ),
    .pal        ( {vram_dout[8],vram_dout[14:9]} ),
    .hflip      ( 1'b0      ),
    .vflip      ( 1'b0      ),
    .rom_addr   ( rom_addr  ),
    .rom_data   ( {16'd0,rom_data[7:4],rom_data[15:12],rom_data[3:0],rom_data[11:8]} ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .pxl        ( {pal,npx} )
);

endmodule
