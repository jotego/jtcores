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

module jtcommando_game(
    input           rst,
    input           soft_rst,
    input           clk,        // 24   MHz
    output          cen12,      // 12   MHz
	output          cen6,       //  6   MHz
    output          cen3,       //  3   MHz
    output          cen1p5,     //  1.5 MHz
    output   [3:0]  red,
    output   [3:0]  green,
    output   [3:0]  blue,
    output          LHBL,
    output          LVBL,
    output          HS,
    output          VS,
    // cabinet I/O
    input   [ 1:0]  start_button,
    input   [ 1:0]  coin_input,
    input   [ 5:0]  joystick1,
    input   [ 5:0]  joystick2,
    // SDRAM interface
    input           downloading,
    input           loop_rst,
    output          sdram_req,
    output  [21:0]  sdram_addr,
    input   [31:0]  data_read,
    input           data_rdy,
    input           sdram_ack,
    output          refresh_en,
    // ROM LOAD
    input   [21:0]  ioctl_addr,
    input   [ 7:0]  ioctl_data,
    input           ioctl_wr,
    output  [21:0]  prog_addr,
    output  [ 7:0]  prog_data,
    output  [ 1:0]  prog_mask,
    output          prog_we,
    // DEBUG
    input           enable_char,
    input           enable_obj,
    input           enable_scr,
    // DIP switches
    input           dip_pause, // Not a DIP on the original PCB
    input   [ 1:0]  dip_lives,
    input   [ 1:0]  dip_level,
    input   [ 1:0]  dip_bonus,
    input           dip_game_mode,
    input           dip_attract_snd,
    input           dip_upright,
    // Sound output
    input           enable_psg,
    input           enable_fm,
    output  signed [15:0] ym_snd,
    output          sample
);

parameter CLK_SPEED=12;

wire [8:0] V;
wire [8:0] H;
wire HINIT;

wire [12:0] cpu_AB;
wire char_cs;
wire flip;
wire [7:0] cpu_dout, char_dout;
wire rd;
wire char_mrdy, scr_mrdy;
wire [12:0] char_addr;
wire [ 7:0] chram_dout,scram_dout;
wire [15:0] chrom_data;
wire rom_ready;

reg rst_game=1'b1;
reg rst_aux;

jtgng_cen #(.CLK_SPEED(CLK_SPEED)) u_cen(
    .clk    ( clk       ),    // 12 MHz
    .cen12  ( cen12     ),
    .cen6   ( cen6      ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    )
);

always @(posedge clk)
    if( rst || !rom_ready ) begin
        {rst_game,rst_aux} <= 2'b11;
    end
    else begin
        {rst_game,rst_aux} <= {rst_aux, downloading };
    end

wire LHBL_obj, LVBL_obj, Hsub;

jtgng_timer u_timer(
    .clk       ( clk      ),
    .cen12     ( cen12    ),
    .cen6      ( cen6     ),
    .rst       ( rst      ),
    .V         ( V        ),
    .H         ( H        ),
    .Hsub      ( Hsub     ),
    .Hinit     ( HINIT    ),
    .LHBL      ( LHBL     ),
    .LHBL_obj  ( LHBL_obj ),
    .LVBL      ( LVBL     ),
    .LVBL_obj  ( LVBL_obj ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          )
);

wire RnW;
wire [3:0] char_pal;

wire [14:0] scr_addr;
wire [23:0] scr_dout;

wire [3:0] cc;
wire blue_cs;
wire redgreen_cs;
wire [ 5:0] obj_pxl;

wire bus_ack, bus_req;
wire [16:0] main_addr;
wire [ 7:0] main_dout;
wire [15:0] sdram_din;
wire [12:0] wr_row;
wire [ 8:0] wr_col;
wire        main_cs;
// OBJ
wire [ 8:0] obj_AB;
wire OKOUT;
wire [7:0] main_ram;
wire blcnten;
// sound
wire sres_b;
wire [7:0] snd_latch;

wire scr_cs, scrpos_cs;

wire [5:0] prom_we;

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
    // bus sharing
    .ram_dout   ( main_ram      ),
    .obj_AB     ( obj_AB        ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .bus_req    ( bus_req       ),
    .bus_ack    ( bus_ack       ),
    // sound
    .sres_b     ( sres_b        ),
    .snd_latch  ( snd_latch     ),

    .LVBL       ( LVBL          ),
    .main_cs    ( main_cs       ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .scr_cs     ( scr_cs        ),
    .scrpos_cs  ( scrpos_cs     ),
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),
    .flip       ( flip          ),
    .cpu_AB     ( cpu_AB        ),
    .RnW        ( RnW           ),
    .rom_addr   ( main_addr     ),
    .rom_dout   ( main_dout     ),
    .start_button( start_button ),
    .coin_input ( coin_input    ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    // DIP switches
    .dip_pause      ( dip_pause       ),
    .dip_flip       ( 1'b0            ),
    .dip_lives      ( dip_lives       ),
    .dip_level      ( dip_level       ),
    .dip_bonus      ( dip_bonus       ),
    .dip_game_mode  ( dip_game_mode   ),
    .dip_attract_snd( dip_attract_snd ),
    .dip_upright    ( dip_upright     )
);

wire [15:0] obj_addr;
wire [15:0] obj_dout;

wire [14:0] snd_addr;
wire [ 7:0] snd_dout;
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
    .rom_dout       ( snd_dout   ),
    .rom_cs         (            ),
    .enable_psg     ( enable_psg ),
    .enable_fm      ( enable_fm  ),
    .ym_snd         ( ym_snd     ),
    .sample         ( sample     )
);
`else
assign snd_addr = 15'd0;
assign sample   = 1'b0;
assign ym_snd   = 16'b0;
`endif

jtgng_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_AB     ( cpu_AB[10:0]  ),
    .V          ( V[7:0]        ),
    .H          ( H             ),
    .RnW        ( RnW           ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    .pause      ( !dip_pause    ),
    // CHAR
    .char_cs    ( char_cs       ),
    .chram_dout ( chram_dout    ),
    .char_mrdy  ( char_mrdy     ),
    .char_addr  ( char_addr     ),
    .chrom_data ( chrom_data    ),
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
    .LVBL_obj   ( LVBL_obj      ),
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),
    .enable_char( enable_char   ),
    .enable_obj ( enable_obj    ),
    .enable_scr ( enable_scr    ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

assign scr_dout[23:16] = 8'd0; // fix me!

// 
jt1943_rom2 #(.char_aw(13),.main_aw(17),.obj_aw(16),.scr1_aw(15),
    .char_offset( 22'h0E000 ),
    .scr1_offset( 22'h10000 ),
    .obj_offset(  22'h20000 )

) u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),
    .LHBL        ( LHBL          ),
    .LVBL        ( LVBL          ),

    .main_cs     ( main_cs       ),
    .snd_cs      ( snd_cs        ),
    .main_ok     ( main_ok       ),
    .snd_ok      ( snd_ok        ),

    .char_addr   ( char_addr     ),
    .main_addr   ( main_addr     ),
    .snd_addr    ( snd_addr      ),
    .obj_addr    ( obj_addr      ),
    .scr1_addr   ( scr_addr      ),
    .scr2_addr   ( 15'd0         ),
    .map1_addr   ( 14'd0         ),
    .map2_addr   ( 14'd0         ),

    .char_dout   ( char_dout     ),
    .main_dout   ( main_dout     ),
    .snd_dout    ( snd_dout      ),
    .obj_dout    ( obj_dout      ),
    .map1_dout   (               ),
    .map2_dout   (               ),
    .scr1_dout   ( scr_dout[15:0]      ), // fix me!
    .scr2_dout   (               ),

    .ready       ( rom_ready     ),
    // SDRAM interface
    .sdram_req   ( sdram_req     ),
    .sdram_ack   ( sdram_ack     ),
    .data_rdy    ( data_rdy      ),
    .downloading ( downloading   ),
    .loop_rst    ( loop_rst      ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     ),
    .refresh_en  ( refresh_en    )
);

jtcommando_prom_we u_prom_we(
    .clk_rom     ( clk_rom       ),
    .clk_rgb     ( clk           ),
    .downloading ( downloading   ),

    .ioctl_wr    ( ioctl_wr      ),
    .ioctl_addr  ( ioctl_addr    ),
    .ioctl_data  ( ioctl_data    ),

    .prog_data   ( prog_data     ),
    .prog_mask   ( prog_mask     ),
    .prog_addr   ( prog_addr     ),
    .prog_we     ( prog_we       ),

    .prom_we     ( prom_we       )
);

assign prom_1d = prom_we[0];
assign prom_2d = prom_we[1];
assign prom_3d = prom_we[2];
assign prom_1h = prom_we[3];
assign prom_6l = prom_we[4];
assign prom_6e = prom_we[5];

endmodule // jtgng