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
    Date: 20-1-2019 */
    
module jt1942_game(
    input           rst,
    input           soft_rst,
    input           clk,        // 24   MHz
    input           clk_rom,    // 96   MHz    
    input           cen6,       //  6   MHz
    input           cen3,       //  3   MHz
    input           cen1p5,     //  1.5 MHz
    output   [3:0]  red,
    output   [3:0]  green,
    output   [3:0]  blue,
    output          LHBL,
    output          LVBL,
    output          HS,
    output          VS,
    // cabinet I/O
    input   [ 7:0]  joystick1,
    input   [ 7:0]  joystick2,  

    // SDRAM interface
    input           downloading,
    input           loop_rst,
    output          autorefresh,
    output          loop_start,
    output  [21:0]  sdram_addr,
    input   [15:0]  data_read,
    input   [24:0]  romload_addr,
    input   [15:0]  romload_data,

    // PROM programming
    input   [ 7:0]  prog_addr,
    input   [ 3:0]  prog_din,
    input           prom_k6_we,
    input           prom_d1_we,
    input           prom_d2_we,
    input           prom_e8_we,
    input           prom_e9_we,
    input           prom_e10_we,
    input           prom_f1_we,    

    // DIP switches
    input           dip_test,
    input   [1:0]   dip_planes,
    input   [1:0]   dip_level, // difficulty level
    input           dip_upright,
    input   [3:0]   dip_price,
    // Sound output
    output  [8:0]   snd,
    output          sample
);

wire [8:0] V;
wire [8:0] H;
wire HINIT;

wire [12:0] cpu_AB;
wire char_cs;
wire flip;
wire [7:0] cpu_dout, char_dout;
wire [ 7:0] chram_dout,scram_dout;
wire rd;
wire scr_mrdy;
wire rom_ready;

reg rst_game=1'b1;
reg rst_aux;

always @(posedge clk)
    if( rst || !rom_ready ) begin
        {rst_game,rst_aux} <= 2'b11;
    end
    else begin
        {rst_game,rst_aux} <= {rst_aux, downloading };
    end

wire LHBL_obj;

jtgng_timer u_timer(
    .clk       ( clk      ),
    .clk_en    ( cen6     ),
    .rst       ( rst      ),
    .V         ( V        ),
    .H         ( H        ),
    .Hinit     ( HINIT    ),
    .LHBL      ( LHBL     ),
    .LHBL_obj  ( LHBL_obj ),
    .LVBL      ( LVBL     ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          )
);

wire rd_n;
// sound
wire sres_b;
wire [7:0] snd_latch;

wire scr_cs, scrpos_cs;

wire [7:0] dipsw_a = { dip_planes, 2'b00, dip_upright, dip_price };
wire [7:0] dipsw_b = { 1'b0, dip_level, 1'b0, dip_test, 3'b0 };

// ROM data
wire  [11:0]  char_addr;
wire  [13:0]  obj_addr;
wire  [15:0]  char_data, obj_data;
wire  [ 7:0]  main_data, snd_data;
wire  [23:0]  scr_data;
wire  [14:0]  scr_addr;
wire  [16:0]  main_addr;
wire  [14:0]  snd_addr;

wire snd_latch0_cs, snd_latch1_cs, snd_int;
wire wait_n;

jt1942_main u_main(
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cen1p5     ( cen1p5        ),
    .rst        ( rst_game      ),
    .soft_rst   ( soft_rst      ),
    .wait_n     ( wait_n        ),
    .scr_mrdy   ( scr_mrdy      ),
    .char_dout  ( chram_dout    ),
    .scr_dout   ( scram_dout    ),
    // sound
    .sres_b        ( sres_b        ),
    .snd_latch0_cs ( snd_latch0_cs ),
    .snd_latch1_cs ( snd_latch1_cs ),
    .snd_int       ( snd_int       ),
    
    .LHBL       ( LHBL          ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .scr_cs     ( scr_cs        ),
    .scrpos_cs  ( scrpos_cs     ),
    .obj_cs     ( obj_cs        ),
    .flip       ( flip          ),
    .V          ( V[7:0]        ),
    .cpu_AB     ( cpu_AB        ),
    .rd_n       ( rd_n          ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),   
    // PROM K6
    .prog_addr  ( prog_addr     ),
    .prom_k6_we ( prom_k6_we    ),
    .prog_din   ( prog_din      ),
    // DIP switches
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       )
);

`ifndef NOSOUND
jt1942_sound u_sound (
    .clk            ( clk            ),
    .cen6           ( cen6           ),
    .cen3           ( cen3           ),
    .cen1p5         ( cen1p5         ),
    .rst            ( rst_game       ),
    .soft_rst       ( soft_rst       ),
    .sres_b         ( sres_b         ),
    .main_dout      ( cpu_dout       ),
    .main_latch0_cs ( snd_latch0_cs  ),
    .main_latch1_cs ( snd_latch1_cs  ),
    .snd_int        ( snd_int        ),
    .rom_addr       ( snd_addr       ),
    .rom_data       ( snd_data       ),
    .snd            ( snd            ),
    .sample         ( sample         ) 
);
`else 
assign snd_addr = 15'd0;
`endif

jt1942_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cpu_AB     ( cpu_AB[10:0]  ),
    .V          ( V[7:0]        ),
    .H          ( H             ),
    .rd_n       ( rd_n          ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    // CHAR
    .char_cs    ( char_cs       ),
    .chram_dout ( chram_dout    ),
    .char_addr  ( char_addr     ), // CHAR ROM
    .char_data  ( char_data     ),
    .char_wait_n( wait_n        ),
    // SCROLL - ROM
    .scr_cs     ( scr_cs        ),
    .scrpos_cs  ( scrpos_cs     ),    
    .scram_dout ( scram_dout    ),
    .scr_addr   ( scr_addr      ),
    .scrom_data ( scr_data      ),
    .scr_mrdy   ( scr_mrdy      ),
    // OBJ
    .obj_cs     ( obj_cs        ),
    .HINIT      ( HINIT         ),
    .obj_addr   ( obj_addr      ),
    .objrom_data( obj_data      ),
    // Color Mix
    .LHBL       ( LHBL          ),
    .LHBL_obj   ( LHBL_obj      ),
    .LVBL       ( LVBL          ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    // PROM access
    .prog_addr  ( prog_addr     ),
    .prog_din   ( prog_din      ),
    .prom_f1_we ( prom_f1_we    ),
    .prom_d1_we ( prom_d1_we    ),
    .prom_d2_we ( prom_d2_we    ),
    .prom_e8_we ( prom_e8_we    ),
    .prom_e9_we ( prom_e9_we    ),
    .prom_e10_we( prom_e10_we   )
);

jtgng_rom #(
    .snd_offset (22'h09000),
    .char_offset(22'h0B000),
    .scr_offset (22'h0C000),
    .scr2_offset(22'h10000),
    .obj_offset (22'h18000)
) u_rom (
    .clk         ( clk_rom       ), // 96MHz = 32 * 6 MHz -> CL=2
    .clk24       ( clk           ),
    .cen6        ( cen6          ),
    .H           ( H[2:0]        ),
    .rst         ( rst           ),
    .char_addr   ( {1'b0,char_addr} ),
    .main_addr   ( main_addr     ),
    .snd_addr    ( snd_addr      ),
    .obj_addr    ( {2'd0, obj_addr} ),
    .scr_addr    ( scr_addr      ),

    .char_dout   ( char_data     ),
    .main_dout   ( main_data     ),
    .snd_dout    ( snd_data      ),
    .obj_dout    ( obj_data      ),
    .scr_dout    ( scr_data      ),
    .ready       ( rom_ready     ),
    // SDRAM interface
    .downloading ( downloading   ),
    .loop_rst    ( loop_rst      ),
    .autorefresh ( autorefresh   ),
    .loop_start  ( loop_start    ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     )
);

endmodule // jtgng