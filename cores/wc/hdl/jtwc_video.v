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
    Date: 27-10-2024 */

module jtwc_video(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             hflip,
    input             vflip,
    output            lhbl,
    output            lvbl,
    output            vs,
    output            hs,
    // Character (fix) RAM
    output     [10:1] fix_addr,
    input      [15:0] fix_dout,
    output     [13:2] char_addr,
    input      [31:0] char_data,
    output            char_cs,
    input             char_ok,
    // Scroll
    input      [ 8:0] scrx,
    input      [ 7:0] scry,
    output     [10:1] vram_addr,
    input      [15:0] vram_data,
    output     [15:2] scr_addr,
    input      [31:0] scr_data,
    output            scr_cs,
    input             scr_ok,
    // Palette RAM
    output     [ 9:0] pal_addr,
    input      [15:0] pal_dout,
    // Output
    output     [ 3:0] red,
    output     [ 3:0] green,
    output     [ 3:0] blue,
    // Debug
    input      [ 3:0] gfx_en
);

wire [31:0] char_sorted, scr_sorted;
wire [15:2] scr_araw;
wire [ 9:0] scr_code;
wire [ 8:0] fix_code, vdump, vrender, hdump;
wire [ 7:0] fix_pxl, scr_pxl;
wire [ 6:0] obj_pxl;
wire [ 3:0] fix_pal, scr_pal;
wire        fix_hflip, fix_vflip, scr_hflip, scr_vflip;

assign fix_code  = {fix_dout[12],fix_dout[7:0]};
assign fix_pal   = fix_dout[11:8];
assign fix_hflip = fix_dout[14];
assign fix_vflip = fix_dout[15];
assign scr_code  = {scr_dout[13:12],scr_dout[7:0]};
assign scr_pal   = scr_dout[11:8];
assign scr_hflip = scr_dout[14];
assign scr_vflip = scr_dout[15];
assign scr_addr  = scr_araw;        // to do: sort bits

assign char_sorted = {
char_data[31],char_data[27],char_data[23],char_data[19],char_data[15],char_data[11],char_data[7],char_data[3],
char_data[30],char_data[26],char_data[22],char_data[18],char_data[14],char_data[10],char_data[6],char_data[2],
char_data[29],char_data[25],char_data[21],char_data[17],char_data[13],char_data[ 9],char_data[5],char_data[1],
char_data[28],char_data[24],char_data[20],char_data[16],char_data[12],char_data[ 8],char_data[4],char_data[0]
};

assign scr_sorted = {
scr_data[31],scr_data[27],scr_data[23],scr_data[19],scr_data[15],scr_data[11],scr_data[7],scr_data[3],
scr_data[30],scr_data[26],scr_data[22],scr_data[18],scr_data[14],scr_data[10],scr_data[6],scr_data[2],
scr_data[29],scr_data[25],scr_data[21],scr_data[17],scr_data[13],scr_data[ 9],scr_data[5],scr_data[1],
scr_data[28],scr_data[24],scr_data[20],scr_data[16],scr_data[12],scr_data[ 8],scr_data[4],scr_data[0]
};

jtframe_vtimer #(
    .VB_START   ( 9'hf7     ),
    .VB_END     ( 9'h7      ),
    .VCNT_END   ( 9'd271    ),
    .VS_START   ( 9'h106    ),
    .HS_START   ( 9'h1b5    ),
    .HB_START   ( 9'h181    ),
    .HJUMP      ( 1         ),
    .HB_END     ( 9'd9      ),
    .HINIT      ( 9'd255    )
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

jtframe_tilemap #(
    .CW ( 9 ),
    .PW ( 8 )
    // .HDUMP_OFFSET( -2 )
) u_char(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .blankn     ( LVBL      ),
    .flip       ( flip      ),

    .vram_addr  ( fix_addr  ),  // {code, V parts, H part}

    .code       ( fix_code  ),
    .pal        ( fix_pal   ),
    .hflip      ( fix_hflip ),
    .vflip      ( fix_vflip ),

    .rom_cs     ( char_cs     ),
    .rom_addr   ( char_addr   ),
    .rom_data   ( char_sorted ), // plane3,plane2,plane1,plane0, each 8 bits
    .rom_ok     ( char_ok     ),

    .pxl        ( fix_pxl     )
);

jtframe_scroll #(
    .SIZE        (   16 ),  // tile width  = 16pxl
    .VW          (    3 ),  // tile height = 8pxl
    .VA          (    9 ),
    .PW          (    8 ),
    .XOR_HFLIP   (    1 ),
    .HJUMP       (    0 )
) u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .hs         ( hs        ),

    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .blankn     ( LVBL      ),  // if !blankn there are no ROM requests
    .flip       ( flip      ),
    .scrx       ( scrx      ),
    .scry       ( scry      ),

    .vram_addr  ( vram_araw ),

    .code       ( scr_code  ),
    .pal        ( scr_pal   ),
    .hflip      ( scr_hflip ),
    .vflip      ( scr_vflip ),

    .rom_addr   ( scr_araw  ),
    .rom_data   ( scr_sorted),
    .rom_cs     ( scr_cs    ),
    .rom_ok     ( scr_ok    ),      // ignored. It assumes that data is always right

    .pxl        ( scr_pxl   )
);

jtwc_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .obj        ( obj_pxl   ),
    .fix        ( fix_pxl   ),
    .scr        ( scr_pxl   ),
    .pal_addr   ( pal_addr  ),
    .pal_dout   ( pal_dout  ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .gfx_en     ( gfx_en    )
);

endmodule
