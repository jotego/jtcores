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
    Date: 6-8-2021 */

module jtexed_video #(
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
    output      [ 8:0]  V,
    output      [ 8:0]  H,
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
    output      [14:2]  scr1_addr,
    input       [31:0]  scr1_data,
    input               scr1_ok,
    input       [10:0]  scr1_hpos,
    input       [10:0]  scr1_vpos,
    input       [ 2:0]  scr1_pal,
    output      [13:0]  map1_addr, // 16kB in 8 bits or 8kW in 16 bits
    input       [ 7:0]  map1_data,
    input               map1_ok,
    output              map1_cs,
    // SCROLL 2
    output      [13:2]  scr2_addr, // 64kB in 8 bits or 32kW in 16 bits
    input       [31:0]  scr2_data,
    input               scr2_ok,
    output      [11:0]  map2_addr, //  8kB in 8 bits or 4kW in 16 bits
    input       [15:0]  map2_data,
    input               map2_ok,
    output              map2_cs,
    input       [15:0]  scr2_hpos,
    input       [ 2:0]  scr2_pal,
    // OBJ
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
    output              LHBL,
    output              LVBL,
    output              HS,
    output              VS,
    // Priority PROMs
    input       [7:0]   prog_addr,
    input      [11:0]   prom_we,
    input       [7:0]   prom_din,
    // Debug
    input       [3:0]   gfx_en,
    input       [7:0]   debug_bus,
    // Pixel output
    output      [3:0]   red,
    output      [3:0]   green,
    output      [3:0]   blue
);

localparam LAYOUT     = 11;

localparam SCR_OFFSET = 2;

localparam PROM_CHAR   = 3,
           PROM_SCR1   = 5,
           PROM_SCR2L4 = 4,
           PROM_OBJ_LO = 6,
           PROM_OBJ_HI = 7,
           PROM_PRIO   =11,
           PROM_SCR2L3 =10,
           PROM_RED    = 0,
           PROM_GREEN  = 1,
           PROM_BLUE   = 2;

wire [3:0] char_pxl;
wire [7:0] obj_pxl;
wire [3:0] scr1_pxl;
wire [5:0] scr2_pxl;
wire [9:0] HF;
wire       LHBL_obj, LVBL_obj, preLHBL, preLVBL, HINIT;

jtgng_timer u_timer(
    .clk       ( clk      ),
    .cen6      ( cen6     ),
    .V         ( V        ),
    .H         ( H        ),
    .Hinit     ( HINIT    ),
    .LHBL      ( preLHBL  ),
    .LVBL      ( preLVBL  ),
    .LHBL_obj  ( LHBL_obj ),
    .LVBL_obj  ( LVBL_obj ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          )
);
`ifndef NOCHAR

jtgng_char #(
    .HOFFSET    (             6 ),
    .ROM_AW     (            13 ),
    .VFLIP      (             6 ),
    .HFLIP_EN   (             0 ),
    .PALETTE    (             1 ),
    .PALW       (             6 ),
    .LAYOUT     (        LAYOUT )
) u_char (
    .clk        ( clk           ),
    .pxl_cen    ( cen6          ),
    .AB         ( cpu_AB[10:0]  ),
    .V          ( V[7:0]        ),
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
    .char_on    ( char_on       ),
    .char_pxl   ( char_pxl      ),
    // Palette PROM
    .prog_addr  ( prog_addr     ),
    .prog_din   ( prom_din[3:0] ),
    .prom_we    ( prom_we[PROM_CHAR] ),
    // unused
    .dseln      (               )
);
`else
assign char_pxl  = ~7'd0;
assign char_mrdy = 1'b1;
`endif

jtexed_scr1 #(
    .HOFFSET      ( SCR_OFFSET  )
) u_scroll1 (
    .rst          ( rst         ),
    .clk          ( clk         ),
    .pxl_cen      ( cen6        ),
    .V            ( V           ),
    .H            ( H           ),
    .HF           ( HF          ),
    .flip         ( flip        ),
    .pal_bank     ( scr1_pal    ),
    .hpos         ( scr1_hpos   ),
    .vpos         ( scr1_vpos   ),

    // PROM access
    .prog_addr    ( prog_addr   ),
    .prog_din     (prom_din[3:0]),
    .prom_we      ( prom_we[PROM_SCR1] ),

    // Map ROM
    .map1_addr    ( map1_addr   ),
    .map1_data    ( map1_data   ),
    .map1_cs      ( map1_cs     ),
    .map1_ok      ( map1_ok     ),

    .rom1_addr    ( scr1_addr   ),
    .rom1_data    ( scr1_data   ),
    .rom1_ok      ( scr1_ok     ),
    // Output pixel
    .scr1_on      ( scr1_on     ),
    .scr1_pxl     ( scr1_pxl    ),
    .debug_bus    ( debug_bus   )
);

wire [1:0] scr2_we = { prom_we[PROM_SCR2L3], prom_we[PROM_SCR2L4] };

jtexed_scr2 #(
    .HOFFSET      ( SCR_OFFSET  )
) u_scroll2 (
    .rst          ( rst         ),
    .clk          ( clk         ),
    .pxl_cen      ( cen6        ),
    .V            ( V           ),
    .H            ( H           ),
    .HF           ( HF          ),
    .flip         ( flip        ),
    .pal_bank     ( scr2_pal    ),
    .hpos         ( scr2_hpos   ),

    // PROM access
    .prog_addr    ( prog_addr   ),
    .prog_din     (prom_din[3:0]),
    .prom_we      ( scr2_we     ),

    // Map ROM
    .map2_addr    ( map2_addr   ),
    .map2_data    ( map2_data   ),
    .map2_cs      ( map2_cs     ),
    .map2_ok      ( map2_ok     ),

    .rom2_addr    ( scr2_addr   ),
    .rom2_data    ( scr2_data   ),
    .rom2_ok      ( scr2_ok     ),
    // Output pixel
    .scr2_on      ( scr2_on     ),
    .scr2_pxl     ( scr2_pxl    ),
    .debug_bus    ( debug_bus   )
);

`ifndef NOOBJ
jtgng_obj #(
    .ROM_AW     ( OBJW        ),
    .PALW       (  4          ),
    .PXL_DLY    (  0          ),
    .LAYOUT     ( LAYOUT      ),
    .PALETTE    (  1          )
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
    .preLHBL      ( preLHBL       ),
    .preLVBL      ( preLVBL       ),
    .LVBL         ( LVBL          ),
    .LHBL         ( LHBL          ),

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