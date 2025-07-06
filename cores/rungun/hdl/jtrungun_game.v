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
    Date: 6-7-2025 */

module jtrungun_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [15:0] oram_dout=0;
wire disp, gvflip, ghflip, pri;

jtrungun_main u_main(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .LVBL           ( LVBL          ),

    .disp           ( disp          ),
    .pri            ( pri           ),
    .ghflip         ( ghflip        ),
    .gvflip         ( gvflip        ),


    .cpu_we         ( cpu_we        ),
    .cpu_dout       ( cpu_dout      ),
    .vdtac          ( vdtac         ),
    .tile_irqn      ( tile_irqn     ),

    .main_addr      ( main_addr     ),
    .rom_data       ( main_data     ),
    .rom_cs         ( main_cs       ),
    .rom_ok         ( main_ok       ),
    // RAM
    .ram_dsn        ( ram_dsn       ),
    .ram_dout       ( ram_data      ),
    .ram_cs         ( ram_cs        ),
    .ram_ok         ( ram_ok        ),
    // cabinet I/O
    .cab_1p         ( cab_1p        ),
    .coin           ( coin          ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .joystick3      ( joystick3     ),
    .joystick4      ( joystick4     ),
    .service        ( {4{service}}  ),

    .cpal_addr      ( cpal_addr     ),

    .cpal_we        ( cpal_we       ),
    .vmem_we        ( vmem_we       ),

    .vmem_dout      ( vmem_dout     ),
    .oram_dout      ( oram_dout     ),
    .cpal_dout      ( cpal_dout     ),
    // To video
    .rmrd           ( rmrd          ),
    .dma_bsy        ( dma_bsy       ),
    .objreg_cs      ( objreg_cs     ),
    .objcha_n       ( objcha_n      ),

    .obj_cs         ( objsys_cs     ),
    .vram_cs        ( tilesys_cs    ),
    .pal_cs         ( pal_cs        ),
    .pcu_cs         ( pcu_cs        ), // priority mixer
    .ccu_cs         ( ccu_cs        ), // video timer
    // EEPROM
    .nv_addr        ( nvram_addr    ),
    .nv_dout        ( nvram_dout    ),
    .nv_din         ( nvram_din     ),
    .nv_we          ( nvram_we      ),
    // DIP switches
    .dipsw          ( dipsw[3:0]    ),
    .dip_pause      ( dip_pause     ),
    .dip_test       ( dip_test      ),
    // Debug
    .st_dout        ( st_main       ),
    .debug_bus      ( debug_bus     )
);

jtrungun_video u_video(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .pxl_cen        ( pxl_cen       ),
    .ghflip         ( ghflip        ),
    .gvflip         ( gvflip        ),
    .pri            ( pri           ),

    .disp           ( disp          ),
    // Base Video
    .lhbl           ( LHBL          ),
    .lvbl           ( LVBL          ),
    .hs             ( HS            ),
    .vs             ( VS            ),
    // CPU interface
    .ccu_cs         ( ccu_cs        ),   // timer
    .addr           ( main_addr[3:1]),
    .rnw            ( cpu_rnw       ),
    .cpu_dout       ( cpu_dout      ),
    .vtimer_mmr     ( vtimer_mmr    ),
    // fixed layer
    .vram_addr      ( vram_addr     ),
    .vram_dout      ( vram_dout     ),
    // palette
    .pal_addr       ( pal_addr      ),
    .pal_dout       ( pal_dout      ),

    .fix_addr       ( fix_addr      ),
    .fix_data       ( fix_data      ),
    .fix_cs         ( fix_cs        ),
    .fix_ok         ( fix_ok        ),
    // final pixel
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    // Debug
    .debug_bus      ( debug_bus     ),
    // IOCTL dump
    .ioctl_addr     ( ioctl_addr[3:0]),
    .ioctl_din      ( ioctl_din     )
);

endmodule
