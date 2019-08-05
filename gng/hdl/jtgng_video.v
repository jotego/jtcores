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
    Date: 30-12-2018 */

module jtgng_video(
    input               rst,
    input               clk,
    input               cen6,
    input               cen3,
    input       [10:0]  cpu_AB,
    input       [ 7:0]  V,
    input       [ 8:0]  H,
    input               RnW,
    input               flip,
    input       [ 7:0]  cpu_dout,
    input               pause,
    // CHAR
    input               char_cs,
    output      [ 7:0]  chram_dout,
    input               char_ok,
    output              char_mrdy,
    output      [12:0]  char_addr,
    input       [15:0]  char_data,
    // SCROLL - ROM
    input               scr_cs,
    input               scrpos_cs,
    output      [ 7:0]  scram_dout,
    output      [14:0]  scr_addr,
    input       [23:0]  scrom_data,
    output              scr_mrdy,
    // OBJ
    input               HINIT,
    output      [ 8:0]  obj_AB,
    input       [ 7:0]  main_ram,
    input               OKOUT,
    output              bus_req, // Request bus
    input               bus_ack, // bus acknowledge
    output              blcnten,    // bus line counter enable
    output      [15:0]  obj_addr,
    input       [15:0]  objrom_data,
    // Color Mix
    input               LVBL,
    input               LVBL_obj,
    input               LHBL,
    input               LHBL_obj,
    input               blue_cs,
    input               redgreen_cs,
    input               enable_char,
    input               enable_obj,
    input               enable_scr,
    output      [3:0]   red,
    output      [3:0]   green,
    output      [3:0]   blue
);

wire [3:0] char_pal;
wire [1:0] char_col;
wire [5:0] obj_pxl;
wire scrwin;
wire [2:0] scr_col;
wire [2:0] scr_pal;
wire [3:0] cc;

localparam scrchr_off = 8'd5;

`ifndef NOCHAR

wire [7:0] char_msg_low;
wire [7:0] char_msg_high = 8'h2;
wire [9:0] char_scan;

jtgng_char #(.Hoffset(scrchr_off)) u_char (
    .clk        ( clk           ),
    .pxl_cen    ( cen6          ),
    .cpu_cen    ( cen6          ),
    .AB         ( cpu_AB[10:0]  ),
    .V          ( V             ),
    .H          ( H[7:0]        ),
    .flip       ( flip          ),
    .din        ( cpu_dout      ),
    .dout       ( chram_dout    ),
    // Bus arbitrion
    .char_cs    ( char_cs       ),
    .wr_n       ( RnW           ),
    .MRDY_b     ( char_mrdy     ),
    .busy       (               ),
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
    .char_col   ( chr_col       ),
    .char_pal   ( chr_pal       )
);

jtgng_ram #(.aw(10),.synfile("msg.hex"),.simfile("msg.bin")) u_char_msg(
    .clk    ( clk          ),
    .cen    ( cen6         ),
    .data   ( 8'd0         ),
    .addr   ( char_scan    ),
    .we     ( 1'b0         ),
    .q      ( char_msg_low )
);

`else
assign char_mrdy = 1'b1;
`endif

`ifndef NOSCR
jtgng_scroll #(.Hoffset(scrchr_off)) u_scroll (
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .AB         ( cpu_AB[10:0]  ),
    .V128       ( V[7:0]        ),
    .H          ( H             ),
    .scr_cs     ( scr_cs        ),
    .scrpos_cs  ( scrpos_cs     ),
    .flip       ( flip          ),
    .din        ( cpu_dout      ),
    .dout       ( scram_dout    ),
    .rd         ( RnW           ),
    .MRDY_b     ( scr_mrdy      ),
    .scr_addr   ( scr_addr      ),
    .scr_col    ( scr_col       ),
    .scr_pal    ( scr_pal       ),
    .scrom_data ( scrom_data    ),
    .scrwin     ( scrwin        )
);
`else
assign scr_mrdy   = 1'b1;
assign scr_col    = 3'd0;
assign scr_pal    = 3'd0;
assign scrwin     = 1'd0;
assign scr_addr   = 15'd0;
assign scram_dout = 8'd0;
`endif

`ifndef NOCOLMIX
jtgng_colmix u_colmix (
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    // characters
    .chr_col    ( char_col      ),
    .chr_pal    ( char_pal      ),
    // scroll
    .scr_col    ( scr_col       ),
    .scr_pal    ( scr_pal       ),
    .scrwin     ( scrwin        ),
    // objects
    .obj_pxl    ( obj_pxl       ),
    // DEBUG
    .enable_char( enable_char   ),
    .enable_obj ( enable_obj    ),
    .enable_scr ( enable_scr    ),
    // CPU interface
    .AB         ( cpu_AB[7:0]   ),
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),
    .DB         ( cpu_dout      ),
    .LVBL       ( LVBL          ),
    .LHBL       ( LHBL          ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);
`else
assign  red = 4'd0;
assign blue = 4'd0;
assign green= 4'd0;
`endif


jtgng_obj u_obj (
    .rst        ( rst         ),
    .clk        ( clk         ),
    .cen6       ( cen6        ),
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
    .objrom_data( objrom_data ),
    // pixel data
    .obj_pxl    ( obj_pxl     )
);

endmodule // jtgng_video