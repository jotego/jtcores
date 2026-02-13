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
wire [ 1:0] cpu_dsn;
wire [ 7:0] snd_cmd, snd_rply, st_main, st_snd, st_video;
wire [15:0] vram_dout;
wire        cpu_ldwn, set_cmd, flip, cpu_rnw,
            vram_cs, vctrl_cs, vflag_cs, pal_cs;

assign debug_view = st_video;
assign dip_flip   = ~flip;
assign fix_addr   = 0;
assign fix_cs     = 0;
assign cpu_ldwn   = cpu_rnw | cpu_dsn[0];

reg        LHBL_l;
reg  [5:0] cnt244;
wire [6:0] nx_244 = {1'b0,cnt244} + 6'd1;
reg        cen244;

always @(posedge clk) begin
    LHBL_l <= LHBL;
    cen244 <= 0;
    if( LHBL & ~LHBL_l ) {cen244,cnt244} <= nx_244;
end

/* verilator tracing_on */
jtcal50_main u_main(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .pxl_cen        ( pxl_cen       ),
    .cen244         ( cen244        ),
    .lvbl           ( LVBL          ),

    .vctrl_cs       ( vctrl_cs      ),
    .vflag_cs       ( vflag_cs      ),
    .vram_cs        ( vram_cs       ),
    .vram_dout      ( vram_dout     ),

    .cpu_rnw        ( cpu_rnw       ),
    .cpu_dout       ( cpu_dout      ),

    .cpu_addr       ( cpu_addr      ),
    .cpu_dsn        ( cpu_dsn       ),
    .ram_addr       ( ram_addr      ),
    .rom_addr       ( main_addr     ),
    .rom_data       ( main_data     ),
    .rom_cs         ( main_cs       ),
    .rom_ok         ( main_ok       ),
    // NVRAM
    .nvram_we       ( nvram_we      ),
    .nvram_dout     ( nvram_dout    ),
    // RAM
    .ram_we         ( ram_we        ),
    .ram_dout       ( ram_dout      ),
    // cabinet I/O
    .cab_1p         ( cab_1p[1:0]   ),
    .coin           ( coin[1:0]     ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .service        ( service       ),
    .tilt           ( tilt          ),
    // video
    .pal_we         ( pal_we        ),
    .pal_dout       ( pal_dout      ),
    .tlv_we         ( tlv_we        ),
    .tlv_dout       ( tlv_dout      ),

    // Sound
    .snd_cmd        ( snd_cmd       ),
    .snd_rply       ( snd_rply      ),
    .set_cmd        ( set_cmd       ),
    // DIP switches
    .dipsw          ( dipsw[15:0]   ),
    .dip_pause      ( dip_pause     ),
    .dip_test       ( dip_test      ),
    // Debug
    .st_dout        ( st_main       ),
    .debug_bus      ( debug_bus     )
);
/* verilator tracing_on */
jtcal50_sound u_sound(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen2           ( cen2          ),
    .cen244         ( cen244        ),

    // communication with main CPU
    .snd_cmd        ( snd_cmd       ),
    .snd_rply       ( snd_rply      ),
    .set_cmd        ( set_cmd       ),
    // ROM
    .rom_addr       ( snd_addr      ),
    .rom_cs         ( snd_cs        ),
    .rom_data       ( snd_data      ),
    .rom_ok         ( snd_ok        ),
    // PCM RAM
    .pcmram_we      ( pcmram_we     ),
    .pcmram_din     ( pcmram_din    ),
    .pcmram_dout    ( pcmram_dout   ),
    .pcmram_addr    ( pcmram_addr   ),
    // PCM ROM
    .pcm_addr       ( pcm_addr      ),
    .pcm_data       ( pcm_data      ),
    .pcm_cs         ( pcm_cs        ),
    // Sound
    .snd            ( snd           ),
    .sample         ( sample        ),
    // Debug
    .debug_bus      ( debug_bus     ),
    .st_dout        ( st_snd        )
);
/* verilator tracing_off */
jtcal50_video u_video(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .clk_cpu        ( clk           ),

    .pxl2_cen       ( pxl2_cen      ),
    .pxl_cen        ( pxl_cen       ),
    .LHBL           ( LHBL          ),
    .LVBL           ( LVBL          ),
    .HS             ( HS            ),
    .VS             ( VS            ),
    .flip           ( flip          ),
    // GFX - CPU interface
    .cpu_rnw        ( cpu_ldwn      ),
    .cpu_dsn        ( cpu_dsn       ),
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),

    .vram_cs        ( vram_cs       ),
    .vctrl_cs       ( vctrl_cs      ),
    .vflag_cs       ( vflag_cs      ),
    .vram_dout      ( vram_dout     ),

    .pal_addr       ( palrd_addr    ),
    .pal_data       ( pal_data      ),

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
    .st_dout        ( st_video      )
);

endmodule
