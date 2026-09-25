/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    Author: Andrea Bogazzi.
    Date: 5-2026 */

// ============================================================================
// jttaitob_game — top-level wrapper for the Taito B System core
// ============================================================================
//
// First target: Rastan Saga 2 / Nastar / Nastar Warrior (rastsag2 set).
//
// Wires together:
//   • jttaitob_main  (68000 @ 12 MHz + work RAM + palette RAM + VRAM +
//                     sprite/scroll RAM + VCU ctrl regs + chip selects)
//   • jttaitob_snd   (Z80 @ 4 MHz + YM2610 @ 8 MHz)
//   • jttaitob_syt   (TC0140SYT — main↔Z80 sound comms)
//   • jttaitob_ioc   (TC0220IOC — DIPs + cabinet inputs + coin/lockout)
//   • jttaitob_video (stub — palette viewer; real TC0180VCU pipeline TBD)
//   • jttaitob_colmix(TC0260DAR passive palette DAC → RGB)
//   • jtframe_cen48  (clock enables for 12 / 8 / 4 MHz)
//   • jtframe_vtimer (320×224 raster at 8 MHz pxl_cen ≈ 60 Hz)
//
// First-iteration scope: 68k spine + sound subsystem + video timing.
// The video output is a palette-viewer (whatever the 68k writes to
// palette becomes visible as a grid). Real tile/sprite pipeline lands
// once the TC0180VCU bring-up starts.
// ============================================================================

module jttaitob_game(
    `include "jtframe_game_ports.inc"
);

// ─────────────────────────────────────────────────────────────────────────────
// Wires between submodules
// ─────────────────────────────────────────────────────────────────────────────
wire [23:1] cpu_addr;
wire [ 1:0] main_dsn;
wire [15:0] main_dout;
wire        main_rnw;

// Sound: jt10 stereo output (framework auto-generates fm_l/fm_r as outputs
// because cfg/mem.yaml declares an `fm` channel).
wire signed [15:0] fm_l_w, fm_r_w;
assign fm_l = fm_l_w;
assign fm_r = fm_r_w;

`ifdef JTFRAME_IOCTL_RD
    assign ioctl_din = 8'h0;
`endif

// TC0140SYT master side wires (68k <-> SYT)
wire        syt_cs_w, syt_addr_w, syt_we_w;
wire [ 3:0] syt_din_w, syt_dout_w;

// TC0220IOC bus
wire        ioc_cs_w, ioc_rnw_w, ioc_lds_n_w;
wire [ 3:0] ioc_addr_w;
wire [ 7:0] ioc_din_w, ioc_dout_w;

// VCU ctrl regs (latched in main.v, consumed in video.v)
wire [127:0] vcu_ctrl_w;

// Video subsystem BRAM port-B
wire [11:0] pal_addr_b_w;
wire [15:0] pal_dout_b_w;
wire [14:0] vram_addr_b_w;
wire [15:0] vram_dout_b_w;
wire [12:0] oram_addr_b_w;
wire [15:0] oram_dout_b_w;

// DIP slicing — JTFRAME packs the dipsw into 32 bits low-to-high
wire [ 7:0] dipsw_a = dipsw[ 7:0];
wire [ 7:0] dipsw_b = dipsw[15:8];

// Cabinet I/O packing — TAITO_B_SYSTEM_INPUT layout (taito_b.cpp:664).
// Taito B uses TAITO_JOY_UDLR_2_BUTTONS (NOT the `_START` variant); the
// START buttons live on IN2, not IN0/IN1.
//
//   IN0/IN1 (TAITO_JOY_UDLR_2_BUTTONS):
//     bit 0 = UP        (active low)
//     bit 1 = DOWN
//     bit 2 = LEFT
//     bit 3 = RIGHT
//     bit 4 = BUTTON1
//     bit 5 = BUTTON2
//     bit 6 = unused (1)
//     bit 7 = unused (1)
//
//   IN2 (TAITO_B_SYSTEM_INPUT):
//     bit 0 = TILT      (active low)
//     bit 1 = SERVICE1
//     bit 2 = COIN1
//     bit 3 = COIN2
//     bit 4 = unused (1)
//     bit 5 = unused (1)
//     bit 6 = START1
//     bit 7 = START2
//
// joystick1[5:0] = {B2, B1, R, L, D, U} after JTFRAME_JOY_RLDU bit-swap,
// which matches MAME's IN0[5:0] verbatim.
wire [ 7:0] cab_in0 = { 2'b11, joystick1[5:0] };
wire [ 7:0] cab_in1 = { 2'b11, joystick2[5:0] };
wire [ 7:0] cab_in2 = { cab_1p[1], cab_1p[0], 2'b11, coin[1], coin[0], service, tilt };

// Debug merging
wire [ 7:0] main_st, snd_st;
assign st_dout    = (debug_bus[7]) ? snd_st : main_st;
assign debug_view = main_st;
assign dip_flip   = 1'b0;

// ─────────────────────────────────────────────────────────────────────────────
// Clock enables (48 MHz → 12 / 8 / 4 / 3 MHz etc.)
// ─────────────────────────────────────────────────────────────────────────────
wire cen12, cen8, cen4, cen6, cen3, cen3q, cen1p5;
wire cen16, cen4_12;
wire cen16b, cen12b, cen6b, cen3b, cen3qb, cen1p5b;

jtframe_cen48 u_cen48(
    .clk      ( clk      ),
    .cen12    ( cen12    ),
    .cen16    ( cen16    ),
    .cen8     ( cen8     ),
    .cen6     ( cen6     ),
    .cen4     ( cen4     ),
    .cen4_12  ( cen4_12  ),
    .cen3     ( cen3     ),
    .cen3q    ( cen3q    ),
    .cen1p5   ( cen1p5   ),
    .cen16b   ( cen16b   ),
    .cen12b   ( cen12b   ),
    .cen6b    ( cen6b    ),
    .cen3b    ( cen3b    ),
    .cen3qb   ( cen3qb   ),
    .cen1p5b  ( cen1p5b  )
);

// Suppress lint warnings on cens we don't currently use
/* verilator lint_off UNUSED */
wire _unused_cens = cen12 | cen16 | cen6 | cen4_12 | cen3 | cen3q | cen1p5 |
                    cen16b | cen12b | cen6b | cen3b | cen3qb | cen1p5b;
/* verilator lint_on UNUSED */

// ─────────────────────────────────────────────────────────────────────────────
// 68k main CPU subsystem
// ─────────────────────────────────────────────────────────────────────────────
jttaitob_main u_main(
    .rst        ( rst48              ),
    .clk        ( clk48              ),
    .LVBL       ( LVBL               ),
    .LHBL       ( LHBL               ),
    .dip_pause  ( dip_pause          ),

    // ROM (SDRAM bank 0, "main" bus from mem.yaml)
    .cpu_addr   ( cpu_addr           ),
    .main_addr  ( main_addr          ),
    .main_dsn   ( main_dsn           ),
    .main_dout  ( main_dout          ),
    .main_rnw   ( main_rnw           ),
    .rom_cs     ( main_cs            ),
    .rom_data   ( main_data          ),
    .rom_ok     ( main_ok            ),

    // Video BRAM port-B
    .pal_addr_b  ( pal_addr_b_w      ),
    .pal_dout_b  ( pal_dout_b_w      ),
    .vram_addr_b ( vram_addr_b_w     ),
    .vram_dout_b ( vram_dout_b_w     ),
    .oram_addr_b ( oram_addr_b_w     ),
    .oram_dout_b ( oram_dout_b_w     ),
    .vcu_ctrl    ( vcu_ctrl_w        ),

    // TC0140SYT master port
    .syt_cs      ( syt_cs_w          ),
    .syt_addr    ( syt_addr_w        ),
    .syt_we      ( syt_we_w          ),
    .syt_din     ( syt_din_w         ),
    .syt_dout    ( syt_dout_w        ),

    // TC0220IOC
    .ioc_cs      ( ioc_cs_w          ),
    .ioc_addr    ( ioc_addr_w        ),
    .ioc_rnw     ( ioc_rnw_w         ),
    .ioc_lds_n   ( ioc_lds_n_w       ),
    .ioc_din     ( ioc_din_w         ),
    .ioc_dout    ( ioc_dout_w        ),

    .debug_bus  ( debug_bus          ),
    .st_dout    ( main_st            )
);

// ─────────────────────────────────────────────────────────────────────────────
// TC0140SYT — sound-comm chip between 68k and Z80
// ─────────────────────────────────────────────────────────────────────────────
wire        snd_rom_cs_w, snd_ram_cs_w, snd_ym_cs_w, snd_syt_sel_w;
wire [ 1:0] snd_rom_a16_w;
wire        snd_rst_w, snd_nmi_n_w;
wire [ 7:0] syt_z80_dout;
wire [15:0] z80_addr_w;
wire [ 7:0] z80_dout_w;
wire        z80_mreq_n_w, z80_rd_n_w, z80_wr_n_w;

jttaitob_syt u_syt(
    .rst        ( rst48              ),
    .clk        ( clk48              ),

    // 68k master
    .main_cs    ( syt_cs_w           ),
    .main_addr  ( syt_addr_w         ),
    .main_dout  ( syt_din_w          ),
    .main_din   ( syt_dout_w         ),
    .main_we    ( syt_we_w           ),

    // Z80 slave
    .snd_addr   ( z80_addr_w         ),
    .snd_dout   ( z80_dout_w         ),
    .snd_din    ( syt_z80_dout       ),
    .snd_mreq_n ( z80_mreq_n_w       ),
    .snd_rd_n   ( z80_rd_n_w         ),
    .snd_wr_n   ( z80_wr_n_w         ),

    .snd_rom_cs ( snd_rom_cs_w       ),
    .snd_rom_a16( snd_rom_a16_w      ),
    .snd_ram_cs ( snd_ram_cs_w       ),
    .snd_ym_cs  ( snd_ym_cs_w        ),
    .snd_syt_sel( snd_syt_sel_w      ),
    .snd_rst    ( snd_rst_w          ),
    .snd_nmi_n  ( snd_nmi_n_w        )
);

// ─────────────────────────────────────────────────────────────────────────────
// Z80 + YM2610 sound subsystem
// ─────────────────────────────────────────────────────────────────────────────
jttaitob_snd u_snd(
    .rst         ( rst48             ),
    .clk         ( clk48             ),
    .cen_z80     ( cen4              ),
    .cen_ym      ( cen8              ),

    .snd_rom_cs  ( snd_rom_cs_w      ),
    .snd_rom_a16 ( snd_rom_a16_w     ),
    .snd_ram_cs  ( snd_ram_cs_w      ),
    .snd_ym_cs   ( snd_ym_cs_w       ),
    .snd_syt_sel ( snd_syt_sel_w     ),
    .snd_rst_soft( snd_rst_w         ),
    .snd_nmi_n   ( snd_nmi_n_w       ),
    .syt_dout_z80( syt_z80_dout      ),

    .z80_addr    ( z80_addr_w        ),
    .z80_dout    ( z80_dout_w        ),
    .z80_mreq_n  ( z80_mreq_n_w      ),
    .z80_rd_n    ( z80_rd_n_w        ),
    .z80_wr_n    ( z80_wr_n_w        ),

    .rom_addr    ( snd_addr          ),
    .rom_cs      ( snd_cs            ),
    .rom_data    ( snd_data          ),
    .rom_ok      ( snd_ok            ),

    .adpcma_addr ( adpcma_addr       ),
    .adpcma_cs   ( adpcma_cs         ),
    .adpcma_data ( adpcma_data       ),
    .adpcma_ok   ( adpcma_ok         ),

    .adpcmb_addr ( adpcmb_addr       ),
    .adpcmb_cs   ( adpcmb_cs         ),
    .adpcmb_data ( adpcmb_data       ),
    .adpcmb_ok   ( adpcmb_ok         ),

    .fm_l        ( fm_l_w            ),
    .fm_r        ( fm_r_w            ),

    .debug_bus   ( debug_bus         ),
    .st_dout     ( snd_st            )
);

// ─────────────────────────────────────────────────────────────────────────────
// TC0220IOC — I/O controller
// ─────────────────────────────────────────────────────────────────────────────
jttaitob_ioc u_ioc(
    .rst        ( rst48              ),
    .clk        ( clk48              ),

    .cs         ( ioc_cs_w           ),
    .addr       ( ioc_addr_w         ),
    .rnw        ( ioc_rnw_w          ),
    .lds_n      ( ioc_lds_n_w        ),
    .din        ( ioc_din_w          ),
    .dout       ( ioc_dout_w         ),

    .dipsw_a    ( dipsw_a            ),
    .dipsw_b    ( dipsw_b            ),
    .in0        ( cab_in0            ),
    .in1        ( cab_in1            ),
    .in2        ( cab_in2            )
);

// ─────────────────────────────────────────────────────────────────────────────
// Video timing — 320×224 active, ~60 Hz at 7 MHz pxl_cen
// ─────────────────────────────────────────────────────────────────────────────
// 7 MHz × (448 cols × 260 rows)⁻¹ ≈ 60.10 Hz refresh, 15.625 kHz H-rate.
// Active: hdump 0..319 (320 cols visible).
//         vdump 15..238 (224 rows visible).
// H-blank = 128 px (320..447) → ~878 clk @48MHz, enough for the sequential
// BG/FG/TX ring fills (~840 clk). Image width 71% of the line.
wire [8:0] hdump_v, vdump_v, vrender_v;

jtframe_vtimer #(
    .HB_START ( 9'd320 ),    // visible 0..319, blanking 320..447
    .HS_START ( 9'd368 ),    // HS pulse 368..395 (27 cyc, ~3.9us @7MHz), centered
    .HCNT_END ( 9'd447 ),    // 448-col cycle
    .HB_END   ( 9'd0   ),
    .V_START  ( 9'd000 ),
    .VS_START ( 9'd245 ),    // VS pulse 245..247 (3 rows)
    .VB_START ( 9'd239 ),    // visible ends after row 238 (15 + 224 = 239)
    .VCNT_END ( 9'd259 ),    // 260-row cycle
    .VB_END   ( 9'd015 )     // visible begins at row 15
) u_vtimer(
    .clk        ( clk     ),
    .pxl_cen    ( pxl_cen ),
    .vdump      ( vdump_v ),
    .vrender    ( vrender_v ),
    .vrender1   (         ),
    .H          ( hdump_v ),
    .Hinit      (         ),
    .Vinit      (         ),
    .LHBL       ( LHBL    ),
    .LVBL       ( LVBL    ),
    .HS         ( HS      ),
    .VS         ( VS      )
);

/* verilator lint_off UNUSED */
wire _unused_vrender = |vrender_v;
/* verilator lint_on UNUSED */

// ─────────────────────────────────────────────────────────────────────────────
// Video pipeline (stub — palette viewer)
// ─────────────────────────────────────────────────────────────────────────────
wire [11:0] pal_idx_w;

jttaitob_video u_video(
    .rst         ( rst48             ),
    .clk         ( clk48             ),
    .pxl_cen     ( pxl_cen           ),

    .LHBL        ( LHBL              ),
    .LVBL        ( LVBL              ),
    .vdump       ( vdump_v           ),
    .vrender     ( vrender_v         ),
    .hdump       ( hdump_v           ),

    .vcu_ctrl    ( vcu_ctrl_w        ),

    .vram_addr_b ( vram_addr_b_w     ),
    .vram_dout_b ( vram_dout_b_w     ),
    .oram_addr_b ( oram_addr_b_w     ),
    .oram_dout_b ( oram_dout_b_w     ),

    // SDRAM bank 2 (gfx ROM) — three buses share the 1 MB region:
    //   bg  → BG plane gfx
    //   obj → FG plane gfx (sprites take this in Phase 3d)
    //   tx  → text plane gfx
    .bg_addr     ( bg_addr           ),
    .bg_cs       ( bg_cs             ),
    .bg_data     ( bg_data           ),
    .bg_ok       ( bg_ok             ),
    .obj_addr    ( obj_addr          ),
    .obj_cs      ( obj_cs            ),
    .obj_data    ( obj_data          ),
    .obj_ok      ( obj_ok            ),
    .tx_addr     ( tx_addr           ),
    .tx_cs       ( tx_cs             ),
    .tx_data     ( tx_data           ),
    .tx_ok       ( tx_ok             ),
    .fg_addr     ( fg_addr           ),
    .fg_cs       ( fg_cs             ),
    .fg_data     ( fg_data           ),
    .fg_ok       ( fg_ok             ),

    .pal_idx     ( pal_idx_w         )
);

// ─────────────────────────────────────────────────────────────────────────────
// Colour mixer (TC0260DAR)
// ─────────────────────────────────────────────────────────────────────────────
jttaitob_colmix u_colmix(
    .rst        ( rst48              ),
    .clk        ( clk48              ),
    .pxl_cen    ( pxl_cen            ),

    .LHBL       ( LHBL               ),
    .LVBL       ( LVBL               ),

    .pal_idx    ( pal_idx_w          ),

    .pal_addr_b ( pal_addr_b_w      ),
    .pal_dout_b ( pal_dout_b_w      ),

    .red        ( red                ),
    .green      ( green              ),
    .blue       ( blue               )
);

// obj bus driven by video.v (FG plane in Phase 3a).

endmodule
