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
    Date: 12-10-2019 */

// Map ROM: 32 kBytes = 2^14 16-word locations
// 32x32 tiles = 5 + 5 bits
// HPOS/VPOS = 16 bits, 5 for in-tile offset, remaining 11 bits, effective: 7 bits only (4 MSBs unused)

module jttora_video(
    input               rst,
    input               clk,
    input               cen12,
    input               cen8,
    input               cen6,
    input               cpu_cen,
    input       [13:1]  cpu_AB,
    input       [ 8:0]  V,
    input       [ 8:0]  H,
    input               RnW,
    input               UDSWn,
    input               LDSWn,
    input               flip,
    input       [15:0]  cpu_dout,
    input               pause,
    // CHAR
    input               char_cs,
    output      [15:0]  char_dout,
    input               char_ok,
    output              char_busy,
    output      [13:0]  char_addr,
    input       [15:0]  char_data,
    // SCROLL
    output      [17:0]  scr_addr,
    input       [15:0]  scr_data,
    input               scr_ok,
    input       [15:0]  scrposh,
    input       [15:0]  scrposv,
    // MAP
    output      [13:0]  map_addr,
    input       [15:0]  map_data,
    input               map_ok,
    output              map_cs,
    // OBJ
    input               HINIT,
    output      [13:1]  obj_AB,
    input       [11:0]  oram_dout,   // only 12 bits are read
    input               OKOUT,
    output              bus_req, // Request bus
    input               bus_ack, // bus acknowledge
    output              blcnten,    // bus line counter enable
    output      [17:0]  obj_addr,
    input       [15:0]  obj_data,
    input               obj_ok,
    // Color Mix
    input               LVBL,
    input               LVBL_obj,
    input               LHBL,
    input               LHBL_obj,
    output              LHBL_dly,
    output              LVBL_dly,
    input               col_uw,
    input               col_lw,
    input       [3:0]   gfx_en,
    // Priority PROM
    input       [7:0]   prog_addr,
    input               prom_prio_we,
    input       [3:0]   prom_din,
    // Pixel output
    output      [3:0]   red,
    output      [3:0]   green,
    output      [3:0]   blue
);

// parameters from jtgng_obj:
localparam AVATAR_MAX    = 8;
localparam LAYOUT        = 3;

wire [5:0] char_pxl;
wire [7:0] obj_pxl;
wire [8:0] scr_pxl;
wire [3:0] avatar_idx;

`ifndef NOCHAR

wire [7:0] char_msg_low;
wire [7:0] char_msg_high;
wire [9:0] char_scan;

jtgng_char #(
    .HOFFSET(      0 ),
    .DW     (     16 ),
    .ROM_AW (     14 ),
    .VFLIP  (      4 ),
    .HFLIP  (      4 ),
    .LAYOUT ( LAYOUT )
) u_char (
    .clk        ( clk           ),
    .pxl_cen    ( cen6          ),
    .cpu_cen    ( cpu_cen       ),
    .AB         ( cpu_AB[11:1]  ),
    .V          ( V[7:0]        ),
    .H          ( H[7:0]        ),
    .flip       ( flip          ),
    .din        ( cpu_dout      ),
    .dout       ( char_dout     ),
    // Bus arbitrion
    .char_cs    ( char_cs       ),
    .wr_n       ( RnW           ),
    .dseln      ( {UDSWn, LDSWn}),
    .busy       ( char_busy     ),
    // Pause screen
    .pause      ( pause         ),
    .scan       ( char_scan     ),
    .msg_low    ( char_msg_low  ),
    .msg_high   ( char_msg_high ),
    // ROM
    .char_addr  ( char_addr     ),
    .rom_data   ( char_data     ),
    .rom_ok     ( char_ok       ),
    // Pixel output
    .char_on    ( 1'b1          ),
    .char_pxl   ( char_pxl      ),
    // unused
    .prog_addr  (               ),
    .prog_din   (               ),
    .prom_we    (               )
);

wire [7:0] char_aux;
jtgng_charmsg #(.VERTICAL(0)) u_msg(
    .clk         ( clk           ),
    .cen6        ( cen6          ),
    .avatar_idx  ( avatar_idx    ),
    .scan        ( char_scan     ),
    .msg_low     ( char_aux      ),
    .msg_high    (               )
);

assign char_msg_high = char_aux[7:6]==2'b11 ? { 3'b111, 5'd2 } : 8'd2;
assign char_msg_low  = char_aux[7:6]==2'b11 ? {2'b01, char_aux[5:0]} : char_aux;

`else
assign char_mrdy = 1'b1;
assign char_pxl  = 6'h3f;
`endif

`ifndef NOSCR
jt1943_scroll #(
    .PALETTE    ( 0        ),
    .LAYOUT     ( LAYOUT   ),
    .ROM_AW     ( 18       ),
    .HOFFSET    ( 3        ))
u_scroll (
    .rst          ( rst            ),
    .clk          ( clk            ),
    .cen6         ( cen6           ),
    .V128         ( V              ),
    .H            ( H              ),
    .SCxON        ( 1'b1           ),
    .hpos         ( scrposh        ),
    .vpos         ( scrposv        ),
    .flip         ( flip           ),
    // No palette PROMs
    .prog_addr    (                ),
    .prom_hi_we   (                ),
    .prom_lo_we   (                ),
    .prom_din     (                ),

    // ROM
    .map_addr     ( map_addr       ),
    .map_data     ( map_data       ),
    .map_ok       ( map_ok         ),
    .map_cs       ( map_cs         ),
    .scr_addr     ( scr_addr       ),
    .scrom_data   ( scr_data       ),
    .scr_pxl      ( scr_pxl        )
);

`else
assign scr_pxl    = 9'h0;
assign scr_addr   = 15'd0;
assign map_addr   = 14'd0;
`endif

// Object DMA transfer takes ~164us as per bootleg PCB measurement
// pin A1 toggles as 250ns low, 250ns high
// So address bus is toggling with a 4MHz clock
// and at 250ns per address, it can sweep 640 locations in 160us.

jtgng_obj #(
    .VERTICAL   ( 0          ),
    .AVATAR_MAX ( AVATAR_MAX ),
    .LAYOUT     ( LAYOUT     ),
    .INVY       ( 1          ),
    .OBJMAX     ( 10'h280    ), // 160 objects max, buffer size = 640 bytes (280h)
    .OBJMAX_LINE( 6'd32      ),
    .PALW       ( 4          ),
    .ROM_AW     ( 18         ),
    .DMA_AW     ( 10         ),
    .DMA_DW     ( 12         ))
u_obj (
    .rst        ( rst         ),
    .clk        ( clk         ),
    .draw_cen   ( cen12       ),
    .dma_cen    ( cen8        ),
    .pxl_cen    ( cen6        ),
    // screen
    .HINIT      ( HINIT       ),
    .LHBL       ( LHBL_obj    ),
    .LVBL       ( LVBL        ),
    .LVBL_obj   ( LVBL_obj    ),
    .V          ( V[7:0]      ),
    .H          ( H           ),
    .flip       ( flip        ),
    // Pause screen
    .pause      ( pause       ),
    .avatar_idx ( avatar_idx  ),
    // CPU bus
    .AB         ( obj_AB[10:1]),
    .DB         ( oram_dout   ),
    // shared bus
    .OKOUT      ( OKOUT       ),
    .bus_req    ( bus_req     ),
    .bus_ack    ( bus_ack     ),
    .blen       ( blcnten     ),
    // SDRAM interface
    .obj_addr   ( obj_addr    ),
    .obj_data   ( obj_data    ),
    .rom_ok     ( obj_ok      ),
    // pixel data
    .obj_pxl    ( obj_pxl     ),
    // unused
    .OBJON      ( 1'b1        ), // not used for non palette PROM games
    .prog_addr  ( 8'd0        ),
    .prom_hi_we ( 1'b0        ),
    .prom_lo_we ( 1'b0        ),
    .prog_din   ( 4'd0        )
);

assign obj_AB[13:11] = 3'b111;

`ifndef NOCOLMIX
jttora_colmix u_colmix (
    .rst          ( rst           ),
    .clk          ( clk           ),
    .cen6         ( cen6          ),
    .cpu_cen      ( cpu_cen       ),

    .char_pxl     ( char_pxl      ),
    .scr_pxl      ( scr_pxl       ),
    .obj_pxl      ( obj_pxl       ),
    .LVBL         ( LVBL          ),
    .LHBL         ( LHBL          ),
    .LHBL_dly     ( LHBL_dly      ),
    .LVBL_dly     ( LVBL_dly      ),

    // PROMs
    .prog_addr    ( prog_addr     ),
    .prom_prio_we ( prom_prio_we  ),
    .prom_din     ( prom_din      ),

    // Avatars
    .pause        ( pause         ),
    .avatar_idx   ( avatar_idx    ),

    // DEBUG
    .gfx_en       ( gfx_en        ),

    // CPU interface
    .AB           ( cpu_AB[10:1]  ),
    .col_uw       ( col_uw        ),
    .col_lw       ( col_lw        ),
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

endmodule // jttora_video