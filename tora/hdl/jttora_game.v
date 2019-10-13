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
    Date: 12-10-2019 */

`timescale 1ns/1ps

module jttora_game(
    input           rst,
    input           clk,
    output          cen12,      // 12   MHz
    output          cen6,       //  6   MHz
    output          cen3,       //  3   MHz
    output          cen1p5,     //  1.5 MHz
    output   [3:0]  red,
    output   [3:0]  green,
    output   [3:0]  blue,
    output          LHBL,
    output          LVBL,
    output          LHBL_dly,
    output          LVBL_dly,
    output          HS,
    output          VS,
    // cabinet I/O
    input   [ 1:0]  start_button,
    input   [ 1:0]  coin_input,
    input   [ 6:0]  joystick1,
    input   [ 6:0]  joystick2,
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
    // DIP switches
    input   [31:0]  status,     // only bits 31:16 are looked at
    input           dip_pause,
    input           dip_flip,
    input           dip_test,
    input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB    
    // Sound output
    output  signed [15:0] snd,
    output          sample,
    input           enable_psg,
    input           enable_fm,
    // Debug
    input   [3:0]   gfx_en
);

parameter CLK_SPEED=48;

wire [ 8:0] V;
wire [ 8:0] H;
wire        HINIT;

wire [13:1] cpu_AB;
wire        snd_cs;
wire        char_cs, col_uw, col_lw;
wire        flip;
wire [15:0] char_dout, cpu_dout;
wire        rd, cpu_cen;
wire        char_busy;
wire        service = 1'b1;

// ROM data
wire [15:0] char_data, scr_data;
wire [31:0] obj_data;
wire [15:0] main_data, map_data;
wire [ 7:0] snd_data;

// ROM address
wire [17:1] main_addr;
wire [14:0] snd_addr;
wire [13:0] map_addr;
wire [13:0] char_addr;
wire [18:0] scr_addr;
wire [14:0] scr2_addr;
wire [18:0] obj_addr;
wire [ 7:0] dipsw_a, dipsw_b;
wire        cen10, cen10b, cen6b, cen_fm;

wire        rom_ready;
wire        main_ok, scr_ok, snd_ok, obj_ok, char_ok;

assign sample=1'b1;
assign obj_addr[0] = 1'b0; // fixed for 32 bit values

`ifdef MISTER

reg rst_game;

always @(negedge clk)
    rst_game <= rst || !rom_ready;

`else

reg rst_game=1'b1;

always @(posedge clk) begin : rstgame_gen
    reg rst_aux;
    if( rst || !rom_ready ) begin
        {rst_game,rst_aux} <= 2'b11;
    end
    else begin
        {rst_game,rst_aux} <= {rst_aux, downloading };
    end
end

`endif

jtgng_cen #(.CLK_SPEED(CLK_SPEED)) u_cen(
    .clk    ( clk       ),
    .cen12  (           ),
    .cen12b (           ),
    .cen6   ( cen6      ),
    .cen6b  ( cen6b     ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    )
);

jtgng_cen10 u_cen10(
    .clk    ( clk       ),
    .cen10  ( cen10     ),
    .cen10b ( cen10b    )
);

// temporary values for FM clock enables
assign cen_fm  = cen3;  

jttora_dip u_dip(
    .clk        ( clk           ),
    .status     ( status        ),
    .dip_pause  ( dip_pause     ),
    .dip_test   ( dip_test      ),
    .dip_flip   ( dip_flip      ),
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       )
);

wire LHBL_obj, LVBL_obj;

jtgng_timer u_timer(
    .clk       ( clk      ),
    .cen6      ( cen6     ),
    .rst       ( rst      ),
    .V         ( V        ),
    .H         ( H        ),
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
// sound
wire [7:0] snd_latch;

wire        main_cs;
// OBJ
wire OKOUT, blcnten, obj_br, bus_ack;
wire [13:1] obj_AB;     // 1 more bit than older games
wire [15:0] oram_dout;

wire        prom_we;

jttora_prom_we u_prom_we(
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

wire [15:0] scrposh, scrposv;
wire UDSWn, LDSWn;

`ifndef NOMAIN
jttora_main u_main(
    .rst        ( rst_game      ),
    .clk        ( clk           ),
    .cen10      ( cen10         ),
    .cen10b     ( cen10b        ),
    .cpu_cen    ( cpu_cen       ),
    // Timing
    .flip       ( flip          ),
    .V          ( V             ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    // sound
    .snd_latch  ( snd_latch     ),
    // CHAR
    .char_dout  ( char_dout     ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    .UDSWn      ( UDSWn         ),
    .LDSWn      ( LDSWn         ),
    // SCROLL 
    .scrposh    ( scrposh       ),
    .scrposv    ( scrposv       ),
    .scr_bank   ( scr_addr[18]  ),
    // OBJ - bus sharing
    .obj_AB     ( obj_AB        ),
    .cpu_AB     ( cpu_AB        ),
    .oram_dout  ( oram_dout     ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .obj_br     ( obj_br        ),
    .bus_ack    ( bus_ack       ),
    .col_uw     ( col_uw        ),
    .col_lw     ( col_lw        ),
    // ROM
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .start_button( start_button ),
    .service     ( service      ),
    .coin_input  ( coin_input   ),
    .joystick1   ( joystick1    ),
    .joystick2   ( joystick2    ),

    .RnW        ( RnW           ),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       )
);
`else
assign main_addr   = 17'd0;
assign cpu_AB      = 13'd0;
assign cpu_dout    = 16'd0;
assign char_cs     = 1'b0;
assign bus_ack     = 1'b0;
assign flip        = 1'b0;
assign RnW         = 1'b1;
assign scrposh     = 16'd0;
assign scrposv     = 16'd0;
assign cpu_cen     = cen12;
assign scr_addr[18]= 1'b0;
`endif

`ifndef NOSOUND
jtgng_sound #(.LAYOUT(3)) u_sound (
    .rst            ( rst_game       ),
    .clk            ( clk            ),
    .cen3           ( cen_fm         ),
    .cen1p5         ( cen1p5         ),  // unused
    // Interface with main CPU
    .sres_b         ( 1'b1           ),  // unused
    .snd_latch      ( snd_latch      ),
    .snd_int        ( 1'b1           ),  // unused
    // sound control
    .enable_psg     ( enable_psg     ),
    .enable_fm      ( enable_fm      ),
    .psg_gain       ( psg_gain       ),
    // ROM
    .rom_addr       ( snd_addr       ),
    .rom_data       ( snd_data       ),
    .rom_cs         ( snd_cs         ),
    .rom_ok         ( snd_ok         ),
    // sound output
    .ym_snd         ( snd            )
);
`else
assign snd_addr = 15'd0;
assign snd_cs   = 1'b0;
assign snd      = 16'b0;
`endif

reg pause;
always @(posedge clk) pause <= ~dip_pause;

`ifndef NOVIDEO
jttora_video #(
    .AVATAR_MAX   (9)
) u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen12      ( cen12         ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB        ),
    .V          ( V[7:0]        ),
    .H          ( H             ),
    .RnW        ( RnW           ),
    .UDSWn      ( UDSWn         ),
    .LDSWn      ( LDSWn         ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    .pause      ( pause         ),
    // CHAR
    .char_cs    ( char_cs       ),
    .char_dout  ( char_dout     ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_busy  ( char_busy     ),
    .char_ok    ( char_ok       ),
    // SCROLL
    .map_data   ( map_data      ),
    .map_addr   ( map_addr      ),
    .scr_addr   ( scr_addr[17:0]),
    .scr_data   ( scr_data      ),
    .scrposh    ( scrposh       ),
    .scrposv    ( scrposv       ),
    .scr_ok     ( scr_ok        ),
    // OBJ
    .HINIT      ( HINIT         ),
    .obj_AB     ( obj_AB        ),
    .oram_dout  ( oram_dout[11:0] ),
    .obj_addr   ( obj_addr[18:1]),
    .obj_data   ( obj_data      ),
    .OKOUT      ( OKOUT         ),
    .bus_req    ( obj_br        ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    .col_uw     ( col_uw        ),
    .col_lw     ( col_lw        ),
    .obj_ok     ( obj_ok        ),
    // PROMs
    .prog_addr    ( prog_addr[7:0]),
    .prom_prio_we ( prom_we       ),
    .prom_din     ( prog_data[3:0]),
    // Color Mix
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .LHBL_obj   ( LHBL_obj      ),
    .LVBL_obj   ( LVBL_obj      ),
    .LHBL_dly   ( LHBL_dly      ),
    .LVBL_dly   ( LVBL_dly      ),
    .gfx_en     ( gfx_en        ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);
`else
// Video module may be ommitted for SDRAM load simulation
assign red       = 4'h0;
assign green     = 4'h0;
assign blue      = 4'h0;
assign obj_addr  = 0;
assign scr_addr  = 0;
assign char_addr = 0;
`endif

wire [ 7:0] scr_nc; // no connect
// // CPU addresses memory by words, not bytes:
wire [17:0] main_rom_addr = { main_addr,1'b0 };

// Scroll data: Z, Y, X
jtgng_rom #(
    .main_dw    ( 16              ),
    .main_aw    ( 18              ),
    .char_aw    ( 14              ),
    .obj_aw     ( 18              ),
    .scr1_aw    ( 19              ),
    .obj_dw     ( 32              ),
    .snd_offset ( 22'h4_0000 >> 1 ),
    .char_offset( 22'h5_8000 >> 1 ),
    .map1_offset( 22'h6_0000 >> 1 ),
    .scr1_offset( 22'h10_0000     ), // SCR and OBJ are not shifted
    .obj_offset ( 22'h20_0000     )
) u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),
    .LHBL        ( LHBL          ),
    .LVBL        ( LVBL          ),

    .pause       ( pause         ),
    .main_cs     ( main_cs       ),
    .snd_cs      ( snd_cs        ),
    .main_ok     ( main_ok       ),
    .snd_ok      ( snd_ok        ),
    .scr1_ok     ( scr_ok        ),
    .scr2_ok     (               ),
    .char_ok     ( char_ok       ),
    .obj_ok      ( obj_ok        ),

    .char_addr   ( char_addr     ),
    .main_addr   ( main_rom_addr ),
    .snd_addr    ( snd_addr      ),
    .obj_addr    ( obj_addr      ),
    .scr1_addr   ( scr_addr      ),
    .scr2_addr   ( 15'd0         ),
    .map1_addr   ( map_addr      ),
    .map2_addr   ( 14'd0         ),

    .char_dout   ( char_data     ),
    .main_dout   ( main_data     ),
    .snd_dout    ( snd_data      ),
    .obj_dout    ( obj_data      ),
    .map1_dout   ( map_data      ),
    .map2_dout   (               ),
    .scr1_dout   ( scr_data      ),
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
    .refresh_en  ( refresh_en    ),

    .prog_data   ( prog_data     ),
    .prog_mask   ( prog_mask     ),
    .prog_addr   ( prog_addr     ),
    .prog_we     ( prog_we       )
);

endmodule