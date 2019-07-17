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
    input           dip_level,
    input   [ 1:0]  dip_start,
    input   [ 1:0]  dip_price1,
    input   [ 1:0]  dip_price2,
    input   [ 2:0]  dip_bonus,
    input   [ 1:0]  dip_upright,
    input           dip_demosnd,
    input           dip_flip,
    // Sound output
    output  [15:0]  snd,
    output          sample,
    // Debug
    input   [3:0]   gfx_en
);

parameter CLK_SPEED=12;

wire [8:0] V;
wire [8:0] H;
wire HINIT;

wire [12:0] cpu_AB;
wire snd_cs;
wire char_cs;
wire flip;
wire [7:0] cpu_dout, chram_dout, scram_dout;
wire rd, cpu_cen;
// ROM data
wire [15:0] char_data;
wire [23:0] scr_data;
wire [15:0] obj_data;
wire [ 7:0] main_data;
wire [ 7:0] snd_data;
// ROM address
wire [15:0] main_addr;
wire [14:0] snd_addr;
wire [12:0] char_addr;
wire [14:0] scr_addr;
wire [15:0] obj_addr;

wire rom_ready;
wire main_ok, snd_ok;

reg rst_game=1'b1;
reg rst_aux;

assign sample = 1'b0;

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

wire [3:0] cc;
wire blue_cs;
wire redgreen_cs;
wire [ 5:0] obj_pxl;

wire bus_ack, bus_req;
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
wire sres_b, snd_int;
wire snd_latch_cs;
wire char_busy, scr_busy;

wire scr_cs, scrpos_cs;

wire [5:0] prom_we;
wire prom_1d, prom_2d, prom_3d, prom_1h, prom_6l, prom_6e;

`ifndef NOMAIN
wire [7:0] dipsw_a = { dip_price1, dip_price2, dip_lives, dip_start };
wire [7:0] dipsw_b = { dip_upright, dip_flip, dip_level, dip_demosnd, dip_bonus };

jtcommando_main u_main(
    .rst        ( rst_game      ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    // Timing
    .flip       ( flip          ),
    .V          ( V             ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    // sound
    .sres_b     ( sres_b        ),
    .snd_int    ( snd_int       ),
    .snd_latch_cs( snd_latch_cs ),
    // Characters
    .char_dout  ( chram_dout    ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    // scroll
    .scrpos_cs  ( scrpos_cs     ),
    .scr_dout   ( scram_dout    ),
    .scr_cs     ( scr_cs        ),
    .scr_busy   ( scr_busy      ),
    // cabinet I/O
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    .start_button( start_button ),
    .coin_input ( coin_input    ),
    // bus sharing
    .cpu_AB     ( cpu_AB        ),
    .ram_dout   ( main_ram      ),
    .obj_AB     ( obj_AB        ),
    .OKOUT      ( OKOUT         ),
    .bus_req    ( bus_req       ),
    .bus_ack    ( bus_ack       ),
    .blcnten    ( blcnten       ),

    .RnW        ( RnW           ),
    // ROM access
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // PROM 6L (interrupts)
    .prog_addr  ( prog_addr[7:0]),
    .prom_6l_we ( prom_6l       ),
    .prog_din   ( prog_data[3:0]),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       )
);
`else 
assign main_addr   = 16'd0;
assign char_cs     = 1'b0;
assign scr_cs      = 1'b0;
assign scrpos_cs   = 1'b0;
assign blue_cs     = 1'b0;
assign redgreen_cs = 1'b0;
assign bus_ack     = 1'b0;
assign flip        = 1'b0;
assign RnW         = 1'b1;
`endif

`ifndef NOSOUND
jtcommando_sound u_sound (
    .clk            ( clk          ),
    .cen3           ( cen3         ),
    .cen1p5         ( cen1p5       ),
    .main_cen       ( cen3         ), // fix!
    // Interface with main CPU
    .sres_b         ( sres_b       ),
    .main_dout      ( cpu_dout     ),
    .main_latch_cs  ( snd_latch_cs ),
    .snd_int        ( snd_int      ),
    // Sound control
    .enable_psg     ( 1'b1         ),
    .enable_fm      ( 1'b1         ),
    // ROM
    .rom_addr       ( snd_addr     ),
    .rom_data       ( snd_data     ),
    .rom_cs         ( snd_cs       ),
    .rom_ok         ( snd_ok       ),
    // sound output
    .snd            ( snd          )
);
`else
assign snd_addr = 15'd0;
assign snd_cs   = 1'b0;
assign snd      = 16'b0;
`endif

wire scr1_ok, scr2_ok, char_ok;
wire scr_ok = scr1_ok & scr2_ok;

jtcommando_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen12      ( cen12         ),
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
    .char_addr  ( char_addr     ),
    .chrom_data ( char_data     ),
    .char_busy  ( char_busy     ),
    .char_ok    ( char_ok       ),
    // SCROLL - ROM
    .scr_cs     ( scr_cs        ),
    .scrpos_cs  ( scrpos_cs     ),
    .scram_dout ( scram_dout    ),
    .scr_addr   ( scr_addr      ),
    .scr_data   ( scr_data      ),
    .scr_ok     ( scr_ok        ),
    .scr_busy   ( scr_busy      ),
    // OBJ
    .HINIT      ( HINIT         ),
    .obj_AB     ( obj_AB        ),
    .main_ram   ( main_ram      ),
    .OKOUT      ( OKOUT         ),
    .bus_req    ( bus_req       ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    .obj_addr   ( obj_addr      ),
    .objrom_data( obj_data      ),
    // PROMs
    .prog_addr  ( prog_addr[7:0]),
    .prom_1d_we ( prom_1d       ),
    .prom_2d_we ( prom_2d       ),
    .prom_3d_we ( prom_3d       ),
    .prom_din   ( prog_data[3:0]),    
    // Color Mix
    .LHBL       ( LHBL          ),
    .LHBL_obj   ( LHBL_obj      ),
    .LVBL       ( LVBL          ),
    .LVBL_obj   ( LVBL_obj      ),
    .gfx_en     ( gfx_en        ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

wire [7:0] scr_nc; // no connect

// Scroll data: Z, Y, X
jt1943_rom2 #(.char_aw(13),.main_aw(16),.obj_aw(16),.scr1_aw(15),
    .snd_offset ( 22'h0_C000 >> 1 ),
    .char_offset( 22'h1_0000 >> 1 ),
    .scr1_offset( 22'h1_4000 >> 1 ),
    .scr2_offset( (22'h1_4000 >> 1) + 22'h0_8000 ),
    .obj_offset ( (22'h1_4000 >> 1) + 22'h1_0000 )
) u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),
    .LHBL        ( LHBL          ),
    .LVBL        ( LVBL          ),

    .main_cs     ( main_cs       ),
    .snd_cs      ( snd_cs        ),
    .main_ok     ( main_ok       ),
    .snd_ok      ( snd_ok        ),
    .scr1_ok     ( scr1_ok       ),
    .scr2_ok     ( scr2_ok       ),
    .char_ok     ( char_ok       ),

    .char_addr   ( char_addr     ),
    .main_addr   ( main_addr     ),
    .snd_addr    ( snd_addr      ),
    .obj_addr    ( obj_addr      ),
    .scr1_addr   ( scr_addr      ),
    .scr2_addr   ( scr_addr      ),
    .map1_addr   ( 14'd0         ),
    .map2_addr   ( 14'd0         ),

    .char_dout   ( char_data     ),
    .main_dout   ( main_data     ),
    .snd_dout    ( snd_data      ),
    .obj_dout    ( obj_data      ),
    .map1_dout   (               ),
    .map2_dout   (               ),
    .scr1_dout   ( scr_data[15:0] ),
    .scr2_dout   ( { scr_nc, scr_data[23:16] } ),

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
    .clk         ( clk           ),
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