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
    Date: 30-4-2022 */

module jtvigil_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire        cpu_cen, fm_cen;
// video signals
wire        v1;

// SDRAM interface
wire        main_cs, scr1_cs, scr2_cs, obj_cs, pcm_cs, snd_cs;
wire [17:0] main_addr, scr2_addr, obj_addr;
wire [15:0] pcm_addr, snd_addr;
wire [16:0] scr1_addr;
wire [ 7:0] main_data, snd_data, pcm_data;
wire [31:0] scr1_data, scr2_data, obj_data;
wire        main_ok, scr1_ok, scr2_ok, obj_ok, pcm_ok, snd_ok;

// CPU interface
wire [ 7:0] main_dout, pal_dout, scr1_dout;
wire        main_rnw, latch_wr, pal_cs, oram_cs, scr1_ramcs;

// Scroll configuration
wire [ 8:0] scr1pos;
wire [10:0] scr2pos;
wire [ 2:0] scr2col;
wire        flip, scr2enb;

// Cabinet inputs
wire [ 7:0] dipsw_a, dipsw_b;


assign { dipsw_b, dipsw_a } = dipsw[15:0];
assign dip_flip             = ~flip;
assign ba_wr                = 0;
assign ba0_din              = 0;
assign ba0_dsn              = 3;
assign ba1_din              = 0;
assign ba1_dsn              = 3;
assign ba2_din              = 0;
assign ba2_dsn              = 3;
assign ba3_din              = 0;
assign ba3_dsn              = 3;
assign debug_view           = 0; // scr1pos[8:1]; //{ flip, 4'd0, scr2col};

jtframe_cen3p57 #(.CLK24(1)) u_cencpu(
    .clk        ( clk24     ),
    .cen_3p57   ( cpu_cen   ),
    .cen_1p78   ( fm_cen    )
);

jtvigil_main u_main(
    .rst         ( rst24      ),
    .clk         ( clk24      ),
    .cpu_cen     ( cpu_cen    ),
    // Video
    .LVBL        ( LVBL       ),
    // Sound communication
    .latch_wr    ( latch_wr   ),
    // Palette
    .pal_cs      ( pal_cs     ),
    .pal_dout    ( pal_dout   ),
    .scr_dout    ( scr1_dout  ),
    // Video circuitry
    .scr_cs      ( scr1_ramcs ),
    .scr1pos     ( scr1pos    ),
    .scr2pos     ( scr2pos    ),
    .scr2col     ( scr2col    ),
    .scr2enb     ( scr2enb    ),
    .obj_cs      ( oram_cs    ),

    // CPU bus
    .main_addr   ( main_addr  ),
    .cpu_dout    ( main_dout  ),
    .main_rnw    ( main_rnw   ),
    // cabinet I/O
    .joystick1   ( joystick1  ),
    .joystick2   ( joystick2  ),
    .cab_1p      ( cab_1p     ),
    .coin        (  coin      ),
    .service     ( service    ),
    // ROM access
    .rom_cs      ( main_cs    ),
    .rom_data    ( main_data  ),
    .rom_ok      ( main_ok    ),
    // DIP switches
    .flip        ( flip       ),
    .dip_pause   ( dip_pause  ),
    .dipsw_a     ( dipsw_a    ),
    .dipsw_b     ( dipsw_b    )
);

jtvigil_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk_cpu    ( clk24     ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),
    .v1         ( v1        ),

    // CPU interface
    .main_addr  ( main_addr[11:0] ),
    .main_dout  ( main_dout ),
    .main_rnw   ( main_rnw  ),
    // Scroll
    .scr1pos    ( scr1pos   ),
    .scr1_ramcs ( scr1_ramcs),
    .scr1_cs    ( scr1_cs   ),
    .scr1_ok    ( scr1_ok   ),
    .scr1_addr  ( scr1_addr ),
    .scr1_data  ( scr1_data ),
    .scr1_dout  ( scr1_dout ),

    .scr2pos    ( scr2pos   ),
    .scr2col    ( scr2col   ),
    .scr2_cs    ( scr2_cs   ),
    .scr2_ok    ( scr2_ok   ),
    .scr2_addr  ( scr2_addr ),
    .scr2_data  ( scr2_data ),
    .scr2enb    ( scr2enb   ),

    // Object
    .oram_cs    ( oram_cs   ),

    // Palette
    .pal_cs     ( pal_cs    ),
    .pal_dout   ( pal_dout  ),
    .flip       ( flip      ),

    // SDRAM interface

    .obj_ok     ( obj_ok    ),
    .obj_cs     ( obj_cs    ),
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),

    // Video signal
    .HS         ( HS        ),
    .VS         ( VS        ),
    .LVBL       ( LVBL      ),
    .LHBL       ( LHBL      ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus )
);

jtvigil_snd u_sound(
    .rst        ( rst24     ),
    .clk        ( clk24     ),
    .cpu_cen    ( cpu_cen   ),
    .fm_cen     ( fm_cen    ),
    .v1         ( v1        ),

    .enable_fm  ( enable_fm ),
    .enable_psg ( enable_psg),

    // From main CPU
    .main_dout  ( main_dout ),
    .latch_wr   ( latch_wr  ),

    // ROM
    .rom_addr   ( snd_addr  ),
    .rom_cs     ( snd_cs    ),
    .rom_data   ( snd_data  ),
    .rom_ok     ( snd_ok    ),

    // PCM ROM
    .pcm_addr   ( pcm_addr  ),
    .pcm_cs     ( pcm_cs    ),
    .pcm_data   ( pcm_data  ),
    .pcm_ok     ( pcm_ok    ),

    .snd        ( snd       ),
    .sample     ( sample    ),
    .peak       ( game_led  ),
    .debug_bus  ( debug_bus )
);

jtvigil_sdram u_sdram(
    .rst        ( rst       ),
    .clk        ( clk       ),

    // Main CPU
    .main_cs    ( main_cs   ),
    .main_addr  ( main_addr ),
    .main_data  ( main_data ),
    .main_ok    ( main_ok   ),

    // Sound CPU
    .snd_addr   ( snd_addr  ),
    .snd_cs     ( snd_cs    ),
    .snd_data   ( snd_data  ),
    .snd_ok     ( snd_ok    ),

    // PCM ROM
    .pcm_addr (pcm_addr ),
    .pcm_cs   (pcm_cs   ),
    .pcm_data (pcm_data ),
    .pcm_ok   (pcm_ok   ),

    // Scroll
    .scr1_cs    ( scr1_cs   ),
    .scr1_ok    ( scr1_ok   ),
    .scr1_addr  ( scr1_addr ),
    .scr1_data  ( scr1_data ),

    .scr2_cs    ( scr2_cs   ),
    .scr2_ok    ( scr2_ok   ),
    .scr2_addr  ( scr2_addr ),
    .scr2_data  ( scr2_data ),

    // Sprite interface
    .obj_ok     ( obj_ok    ),
    .obj_cs     ( obj_cs    ),
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),

    // Bank 0: allows R/W
    .ba0_addr    ( ba0_addr      ),
    .ba1_addr    ( ba1_addr      ),
    .ba2_addr    ( ba2_addr      ),
    .ba3_addr    ( ba3_addr      ),
    .ba_rd       ( ba_rd         ),
    .ba_ack      ( ba_ack        ),
    .ba_dst      ( ba_dst        ),
    .ba_dok      ( ba_dok        ),
    .ba_rdy      ( ba_rdy        ),

    .data_read   ( data_read     ),

    // ROM load
    .ioctl_rom   ( ioctl_rom     ),
    .dwnld_busy  ( dwnld_busy    ),

    .ioctl_addr  ( ioctl_addr    ),
    .ioctl_dout  ( ioctl_dout    ),
    .ioctl_wr    ( ioctl_wr      ),
    .prog_addr   ( prog_addr     ),
    .prog_data   ( prog_data     ),
    .prog_mask   ( prog_mask     ),
    .prog_ba     ( prog_ba       ),
    .prog_we     ( prog_we       ),
    .prog_rd     ( prog_rd       ),
    .prog_ack    ( prog_ack      ),
    .prog_rdy    ( prog_rdy      )
);

endmodule
