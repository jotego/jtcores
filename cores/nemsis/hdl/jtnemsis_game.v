/*

FPGA compatible core of arcade hardware by LMN-san, OScherler, Raki.

(c) LMN-san, OScherler, Raki 2020–2026.
// SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
// JTCORES project edits: 2026-11-08.

The authors do not endorse or participate in illegal distribution
of copyrighted material. This work can be used with legally
obtained ROM dumps of games or with homebrew software for
the arcade platform.

This file license is GNU GPLv3.
You can read the whole license file at http://www.gnu.org/licenses/

*/

//================================================================================
//  Nemesis Top-Level Module
//================================================================================

`default_nettype none

module jtnemsis_game(
	`include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

localparam [21:0] WAV1_OFFSET = 22'h04_4000,
                  WAV2_OFFSET = 22'h04_4100,
                  PROM_END    = 22'h04_4200;

// ---------------------------------------------------------------------------
// Interconnection Signals
// ---------------------------------------------------------------------------

wire        cen_9, pxl_cenb, clk6, cen_3p5, cen_1p7, audio_div_cen;
wire [  3:0] wav1_data, wav2_data;
wire [  7:0] wav1_vol_data, wav2_vol_data;
wire [ 7:0] wav1_addr, wav1_vol_addr, wav2_addr, wav2_vol_addr;
wire [ 7:0] prog_addr_wave1, prog_addr_wave2;
wire        prom_a01_we, prom_a02_we;
wire [17:1] req_main_addr;
wire        req_main_cs;

wire        hflip, vflip;
wire        inter_non, resolution_288_256;
wire        chacs_n, objram_n, vcs2, vcs1, vzcs;
wire        h1_n, h2, v256, vblank;

wire [15:1] video_addr;
wire [ 7:0] sound_db;
wire [15:0] video_din, video_dout;
wire        lds_n, uds_n, rw_n, sound_on_n, data_n;

wire [ 4:0] red5, green5, blue5;
wire        preLHBL, preLVBL;
wire [ 1:0] color_source;
reg  [ 1:0] color_source_rgb;
wire [ 7:0] st_main, st_sound, status_data;
wire        rc33_en, rc47_en;

assign dip_flip = 0;
assign main_cs    = req_main_cs & (~uds_n | ~lds_n);
assign main_addr  = req_main_addr;
assign prog_addr_wave1 = prog_addr[7:0] - WAV1_OFFSET[7:0];
assign prog_addr_wave2 = prog_addr[7:0] - WAV2_OFFSET[7:0];
assign prom_a01_we = prom_we && ( prog_addr >= WAV1_OFFSET ) && ( prog_addr < WAV2_OFFSET );
assign prom_a02_we = prom_we && ( prog_addr >= WAV2_OFFSET ) && ( prog_addr < PROM_END    );
assign status_data = debug_bus[7:6] == 2'd0 ? st_main  :
                     debug_bus[7:6] == 2'd1 ? st_sound : 8'd0;
assign debug_view  = status_data;
assign preLVBL     = ~vblank;
assign ay7e_rcen = { ~rc33_en & rc47_en,
                     rc33_en & ~rc47_en,
                     rc33_en & rc47_en };
assign ay8e_rcen = rc47_en;
assign wav1_rcen = rc47_en;
assign wav2_rcen = rc47_en;

`ifdef JTFRAME_STATUS
assign st_dout = status_data;
`endif

always @(posedge clk or posedge rst) begin
	if( rst ) color_source_rgb <= 2'd0;
	else if( pxl_cen ) color_source_rgb <= color_source;
end

// ---------------------------------------------------------------------------
// Clock enables. The generator derives 9.216MHz CPU, 6.144MHz pixel, and
// 3.579545MHz audio timing from the 49.152MHz base clock. The original
// schematic's nominal 48MHz description corresponds to 9MHz CPU timing.
// ---------------------------------------------------------------------------

jtnemsis_gx400_cen u_cen(
	.clk                 ( clk               ),
	.vsync60             ( 1'b0              ),
	.cen_12              ( pxl2_cen          ),
	.cen_6               ( pxl_cen           ),
	.cen_6b              ( pxl_cenb          ),
	.clk6                ( clk6              ),
	.cen_9               ( cen_9             ),
	.cen_3p5             ( cen_3p5           ),
	.cen_1p7             ( cen_1p7           ),
	.audio_div_cen       ( audio_div_cen     )
);

// ** 1K (256 x 4) NiCR PROM **
// ** [6301] @ 7A            **
jtframe_prom #( .AW(8), .DW(4) ) u_wav1_rom(
	.clk     ( clk             ),
	.cen     ( 1'b1            ),
	.rd_addr ( wav1_addr       ),
	.wr_addr ( prog_addr_wave1 ),
	.data    ( prog_data[3:0]  ),
	.we      ( prom_a01_we     ),
	.q       ( wav1_data       )
);

// ** 1K (256 x 4) NiCR PROM **
// ** [6301] @ 7B            **
jtframe_prom #( .AW(8), .DW(4) ) u_wav2_rom(
	.clk     ( clk             ),
	.cen     ( 1'b1            ),
	.rd_addr ( wav2_addr       ),
	.wr_addr ( prog_addr_wave2 ),
	.data    ( prog_data[3:0]  ),
	.we      ( prom_a02_we     ),
	.q       ( wav2_data       )
);

// Volume table: models the switched resistor ladders at the output of the 6301
// PROMs @ 7A, 7B. Not a PCB ROM -- a computed constant, so it is built in
// rather than carried by the MRA. Two readers -> two copies.

jtframe_prom #( .AW(8),
	.SIMHEX("prom_vol.hex"), .SYNHEX("prom_vol.hex")) u_wav1_vol_rom(
	.clk     ( clk                ),
	.cen     ( 1'b1               ),
	.rd_addr ( wav1_vol_addr      ),
	.wr_addr ( 8'd0               ),
	.data    ( 8'd0               ),
	.we      ( 1'b0               ),
	.q       ( wav1_vol_data      )
);

jtframe_prom #( .AW(8),
	.SIMHEX("prom_vol.hex"), .SYNHEX("prom_vol.hex")) u_wav2_vol_rom(
	.clk     ( clk                ),
	.cen     ( 1'b1               ),
	.rd_addr ( wav2_vol_addr      ),
	.wr_addr ( 8'd0               ),
	.data    ( 8'd0               ),
	.we      ( 1'b0               ),
	.q       ( wav2_vol_data      )
);

// ---------------------------------------------------------------------------
// Main board
// ---------------------------------------------------------------------------

jtnemsis_main u_main(
	.rst                 ( rst              ),
	.clk                 ( clk              ),
	.pxl_cen             ( pxl_cen          ),
	.cen_9               ( cen_9            ),
	.vblank              ( vblank           ),
	.v256                ( v256             ),
	.clk6                ( clk6             ),
	.h1_n                ( h1_n             ),
	.h2                  ( h2               ),

	.chacs_n             ( chacs_n          ),
	.rw_n                ( rw_n             ),
	.uds_n               ( uds_n            ),
	.lds_n               ( lds_n            ),
	.inter_non           ( inter_non        ),
	.resolution_288_256  ( resolution_288_256 ),
	.vflip               ( vflip            ),
	.hflip               ( hflip            ),
	.objram_n            ( objram_n         ),
	.vcs2                ( vcs2             ),
	.vcs1                ( vcs1             ),
	.vzcs                ( vzcs             ),

	.main_addr           ( req_main_addr    ),
	.main_cs             ( req_main_cs      ),
	.main_data           ( main_data        ),
	.main_ok             ( main_ok          ),
	.ioctl_addr          ( ioctl_addr[3:0]  ),
	`ifdef JTFRAME_IOCTL_RD
	.ioctl_din           ( ioctl_din        ),
	`endif

	.sound_on_n          ( sound_on_n       ),
	.data_n              ( data_n           ),
	.sound_db            ( sound_db         ),

	.video_addr          ( video_addr       ),
	.video_din           ( video_dout       ),
	.video_dout          ( video_din        ),
	.pal_cpu_addr        ( pal_cpu_addr     ),
	.pal_cpu_din         ( pal_cpu_din      ),
	.pal_cpu_we          ( pal_cpu_we       ),
	.pal_cpu_dout        ( pal_dout         ),
	.pal_video_dout      ( pal_video_dout   ),

	.red                 ( red5             ),
	.green               ( green5           ),
	.blue                ( blue5            ),

	.joystick1           ( joystick1        ),
	.joystick2           ( joystick2        ),
	.coin                ( coin[1:0]        ),
	.cab_1p              ( cab_1p[1:0]      ),
	.dipsw               ( dipsw[23:0]      ),
	.service             ( service          ),
	.dip_pause           ( dip_pause        ),
	.debug_bus           ( debug_bus        ),
	.st_dout             ( st_main          )
);

// ---------------------------------------------------------------------------
// Colour mixing
// ---------------------------------------------------------------------------

// Capture the source tag at the same pixel enable as main's palette RGB
// register. Colmix delays it one master clock alongside the measured LUT.
jtnemsis_colmix u_colmix(
	.rst      ( rst              ),
	.clk      ( clk              ),
	.pxl_cen  ( pxl_cen          ),
	.source   ( color_source_rgb ),
	.red5     ( red5             ),
	.green5   ( green5           ),
	.blue5    ( blue5            ),
	.preLHBL  ( preLHBL          ),
	.preLVBL  ( preLVBL          ),
	.LHBL     ( LHBL             ),
	.LVBL     ( LVBL             ),
	.red      ( red              ),
	.green    ( green            ),
	.blue     ( blue             ),
	.gfx_en   ( gfx_en           )
);

// ---------------------------------------------------------------------------
// Video board
// ---------------------------------------------------------------------------

jtnemsis_gx400a_video u_video(
	.clk                  ( clk                  ),
	.rst                  ( rst                  ),
	.pxl_cen              ( pxl_cen              ),
	.pxl_cenb             ( pxl_cenb             ),
	.clk6                 ( clk6                 ),
	.hflip                ( hflip                ),
	.vflip                ( vflip                ),
	.inter_non            ( inter_non            ),
	.resolution_288_256   ( resolution_288_256   ),
	.gfx_en               ( gfx_en               ),

	.HS                   ( HS                   ),
	.VS                   ( VS                   ),
	.preLHBL              ( preLHBL              ),
	.vblank               ( vblank               ),
	.pal_addr             ( pal_video_addr       ),
	.color_source         ( color_source         ),
	.h1_n                 ( h1_n                 ),
	.h2                   ( h2                   ),
	.v256                 ( v256                 ),

	.cpu_addr             ( video_addr           ),
	.cpu_din              ( video_din            ),
	.cpu_dout             ( video_dout           ),
	.uds_n                ( uds_n                ),
	.lds_n                ( lds_n                ),
	.rnw                  ( rw_n                 ),
	.chacs_n              ( chacs_n              ),
	.objram_n             ( objram_n             ),
	.vcs1                 ( vcs1                 ),
	.vcs2                 ( vcs2                 ),
	.vzcs                 ( vzcs                 ),

	.scroll_cpu_addr ( scroll_cpu_addr ),
	.scroll_cpu_din  ( scroll_cpu_din  ),
	.scroll_cpu_we   ( scroll_cpu_we   ),
	.scroll_cpu_dout ( scroll_dout     ),
	.scroll_gfx_addr ( scroll_gfx_addr ),
	.scroll_gfx_dout ( scroll_gfx_dout ),

	.obj_cpu_addr    ( obj_cpu_addr    ),
	.obj_cpu_din     ( obj_cpu_din     ),
	.obj_cpu_we      ( obj_cpu_we      ),
	.obj_cpu_dout    ( obj_dout        ),
	.obj_gfx_addr    ( obj_gfx_addr    ),
	.obj_gfx_dout    ( obj_gfx_dout    ),

	.vram1_cpu_addr  ( vram1_cpu_addr  ),
	.vram1_cpu_din   ( vram1_cpu_din   ),
	.vram1_cpu_we    ( vram1_cpu_we    ),
	.vram1_cpu_dout  ( vram1_dout      ),
	.vram_gfx_addr   ( vram_gfx_addr   ),
	.vram1_gfx_dout  ( vram1_gfx_dout  ),

	.vram2_cpu_addr  ( vram2_cpu_addr  ),
	.vram2_cpu_din   ( vram2_cpu_din   ),
	.vram2_cpu_we    ( vram2_cpu_we    ),
	.vram2_cpu_dout  ( vram2_dout      ),
	.vram2_gfx_addr  ( vram2_gfx_addr  ),
	.vram2_gfx_dout  ( vram2_gfx_dout  ),

	.char_cpu_addr   ( char_cpu_addr   ),
	.char_cpu_din    ( char_cpu_din    ),
	.char_cpu_we     ( char_cpu_we     ),
	.char_cpu_dout   ( char_dout       ),
	.char_gfx_addr   ( char_gfx_addr   ),
	.char_gfx_dout   ( char_gfx_dout   )
);

// ---------------------------------------------------------------------------
// The sound board exposes native unsigned sources to JTFRAME's audio mixer.
// ---------------------------------------------------------------------------

jtnemsis_sound u_sound(
	.clk              ( clk               ),
	.cpu_cen          ( sndcpu_cen        ),
	.cen_3p5          ( cen_3p5           ),
	.cen_1p7          ( cen_1p7           ),
	.audio_div_cen    ( audio_div_cen     ),

	.rst              ( rst               ),
	.main_db          ( sound_db          ),
	.data_n           ( data_n            ),
	.sound_on_n       ( sound_on_n        ),

	.z80_cs           ( audio_cs          ),
	.z80_addr         ( audio_addr        ),
	.z80_data         ( audio_data        ),

	.wav1_addr        ( wav1_addr         ),
	.wav1_vol_addr    ( wav1_vol_addr     ),
	.wav2_addr        ( wav2_addr         ),
	.wav2_vol_addr    ( wav2_vol_addr     ),
	.wav1_data        ( wav1_data         ),
	.wav1_vol_data    ( wav1_vol_data     ),
	.wav2_data        ( wav2_data         ),
	.wav2_vol_data    ( wav2_vol_data     ),

	.ay7e             ( ay7e              ),
	.ay8e             ( ay8e              ),
	.wav1             ( wav1              ),
	.wav2             ( wav2              ),
	.rc33_en          ( rc33_en           ),
	.rc47_en          ( rc47_en           ),
	.debug_bus        ( debug_bus         ),
	.st_dout          ( st_sound          )
);

endmodule
