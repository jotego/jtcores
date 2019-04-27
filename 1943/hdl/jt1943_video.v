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

`timescale 1ns/1ps

module jt1943_video(
    input               rst,
    input               clk,
    input               cen6,
    input               cen3,
    input               cpu_cen,
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
    input               CHON,
    output      [ 7:0]  chram_dout,
    output      [13:0]  char_addr,
    input       [15:0]  char_data,
    output              char_wait,
    // SCROLL - ROM
    input               SC1ON,
    input               SC2ON,
    input       [ 1:0]  scr1posh_cs,
    input       [ 1:0]  scr2posh_cs,
    input       [ 7:0]  scrposv,
    output      [16:0]  scr1_addr,
    output      [14:0]  scr2_addr,
    input       [15:0]  scr1_data,
    input       [15:0]  scr2_data,
    // MAP
    output      [13:0]  map1_addr,
    output      [13:0]  map2_addr,
    input       [15:0]  map1_data,
    input       [15:0]  map2_data,
    // OBJ
    input               OBJON,
    input               HINIT,
    output      [16:0]  obj_addr,
    input       [15:0]  objrom_data,
    // shared bus
    output      [12:0]  obj_AB,
    input        [7:0]  obj_DB,
    input               OKOUT,
    output              bus_req,   // Request bus
    input               bus_ack,   // bus acknowledge
    output              blcnten,   // bus line counter enable
    // Color Mix
    input               LVBL,
    input               LVBL_obj,
    input               LHBL,
    input               LHBL_obj,
    output      [3:0]   red,
    output      [3:0]   green,
    output      [3:0]   blue,
    // PROM access
    input       [7:0]   prog_addr,
    input       [3:0]   prog_din,
    // Char
    input               prom_7f_we,
        // color mixer
    input               prom_12a_we,
    input               prom_13a_we,
    input               prom_14a_we,
    input               prom_12c_we,
        // scroll
    input               prom_6l_we,
    input               prom_7l_we,
    input               prom_12l_we,
    input               prom_12m_we,
        // obj
    input               prom_7c_we,
    input               prom_8c_we,
    // Debug
    input       [3:0]   gfx_en
);

wire [3:0] char_pxl;
wire [5:0] scr1_pxl, scr2_pxl;
wire [7:0] obj_pxl;

localparam chr_off = 8'd5;
localparam scr_off = 8'd12;

wire [2:0] avatar_idx;

`ifdef AVATARS
wire obj_pause=pause;
`else 
wire obj_pause=1'b0;
`endif

`ifndef NOCHAR
jt1943_char #(.HOFFSET(chr_off)) u_char (
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    .AB         ( cpu_AB[10:0]  ),
    .V128       ( V[7:0]        ),
    .H          ( H             ),
    .char_cs    ( char_cs       ),
    .CHON       ( CHON          ),
    .flip       ( flip          ),
    .din        ( cpu_dout      ),
    .dout       ( chram_dout    ),
    .rd_n       ( rd_n          ),
    .wr_n       ( wr_n          ),
    .cpu_wait   ( char_wait     ),
    .char_pxl   ( char_pxl      ),
    // Pause screen
    .pause      ( pause         ),
    .avatar_idx ( avatar_idx    ),
    // Palette PROM F1
    .prog_addr  ( prog_addr     ),
    .prom_din   ( prog_din      ),
    .prom_7f_we ( prom_7f_we    ),
    // ROM
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     )
);
`else
assign char_wait_n = 1'b1;
assign char_pxl = 4'hf;
`endif

`ifndef NOSCR
jt1943_scroll #(.HOFFSET(scr_off),
    .SIMFILE_MSB("../../../rom/1943/bm9.6l"),
    .SIMFILE_LSB("../../../rom/1943/bm10.7l")
) u_scroll1 (
    .rst          ( rst           ),
    .clk          ( clk           ),
    .cen6         ( cen6          ),
    .cen3         ( cen3          ),
    .V128         ( V[7:0]        ),
    .H            ( H             ),
    .LVBL         ( LVBL          ),
    .scrposh_cs   ( scr1posh_cs   ),
    `ifndef TESTSCR1
    .SCxON        ( SC1ON         ),
    .vpos         ( scrposv       ),
    .flip         ( flip          ),
    `else
    .SCxON        ( 1'b1          ),
    .vpos         ( 8'd0          ),
    .flip         ( 1'b0          ),
    `endif
    .din          ( cpu_dout      ),
    .wr_n         ( wr_n          ),
    .pause        ( pause         ),
    // Palette PROMs
    .prog_addr    ( prog_addr     ),
    .prom_msb_we  ( prom_6l_we    ),
    .prom_lsb_we  ( prom_7l_we    ),
    .prom_din     ( prog_din      ),

    // ROM
    .map_addr     ( map1_addr     ),
    .map_data     ( map1_data     ),
    .scr_addr     ( scr1_addr     ),
    .scrom_data   ( scr1_data     ),
    .scr_pxl      ( scr1_pxl      )
);

wire [1:0] scr2_nc; // not connected bits of the address

jt1943_scroll #(.HOFFSET(scr_off),
    .SIMFILE_MSB("../../../rom/1943/bm11.12l"),
    .SIMFILE_LSB("../../../rom/1943/bm12.12m"),
    .AS8MASK(1'b0)
) u_scroll2 (
    .rst          ( rst           ),
    .clk          ( clk           ),
    .cen6         ( cen6          ),
    .cen3         ( cen3          ),
    .V128         ( V[7:0]        ),
    .H            ( H             ),
    .LVBL         ( LVBL          ),
    .scrposh_cs   ( scr2posh_cs   ),
    `ifndef TESTSCR2
    .SCxON        ( SC2ON         ),
    .vpos         ( scrposv       ),
    .flip         ( flip          ),
    `else
    .SCxON        ( 1'b1          ),
    .vpos         ( 8'd0          ),
    .flip         ( 1'b0          ),
    `endif
    .din          ( cpu_dout      ),
    .wr_n         ( wr_n          ),

    .pause        ( pause         ),
    // Palette PROMs
    .prog_addr    ( prog_addr     ),
    .prom_msb_we  ( prom_12l_we   ),
    .prom_lsb_we  ( prom_12m_we   ),
    .prom_din     ( prog_din      ),

    // ROM
    .map_addr     ( map2_addr     ),
    .map_data     ( map2_data     ),
    .scr_addr     ( { scr2_nc, scr2_addr} ),
    .scrom_data   ( scr2_data     ),
    .scr_pxl      ( scr2_pxl      )
);
`else
assign scr1_pxl  = 6'h31;
assign scr1_addr = 17'h0;
assign map1_addr = 14'h0;

assign scr2_pxl  = ~6'h0;
assign scr2_addr = 17'h0;
assign map2_addr = 14'h0;
`endif


`ifndef NOCOLMIX
jt1943_colmix u_colmix (
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .LVBL       ( LVBL          ),
    .LHBL       ( LHBL          ),
    .pause      ( obj_pause     ),
    // pixel input from generator modules
    .char_pxl   ( char_pxl      ),        // character color code
    .scr1_pxl   ( scr1_pxl      ),
    .scr2_pxl   ( scr2_pxl      ),
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
    .blue       ( blue          ),
    // debug
    .gfx_en     ( gfx_en        )
);
`else
assign  red = 4'd0;
assign blue = 4'd0;
assign green= 4'd0;
`endif

`ifndef NOOBJ
jt1943_obj u_obj(
    .rst            ( rst        ),
    .clk            ( clk        ),
    .cen6           ( cen6       ),
    //.cen3           ( cen3      ),
    // screen
    .OBJON          ( OBJON      ),
    .HINIT          ( HINIT      ),
    .LHBL           ( LHBL_obj   ),
    .LVBL           ( LVBL       ),
    .LVBL_obj       ( LVBL_obj   ),
    .V              ( V          ),
    .H              ( H          ),
    .flip           ( flip       ),
    // Pause screen
    .pause          ( obj_pause  ),
    .avatar_idx     ( avatar_idx ),
    // CPU bus
    .AB             ( obj_AB     ),
    .DB             ( obj_DB     ),
    // shared bus
    .OKOUT          ( OKOUT      ),
    .bus_req        ( bus_req    ),        // Request bus
    .bus_ack        ( bus_ack    ),    // bus acknowledge
    .blen           ( blcnten    ),   // bus line counter enable
    // SDRAM interface
    .obj_addr       ( obj_addr    ),
    .objrom_data    ( objrom_data ),
    // PROMs
    .prog_addr      ( prog_addr   ),
    .prom_7c_we     ( prom_7c_we  ),
    .prom_8c_we     ( prom_8c_we  ),
    .prog_din       ( prog_din    ),
    // pixel output
    .obj_pxl        ( obj_pxl     )
);
`else
assign prog_addr = 'd0;
assign obj_pxl   = ~'d0;
assign bus_req   = 'b0;
assign blcnten   = 'b0;
`endif

endmodule // jtgng_video