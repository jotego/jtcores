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

`include "1942.vh"
localparam BA3_START = `JTFRAME_BA3_START;
localparam OBJ_START = `JTFRAME_BA2_START + (`OBJ_OFFSET<<1);

wire [ 8:0] V, H;
wire [12:0] cpu_AB;
wire char_cs;
wire flip;
wire [ 7:0] cpu_dout, char_dout;
wire [ 7:0] chram_dout,scram_dout;
wire        cpu_cen, wr_n, rd_n, ay0_cs, ay1_cs, main_wr_n;
// sound
wire        sres_b, snd_latch0_cs, snd_latch1_cs, snd_int;
wire [ 7:0] snd_latch;

wire        scr_cs, obj_cs;
wire [ 2:0] scr_br;
wire [ 8:0] scr_hpos, scr_vpos;
wire        char_busy, scr_busy;

wire        prom_red_we, prom_green_we, prom_blue_we,
            prom_char_we, prom_scr_we, prom_obj_we,
            prom_d1_we, prom_d2_we, prom_irq_we;

reg  [ 1:0] game_id=0;
reg         flip_xor=0, eff_flip=0, hige=0;

assign prom_red_we   = prom_we && prog_addr[11:8]==0; // sb-5.e8 - also used as Higemaru's palette
assign prom_green_we = prom_we && prog_addr[11:8]==1; // sb-6.e9
assign prom_blue_we  = prom_we && prog_addr[11:8]==2; // sb-7.e10
assign prom_char_we  = prom_we && prog_addr[11:8]==(!hige ? 4'd3 : 4'd1) && (!hige || !prog_addr[7]); // sb-0.f1
assign prom_scr_we   = prom_we && prog_addr[11:8]==4; // sb-4.d6
assign prom_obj_we   = prom_we && prog_addr[11:8]==(!hige ? 4'd5 : 4'd2); // sb-8.k3
assign prom_d1_we    = prom_we && prog_addr[11:8]==6; // sb-2.d1 -- unused by Vulgus
assign prom_d2_we    = prom_we && prog_addr[11:8]==7; // sb-3.d2 -- unused by Vulgus
assign prom_irq_we   = prom_we && prog_addr[11:8]==(!hige ? 4'd8 : 4'd3); // sb-1.k6

assign pxl2_cen = cen12;
assign pxl_cen  = cen6;
assign debug_view = 0;
assign dip_flip = eff_flip^flip_xor;
// CHAR VRAM in mem.yaml
assign chram_dout = cpu_AB[10] ? chram_o16[15:8] : chram_o16[7:0];
assign chram_din  = {2{cpu_dout}};
assign chram_addr = cpu_AB[9:0];
assign chram_we   = {2{char_cs&~wr_n}} & {cpu_AB[10],~cpu_AB[10]};

always @* begin
    post_addr = prog_addr;
    if( ioctl_addr[24:8]>=OBJ_START[24:8] && ioctl_addr[24:8]<BA3_START[24:8] && !hige ) begin // bypass the header in the comparison
        post_addr[5:1] = { post_addr[4:1], post_addr[5] };
    end
end

always @(posedge clk) begin
    hige <= game_id==HIGEMARU;
    if( header && prog_we ) begin
        case(ioctl_addr[1:0])
            0: game_id  <= prog_data[1:0];
            1: flip_xor <= prog_data[0];
        endcase
    end
    // Vulgus has an "extra" DIP switch to enable screnn flip
    eff_flip <= (game_id==VULGUS & dipsw[16]) ^ flip_xor ^ flip ;
end
/* verilator tracing_off */
jt1942_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),

    .game_id    ( game_id       ),
    // sound
    .sres_b        ( sres_b        ),
    .snd_latch0_cs ( snd_latch0_cs ),
    .snd_latch1_cs ( snd_latch1_cs ),
    .snd_int       ( snd_int       ),
    // Higemaru's sound
    .ay0_cs     ( ay0_cs        ),
    .ay1_cs     ( ay1_cs        ),

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
    .cab_1p      ( cab_1p       ),
    .coin        ( coin         ),
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
    .sres_b         ( sres_b         ),
    .clk            ( clk            ),
    .cen3           ( cen3           ),
    .cen1p5         ( cen1p5         ),
    .game_id        ( game_id        ),

    .main_dout      ( cpu_dout       ),
    .main_latch0_cs ( snd_latch0_cs  ),
    .main_latch1_cs ( snd_latch1_cs  ),
    .snd_int        ( snd_int        ),
    // Higemaru's sound
    .main_wr_n      ( wr_n           ),
    .main_ay0_cs    ( ay0_cs         ),
    .main_ay1_cs    ( ay1_cs         ),
    .main_a0        ( cpu_AB[0]      ),
    // Sub Z80 ROM
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
/* verilator tracing_on */
jt1942_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .game_id    ( game_id       ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB[10:0]  ),
    .V          ( V             ),
    .H          ( H             ),
    .rd_n       ( rd_n          ),
    .wr_n       ( wr_n          ),
    .flip       ( dip_flip      ),
    .cpu_dout   ( cpu_dout      ),
    .pause      ( ~dip_pause    ), //dipsw_a[7]    ),
    // CHAR
    .char_cs    ( char_cs       ),
    .char_addr  ( char_addr     ), // CHAR ROM
    .char_data  ( char_data     ),
    .char_ok    ( char_ok       ),
    .char_busy  ( char_busy     ),
    .tmap_addr  ( tmap_addr     ),
    .tmap_dout  ( tmap_dout     ),
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
    .prog_din   ( prog_data     ),
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
