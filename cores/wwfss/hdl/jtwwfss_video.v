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
    Date: 31-8-2024 */

module jtwwfss_video(
    input           rst,
    input           clk,
    input           pxl_cen,

    input           flip,
    output          LHBL,
    output          LVBL,
    output          VS,
    output          HS,
    output          v8,

    // Char
    output  [10:1]  cram_addr,
    input   [15:0]  cram_data,
    output  [16:2]  char_addr,
    input   [31:0]  char_data,
    output          char_cs,
    input           char_ok,

    // Scroll
    input   [ 8:0]  scrx, scry,
    output  [10:1]  vram_addr,
    input   [15:0]  vram_data,
    output  [18:2]  scr_addr,
    input   [31:0]  scr_data,
    output          scr_cs,
    input           scr_ok,

    // Object
    output  [ 8:0]  oram_addr,
    input   [ 7:0]  oram_data,
    output  [20:2]  obj_addr,
    input   [31:0]  obj_data,
    output          obj_cs,
    input           obj_ok,

    output    [9:1] pal_addr,
    input    [15:0] pal_dout,

    output  [ 3:0]  red, green, blue,
    input   [ 3:0]  gfx_en
);

wire [18:2]  scr_araw;
wire [10:1] vram_araw;
wire [ 8:0] hdump, vdump, vrender;
wire [ 6:0] char_pxl, scr_pxl, obj_pxl;
wire        nc;

wire [31:0] char_sorted, scr_sorted;

assign char_sorted = {
char_data[ 6],char_data[ 7],char_data[14],char_data[15],char_data[22],char_data[23],char_data[30],char_data[31],
char_data[ 4],char_data[ 5],char_data[12],char_data[13],char_data[20],char_data[21],char_data[28],char_data[29],
char_data[ 2],char_data[ 3],char_data[10],char_data[11],char_data[18],char_data[19],char_data[26],char_data[27],
char_data[ 0],char_data[ 1],char_data[ 8],char_data[ 9],char_data[16],char_data[17],char_data[24],char_data[25]
};

assign scr_sorted = {
scr_data[12],scr_data[13],scr_data[14],scr_data[15],scr_data[28],scr_data[29],scr_data[30],scr_data[31],
scr_data[ 8],scr_data[ 9],scr_data[10],scr_data[11],scr_data[24],scr_data[25],scr_data[26],scr_data[27],
scr_data[ 4],scr_data[ 5],scr_data[ 6],scr_data[ 7],scr_data[20],scr_data[21],scr_data[22],scr_data[23],
scr_data[ 0],scr_data[ 1],scr_data[ 2],scr_data[ 3],scr_data[16],scr_data[17],scr_data[18],scr_data[19]
};

assign v8     = vdump[3];
assign vram_addr = { vram_araw[10], vram_araw[5], vram_araw[9:6], vram_araw[4:1] };
assign scr_addr  = { scr_araw[18:7], scr_araw[5:2], scr_araw[6] };

jtframe_vtimer #(
    .VB_START   ( 9'hf7     ),
    .VB_END     ( 9'h7      ),
    .VCNT_END   ( 9'd271    ),
    .VS_START   ( 9'h106    ),
    .HS_START   ( 9'h1b5    ),
    .HB_START   ( 9'h189    ),
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
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .HS         ( HS        ),
    .VS         ( VS        )
);

jtframe_tilemap #(
    .CW ( 12 ),
    .PW (  7 ),
    .HDUMP_OFFSET( 1 )
) u_char(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .blankn     ( LVBL      ),
    .flip       ( flip      ),

    .vram_addr  ( cram_addr ),

    .code       (cram_data[11: 0]),
    .pal        (cram_data[14:12]),
    .hflip      ( 1'b0        ),
    .vflip      ( 1'b0        ),

    .rom_cs     ( char_cs     ),
    .rom_addr   ( char_addr   ),
    .rom_data   ( char_sorted ),
    .rom_ok     ( char_ok     ),

    .pxl        ( char_pxl    )
);

wire [8:0] hlin = hdump[8] ? hdump-9'h80 : hdump;

jtframe_scroll #(
    .SIZE        (   16 ),
    .VA          (   10 ),
    .PW          (    7 ),
    .XOR_HFLIP   (    1 ), // set to 1 so hflip gets ^ with flip
    .HJUMP       (    0 )
) u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .hs         ( HS        ),

    .vdump      ( vdump     ),
    .hdump      ( hlin      ),
    .blankn     ( LVBL      ),  // if !blankn there are no ROM requests
    .flip       ( flip      ),
    .scrx       ( scrx      ),
    .scry       ( scry      ),

    .vram_addr  ( vram_araw ),

    .code       ( vram_data[11:0] ),
    .pal        ( vram_data[14:12]),
    .hflip      ( vram_data[15]   ),
    .vflip      ( 1'b0      ),

    .rom_addr   ( scr_araw  ),
    .rom_data   ( scr_sorted),
    .rom_cs     ( scr_cs    ),
    .rom_ok     ( scr_ok    ),      // ignored. It assumes that data is always right

    .pxl        ( scr_pxl   )
);

jtdd_obj #(.LAYOUT(2)) u_obj(
    .clk         ( clk              ),
    .rst         ( rst              ),
    .pxl_cen     ( pxl_cen          ),
    // screen
    .hdump       ( hdump            ),
    .VPOS        ( vrender[7:0]     ),
    .flip        ( flip             ),
    .HBL         ( ~LHBL            ),
    .hs          ( HS               ),
    // Video RAM
    .oram_addr   ( oram_addr        ),
    .oram_data   ( oram_data        ),
    // ROM access
    .rom_cs      ( obj_cs           ),
    .rom_addr    ( obj_addr         ),
    .rom_data    ( obj_data         ),
    .rom_ok      ( obj_ok           ),
    .pxl         ( {nc,obj_pxl}     ),

    .debug_bus   ( 8'd0             )
);

jtwwfss_colmix u_colmix(
    .clk        ( clk           ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),

    .char_pxl   ( char_pxl      ),
    .scr_pxl    ( scr_pxl       ),
    .obj_pxl    ( obj_pxl       ),

    .pal_addr   ( pal_addr      ),
    .pal_dout   ( pal_dout      ),

    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),

    .gfx_en     ( gfx_en        )
);

endmodule