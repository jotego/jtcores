/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 2-1-2025 */

module jtgaiden_scroll(
    input               rst,
    input               clk,
    input               pxl_cen,

    input               hs,
    input               blankn,
    input               flip,
    input         [8:0] vdump,
    input         [8:0] hdump,
    input        [15:0] scr_x,
    input        [15:0] scr_y,

    // video RAM
    output       [12:1] ram_addr,
    input        [15:0] ram_dout,

    // ROM
    output              rom_cs,
    output       [18:2] rom_addr,
    input        [31:0] rom_data,
    input               rom_ok,

    output       [ 8:0] pxl
);

wire [31:0] ram_full, sorted;
wire [18:2] raw_addr;
wire [11:0] code;
wire [ 4:0] attr;
wire [ 3:0] pal;
wire        blend;

assign code     = ram_full[16+:12];
assign blend    = ram_full[3];
assign pal      = ram_full[7:4];
assign attr     = {blend,pal};
assign rom_addr = {raw_addr[18:7],raw_addr[5],raw_addr[6],raw_addr[4:2]};

jtframe_8x8x4_packed_msb u_conv(
    .raw    ( rom_data  ),
    .sorted ( sorted    )
);

jtframe_bram_burst u_txtburst(
    .clk    ( clk          ),
    .sel    ( ram_addr[12] ),
    .din16  ( ram_dout     ),
    .dout32 ( ram_full     )
);

localparam [8:0] DEEP_IN_HB=9'h120;

jtframe_scroll #(
    .PW(9),.SIZE(16),.VA(11),
    .MAP_HW(10),.MAP_VW(9),
    .HJUMP(0),.HLOOP(DEEP_IN_HB))
u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .hs         ( hs        ),
    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .blankn     ( 1'b1      ),
    .flip       ( flip      ),
    .scrx       ( scr_x[9:0]),
    .scry       ( scr_y[8:0]),

    .vram_addr  ( ram_addr[11:1] ),

    .code       ( code      ),
    .pal        ( attr      ),
    .hflip      ( flip      ),
    .vflip      ( 1'b0      ),

    .rom_addr   ( raw_addr  ),
    .rom_data   ( sorted    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),

    .pxl        ( pxl       )
);

endmodule