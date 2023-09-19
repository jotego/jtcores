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
    Date: 30-12-2018 */

module jtgng_video #(
// parameters from jtgng_char
parameter CHAR_AW   = 13,
// parameters from jtgng_scroll
parameter SCR_TILE4 = 0,  // 3 bpp (default=0) or 4 bpp (set to 1)
          SCR_AW    = 15,
// parameters from jtgng_colmix:
parameter SCRWIN        = 1,
          PALETTE_PROM  = 0,
          PALETTE_RED   = "",
          PALETTE_GREEN = "",
          PALETTE_BLUE  = "",
// parameters from jtgng_obj
parameter       OBJ_AW  = 16,
            OBJ_LAYOUT  = 0,
parameter [1:0] OBJ_PAL = 2'b01, // 01 for GnG, 10 for Commando
    // These two bits mark the region of the palette RAM/PROM where
    // palettes for objects are stored

// parameters from jtgng_obj:
          GNGPAL        = 0
) (
    input               rst,
    input               clk,
    input               cen12,
    input               cen6,
    input       [10:0]  cpu_AB,
    input       [ 7:0]  V,
    input       [ 8:0]  H,
    input               RnW,
    input               flip,
    input       [ 7:0]  cpu_dout,
    // CHAR
    input               char_cs,
    output      [ 7:0]  char_dout,
    input               char_ok,
    output              char_busy,
    output [CHAR_AW-1:0]char_addr,
    input       [15:0]  char_data,
    // SCROLL - ROM
    input               scr_cs,
    output      [ 7:0]  scr_dout,
    output [SCR_AW-1:0] scr_addr,
    input  [(SCR_TILE4 ? 15:23):0]  scr_data, // 16 bits if SCR_TILE4 is set
    input               scr_ok,
    output              scr_busy,
    input       [ 8:0]  scr_hpos,
    input       [ 8:0]  scr_vpos,
    // OBJ
    input               HINIT,
    output      [ 8:0]  obj_AB,
    input       [ 7:0]  main_ram,
    input               OKOUT,
    output              bus_req, // Request bus
    input               bus_ack, // bus acknowledge
    output              blcnten,    // bus line counter enable
    output [OBJ_AW-1:0] obj_addr,
    input       [15:0]  obj_data,
    input               obj_ok,
    // Color Mix
    input               preLHBL,
    input               preLVBL,
    input               LVBL_obj,
    input               LHBL_obj,
    output              LHBL,
    output              LVBL,
    // Palette PROMs
    input       [7:0]   prog_addr,
    input               prom_red_we,
    input               prom_green_we,
    input               prom_blue_we,
    input       [3:0]   prom_din,
    // Palette RAM
    input               blue_cs,
    input               redgreen_cs,
    input       [3:0]   gfx_en,
    // Pixel output
    output      [3:0]   red,
    output      [3:0]   green,
    output      [3:0]   blue
);

wire [5:0] char_pxl;
wire [5:0] obj_pxl;
wire scrwin;
wire [(SCR_TILE4?3:2):0] scr_col;
wire [2:0] scr_pal;
wire [3:0] cc;
wire [3:0] avatar_idx;

`ifdef NOVIDEO
`define NOCHAR
`define NOSCR
`define NOOBJ
`define NOCOLMIX
`endif

`ifndef NOCHAR

jtgng_char #(.HOFFSET(1),.ROM_AW(CHAR_AW)) u_char (
    .clk        ( clk           ),
    .pxl_cen    ( cen6          ),
    .AB         ( cpu_AB[10:0]  ),
    .V          ( V             ),
    .H          ( H[7:0]        ),
    .flip       ( flip          ),
    .din        ( cpu_dout      ),
    .dout       ( char_dout     ),
    // Bus arbitrion
    .char_cs    ( char_cs       ),
    .wr_n       ( RnW           ),
    .busy       ( char_busy     ),
    // ROM
    .char_addr  ( char_addr     ),
    .rom_data   ( char_data     ),
    .rom_ok     ( char_ok       ),
    // Pixel output
    .char_on    ( 1'b1          ),
    .char_pxl   ( char_pxl      ),
    // unused
    .dseln      (               ),
    .prog_addr  (               ),
    .prog_din   (               ),
    .prom_we    (               )
);
`else
assign char_mrdy = 1'b1;
`endif

`ifndef NOSCR
jtgng_scroll #(
    .HOFFSET( 1         ),
    .TILE4  ( SCR_TILE4 ),
    .ROM_AW ( SCR_AW    )
) u_scroll (
    .clk        ( clk           ),
    .pxl_cen    ( cen6          ),
    // screen position
    .H          ( H             ),
    .V          ( V[7:0]        ),
    .hpos       ( scr_hpos      ),
    .vpos       ( scr_vpos      ),
    .flip       ( flip          ),
    // bus arbitrion
    .Asel       ( cpu_AB[10]    ),
    .AB         ( cpu_AB[9:0]   ),
    .scr_cs     ( scr_cs        ),
    .din        ( cpu_dout      ),
    .dout       ( scr_dout      ),
    .wr_n       ( RnW           ),
    .busy       ( scr_busy      ),
    // ROM
    .scr_addr   ( scr_addr      ),
    .rom_data   ( scr_data      ),
    .rom_ok     ( scr_ok        ),
    // pixel output
    .scr_col    ( scr_col       ),
    .scr_pal    ( { scrwin, scr_pal } )
);
`else
assign scr_busy   = 1'b1;
assign scr_col    = 0;
assign scr_pal    = 3'd0;
assign scrwin     = 1'd0;
assign scr_addr   = 15'd0;
assign scr_dout   = 8'd0;
`endif

`ifndef NOOBJ
jtgng_obj #(
    .ROM_AW    ( OBJ_AW     ),
    .LAYOUT    ( OBJ_LAYOUT )
)
u_obj (
    .rst        ( rst         ),
    .clk        ( clk         ),
    .draw_cen   ( cen12       ),
    .dma_cen    ( cen6        ),
    .pxl_cen    ( cen6        ),
    .AB         ( obj_AB      ),
    .DB         ( main_ram    ),
    .OKOUT      ( OKOUT       ),
    .bus_req    ( bus_req     ),
    .bus_ack    ( bus_ack     ),
    .blen       ( blcnten     ),
    .LHBL       ( LHBL_obj    ),
    .LVBL       ( LVBL        ),
    .LVBL_obj   ( LVBL_obj    ),
    .HINIT      ( HINIT       ),
    .flip       ( flip        ),
    .V          ( V[7:0]      ),
    .H          ( H           ),
    // SDRAM interface
    .obj_addr   ( obj_addr    ),
    .obj_data   ( obj_data    ),
    .rom_ok     ( obj_ok      ),
    // pixel data
    .obj_pxl    ( obj_pxl     ),
    // unused
    .prog_addr  (             ),
    .prog_din   (             ),
    .prom_hi_we ( 1'b0        ),
    .prom_lo_we ( 1'b0        ),
    .OBJON      ( 1'b1        )
);
`else
assign obj_addr = {OBJ_AW{1'b0}};
assign obj_pxl  = 6'd0;
assign bus_req  = 1'b0;
`endif

`ifndef NOCOLMIX
jtgng_colmix #(
    .SCRWIN       ( SCRWIN       ),
    .OBJ_PAL      ( OBJ_PAL      ),
    .PALETTE_PROM ( PALETTE_PROM ),
    .PALETTE_RED  ( PALETTE_RED  ),
    .PALETTE_GREEN( PALETTE_GREEN),
    .PALETTE_BLUE ( PALETTE_BLUE ),
    .GNGPAL       ( GNGPAL       )
)u_colmix (
    .rst          ( rst           ),
    .clk          ( clk           ),
    .cen6         ( cen6          ),

    .char_pxl     ( char_pxl      ),
    .scr_pxl      ( {scrwin, scr_pal, scr_col} ),
    .obj_pxl      ( obj_pxl       ),
    .preLHBL      ( preLHBL       ),
    .preLVBL      ( preLVBL       ),
    .LVBL         ( LVBL          ),
    .LHBL         ( LHBL          ),

    // PROMs
    .prog_addr    ( prog_addr     ),
    .prom_red_we  ( prom_red_we   ),
    .prom_green_we( prom_green_we ),
    .prom_blue_we ( prom_blue_we  ),
    .prom_din     ( prom_din      ),

    // DEBUG
    .gfx_en       ( gfx_en        ),

    // CPU interface
    .AB           ( cpu_AB[7:0]   ),
    .blue_cs      ( blue_cs       ),
    .redgreen_cs  ( redgreen_cs   ),
    .DB           ( cpu_dout      ),

    // colour output
    .red          ( red           ),
    .green        ( green         ),
    .blue         ( blue          )
);
`else
assign  red = 4'd0;
assign blue = 4'd0;
assign green= 4'd0;
`endif

endmodule // jtgng_video
