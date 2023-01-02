/*  This file is part of JTGNG.
    JTGNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTGNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTGNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-1-2019 */

module jthige_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [ 8:0] V, H;
wire [12:0] cpu_AB;
wire [ 7:0] char_dout;
wire [ 7:0] chram_dout;
wire [ 7:0] dipsw_a, dipsw_b;
wire        char_cs, flip, cpu_cen;
wire        cen12, cen6, cen3, cen1p5;
wire        preLHBL, preLVBL;
wire [ 2:0] pre_r, pre_g, pre_b;

assign pxl2_cen = cen12;
assign pxl_cen  = cen6;
assign game_led = 0;
assign {dipsw_b, dipsw_a} = dipsw[15:0];
assign dip_flip = ~flip;

assign red    = { pre_r, pre_r[2] };
assign green  = { pre_g, pre_g[2] };
assign blue   = { pre_b, pre_b[2] };

wire         wr_n, rd_n;
wire         char_cs, obj_cs, char_busy;

jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen12  ( cen12     ),
    .cen6   ( cen6      ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    ),
    // unused
    .cen16  (           ),
    .cen16b (           ),
    .cen8   (           ),
    .cen4   (           ),
    .cen4_12(           ),
    .cen3q  (           ),
    .cen12b (           ),
    .cen6b  (           ),
    .cen3b  (           ),
    .cen3qb (           ),
    .cen1p5b(           )
);

wire prom_pal_we   = prom_we && prog_addr <  22'he020;
wire prom_char_we  = prom_we && prog_addr >= 22'he020 && prog_addr < 22'he120;
wire prom_obj_we   = prom_we && prog_addr >= 22'he120 && prog_addr < 22'he220;
wire prom_irq_we   = prom_we && prog_addr >= 22'he220 && prog_addr < 22'he320;

wire [8:0] prom_addr = prog_addr[8:0] - 9'h20;

`ifndef NOMAIN
jthige_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cen1p5     ( cen1p5        ),
    .cpu_cen    ( cpu_cen       ),
    .LHBL       ( LHBL          ),
    .cpu_dout   ( cpu_dout      ),
    .dip_pause  ( dip_pause     ),
    // Char
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    .char_dout  ( chram_dout    ),
    // video (other)
    .obj_cs     ( obj_cs        ),
    .flip       ( flip          ),
    .V          ( V[7:0]        ),
    .cpu_AB     ( cpu_AB        ),
    .rd_n       ( rd_n          ),
    .wr_n       ( wr_n          ),
    // RAM
    .ram_we     ( ram_we        ),
    .ram_dout   ( ram_dout      ),
    // SDRAM / ROM access
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .start_button( start_button ),
    .coin_input  ( coin_input   ),
    .joystick1   ( joystick1[4:0] ),
    .joystick2   ( joystick2[4:0] ),
    // PROM K6
    .prog_addr  ( prom_addr[7:0]),
    .prom_irq_we( prom_irq_we   ),
    .prog_din   ( prog_data[3:0]),
    // DIP switches
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       ),
    // Sound output
    .sample     ( sample        ),
    .snd        ( snd           )
);
`else
assign main_cs   = 1'b0;
assign cpu_cen   = cen3;
assign char_cs   = 1'b0;
assign obj_cs    = 1'b0;
assign flip      = 1'b0;
`endif

jthige_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB[10:0]  ),
    .V          ( V             ),
    .H          ( H             ),
    .rd_n       ( rd_n          ),
    .wr_n       ( wr_n          ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    // CHAR
    .char_cs    ( char_cs       ),
    .chram_dout ( chram_dout    ),
    .char_addr  ( char_addr     ), // CHAR ROM
    .char_data  ( char_data     ),
    .char_ok    ( char_ok       ),
    .char_busy  ( char_busy     ),
    // OBJ
    .obj_cs     ( obj_cs        ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_ok     ( obj_ok        ),
    // Color Mix
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .red        ( pre_r         ),
    .green      ( pre_g         ),
    .blue       ( pre_b         ),
    .gfx_en     ( gfx_en        ),
    // PROM access
    .prog_addr  ( prog_addr[7:0]),
    .prom_addr  ( prom_addr[7:0]),
    .prog_din   ( prog_data     ),
    .prom_char_we( prom_char_we ),
    .prom_obj_we( prom_obj_we   ),
    .prom_pal_we( prom_pal_we   )
);

endmodule
