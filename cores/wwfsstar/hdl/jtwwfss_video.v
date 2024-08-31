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
    input           clk,
    input           pxl_cen,

    input   [15:0] cpu_dout,
    input   [11:0] cpu_addr,

    // Char
    output     [16:2]  char_addr,
    input      [31:0]  char_data,
    output             char_cs,
    input              char_ok,
    output     [10:1]  cram_addr,
    input      [15:0]  cram_data,

    input          scr_cs,
    output  [ 7:0] scr_dout,

    input          oram_cs,
    output  [ 7:0] oram_dout,

    input   [ 1:0] pal_wen,
    output  [15:0] pal_dout,

    output  [ 3:0] red, green, blue,
    input   [ 3:0] gfx_en
);

wire [ 6:0] char_pxl, scr_pxl,, obj_pxl;
wire        blankn;

wire [31:0] char_sorted = {
char_data[ 6],char_data[ 7],char_data[14],char_data[15],char_data[22],char_data[23],char_data[30],char_data[31],
char_data[ 4],char_data[ 5],char_data[12],char_data[13],char_data[20],char_data[21],char_data[28],char_data[29],
char_data[ 2],char_data[ 3],char_data[10],char_data[11],char_data[18],char_data[19],char_data[26],char_data[27],
char_data[ 0],char_data[ 1],char_data[ 8],char_data[ 9],char_data[16],char_data[17],char_data[24],char_data[25]
};

assign blankn = LHBL & LVBL;

jtframe_tilemap #(
    .CW ( 12 ),
    .PW (  7 ),
    .HDUMP_OFFSET( -2 )
) u_char(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .blankn     ( LVBL      ),
    .flip       ( flip      ),

    .vram_addr  ( cram_addr ),

    .code       (cram_data[10: 0]),
    .pal        (cram_data[15:13]),
    .hflip      ( 1'b0        ),
    .vflip      ( 1'b0        ),

    .rom_cs     ( char_cs     ),
    .rom_addr   ( char_addr   ),
    .rom_data   ( char_sorted ),
    .rom_ok     ( char_ok     ),

    .pxl        ( char_pxl    )
);

jtframe_scroll #(
    .SIZE (16),
    VA   = 10,
    CW   = 12,
    PW   =  8,
    MAP_HW = 9,    // size of the map in pixels
    MAP_VW = 9,
    XOR_HFLIP = 0, // set to 1 so hflip gets ^ with flip
)u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    input              hs,

    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .blankn     ( blankn    ),  // if !blankn there are no ROM requests
    input              flip,    // Screen flip
    .scrx       ( scrx      ),
    .scry       ( scry      ),

    .vram_addr  ( vram_addr ),

    .code       ( vram_dout[11:0] ),
    .pal        ( vram_dout[14:12]),
    .hflip      ( vram_dout[15]   ),
    .vflip      ( 1'b0      ),

    .rom_addr   ( scr_addr  ),
    .rom_data   ( scr_data  ),
    .rom_cs     ( scr_cs    ),
    .rom_ok     ( scr_ok    ),      // ignored. It assumes that data is always right

    .pxl        ( scr_pxl   )
);

jtwwfss_colmix u_colmix(
    .clk        ( clk           ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),

    .cpu_addr   ( cpu_addr[9:1] ),
    .cpu_dout   ( cpu_dout      ),
    .cpu_din    ( pal_dout      ),
    .pal_wen    ( pal_wen       ),

    .char_pxl   ( char_pxl      ),
    .scr_pxl    ( scr_pxl       ),
    .obj_pxl    ( obj_pxl       ),

    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),

    .gfx_en     ( gfx_en        )
);

endmodule