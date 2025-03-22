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
    Date: 15-3-2025 */

module jtrthunder_scroll(
    input               rst,
    input               clk, pxl_cen, hs,
    input               flip,
    input        [ 8:0] hdump, vdump,
    input        [ 8:0] scrx,
    input        [ 7:0] scry,

    output       [11:1] vram_addr,
    input        [15:0] vram_dout,
    output       [ 4:0] dec_addr,
    input        [ 7:0] dec_data,

    output              rom_cs,
    output       [15:2] rom_addr,
    input        [31:0] rom_data,   // upper byte not used
    input               rom_ok,

    output       [10:0] pxl
);

parameter ID=0;

wire [11:0] pre_pxl;
wire [10:0] code;
wire [ 7:0] pal;
wire [ 2:0] code_msb;
wire        hflip, vflip;

assign pal  = vram_dout[15:8];
assign code = {code_msb,vram_dout[7:0]};
assign pxl  = {pre_pxl[11:4],pre_pxl[2:0]};
assign dec_addr = {ID[0],ID==0?pal[1:0]:2'b0,ID==1?pal[1:0]:2'b0};
assign code_msb = ID==0 ? dec_data[3:1] : dec_data[7:5];

jtframe_scroll #(.PW(12),.CW(11),.VA(11),.MAP_VW(8)) u_scroll (
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( hs            ),
    .vdump      ( vdump         ),
    .hdump      ( hdump         ),
    .blankn     ( 1'b1          ),
    .flip       ( flip          ),
    .scrx       ( scrx          ),
    .scry       ( scry          ),
    .vram_addr  ( vram_addr     ),
    .code       ( code          ),
    .pal        ( pal           ),
    .hflip      ( 1'b0          ),
    .vflip      ( 1'b0          ),
    .rom_addr   ( rom_addr      ),
    .rom_data   ( rom_data      ),
    .rom_cs     ( rom_cs        ),
    .rom_ok     ( rom_ok        ),
    .pxl        ( pre_pxl       )
);

endmodule