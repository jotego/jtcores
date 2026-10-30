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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
            Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-8-2026 */

module jttaitox_game(
    `include "jtframe_game_ports.inc"
);

wire [23:1] cpu_addr;
wire [15:0] vid_dout;
wire [ 1:0] cpu_dsn;
wire [ 7:0] cchip_dout, st_video;
wire [ 3:0] syt_dout;
wire        cpu_rnw, cpu_cen, flip,
            oram_cs, vdcm_cs, syt_cs, cchip_cs, syt_rst, cchip_rst;

wire        cchip, ym2151;
`ifndef RAM_IN_SDRAM
wire        ram_cs, ram_ok = 1'b1;   // work RAM is in BRAM: never busy
`endif

assign debug_view = st_video;
assign dip_flip   = ~flip;

jttaitox_header u_header(
    .clk        ( clk           ),
    .header     ( header        ),
    .prog_addr  ( prog_addr[3:0]),
    .prog_data  ( prog_data     ),
    .prog_we    ( prog_we       ),

    .cchip      ( cchip         ),
    .ym2151     ( ym2151        )
);

jttaitox_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .LVBL       ( LVBL          ),

    .cchip      ( cchip         ),

    .cpu_cen    ( cpu_cen       ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_dout   ( cpu_dout      ),
    .cpu_rnw    ( cpu_rnw       ),
    .cpu_dsn    ( cpu_dsn       ),

    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),

    .ram_cs     ( ram_cs        ),
    .ram_ok     ( ram_ok        ),
    .ram_data   ( ram_data      ),
    .ram_we     ( ram_we        ),
`ifdef RAM_IN_SDRAM
    .ram_dsn    ( ram_dsn       ),
`endif
    .pal_we     ( pal_we        ),
    .pal_dout   ( pal_dout      ),

    .oram_cs    ( oram_cs       ),
    .vdcm_cs    ( vdcm_cs       ),
    .vid_dout   ( vid_dout      ),

    .syt_cs     ( syt_cs        ),
    .syt_dout   ( syt_dout      ),
    .syt_rst    ( syt_rst       ),

    .cchip_cs   ( cchip_cs      ),
    .cchip_dout ( cchip_dout    ),
    .cchip_rst  ( cchip_rst     ),

    .joystick1  ( joystick1[6:0]),
    .joystick2  ( joystick2[6:0]),
    .start_button( cab_1p[1:0]       ),
    .coin       ( coin[1:0]     ),
    .service    ( service       ),
    .tilt       ( tilt          ),
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw[ 7:0]   ),
    .dipsw_b    ( dipsw[15:8]   )
);

jttaitox_cchip u_cchip(
    .rst        ( cchip_rst     ),
    .clk        ( clk           ),
    .cen        ( cen8          ),
    .cs         ( cchip_cs      ),
    .addr       ( cpu_addr[11:1]),
    .din        ( cpu_dout[7:0] ),
    .dout       ( cchip_dout    ),
    .rnw        ( cpu_rnw       ),
    .LVBL       ( LVBL          ),

    .joystick1  ( joystick1[6:0]),
    .joystick2  ( joystick2[6:0]),
    .start_button( cab_1p[1:0]       ),
    .coin       ( coin[1:0]     ),
    .service    ( service       ),
    .tilt       ( tilt          ),
    .counters   (               ),

`ifdef RAM_IN_SDRAM
    .ccrom_addr ( ccrom_addr    ),
    .ccrom_cs   ( ccrom_cs      ),
    .ccrom_data ( ccrom_data    ),
    .ccrom_ok   ( ccrom_ok      )
`else
    .cchip_mask_addr ( cchip_mask_addr  ),
    .cchip_mask_data ( cchip_mask_data  ),
    .cchip_eprom_addr( cchip_eprom_addr ),
    .cchip_eprom_data( cchip_eprom_data )
`endif
);

jttaitox_snd u_snd(
    .rst        ( syt_rst       ),
    .clk        ( clk           ),
    .cen8       ( cen8          ),
    .fm_cen     ( fm_cen        ),
    .fm_cenp1   ( fm_cenp1      ),
    .ym2151     ( ym2151        ),
    .snd_cen    ( snd_cen       ),

    .main_cen   ( cpu_cen       ),
    .syt_cs     ( syt_cs        ),
    .main_addr  ( cpu_addr[1]   ),
    .main_dout  ( cpu_dout[3:0] ),
    .main_din   ( syt_dout      ),
    .main_rnw   ( cpu_rnw       ),

    .rom_addr   ( snd_addr      ),
    .rom_cs     ( snd_cs        ),
    .rom_ok     ( snd_ok        ),
    .rom_data   ( snd_data      ),

    .adpcma_addr( adpcma_addr   ),
    .adpcma_cs  ( adpcma_cs     ),
    .adpcma_data( adpcma_data   ),
    .adpcmb_addr( adpcmb_addr   ),
    .adpcmb_cs  ( adpcmb_cs     ),
    .adpcmb_data( adpcmb_data   ),

    .fm_l       ( fm_l          ),
    .fm_r       ( fm_r          ),
    .sup_l      ( sup_l         ),
    .sup_r      ( sup_r         ),
    .psg        ( psg           )
);

jttaitox_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .pxl2_cen   ( pxl2_cen      ),

    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .flip       ( flip          ),

    .cpu_rnw    ( cpu_rnw       ),
    .cpu_dsn    ( cpu_dsn       ),
    .cpu_addr   ( cpu_addr[13:1]),
    .cpu_dout   ( cpu_dout      ),
    .oram_cs    ( oram_cs       ),
    .vdcm_cs    ( vdcm_cs       ),
    .vid_dout   ( vid_dout      ),

    .col_addr   ( col_addr      ),
    .col_data   ( col_data      ),
    .yram_dout  ( yram_dout     ),
    .yram_we    ( yram_we       ),

    .dma_addr   ( dma_addr      ),
    .dma_din    ( dma_din       ),
    .dma_we     ( dma_we        ),
    .dma_dout   ( dma_dout      ),
    .code_dout  ( code_dout     ),
    .code_addr  ( code_addr     ),

    .pal_addr   ( palrd_addr    ),
    .pal_data   ( pal_data      ),

    .scr_addr   ( scr_addr      ),
    .scr_data   ( scr_data      ),
    .scr_ok     ( scr_ok        ),
    .scr_cs     ( scr_cs        ),

    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_ok     ( obj_ok        ),
    .obj_cs     ( obj_cs        ),

    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),

    .ioctl_addr ( ioctl_addr[1:0] ),
    .ioctl_din  ( ioctl_din     ),
    .gfx_en     ( gfx_en        ),
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_video      )
);

endmodule
