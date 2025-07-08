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

wire [ 7:0] vtimer_mmr, st_main, st_snd;
wire [ 3:0] psac_bank;
wire        lrsw, ccu_cs, disp, gvflip, ghflip, pri, cpu_rnw;

assign sample=0, snd_left=0, snd_right=0, debug_view=0;
assign dip_flip = ghflip ^ gvflip;
assign snd_cs=0, snd_addr=0, pcm_cs=0, pcm_addr=0;
assign oram_addr=0, psac0_addr=0, psac1_addr=0, psac2_addr=0, line_addr=0;

jtrungun_main u_main(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .pxl_cen        ( pxl_cen       ),
    .lvbl           ( LVBL          ),

    .lrsw           ( lrsw          ),
    .disp           ( disp          ),
    .pri            ( pri           ),
    .ghflip         ( ghflip        ),
    .gvflip         ( gvflip        ),

    .cpu_rnw        ( cpu_rnw       ),
    .cpu_dout       ( cpu_dout      ),

    .vmem_addr      ( vmem_addr     ),
    .pmem_addr      ( pmem_addr     ),
    .psac_bank      ( psac_bank     ),
    .vtimer_mmr     ( vtimer_mmr    ),

    .main_addr      ( main_addr     ),
    .rom_data       ( main_data     ),
    .rom_cs         ( main_cs       ),
    .rom_ok         ( main_ok       ),
    // RAM
    .ram_dsn        ( ram_dsn       ),
    .ram_we         ( ram_we        ),
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

    .vmem_we        ( vmem_we       ),
    .pmem0_we       ( pmem0_we      ),
    .pmem1_we       ( pmem1_we      ),
    .pmem2_we       ( pmem2_we      ),
    .lmem_we        ( lmem_we       ),
    .omem_we        ( omem_we       ),
    .cpal_we        ( cpal_we       ),

    .vmem_dout      ( vmem_dout     ),
    .pmem0_dout     ( pmem0_dout    ),
    .pmem1_dout     ( pmem1_dout    ),
    .pmem2_dout     ( pmem2_dout    ),
    .lmem_dout      ( lmem_dout     ),
    .omem_dout      ( omem_dout     ),
    .cpal_dout      ( cpal_dout     ),

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
    .lrsw           ( lrsw          ),
    .pri            ( pri           ),

    .disp           ( disp          ),
    // Base Video
    .lhbl           ( LHBL          ),
    .lvbl           ( LVBL          ),
    .hs             ( HS            ),
    .vs             ( VS            ),
    // CPU interface
    .ccu_cs         ( ccu_cs        ),   // timer
    .addr           ( main_addr[4:1]),
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

    .scr_addr       ( scr_addr      ),
    .scr_data       ( scr_data      ),
    .scr_cs         ( scr_cs        ),
    .scr_ok         ( scr_ok        ),

    .obj_addr       ( obj_addr      ),
    .obj_data       ( obj_data      ),
    .obj_cs         ( obj_cs        ),
    .obj_ok         ( obj_ok        ),
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

jtrungun_sound u_sound(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen_8          ( cen_8         ),
    .cen_pcm        ( cen_pcm       ),

    input           pair_we,
    // communication with main CPU
    input   [ 7:0]  main_dout,  // bus access for Punk Shot
    output  [ 7:0]  main_din,
    output  [ 7:0]  pair_dout,
    input   [ 4:1]  main_addr,
    input           main_rnw,

    input           snd_irq,
    // ROM
    .rom_addr       ( snd_addr      ),
    .rom_cs         ( snd_cs        ),
    .rom_data       ( snd_data      ),
    .rom_ok         ( snd_ok        ),
    // ADPCM ROM
    .pcma_addr      ( pcma_addr     ),
    .pcmb_addr      ( pcmb_addr     ),
    .pcma_dout      ( pcma_dout     ),
    .pcmb_dout      ( pcmb_dout     ),
    .pcma_cs        ( pcma_cs       ),
    .pcmb_cs        ( pcmb_cs       ),
    // Sound output
    .k539a_l        ( k539a_l       ),
    .k539a_r        ( k539a_r       ),
    .k539b_l        ( k539b_l       ),
    .k539b_r        ( k539b_r       ),
    // Debug
    .debug_bus      ( debug_bus     ),
    .st_dout        ( st_snd        )
);

endmodule
