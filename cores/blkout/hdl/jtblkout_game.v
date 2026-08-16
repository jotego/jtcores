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

    Author: Andrea Bogazzi. email: andreabogazzi79@gmail.com
    Version: 1.0
    Date: 31-7-2026
*/

module jtblkout_game(
    `include "jtframe_game_ports.inc"
);

wire [ 1:0] main_dsn;
wire        main_rnw;
wire        frontcol_cs;
wire [ 7:0] snd_latch, st_video;
wire        snd_irq;

assign dip_flip   = 0;
assign debug_view = st_video;

wire blockout, blockoutj;

jtblkout_header u_header(
    .clk        ( clk            ),
    .header     ( header         ),
    .prog_we    ( prog_we        ),
    .blockout   ( blockout       ),
    .blockoutj  ( blockoutj      ),
    .prog_addr  ( prog_addr[2:0] ),
    .prog_data  ( prog_data      )
);

jtblkout_main u_main(
    .rst        ( rst24     ),
    .clk        ( clk24     ),
    .LVBL       ( LVBL      ),

    .main_addr  ( main_addr ),
    .main_dout  ( cpu_dout  ),
    .main_dsn   ( main_dsn  ),
    .main_rnw   ( main_rnw  ),
    .rom_cs     ( main_cs   ),
    .work_we    ( work_we   ),
    .work2_we   ( work2_we  ),
    .work3_sel  ( work3_sel ),
    .work3_addr ( work3_addr),
    .work3_dsn  ( work3_dsn ),
    .work3_we   ( work3_we  ),
    .fvram_we   ( fvram_we  ),
    .pal_we     ( pal_we    ),
    .fbram_sel  ( fbram_sel ),
    .fbram_addr ( fbram_addr),
    .fbram_dsn  ( fbram_dsn ),
    .fbram_we   ( fbram_we  ),
    .frontcol_cs( frontcol_cs ),

    .blockoutj  ( blockoutj ),
    .work_dout  ( work_dout ),
    .work2_dout ( work2_dout),
    .work3_dout ( work3_data),
    .work3_ok   ( work3_ok  ),
    .fvram_dout ( fvram_dout),
    .pal_dout   ( pal_dout  ),
    .fb_dout    ( fbram_data),
    .fb_ok      ( fbram_ok  ),
    .rom_data   ( main_data ),
    .rom_ok     ( main_ok   ),

    .snd_irq    ( snd_irq   ),
    .snd_latch  ( snd_latch ),

    .joystick1  ( joystick1 ),
    .joystick2  ( joystick2 ),
    .cab_1p     ( cab_1p    ),
    .coin       ( coin      ),
    .service    ( service   ),
    .tilt       ( tilt      ),
    .dip_pause  ( dip_pause ),
    .dipsw_a    ( dipsw[ 7:0] ),
    .dipsw_b    ( dipsw[15:8] )
);

jtblkout_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .HS         ( HS        ),
    .VS         ( VS        ),

    .frontcol_cs( frontcol_cs ),
    .main_addr  ( main_addr[1] ),
    .cpu_dout   ( cpu_dout  ),
    .main_dsn   ( main_dsn  ),
    .main_rnw   ( main_rnw  ),

    .fbrd_addr  ( fbrd_addr ),
    .fbrd_cs    ( fbrd_cs   ),
    .fbrd_data  ( fbrd_data ),
    .fbrd_ok    ( fbrd_ok   ),

    .palrd_addr ( palrd_addr),
    .pal_data   ( pal_data  ),

    .fvrd_addr  ( fvrd_addr ),
    .fvram_data ( fvram_data),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),

    .ioctl_addr ( ioctl_addr),
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_video  )
);

jtdd2_sound u_sound(
    .rst        ( rst24        ),
    .clk        ( clk24        ),
    .H8         ( 1'b0         ),
    .cen_snd    ( cen_snd      ),
    .cen_fm     ( cen_fm       ),
    .cen_fm2    ( cen_fm2      ),
    .cen_oki    ( cen_oki      ),

    .snd_irq    ( snd_irq      ),
    .snd_latch  ( snd_latch    ),

    .rom_addr   ( snd_addr     ),
    .rom_cs     ( snd_cs       ),
    .rom_data   ( snd_data     ),
    .rom_ok     ( snd_ok       ),

    .adpcm_addr ( pcm_addr     ),
    .adpcm_cs   ( pcm_cs       ),
    .adpcm_data ( pcm_data     ),
    .adpcm_ok   ( pcm_ok       ),

    .fm_l       ( fm_l         ),
    .fm_r       ( fm_r         ),
    .pcm        ( pcm          )
);

endmodule
