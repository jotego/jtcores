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
    Date: 22-11-2024 */

module jtflstory_scroll(
    input             rst, clk, pxl_cen,
                      lvbl, hs,
                      gvflip, ghflip,
                      palwcfg,

    input      [ 1:0] bank,
    input             flen,

    output     [10:1] vram_addr,
    input      [15:0] vram_data,
    input      [ 7:0] oram_dout,

    output     [16:2] rom_addr,
    input      [31:0] rom_data,
    output            rom_cs,
    input             rom_ok,

    input      [ 8:0] vdump, hdump,
    output     [ 1:0] prio,
    output     [ 7:0] pxl
);

wire [31:0] sorted;
wire [ 8:0] scry;
wire [11:0] code;
wire [ 5:0] pal;
wire        hflip, vflip;
wire        flip;

assign code  =
    palwcfg ? { 1'b0, vram_data[13:11], vram_data[7:0] } :
    { bank, vram_data[15:14], vram_data[7:0] }; // 2+2+8=12 bits
assign pal   =
    palwcfg ? { 3'd0, vram_data[10:8] } :
        vram_data[13:8]; // upper 2 bits = priority
assign hflip = (vram_data[palwcfg ? 14 : 11 ]) & (flen | palwcfg); // xor with ghflip on PCB
assign vflip = (vram_data[palwcfg ? 15 : 12 ]) & (flen | palwcfg);
assign scry  = {1'b0,oram_dout};
assign flip  = gvflip | ghflip; // imperfect implementation

assign sorted = ~{
    rom_data[12],rom_data[13],rom_data[14],rom_data[15],rom_data[28],rom_data[29],rom_data[30],rom_data[31],
    rom_data[ 8],rom_data[ 9],rom_data[10],rom_data[11],rom_data[24],rom_data[25],rom_data[26],rom_data[27],
    rom_data[ 4],rom_data[ 5],rom_data[ 6],rom_data[ 7],rom_data[20],rom_data[21],rom_data[22],rom_data[23],
    rom_data[ 0],rom_data[ 1],rom_data[ 2],rom_data[ 3],rom_data[16],rom_data[17],rom_data[18],rom_data[19]
};

// only vertical scroll available (column-wise)
jtframe_scroll #(
    .SIZE        (    8 ),
    .CW          (   12 ),
    .VA          (   10 ),
    .MAP_VW      (    8 ),
    .MAP_HW      (    8 ),
    .PW          (   10 ),
    .XOR_HFLIP   (    1 ),
    .HJUMP       (    1 ),
    .COL_SCROLL  (    1 )
) u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .hs         ( hs        ),

    .vdump      ({1'b0,vdump[7:0]}),
    .hdump      ({1'b0,hdump[7:0]}),
    .blankn     ( lvbl      ),  // if !blankn there are no ROM requests
    .flip       ( flip      ),
    .scrx       ( 8'd0      ),
    .scry       ( scry[7:0] ),

    .vram_addr  ( vram_addr ),

    .code       ( code      ),
    .pal        ( pal       ),
    .hflip      ( hflip     ),
    .vflip      ( vflip     ),

    .rom_addr   ( rom_addr  ),
    .rom_data   ( sorted    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),      // ignored. It assumes that data is always right

    .pxl        ( {prio,pxl})
);

endmodule    