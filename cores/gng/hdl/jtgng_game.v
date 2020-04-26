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
    Date: 27-10-2017 */

`timescale 1ns/1ps

module jtgng_game(
    input           rst,
    input           clk,
    output          pxl2_cen,   // 12   MHz
    output          pxl_cen,    //  6   MHz
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
    output          dwnld_busy,
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
    output          prog_rd,
    // DIP switches
    input   [31:0]  status,     // only bits 31:16 are looked at
    input   [31:0]  dipsw,
    input           dip_pause,
    inout           dip_flip,
    input           dip_test,
    input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB   
    // Sound output
    output  signed [15:0] snd,
    output          sample,
    input           enable_psg,
    input           enable_fm,
    // Debug
    input   [ 3:0]  gfx_en
);

// These signals are used by games which need
// to read back from SDRAM during the ROM download process
assign prog_rd    = 1'b0;
assign dwnld_busy = downloading;

parameter CLK_SPEED=48;

wire [8:0] V;
wire [8:0] H;
wire HINIT;

wire [12:0] cpu_AB;
wire snd_cs;
wire char_cs;
wire flip;
wire [7:0] cpu_dout, char_dout, scr_dout;
wire rd, cpu_cen;
wire char_busy, scr_busy;

// ROM data
wire [15:0] char_data;
wire [23:0] scr_data;
wire [15:0] obj_data;
wire [ 7:0] main_data;
wire [ 7:0] snd_data;
// ROM address
wire [16:0] main_addr;
wire [14:0] snd_addr;
wire [12:0] char_addr;
wire [14:0] scr_addr;
wire [15:0] obj_addr;
wire [ 7:0] dipsw_a, dipsw_b;

wire rom_ready;
wire main_ok, snd_ok;
wire cen12, cen6, cen6b, cen3, cen1p5, cen1p5b;

assign pxl2_cen = cen12;
assign pxl_cen  = cen6;

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

jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen12  ( cen12     ),
    .cen6   ( cen6      ),
    .cen6b  ( cen6b     ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    ),
    .cen1p5b( cen1p5b   )
);

assign {dipsw_b, dipsw_a} = dipsw[15:0];
assign dip_flip = dipsw_a[7];

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

wire blue_cs;
wire redgreen_cs;

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
wire sres_b;
wire [7:0] snd_latch;

wire scr_cs;
wire [8:0] scr_hpos, scr_vpos;

jtgng_prom_we u_prom_we(
    .clk         ( clk           ),
    .downloading ( downloading   ),

    .ioctl_wr    ( ioctl_wr      ),
    .ioctl_addr  ( ioctl_addr    ),
    .ioctl_data  ( ioctl_data    ),

    .prog_data   ( prog_data     ),
    .prog_mask   ( prog_mask     ),
    .prog_addr   ( prog_addr     ),
    .prog_we     ( prog_we       ),
    .sdram_ack   ( sdram_ack     )
);

`ifndef NOMAIN
jtgng_main u_main(
    .rst        ( rst_game      ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen_E      ( cen1p5        ),
    .cen_Q      ( cen1p5b       ),
    .cpu_cen    ( cpu_cen       ),
    // Timing
    .flip       ( flip          ),
    .LVBL       ( LVBL          ),

    // sound
    .sres_b     ( sres_b        ),
    .snd_latch  ( snd_latch     ),
    // CHAR
    .char_dout  ( char_dout     ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    // SCROLL
    .scr_dout   ( scr_dout      ),
    .scr_cs     ( scr_cs        ),
    .scr_busy   ( scr_busy      ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    //.scr_holdn  ( gfx_en[2]     ), // hold scroll latches
    .scr_holdn  ( 1'b1          ), // hold scroll latches
    // OBJ - bus sharing
    .obj_AB     ( obj_AB        ),
    .cpu_AB     ( cpu_AB        ),
    .ram_dout   ( main_ram      ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .bus_req    ( bus_req       ),
    .bus_ack    ( bus_ack       ),
    // Palette RAM
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),
    // ROM
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .start_button( start_button ),
    .coin_input ( coin_input    ),
    .joystick1  ( joystick1[5:0]),
    .joystick2  ( joystick2[5:0]),

    .RnW        ( RnW           ),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       )
);
`else
assign main_addr   = 17'd0;
assign char_cs     = 1'b0;
assign scr_cs      = 1'b0;
assign blue_cs     = 1'b0;
assign redgreen_cs = 1'b0;
assign bus_ack     = 1'b0;
assign flip        = 1'b0;
assign RnW         = 1'b1;
assign scr_hpos    = 9'd0;
assign scr_vpos    = 9'd0;
assign cpu_cen     = cen3;
`endif

`ifndef NOSOUND
reg [7:0] psg_gain;
always @(posedge clk) begin
    case( dip_fxlevel )
        2'd0: psg_gain <= 8'h1F;
        2'd1: psg_gain <= 8'h3F;
        2'd2: psg_gain <= 8'h7F;
        2'd3: psg_gain <= 8'hFF;
    endcase // dip_fxlevel
end

jtgng_sound #(.FM_GAIN(8'h38)) u_sound (
    .rst            ( rst_game   ),
    .clk            ( clk        ),
    .cen3           ( cen3       ),
    .cen1p5         ( cen1p5     ),
    // Interface with main CPU
    .sres_b         ( sres_b     ),
    .snd_latch      ( snd_latch  ),
    .snd_int        ( V[5]       ),
    // sound control
    .enable_psg     ( enable_psg ),
    .enable_fm      ( enable_fm  ),
    .psg_gain       ( psg_gain   ),
    // ROM
    .rom_addr       ( snd_addr   ),
    .rom_data       ( snd_data   ),
    .rom_cs         ( snd_cs     ),
    .rom_ok         ( snd_ok     ),
    // sound output
    .ym_snd         ( snd        ),
    .sample         ( sample     )
);
`else
assign snd_addr = 15'd0;
assign sample   = 1'b0;
assign snd_cs   = 1'b0;
assign snd      = 16'b0;
`endif

wire char_ok, scr1_ok, scr2_ok, obj_ok;
wire scr_ok = scr1_ok & scr2_ok;

jtgng_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen12      ( cen12         ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB[10:0]  ),
    .V          ( V[7:0]        ),
    .H          ( H             ),
    .RnW        ( RnW           ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    .pause      ( !dip_pause    ),
    // CHAR
    .char_cs    ( char_cs       ),
    .char_dout  ( char_dout     ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_busy  ( char_busy     ),
    .char_ok    ( char_ok       ),
    // SCROLL - ROM
    .scr_cs     ( scr_cs        ),
    .scr_dout   ( scr_dout      ),
    .scr_addr   ( scr_addr      ),
    .scr_data   ( scr_data      ),
    .scr_busy   ( scr_busy      ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    .scr_ok     ( scr_ok        ),
    // OBJ
    .HINIT      ( HINIT         ),
    .obj_AB     ( obj_AB        ),
    .main_ram   ( main_ram      ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_ok     ( obj_ok        ),
    .OKOUT      ( OKOUT         ),
    .bus_req    ( bus_req       ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    // Color Mix
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .LHBL_obj   ( LHBL_obj      ),
    .LVBL_obj   ( LVBL_obj      ),
    .LHBL_dly   ( LHBL_dly      ),
    .LVBL_dly   ( LVBL_dly      ),
    .gfx_en     ( gfx_en        ),
    // Palette RAM
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

wire [7:0] scr_nc; // no connect

// Scroll data: Z, Y, X
jtframe_rom #(
    .SLOT0_AW    ( 13              ), // Char
    .SLOT0_DW    ( 16              ),
    .SLOT0_OFFSET( 22'h1_4000 >> 1 ),

    .SLOT1_AW    ( 15              ), // Scroll bytes 0-1
    .SLOT1_DW    ( 16              ),
    .SLOT1_OFFSET( 22'h2_0000 >> 1 ),

    .SLOT2_AW    ( 15              ), // Scroll byte 2
    .SLOT2_DW    ( 16              ),
    .SLOT2_OFFSET( (22'h2_0000 >> 1) + 22'h0_8000 ),

    .SLOT6_AW    ( 15              ), // Sound
    .SLOT6_DW    (  8              ),
    .SLOT6_OFFSET( 22'h1_8000 >> 1 ),

    .SLOT7_AW    ( 17              ),
    .SLOT7_DW    (  8              ),
    .SLOT7_OFFSET(  0              ), // Main

    .SLOT8_AW    ( 16              ), // objects
    .SLOT8_DW    ( 16              ),
    .SLOT8_OFFSET( 22'h4_0000 >> 1 )
) u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),
    .vblank      ( ~LVBL         ),

    .slot0_cs    ( LVBL          ),
    .slot1_cs    ( LVBL          ),
    .slot2_cs    ( LVBL          ), 
    .slot3_cs    ( 1'b0          ), // unused
    .slot4_cs    ( 1'b0          ), // unused
    .slot5_cs    ( 1'b0          ), // unused
    .slot6_cs    ( snd_cs        ),
    .slot7_cs    ( main_cs       ),
    .slot8_cs    ( 1'b1          ),

    .slot0_ok    ( char_ok       ),
    .slot1_ok    ( scr1_ok       ),
    .slot2_ok    ( scr2_ok       ),
    .slot6_ok    ( snd_ok        ),
    .slot7_ok    ( main_ok       ),
    .slot8_ok    ( obj_ok        ),

    .slot0_addr  ( char_addr     ),
    .slot1_addr  ( scr_addr      ),
    .slot2_addr  ( scr_addr      ),
    .slot6_addr  ( snd_addr      ),
    .slot7_addr  ( main_addr     ),
    .slot8_addr  ( obj_addr      ),

    .slot0_dout  ( char_data     ),
    .slot1_dout  ( scr_data[15:0]),
    .slot2_dout  ( { scr_nc, scr_data[23:16]       } ),
    .slot6_dout  ( snd_data      ),
    .slot7_dout  ( main_data     ),
    .slot8_dout  ( obj_data      ),

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

endmodule // jtgng