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
    Date: 2-12-2019 */


module jtdd_video(
    input              rst,
    input              clk,
    input              clk_cpu,
    input              pxl_cen,
    // CPU bus
    input      [12:0]  cpu_AB,
    input              cpu_wrn,
    input      [ 7:0]  cpu_dout,
    // Palette
    input              pal_cs,
    output     [ 7:0]  pal_dout,
    // Char
    output     [15:2]  char_addr,
    input      [31:0]  char_data,
    output             char_cs,
    input              char_ok,
    output     [10:1]  cram_addr,
    input      [15:0]  cram_data,
    // Scroll
    input              vram_cs,
    input      [ 8:0]  scrhpos,
    input      [ 8:0]  scrvpos,
    output     [ 7:0]  scr_dout,
    output     [16:0]  scr_addr,
    input      [15:0]  scr_data,
    input              scr_ok,
    // Object
    output     [19:2]  obj_addr,
    input      [31:0]  obj_data,
    input              obj_ok,
    output             obj_cs,
    output     [ 8:0]  oram_addr,
    input      [ 7:0]  oram_data,
    // video signals
    output             VBL,
    output             LVBL,
    output             VS,
    output             LHBL,
    output             HS,
    output             IMS, // Interrupt Middle Screen
    input              flip,
    output             H8,
    // PROM programming
    input [7:0]        prog_addr,
    input [3:0]        prom_din,
    input              prom_prio_we,
    // Pixel output
    output     [3:0]   red,
    output     [3:0]   green,
    output     [3:0]   blue,
    // Debug
    input      [7:0]   debug_bus,
    input      [3:0]   gfx_en
);

wire [6:0]  char_pxl;  // called mcol in schematics
wire [7:0]  obj_pxl;  // called ocol in schematics
wire [7:0]  scr_pxl;  // called bcol in schematics
wire [8:0]  hdump, vdump;
wire        HBL;

assign IMS = vdump[3];
assign VBL = ~LVBL;
assign HBL = ~LHBL;
assign H8 = hdump[3];

jtframe_vtimer #(
    .VB_START   ( 9'hf7     ),
    .VB_END     ( 9'h7      ),
    .VCNT_END   ( 9'd271    ),
    .VS_START   ( 9'h106    ),
    .HS_START   ( 9'h1ae    ),
    .HB_START   ( 9'h184    ),
    .HJUMP      ( 1         ),
    .HB_END     ( 9'd4      ),
    .HINIT      ( 9'd255    )
)   u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    (           ),
    .vrender1   (           ),
    .H          ( hdump     ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .HS         ( HS        ),
    .VS         ( VS        )
);

wire [31:0] char_sorted = {
char_data[ 6],char_data[ 7],char_data[14],char_data[15],char_data[22],char_data[23],char_data[30],char_data[31],
char_data[ 4],char_data[ 5],char_data[12],char_data[13],char_data[20],char_data[21],char_data[28],char_data[29],
char_data[ 2],char_data[ 3],char_data[10],char_data[11],char_data[18],char_data[19],char_data[26],char_data[27],
char_data[ 0],char_data[ 1],char_data[ 8],char_data[ 9],char_data[16],char_data[17],char_data[24],char_data[25]
};

jtframe_tilemap #(
    .CW ( 11 ),
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

`ifndef NOSCROLL
jtdd_scroll u_scroll(
    .rst         ( rst              ),
    .clk         ( clk              ),
    .clk_cpu     ( clk_cpu          ),
    .pxl_cen     ( pxl_cen          ),
    .cpu_AB      ( cpu_AB[10:0]     ),
    .vram_cs     ( vram_cs          ),
    .cpu_wrn     ( cpu_wrn          ),
    .cpu_dout    ( cpu_dout         ),
    .scr_dout    ( scr_dout         ),
    .HPOS        ( hdump[7:0]       ),
    .VPOS        ( vdump[7:0]       ),
    .scrhpos     ( scrhpos          ),
    .scrvpos     ( scrvpos          ),
    .flip        ( flip             ),
    .rom_addr    ( scr_addr         ),
    .rom_data    ( scr_data         ),
    .rom_ok      ( scr_ok           ),
    .scr_pxl     ( scr_pxl          )
);
`else
assign scr_addr = 17'd0;
assign scr_pxl = 8'd0;
`endif

jtdd_obj u_obj(
    .clk         ( clk              ),
    .rst         ( rst              ),
    .pxl_cen     ( pxl_cen          ),
    // screen
    .hdump       ( hdump            ),
    .VPOS        ( vdump[7:0]       ),
    .flip        ( flip             ),
    .HBL         ( HBL              ),
    .hs          ( HS               ),
    // Video RAM
    .oram_addr   ( oram_addr        ),
    .oram_data   ( oram_data        ),
    // ROM access
    .rom_cs      ( obj_cs           ),
    .rom_addr    ( obj_addr         ),
    .rom_data    ( obj_data         ),
    .rom_ok      ( obj_ok           ),
    .pxl         ( obj_pxl          ),

    .debug_bus   ( debug_bus        )
);

jtdd_colmix u_colmix(
    .rst         ( rst              ),
    .clk         ( clk              ),
    .clk_cpu     ( clk_cpu          ),
    .pxl_cen     ( pxl_cen          ),
    .cpu_dout    ( cpu_dout         ),
    .pal_dout    ( pal_dout         ),
    .cpu_AB      ( cpu_AB[9:0]      ),
    .cpu_wrn     ( cpu_wrn          ),
    .LVBL        ( LVBL             ),
    .LHBL        ( LHBL             ),
    .char_pxl    ( char_pxl         ),
    .obj_pxl     ( obj_pxl          ),
    .scr_pxl     ( scr_pxl          ),
    .pal_cs      ( pal_cs           ),
    .prog_addr   ( prog_addr        ),
    .prom_din    ( prom_din         ),
    .prom_prio_we( prom_prio_we     ),
    .red         ( red              ),
    .green       ( green            ),
    .blue        ( blue             ),
    .gfx_en      ( gfx_en           )
);

endmodule