/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later */

// jtmnymny_game.v — Money Money (Zaccaria Z80uP) top level

module jtmnymny_game(
    `include "jtframe_game_ports.inc"
);

wire [11:0] cpu_addr;
wire [ 7:0] cpu_dout, snd_latch;
wire [ 8:0] pal_addr;
wire        cpu_wrn, vram_cs, attr_cs, objram_cs;
wire        flip_x, flip_y, ressound, coin_cnt, nmi_mask, acs;
wire [ 7:0] ay4g_a, ay4g_b, ay4g_c, ay4h_a, ay4h_b, ay4h_c, dac;
wire signed [13:0] speech;
wire [ 4:0] ioa;
wire        level, levelt, sw1;

wire [ 7:0] p1_in, p2_in, coins_in;
wire [ 3:0] sys_in;

// jtframe cab inputs are already active low, like the PCB (JTFRAME_JOY_DURL order)
assign p1_in    = { 1'b1, joystick1[3], joystick1[2], joystick1[4], 2'b11, joystick1[1], joystick1[0] };
assign p2_in    = { 1'b1, joystick2[3], joystick2[2], joystick2[4], 2'b11, joystick2[1], joystick2[0] };
assign sys_in   = { 1'b1, tilt, cab_1p[1], cab_1p[0] };
assign coins_in = { 4'b0000, acs, coin[2], coin[1], coin[0] };

// BRAM wiring (CPU side)
assign wram_addr   = cpu_addr[10:0];
assign wram_din    = cpu_dout;
assign vram_addr   = cpu_addr[10:0];
assign vram_din    = cpu_dout;
assign vram_we     = vram_cs   & ~cpu_wrn;
assign attr_addr   = cpu_addr[5:0];
assign attr_din    = cpu_dout;
assign attr_we     = attr_cs   & ~cpu_wrn;
assign objram_addr = cpu_addr[7:0];
assign objram_din  = cpu_dout;
assign objram_we   = objram_cs & ~cpu_wrn;
assign pal9f_addr  = pal_addr;
assign pal9g_addr  = pal_addr;

assign dip_flip   = flip_x;

// MRA header byte 0, bit 0: game select for the protection PAL
reg jackrabt=0;
always @(posedge clk) begin
    if( header && prog_we && prog_addr[2:0]==0 ) jackrabt <= prog_data[0];
end

assign debug_view = 0;
`ifdef JTFRAME_IOCTL_RD
assign ioctl_din  = 0;   // wram dump is handled by the mem.yaml wrapper
`endif

// 1B11142 analog network model, coefficients from ver/audio
jtmnymny_mixer u_mixer(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( mix_cen       ),
    .ay4g_a     ( ay4g_a        ),
    .ay4g_b     ( ay4g_b        ),
    .ay4g_c     ( ay4g_c        ),
    .ay4h_a     ( ay4h_a        ),
    .ay4h_b     ( ay4h_b        ),
    .speech     ( speech        ),
    .dac        ( dac           ),
    .ioa        ( ioa           ),
    .level      ( level         ),
    .levelt     ( levelt        ),
    .sw1        ( sw1           ),
    .music      ( music         ),
    .voice      ( voice         ),
    .pcm        ( pcm           )
);

jtmnymny_main u_main(
    .rst        ( rst           ),
    .jackrabt   ( jackrabt      ),
    .clk        ( clk           ),
    .cpu_cen    ( cpu_cen       ),
    .LVBL       ( LVBL          ),
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_dout   ( cpu_dout      ),
    .cpu_wrn    ( cpu_wrn       ),
    .vram_cs    ( vram_cs       ),
    .attr_cs    ( attr_cs       ),
    .objram_cs  ( objram_cs     ),
    .ram_we     ( wram_we       ),
    .vram_dout  ( vram_dout     ),
    .attr_dout  ( attr_dout     ),
    .objram_dout( objram_dout   ),
    .ram_dout   ( wram_dout     ),
    .flip_x     ( flip_x        ),
    .flip_y     ( flip_y        ),
    .ressound   ( ressound      ),
    .coin_cnt   ( coin_cnt      ),
    .nmi_mask   ( nmi_mask      ),
    .snd_latch  ( snd_latch     ),
    .acs        ( acs           ),
    .p1_in      ( p1_in         ),
    .p2_in      ( p2_in         ),
    .sys_in     ( sys_in        ),
    .coins_in   ( coins_in      ),
    .dipsw_a    ( dipsw[ 7:0]   ),
    .dipsw_b    ( dipsw[15:8]   ),
    .dipsw_c    ( dipsw[23:16]  )
);

jtmnymny_snd u_snd(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .mcpu_cen   ( mcpu_cen      ),
    .psg_cen    ( psg_cen       ),
    .tms_cen    ( tms_cen       ),
    .ressound   ( ressound      ),
    .snd_latch  ( snd_latch     ),
    .acs        ( acs           ),
    .melody_cs  ( melody_cs     ),
    .melody_addr( melody_addr   ),
    .melody_data( melody_data   ),
    .melody_ok  ( melody_ok     ),
    .speech_cs  ( speech_cs     ),
    .speech_addr( speech_addr   ),
    .speech_data( speech_data   ),
    .speech_ok  ( speech_ok     ),
    .ay4g_a     ( ay4g_a        ),
    .ay4g_b     ( ay4g_b        ),
    .ay4g_c     ( ay4g_c        ),
    .ay4h_a     ( ay4h_a        ),
    .ay4h_b     ( ay4h_b        ),
    .ay4h_c     ( ay4h_c        ),
    .speech     ( speech        ),
    .dac        ( dac           ),
    .ioa        ( ioa           ),
    .level      ( level         ),
    .levelt     ( levelt        ),
    .sw1        ( sw1           )
);

jtmnymny_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .pxl2_cen   ( pxl2_cen      ),
    .flip_x     ( flip_x        ),
    .flip_y     ( flip_y        ),
    .vram_v_addr( vram_v_addr   ),
    .vram_v_dout( vram_v_dout   ),
    .attr_v_addr( attr_v_addr   ),
    .attr_v_dout( attr_v_dout   ),
    .objram_v_addr( objram_v_addr ),
    .objram_v_dout( objram_v_dout ),
    .pal_addr   ( pal_addr      ),
    .pal9f_data ( pal9f_data    ),
    .pal9g_data ( pal9g_data    ),
    .scr_addr   ( scr_addr      ),
    .scr_cs     ( scr_cs        ),
    .scr_data   ( scr_data      ),
    .scr_ok     ( scr_ok        ),
    .objgfx_addr( objgfx_addr   ),
    .objgfx_cs  ( objgfx_cs     ),
    .objgfx_data( objgfx_data   ),
    .objgfx_ok  ( objgfx_ok     ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            )
);

endmodule
