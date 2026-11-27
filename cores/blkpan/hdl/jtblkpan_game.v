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

    Author: Andrea Bogazzi
    Date: 2026

    Black Panther (Konami GX604, 1987). */

module jtblkpan_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

reg  [ 2:0] clk6_holder = 3'd0;
wire        cen12, cen6, cen6b, clk6;
wire        hflip, vflip, main_hflip, main_vflip;
wire        chacs_n, objram_n, vcs1, vcs2, vzcs;
wire [15:1] video_addr;
wire [15:0] video_dout;
wire        main_uds_n, main_lds_n, main_rw_n;
wire        preLHBL, vblank, h1_n, h2;
wire [14:0] rgb, rgb_blk;
reg  [14:0] rgb_dly;

wire [ 7:0] snd_latch;
wire        snd_irq;
wire [ 7:0] in0, in1, in2;

assign dip_flip = 0;
assign debug_view = 0;

`ifdef SIMSCENE
jtblkpan_intlatch_mmr #(
    .SIMFILE ( "mmr.bin" )
) u_intlatch(
    .rst        ( rst   ),
    .clk        ( clk   ),
    .cs         ( 1'b0  ),
    .addr       ( 2'd0  ),
    .rnw        ( 1'b1  ),
    .din        ( 8'd0  ),
    .hflip      ( hflip ),
    .vflip      ( vflip ),
    .ioctl_addr ( 2'd0  ),
    .ioctl_din  (       ),
    .debug_bus  ( 8'd0  ),
    .st_dout    (       )
);
`else
assign hflip = main_hflip;
assign vflip = main_vflip;
`endif

// ---------------------------------------------------------------------------
// Cabinet. Black Panther's ports are IP_ACTIVE_HIGH (unusual -- Nemesis and
// most other boards are active low), so jtframe's idle-high signals are
// inverted here. The DIP bits embedded in IN0/IN1 come straight from dipsw,
// which already carries the true MAME port value.
//   IN0: b0 COIN1  b1 COIN2  b2 SERVICE1  b3 START1  b4 START2
//        b5 flip screen, b7:6 continue        (dipsw[23:21])
//   IN1: b0 LEFT b1 RIGHT b2 UP b3 DOWN b4 BTN1 b5 BTN2, b7 service mode
//        (dipsw[31], active low in MAME)
// ---------------------------------------------------------------------------
assign in0 = { dipsw[23:21], ~cab_1p[1], ~cab_1p[0], ~service, ~coin[1], ~coin[0] };
assign in1 = { dipsw[31], 1'b0, ~joystick1[5], ~joystick1[4],
               ~joystick1[2], ~joystick1[3], ~joystick1[0], ~joystick1[1] };
assign in2 = { 2'b00,      ~joystick2[5], ~joystick2[4],
               ~joystick2[2], ~joystick2[3], ~joystick2[0], ~joystick2[1] };

assign cen12 = pxl2_cen;
assign cen6  = pxl_cen;
assign clk6  = clk6_holder <= 3'd4;
assign cen6b = clk6_holder == 3'd4;

always @(posedge clk)
    clk6_holder <= cen6 ? 3'd0 : clk6_holder + 3'd1;

jtblkpan_main u_main(
    .clk         ( clk           ),
    .rst         ( rst           ),

    .o_addr      ( video_addr    ),
    .o_dout      ( main_dout     ),
    .i_video_din ( video_dout    ),
    .o_rw_n      ( main_rw_n     ),
    .o_uds_n     ( main_uds_n    ),
    .o_lds_n     ( main_lds_n    ),
    .o_chacs_n   ( chacs_n       ),
    .o_objram_n  ( objram_n      ),
    .o_vcs1      ( vcs1          ),
    .o_vcs2      ( vcs2          ),
    .o_vzcs      ( vzcs          ),
    .o_hflip     ( main_hflip    ),
    .o_vflip     ( main_vflip    ),
    .i_vbl       ( vblank        ),
    .i_clk6      ( clk6          ),
    .i_h1_n      ( h1_n          ),
    .i_h2        ( h2            ),

    .o_pal_addr  ( palcpu_addr   ),
    .o_pal_we    ( palcpu_we     ),
    .i_pal_dout  ( palcpu_dout   ),

    .o_snd_latch ( snd_latch     ),
    .o_snd_irq   ( snd_irq       ),

    .i_in0       ( in0           ),
    .i_in1       ( in1           ),
    .i_in2       ( in2           ),
    .i_dsw0      ( dipsw[ 7:0]   ),
    .i_dsw1      ( dipsw[15:8]   ),

    .o_rom_cs    ( main_cs       ),
    .o_rom_addr  ( main_addr     ),
    .i_rom_data  ( main_data     ),
    .i_rom_ok    ( main_ok       ),

    .o_ram_cs    ( workram_cs    ),
    .o_ram_we    ( workram_we    ),
    .o_ram_dsn   ( workram_dsn   ),
    .o_ram_addr  ( workram_addr  ),
    .i_ram_data  ( workram_data  ),
    .i_ram_ok    ( workram_ok    )
);

`ifndef NOSOUND
jtblkpan_snd u_snd(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .cen_z80    ( cen3p5     ),
    .cen_fm     ( cen3p5     ),
    .cen_fm2    ( cen1p7     ),
    .cen_pcm    ( cen3p5     ),

    .i_latch    ( snd_latch  ),
    .i_irq      ( snd_irq    ),

    .rom_cs     ( snd_cs     ),
    .rom_addr   ( snd_addr   ),
    .rom_data   ( snd_data   ),
    .rom_ok     ( snd_ok     ),

    .ram_addr   ( sndram_addr ),
    .ram_din    ( sndram_din  ),
    .ram_we     ( sndram_we   ),
    .ram_dout   ( sndram_dout ),

    .pcma_addr  ( pcma_addr  ),
    .pcma_dout  ( pcma_data  ),
    .pcma_cs    ( pcma_cs    ),
    .pcma_ok    ( pcma_ok    ),
    .pcmb_addr  ( pcmb_addr  ),
    .pcmb_dout  ( pcmb_data  ),
    .pcmb_cs    ( pcmb_cs    ),
    .pcmb_ok    ( pcmb_ok    ),

    .fm_l       ( fm_l       ),
    .fm_r       ( fm_r       ),
    .pcm        ( pcm        ),

    .debug_bus  ( debug_bus  )
);
`else
assign { snd_addr, pcma_addr, pcmb_addr } = 49'd0;
assign { snd_cs, pcma_cs, pcmb_cs } = 3'd0;
assign { sndram_addr, sndram_din, sndram_we } = 20'd0;
assign { fm_l, fm_r, pcm } = 43'd0;
`endif

jtnemsis_gx400a_video u_video(
    .clk                ( clk             ),
    .rst                ( rst             ),
    .pxl_cen            ( cen6            ),
    .pxl_cenb           ( cen6b           ),
    .clk6               ( clk6            ),
    .hflip              ( hflip           ),
    .vflip              ( vflip           ),
    .inter_non          ( 1'b0            ),
    .resolution_288_256 ( 1'b0            ),
    .gfx_en             ( gfx_en          ),

    .HS                 ( HS              ),
    .VS                 ( VS              ),
    .preLHBL            ( preLHBL         ),
    .vblank             ( vblank          ),
    .pal_addr           ( pal_addr        ),
    .color_source       (                 ),
    .h1_n               ( h1_n            ),
    .h2                 ( h2              ),
    .v256               (                 ),

    .cpu_addr           ( video_addr      ),
    .cpu_din            ( main_dout       ),
    .cpu_dout           ( video_dout      ),
    .uds_n              ( main_uds_n      ),
    .lds_n              ( main_lds_n      ),
    .rnw                ( main_rw_n       ),
    .chacs_n            ( chacs_n         ),
    .objram_n           ( objram_n        ),
    .vcs1               ( vcs1            ),
    .vcs2               ( vcs2            ),
    .vzcs               ( vzcs            ),

    .scroll_cpu_addr    ( scroll_cpu_addr ),
    .scroll_cpu_din     ( scroll_cpu_din  ),
    .scroll_cpu_we      ( scroll_cpu_we   ),
    .scroll_cpu_dout    ( scroll_dout     ),
    .scroll_gfx_addr    ( scroll_gfx_addr ),
    .scroll_gfx_dout    ( scroll_gfx_dout ),

    .obj_cpu_addr       ( obj_cpu_addr    ),
    .obj_cpu_din        ( obj_cpu_din     ),
    .obj_cpu_we         ( obj_cpu_we      ),
    .obj_cpu_dout       ( obj_dout        ),
    .obj_gfx_addr       ( obj_gfx_addr    ),
    .obj_gfx_dout       ( obj_gfx_dout    ),

    .vram1_cpu_addr     ( vram1_cpu_addr  ),
    .vram1_cpu_din      ( vram1_cpu_din   ),
    .vram1_cpu_we       ( vram1_cpu_we    ),
    .vram1_cpu_dout     ( vram1_dout      ),
    .vram_gfx_addr      ( vram_gfx_addr   ),
    .vram1_gfx_dout     ( vram1_gfx_dout  ),

    .vram2_cpu_addr     ( vram2_cpu_addr  ),
    .vram2_cpu_din      ( vram2_cpu_din   ),
    .vram2_cpu_we       ( vram2_cpu_we    ),
    .vram2_cpu_dout     ( vram2_dout      ),
    .vram2_gfx_addr     ( vram2_gfx_addr  ),
    .vram2_gfx_dout     ( vram2_gfx_dout  ),

    .char_cpu_addr      ( char_cpu_addr   ),
    .char_cpu_din       ( char_cpu_din    ),
    .char_cpu_we        ( char_cpu_we     ),
    .char_cpu_dout      ( char_dout       ),
    .char_gfx_addr      ( char_gfx_addr   ),
    .char_gfx_dout      ( char_gfx_dout   )
);

// ---------------------------------------------------------------------------
// Colour. xBGR_555 straight out of the palette RAM -- no resistor-ladder LUT
// on this board (MAME: PALETTE(...).set_format(palette_device::xBGR_555)).
// ---------------------------------------------------------------------------
assign rgb      = { pal_dout[14:10], pal_dout[9:5], pal_dout[4:0] }; // B,G,R
assign { blue, green, red } = rgb_blk;

always @(posedge clk) if(cen6)
    rgb_dly <= rgb;

jtframe_blank #( .DLY(0), .DW(15) ) u_blank(
    .clk      ( clk      ),
    .pxl_cen  ( cen6     ),
    .preLHBL  ( preLHBL  ),
    .preLVBL  ( ~vblank  ),
    .LHBL     ( LHBL     ),
    .LVBL     ( LVBL     ),
    .preLBL   (          ),
    .rgb_in   ( rgb_dly  ),
    .rgb_out  ( rgb_blk  )
);

endmodule
