/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 27-9-2026 */

module jtskykid_text(
    input               rst, clk, pxl_cen, hs, flip,
    input        [ 8:0] hdump, vdump,

    output       [ 9:0] vram_addr,
    input        [15:0] vram_dout,

    output              rom_cs,
    output       [12:1] rom_addr,
    input        [15:0] rom_data,
    input               rom_ok,

    output       [ 5:0] pal,
    output       [ 3:0] cat,
    output       [ 1:0] pxl
);

wire [10:0] map_addr;
wire [ 5:0] c6 = map_addr[5:0]-6'd2;
wire [ 4:0] r5 = map_addr[10:6]+5'd2;
wire [ 3:0] npx;

assign vram_addr = c6[5] ? {5'd0,r5} + {c6[4:0],5'd0} : {5'd0,c6[4:0]} + {r5,5'd0};
assign pxl = npx[1:0];

jtframe_scroll #(
    .CW         ( 9         ),
    .PW         ( 14        ),
    .VA         ( 11        ),
    .MAP_HW     ( 9         ),
    .MAP_VW     ( 8         ),
    .FLIP_HW    ( 9         )
) u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .blankn     ( 1'b1      ),
    .flip       ( flip      ),
    .scrx       ( flip ? 9'h158 : 9'h1c8 ),
    .scry       ( 8'hf0     ),
    .vram_addr  ( map_addr  ),
    .code       ( {flip,vram_dout[7:0]} ),
    .pal        ( {vram_dout[7:4],vram_dout[13:8]} ),
    .hflip      ( 1'b0      ),
    .vflip      ( flip      ),
    .rom_addr   ( rom_addr  ),
    .rom_data   ( {16'd0,rom_data[15:12],rom_data[7:4],rom_data[11:8],rom_data[3:0]} ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .pxl        ( {cat,pal,npx} )
);

endmodule
