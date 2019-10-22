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
    Date: 14-9-2019 */

`timescale 1ns/1ps

module jtbiocom_game(
    input           rst,
    input           clk,
    output          cen12,      // 12   MHz
    output          cen6,       //  6   MHz
    output          cen3,       //  3   MHz
    output          cen1p5,     //  1.5 MHz
    output   [4:0]  red,
    output   [4:0]  green,
    output   [4:0]  blue,
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
    output  signed [15:0] snd_left,
    output  signed [15:0] snd_right,
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
wire [ 7:0] char_dout, scr1_dout, scr2_dout;
wire [15:0] cpu_dout;
wire        rd, cpu_cen;
wire        char_busy, scr1_busy, scr2_busy;

// ROM data
wire [15:0] char_data, scr1_data, scr2_data;
wire [31:0] obj_data;
wire [15:0] main_data;
wire [ 7:0] snd_data;
// MCU interface
wire [ 7:0] snd_din, snd_dout;
wire        snd_mcu_wr;
wire        mcu_brn;
wire [ 7:0] mcu_din, mcu_dout;
wire [16:1] mcu_addr;
wire        mcu_wr, mcu_DMAn, mcu_DMAONn;

// ROM address
wire [17:1] main_addr;
wire [14:0] snd_addr;
wire [12:0] char_addr;
wire [16:0] scr1_addr;
wire [14:0] scr2_addr;
wire [16:0] obj_addr;
wire [ 7:0] dipsw_a, dipsw_b;
wire        cen12b, cen6b, cen_fm, cen_fm2;

wire        rom_ready;
wire        main_ok, snd_ok, obj_ok;
wire        scr1_ok, scr2_ok, char_ok;

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

wire cen8;

jtgng_cen #(.CLK_SPEED(CLK_SPEED)) u_cen(
    .clk    ( clk       ),
    .cen12  ( cen12     ),
    .cen12b ( cen12b    ),
    .cen8   ( cen8      ),
    .cen6   ( cen6      ),
    .cen6b  ( cen6b     ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    )
);

// temporary values for FM clock enables
assign cen_fm  = cen3;  
assign cen_fm2 = cen1p5;

jtbiocom_dip u_dip(
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

wire [ 1:0] prom_we;
wire        prom_mcu_we  = prom_we[0];
wire        prom_prio_we = prom_we[1];

jtbiocom_prom_we u_prom_we(
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

wire scr1_cs, scr2_cs;
wire [9:0] scr1_hpos, scr1_vpos;
wire [8:0] scr2_hpos, scr2_vpos;

`ifndef NOMAIN
jtbiocom_main u_main(
    .rst        ( rst_game      ),
    .clk        ( clk           ),
    .cen12      ( cen12         ),
    .cen12b     ( cen12b        ),
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
    // SCROLL 1
    .scr1_dout  ( scr1_dout     ),
    .scr1_cs    ( scr1_cs       ),
    .scr1_busy  ( scr1_busy     ),
    .scr1_hpos  ( scr1_hpos     ),
    .scr1_vpos  ( scr1_vpos     ),
    // SCROLL 2
    .scr2_dout  ( scr2_dout     ),
    .scr2_cs    ( scr2_cs       ),
    .scr2_busy  ( scr2_busy     ),
    .scr2_hpos  ( scr2_hpos     ),
    .scr2_vpos  ( scr2_vpos     ),
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
    // MCU interface
    .mcu_brn    (  mcu_brn      ),
    .mcu_din    (  mcu_din      ),
    .mcu_dout   (  mcu_dout     ),
    .mcu_addr   (  mcu_addr     ),
    .mcu_wr     (  mcu_wr       ),
    .mcu_DMAn   (  mcu_DMAn     ),
    .mcu_DMAONn (  mcu_DMAONn   ),
    // ROM
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .start_button( start_button ),
    .coin_input  ( coin_input   ),
    .joystick1   ( joystick1[5:0] ),
    .joystick2   ( joystick2[5:0] ),

    .RnW        ( RnW           ),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       )
);
`else
    `ifndef SIM_SCR1_HPOS
    `define SIM_SCR1_HPOS 10'd0
    `endif
    `ifndef SIM_SCR1_VPOS
    `define SIM_SCR1_VPOS 10'd0
    `endif
    `ifndef SIM_SCR2_HPOS
    `define SIM_SCR2_HPOS 9'd0
    `endif
    `ifndef SIM_SCR1_VPOS
    `define SIM_SCR2_VPOS 9'd0
    `endif

    assign main_addr   = 17'd0;
    assign cpu_AB      = 13'd0;
    assign cpu_dout    = 16'd0;
    assign char_cs     = 1'b0;
    assign scr1_cs     = 1'b0;
    assign scr2_cs     = 1'b0;
    assign bus_ack     = 1'b0;
    assign flip        = 1'b0;
    assign RnW         = 1'b1;
    assign scr1_hpos   = `SIM_SCR1_HPOS;
    assign scr1_vpos   = `SIM_SCR1_VPOS;
    assign scr2_hpos   = `SIM_SCR2_HPOS;
    assign scr2_vpos   = `SIM_SCR2_VPOS;
    assign cpu_cen     = cen12;
    assign OKOUT       = 1'b0;
`endif

`ifndef NOMCU
jtbiocom_mcu u_mcu(
    .rst        ( rst_game      ),
    .clk        ( clk           ),
    .cen6a      ( cen6          ),       //  6   MHz
    .cen6b      ( cen6b         ),       //  6   MHz
    // Main CPU interface
    .DMAONn     ( mcu_DMAONn    ),
    .mcu_din    ( mcu_din       ),
    .mcu_dout   ( mcu_dout      ),
    .mcu_wr     ( mcu_wr        ),   // always write to low bytes
    .mcu_addr   ( mcu_addr      ),
    .mcu_brn    ( mcu_brn       ), // RQBSQn
    .DMAn       ( mcu_DMAn      ),

    // Sound CPU interface
    .snd_din    ( snd_din       ),
    .snd_dout   ( snd_dout      ),
    .snd_mcu_wr ( snd_mcu_wr    ),
    // ROM programming
    .prog_addr  ( prog_addr[11:0] ),
    .prom_din   ( prog_data       ),
    .prom_we    ( prom_mcu_we     )
);
`else 
assign mcu_DMAn = 1'b1;
assign mcu_brn  = 1'b1;
assign mcu_wr   = 1'b1;
assign mcu_addr = 16'd0;
assign mcu_din  =  8'd0;
`endif

`ifndef NOSOUND
jtbiocom_sound u_sound (
    .rst            ( rst_game       ),
    .clk            ( clk            ),
    .cen_fm         ( cen_fm         ),
    .cen_fm2        ( cen_fm2        ),
    // Interface with main CPU
    .snd_latch      ( snd_latch      ),
    // Interface with MCU
    .snd_din        ( snd_din        ),
    .snd_dout       ( snd_dout       ),
    .snd_mcu_wr     ( snd_mcu_wr     ),
    // ROM
    .rom_addr       ( snd_addr       ),
    .rom_data       ( snd_data       ),
    .rom_cs         ( snd_cs         ),
    .rom_ok         ( snd_ok         ),
    // sound output
    .left           ( snd_left       ),
    .right          ( snd_right      ),
    .sample         (     sample     )
);
`else
assign snd_addr   = 15'd0;
assign snd_cs     = 1'b0;
assign snd_left  = 16'b0;
assign snd_right = 16'b0;
assign snd_mcu_wr = 1'b0;
assign snd_dout   = 8'd0;
`endif

reg pause;
always @(posedge clk) pause <= ~dip_pause;

`ifndef NOVIDEO
jtbiocom_video #(
    .OBJ_PAL      (2'b10),
    .PALETTE_PROM (1),
    .SCRWIN       (0),
    .AVATAR_MAX   (9)
) u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen8       ( cen8          ),
    .cen6       ( cen6          ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB        ),
    .V          ( V[7:0]        ),
    .H          ( H             ),
    .RnW        ( RnW           ),
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
    // SCROLL 1
    .scr1_cs    ( scr1_cs       ),
    .scr1_dout  ( scr1_dout     ),
    .scr1_addr  ( scr1_addr     ),
    .scr1_data  ( scr1_data     ),
    .scr1_busy  ( scr1_busy     ),
    .scr1_hpos  ( scr1_hpos     ),
    .scr1_vpos  ( scr1_vpos     ),
    .scr1_ok    ( scr1_ok       ),
    // SCROLL 2
    .scr2_cs    ( scr2_cs       ),
    .scr2_dout  ( scr2_dout     ),
    .scr2_addr  ( scr2_addr     ),
    .scr2_data  ( scr2_data     ),
    .scr2_busy  ( scr2_busy     ),
    .scr2_hpos  ( scr2_hpos     ),
    .scr2_vpos  ( scr2_vpos     ),
    .scr2_ok    ( scr2_ok       ),
    // OBJ
    .HINIT      ( HINIT         ),
    .obj_AB     ( obj_AB        ),
    .oram_dout  ( oram_dout[11:0] ),
    .obj_addr   ( obj_addr[16:1]),
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
    .prom_prio_we ( prom_prio_we  ),
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
assign red       = 5'h0;
assign green     = 5'h0;
assign blue      = 5'h0;
assign obj_addr  = 0;
assign scr1_addr = 0;
assign scr2_addr = 0;
assign char_addr = 0;
`endif

wire [ 7:0] scr_nc; // no connect
// // CPU addresses memory by words, not bytes:
wire [17:0] main_rom_addr = { main_addr,1'b0 };

// Scroll data: Z, Y, X
jtgng_rom #(
    .main_dw    ( 16              ),
    .main_aw    ( 18              ),
    .char_aw    ( 13              ),
    .obj_aw     ( 17              ), // AD11 is disconnected in schematics
    .scr1_aw    ( 17              ),
    .scr2_aw    ( 15              ),
    .obj_dw     ( 32              ),
    .snd_offset ( 22'h4_0000 >> 1 ),
    .char_offset( 22'h4_8000 >> 1 ),
    .scr1_offset( 22'h5_0000      ), // SCR and OBJ are not shifted
    .scr2_offset( 22'h7_0000      ),
    .obj_offset ( 22'hC_0000      )
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
    .scr1_ok     ( scr1_ok       ),
    .scr2_ok     ( scr2_ok       ),
    .char_ok     ( char_ok       ),
    .obj_ok      ( obj_ok        ),

    .char_addr   ( char_addr     ),
    .main_addr   ( main_rom_addr ),
    .snd_addr    ( snd_addr      ),
    .obj_addr    ( obj_addr      ),
    .scr1_addr   ( scr1_addr     ),
    .scr2_addr   ( scr2_addr     ),
    .map1_addr   ( 14'd0         ),
    .map2_addr   ( 14'd0         ),

    .char_dout   ( char_data     ),
    .main_dout   ( main_data     ),
    .snd_dout    ( snd_data      ),
    .obj_dout    ( obj_data      ),
    .map1_dout   (               ),
    .map2_dout   (               ),
    .scr1_dout   ( scr1_data     ),
    .scr2_dout   ( scr2_data     ),

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