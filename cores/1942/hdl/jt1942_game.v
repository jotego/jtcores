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
    Date: 20-1-2019 */


module jt1942_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

localparam VULGUS    = `ifdef VULGUS 1'b1; `else 1'b0; `endif
localparam OBJ_START = `JTFRAME_BA2_START + (`OBJ_OFFSET<<1);

wire [ 8:0] V, H;
wire [12:0] cpu_AB;
wire char_cs;
wire flip;
wire [ 7:0] cpu_dout, char_dout;
wire [ 7:0] chram_dout,scram_dout;
wire        cpu_cen, wr_n, rd_n;
wire        cen12, cen6, cen3, cen1p5;
// sound
wire        sres_b, snd_latch0_cs, snd_latch1_cs, snd_int;
wire [ 7:0] snd_latch;

wire        scr_cs, obj_cs;
wire [ 2:0] scr_br;
wire [ 8:0] scr_hpos, scr_vpos;
wire        char_busy, scr_busy, eff_flip;

wire        prom_red_we, prom_green_we, prom_blue_we,
            prom_char_we, prom_scr_we, prom_obj_we,
            prom_d1_we, prom_d2_we, prom_irq_we;

assign prom_red_we   = prog_addr[11:8]==0; // sb-5.e8
assign prom_green_we = prog_addr[11:8]==1; // sb-6.e9
assign prom_blue_we  = prog_addr[11:8]==2; // sb-7.e10
assign prom_char_we  = prog_addr[11:8]==3; // sb-0.f1
assign prom_scr_we   = prog_addr[11:8]==4; // sb-4.d6
assign prom_obj_we   = prog_addr[11:8]==5; // sb-8.k3
assign prom_d1_we    = prog_addr[11:8]==6; // sb-2.d1 -- unused by Vulgus
assign prom_d2_we    = prog_addr[11:8]==7; // sb-3.d2 -- unused by Vulgus
assign prom_irq_we   = prog_addr[11:8]==8; // sb-1.k6

assign pxl2_cen = cen12;
assign pxl_cen  = cen6;
assign debug_view = 0;

`ifndef VULGUS
assign dip_flip = flip;
assign eff_flip = flip;
`else
assign eff_flip = dip_flip;
`endif

always @* begin
    post_addr = prog_addr;
    if( ioctl_addr>=OBJ_START[24:0] && ioctl_addr<`JTFRAME_BA3_START ) begin
        post_addr[5:1] = { post_addr[4:1], post_addr[5] };
    end
end

jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen12  ( cen12     ),
    .cen6   ( cen6      ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    ),
    // Unused
    .cen16  (           ),
    .cen8   (           ),
    .cen4   (           ),
    .cen4_12(           ),
    .cen3q  (           ),
    .cen3qb (           ),
    .cen16b (           ),
    .cen12b (           ),
    .cen6b  (           ),
    .cen3b  (           ),
    .cen1p5b(           )
);

jt1942_main #(.VULGUS(VULGUS)) u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    // sound
    .sres_b        ( sres_b        ),
    .snd_latch0_cs ( snd_latch0_cs ),
    .snd_latch1_cs ( snd_latch1_cs ),
    .snd_int       ( snd_int       ),

    .LHBL       ( LHBL          ),
    .cpu_dout   ( cpu_dout      ),
    .dip_pause  ( dip_pause     ),
    // Char
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    .char_dout  ( chram_dout    ),
    // Scroll
    .scr_cs     ( scr_cs        ),
    .scr_busy   ( scr_busy      ),
    .scr_dout   ( scram_dout    ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    // video (other)
    .scr_br     ( scr_br        ),
    .obj_cs     ( obj_cs        ),
    .flip       ( flip          ),
    .V          ( V[7:0]        ),
    .cpu_AB     ( cpu_AB        ),
    .rd_n       ( rd_n          ),
    .wr_n       ( wr_n          ),
    // SDRAM / ROM access
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .start_button( start_button ),
    .coin_input  ( coin_input   ),
    .service     ( service      ),
    .joystick1   ( joystick1[5:0] ),
    .joystick2   ( joystick2[5:0] ),
    // PROM K6
    .prog_addr  ( prog_addr[7:0]),
    .prom_irq_we( prom_irq_we   ),
    .prog_din   ( prog_data[3:0]),
    // Cheat
    .cheat_invincible( 1'b0 ),
    // DIP switches
    .dipsw_a    ( dipsw[ 7:0]   ),
    .dipsw_b    ( dipsw[15:8]   ),
    .coin_cnt   (               )
);

jt1942_sound u_sound (
    .rst            ( rst            ),
    .clk            ( clk            ),
    .cen3           ( cen3           ),
    .cen1p5         ( cen1p5         ),
    .sres_b         ( sres_b         ),
    .main_dout      ( cpu_dout       ),
    .main_latch0_cs ( snd_latch0_cs  ),
    .main_latch1_cs ( snd_latch1_cs  ),
    .snd_int        ( snd_int        ),
    .rom_cs         ( snd_cs         ),
    .rom_addr       ( snd_addr       ),
    .rom_data       ( snd_data       ),
    .rom_ok         ( snd_ok         ),
    .snd            ( snd            ),
    .sample         ( sample         ),
    .peak           ( game_led       ),
    // Unused
    .snd_latch      (                )
);

jt1942_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB[10:0]  ),
    .V          ( V             ),
    .H          ( H             ),
    .rd_n       ( rd_n          ),
    .wr_n       ( wr_n          ),
    .flip       ( eff_flip      ),
    .cpu_dout   ( cpu_dout      ),
    .pause      ( ~dip_pause    ), //dipsw_a[7]    ),
    // CHAR
    .char_cs    ( char_cs       ),
    .chram_dout ( chram_dout    ),
    .char_addr  ( char_addr     ), // CHAR ROM
    .char_data  ( char_data     ),
    .char_ok    ( char_ok       ),
    .char_busy  ( char_busy     ),
    // SCROLL - ROM
    .scr_cs     ( scr_cs        ),
    .scram_dout ( scram_dout    ),
    .scr_addr   ( scr_addr      ),
    .scrom_data ( scr_data[23:0]),
    .scr_busy   ( scr_busy      ),
    .scr_br     ( scr_br        ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    .scr_ok     ( scr_ok        ),
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
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    .gfx_en     ( gfx_en        ),
    // PROM access
    .prog_addr  ( prog_addr[7:0]),
    .prog_din   ( prog_data[3:0]),
    .prom_char_we( prom_char_we ),
    .prom_d1_we ( prom_d1_we    ),
    .prom_d2_we ( prom_d2_we    ),
    .prom_d6_we ( prom_scr_we   ),
    .prom_obj_we( prom_obj_we   ),
    .prom_e8_we ( prom_red_we   ),
    .prom_e9_we ( prom_green_we ),
    .prom_e10_we( prom_blue_we  )
);

endmodule
