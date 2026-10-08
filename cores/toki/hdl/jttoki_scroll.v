/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 1-7-2025 */

module jttoki_scroll(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             cabal,

    input       [8:0] hdump,
    input       [8:0] vdump,
    input             hs,
    input       [7:0] line_number,

    input       [8:0] scroll_x,
    input       [8:0] scroll_y,

    output     [10:1] vram_addr,
    input      [15:0] vram_out,

    input      [31:0] gfx_data,
    input             gfx_ok,
    output     [18:2] gfx_addr,
    output            gfx_cs,

    output      [7:0] pxl
);

wire [31:0] sorted;
wire [11:0] code = vram_out[11:0];
wire [ 3:0] pal  = vram_out[15:12];
wire [ 8:0] scrx = cabal ? 9'd0 : scroll_x;
wire [ 8:0] scry = cabal ? 9'd0 : scroll_y;
wire [10:1] raw_vram_addr;

assign sorted = { gfx_data[12], gfx_data[13], gfx_data[14], gfx_data[15],
                  gfx_data[28], gfx_data[29], gfx_data[30], gfx_data[31],
                  gfx_data[ 8], gfx_data[ 9], gfx_data[10], gfx_data[11],
                  gfx_data[24], gfx_data[25], gfx_data[26], gfx_data[27],
                  gfx_data[ 4], gfx_data[ 5], gfx_data[ 6], gfx_data[ 7],
                  gfx_data[20], gfx_data[21], gfx_data[22], gfx_data[23],
                  gfx_data[ 0], gfx_data[ 1], gfx_data[ 2], gfx_data[ 3],
                  gfx_data[16], gfx_data[17], gfx_data[18], gfx_data[19] };

assign vram_addr = cabal ? {2'b00, raw_vram_addr[9:6], raw_vram_addr[4:1]} : raw_vram_addr;

jtframe_scroll #(
    .SIZE       ( 16         ),
    .PW         ( 8          ),
    .CW         ( 12         ),
    .VA         ( 10         ),
    .LATCH_SCRX ( 1          )
) u_scroll(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .pxl_cen    ( pxl_cen    ),

    .hs         ( hs         ),
    .vdump      ( vdump      ),
    .hdump      ( hdump      ),
    .blankn     ( 1'b1       ),
    .flip       ( 1'b0       ),
    .scrx       ( scrx       ),
    .scry       ( scry       ),

    .vram_addr  ( raw_vram_addr ),

    .code       ( code       ),
    .pal        ( pal        ),
    .hflip      ( 1'b0       ),
    .vflip      ( 1'b0       ),

    .rom_addr   ( gfx_addr   ),
    .rom_data   ( sorted     ),
    .rom_cs     ( gfx_cs     ),
    .rom_ok     ( gfx_ok     ),

    .pxl        ( pxl        )
);

endmodule
