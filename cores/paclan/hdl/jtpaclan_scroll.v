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
    Date: 18-5-2025 */

module jtpaclan_scroll(
    input               rst,
    input               clk, pxl_cen, hs,
    input               flip,
    input        [ 8:0] hdump, vdump,
    input        [ 8:0] scrx,

    output       [11:1] vram_addr,
    input        [15:0] vram_dout,

    output              rom_cs,
    output       [12:1] rom_addr,
    input        [15:0] rom_data,   // upper byte not used
    input               rom_ok,
    input        [ 7:0] debug_bus,

    output              prio,
    output       [ 9:0] pxl
);

parameter  LAYER   = 0,
           HBASE   = 9'd0,
           HOFFSET = -9'd32,
           VOFFSET = 8'd0;

localparam PALW=LAYER==0 ? 8 : 9,
           UNUSED=2,    // 2 bits unused as tilemap is 2bpp not 4bpp
           PRIO=13;

wire [31:0] sorted;
wire [12:0] pre_pxl;
wire [ 8:0] code, xadj;
wire [ 8:0] pal;
wire        hflip, vflip;

assign vflip= vram_dout[15];
assign hflip= vram_dout[14];
assign pal  = {vram_dout[PRIO],
    LAYER==0 ? {code[8:5],vram_dout[12:9]} :
               {code[8:6],vram_dout[13:9]} };
assign code = vram_dout[8:0];
assign xadj = scrx + HOFFSET + HBASE;

assign prio = pre_pxl[12];
assign pxl  = {pre_pxl[4+:8],pre_pxl[1:0]};

assign sorted   = {16'd0,
    rom_data[15-:4],rom_data[7-:4],
    rom_data[ 8+:4],rom_data[0+:4]
};

jtframe_scroll #(.PW(2+UNUSED+8+1),.CW(9),.VA(11),.MAP_VW(8)) u_scroll (
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( hs            ),
    .vdump      ( vdump         ),
    .hdump      ( hdump         ),
    .blankn     ( 1'b1          ),
    .flip       ( flip          ),
    .scrx       ( xadj          ),
    .scry       ( 8'd0          ),
    .vram_addr  ( vram_addr     ),
    .code       ( code          ),
    .pal        ( pal           ),
    .hflip      ( hflip         ),
    .vflip      ( vflip         ),
    .rom_addr   ( rom_addr      ),
    .rom_data   ( sorted        ),
    .rom_cs     ( rom_cs        ),
    .rom_ok     ( rom_ok        ),
    .pxl        ( pre_pxl       )
);

endmodule