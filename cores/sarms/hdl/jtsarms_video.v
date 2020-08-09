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
    Date: 9-8-2020 */

module jtsarms_video #(
    parameter SCRW = 18,
    parameter OBJW = 18
)(
    input               rst,
    input               clk,
    input               cen12,
    input               cen8,
    input               cen6,
    input               cen3,
    input               cpu_cen,
    input       [11:0]  cpu_AB,
    input       [ 8:0]  V,
    input       [ 8:0]  H,
    input               RnW,
    input               flip,
    input       [ 7:0]  cpu_dout,
    // Enable bits
    input               CHON,
    input               SCRON,
    input               OBJON,
    // CHAR
    input               char_cs,
    output      [ 7:0]  char_dout,
    input               char_ok,
    output              char_busy,
    output      [13:0]  char_addr,
    input       [15:0]  char_data,
    // SCROLL - ROM
    output  [SCRW-1:0]  scr_addr,
    input       [15:0]  scr_data,
    input               scr_ok,
    output              scr_busy,
    input       [15:0]  scr_hpos,
    input       [15:0]  scr_vpos,
    output      [13:0]  map_addr, // 32kB in 8 bits or 16kW in 16 bits
    input       [15:0]  map_data,
    // Star field
    output      [14:0]  star_addr, // 64kB in 8 bits or 32kW in 16 bits
    input       [15:0]  star_data,
    input       [15:0]  star_hpos,
    // OBJ
    input               HINIT,
    output      [12:0]  obj_AB,
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
    // input       [7:0]   prog_addr,
    // input               prom_prio_we,
    // input       [3:0]   prom_din,
    // Palette RAM
    input               blue_cs,
    input               redgreen_cs,
    input       [3:0]   gfx_en,
    // Pixel output
    output      [3:0]   red,
    output      [3:0]   green,
    output      [3:0]   blue
);

localparam LAYOUT     = 8;

localparam PXL_CHRW=6;
localparam SCR_OFFSET = 1;

wire [PXL_CHRW-1:0] char_pxl;
wire [6:0] obj_pxl;
wire [7:0] scr_pxl;
wire [6:0] star_pxl;

`ifndef NOCHAR

wire [9:0] char_scan;

jtgng_char #(
    .HOFFSET ( 7),
    .ROM_AW  (14),
    .PALW    ( 4)
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
    .scan       ( char_scan     ),
    .msg_low    ( 8'd0          ),
    .msg_high   ( 8'd0          ),
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
assign char_pxl  = ~7'd0;
assign char_mrdy = 1'b1;
`endif

`ifndef NOSCR
jt1943_scroll #(
    .HOFFSET    (SCR_OFFSET+1 ),
    .AS8MASK    ( 1'b0      ),
    .ROM_AW     ( 15        ),
    .PALETTE    ( 0         ),
    .LAYOUT     ( LAYOUT+1  )
) u_scroll2 (
    .rst          ( rst           ),
    .clk          ( clk           ),
    .cen6         ( cen6          ),
    .V128         ( {1'b0, V[7:0]} ),
    .H            ( H             ),
    .hpos         ( scr2_hpos     ),
    .SCxON        ( 1'b1          ),
    .vpos         ( 8'd0          ),
    .flip         ( flip          ),
    // Palette PROMs - unused in Side Arms
    .prog_addr    ( 8'd0          ),
    .prom_hi_we   ( 1'b0          ),
    .prom_lo_we   ( 1'b0          ),
    .prom_din     ( 4'd0          ),

    // ROM
    .map_addr     ( map_addr      ),
    .map_data     ( map_data      ),
    .scr_addr     ( scr_addr      ),
    .scrom_data   ( scr_data      ),
    .scr_pxl      ( scr_pxl       )
);
`else
assign scr_pxl    = 8'h7f;
assign scr_addr   = 17'd0;
assign scr_dout   = 8'd0;
assign map_addr   = 'd0;
`endif


`ifndef NOOBJ
jtgng_obj #(
    .ROM_AW       ( OBJW        ),
    .PALW         (  4          ),
    .PXL_DLY      (  1          ),
    .LAYOUT       ( LAYOUT      )
//    .OBJMAX_LINE  ( 31          ),
) u_obj (
    .rst        ( rst         ),
    .clk        ( clk         ),
    .draw_cen   ( cen12       ),
    .dma_cen    ( cen6        ),
    .pxl_cen    ( cen6        ),
    .AB         ( {obj_AB[11:5], obj_AB[1:0]} ),
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
    // unused
    .prog_addr  (             ),
    .prog_din   (             ),
    .prom_hi_we ( 1'b0        ),
    .prom_lo_we ( 1'b0        ),
    .OBJON      ( 1'b1        )
);
assign obj_AB[ 12] = 1'b1;
assign obj_AB[4:2] = 3'b0;
`else
assign blcnten = 1'b0;
assign bus_req = 1'b0;
assign obj_pxl = ~6'd0;
`endif

`ifndef NOCOLMIX
jtsarms_colmix #(
    .CHARW  (   PXL_CHRW    )
)
u_colmix (
    .rst          ( rst           ),
    .clk          ( clk           ),
    .cen12        ( cen12         ),
    .pxl_cen      ( cen8          ),
    .cpu_cen      ( cpu_cen       ),

    .char_pxl     ( char_pxl      ),
    .scr_pxl      ( scr_pxl       ),
    .star_pxl     ( star_pxl      ),
    .obj_pxl      ( obj_pxl       ),
    .LVBL         ( LVBL          ),
    .LHBL         ( LHBL          ),
    .LHBL_dly     ( LHBL_dly      ),
    .LVBL_dly     ( LVBL_dly      ),

    // Enable bits
    .CHON         ( CHON          ),
    .SCRON        ( SCRON         ),
    .OBJON        ( OBJON         ),

    // Priority PROM
    // .prog_addr    ( prog_addr     ),
    // .prom_prio_we ( prom_prio_we  ),
    // .prom_din     ( prom_din      ),

    // DEBUG
    .gfx_en       ( gfx_en        ),

    // CPU interface
    .AB           ( cpu_AB[9:0]   ),
    .blue_cs      ( blue_cs       ),
    .redgreen_cs  ( redgreen_cs   ),
    .DB           ( cpu_dout      ),
    .cpu_wrn      ( RnW           ),

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