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
    Date: 2-4-2022 */

module jtrastan_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [18:1] main_addr;
wire [15:0] main_dout, main_data, ram_data, oram_dout, pal_dout;
wire [ 1:0] main_dsn;
wire        main_cs, obj_cs, ram_cs, vram_cs, main_rnw,
            ram_ok, main_ok;
wire        scr_cs, pal_cs, sdakn, odakn;
wire [ 2:0] obj_pal;

wire [14:0] scr0ram_addr, scr1ram_addr;
wire [31:0] scr0ram_data, scr1ram_data, orom_data;
wire        scr0ram_ok, scr1ram_ok, orom_ok;
wire        scr0ram_cs, scr1ram_cs, orom_cs;

wire [18:0] scr0rom_addr, scr1rom_addr, orom_addr;
wire [31:0] scr0rom_data, scr1rom_data;
wire        scr0rom_ok, scr1rom_ok,
            scr0rom_cs, scr1rom_cs;
wire [15:0] snd_addr, pcm_addr;
wire [ 7:0] snd_data, pcm_data, dipsw_b, dipsw_a;
wire        snd_cs, pcm_cs, snd_ok, pcm_ok, sub_cs;

wire        flip;
wire        sn_rd, sn_we, snd_rstn, mintn;
wire [ 3:0] sn_dout;

assign      dip_flip = flip;
assign      { dipsw_b, dipsw_a } = dipsw[15:0];
assign      ba1_dsn=3;
assign      ba2_dsn=3;
assign      ba3_dsn=3;
assign      ba1_din=0;
assign      ba2_din=0;
assign      ba3_din=0;
assign   ba_wr[3:1]=0;

`ifndef NOMAIN
jtrastan_main u_main(
    .rst        ( rst       ),
    .clk        ( clk       ), // 48 MHz
    .LVBL       ( LVBL      ),

    .main_addr  ( main_addr ),
    .main_dout  ( main_dout ),
    .main_dsn   ( main_dsn  ),
    .main_rnw   ( main_rnw  ),
    .rom_cs     ( main_cs   ),
    .ram_cs     ( ram_cs    ),
    .vram_cs    ( vram_cs   ),
    .obj_cs     ( obj_cs    ),
    .pal_cs     ( pal_cs    ),
    .scr_cs     ( scr_cs    ),

    .obj_pal    ( obj_pal   ),
    .oram_dout  ( oram_dout ),
    .pal_dout   ( pal_dout  ),
    .ram_dout   ( ram_data  ),
    .ram_ok     ( ram_ok    ),
    .rom_data   ( main_data ),
    .rom_ok     ( main_ok   ),

    .odakn      ( odakn     ),
    .sdakn      ( sdakn     ),

    // Sound interface
    .sn_dout    ( sn_dout   ),
    .sn_rd      ( sn_rd     ),
    .sn_we      ( sn_we     ),

    // test board interface
    .sub_cs     ( sub_cs    ),
    .snd_rstn   ( snd_rstn  ),
    .mintn      ( mintn     ),

    .joystick1  ( joystick1 ),
    .joystick2  ( joystick2 ),
    .cab_1p     ( cab_1p    ),
    .coin       ( coin      ),
    .tilt       ( tilt      ),
    .service    ( service   ),

    .dip_test   ( dip_test  ),
    .dip_pause  ( dip_pause ),
    .dipsw_a    ( dipsw_a   ),
    .dipsw_b    ( dipsw_b   )
);
`else
assign main_addr = 0;
assign main_dout = 0;
assign main_cs   = 0;
assign ram_cs    = 0;
assign vram_cs   = 0;
assign obj_cs    = 0;
assign main_rnw  = 1;
assign main_dsn  = 3;
assign scr_cs    = 0;
assign pal_cs    = 0;
assign sn_rd     = 0;
assign sn_we     = 0;
assign obj_pal   = 0;
`endif

`ifndef NOSOUND
jtrastan_snd u_sound(
    .rst        ( rst24         ),
    .clk        ( clk24         ), // 24 MHz

    // From main CPU
    .rst48      ( rst           ),
    .clk48      ( clk           ),
    .main_addr  (main_addr[1]   ),
    .main_dout  (main_dout[3:0] ),
    .main_din   ( sn_dout       ),
    .main_rnw   ( main_rnw      ),
    .sn_we      ( sn_we         ),
    .sn_rd      ( sn_rd         ),

    .rom_addr   ( snd_addr      ),
    .rom_cs     ( snd_cs        ),
    .rom_ok     ( snd_ok        ),
    .rom_data   ( snd_data      ),

    .pcm_addr   ( pcm_addr      ),
    .pcm_cs     ( pcm_cs        ),
    .pcm_ok     ( pcm_ok        ),
    .pcm_data   ( pcm_data      ),

    .snd        ( snd           ),
    .sample     ( sample        ),
    .peak       ( game_led      )
);
`else
assign snd_cs = 0;
assign snd_addr = 0;
assign pcm_addr = 0;
assign pcm_cs = 0;
assign snd    = 0;
assign sample = 0;
assign game_led=0;
assign sn_dout =0;
`endif

jtrastan_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    .HS         ( HS        ),
    .VS         ( VS        ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .flip       ( flip      ),
    .obj_pal    ( obj_pal   ),

    .main_addr  ( main_addr ),
    .main_dout  ( main_dout ),
    .oram_dout  ( oram_dout ),
    .pal_dout   ( pal_dout  ),
    .main_dsn   ( main_dsn  ),
    .main_rnw   ( main_rnw  ),
    .scr_cs     ( scr_cs    ),
    .pal_cs     ( pal_cs    ),
    .obj_cs     ( obj_cs    ),
    .sdakn      ( sdakn     ),
    .odakn      ( odakn     ),

    .ram0_addr  ( scr0ram_addr ),
    .ram0_data  ( scr0ram_data ),
    .ram0_ok    ( scr0ram_ok   ),
    .ram0_cs    ( scr0ram_cs   ),

    .rom0_addr  ( scr0rom_addr ),
    .rom0_data  ( scr0rom_data ),
    .rom0_cs    ( scr0rom_cs   ),
    .rom0_ok    ( scr0rom_ok   ),

    .ram1_addr  ( scr1ram_addr ),
    .ram1_data  ( scr1ram_data ),
    .ram1_ok    ( scr1ram_ok   ),
    .ram1_cs    ( scr1ram_cs   ),

    .rom1_addr  ( scr1rom_addr ),
    .rom1_data  ( scr1rom_data ),
    .rom1_cs    ( scr1rom_cs   ),
    .rom1_ok    ( scr1rom_ok   ),

    .orom_addr  ( orom_addr    ),
    .orom_data  ( orom_data    ),
    .orom_cs    ( orom_cs      ),
    .orom_ok    ( orom_ok      ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),

    // Debug
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_addr ( ioctl_addr[10:0]),
    .ioctl_din  ( ioctl_din ),
    .debug_view ( debug_view)
);

jtrastan_sdram u_sdram(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .main_addr  ( main_addr ),
    .main_data  ( main_data ),
    .main_dsn   ( main_dsn  ),
    .main_dout  ( main_dout ),
    .main_cs    ( main_cs   ),
    .main_rnw   ( main_rnw  ),
    .ram_cs     ( ram_cs    ),
    .vram_cs    ( vram_cs   ),
    .ram_data   ( ram_data  ),
    .ram_ok     ( ram_ok    ),
    .main_ok    ( main_ok   ),

    // Sound
    .snd_addr   ( snd_addr      ),
    .snd_cs     ( snd_cs        ),
    .snd_ok     ( snd_ok        ),
    .snd_data   ( snd_data      ),

    .pcm_addr   ( pcm_addr      ),
    .pcm_cs     ( pcm_cs        ),
    .pcm_ok     ( pcm_ok        ),
    .pcm_data   ( pcm_data      ),

    // GFX ROMs
    .scr0rom_addr   ( scr0rom_addr  ),
    .scr0rom_data   ( scr0rom_data  ),
    .scr0rom_cs     ( scr0rom_cs    ),
    .scr0rom_ok     ( scr0rom_ok    ),

    .scr1rom_addr   ( scr1rom_addr  ),
    .scr1rom_data   ( scr1rom_data  ),
    .scr1rom_cs     ( scr1rom_cs    ),
    .scr1rom_ok     ( scr1rom_ok    ),
    .scr0ram_addr   ( scr0ram_addr  ),

    // VRAM
    .scr0ram_data   ( scr0ram_data  ),
    .scr0ram_cs     ( scr0ram_cs    ),
    .scr0ram_ok     ( scr0ram_ok    ),
    .scr1ram_addr   ( scr1ram_addr  ),

    .scr1ram_data   ( scr1ram_data  ),
    .scr1ram_cs     ( scr1ram_cs    ),
    .scr1ram_ok     ( scr1ram_ok    ),

    .orom_addr  ( orom_addr ),
    .orom_data  ( orom_data ),
    .orom_cs    ( orom_cs   ),
    .orom_ok    ( orom_ok   ),

    // SDRAM interface
    .ioctl_rom  ( ioctl_rom ),
    .dwnld_busy ( dwnld_busy),

    // Bank 0: allows R/W
    .ba0_addr   ( ba0_addr  ),
    .ba1_addr   ( ba1_addr  ),
    .ba2_addr   ( ba2_addr  ),
    .ba3_addr   ( ba3_addr  ),
    .ba0_din    ( ba0_din   ),
    .ba0_din_m  ( ba0_dsn   ),  // write mask
    .ba_rd      ( ba_rd     ),
    .ba_wr      ( ba_wr[0]  ),
    .ba_ack     ( ba_ack    ),
    .ba_dst     ( ba_dst    ),
    .ba_dok     ( ba_dok    ),
    .ba_rdy     ( ba_rdy    ),

    .data_read  ( data_read ),
    // ROM LOAD
    .ioctl_addr ( ioctl_addr),
    .ioctl_dout ( ioctl_dout),
    .ioctl_wr   ( ioctl_wr  ),
    .ioctl_ram  ( ioctl_ram ),
    .prog_addr  ( prog_addr ),
    .prog_data  ( prog_data ),
    .prog_mask  ( prog_mask ),
    .prog_ba    ( prog_ba   ),
    .prog_we    ( prog_we   ),
    .prog_rd    ( prog_rd   ),
    .prog_ack   ( prog_ack  ),
    .prog_dst   ( prog_dst  ),
    .prog_dok   ( prog_dok  ),
    .prog_rdy   ( prog_rdy  )
);

endmodule
