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
    // ROM data
    output  [12:0]  char_addr,
    input   [15:0]  char_data,
    output  [12:0]  obj_addr,
    input   [15:0]  obj_data,
    output  [14:0]  scr_addr,
    input   [23:0]  scr_data,    
    output  [16:0]  main_addr,
    input   [ 7:0]  main_data,
    output  [14:0]  snd_addr,
    input   [ 7:0]  snd_data,

    // PROM programming
    input   [ 7:0]  prog_addr,
    input   [ 3:0]  prom_din,
    input           prom_e8_we,
    input           prom_e9_we,
    input           prom_e10_we,
    input           prom_f1_we,    

    // DIP switches
    input           dip_game_mode,
    input           dip_attract_snd,
    input           dip_upright,
    // Sound output
    output  [15:0]  snd,
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
wire char_mrdy, scr_mrdy;
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

wire RnW;
// sound
wire sres_b;
wire [7:0] snd_latch;

wire scr_cs, scrpos_cs;

jtgng_main u_main(
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cen1p5     ( cen1p5        ),
    .rst        ( rst_game      ),
    .soft_rst   ( soft_rst      ),
    .ch_mrdy    ( char_mrdy     ),
    .scr_mrdy   ( scr_mrdy      ),
    .char_dout  ( chram_dout    ),
    .scr_dout   ( scram_dout    ),
    // sound
    .sres_b     ( sres_b        ),
    .snd_latch  ( snd_latch     ),
    
    .LVBL       ( LVBL          ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .scr_cs     ( scr_cs        ),
    .scrpos_cs  ( scrpos_cs     ),
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),
    .flip       ( flip          ),
    .bus_ack    ( bus_ack       ),
    .cpu_AB     ( cpu_AB        ),
    .RnW        ( RnW           ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),   
    // DIP switches
    .dip_flip       ( 1'b0      ),
    .dip_game_mode  ( dip_game_mode     ),
    .dip_attract_snd( dip_attract_snd   ),
    .dip_upright    ( dip_upright       )
);

`ifndef NOSOUND
jtgng_sound u_sound (
    .clk            ( clk        ),
    .cen3           ( cen3       ),
    .cen1p5         ( cen1p5     ),
    .rst            ( rst_game   ),
    .soft_rst       ( soft_rst   ),
    .sres_b         ( sres_b     ),
    .snd_latch      ( snd_latch  ),
    .V32            ( V[5]       ),
    .rom_addr       ( snd_addr   ),
    .rom_data       ( snd_data   ),
    .enable_psg     ( enable_psg ),
    .enable_fm      ( enable_fm  ),
    .ym_snd         ( ym_snd     ),
    .sample         ( sample     ) 
);
`else 
assign snd_addr = 15'd0;
`endif

jtgng_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cpu_AB     ( cpu_AB[10:0]  ),
    .V          ( V[7:0]        ),
    .H          ( H             ),
    .RnW        ( RnW           ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    // CHAR
    .char_cs    ( char_cs       ),
    .chram_dout ( chram_dout    ),
    .char_mrdy  ( char_mrdy     ),
    .char_addr  ( char_addr     ), // CHAR ROM
    .char_data  ( char_data     ),
    // SCROLL - ROM
    .scr_cs     ( scr_cs        ),
    .scrpos_cs  ( scrpos_cs     ),    
    .scram_dout ( scram_dout    ),    
    .scr_addr   ( scr_addr      ),
    .scrom_data ( scr_dout      ),   
    .scr_mrdy   ( scr_mrdy      ), 
    // OBJ
    .HINIT      ( HINIT         ),    
    .obj_AB     ( obj_AB        ),    
    .main_ram   ( main_ram      ),
    .OKOUT      ( OKOUT         ),
    .bus_req    ( bus_req       ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    .obj_addr   ( obj_addr      ),
    .objrom_data( obj_dout      ),    
    // Color Mix
    .LHBL       ( LHBL          ),       
    .LHBL_obj   ( LHBL_obj      ),       
    .LVBL       ( LVBL          ),
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),    
    .enable_char( enable_char   ),
    .enable_obj ( enable_obj    ),
    .enable_scr ( enable_scr    ),    
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )    
);

endmodule // jtgng