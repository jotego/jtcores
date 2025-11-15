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
    Date: 14-11-2025 */

module jtcal50_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [13:1] cpu_addr;
wire [ 7:0] snd_cmd, snd_rply, st_main, st_snd;
wire        vctrl_cs, vflag_cs;

/* verilator tracing_on */
jtcal50_main u_main(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .pxl_cen        ( pxl_cen       ),
    .cen244         ( cen244        ),
    .lvbl           ( LVBL          ),

    .vctrl_cs       ( vctrl_cs      ),
    .vflag_cs       ( vflag_cs      ),

    .cpu_rnw        ( cpu_rnw       ),
    .cpu_dout       ( cpu_dout      ),

    .cpu_addr       ( cpu_addr      ),
    .rom_addr       ( main_addr     ),
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
    .service        ( service       ),
    .tilt           ( tilt          ),
    // objects
    .objrg_cs       ( objrg_cs      ),
    .objrm_cs       ( objrm_cs      ),
    .odma           ( dma_bsy       ),
    .objcha_n       ( objcha_n      ),

    .cpal_addr      ( cpal_addr     ),

    // Sound
    .snd_cmd        ( snd_cmd       ),
    .snd_rply       ( snd_rply      ),
    // DIP switches
    .dipsw          ( dipsw[15:0]   ),
    .dip_pause      ( dip_pause     ),
    .dip_test       ( dip_test      ),
    // Debug
    .st_dout        ( st_main       ),
    .debug_bus      ( debug_bus     )
);
/* verilator tracing_off */
jtcal50_sound u_sound(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen2           ( cen2          ),

    // communication with main CPU
    .snd_cmd        ( snd_cmd       ),
    .snd_rply       ( snd_rply      ),
    // ROM
    .rom_addr       ( snd_addr      ),
    .rom_cs         ( snd_cs        ),
    .rom_data       ( snd_data      ),
    .rom_ok         ( snd_ok        ),
    // ADPCM ROM
    .pcma_addr      ( pcma_addr     ),
    .pcma_data      ( pcma_data     ),
    .pcma_cs        ( pcma_cs       ),
    // Debug
    .debug_bus      ( debug_bus     ),
    .st_dout        ( st_snd        )
);
/* verilator tracing_on */
jtcal50_video u_video(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .clk_cpu        ( clk           ),

    .pxl2_cen       ( pxl2_cen      ),
    .pxl_cen        ( pxl_cen       ),
    .hb_dly         ( hb_dly        ),
    .LHBL           ( LHBL          ),
    .LVBL           ( LVBL          ),
    .HS             ( HS            ),
    .VS             ( VS            ),
    .flip           ( flip          ),
    .hdump          ( hdump         ),
    // PROMs
    .prom_we        ( colprom_we    ),
    .prog_addr      ( prog_addr[9:0]),
    .prog_data      ( prog_data     ),
    .colprom_en     ( colprom_en    ),
    // GFX - CPU interface
    .cpu_rnw        ( cpu_rnw       ),
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),

    .vram_cs        ( vram_cs       ),
    .vctrl_cs       ( vctrl_cs      ),
    .vflag_cs       ( vflag_cs      ),
    .vram_dout      ( vram_dout     ),

    .pal_cs         ( pal_cs        ),
    .pal_dout       ( pal_dout      ),

    .pal2_cs        ( pal2_cs       ),
    .cpu2_dout      ( shr_din       ),
    .cpu2_rnw       ( sub_rnw       ),
    .cpu2_addr      ( shr_addr[9:0] ),

    // SDRAM
    .scr_addr       ( scr_addr      ),
    .scr_data       ( scr_data      ),
    .scr_ok         ( scr_ok        ),
    .scr_cs         ( scr_cs        ),

    .obj_addr       ( obj_addr      ),
    .obj_data       ( obj_data      ),
    .obj_ok         ( obj_ok        ),
    .obj_cs         ( obj_cs        ),
    // pixels
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    // Test
    .gfx_en         ( gfx_en        ),
    .debug_bus      ( debug_bus     ),
    .st_dout        ( gfx_st        )
);

endmodule
