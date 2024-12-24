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
    Date: 27-10-2017 */


module jtgng_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [ 8:0] V, H;
wire [ 7:0] cpu_dout, char_dout, scr_dout, st_snd;

wire [12:0] cpu_AB;
wire        snd_cs, char_cs, flip, HINIT;
wire        char_busy, scr_busy, block_flash, preLHBL, preLVBL;

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

wire        main_ok, snd_ok;
wire        cen6, cen3, cen1p5, cen1p5b;
wire        LHBL_obj, LVBL_obj;

wire        RnW, blue_cs, redgreen_cs, bus_ack, bus_req;
wire [15:0] sdram_din;
wire [12:0] wr_row;
wire [ 8:0] wr_col;
wire        main_cs;
// OBJ
wire [ 8:0] obj_AB;
wire        OKOUT, blcnten;
wire [ 7:0] main_ram;
// sound
wire        sres_b;
wire [ 7:0] snd_latch;

wire        scr_cs;
wire [ 8:0] scr_hpos, scr_vpos;

// These signals are used by games which need
// to read back from SDRAM during the ROM download process
assign prog_rd    = 1'b0;
assign dwnld_busy = ioctl_rom;

assign block_flash = status[13];
assign dip_flip    = flip;
assign debug_view  = debug_bus[7] ? st_snd :
            { 3'd0, ~sres_b, 2'd0, blcnten, OKOUT };

jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen12  (           ),
    .cen6   ( cen6      ),
    .cen6b  (           ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    ),
    .cen1p5b( cen1p5b   ),
    // unused
    .cen8   (           ),
    .cen4   (           ),
    .cen12b (           ),
    .cen16  (           ),
    .cen3q  (           ),
    .cen3b  (           ),
    .cen3qb (           ),
    .cen4_12(           ),
    .cen16b (           )
);

jtgng_timer u_timer(
    .clk       ( clk      ),
    .cen6      ( pxl_cen  ),
    .V         ( V        ),
    .H         ( H        ),
    .Hinit     ( HINIT    ),
    .LHBL      ( preLHBL  ),
    .LVBL      ( preLVBL  ),
    .LHBL_obj  ( LHBL_obj ),
    .LVBL_obj  ( LVBL_obj ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          )
);

jtgng_prom_we u_prom_we(
    .clk         ( clk           ),
    .ioctl_rom   ( ioctl_rom     ),

    .ioctl_wr    ( ioctl_wr      ),
    .ioctl_addr  (ioctl_addr[21:0]),
    .ioctl_dout  ( ioctl_dout    ),

    .prog_data   ( prog_data     ),
    .prog_mask   ( prog_mask     ),
    .prog_addr   ( prog_addr     ),
    .prog_we     ( prog_we       ),
    .sdram_ack   ( sdram_ack     )
);

`ifndef NOMAIN
jtgng_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk_dma    ( clk           ),
    .cen6       ( cen6          ),
    // Timing
    .flip       ( flip          ),
    .LVBL       ( LVBL          ),
    .block_flash( block_flash   ),

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
    .dma_dout   ( main_ram      ),
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
    .cab_1p     ( cab_1p        ),
    .coin       ( coin          ),
    .service    ( service       ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),

    .RnW        ( RnW           ),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw[ 7:0]   ),
    .dipsw_b    ( dipsw[15:8]   )
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
`endif

`ifndef NOSOUND
jtgng_sound #(.PSG_ATT(1)) u_sound (
    .rst            ( rst        ),
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
    .psg_level      ( dip_fxlevel),
    // ROM
    .rom_addr       ( snd_addr   ),
    .rom_data       ( snd_data   ),
    .rom_cs         ( snd_cs     ),
    .rom_ok         ( snd_ok     ),
    // sound output
    .ym_snd         ( snd        ),
    .sample         ( sample     ),
    .peak           ( game_led   ),
    .debug_bus      ( debug_bus  ),
    .debug_view     ( st_snd     ),
    // unused
    .snd2_latch     (            )
);
`else
    assign snd_addr   = 0;
    assign sample     = 0;
    assign game_led   = 0;
    assign snd_cs     = 0;
    assign snd        = 0;
    assign st_snd     = 0;
`endif

wire char_ok, scr1_ok, scr2_ok, obj_ok;
wire scr_ok = scr1_ok & scr2_ok;

/* verilator tracing_off */
jtgng_video #(.GNGPAL(1)) u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen12      ( pxl2_cen      ),
    .cen6       ( pxl_cen       ),
    .cpu_AB     ( cpu_AB[10:0]  ),
    .V          ( V[7:0]        ),
    .H          ( H             ),
    .RnW        ( RnW           ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
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
    .preLHBL    ( preLHBL       ),
    .preLVBL    ( preLVBL       ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .LHBL_obj   ( LHBL_obj      ),
    .LVBL_obj   ( LVBL_obj      ),
    .gfx_en     ( gfx_en        ),
    // Palette RAM
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),
    // PROM ports used to assign a non-zero starting value to the palette RAM
    .prog_addr  ( prog_addr[7:0]),
    .prom_red_we( prog_we       ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    // Unused
    .prom_green_we( 1'd0 ),
    .prom_blue_we ( 1'd0 ),
    .prom_din     ( 4'd0 )
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
    .slot3_ok    (               ),
    .slot4_ok    (               ),
    .slot5_ok    (               ),
    .slot6_ok    ( snd_ok        ),
    .slot7_ok    ( main_ok       ),
    .slot8_ok    ( obj_ok        ),

    .slot0_addr  ( char_addr     ),
    .slot1_addr  ( scr_addr      ),
    .slot2_addr  ( scr_addr      ),
    .slot3_addr  (               ),
    .slot4_addr  (               ),
    .slot5_addr  (               ),
    .slot6_addr  ( snd_addr      ),
    .slot7_addr  ( main_addr     ),
    .slot8_addr  ( obj_addr      ),

    .slot0_dout  ( char_data     ),
    .slot1_dout  ( scr_data[15:0]),
    .slot2_dout  ( { scr_nc, scr_data[23:16]       } ),
    .slot3_dout  (               ),
    .slot4_dout  (               ),
    .slot5_dout  (               ),
    .slot6_dout  ( snd_data      ),
    .slot7_dout  ( main_data     ),
    .slot8_dout  ( obj_data      ),

    // SDRAM interface
    .sdram_rd    ( sdram_req     ),
    .sdram_ack   ( sdram_ack     ),
    .data_rdy    ( data_rdy      ),
    .data_dst    ( data_dst      ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     )
);

endmodule // jtgng
