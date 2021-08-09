/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 6-8-2021 */

module jtexed_video #(
    parameter SCR1W = 14,
    parameter SCR2W = 13,
    parameter OBJW  = 14
)(
    input               rst,
    input               clk,
    input               cen12,
    input               cen8,
    input               cen6,
    input               cen3,
    input               cpu_cen,
    input       [11:0]  cpu_AB,
    input               game_sel,
    input       [ 8:0]  V,
    input       [ 8:0]  H,
    input               RnW,
    input               flip,
    input       [ 7:0]  cpu_dout,
    // layer enable signals from CPU
    input               char_on,
    input               scr1_on,
    input               scr2_on,
    input               obj_on,
    // CHAR
    input               char_cs,
    output      [ 7:0]  char_dout,
    input               char_ok,
    output              char_busy,
    output      [12:0]  char_addr,
    input       [15:0]  char_data,
    // SCROLL - ROM
    output [SCR1W-1:0]  scr1_addr,
    input       [15:0]  scr1_data,
    input               scr1_ok,
    input       [ 9:0]  scr1_hpos,
    input       [10:0]  scr1_vpos,
    output      [12:0]  map1_addr, // 16kB in 8 bits or 8kW in 16 bits
    input       [15:0]  map1_data,
    input               map1_ok,
    output              map1_cs,
    // SCROLL 2
    output [SCR2W-1:0]  scr2_addr, // 64kB in 8 bits or 32kW in 16 bits
    input       [15:0]  scr2_data,
    output      [11:0]  map2_addr, //  8kB in 8 bits or 4kW in 16 bits
    input       [15:0]  map2_data,
    input               map2_ok,
    output              map2_cs,
    input       [15:0]  scr2_hpos,
    // OBJ
    input               HINIT,
    output      [ 8:0]  obj_AB,
    input       [ 7:0]  main_ram,
    input               OKOUT,
    output              bus_req, // Request bus
    input               bus_ack, // bus acknowledge
    output              blcnten, // bus line counter enable
    output  [OBJW-1:0]  obj_addr,
    input       [15:0]  obj_data,
    input               obj_ok,
    // Color Mix
    input               LVBL,
    input               LVBL_obj,
    input               LHBL,
    input               LHBL_obj,
    output              LHBL_dly,
    output              LVBL_dly,
    // Priority PROMs
    input       [7:0]   prog_addr,
    input      [11:0]   prom_we,
    input       [7:0]   prom_din,
    // Debug
    input       [3:0]   gfx_en,
    // Pixel output
    output      [3:0]   red,
    output      [3:0]   green,
    output      [3:0]   blue
);

localparam LAYOUT     = 11;

localparam SCR_OFFSET = 2;

localparam PROM_CHAR   = 3,
           PROM_SCR1   = 5,
           PROM_SCR2   = 4,
           PROM_OBJ_LO = 6,
           PROM_OBJ_HI = 6,
           PROM_PRIO   =11,
           PROM_RED    = 0,
           PROM_GREEN  = 1,
           PROM_BLUE   = 2;

wire [3:0] char_pxl;
wire [7:0] obj_pxl;
wire [3:0] scr1_pxl;
wire [5:0] scr2_pxl;

`ifndef NOCHAR

jtgng_char #(
    .HOFFSET (      8 ),
    .ROM_AW  (     13 ),
    .VFLIP   (      6 ),
    .HFLIP_EN(      0 ),
    .PALETTE (      0 ),
    .PALW    (      6 ),
    .LAYOUT  ( LAYOUT )
) u_char (
    .clk        ( clk           ),
    .pxl_cen    ( cen6          ),
    .cpu_cen    ( cpu_cen       ),
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
    // Pause screen
    .pause      ( 1'b0          ),
    .scan       (               ),
    .msg_low    ( 8'd0          ),
    .msg_high   ( 8'd0          ),
    // ROM
    .char_addr  ( char_addr     ),
    .rom_data   ( char_data     ),
    .rom_ok     ( char_ok       ),
    // Pixel output
    .char_on    ( char_on       ),
    .char_pxl   ( char_pxl      ),
    // Palette PROM
    .prog_addr  ( prog_addr     ),
    .prog_din   ( prom_din      ),
    .prom_we    ( prom_we[PROM_CHAR] ),
    // unused
    .dseln      (               )
);
`else
assign char_pxl  = ~7'd0;
assign char_mrdy = 1'b1;
`endif

jt1943_scroll #(
    .HOFFSET    (SCR_OFFSET+1 ),
    .AS8MASK    ( 1'b0      ),
    .ROM_AW     ( 15        ),
    .LAYOUT     ( LAYOUT+1  )
) u_scroll1 (
    .rst          ( rst           ),
    .clk          ( clk           ),
    .cen6         ( cen6          ),
    .LHBL         ( LHBL          ),
    .V128         ( {1'b0, V[7:0]} ),
    .H            ( H             ),
    .hpos         ( scr1_hpos     ),
    .SCxON        ( scr1_on       ),
    .vpos         ( scr1_vpos     ),
    .flip         ( flip          ),
    // Palette PROMs
    .prog_addr    ( prog_addr     ),
    .prom_hi_we   ( 1'b0          ),
    .prom_lo_we   ( prom_we[PROM_SCR1] ),
    .prom_din     ( prom_din      ),

    // ROM
    .map_addr     ( map1_addr     ),
    .map_data     ( map1_data     ),
    .map_cs       ( map1_cs       ),
    .map_ok       ( map1_ok       ),
    .scr_addr     ( scr1_addr     ),
    .scrom_data   ( scr1_data     ),
    .scr_pxl      ( scr1_pxl      )
);

jt1943_scroll #(
    .HOFFSET    (SCR_OFFSET+1 ),
    .AS8MASK    ( 1'b0      ),
    .ROM_AW     ( 15        ),
    .LAYOUT     ( LAYOUT+1  )
) u_scroll2 (
    .rst          ( rst           ),
    .clk          ( clk           ),
    .cen6         ( cen6          ),
    .LHBL         ( LHBL          ),
    .V128         ( {1'b0, V[7:0]} ),
    .H            ( H             ),
    .hpos         ( scr2_hpos     ),
    .SCxON        ( scr2_on       ),
    .vpos         ( 8'd0          ),
    .flip         ( flip          ),
    // Palette PROMs
    .prog_addr    ( prog_addr     ),
    .prom_hi_we   ( 1'b0          ),
    .prom_lo_we   ( prom_we[PROM_SCR2] ),
    .prom_din     ( prom_din      ),

    // ROM
    .map_addr     ( map2_addr     ),
    .map_data     ( map2_data     ),
    .map_cs       ( map2_cs       ),
    .map_ok       ( map2_ok       ),
    .scr_addr     ( scr2_addr     ),
    .scrom_data   ( scr2_data     ),
    .scr_pxl      ( scr2_pxl      )
);

`ifndef NOOBJ
jtgng_obj #(
    .ROM_AW       ( OBJW        ),
    .PALW         (  4          ),
    .PXL_DLY      (  1          ),
    .LAYOUT       ( LAYOUT      ),
    .PALETTE      (  1          )
) u_obj (
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
    // avatar display
    .pause      ( 1'b0        ),
    .avatar_idx (             ),
    // SDRAM interface
    .obj_addr   ( obj_addr    ),
    .obj_data   ( obj_data    ),
    .rom_ok     ( obj_ok      ),
    // pixel data
    .obj_pxl    ( obj_pxl     ),
    // palette PROM
    .prog_addr  ( prog_addr   ),
    .prog_din   ( prom_din[3:0] ),
    .prom_hi_we ( prom_we[PROM_OBJ_HI] ),
    .prom_lo_we ( prom_we[PROM_OBJ_LO] ),
    .OBJON      ( obj_on      )
);
`else
assign blcnten = 1'b0;
assign bus_req = 1'b0;
assign obj_pxl = ~6'd0;
`endif

`ifndef NOCOLMIX
jtexed_colmix u_colmix (
    .rst          ( rst           ),
    .clk          ( clk           ),
    .pxl_cen      ( cen6          ),

    .char_pxl     ( char_pxl      ),
    .scr1_pxl     ( scr1_pxl      ),
    .scr2_pxl     ( scr2_pxl      ),
    .obj_pxl      ( obj_pxl       ),
    .LVBL         ( LVBL          ),
    .LHBL         ( LHBL          ),
    .LHBL_dly     ( LHBL_dly      ),
    .LVBL_dly     ( LVBL_dly      ),

    // Palette and priority PROMs
    .prog_addr    ( prog_addr     ),
    .prom_prio_we ( prom_we[PROM_PRIO]         ),
    .prom_rgb_we  ( prom_we[PROM_BLUE:PROM_RED]),
    .prom_din     ( prom_din      ),

    // DEBUG
    .gfx_en       ( gfx_en        ),

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

endmodule