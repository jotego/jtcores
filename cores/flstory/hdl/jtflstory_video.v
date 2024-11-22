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

module jtflstory_video(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             hflip,
    input             vflip,
    output            lhbl,
    output            lvbl,
    output            vs,
    output            hs,

    // Scroll
    output     [10:1] vram_addr,
    input      [15:0] vram_data,
    output     [14:2] scr_addr,
    input      [31:0] scr_data,
    output            scr_cs,
    input             scr_ok,

    // Objects
    //      RAM shared with CPU
    output     [ 7:0] oram_addr,
    input      [ 7:0] oram_dout,
    //      ROM
    output     [14:2] obj_addr,
    input      [31:0] obj_data,
    output            obj_cs,
    input             obj_ok,
);

wire [31:0] scr_sorted;
wire [ 8:0] vdump, vrender, hdump, scry;
wire [ 7:0] scr_pxl, obj_pxl;
wire [10:0] scr_code;
wire        scr_bank;
wire [ 3:0] scr_pal;

assign scr_code  = { scr_bank, vram_data[15:14], vram_data[7:0] }; // 1+2+8=11 bits
assign scr_pal   = { vram_data[13], vram_data[11:8] }; // upper bit = priority
assign scr_hflip = vram_data[11]; // bit 11 shared with pal
assign scr_vflip = vram_data[12];
assign scry      = {1'b0,oram_dout};

assign scr_sorted = ~{
    scr_data[28],scr_data[29],scr_data[30],scr_data[31],scr_data[20],scr_data[21],scr_data[22],scr_data[23],
    scr_data[24],scr_data[25],scr_data[26],scr_data[27],scr_data[16],scr_data[17],scr_data[18],scr_data[19],
    scr_data[12],scr_data[13],scr_data[14],scr_data[15],scr_data[ 4],scr_data[ 5],scr_data[ 7],scr_data[10],
    scr_data[ 8],scr_data[ 9],scr_data[10],scr_data[11],scr_data[ 0],scr_data[ 1],scr_data[ 2],scr_data[ 3]
};

jtframe_vtimer #(
    .V_START    ( 9'h0f0    ),
    .VCNT_END   ( 9'h1ff    ),
    .VB_START   ( 9'h1ef    ),
    .VB_END     ( 9'h10f    ),
    .VS_START   ( 9'h0f8    ),

    .HCNT_START ( 9'h080    ),
    .HCNT_END   ( 9'h1ff    ),
    .HS_START   ( 9'h0ad    ),
    .HB_START   ( 9'h089    ),
    .HB_END     ( 9'h109    )
)   u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   (           ),
    .H          ( hdump     ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( lhbl      ),
    .LVBL       ( lvbl      ),
    .HS         ( hs        ),
    .VS         ( vs        )
);

// original video seems to draw the tile map on the fly, whereas the
// objetcs are written to a single buffer during HB and then dumped on
// the same line. There is no double-line buffer, despite being enough memory
// to implement it. This sets a harsh limit of 128/16=8 sprites per line but
// that seems to be too few

// only vertical scroll available (column-wise)
jtframe_scroll #(
    .SIZE        (    8 ),
    .CW          (   10 ),
    .VR          ( 10+4 ),
    .VA          (   10 ),
    .MAP_VW      (    8 ),
    .MAP_HW      (    9 ),
    .PW          (    8 ),
    .XOR_HFLIP   (    1 ),
    .HJUMP       (    1 )
) u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .hs         ( hs        ),

    .vdump      ({1'b0,vdump[7:0]}),
    .hdump      ({1'b0,hdump[7:0]}),
    .blankn     ( lvbl      ),  // if !blankn there are no ROM requests
    .flip       ( flip      ),
    .scrx       ( 9'd0      ),
    .scry       ( scry      ),

    .vram_addr  ( vram_addr ),

    .code       ( scr_code  ),
    .pal        ( scr_pal   ),
    .hflip      ( scr_hflip ),
    .vflip      ( scr_vflip ),

    .rom_addr   ( scr_addr  ),
    .rom_data   ( scr_sorted),
    .rom_cs     ( scr_cs    ),
    .rom_ok     ( scr_ok    ),      // ignored. It assumes that data is always right

    .pxl        ( scr_pxl   )
);

jtflstory_obj u_obj(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .hs         ( hs        ),
    .flip       ( flip      ),

    .vrender    ( vrender   ),
    .hdump      ( hdump     ),
    // RAM shared with CPU
    .ram_addr   ( oram_addr ),
    .ram_dout   ( oram_dout ),
    // ROM
    .rom_addr   ( obj_addr  ),
    .rom_data   ( obj_data  ),
    .rom_cs     ( obj_cs    ),
    .rom_ok     ( obj_ok    ),
    .pxl        ( obj_pxl   )
);

endmodule