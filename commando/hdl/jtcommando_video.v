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
    Date: 29-6-2019 */

module jtcommando_video(
    input               rst,
    input               clk,
    input               cen12,
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
    output      [12:0]  char_addr,
    input       [15:0]  chrom_data,
    output              char_busy,
    // SCROLL - ROM
    input               scr_cs,
    input               scrpos_cs,
    output      [ 7:0]  scram_dout,
    output      [14:0]  scr_addr,
    input       [23:0]  scrom_data,
    output              scr_busy,
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
    // PROMs
    input       [7:0]   prog_addr,
    input               prom_1d_we,
    input               prom_2d_we,
    input               prom_3d_we,
    input       [3:0]   prom_din,    
    // Color Mix
    input               LVBL,
    input               LVBL_obj,
    input               LHBL,
    input               LHBL_obj,
    input       [3:0]   gfx_en,
    output      [3:0]   red,
    output      [3:0]   green,
    output      [3:0]   blue
);

wire [5:0] char_pxl;
wire [5:0] obj_pxl;
wire [6:0] scr_pxl;

localparam scrchr_off = 8'd5;

`ifndef NOCHAR
jtgng_char #(.Hoffset(scrchr_off)) u_char (
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .AB         ( cpu_AB[10:0]  ),
    .V128       ( V[7:0]        ),
    .H128       ( H[7:0]        ),
    .char_cs    ( char_cs       ),
    .flip       ( flip          ),
    .pause      ( pause         ),
    .din        ( cpu_dout      ),
    .dout       ( chram_dout    ),
    .rd         ( RnW           ),
    .MRDY_b     (               ),
    .busy       ( char_busy     ),
    .char_addr  ( char_addr     ),
    .chrom_data ( chrom_data    ),
    .char_col   ( char_pxl[1:0] ),
    .char_pal   ( char_pxl[5:2] )
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
    .MRDY_b     (               ),
    .busy       ( scr_busy      ),
    .scr_addr   ( scr_addr      ),
    .scr_col    ( scr_pxl[2:0]  ),
    .scr_pal    ( scr_pxl[5:3]  ),
    .scrom_data ( scrom_data    ),
    .scrwin     ( scr_pxl[6]    )
);
`else
assign scr_mrdy   = 1'b1;
assign scr_pxl    = 7'd0;
assign scr_addr   = 15'd0;
assign scram_dout = 8'd0;
`endif

`ifndef NOCOLMIX
jtcommando_colmix u_colmix (
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen12      ( cen12         ),
    .cen6       ( cen6          ),

    .char_pxl   ( char_pxl      ),  // PAL is top 4 bits
    .scr_pxl    ( scr_pxl       ),  // SCRWIN is the MSB
    .obj_pxl    ( obj_pxl       ),
    .LVBL       ( LVBL          ),
    .LHBL       ( LHBL          ),
    // PROMs
    .prog_addr  ( prog_addr     ),
    .prom_1d_we ( prom_1d_we    ),
    .prom_2d_we ( prom_2d_we    ),
    .prom_3d_we ( prom_3d_we    ),
    .prom_din   ( prom_din      ),

    // DEBUG
    .gfx_en     ( gfx_en        ),
    .pause      ( pause         ),
    // colour output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);
`else
assign  red = 4'd0;
assign blue = 4'd0;
assign green= 4'd0;
`endif

`ifndef NOOBJ
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
`else
assign obj_pxl  = ~6'd0;
assign obj_addr = 16'd0;
assign bus_req  = 1'b0;
assign blcnten  = 1'b0;
`endif
endmodule // jtcommando_video