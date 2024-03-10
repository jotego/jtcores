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

wire [15:0] oram_dout, pal_dout;
wire [ 1:0] main_dsn;
wire        sub_cs, obj_cs, ram_cs, vram_cs, main_rnw;
wire        scr_cs, pal_cs, sdakn, odakn;
wire [ 2:0] obj_pal;

wire        flip;
wire        sn_rd, sn_we, snd_rstn, mintn;
wire [ 3:0] sn_dout;

assign dip_flip = flip;
assign ram_addr = ram_cs ? {4'd0, main_addr[13:1] } : { 2'b10, main_addr[15:1] };
assign ram_we   = xram_cs & ~main_rnw;
assign xram_cs  = ram_cs | vram_cs;
assign ram_dsn  = main_dsn;

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
    .dipsw_a    (dipsw[ 7:0]),
    .dipsw_b    (dipsw[15:8])
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

    .fm_l       ( fm_l          ),
    .fm_r       ( fm_r          ),
    .pcm        ( pcm           )
);
`else
assign snd_cs = 0;
assign snd_addr = 0;
assign pcm_addr = 0;
assign pcm_cs = 0;
assign snd    = 0;
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

endmodule
