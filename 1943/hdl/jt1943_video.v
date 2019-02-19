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
    Date: 19-2-2019 */

module jt1943_video(
    input               rst,    
    input               clk,
    input               cen6,
    input               cen3,
    input       [10:0]  cpu_AB,
    input       [ 7:0]  V,
    input       [ 8:0]  H,
    input               rd_n,
    input               wr_n,
    input               flip,
    input       [ 7:0]  cpu_dout,
    input               pause,
    // CHAR
    input               char_cs,
    output      [ 7:0]  chram_dout,
    output      [13:0]  char_addr,
    input       [15:0]  char_data,
    output              char_wait_n,
    // SCROLL - ROM
    input               scr_cs,
    input       [ 1:0]  scrpos_cs,    
    output              scr_wait_n,
    output      [ 7:0]  scram_dout,    
    output      [14:0]  scr_addr,
    input       [23:0]  scrom_data,
    input       [ 2:0]  scr_br,
    // OBJ
    input               obj_cs,
    input               HINIT,    
    output      [14:0]  obj_addr,
    input       [15:0]  objrom_data,    
    // Color Mix
    input               LVBL,
    input               LHBL,       
    input               LHBL_obj,       
    output      [3:0]   red,
    output      [3:0]   green,
    output      [3:0]   blue,
    // PROM access
    input       [7:0]   prog_addr,
    input       [3:0]   prog_din,    
    input               prom_12a_we,
    input               prom_13a_we,
    input               prom_14a_we,
    input               prom_12c_we,
);

wire [3:0] char_pxl;
wire [5:0] scr1_pxl, scr2_pxl, obj_pxl;

localparam scrchr_off = 8'd4;

`ifndef NOCHAR
jt1943_char #(.HOFFSET(scrchr_off)) u_char (
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .AB         ( cpu_AB[10:0]  ),
    .V128       ( V[7:0]        ),
    .H128       ( H[7:0]        ),
    .char_cs    ( char_cs       ),
    .flip       ( flip          ),
    .din        ( cpu_dout      ),
    .dout       ( chram_dout    ),
    .rd_n       ( rd_n          ),
    .wait_n     ( char_wait_n   ),
    .char_pxl   ( char_pxl      ),
    .pause      ( pause         ),
    // Palette PROM F1
    .prog_addr  ( prog_addr     ),
    .prom_din   ( prog_din      ),
    .prom_f1_we ( prom_f1_we    ),
    // ROM
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     )
);
`else 
assign char_wait_n = 1'b1;
assign char_pxl = 4'hf;
`endif

`ifndef NOSCR
jt1943_scroll #(.HOFFSET(scrchr_off)) u_scroll (
    .clk          ( clk           ),
    .cen6         ( cen6          ),
    .cen3         ( cen3          ),
    .AB           ( cpu_AB[9:0]   ),
    .V128         ( V[7:0]        ),
    .H            ( H             ),
    .scr_cs       ( scr_cs        ),
    .scrpos_cs    ( scrpos_cs     ),
    .wait_n       ( scr_wait_n    ),
    .flip         ( flip          ),
    .din          ( cpu_dout      ),
    .dout         ( scram_dout    ),
    .rd_n         ( rd_n          ),
    .wr_n         ( wr_n          ),
    // Palette PROMs D1, D2
    .scr_br       ( scr_br        ),
    .prog_addr    ( prog_addr     ),
    .prom_d1_we   ( prom_d1_we    ),
    .prom_d2_we   ( prom_d2_we    ),
    .prom_d6_we   ( prom_d6_we    ),
    .prom_din     ( prog_din      ),    

    // ROM
    .scr_addr     ( scr_addr[13:0]),
    .scrom_data   ( scrom_data    ),
    .scr_pxl      ( scr_pxl       )
);
assign scr_addr[14]=1'b0; // this game only uses bits 13:0, but I
    // leave bit 14 to maintain the same ROM interface as with GnG
`else 
assign scr_wait_n = 1'b1;
assign scr_pxl = ~6'h0;
`endif

`ifndef NOCOLMIX
jt1943_colmix u_colmix (
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .LVBL       ( LVBL          ),
    .LHBL       ( LHBL          ),
    // pixel input from generator modules
    .char_pxl   ( char_pxl      ),        // character color code
    .scr_pxl    ( scr_pxl       ),
    .obj_pxl    ( obj_pxl       ),
    // Palette and priority PROMs
    .prog_addr  ( prog_addr     ),
    .prom_12a_we( prom_12a_we   ),
    .prom_13a_we( prom_13a_we   ),
    .prom_14a_we( prom_14a_we   ),
    .prom_12c_we( prom_12c_we   ),    
    .prom_din   ( prog_din      ),    
    // output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);
`else
assign  red = 4'd0;
assign blue = 4'd0;
assign green= 4'd0;
`endif

jt1943_obj u_obj(   
    .rst            ( rst       ),
    .clk            ( clk       ),
    .cen6           ( cen6      ),
    .cen3           ( cen3      ),
    // screen
    .HINIT          ( HINIT     ),
    .LHBL           ( LHBL_obj  ),
    .LVBL           ( LVBL      ),
    .V              ( V         ),
    .H              ( H         ),
    .flip           ( flip      ),
    // CPU bus
    .AB             ( cpu_AB[6:0] ),
    .DB             ( cpu_dout    ),
    .obj_cs         ( obj_cs      ),
    .wr_n           ( wr_n        ),
    // SDRAM interface
    .obj_addr       ( obj_addr    ),
    .objrom_data    ( objrom_data ),
    // PROMs
    .prog_addr      ( prog_addr   ),
    .prom_m11_we    ( prom_m11_we ),
    .prom_k3_we     ( prom_k3_we  ),
    .prog_din       ( prog_din    ),
    // pixel output
    .obj_pxl        ( obj_pxl   )
);

endmodule // jtgng_video