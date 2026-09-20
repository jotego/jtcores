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
    Date: 18-9-2026
*/

// System FL top. i960 main CPU + video. C75/C352 still stubbed
// define NOMAIN for video-only simulations (scene replays)
module jtsysfl_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [15:1] tmap_addr;
wire [16:1] rozmap_addr, objtab_addr;
wire [12:0] rgb_addr;
wire [ 8:0] hdump, vdump, vrender;
wire [ 7:0] st_video, ioctl_video, ioctl_misc;
wire        raster_irqn, flip;
wire [ 1:0] sprbank;

// main CPU <-> video
wire        scfg_cs, rozcfg_cs, cpu_rnw, pal_cs, misc_cs;
wire [ 5:1] cfg_addr;
wire [ 1:0] vdsn, misc_a;
wire [15:0] vcpu_dout, scfg_dout, rozcfg_dout;
wire [14:0] pal_amux;
wire [ 7:0] pal_din8, pal_dout8, misc_din;
wire        cpu_halted;

assign flip       = dip_flip;

`ifdef JTFRAME_LF_BUFFER
// screen row (0-223, 224+ during blanking) for the line frame buffer.
// Visible rows are 0x121-0x1FF plus the counter-wrap row 0xF8
wire [ 8:0] vmap  = vrender >= 9'h121 ? vrender - 9'h121 : vrender - 9'd25;
assign game_hdump   = hdump;
assign game_vrender = vmap[7:0];
assign fb_keep      = 0;
`else
// video still compiles without the frame buffer, sprites blanked
wire        ln_hs  = 0;
wire [ 7:0] ln_v   = 0;
wire [15:0] ln_pxl = 16'h00ff;
wire [ 8:0] ln_addr;
wire [15:0] ln_data;
wire        ln_we, ln_done;
`endif
assign debug_view = st_video;
assign game_led   = 0;
assign vram_addr  = tmap_addr;
assign rozram_addr= rozmap_addr;
assign oram_addr  = objtab_addr;
assign rpal_addr  = rgb_addr;
assign gpal_addr  = rgb_addr;
assign bpal_addr  = rgb_addr;
assign pal_wdin   = pal_din8;

// MMR sections dumped after the BRAMs; 0x56000 is 128B-aligned
assign ioctl_din = &ioctl_addr[6:4] ? ioctl_misc : ioctl_video;

`ifndef NOMAIN
jtsysfl_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cpu_cen    ( cpu_cen       ),
    .lvbl       ( LVBL          ),
    .hs         ( HS            ),
    .raster_irqn( raster_irqn   ),
    // program + data ROM
    .main_addr  ( main_addr     ),
    .main_cs    ( main_cs       ),
    .main_ok    ( main_ok       ),
    .main_data  ( main_data     ),
    // work RAM
    .wram_addr  ( wram_addr     ),
    .wram_cs    ( wram_cs       ),
    .wram_we    ( wram_we       ),
    .wram_din   ( wram_din      ),
    .wram_dsn   ( wram_dsn      ),
    .wram_ok    ( wram_ok       ),
    .wram_data  ( wram_data     ),
    .wram32_addr( wram32_addr   ),
    .wram32_cs  ( wram32_cs     ),
    .wram32_ok  ( wram32_ok     ),
    .wram32_data( wram32_data   ),
    // BRAMs
    .cvram_addr ( cvram_addr    ),
    .cvram_din  ( cvram_din     ),
    .cvram_we   ( cvram_we      ),
    .cvram_dout ( cvram_dout    ),
    .crozram_addr( crozram_addr ),
    .crozram_din( crozram_din   ),
    .crozram_we ( crozram_we    ),
    .crozram_dout( crozram_dout ),
    .coram_addr ( coram_addr    ),
    .coram_din  ( coram_din     ),
    .coram_we   ( coram_we      ),
    .coram_dout ( coram_dout    ),
    .nvram_addr ( nvram_addr    ),
    .nvram_din  ( nvram_din     ),
    .nvram_we   ( nvram_we      ),
    .nvram_dout ( nvram_dout    ),
    .share_addr ( share_addr    ),
    .share_din  ( share_din     ),
    .share_we   ( share_we      ),
    .share_dout ( share_dout    ),
    .comram_addr( comram_addr   ),
    .comram_din ( comram_din    ),
    .comram_we  ( comram_we     ),
    .comram_dout( comram_dout   ),
    // video registers
    .scfg_cs    ( scfg_cs       ),
    .rozcfg_cs  ( rozcfg_cs     ),
    .cfg_addr   ( cfg_addr      ),
    .cpu_rnw    ( cpu_rnw       ),
    .vdsn       ( vdsn          ),
    .vcpu_dout  ( vcpu_dout     ),
    .scfg_dout  ( scfg_dout     ),
    .rozcfg_dout( rozcfg_dout   ),
    .pal_cs     ( pal_cs        ),
    .pal_amux   ( pal_amux      ),
    .pal_din    ( pal_din8      ),
    .pal_dout   ( pal_dout8     ),
    // sprite bank
    .misc_cs    ( misc_cs       ),
    .misc_addr  ( misc_a        ),
    .misc_din   ( misc_din      ),
    .halted     ( cpu_halted    )
);

wire flr;

// game id from the MRA header, byte 0
jtsysfl_header u_header(
    .clk        ( clk           ),
    .header     ( header        ),
    .prog_we    ( prog_we       ),
    .flr        ( flr           ),
    .prog_addr  ( prog_addr[2:0]),
    .prog_data  ( prog_data     )
);

`ifdef C75_STUB
// TEMPORARY C75 stub, kept for A/B debugging, see jtsysfl_main.v
jtsysfl_c75stub u_c75stub(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .lvbl       ( LVBL          ),
    .mcu_addr   ( mcu_addr      ),
    .mcu_din    ( mcu_din       ),
    .mcu_we     ( mcu_we        )
);
assign c75bios_addr = 0;
assign mcurom_addr  = 0;
assign mcurom_cs    = 0;
assign pcm_addr     = 0;
assign pcm_cs       = 0;
assign snd_left     = 0;
assign snd_right    = 0;
assign sample       = 0;
`else
// real C75 (M37702 + BIOS) + C352
jtsysfl_c75 u_c75(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .xin_cen    ( xin_cen       ),
    .c352_cen   ( c352_cen      ),
    .lvbl       ( LVBL          ),
    // MISC[7:4] = {SERVICE1, TEST, COIN1, COIN2}, active low
    .cab_misc   ( {service, dip_test, coin[0], coin[1]} ),
    .joystick   ( joystick1[7:0]),
    .start      ( cab_1p[0]     ),
    .flr        ( flr           ),
    .mcu_addr   ( mcu_addr      ),
    .mcu_din    ( mcu_din       ),
    .mcu_we     ( mcu_we        ),
    .mcu_dout   ( mcu_dout      ),
    .bios_addr  ( c75bios_addr  ),
    .bios_data  ( c75bios_data  ),
    .mcurom_addr( mcurom_addr   ),
    .mcurom_cs  ( mcurom_cs     ),
    .mcurom_data( mcurom_data   ),
    .mcurom_ok  ( mcurom_ok     ),
    .pcm_addr   ( pcm_addr      ),
    .pcm_cs     ( pcm_cs        ),
    .pcm_data   ( pcm_data      ),
    .pcm_ok     ( pcm_ok        ),
    .snd_l      ( snd_left      ),
    .snd_r      ( snd_right     ),
    .sample     ( sample        ),
    .debug_bus  ( debug_bus     )
);
`endif
`else
assign main_addr  = 0;
assign main_cs    = 0;
assign wram_addr  = 0;
assign wram_cs    = 0;
assign wram_we    = 0;
assign wram_din   = 0;
assign wram_dsn   = 3;
assign wram32_addr= 0;
assign wram32_cs  = 0;
assign cvram_addr = 0;
assign cvram_din  = 0;
assign cvram_we   = 0;
assign crozram_addr = 0;
assign crozram_din  = 0;
assign crozram_we   = 0;
assign coram_addr = 0;
assign coram_din  = 0;
assign coram_we   = 0;
assign nvram_addr = 0;
assign nvram_din  = 0;
assign nvram_we   = 0;
assign share_addr = 0;
assign share_din  = 0;
assign share_we   = 0;
assign comram_addr= 0;
assign comram_din = 0;
assign comram_we  = 0;
assign mcu_addr   = 0;
assign mcu_din    = 0;
assign mcu_we     = 0;
assign c75bios_addr = 0;
assign mcurom_addr  = 0;
assign mcurom_cs    = 0;
assign pcm_addr     = 0;
assign pcm_cs       = 0;
assign snd_left     = 0;
assign snd_right    = 0;
assign sample       = 0;
assign scfg_cs    = 0;
assign rozcfg_cs  = 0;
assign cfg_addr   = 0;
assign cpu_rnw    = 1;
assign vdsn       = 3;
assign vcpu_dout  = 0;
assign pal_cs     = 0;
assign pal_amux   = 0;
assign pal_din8   = 0;
assign misc_cs    = 0;
assign misc_a     = 0;
assign misc_din   = 0;
assign cpu_halted = 0;
`endif

jtsysfl_misc_mmr #(.SEEK('h70)) u_misc(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cs         ( misc_cs       ),
    .addr       ( misc_a        ),
    .rnw        ( 1'b0          ), // write-only from the CPU
    .din        ( misc_din      ),
    .dout       (               ),
    .sprbank    ( sprbank       ),
    .ioctl_addr ( ioctl_addr[1:0] ),
    .ioctl_din  ( ioctl_misc    ),
    .debug_bus  ( debug_bus     ),
    .st_dout    (               )
);

jtsysfl_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .lhbl       ( LHBL          ),
    .lvbl       ( LVBL          ),
    .hs         ( HS            ),
    .vs         ( VS            ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .raster_irqn( raster_irqn   ),
    .flip       ( flip          ),
    .sprbank    ( sprbank       ),

    .ln_hs      ( ln_hs         ),
    .ln_v       ( ln_v          ),
    .ln_pxl     ( ln_pxl        ),
    .ln_addr    ( ln_addr       ),
    .ln_data    ( ln_data       ),
    .ln_we      ( ln_we         ),
    .ln_done    ( ln_done       ),

    .scfg_cs    ( scfg_cs       ),
    .rozcfg_cs  ( rozcfg_cs     ),
    .cfg_addr   ( cfg_addr      ),
    .cpu_rnw    ( cpu_rnw       ),
    .dsn        ( vdsn          ),
    .cpu_dout   ( vcpu_dout     ),
    .scfg_dout  ( scfg_dout     ),
    .rozcfg_dout( rozcfg_dout   ),
    .pal_cs     ( pal_cs        ),
    .pal_amux   ( pal_amux      ),
    .pal_din    ( pal_din8      ),
    .pal_dout   ( pal_dout8     ),

    .tmap_addr  ( tmap_addr     ),
    .tmap_data  ( vram_dout     ),
    .rozmap_addr( rozmap_addr   ),
    .rozmap_data( rozram_dout   ),
    .objtab_addr( objtab_addr   ),
    .objtab_data( oram_dout     ),
    .rgb_addr   ( rgb_addr      ),
    .pal_addr   ( pal_waddr     ),
    .rpal_we    ( rpal_we       ),
    .gpal_we    ( gpal_we       ),
    .bpal_we    ( bpal_we       ),
    .red_dout   ( rpal_dout     ),
    .rpal_dout  ( rpal_cdout    ),
    .green_dout ( gpal_dout     ),
    .gpal_dout  ( gpal_cdout    ),
    .blue_dout  ( bpal_dout     ),
    .bpal_dout  ( bpal_cdout    ),

    .smask_cs   ( smask_cs      ),
    .smask_addr ( smask_addr    ),
    .smask_ok   ( smask_ok      ),
    .smask_data ( smask_data    ),
    .scr_cs     ( scr_cs        ),
    .scr_addr   ( scr_addr      ),
    .scr_ok     ( scr_ok        ),
    .scr_data   ( scr_data      ),
    .rmask_cs   ( rmask_cs      ),
    .rmask_addr ( rmask_addr    ),
    .rmask_ok   ( rmask_ok      ),
    .rmask_data ( rmask_data    ),
    .roz_cs     ( roz_cs        ),
    .roz_addr   ( roz_addr      ),
    .roz_ok     ( roz_ok        ),
    .roz_data   ( roz_data      ),
    .objrom_cs  ( objrom_cs     ),
    .objrom_addr( objrom_addr   ),
    .objrom_ok  ( objrom_ok     ),
    .objrom_data( objrom_data   ),

    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),

    .ioctl_addr ( ioctl_addr[6:0] ),
    .ioctl_din  ( ioctl_video   ),
    .gfx_en     ( gfx_en        ),
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_video      )
);

endmodule
