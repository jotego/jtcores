/*  This file is part of JTDD.
    JTDD program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTDD program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTDD.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 2-12-2019 */


module jtdd_video(
    input              clk,
    input              rst,
    input              pxl_cen,
    input              pxl_cenb,
    // CPU bus
    input      [12:0]  cpu_AB,
    input              cpu_wrn,
    input      [ 7:0]  cpu_dout,
    input              cen_Q,
    // Palette
    input              pal_cs,
    output     [ 7:0]  pal_dout,
    // Char
    input              char_cs,
    output     [ 7:0]  char_dout,
    output     [15:0]  char_addr,
    input      [ 7:0]  char_data,
    input              char_ok,
    // Scroll
    input              scr_cs,
    input      [ 8:0]  scrhpos,
    input      [ 8:0]  scrvpos,
    output     [ 7:0]  scr_dout,
    output     [16:0]  scr_addr,
    input      [15:0]  scr_data,
    input              scr_ok,
    // Object
    input              obj_cs,
    output     [ 7:0]  obj_dout,
    output     [18:0]  obj_addr,
    input      [15:0]  obj_data,
    input              obj_ok,    
    // video signals
    output             VBL,
    output             LVBL_dly,
    output             VS,
    output             HBL,
    output             LHBL_dly,
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
    input      [3:0]   gfx_en
);

wire [6:0]  char_pxl;  // called mcol in schematics
wire [7:0]  obj_pxl;  // called ocol in schematics
wire [7:0]  scr_pxl;  // called bcol in schematics
wire [7:0]  HPOS, VPOS;

assign IMS = VPOS[3];

jtdd_timing u_timing(
    .clk      (  clk      ),
    .rst      (  rst      ),
    .pxl_cen  (  pxl_cen  ),
    .flip     (  flip     ),
    .VPOS     (  VPOS     ),
    .HPOS     (  HPOS     ),
    .VBL      (  VBL      ),
    .VS       (  VS       ),
    .HBL      (  HBL      ),
    .HS       (  HS       ),
    .M        (           )
);

assign H8 = HPOS[3];

`ifndef NOCHAR
jtdd_char u_char(
    .clk         ( clk              ),
    .rst         ( rst              ),
    .pxl_cen     ( pxl_cen          ),
    .cpu_AB      ( cpu_AB[10:0]     ),
    .char_cs     ( char_cs          ),
    .cpu_wrn     ( cpu_wrn          ),
    .cpu_dout    ( cpu_dout         ),
    .cen_Q       ( cen_Q            ),
    .char_dout   ( char_dout        ),
    .HPOS        ( HPOS             ),
    .VPOS        ( VPOS             ),
    .flip        ( flip             ),
    .rom_addr    ( char_addr        ),
    .rom_data    ( char_data        ),
    .rom_ok      ( char_ok          ),
    .char_pxl    ( char_pxl         )
);
`else 
assign char_addr = 16'd0;
assign char_pxl  = 7'd0;
`endif

`ifndef NOSCROLL
jtdd_scroll u_scroll(
    .clk         ( clk              ),
    .rst         ( rst              ),
    .pxl_cen     ( pxl_cen          ),
    .pxl_cenb    ( pxl_cenb         ),
    .cpu_AB      ( cpu_AB[10:0]     ),
    .scr_cs      ( scr_cs           ),
    .cpu_wrn     ( cpu_wrn          ),
    .cpu_dout    ( cpu_dout         ),
    .cen_Q       ( cen_Q            ),
    .scr_dout    ( scr_dout         ),
    .HPOS        ( HPOS             ),
    .VPOS        ( VPOS             ),
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
    .cpu_AB      ( cpu_AB[8:0]      ),
    .cen_Q       ( cen_Q            ),
    .obj_cs      ( obj_cs           ),
    .cpu_wrn     ( cpu_wrn          ),
    .cpu_dout    ( cpu_dout         ),
    .obj_dout    ( obj_dout         ),
    // screen
    .HPOS        ( HPOS             ),
    .VPOS        ( VPOS             ),
    .flip        ( flip             ),
    .HBL         ( HBL              ),
    // ROM access
    .rom_addr    ( obj_addr         ),
    .rom_data    ( obj_data         ),
    .rom_ok      ( obj_ok           ),
    .obj_pxl     ( obj_pxl          )
);

jtdd_colmix u_colmix(
    .clk         ( clk              ),
    .rst         ( rst              ),
    .pxl_cen     ( pxl_cen          ),
    .cen_Q       ( cen_Q            ),
    .cpu_dout    ( cpu_dout         ),
    .pal_dout    ( pal_dout         ),
    .cpu_AB      ( cpu_AB[9:0]      ),
    .cpu_wrn     ( cpu_wrn          ),
    .VBL         ( VBL              ),
    .HBL         ( HBL              ),
    .LVBL_dly    ( LVBL_dly         ),
    .LHBL_dly    ( LHBL_dly         ),
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