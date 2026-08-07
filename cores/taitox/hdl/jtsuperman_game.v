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
    Date: 5-2026 */

// ============================================================================
// jtsuperman_game — top-level wrapper for the Taito X System core
// ============================================================================
//
// Instantiates the three game halves (main, video, sound), the TC0140SYT
// sound-comm chip, and the cabinet I/O glue. The framework-generated
// memory port set (from cfg/mem.yaml) is pulled in by
// jtframe_game_ports.inc.
//
// First-iteration scope: bring up the 68k spine + video timing + silent
// sound. The video subsystem's CPU-side wiring is intentionally stubbed
// with zeros — the kiwi-derived jtsuperman_video.v still expects 8-bit
// TNZS-shaped buses. Rewiring it to the 68k's 16-bit buses is a follow-up
// commit; for now the video pipeline clocks through frames and produces
// black output. That's enough to validate the framework + timing.
// ============================================================================

module jtsuperman_game(
    `include "jtframe_game_ports.inc"
);

// ─────────────────────────────────────────────────────────────────────────────
// Wires between submodules
// ─────────────────────────────────────────────────────────────────────────────

// 68k bus to SDRAM. main_addr/data/cs/ok and ram_addr/data/cs/ok come from
// mem_ports.inc (auto-gen). main_dsn/main_dout/main_rnw are exposed by
// jtsuperman_main as named ports; declare local helper wires for them.
wire [23:1] cpu_addr;
wire [ 1:0] main_dsn;
wire [15:0] main_dout;
wire        main_rnw;

// Sound: jt10 stereo output. The framework's mem_ports.inc auto-generates
// fm_l/fm_r as outputs because cfg/mem.yaml declares an `fm` channel.
wire signed [15:0] fm_l_w, fm_r_w;
assign fm_l = fm_l_w;
assign fm_r = fm_r_w;

// IOCTL register read — drive 0 (no debug regs surfaced yet)
`ifdef JTFRAME_IOCTL_RD
    assign ioctl_din = 8'h0;
`endif

// TC0140SYT master side (main ↔ syt) — local wires
wire        syt_cs_w, syt_addr_w, syt_we_w;
wire [ 3:0] syt_din_w, syt_dout_w;

// C-chip bus (main ↔ jtsuperman_cchip)
wire        cchip_cs_w, cchip_we_w, cchip_lds_n_w, cchip_int_n_w;
wire [11:1] cchip_addr_w;
wire [ 7:0] cchip_din_w, cchip_dout_w;

// DIP slicing — JTFRAME packs the dipsw into 32 bits low-to-high
wire [ 7:0] dipsw_a = dipsw[ 7:0];
wire [ 7:0] dipsw_b = dipsw[15:8];

// Cabinet I/O packing — joystick1 / joystick2 / coin / cab_1p / service / tilt
// arrive from JTFRAME. Pack to match MAME taito_x.cpp's IN0/IN1/IN2:
//
//   IN0 / IN1 = TAITO_JOY_UDLR_2_BUTTONS_START( N ):
//     bit 0..3: UP, DOWN, LEFT, RIGHT (active low)
//     bit 4..5: BUTTON1, BUTTON2      (active low)
//     bit 6   : STARTn                (active low)
//     bit 7   : unused (1)
//
//   IN2 (Superman input port):
//     bit 0   : COIN1                 (active low)
//     bit 1   : COIN2                 (active low)
//     bit 2   : SERVICE1              (active low)
//     bit 3   : TILT                  (active low)
//     bit 4..7: unused (1)
//
// JTFRAME polarities at game.v level: joystick*, coin, cab_1p, service,
// and tilt are ALL active LOW (pressed = 0).  test.cpp drives each at 1
// for idle and 0 for pressed, matching MAME's IN0/IN1/IN2 convention, so
// nothing is inverted here.
// Superman PCB schematic (TC0030CMD pinout, verified on-board):
//   port_pa[7] = 1P START   (NOT bit 6 as MAME's macro name suggests)
//   port_pa[6] = 1P BUTTON3 (Superman has 2 buttons — tied high)
//   port_pa[5] = 1P BUTTON2
//   port_pa[4] = 1P BUTTON1
//   port_pa[3:0] = 1P UDLR
// MAME's macro is TAITO_JOY_UDLR_2_BUTTONS_START where the "_START" suffix
// adds START at bit 7 and BUTTON3 stays at bit 6 (kept high for 2-button
// games).  Same layout for port_pb (player 2).
// Button-3 slot (bit 6): was tied high when this core supported only
// 2-button games (Superman/Gigandes/Ballbros).  Bumped to wire in
// joystick1/2 bit 6 for Kyustrkr's 3rd button (Shoot).  For the
// 1/2-button games the JTFRAME side never asserts B3, so the slot
// reads high anyway — equivalent to the old `1'b1`.
wire [ 7:0] cab_in0 = { cab_1p[0], joystick1[6], joystick1[5:0] };
wire [ 7:0] cab_in1 = { cab_1p[1], joystick2[6], joystick2[5:0] };
wire [ 7:0] cab_in2 = { 4'b1111, tilt, service, coin[1], coin[0] };

// ─────────────────────────────────────────────────────────────────────────────
// MRA header → per-game flags (multi-game support, kiwi-pattern)
// ─────────────────────────────────────────────────────────────────────────────
// The MRA prepends 16 bytes of header (JTFRAME_HEADER=16 in macros.def).
// We only use byte 0 today; the rest is reserved for future use.
//
//   byte 0:
//     bit 0 = cchip_en          (1 = Superman has the Taito C-chip at $900xxx)
//     bit 1 = direct_input_en   (1 = cousins read IN0/IN1/IN2 directly at $900xxx)
//     bit 2 = adpcmb_en         (1 = Gigandes uses YM2610 Delta-T ADPCM-B)
//     bit 3 = coin_lockout_inv  (1 = kyustrkr inverts coin-lockout polarity)
//     bit 4 = fg_yoff_alt       (1 = use FG yoffset -0x0a instead of the
//                                    default -0x12; see X1-001A FG y_data
//                                    formula in `u_obj` below)
//     bit 5 = force_flip        (1 = XOR the X1-001A's screenflip bit
//                                    with 1 so the game looks upright on
//                                    a non-rotated monitor.  Set ONLY for
//                                    Kyustrkr, whose MAME GAME() entry is
//                                    ROT180 — the PCB was meant for a
//                                    cabinet rotated 180°, and the game
//                                    writes ctrl[0] bit 6 = 1 every frame
//                                    to pre-mirror its output.  MAME's
//                                    ROT180 cancels that mirror in
//                                    software; we have no ROT180 path,
//                                    so we XOR the chip's flip bit here
//                                    to produce the same end result.
//                                    Gigandes/Ballbros/Superman are ROT0
//                                    and never want this bit asserted.)
//     bits 6..7 = reserved
//
// FG yoffset per game (taito_x.cpp:1037..1164):
//   Superman / Daisenpu   →  m_spritegen->set_fg_yoffsets(-0x12, 0x0e)
//   Gigandes / Ballbros / →  m_spritegen->set_fg_yoffsets(-0x0a, 0x0e)
//     Kyustrkr               (cousins are 8 lines higher on screen for
//                             the same vram_y value)
// Our `u_obj` uses an empirical K=248 in the y_data formula that lines up
// the Superman 0x12 offset against our +18-line vtimer residual; cousins
// need K=240 (= 248-8) to land at the right scanline.  The fg_yoff_alt
// header bit selects which constant to use at compile-of-MRA time.
//
// Defaults: 0 across the board.  Each MRA in mame2mra.toml sets the bits
// it needs.  Superman MRA sets bit 0 (cchip_en=1), Gigandes sets bits
// 1+2+4 (direct_input + adpcmb + fg_yoff_alt), etc.  An all-zero header
// would behave as "Tier-2 cousin with no special hardware" which is
// intentionally a no-op safety state.
reg cchip_en          = 1'b0;
reg direct_input_en   = 1'b0;
reg adpcmb_en         = 1'b0;
reg coin_lockout_inv  = 1'b0;
reg fg_yoff_alt       = 1'b0;
reg force_flip        = 1'b0;
always @(posedge clk) begin
    if (prog_we && header && prog_addr[3:0] == 4'd0) begin
        cchip_en         <= prog_data[0];
        direct_input_en  <= prog_data[1];
        adpcmb_en        <= prog_data[2];
        coin_lockout_inv <= prog_data[3];
        fg_yoff_alt      <= prog_data[4];
        force_flip       <= prog_data[5];
    end
end

// Debug merging
wire [ 7:0] main_st;
assign st_dout    = main_st;
assign debug_view = main_st;
assign dip_flip   = 1'b0;             // wire to flag register once it exists

// ─────────────────────────────────────────────────────────────────────────────
// Main 68000 subsystem
// ─────────────────────────────────────────────────────────────────────────────
// Video subsystem BRAM port-B. Until the full X1-001A engine is wired,
// we use port-B as a **palette viewer**: scan all 2048 palette entries
// across the screen so any entry Superman has written shows as a
// coloured cell. This proves the 68k → palette BRAM → pixel pipeline
// works end-to-end AND visualises what the CPU has put into palette.
//
// Address mapping: high 4 bits of vdump pick a 16-line strip; high 7
// bits of hdump pick a column within that strip. 16 strips × 128
// columns = 2048 entries — the full palette.
wire [15:0] pal_dout_b_w, vram_dout_b_w, oram_dout_b_w;
wire [15:0] oram_bg_dout_b_w;
wire [12:0] oram_bg_addr_b_w;
reg  [10:0] pal_addr_b_r;

jtsuperman_main u_main(
    .rst        ( rst48              ),
    .clk        ( clk48              ),
    .LVBL       ( LVBL               ),
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

    // Video BRAM port-B exposure (read-only into video subsystem)
    .pal_addr_b ( pal_addr_b_r       ),
    .pal_dout_b ( pal_dout_b_w       ),
    .vram_addr_b( vram_addr_b_w      ),
    .vram_dout_b( vram_dout_b_w      ),
    .oram_addr_b( oram_addr_b_w      ),
    .oram_dout_b( oram_dout_b_w      ),
    .oram_bg_addr_b( oram_bg_addr_b_w ),
    .oram_bg_dout_b( oram_bg_dout_b_w ),

    // TC0140SYT master port (chip itself instantiated below)
    .syt_cs     ( syt_cs_w           ),
    .syt_addr   ( syt_addr_w         ),
    .syt_we     ( syt_we_w           ),
    .syt_din    ( syt_din_w          ),
    .syt_dout   ( syt_dout_w         ),

    // C-chip bus (wrapper instantiated below)
    .cchip_cs   ( cchip_cs_w         ),
    .cchip_addr ( cchip_addr_w       ),
    .cchip_din  ( cchip_din_w        ),
    .cchip_we   ( cchip_we_w         ),
    .cchip_lds_n( cchip_lds_n_w      ),
    .cchip_dout ( cchip_dout_w       ),
    .cchip_int_n( cchip_int_n_w      ),

    // DIPs + direct I/O (used by Ballbros/Gigandes/Kyustrkr at 0x900000)
    .dipsw_a    ( dipsw_a            ),
    .dipsw_b    ( dipsw_b            ),
    .cab_in0    ( cab_in0            ),
    .cab_in1    ( cab_in1            ),
    .cab_in2    ( cab_in2            ),

    // Multi-game header flags (decoded above)
    .cchip_en          ( cchip_en          ),
    .direct_input_en   ( direct_input_en   ),
    .coin_lockout_inv  ( coin_lockout_inv  ),

    .debug_bus  ( debug_bus          ),
    .st_dout    ( main_st            )
);

// ─────────────────────────────────────────────────────────────────────────────
// TC0140SYT — sound-comm chip between 68k and Z80
// ─────────────────────────────────────────────────────────────────────────────
//
// The Z80 side is fully decoded *inside* the SYT (it emits the Z80 chip
// selects for ROM/RAM/YM/SYT regions). For first-cut bring-up we leave
// the Z80 inputs floating at idle (MREQ_n=1, RD_n=1, WR_n=1) since the
// sound CPU isn't running yet. The 68k side is fully active.
//
// snd_addr/dout etc. will be wired in when jtsuperman_snd.v is rewritten
// to host the real Z80 + jt10.
wire        snd_rom_cs_w, snd_ram_cs_w, snd_ym_cs_w, snd_syt_sel_w;
wire [ 1:0] snd_rom_a16_w;
wire        snd_rst_w, snd_nmi_n_w;
wire [ 7:0] syt_z80_dout;
wire [15:0] z80_addr_w;
wire [ 7:0] z80_dout_w;
wire        z80_mreq_n_w, z80_rd_n_w, z80_wr_n_w;

jtsuperman_syt u_syt(
    .rst        ( rst48              ),
    .clk        ( clk48              ),

    // 68k master
    .main_cs    ( syt_cs_w           ),
    .main_addr  ( syt_addr_w         ),
    .main_dout  ( syt_din_w          ),
    .main_din   ( syt_dout_w         ),
    .main_we    ( syt_we_w           ),

    // Z80 slave — driven by jtsuperman_snd
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
// Clock enables for the sound subsystem — jtframe_cen48 gives us all the
// standard divisions of a 48 MHz clock. We need 8 MHz (YM2610) and 4 MHz (Z80).
// ─────────────────────────────────────────────────────────────────────────────
wire cen8, cen4;
wire cen12, cen16, cen6_unused, cen4_12, cen3, cen3q, cen1p5;
wire cen16b, cen12b, cen6b, cen3b, cen3qb, cen1p5b;

jtframe_cen48 u_cen48(
    .clk      ( clk48     ),
    .cen12    ( cen12     ),
    .cen16    ( cen16     ),
    .cen8     ( cen8      ),
    .cen6     ( cen6_unused ),
    .cen4     ( cen4      ),
    .cen4_12  ( cen4_12   ),
    .cen3     ( cen3      ),
    .cen3q    ( cen3q     ),
    .cen1p5   ( cen1p5    ),
    .cen16b   ( cen16b    ),
    .cen12b   ( cen12b    ),
    .cen6b    ( cen6b     ),
    .cen3b    ( cen3b     ),
    .cen3qb   ( cen3qb    ),
    .cen1p5b  ( cen1p5b   )
);

// ─────────────────────────────────────────────────────────────────────────────
// Taito C-chip (NEC uPD78C11 MCU + Fulvio's wrapper, adapted for Superman)
// ─────────────────────────────────────────────────────────────────────────────
//
// Superman port assignment per MAME taito_x.cpp:
//   PA in  = IN0 (joystick 1 + buttons)
//   PB in  = IN1 (joystick 2 + buttons)
//   AN in  = IN2 (coin/service/start/tilt)  → fed via port_cr0 (ADC 0)
//   PC out = coin counters / lockouts        → port_pc_out
//
// The mask ROM + game EPROM (b61_11.m11) are baked into the bitstream via
// $readmemh inside jtsuperman_cchip. ext_tick will eventually drive INTFT0
// for the 60 Hz timer interrupt; tie low until that wiring lands.
//
// BRING_UP=1 keeps Fulvio's testbench scaffolding active (mask-ROM
// command-inject + IRQ rearm helpers). Switch to 0 once we've proved the
// real 68k drives the bus the same way the testbench did.
jtsuperman_cchip #(
    .BRING_UP   ( 1'b0               )   // Rainbow-specific scaffolding off
) u_cchip (
    .clk        ( clk48              ),
    .rstn       ( ~rst48             ),
    // 68k-side bus (window decoded in jtsuperman_main)
    .cs         ( cchip_cs_w         ),
    .addr       ( cchip_addr_w       ),
    .din        ( cchip_din_w        ),
    .dout       ( cchip_dout_w       ),
    .we         ( cchip_we_w         ),
    .uds_n      ( 1'b1               ),   // Superman wires C-chip on low byte
    .lds_n      ( cchip_lds_n_w      ),
    .dtack_n    (                    ),   // ignored; main paces via jtframe_68kdtack_cen
    .int_n      ( cchip_int_n_w      ),
    .com_res_n  ( 1'b1               ),
    // MCU port inputs (Superman cabinet mapping)
    .port_pa    ( cab_in0            ),
    .port_pb    ( cab_in1            ),
    .port_pc    ( 8'hFF              ),   // PC is output on Superman
    .port_pd    ( 8'hFF              ),
    // ADC inputs.  MAME wires the physical COIN/SERVICE/TILT signals to
    // C-chip analog channels AN0..AN7 (an[0..7]_func, returning $FF if the
    // signal is set, else 0).  Our MCU wrapper only exposes cr0..cr3.
    // The EPROM uses 8-channel scan mode; CR3 holds AN7 = TILT.  With
    // cr3=0 the boot treats TILT as ACTIVE and displays the "TILT" fatal
    // screen, so we must drive it from the inactive (=1) TILT bit.
    // Real ADC channel multiplexing belongs inside the MCU core (CR0..CR3
    // should reflect the currently-scanned AN channel per the ANM
    // register); a follow-up will model that properly.
    .port_cr0   ( {8{cab_in2[0]}}    ),   // AN0 = COIN1   (IN2 bit 0)
    .port_cr1   ( {8{cab_in2[1]}}    ),   // AN1 = COIN2   (IN2 bit 1)
    .port_cr2   ( {8{cab_in2[2]}}    ),   // AN2 = SERVICE1(IN2 bit 2)
    .port_cr3   ( {8{cab_in2[3]}}    ),   // AN7 = TILT    (IN2 bit 3)
    // MCU port outputs — only PC matters (coin counters); rest are unused
    .port_pa_out(                    ),
    .port_pb_out(                    ),
    .port_pc_out(                    ),
    .port_pd_out(                    ),
    .port_pf_out(                    ),
    // MAME (taito_x.cpp): vblank fires `m_cchip->ext_interrupt(ASSERT_LINE)`
    // followed immediately by a CLEAR_LINE timer. In FPGA terms this is a
    // one-clock-cycle pulse on the falling edge of LVBL (start of vblank),
    // which is the same edge that drives the 68k's IRQ-6 inside main.
    .ext_tick   ( vbl_pulse          ),
    // Debug taps unused at game level
    .dbg_pc     ( mcu_pc             ),
    .dbg_pc_next(                    ),
    .dbg_a      (                    ),
    .dbg_v      (                    ),
    .dbg_bc     (                    ),
    .dbg_de     (                    ),
    .dbg_hl     (                    ),
    .dbg_ea     (                    ),
    .dbg_sp     (                    ),
    .dbg_psw    (                    ),
    .dbg_iff    (                    ),
    .dbg_ap     (                    ),
    .dbg_vp     (                    ),
    .dbg_bcp    (                    ),
    .dbg_dep    (                    ),
    .dbg_hlp    (                    ),
    .dbg_eap    (                    ),
    .dbg_mm     (                    ),
    .dbg_mkh    (                    ),
    .dbg_mkl    (                    ),
    .dbg_retire ( mcu_retire         ),
    .dbg_trap   (                    )
);

// Simulation-only MCU activity counter — proves the uPD78C11 is actually
// executing and shows where it is.  Tracks:
//   - first 16 retires verbosely (boot sequence)
//   - every 100K with current PC (long-term progression)
//   - min/max PC seen so far (so we can see if EPROM 0x2000+ is ever entered)
//   - vbl_pulse count + INTF1-ISR entries (PC=0x0010) + EPROM entries
`ifdef SIMULATION
wire        mcu_retire;
wire [15:0] mcu_pc;
integer     mcu_inst_count   = 0;
integer     mcu_prev_count   = 0;
integer     vbl_pulse_count  = 0;
integer     mcu_intf1_count  = 0;
integer     mcu_eprom_count  = 0;
reg  [15:0] mcu_pc_min       = 16'hFFFF;
reg  [15:0] mcu_pc_max       = 16'h0000;
reg         mcu_saw_eprom    = 1'b0;   // PC ever in 0x2000-0x3FFF?
reg  [15:0] mcu_pc_prev      = 16'hFFFF;
always @(posedge clk48) begin
    if (vbl_pulse) vbl_pulse_count = vbl_pulse_count + 1;
    if (mcu_retire) begin
        mcu_inst_count = mcu_inst_count + 1;
        if (mcu_pc < mcu_pc_min) mcu_pc_min <= mcu_pc;
        if (mcu_pc > mcu_pc_max) mcu_pc_max <= mcu_pc;
        if (mcu_pc >= 16'h2000 && mcu_pc < 16'h4000) begin
            mcu_saw_eprom <= 1'b1;
            if (mcu_pc_prev < 16'h2000) // first cycle entering EPROM
                mcu_eprom_count = mcu_eprom_count + 1;
        end
        if (mcu_pc == 16'h0010 && mcu_pc_prev != 16'h0010)
            mcu_intf1_count = mcu_intf1_count + 1;
        mcu_pc_prev <= mcu_pc;
        if (mcu_inst_count <= 16 ||
            (mcu_inst_count <= 1024 && (mcu_inst_count % 64) == 0) ||
            (mcu_inst_count % 100000) == 0) begin
            $display("[%0t] MCU retire #%0d  PC=%04x  (min=%04x max=%04x  vbl=%0d  intf1=%0d  epr_in=%0d  eprom_seen=%b)",
                     $time, mcu_inst_count, mcu_pc,
                     mcu_pc_min, mcu_pc_max,
                     vbl_pulse_count, mcu_intf1_count, mcu_eprom_count,
                     mcu_saw_eprom);
        end
    end
    mcu_prev_count <= mcu_inst_count;
end
`else
wire        mcu_retire;
wire [15:0] mcu_pc;
`endif

// ─────────────────────────────────────────────────────────────────────────────
// Video — minimal first cut: timing-only, black pixels
// ─────────────────────────────────────────────────────────────────────────────
//
// The kiwi-derived jtsuperman_video subsystem expects 8-bit TNZS-shaped
// CPU buses; rewiring it to the 68k's 16-bit buses is a separate task.
// For this iteration we just run jtframe_vtimer directly so the core
// produces correct H/V sync and pulses LHBL/LVBL — enough for the 68k
// to take vblank IRQs and for the framework to emit frames. Pixels are
// constant black.
//
// SDRAM gfx buses (scr/obj) are tied to "no request" so the framework's
// SDRAM controller doesn't complain about unconnected reads.
//
// Vtimer at PXLCLK=8 with a 512×272 grid — matches the cores/pang
// pattern that's known to lock cleanly on both MiSTer's HDMI scaler
// and analog CRTs.  H rate is exactly 15.625 kHz (the NTSC SDTV
// target); refresh is 8 MHz / (512 × 272) = 57.46 Hz, within 0.05%
// of MAME taito_x.cpp's spec of 57.43 Hz.
//
// At our earlier PXLCLK=6, even with a tight 416-col total, the H
// rate came out at 14.42 kHz — 7.6% below 15.625 kHz — which made
// MiSTer's HDMI scaler interpolate badly (per-column striping) and
// kept analog CRTs from locking sync at all.  Switching to PXLCLK=8
// + the wider 512-col total restores the standard rate.
//
// Visible window kept at vdump 15..254 (240 rows, matching kiwi-style
// BG/FG renderer assumptions) — absolute counter values differ from
// MAME's vdump 8..247 but every renderer uses vdump relative to its
// own reference, not the absolute number.
//   Visible: vdump 15..254          (240 rows)
//   Pre-vis VBLANK: vdump 0..14     (15 rows)
//   Post-vis VBLANK + VS: vdump 255..271 (17 rows; VS pulse 257..259)
//   Total V cycle: 272 rows.
//   Total H cycle: 512 cols (visible 0..383 + 128-col blanking;
//                            HS pulse 388..414, 27 cyc).
wire [8:0] hdump_v, vdump_v, vrender_v;

// HS_START/VS_START offset by +8 (was 388/257) so PAL TVs centre the
// picture without needing the maximum CRT-knob travel — user reported
// the default lands too far bottom-right, and the standard centring
// pots couldn't pull it back.  Pushing the sync pulses 8 cycles later
// effectively grows the front porch and shrinks the back porch, which
// the TV interprets as "picture starts sooner after sync" — i.e. it
// slides up-and-left.  Visible window itself (vdump 15..254 / hdump
// 0..383) is untouched, so the game's view of pixel coordinates is
// unchanged.
jtframe_vtimer #(
    .HB_START ( 9'd384 ),    // visible 0..383, blanking 384..511 (128 cyc)
    .HS_START ( 9'd396 ),    // HS pulse 396..422 (was 388..414; +8 ⇒ picture LEFT 8 px)
    .HCNT_END ( 9'd511 ),
    .HB_END   ( 9'd0   ),
    .V_START  ( 9'd000 ),    // counter wraps from VCNT_END back to 0
    .VS_START ( 9'd265 ),    // VS pulse 265..267 (was 257..259; +8 ⇒ picture UP 8 rows)
    .VB_START ( 9'd255 ),    // visible ends after row 254
    .VCNT_END ( 9'd271 ),    // 272-row cycle
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

// VBLANK pulse → C-chip INTF1. MAME (taito_x.cpp) fires
// `m_cchip->ext_interrupt(ASSERT_LINE)` on vblank, immediately followed by
// a CLEAR_LINE timer — i.e., a one-clock-cycle pulse at the start of
// vblank. LVBL is high during active scan and low during vblank, so we
// pulse on the falling edge of LVBL.
reg  LVBL_q;
wire vbl_pulse = LVBL_q & ~LVBL;
always @(posedge clk48 or posedge rst48) begin
    if (rst48) LVBL_q <= 1'b0;
    else       LVBL_q <= LVBL;
end

// ─────────────────────────────────────────────────────────────────────────────
// Video — X1-001A sprite-position renderer (first cut).
// ─────────────────────────────────────────────────────────────────────────────
//
// jtsuperman_obj_v2 pre-loads up to 32 sprites from OBJ RAM during
// VBLANK and emits a 9-bit palette index when (hdump, vdump) falls
// inside a sprite's 16x16 bbox.  No gfx ROM fetch yet — each sprite
// renders as a SOLID-COLOURED 16x16 square (with dx-stripes so
// individual sprites are distinguishable).
//
// We mux the sprite output over the palette-viewer background:
//   - if pxl[9]=1, sprite covers this pixel → palette[$100 | pxl[8:0]]
//   - else                                  → palette viewer fallback
// kiwi obj engine driving full line-buffered sprite render.
// Address translator: kiwi's lut_addr [12:1] uses bit-10 (~st[1]) to
// pick which half of a sprite list entry to read.  For X1-001A:
//   bit-10 = 1 → read x+color word at OBJ word 0x200+N
//   bit-10 = 0 → read code+ctrl word at OBJ word N
// where N = lut_addr[8:1] (8-bit sprite index, 256 sprites).
wire [12:1] kiwi_lut_addr;
wire [ 8:0] kiwi_y_addr;
wire [20:2] kiwi_rom_addr;
wire        kiwi_rom_cs;
wire [ 8:0] obj_pxl_w_full;

// Kiwi lut_addr layout: { page, 1'b0, ~st[1], objcnt[8:0] }
//   page    : bit 12  (0 = FG, 1 = BG)
//   ~st[1]  : bit 10  (1 = read X+color word, 0 = read code+ctrl word)
//   objcnt  : bits 9:1 (9-bit sprite index)
// OBJ word offsets:
//   FG codes  : 0x000..0x1FF   (page=0, ~st[1]=0)
//   FG xcol   : 0x200..0x3FF   (page=0, ~st[1]=1)
//   BG codes  : 0x400..0x5FF   (page=1, ~st[1]=0)
//   BG xcol   : 0x600..0x7FF   (page=1, ~st[1]=1)
wire        sel_page   = kiwi_lut_addr[12];
wire        sel_xcolor = kiwi_lut_addr[10];
wire [ 8:0] obj_idx    = kiwi_lut_addr[9:1];

// X1-001A bank-swap (m_spritectrl[1] bits 5,6) — see MAME x1_001.cpp:268
//   `bank = ((ctrl2 ^ (~ctrl2<<1)) & 0x40) ? bank_size : 0`
// Decoding the XOR-with-shifted-invert:
//   bit6_of_(ctrl2 ^ ~(ctrl2<<1)) = ctrl2[6] XOR ~ctrl2[5]
//                                 = 1 when ctrl2[6] == ctrl2[5]
// So bank=1 (read second 0x800-word bank) when bits 5 and 6 of ctrl[1]
// match.  Superman has ctrl[1]=0x21 always (bit5=1, bit6=0 → no swap),
// so this is a no-op for Superman.  Gigandes alternates 0x20/0x60 per
// frame: 0x60 (5=1,6=1) swaps; 0x20 (5=1,6=0) doesn't.  Without this
// swap, our OBJ-RAM read always points at bank 0 — which is exactly
// the buffer the 68k is mid-writing — and we render the half-finished
// data as the "purple band" and the sprite tearing reported on
// Gigandes hardware.
wire        bank_swap  = ~(bg_ctrl1_r[6] ^ bg_ctrl1_r[5]);

// Bank size for Taito X is 0x1000 words (per taito_x.cpp:1008
// `draw_sprites(..., 0x1000)`), so the swap shifts the OBJ-RAM read
// address by bit 12.  This matches how the 68k writes bank 1 — at
// $e02000-$e03fff (= u_oram words 0x1000-0x1fff).
// Address layout:
//   bit [12]      = bank_swap (= 0 / 0x1000)
//   bit [11]      = 0 (unused within a bank)
//   bit [10]      = sel_page (FG = 0, BG = 1) → +0x400
//   bit [9]       = sel_xcolor (code/ctrl = 0, color/x = 1) → +0x200
//   bits [8:0]    = obj_idx (sprite index 0..511)
// Resulting addresses:
//   bank 0  FG code  : 0x000..0x1FF      bank 1: 0x1000..0x11FF
//   bank 0  FG color : 0x200..0x3FF      bank 1: 0x1200..0x13FF
//   bank 0  BG code  : 0x400..0x5FF      bank 1: 0x1400..0x15FF
//   bank 0  BG color : 0x600..0x7FF      bank 1: 0x1600..0x17FF
// — exactly the offsets used by MAME's draw_background/draw_foreground
// when `bank = 0x1000`.
wire [12:0] oram_addr_b_w = {bank_swap, 1'b0, sel_page, sel_xcolor, obj_idx};

// ─── Per-column BG scroll cache ────────────────────────────────────────────
// MAME (seta001.cpp:271,301,302) keeps a scrollram array at
// m_spriteylow[0x200..0x2FF], i.e. our VRAM words 0x200..0x2FF.  Each of
// the 16 BG columns has its scroll-Y at word offset 0x200+col*0x10 and
// scroll-X at 0x200+col*0x10+4.  We snapshot all 32 values once per
// VBLANK into two 16-entry register arrays so the BG kiwi can apply
// them combinationally to every sprite it iterates during the next
// active frame.
reg [7:0] bg_scrolly_arr [0:15];
reg [7:0] bg_scrollx_arr [0:15];
reg [7:0] bg_ctrl0_r;   // m_spritectrl[0] - startcol bits (0,1) + screenflip (6)
reg [7:0] bg_ctrl1_r;   // m_spritectrl[1] - numcol (bits[3:0]) + bank-swap (bit 6)
// Decoded bits of m_spritectrl[1]:
//   bits[3:0] = numcol.  Superman writes 0x21 once at boot (mPC=0x003F16)
//               and never touches it for the whole attract loop.  MAME
//               special-cases numcol==1 as "draw all 16 columns" — see
//               seta001 draw_background lines 294-295.  Cousins like
//               Gigandes use numcol==0, which MAME draws as ZERO BG
//               columns (the title is rendered entirely with FG sprites
//               on a black background).  When we always drew 16 cols
//               regardless of numcol, the leftmost columns rendered
//               whatever stale OBJ-RAM bytes lived there as BG tiles —
//               that produced the "purple band on the left" reported on
//               Gigandes hardware.
//   bit  5  = EOF buffer-copy.  Superman has it suppressed (single-
//             buffer attract).  Cousins toggle this with bit 6 for
//             active double-buffering (the bit-6 swap below).
//   bit  6  = sprite bank / front-back swap.  Superman static at 0;
//             cousins toggle 0/1 each frame (e.g. Gigandes alternates
//             ctrl[1]=0x20/0x60).  Not yet plumbed into the OBJ-RAM
//             address path — see "Gigandes: sprite glitches" task.
reg [7:0] bg_ctrl2_r;   // m_spritectrl[2] - low 8 bits of `upper`
reg [7:0] bg_ctrl3_r;   // m_spritectrl[3] - high 8 bits of `upper`

// load_state encodes 16 col passes (0..15) plus 4 ctrl reads (16..19)
// plus an idle terminator (20+).  load_phase still uses 5 phases per
// pass for the cols and 3 phases per pass for the ctrl reads.
reg [4:0] load_state;
reg [2:0] load_phase;
reg       load_busy;
reg       lvbl_q;
reg [9:0] scroll_vram_addr;

integer init_bgscroll;
initial begin
    for (init_bgscroll = 0; init_bgscroll < 16; init_bgscroll = init_bgscroll + 1) begin
        bg_scrolly_arr[init_bgscroll] = 8'd0;
        bg_scrollx_arr[init_bgscroll] = 8'd0;
    end
    // Reset state for the four spritectrl shadow registers — these
    // values hold ONLY for the handful of frames between FPGA reset
    // and the 68k's first write to $d00600-$d00607 (then the VBLANK
    // load FSM at load_state 16..19 copies the live values from
    // u_vram and our spritectrl shadows track the chip from then on).
    //
    // We deliberately do NOT bias these towards Superman's runtime
    // values (ctrl[0]=0x10, ctrl[1]=0x21).  Both Superman and the
    // cousins go through the EXACT same load path; biasing the reset
    // value would let a Superman-specific bug in the load FSM hide
    // behind "happens to also be the runtime value".  All-zeros is
    // what the real X1-001A hardware reads back at power-on too.
    bg_ctrl0_r = 8'd0;
    bg_ctrl1_r = 8'd0;
    bg_ctrl2_r = 8'd0;
    bg_ctrl3_r = 8'd0;
end

// Per-frame BG state load.  BRAM has a 2-cycle effective latency from
// "schedule addr1" to "data on q1" because both registers update on
// the same clock edge, so we issue, wait a cycle, then capture.
//
//   load_state 0..15: scrolly[col] + scrollx[col] for each of 16 cols
//                     (5 phases each: issue/wait/capture/issue/wait/capture)
//   load_state 16:    m_spritectrl[2] at VRAM word 0x302
//                     (3 phases: issue/wait/capture)
//   load_state 17:    m_spritectrl[3] at VRAM word 0x303
//   load_state 18:    m_spritectrl[0] at VRAM word 0x300
//   load_state 19:    m_spritectrl[1] at VRAM word 0x301
//   load_state >=20:  done -> clear load_busy
always @(posedge clk48, posedge rst48) begin
    if (rst48) begin
        load_busy        <= 1'b0;
        load_state       <= 5'd0;
        load_phase       <= 3'd0;
        lvbl_q           <= 1'b0;
        scroll_vram_addr <= 10'd0;
    end else begin
        lvbl_q <= LVBL;
        // Trigger at LVBL RISING (end of VBL, start of visible) — by
        // this point the 68k VBL ISR has had ~2.7 ms of VBL period to
        // run and update its per-frame spritectrl writes.  Previously
        // we triggered at LVBL FALLING (start of VBL) which captured
        // ctrl[1] BEFORE the ISR wrote the new value — every frame
        // we were 1 frame behind MAME's bank-swap state, which the
        // user reported as "stabilize briefly then go bad" sprite
        // flicker.  Schematic shows the X1-001 owns OBJ-RAM via the
        // OBJ NOR-strobe and the spritectrl regs live inside the
        // X1-002 die, so the chip itself sees the post-ISR values —
        // we should too.
        if (!lvbl_q && LVBL && !load_busy) begin
            load_busy  <= 1'b1;
            load_state <= 5'd0;
            load_phase <= 3'd0;
        end else if (load_busy) begin
            if (load_state < 5'd16) begin
                // scrolly + scrollx for col = load_state[3:0]
                case (load_phase)
                3'd0: begin
                    scroll_vram_addr <= {1'b1, 1'b0, load_state[3:0], 4'b0000};
                    load_phase       <= 3'd1;
                end
                3'd1: begin
                    load_phase <= 3'd2;
                end
                3'd2: begin
                    bg_scrolly_arr[load_state[3:0]] <= vram_dout_b_w[7:0];
                    scroll_vram_addr <= {1'b1, 1'b0, load_state[3:0], 4'b0100};
                    load_phase <= 3'd3;
                end
                3'd3: begin
                    load_phase <= 3'd4;
                end
                3'd4: begin
                    bg_scrollx_arr[load_state[3:0]] <= vram_dout_b_w[7:0];
                    load_state <= load_state + 5'd1;
                    load_phase <= 3'd0;
                end
                default: load_phase <= 3'd0;
                endcase
            end else if (load_state == 5'd16) begin
                // Read m_spritectrl[2] at VRAM word 0x302 (low byte).
                case (load_phase)
                3'd0: begin
                    scroll_vram_addr <= 10'h302;
                    load_phase       <= 3'd1;
                end
                3'd1: begin
                    load_phase <= 3'd2;
                end
                3'd2: begin
                    bg_ctrl2_r <= vram_dout_b_w[7:0];
                    load_state <= 5'd17;
                    load_phase <= 3'd0;
                end
                default: load_phase <= 3'd0;
                endcase
            end else if (load_state == 5'd17) begin
                case (load_phase)
                3'd0: begin
                    scroll_vram_addr <= 10'h303;
                    load_phase       <= 3'd1;
                end
                3'd1: begin
                    load_phase <= 3'd2;
                end
                3'd2: begin
                    bg_ctrl3_r <= vram_dout_b_w[7:0];
                    load_state <= 5'd18;
                    load_phase <= 3'd0;
                end
                default: load_phase <= 3'd0;
                endcase
            end else if (load_state == 5'd18) begin
                // Read m_spritectrl[0] at VRAM word 0x300 (low byte).
                case (load_phase)
                3'd0: begin
                    scroll_vram_addr <= 10'h300;
                    load_phase       <= 3'd1;
                end
                3'd1: begin
                    load_phase <= 3'd2;
                end
                3'd2: begin
                    bg_ctrl0_r <= vram_dout_b_w[7:0];
                    load_state <= 5'd19;
                    load_phase <= 3'd0;
                end
                default: load_phase <= 3'd0;
                endcase
            end else if (load_state == 5'd19) begin
                // Read m_spritectrl[1] at VRAM word 0x301 (low byte).
                // numcol (bits[3:0]) gates whether the BG layer renders at
                // all — Gigandes uses numcol=0 (no BG, FG-sprite-only title)
                // and the unread default 8'h21 (numcol=1) made the leftmost
                // columns render stale data as a purple band.
                case (load_phase)
                3'd0: begin
                    scroll_vram_addr <= 10'h301;
                    load_phase       <= 3'd1;
                end
                3'd1: begin
                    load_phase <= 3'd2;
                end
                3'd2: begin
                    bg_ctrl1_r <= vram_dout_b_w[7:0];
                    load_state <= 5'd20;
                    load_phase <= 3'd0;
                end
                default: load_phase <= 3'd0;
                endcase
            end else begin
                // done
                load_busy <= 1'b0;
            end
        end
    end
end

// VRAM port-B mux: the FSM owns the port while loading scrolls during
// VBLANK; the FG kiwi reads sprite-Y the rest of the time.  Even if the
// FG kiwi is still winding down at vdump=240..247 when the load starts,
// those scanlines are blanked anyway, so the wrong Y reads don't show.
wire [ 9:0] vram_addr_b_w = load_busy ? scroll_vram_addr : {1'b0, kiwi_y_addr};

// Both H and V flip polarities differ between kiwi obj.v (TNZS' X1-001)
// and our X1-001A gfx-ROM byte interleaving: with bits 15/14 unchanged,
// sprites came out upside-down AND mirrored ("TAITO" → "OTIAT").  Invert
// BOTH bits on the code+ctrl word (sel_xcolor==0) so the color byte from
// the X+color word stays intact.
//
// We use a registered sel_xcolor (sel_xcolor_q) here because BRAM has
// 1-cycle latency: oram_dout_b_w reflects the address issued in the
// PREVIOUS cycle.
reg sel_xcolor_q;
always @(posedge clk48) sel_xcolor_q <= sel_xcolor;
wire [15:0] lut_data_to_kiwi = sel_xcolor_q
                             ? oram_dout_b_w
                             : {~oram_dout_b_w[15], ~oram_dout_b_w[14], oram_dout_b_w[13:0]};

// FG wrap-range predicate (cousins only).  yoff is the X1-001A's
// m_fg_noflipyoffs (per taito_x.cpp): -0x12 for Superman, -0x0a for
// Gigandes/cousins.  In 8-bit two's complement: 0xEE / 0xF6.
//
// On Gigandes the kiwi engine sits 24 scanlines higher than MAME's
// geometry (an empirical residual we still need to root-cause), so
// any FG sprite whose MAME sy_screen is in [0..26] (= the top 27
// rows of the cliprect) lands at our screen_y in [-24..2] and either
// wraps via mod-256 to the BOTTOM of the screen or clips into the
// very top edge — either way producing a residual purple/grey block
// at one of the corners.
//
// Until we land the X1-001A's "second transpen at sy-256" wrap copy
// in obj.v (the proper fix), suppress those sprites entirely via the
// 8'hFE sentinel (vf = vdump-1, so a y_data of 0xFE matches at
// vf=254..255 + 0..13 which is vdump=255..0..14 — every one of those
// is outside visible vdump 15..254).  Earlier attempts used 8'hF0
// (matched 14 visible rows at the BOTTOM, producing the original
// purple band) and 8'hFF (matched ONE row at the TOP — user reported
// "you just moved the purple corner up").  8'hFE is the only 8-bit
// sentinel whose full 16-row window fits entirely in invisible vdump.
//
// Superman empirically renders TOP-row sprites correctly with K=248
// (its score-header labels live at the top edge), so the gate is
// disabled for Superman — turning it on broke "1UP / HIGH SCORE / 2UP"
// on the Superman attract.  Per-game gate driven by fg_yoff_alt
// (= 1 only for cousins).
//
// Condition (Gigandes only): ((vram_y + yoff) & 0xff) >= 224
//   = MAME sy_screen <= 16 (= 240 - 224)
// For Gigandes (yoff = 0xF6) -> vram_y in [0..9, 234..255] gate ON.
//
// This catches the sprites that mod-256 wrap to the BOTTOM of the
// visible window.  A wider gate (>= 192, sy <= 48) would also catch
// the residual top-edge artefacts caused by the +24-line offset
// between our kiwi engine and MAME's geometry — but it also kills
// the top portion of the GIGANDES "G" letter (the legitimate
// sprites at the same vram_y range).  The correct fix for the
// +24 offset is to either rebaseline the kiwi engine to MAME-exact
// vdump timing or implement the X1-001A's wrap-up copy; deferred.
wire [7:0]  fg_yoff_w            = fg_yoff_alt ? 8'hF6 : 8'hEE;
wire [7:0]  fg_sy_unclipped_w    = vram_dout_b_w[7:0] + fg_yoff_w;
wire        fg_wrap_range_w      = fg_yoff_alt && (fg_sy_unclipped_w >= 8'd224);

jtsuperman_obj u_obj(
    .rst       ( rst48          ),
    .clk       ( clk48          ),
    .lut_cen   ( pxl2_cen       ),
    .pxl_cen   ( pxl_cen        ),
    .hs        ( HS             ),
    .flip      ( bg_flip        ),
    .page      ( 1'b0           ),
    .lut_addr  ( kiwi_lut_addr  ),
    .lut_data  ( lut_data_to_kiwi ),
    .y_addr    ( kiwi_y_addr    ),
    // FG sy formula = MAME's no-flip draw_foreground exactly:
    //   chip_y = (FG_YOFF + 18 - vram_y) & 0xff
    // With the new TNZS-style vtimer (visible vdump 15..254), the
    // kiwi engine still produces a +18 line residual offset vs MAME
    // (down from +33 with the old 0..239 vtimer). Pixel-perfect needs
    // a deeper kiwi-engine timing fix to land sprite top at vdump=15.
    //
    // Per-game constant from the X1-001A FG yoffset (taito_x.cpp):
    //   Superman / Daisenpu (yoff=-0x12): K = 0xF8 (= 248) — empirical
    //   Gigandes  / cousins (yoff=-0x0a): K = 0xF0 (= 240) — empirical
    //
    // WRAP-RANGE GATE.  MAME's draw_foreground computes
    //   sy_screen = max_y - ((vram_y + yoff) & 0xff)
    // For sprites with sy_screen <= 16 (within 16 rows of the top of
    // the cliprect) MAME also draws a "wrap up" copy at sy-256, so
    // sprites near the top edge show correctly.  Our HDL's match is
    // mod-256 and we don't do the second wrap copy, so sprites that
    // MAME draws at the top edge get incorrectly placed at the BOTTOM
    // of the screen via the mod-256 wrap — producing the residual
    // ~16x8 purple block at the bottom-left of the Gigandes title and
    // the equivalent grey rect behind the life-counter HUD on the
    // gameplay attract.
    //
    // Until we add a proper "draw at vdump=Y and vdump=Y-256" wrap-
    // copy pass to the kiwi engine, suppress these sprites entirely
    // via the 8'hFE sentinel.  vf = vdump-1, so visible vf = 14..253.
    // y_data=8'hFE gives match window vf=254..255 + 0..13 — all
    // outside [14..253], so the sprite renders nowhere.  Picking
    // 8'hFF instead leaves a 1-row leak at vf=14 (= vdump=15, top of
    // visible) — the user observed the bottom-left purple corner
    // "moved up" to a top-row stripe after the first attempt.
    // Cost: the partial sprite tops MAME would show at the very top
    // of the screen are missing — those are 16-pixel slivers and
    // almost never carry user-visible game content (CREDIT 0 and
    // similar HUD overlays live well below the top edge).
    //
    // Condition (sy_screen <= 16 in MAME):
    //   ((vram_y + yoff) & 0xff) >= 224
    // For Gigandes (yoff = -10 = 0xF6, fg_yoff_alt=1):
    //   vram_y in [0..9] (sum 0xF6..0xFF) OR [234..255] (sum 0xE0..0xF5)
    // For Superman (yoff = -18 = 0xEE, fg_yoff_alt=0):
    //   vram_y in [0..17] OR [242..255]
    // Superman empirically renders correctly without this gate (the
    // game's content doesn't put sprites in that range), so the gate
    // is GATED off for Superman by fg_yoff_alt being 0.
    .y_data    ( (fg_yoff_alt ? 8'd8 : 8'd248) - vram_dout_b_w[7:0] ),
    .rom_addr  ( kiwi_rom_addr  ),
    .rom_cs    ( kiwi_rom_cs    ),
    .rom_ok    ( obj_ok         ),
    .rom_data  ( obj_data       ),
    .vdump     ( vdump_v        ),
    .hdump     ( hdump_v        ),
    .pxl       ( obj_pxl_w_full ),
    .debug_bus ( debug_bus      )
);

// 9-bit pxl from kiwi obj: {pal[4:0], code[3:0]} per pixel.  Bit 8 (= pal[4])
// being set serves as a "sprite present" indicator only when palette is
// non-zero; pal=0 transparent sprites would show as pxl=0.  Use pxl[3:0]
// (color index from gfx) to detect transparent (=0) sprite pixels.
wire        obj_hit       = |obj_pxl_w_full[3:0];   // non-transparent
wire [ 8:0] obj_pxl_w     = obj_pxl_w_full;

// ─── BG-column kiwi engine ─────────────────────────────────────────────────
// Second kiwi instance pointed at OBJ-RAM 0x400-0x7FF via page=1.  It reads
// from u_oram_bg (the mirrored OBJ BRAM in main.v) so it never contends
// with the FG kiwi on the original.  Its SDRAM bus is `bg` from mem.yaml.
// Per-column scroll is NOT applied yet — sy is derived purely from the
// kiwi sprite index (offs/2 * 16 within each column), screenflipped.
wire [12:1] kiwi_bg_lut_addr;
wire [ 8:0] kiwi_bg_y_addr;
wire [20:2] kiwi_bg_rom_addr;
wire        kiwi_bg_rom_cs;
wire [ 8:0] obj_bg_pxl_w_full;

wire        sel_xcolor_bg = kiwi_bg_lut_addr[10];
wire [ 8:0] obj_idx_bg    = kiwi_bg_lut_addr[9:1];
// BG kiwi always asserts page=1, so the [12] bit of its lut_addr is 1.
// Translate to OBJ word { page=1, sel_xcolor_bg, obj_idx_bg } = 0x400 or
// 0x600 base, same scheme as the FG translator.
// BG side also follows the bank-swap (MAME draw_background uses the
// same `bank` value as draw_foreground — same bit-6/bit-5 decode).
// Same bit layout as oram_addr_b_w above: bit 12 = bank, bit 10 =
// sel_page (forced 1 for BG), bit 9 = sel_xcolor.
assign oram_bg_addr_b_w = {bank_swap, 1'b0, 1'b1, sel_xcolor_bg, obj_idx_bg};

reg sel_xcolor_bg_q;
reg [3:0] bg_col_q;
reg       bg_offs_lsb_q;
always @(posedge clk48) begin
    sel_xcolor_bg_q <= sel_xcolor_bg;
    bg_col_q        <= kiwi_bg_lut_addr[9:6];   // objcnt[8:5] = column
    bg_offs_lsb_q   <= kiwi_bg_lut_addr[1];     // objcnt[0]    = offs[0]
end

// X-position injection: MAME's BG sx = scrollx[mame_col] + (offs & 1) * 16
// (xoffs = 0 for Superman since set_bg_xoffsets is never called).  Then
// for each mame_col, if `upper` bit `mame_col` is set, sx -= 256.  This
// is the X1-001A's mechanism for the right-side wrap of the BG layer
// (seta001.cpp:297,318):
//     upper = m_spritectrl[2] + m_spritectrl[3] * 256
//     if (upper & (1 << col)) sx -= 256
// In burst_01200 (the green-villain attract panel) upper = 0x0F00, so
// BG cols 8..11 draw at X=256..367 instead of X=0..96 - that's the
// difference between the villain appearing on the LEFT (our previous
// render) and CENTERED (MAME).
//
// In our 9-bit arithmetic, sx-=256 is equivalent to sx+=256 with mod-
// 512 wrap (since -256 = 0x100 in 9-bit unsigned), so we just OR in
// the 9'd256 when the upper bit is set.
//
// startcol mapping: MAME's draw_background reads OBJ slot
//     i = ((mame_col + startcol) & 0xf) * 32 + offs
// with startcol = (ctrl[0]&1)*4 + (ctrl[0]&2)*4 (per seta001.cpp lines
// 280-284). Wired dynamically from the VBLANK-loaded ctrl[0] register.
// hardcoded for now, dynamic read of ctrl[0] is a TODO.
// MAME seta001.cpp lines 280-284:
//   startcol = 0; if (ctrl[0] & 0x01) startcol += 4; if (ctrl[0] & 0x02) startcol += 8
// In 4-bit: bits 2 (=4) and 3 (=8) of startcol come from bits 0 and 1 of ctrl[0].
wire [3:0] bg_startcol  = { bg_ctrl0_r[1], bg_ctrl0_r[0], 2'b00 };
wire [3:0] bg_scroll_idx = bg_col_q - bg_startcol;
// Global screen-flip from ctrl[0] bit 6.  XOR with force_flip to
// compensate for MAME's per-game ROT180 game-level orientation
// (Kyustrkr only — see header byte 0 bit 5 comment above).  For all
// ROT0 games force_flip=0 so this is a pass-through.
wire       bg_flip      = bg_ctrl0_r[6] ^ force_flip;

wire [15:0] bg_upper        = {bg_ctrl3_r, bg_ctrl2_r};
wire        bg_upper_bit    = bg_upper[bg_scroll_idx];

// MAME's set_bg_xoffsets(0x1, -0x1) gives BG non-flip xoffs=1.
// Cross-correlation against MAME burst captures confirmed our HDL was
// missing this constant +1 X offset.
wire [ 8:0] bg_xpos_inject = {1'b0, bg_scrollx_arr[bg_scroll_idx]}
                           + (bg_offs_lsb_q ? 9'd16  : 9'd0)
                           + (bg_upper_bit  ? 9'd256 : 9'd0)
                           + 9'd1;

wire [15:0] lut_data_to_kiwi_bg = sel_xcolor_bg_q
                                ? {oram_bg_dout_b_w[15:9], bg_xpos_inject}
                                : {~oram_bg_dout_b_w[15], ~oram_bg_dout_b_w[14], oram_bg_dout_b_w[13:0]};

// SCAN_LOW_FIRST=1: BG iterates objcnt 0..0x1FF (LOW→HIGH) so that with
// KEEP_OLD=0 the high-col sprites (drawn last) overlay the low-col
// ones — matches MAME draw_background's `for col=0..numcol-1` order
// without hitting the dual-port RAM latency hazard that broke
// KEEP_OLD=1 (see 8abda86ce/936500553 history in jtsuperman_obj.v).
// FG keeps the default HIGH→LOW (SCAN_LOW_FIRST=0) which matches MAME
// draw_foreground's `i = spritelimit..0` order with KEEP_OLD=0.
jtsuperman_obj #(.SCAN_LOW_FIRST(1)) u_obj_bg(
    .rst       ( rst48              ),
    .clk       ( clk48              ),
    .lut_cen   ( pxl2_cen           ),
    .pxl_cen   ( pxl_cen            ),
    .hs        ( HS                 ),
    .flip      ( bg_flip            ),
    .page      ( 1'b1               ),
    .lut_addr  ( kiwi_bg_lut_addr   ),
    .lut_data  ( lut_data_to_kiwi_bg ),
    .y_addr    ( kiwi_bg_y_addr     ),
    // BG sy with per-column scroll, no-flip ordering (see ae917864d).
    //   sy = (offs/2) * 16 - scrolly[mame_col]
    // The scrolly lookup uses the same startcol-shifted index as scrollx
    // (the scrollram entry that owns OBJ slot N belongs to mame_col
    // = ((N>>5) - startcol) & 0xf, regardless of axis).
    //
    // numcol gate (MAME x1_001.cpp:259,288-293): when the sprite's
    // MAME-equivalent column is >= bg_numcol_eff, force y_data to a
    // sentinel value that never matches inside the visible vdump
    // window — the kiwi engine sees `match=false` and immediately
    // skips the sprite without writing the line buffer.
    //
    // SENTINEL CHOICE: The obj.v match window is vf[7:0] ∈
    // [y_data, y_data+15] mod 256, and vf = vdump - 1.  Visible vdump
    // is 15..254, so visible vf = 14..253.  For the gate to truly
    // suppress the sprite the 16-entry match window must be entirely
    // outside [14..253]:
    //   y_data = 8'hFE  -> match at vf = 254..255, 0..13   ✓ all invisible
    //   y_data = 8'hFF  -> match at vf = 255,   0..14      ✗ vf=14 visible (vdump=15)
    // I started with 8'hF0 (matches at vf=240..255 = visible bottom
    // 15 rows — produced the original bottom-left purple band) then
    // moved to 8'hFF, which still leaked ONE row at the very top of
    // the screen — the user observed the bottom corner "moved up" to
    // a top-corner row.  8'hFE is the only 8-bit value whose full
    // 16-row match window fits in the invisible region.
    //
    // For Gigandes (numcol=13) this stops cols 13..15 from rendering.
    // For Gigandes (numcol=0, title) this stops ALL cols.
    // Superman uses numcol=1 (=> bg_numcol_eff=16) so the gate never
    // fires — Superman behaviour is unchanged.
    .y_data    ( ({1'b0, (kiwi_bg_y_addr[8:5] - bg_startcol)} >= bg_numcol_eff)
                 ? 8'hFE
                 : ({kiwi_bg_y_addr[4:1], 4'b0} - bg_scrolly_arr[kiwi_bg_y_addr[8:5] - bg_startcol] + 8'd7) ),
    .rom_addr  ( kiwi_bg_rom_addr   ),
    .rom_cs    ( kiwi_bg_rom_cs     ),
    .rom_ok    ( bg_ok              ),
    .rom_data  ( bg_data            ),
    .vdump     ( vdump_v            ),
    .hdump     ( hdump_v            ),
    .pxl       ( obj_bg_pxl_w_full  ),
    .debug_bus ( debug_bus          )
);

// numcol gate from m_spritectrl[1] bits[3:0]:
//   0       → cousins (Gigandes/Ballbros/Kyustrkr) — DO NOT draw BG; the
//             title screen is FG sprites only.  Without this gate, our
//             BG renderer drew stale OBJ-RAM bytes at the leftmost
//             columns and produced the "purple band on the left" bug.
//   1       → Superman — MAME special-case "draw all 16 columns".
//   2..15   → draw bits[3:0] columns (not yet exercised by any cousin we
//             know of, but pass-through here for safety).
// numcol from m_spritectrl[1] bits[3:0] — MAME x1_001.cpp:259,288-293:
//   int numcol = ctrl2 & 0x0f;
//   if (numcol == 1) numcol = 16;
//   for (col = 0; col < numcol; col++) { ... draw BG col ... }
// So:
//   numcol=0  → 0 BG cols drawn (loop skipped)
//   numcol=1  → 16 cols (special case)
//   numcol=N  → N cols drawn (e.g. Gigandes uses numcol=13 during the
//               attract control-diagram screen).
// When we always drew 16 cols regardless of numcol, the extra cols
// (Gigandes: cols 13..15) rendered stale OBJ-RAM bytes as the "purple
// band on the left" on hardware.  The actual gating is applied at the
// lut_data mux below (see `lut_data_to_kiwi_bg`) — by the time we get
// here the BG line buffer has already discarded the per-col info.
// Superman uses ctrl[1]=0x21 (numcol=1 → 16 cols), so the gate never
// triggers and behaviour is unchanged.
wire [4:0]  bg_numcol_eff = (bg_ctrl1_r[3:0] == 4'd1) ? 5'd16
                          : {1'b0, bg_ctrl1_r[3:0]};
wire        bg_hit  = |obj_bg_pxl_w_full[3:0];   // BG non-transparent

assign bg_addr = kiwi_bg_rom_addr;
assign bg_cs   = kiwi_bg_rom_cs;

// ─── Composite: FG over BG over palette[0] ─────────────────────────────────
// Pick FG first (it sits in front of BG); if FG is transparent, fall back
// to BG; if BG also transparent, use palette[$000] (background colour).
wire [ 8:0] bg_pal_idx  = {obj_bg_pxl_w_full[8:4], obj_bg_pxl_w_full[3:0]};
wire [ 8:0] obj_pal_idx = {obj_pxl_w[8:4], obj_pxl_w[3:0]};   // pal[4:0]<<4 | color
always @* begin
    if (obj_hit)
        pal_addr_b_r = {2'b00, obj_pal_idx};   // FG: palette[$000..$1FF]
    else if (bg_hit)
        pal_addr_b_r = {2'b00, bg_pal_idx};    // BG: palette[$000..$1FF]
    else
        pal_addr_b_r = 11'd0;                  // background = palette[$000]
end

// xRGB_555: bits [14:10]=R, [9:5]=G, [4:0]=B.  With the full 5-bit
// palette routed correctly, TAITO logo came out RED — the famous Taito
// blue lives in bits [4:0], not [14:10].  So this chip uses RGB ordering,
// not BGR.  (Most jt cores wire MAME's palette as xBGR; X1-001A is xRGB.)
assign red   = pal_dout_b_w[14:10];
assign green = pal_dout_b_w[ 9: 5];
assign blue  = pal_dout_b_w[ 4: 0];

// SDRAM graphics.  obj bus drives kiwi obj engine — sprite tile gfx
// from bank 2.  kiwi's rom_addr [20:2] (19 bits) matches our newly-
// widened obj_addr [20:2] EXACTLY now (mem.yaml: addr_width=21).
assign obj_addr = kiwi_rom_addr;
assign obj_cs   = kiwi_rom_cs;

`ifdef SIMULATION
// Probe the obj SDRAM path so we know whether kiwi obj is requesting
// gfx data and whether anything non-zero comes back.
integer obj_cs_count = 0;
integer obj_ok_count = 0;
integer obj_data_nz_count = 0;
reg obj_cs_q;
always @(posedge clk48) begin
    obj_cs_q <= obj_cs;
    if (obj_cs & ~obj_cs_q) obj_cs_count = obj_cs_count + 1;
    if (obj_cs & obj_ok)    obj_ok_count = obj_ok_count + 1;
    if (obj_cs & obj_ok & (obj_data != 32'd0)) obj_data_nz_count = obj_data_nz_count + 1;
end
integer prev_objsdram_dump = 0;
always @(posedge clk48) begin
    if (obj_cs_count != prev_objsdram_dump && (obj_cs_count % 5000) == 0) begin
        $display("[%0t] OBJ-SDRAM  cs_pulses=%0d  ok_ticks=%0d  nonzero_data_ticks=%0d  addr_sample=%05x  data_sample=%08x",
                 $time, obj_cs_count, obj_ok_count, obj_data_nz_count, obj_addr, obj_data);
        prev_objsdram_dump <= obj_cs_count;
    end
end
`endif

// ─────────────────────────────────────────────────────────────────────────────
// Sound subsystem — real Z80 + jt10 (YM2610) + SYT slave wiring
// ─────────────────────────────────────────────────────────────────────────────
//
// jtsuperman_snd hosts the Z80 (4 MHz) and the YM2610 (jt10, 8 MHz). The
// TC0140SYT instantiated above decodes the Z80 memory map and gates the
// chip selects we feed here. ADPCM-A ROM comes from SDRAM bank 1.
wire [ 7:0] snd_st_w;
// Gate the Z80 and YM2610 clock enables with dip_pause so OSD pause
// freezes the sound subsystem too.  Without this, the 68k stops
// (HALTn asserted in jtsuperman_main) but the Z80 keeps spinning its
// dispatcher loop and the YM2610 keeps generating tones — so music
// keeps playing while the rest of the game is frozen, which feels
// wrong (and on real hardware the audio would also pause since the
// chip clocks are derived from the 68k's clock tree).
// dip_pause = 1 when game runs, 0 when paused (same convention as
// the 68k HALTn wiring).
wire cen_z80_paused = cen4 & dip_pause;
wire cen_ym_paused  = cen8 & dip_pause;

jtsuperman_snd u_snd(
    .rst            ( rst48              ),
    .clk            ( clk48              ),
    .cen_z80        ( cen_z80_paused     ),
    .cen_ym         ( cen_ym_paused      ),

    // SYT slave-side connections — chip selects from u_syt above
    .snd_rom_cs     ( snd_rom_cs_w   ),
    .snd_rom_a16    ( snd_rom_a16_w  ),
    .snd_ram_cs     ( snd_ram_cs_w   ),
    .snd_ym_cs      ( snd_ym_cs_w    ),
    .snd_syt_sel    ( snd_syt_sel_w  ),
    .snd_rst_soft   ( snd_rst_w      ),
    .snd_nmi_n      ( snd_nmi_n_w    ),
    .syt_dout_z80   ( syt_z80_dout   ),

    // Z80 bus back to SYT
    .z80_addr       ( z80_addr_w     ),
    .z80_dout       ( z80_dout_w     ),
    .z80_mreq_n     ( z80_mreq_n_w   ),
    .z80_rd_n       ( z80_rd_n_w     ),
    .z80_wr_n       ( z80_wr_n_w     ),

    // Sound ROM (SDRAM bank 1)
    .rom_addr       ( snd_addr       ),
    .rom_cs         ( snd_cs         ),
    .rom_data       ( snd_data       ),
    .rom_ok         ( snd_ok         ),

    // ADPCM-A (SDRAM bank 1)
    .adpcma_addr    ( adpcma_addr    ),
    .adpcma_cs      ( adpcma_cs      ),
    .adpcma_data    ( adpcma_data    ),
    .adpcma_ok      ( adpcma_ok      ),

    // Audio out (stereo) → game-level fm_l/fm_r
    .fm_l           ( fm_l_w         ),
    .fm_r           ( fm_r_w         ),

    .debug_bus      ( debug_bus      ),
    .st_dout        ( snd_st_w       )
);

endmodule
