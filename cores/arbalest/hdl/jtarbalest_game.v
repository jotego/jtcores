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

    Author: Andrea Bogazzi. andreabogazzi79@gmail.com
    Version: 1.0
    Date: 17-06-2026 */

// Seta downtown.cpp (metafox-class) top.
// Reuses the cal50 video pipeline (jtcal50_video = single X1-012 layer + X1-001
// sprites + direct xRGB-555 colmix) IMPORTED via cfg/files.yaml. Only the bus
// topology differs, so main/sub/sound are local to this core.
module jtarbalest_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [13:1] cpu_addr;
wire [ 1:0] cpu_dsn;
wire [ 8:0] hdump;
wire [ 7:0] st_main, st_sub, st_video, x1_dout, slatch0, slatch1;
wire [15:0] vram_dout;
wire        flip, cpu_rnw, sub_rst,
            vram_cs, vctrl_cs, vflag_cs, tctrl_cs,
            x1_cs, shram_cs;

// MRA header byte 0 = game_id (0=metafox, 1=arbalest)
`ifdef JTFRAME_SIM_GAMEID
reg [3:0] game_id = `JTFRAME_SIM_GAMEID;
`else
reg [3:0] game_id = 4'd0;
`endif
always @(posedge clk) if( prog_we && header ) case( prog_addr[3:0] )
    4'd0: game_id <= prog_data[3:0];
    default:;
endcase

assign debug_view = st_video;
assign dip_flip   = ~flip;
assign mute       = 0;

/* verilator tracing_on */
jtarbalest_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen8       ( cen8          ),
    .lvbl       ( LVBL          ),

    .rom_addr   ( main_addr     ),
    .ram_addr   ( ram_addr      ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_dsn    ( cpu_dsn       ),
    .ram_we     ( ram_we        ),
    .cpu_dout   ( cpu_dout      ),
    .cpu_rnw    ( cpu_rnw       ),

    .rom_cs     ( main_cs       ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    .ram_dout   ( ram_dout      ),

    // X1-010 sound (main bus)
    .x1_cs      ( x1_cs         ),
    .x1_dout    ( x1_dout       ),

    // I/O sub-CPU (sub_ctrl_w decoded in main)
    .slatch0    ( slatch0       ),
    .slatch1    ( slatch1       ),
    .sub_rst    ( sub_rst       ),
    .shram_cs   ( shram_cs      ),
    .shram_we   ( shram_we      ),
    .shram_dout ( shram_dout    ),

    // video
    .pal_we     ( pal_we        ),
    .pal_dout   ( pal_dout      ),
    .tctrl_cs   ( tctrl_cs      ),
    .tlv_we     ( tlv_we        ),
    .tlv_dout   ( tlv_dout      ),
    .vram_cs    ( vram_cs       ),
    .vflag_cs   ( vflag_cs      ),
    .vctrl_cs   ( vctrl_cs      ),
    .vram_dout  ( vram_dout     ),

    // cabinet
    .game_id    ( game_id       ),
    .dipsw      ( dipsw[15:0]   ),
    .dip_pause  ( dip_pause     ),
    .st_dout    ( st_main       ),
    .debug_bus  ( debug_bus     )
);

/* verilator tracing_on */
jtarbalest_sub u_sub(
    .rst        ( sub_rst       ),
    .clk        ( clk           ),
    .cen        ( cen8          ),   // 8 MHz crystal cen -> ~2 MHz E (jt65c02 /4)
    .joystick1  ( joystick1[5:0]),
    .joystick2  ( joystick2[5:0]),
    .cab_1p     ( cab_1p[1:0]   ),
    .coin       ( coin[1:0]     ),
    .service    ( service       ),
    .tilt       ( tilt          ),
    .slatch0    ( slatch0       ),
    .slatch1    ( slatch1       ),

    .rom_addr   ( snd_addr      ),
    .rom_cs     ( snd_cs        ),
    .rom_data   ( snd_data      ),
    .rom_ok     ( snd_ok        ),

    .subsh_addr ( subsh_addr    ),
    .subsh_din  ( subsh_din     ),
    .subsh_dout ( subsh_dout    ),
    .subsh_we   ( subsh_we      ),

    .hs         ( HS            ),
    .lvbl       ( LVBL          ),
    .st_dout    ( st_sub        )
);

/* verilator tracing_on */
jtarbalest_sound u_sound(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen_pcm    ( cen_pcm       ),

    .cs         ( x1_cs         ),
    .addr       ( cpu_addr      ),
    .din        ( cpu_dout[7:0] ),
    .dout       ( x1_dout       ),
    .we         (~cpu_rnw       ),

    .pcm_addr   ( pcm_addr      ),
    .pcm_data   ( pcm_data      ),
    .pcm_cs     ( pcm_cs        ),

    .snd_left   ( pcm_8k        ),
    .snd_right  ( pcm_4k        )
);

/* verilator tracing_on */
jtcal50_video #(.SPRMODE(1), // SETAC: 16KB sprite RAM + 0x1000 bank
    // metafox/arbalest visarea = 224 lines (MAME set_visarea rows 16..239)
    .VB_END(9'd7), .VB_START(9'd231),

    .THOFFS(16'h06), .TVOFFS(-9'd8),
    .SPR_HADJ(9'd5-9'd8),
    // metafox/arbalest use the X1-001 background layer (draw_background) for the
    // attract scenery;
    .SCR_EN(1)
) u_video( // metafox: 16KB sprite RAM + setac bank
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk_cpu    ( clk           ),
    .cen244     (               ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .hdump      ( hdump         ),
    .flip       ( flip          ),

    .cpu_rnw    ( cpu_rnw       ),
    .cpu_dsn    ( cpu_dsn       ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_dout   ( cpu_dout      ),
    .vram_cs    ( vram_cs       ),
    .vctrl_cs   ( vctrl_cs      ),
    .vflag_cs   ( vflag_cs      ),
    .vram_dout  ( vram_dout     ),

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

    .tctrl_cs   ( tctrl_cs      ),
    .tvram_addr ( tlrd_addr     ),
    .tvram_dout ( tlrd_data     ),
    .tile_addr  ( tile_addr     ),
    .tile_data  ( tile_data     ),
    .tile_cs    ( tile_cs       ),
    .tile_ok    ( tile_ok       ),

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

    .ioctl_addr (ioctl_addr[2:0]),
    .ioctl_din  ( ioctl_din     ),
    .gfx_en     ( gfx_en        ),
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_video      )
);

endmodule
