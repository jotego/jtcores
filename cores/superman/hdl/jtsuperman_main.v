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
// jtsuperman_main — 68000 main CPU subsystem for the Taito X System
// ============================================================================
//
// PCB: Seta-built, sold by Taito as the "X System" (P0-039A, ROM-set prefix
// "b61" for Superman). One 16 MHz master XTAL feeds:
//
//   • Motorola 68000  @ 16 MHz / 2 = 8 MHz   ← this module
//   • Zilog Z80       @ 16 MHz / 4 = 4 MHz   ← jtsuperman_snd.v
//   • YM2610          @ 16 MHz / 2 = 8 MHz   ← jt10 inside _snd.v
//   • Taito C-chip    @ 16 MHz / 2 = 8 MHz   ← jtsuperman_cchip.v (deferred)
//
// 68000 sees 16 MB of byte address space; the X System decodes the upper
// bits into a sparse map (MAME taito/taito_x.cpp, mirrored in
// cores/superman/doc/taito_x.cpp). Across the four games we plan to ship
// in this core the layout is the same except at 0x900000:
//
//   shared base (all games)
//     0xB00000-0xB00FFF   palette RAM            (4 KB = 2048 × 16-bit)
//     0xD00000-0xD005FF   sprite Y RAM            (1.5 KB, X1-001 spriteylow)
//     0xD00600-0xD00607   sprite control regs     (8 bytes,  X1-001 spritectrl)
//     0xE00000-0xE03FFF   object RAM              (16 KB, sprite code+X+attr)
//     0xF00000-0xF03FFF   68k work RAM            (16 KB)
//
//   per-game overlay
//     superman/u/j        0x000000-0x07FFFF ROM (512 KB)
//                         0x900000-0x9007FF C-chip shared RAM (byte)
//                         0x900800-0x900FFF C-chip ASIC regs  (byte)
//
//     gigandes/a          0x000000-0x07FFFF ROM (512 KB)
//                         0x900000-0x90000F direct I/O ports
//
//     ballbros, kyustrkr  0x000000-0x03FFFF ROM (256 KB)
//                         0x900000-0x90000F direct I/O ports
//
//   shared peripherals
//     0x300000/400000/600000   watchdog scribbles (~once per frame, ignored)
//     0x500000-0x500007        DIP switch A/B (read-only)
//     0x800001 byte            TC0140SYT master_port_w (write index)
//     0x800003 byte            TC0140SYT master_comm_r/w (read/write data)
//
// IRQ source: Superman gets IRQ level 6 from the C-chip's timer pin (the
// C-chip is also what reads the joysticks/coin/start). The C-chip-less
// games drive IRQ 6 from V-blank instead. For first bring-up — before
// jtsuperman_cchip exists — we wire IRQ 6 to V-blank for *all* sets so
// Ballbros/Gigandes/Kyustrkr can boot. When the C-chip lands, we'll route
// its IRQ pin through a per-set mux.
//
// Read alongside:
//   • cores/superman/doc/taito_x.cpp       — MAME driver snapshot
//   • cores/superman/doc/taitosnd.cpp      — TC0140SYT register reference
//   • cores/superman/hdl/jtsuperman_syt.v  — our TC0140SYT implementation
//   • cores/rastan/hdl/jtrastan_main.v     — canonical Taito 68k spine
//
// ============================================================================

module jtsuperman_main(
    // ─── Reset & clock ─────────────────────────────────────────────────────
    //
    // Everything runs off one 48 MHz "system clock" (clk). jtframe_68kdtack_cen
    // creates two 8 MHz clock enables (Phi1/Phi2, 180° apart) for the 68k.
    //
    // rst is active-HIGH (drive high = held in reset).
    input               rst,
    input               clk,                  // 48 MHz JTFRAME_CLK48

    // ─── Video timing inputs ───────────────────────────────────────────────
    //
    // LVBL = "Line/Vertical Blank, active LOW" — high during visible scan,
    // low during vertical blank. We trigger IRQ 6 on the falling edge of
    // LVBL (start of vblank). When the C-chip lands this is replaced by
    // its IRQ pin.
    //
    // dip_pause comes from JTFRAME's pause menu — drives HALTn to freeze
    // the CPU cleanly without scrambling internal state.
    input               LVBL,
    input               dip_pause,

    // ─── Program ROM port (lives in SDRAM bank 0) ──────────────────────────
    //
    // 68000 fetches 16-bit words. We expose an 18-bit word address (covers
    // 512 KB / 2 = 256 K words → 18 bits) plus chip-select + valid-data
    // handshake (rom_ok). Until rom_ok is high we tell the 68k "not yet"
    // via DTACK.
    // cpu_addr is the full 23-bit word address — exposed so game.v can
    // drive smaller per-region SDRAM buses (work RAM) from the same bus.
    output       [23:1] cpu_addr,
    output       [18:1] main_addr,
    output       [ 1:0] main_dsn,             // {UDSn, LDSn} for byte writes
    output       [15:0] main_dout,
    output              main_rnw,
    output reg          rom_cs,
    input        [15:0] rom_data,
    input               rom_ok,

    // ─── Video subsystem read ports (BRAMs internal to this module) ───────
    //
    // Each video memory region is a dual-port BRAM owned by this module.
    // Port A is the 68k (handled internally). Port B is exposed for the
    // video subsystem so it can scan sprite Y coordinates, object code,
    // and look up palette colours during raster.
    //
    //   pal  — 0xB00000-0xB00FFF — palette RAM       (2048 words, 4 KB)
    //   vram — 0xD00000-0xD007FF — sprite Y + ctl    (1024 words, 2 KB)
    //   oram — 0xE00000-0xE03FFF — sprite code/X/atr (8192 words, 16 KB)
    //
    // Total BRAM: 22 KB for video + 16 KB for work RAM = 38 KB. Fits on
    // every JTFRAME target (MiSTer ~580 KB, Pocket ~720 KB, MiST ~75 KB).
    input        [10:0] pal_addr_b,
    output       [15:0] pal_dout_b,
    input        [ 9:0] vram_addr_b,
    output       [15:0] vram_dout_b,
    input        [12:0] oram_addr_b,
    output       [15:0] oram_dout_b,
    // Second OBJ-RAM read port for the BG-column kiwi engine.  Both
    // copies of u_oram receive the same CPU writes so the BG side always
    // sees the live OBJ data; port-B of the duplicate serves the BG kiwi
    // without colliding with the FG kiwi on the original.
    input        [12:0] oram_bg_addr_b,
    output       [15:0] oram_bg_dout_b,

    // ─── TC0140SYT master port (jtsuperman_syt is in jtsuperman_game.v) ───
    //
    // The SYT lives at 0x800001 (master_port_w, byte write) and 0x800003
    // (master_comm_r/w, byte). The chip uses the low byte of the 16-bit
    // bus (umask16(0x00ff)). Our SYT module takes a 4-bit master nibble.
    //
    // syt_cs   — high while the 68k accesses the 0x800000 window
    // syt_addr — bit 1 of the 68k address (selects port vs comm)
    // syt_we   — high on writes
    // syt_din  — main-side input nibble (master->slave data path)
    // syt_dout — main-side output nibble (slave->master data path)
    output reg          syt_cs,
    output              syt_addr,
    output              syt_we,
    output       [ 3:0] syt_din,
    input        [ 3:0] syt_dout,

    // ─── C-chip window (Superman only — fully internal stub for now) ──────
    //
    // 0x900000-0x900FFF. For Ballbros/Gigandes/Kyustrkr this is direct I/O
    // (input mux below). For Superman the real C-chip will live here —
    // jtsuperman_cchip + jt6805 + IROM. Until then reads return cab_in*
    // bytes (works for the cousin games; Superman won't boot until C-chip
    // lands which is the explicit plan).
    //
    // ─── Cabinet & DIPs ───────────────────────────────────────────────────
    //
    // Eight bits each for DIP A and DIP B (the chip presents them as two
    // 4-bit nibbles per byte read across the 4-byte 0x500000 window). The
    // cab_* inputs only matter for Ballbros/Gigandes/Kyustrkr where the
    // 68k reads them directly at 0x900000-0x90000F; Superman reads them
    // via the C-chip instead.
    input        [ 7:0] dipsw_a,
    input        [ 7:0] dipsw_b,
    input        [ 7:0] cab_in0,              // 0x900001  IN0 — buttons
    input        [ 7:0] cab_in1,              // 0x900003  IN1 — joys + start
    input        [ 7:0] cab_in2,              // 0x900005  IN2 — coin/service

    // ─── C-chip bus (real jtsuperman_cchip lives in jtsuperman_game.v) ──
    output reg          cchip_cs,         // window 0x900000-0x900FFF
    output       [11:1] cchip_addr,
    output       [ 7:0] cchip_din,        // low byte of 68k data
    output              cchip_we,
    output              cchip_lds_n,
    input        [ 7:0] cchip_dout,
    input               cchip_int_n,      // IRQ 6 source from C-chip (active LOW)

    // ─── Multi-game header flags (from jtsuperman_game.v MRA-header decode) ─
    // cchip_en          = 1 only for Superman.  Gates the cchip_cs window.
    // direct_input_en   = 1 for cousins (Gigandes/Ballbros/Kyustrkr).
    //                     Activates a small input_r block reading
    //                     IN0/IN1/IN2 directly at 0x900001/0x900003/0x900005.
    // coin_lockout_inv  = 1 only for Kyustrkr.  Inverts the coin-lockout
    //                     polarity in the direct_input_w sink (TODO).
    input               cchip_en,
    input               direct_input_en,
    input               coin_lockout_inv,

    // ─── Debug ─────────────────────────────────────────────────────────────
    input        [ 7:0] debug_bus,
    output       [ 7:0] st_dout
);

`ifndef NOMAIN

// ============================================================================
// 68000 core signals
// ============================================================================
wire [23:1] A;
wire        cpu_cen, cpu_cenb;
wire        UDSn, LDSn, RnW, ASn, VPAn, DTACKn;
wire [ 2:0] FC, IPLn;
wire [15:0] cpu_dout;
reg  [15:0] cpu_din;
wire        allFC;                            // high when NOT in CPU space (interrupt ack)
reg         intn;                             // IRQ 6 latched, active LOW
reg         LVBLl;                            // LVBL one cycle delayed (edge detect)

// Convenience expose
assign cpu_addr  = A;
assign main_addr = A[18:1];
assign main_dsn  = {UDSn, LDSn};
assign main_dout = cpu_dout;
assign main_rnw  = RnW;
assign allFC     = ~&FC;                      // FC==7 means IACK cycle

// IPL encoding: drive 3'b001 to assert level 6, 3'b111 for idle.
//   level 6 = binary 110 → IPLn = bit-inverted = 3'b001  (Superman)
//   level 2 = binary 010 → IPLn = bit-inverted = 3'b101  (cousins)
//
// MAME taito_x.cpp:
//   superman → custom interrupt() callback driving IPL=6 from the
//              C-chip timer pin; VBlank-triggered.
//   cousins  → irq2_line_hold on VBlank → IPL=2.
//
// The cousin handlers live at vector $68 (autovector level 2) and
// initialise palette/VRAM/etc.  If we fire level 6 on a cousin game
// the wrong vector ($78) runs, palette stays uninitialised, screen
// stays black — which is exactly what Gigandes Phase A showed.
//
// IMPORTANT: this requires VPAn to assert for the level-2 IACK cycle
// (A[3:1]==2) too — see VPAn assignment below.  Otherwise the 68k
// reads a junk vector and jumps to garbage.
//
//   cchip_en=1  intn=0 → IPLn=001 (level 6)
//   cchip_en=0  intn=0 → IPLn=101 (level 2)
//   intn=1 (no irq)    → IPLn=111 (idle) in both cases
assign IPLn = {intn | ~cchip_en, intn, 1'b1};

// VPAn (Valid Peripheral Address) low forces autovectoring during an IACK
// cycle. On the 68k an IACK is FC==7 with A[3:1] = irq level. Taito X has
// no vectored interrupts on any of the family games — superman uses level 6
// (autovector $78), cousins use level 2 (autovector $68).  Assert VPA for
// any IACK cycle so the 68k always autovectors regardless of level.
assign VPAn = !(!ASn && FC==3'd7 && RnW);

// ============================================================================
// Address decoder — combinational, ASn-gated (rastan style)
// ============================================================================
//
// Each chip-select goes high while ASn is low AND the 68k is in user/
// supervisor space (allFC) AND the upper bits match. Region map verbatim
// from MAME taito_x.cpp lines 620-694:
//
//   A[23:20] = 0x0  ROM             (size depends on game; 0-7 valid)
//   A[23:20] = 0x3  watchdog scribble — ignore
//   A[23:20] = 0x4  watchdog scribble — ignore
//   A[23:20] = 0x5  DIP switches (read-only)
//   A[23:20] = 0x6  watchdog scribble — ignore
//   A[23:20] = 0x8  TC0140SYT      (0x800001 / 0x800003)
//   A[23:20] = 0x9  C-chip  (Superman) OR I/O (Ballbros/Gigandes/Kyustrkr)
//   A[23:20] = 0xB  palette RAM    (0xB00000-0xB00FFF) — TODO BRAM
//   A[23:20] = 0xD  sprite Y + ctl (0xD00000-0xD007FF) — TODO BRAM
//   A[23:20] = 0xE  object RAM     (0xE00000-0xE03FFF) — TODO BRAM
//   A[23:20] = 0xF  work RAM       (0xF00000-0xF03FFF)
reg         dsw_cs;
reg         pal_cs, vram_cs, oram_cs, ram_cs;
reg         direct_in_cs;        // cousins: $900001/$900003/$900005 IN0/IN1/IN2
reg  [ 7:0] input_byte;          // cousin input mux output
// Cousin coin-counter writes ($900008-$90000F) are decoded then dropped on
// the floor — the MAME bookkeeping side effect is irrelevant for gameplay.
// coin_lockout_inv is reserved for kyustrkr's inverted polarity (Phase B).
/* verilator lint_off UNUSED */
wire        _unused_coin_lockout_inv = coin_lockout_inv;
/* verilator lint_on UNUSED */
// cchip_cs declared as `output reg` in the port list above.
// watchdog at 0x300000/0x400000/0x600000 is decoded but not connected —
// dropped to silence Quartus warning 10036. Add back if HW behaviour
// depends on the timeout reset.

always @* begin
    rom_cs       = allFC && !ASn && A[23:19] == 5'h00;                // 0x000000-0x07FFFF
    dsw_cs       = allFC && !ASn &&  A[23:20] == 4'h5 && RnW;         // 0x500000-0x50000F
    syt_cs       = allFC && !ASn &&  A[23:20] == 4'h8;                // 0x800000
    // C-chip vs direct-input multiplex (multi-game header flags).
    // Superman:           cchip_en=1, direct_input_en=0 → cchip_cs over full
    //                     $900000-$900FFF (0x9007FF + 0x900800 ASIC bank).
    // Gigandes/Ballbros/Kyustrkr:
    //                     cchip_en=0, direct_input_en=1 → direct_in_cs at
    //                     $900001/$900003/$900005 reads, $900008-$90000F
    //                     writes (coin counter / lockout).  No C-chip.
    cchip_cs     = cchip_en        && allFC && !ASn &&  A[23:20] == 4'h9;
    direct_in_cs = direct_input_en && allFC && !ASn &&  A[23:20] == 4'h9 && RnW && A[19:4] == 16'h0000;
    // Cousin-game input_r — MAME taito_x.cpp::input_r selects on the word
    // offset (A[3:1]): 000=IN0, 001=IN1, 010=IN2; others return 0.
    // Reads land on the low byte of cpu_din (LDSn asserted for the odd
    // byte address $900001/$900003/$900005).
    case (A[3:1])
        3'd0:    input_byte = cab_in0;
        3'd1:    input_byte = cab_in1;
        3'd2:    input_byte = cab_in2;
        default: input_byte = 8'hFF;
    endcase
    pal_cs       = allFC && !ASn &&  A[23:12] == 12'hB00;             // 0xB00000-0xB00FFF
    vram_cs      = allFC && !ASn &&  A[23:11] == 13'b1101_0000_0000_0;// 0xD00000-0xD007FF
    oram_cs      = allFC && !ASn &&  A[23:14] == 10'b1110_0000_00;    // 0xE00000-0xE03FFF
    ram_cs       = allFC && !ASn &&  A[23:14] == 10'b1111_0000_00;    // 0xF00000-0xF03FFF
end

// Byte-lane writes: 68k UDSn/LDSn are active LOW; jtframe_dual_ram16's we is
// active HIGH per-byte. ~UDSn = upper byte write, ~LDSn = lower byte write.
wire [1:0] cpu_we = {~UDSn, ~LDSn} & {2{~RnW}};

// ============================================================================
// C-chip bus drive — the real jtsuperman_cchip is in jtsuperman_game.v.
// ============================================================================
//
// We expose the byte-wide bus signals so the wrapper in game.v can run
// the actual uPD78C11 MCU + shared RAM + ASIC registers. The previous
// hardcoded HLE byte (GWK signature + ASIC ready=1) is gone — real
// C-chip code in the EPROM writes those values now.
assign cchip_addr  = A[11:1];
assign cchip_din   = cpu_dout[7:0];
assign cchip_we    = cchip_cs & ~RnW;
assign cchip_lds_n = LDSn;

// SYT is byte-only on the low lane. Address bit 1 selects "port" vs "comm"
// (0x800001 vs 0x800003). The chip's 4-bit master data sits in D[3:0].
assign syt_addr = A[1];
assign syt_we   = syt_cs & ~RnW & ~LDSn;
assign syt_din  = cpu_dout[3:0];

// ============================================================================
// DIP / cabinet read multiplexer
// ============================================================================
//
// 0x500000-0x500007 — DIP A in low byte at +0/+2, DIP B at +4/+6.
// 0x900000-0x90000F — direct inputs (non-Superman games). For Superman this
//                     window goes through the C-chip and cchip_dout supplies
//                     the read data; for the others we mux cab_in0/1/2 here.
//
// The C-chip path is selected dynamically by cchip_dout being non-zero —
// for the stub (no C-chip yet) cchip_dout will be 0xFF and we'll get the
// "input fallback" behaviour. This works for Ballbros/Gigandes/Kyustrkr
// where the C-chip never existed.
reg [7:0] dsw_byte;
// io_byte (direct cabinet inputs for non-cchip Taito-X games) removed —
// Superman always goes through the C-chip (cchip_dout). Dropped to
// silence Quartus warning 10036. Re-add when Ballbros/Gigandes/Kyustrkr
// support lands.

always @* begin
    case (A[3:1])
        3'd0: dsw_byte = dipsw_a;             // 0x500000
        3'd1: dsw_byte = dipsw_a;             // 0x500002 (mirrored — TBD verify)
        3'd2: dsw_byte = dipsw_b;             // 0x500004
        3'd3: dsw_byte = dipsw_b;             // 0x500006
        default: dsw_byte = 8'hFF;
    endcase
end

// ============================================================================
// On-chip RAMs — work / palette / sprite-Y / object, all dual-port BRAM
// ============================================================================
//
// Port A is the 68k (this module). Port B is exposed for the video
// subsystem (jtsuperman_video.v in game.v) to scan during raster.
// Total BRAM: 16 + 4 + 2 + 16 = 38 KB.
wire [15:0] ram_dout, pal_dout_a, vram_dout_a, oram_dout_a;

// ----------------------------------------------------------------------
// Work RAM (8K × 16-bit @ 0xF00000) — port B unused for now.
// ----------------------------------------------------------------------
// An earlier HLE attempt drove port B from a "vblank clear of $F01CCE"
// side-channel to break the 68k out of the C-chip wait at PC 0x4210.
// That backfired during the boot memory test (which writes patterns of
// 0x00/0xFF/... and verifies them — our HLE clobbering $F01CCE with 0
// on every vblank corrupted the $FF pass and routed the 68k into the
// memory-test-failure display routine at 0x1CC0+). Real C-chip
// behaviour will live in jtsuperman_cchip.v and gate on game phase.
jtframe_dual_ram16 #(.AW(13)) u_workram(
    .clk0  ( clk          ),
    .data0 ( cpu_dout     ),
    .addr0 ( A[13:1]      ),
    .we0   ( cpu_we & {2{ram_cs}} ),
    .q0    ( ram_dout     ),
    .clk1  ( clk          ),
    .data1 ( 16'h0        ),
    .addr1 ( 13'd0        ),
    .we1   ( 2'b00        ),
    .q1    (              )
);

jtframe_dual_ram16 #(.AW(11)) u_pal(      // 2K words = 4 KB at 0xB00000
    .clk0  ( clk          ),
    .data0 ( cpu_dout     ),
    .addr0 ( A[11:1]      ),
    .we0   ( cpu_we & {2{pal_cs}} ),
    .q0    ( pal_dout_a   ),
    .clk1  ( clk          ),
    .data1 ( 16'h0        ),
    .addr1 ( pal_addr_b   ),
    .we1   ( 2'b00        ),
    .q1    ( pal_dout_b   )
);

jtframe_dual_ram16 #(.AW(10)) u_vram(     // 1K words = 2 KB at 0xD00000
    .clk0  ( clk          ),
    .data0 ( cpu_dout     ),
    .addr0 ( A[10:1]      ),
    .we0   ( cpu_we & {2{vram_cs}} ),
    .q0    ( vram_dout_a  ),
    .clk1  ( clk          ),
    .data1 ( 16'h0        ),
    .addr1 ( vram_addr_b  ),
    .we1   ( 2'b00        ),
    .q1    ( vram_dout_b  )
);

jtframe_dual_ram16 #(.AW(13)) u_oram(     // 8K words = 16 KB at 0xE00000
    .clk0  ( clk          ),
    .data0 ( cpu_dout     ),
    .addr0 ( A[13:1]      ),
    .we0   ( cpu_we & {2{oram_cs}} ),
    .q0    ( oram_dout_a  ),
    .clk1  ( clk          ),
    .data1 ( 16'h0        ),
    .addr1 ( oram_addr_b  ),
    .we1   ( 2'b00        ),
    .q1    ( oram_dout_b  )
);

// BG mirror of u_oram.  Both BRAMs receive identical CPU writes, so the
// BG-side read port (oram_bg_addr_b) always reads back the live OBJ data
// without contending with the FG kiwi on port-B of the first copy.
// Inferred BRAM cost is +8 KB (1 extra dual-port block on MiSTer-class
// targets); cheap compared to wiring a real arbiter and matches the
// pattern other JT cores use for FG/BG dual sprite engines.
jtframe_dual_ram16 #(.AW(13)) u_oram_bg(
    .clk0  ( clk          ),
    .data0 ( cpu_dout     ),
    .addr0 ( A[13:1]      ),
    .we0   ( cpu_we & {2{oram_cs}} ),
    .q0    (              ),
    .clk1  ( clk          ),
    .data1 ( 16'h0        ),
    .addr1 ( oram_bg_addr_b ),
    .we1   ( 2'b00        ),
    .q1    ( oram_bg_dout_b )
);

// ============================================================================
// Read multiplexer — cpu_din pickup, registered
// ============================================================================
//
// Sources:
//   rom_data : SDRAM, paced by DTACK on rom_ok
//   ram/pal/vram/oram_dout : BRAMs, 1-cycle latency (no DTACK pacing needed
//                            since the DTACK helper only sees rom_cs in
//                            bus_busy below — BRAM reads complete in time)
//   dsw_byte : DIP switches (low byte, byte-mirrored on upper)
//   io_byte  : direct cabinet inputs (used by cousin games; for Superman
//              the C-chip will return data here instead, eventually)
//   syt_dout : TC0140SYT master-side 4-bit nibble
always @(posedge clk) begin
    cpu_din <= rom_cs    ? rom_data                          :
               ram_cs    ? ram_dout                          :
               pal_cs    ? pal_dout_a                        :
               vram_cs   ? vram_dout_a                       :
               oram_cs   ? oram_dout_a                       :
               dsw_cs    ? {8'hFF, dsw_byte}                 :
               cchip_cs  ? {8'hFF, cchip_dout}               :
               // Cousin games (Gigandes / Ballbros / Kyustrkr) read
               // IN0/IN1/IN2 directly from this 16-byte window.  See
               // direct_in_cs decode above + the input_byte mux below.
               direct_in_cs ? {8'hFF, input_byte}            :
               // MAME's tc0140syt master_comm_r returns the stored
               // nibble in m_masterdata[mainmode] (a u8 with the high
               // nibble forced to 0 by `data &= 0x0F` on every slave
               // write).  Padding with 4'hF makes the byte 68k reads
               // for the Z80 ack look like 0xFE instead of 0x0E —
               // every `cmpi.b #$0E,d0` after the ack fails and the
               // sound-init path never advances past frame 76.  Use 0.
               // (Rastan still uses 4'hF; its 68k masks with andi.b
               //  before comparing, so it doesn't notice.)
               syt_cs    ? {8'hFF, 4'h0, syt_dout}           :
               16'hFFFF;
end

// ============================================================================
// IRQ 6 generation
// ============================================================================
//
// Falling edge of LVBL (start of vblank) sets intn=0 → IPLn=3'b001 = level 6
// to the 68k. The IACK cycle (FC==7, A[3:1]==6, VPAn low → autovector) tells
// the CPU to use auto-generated vector $78. We clear intn during the IACK so
// the level drops back to idle once acknowledged.
//
// When the C-chip lands, this LVBL-driven path gets replaced (or merged)
// with the C-chip's IRQ pin for Superman; the cousin games keep this path.
always @(posedge clk, posedge rst) begin
    if (rst) begin
        intn  <= 1'b1;
        LVBLl <= 1'b0;
    end else begin
        LVBLl <= LVBL;
        if (!VPAn)
            intn <= 1'b1;                     // CPU acknowledged → drop IRQ
        else if (LVBLl & ~LVBL)
            intn <= 1'b0;                     // entering vblank → raise IRQ
    end
end

`ifdef SIMULATION
// Per-region activity summary.  irq_count already counts !VPAn (the IACK
// pulses).  We also dump per-region access counters so we can see whether
// the boot is actively painting attract-mode graphics into palette / VRAM
// / OBJ RAM (a sign of forward progress past idle).  Print every 250K ROM
// fetches.
integer prev_irq_print = 0;
integer prev_pal_count    = 0;
integer prev_vram_count   = 0;
integer prev_oram_count   = 0;
always @(posedge clk) begin
    if (rom_count != prev_irq_print && (rom_count % 250000) == 0) begin
        $display("[%0t] SIM rom=%0d  irq=%0d  intn=%b  pal=%0d(+%0d)  vram=%0d(+%0d)  oram=%0d(+%0d)  syt=%0d  cchip=%0d",
                 $time, rom_count, irq_count, intn,
                 pal_count,  pal_count  - prev_pal_count,
                 vram_count, vram_count - prev_vram_count,
                 oram_count, oram_count - prev_oram_count,
                 syt_count, cchip_count);
        prev_irq_print  <= rom_count;
        prev_pal_count  <= pal_count;
        prev_vram_count <= vram_count;
        prev_oram_count <= oram_count;
    end
end

// Gate-flag probe: log every write to $F01CCA (the boot-phase flag
// whose value-2 reading would skip the 'NO ERROR' self-test display
// screen).  Static disassembly finds 5 writers that store 0,1,3,4 —
// never 2 — so we want to see the runtime trajectory.
// $F01CCA is a WORD at byte address $F01CCA.  In word-address terms
// (A[23:1]) that's $F01CCA >> 1 = 23'h780E5.
//
// Also dump cchip ASIC-reg-1 (byte $900803, word $900802 / word-addr
// 23'h480401) writes — that's the boot's command channel where the
// 68k writes 2 as ACK ($2B08: MOVE.B #$02, $00900803).
// $F01CCA byte_addr -> A[23:1] = $F01CCA >> 1 = 0x780E65 (NOT 0x780E5 —
// that would compare to a 20-bit value zero-padded to 23 bits, which is
// $0780E5 << 1 = $0F01CA, a completely different address).  Earlier
// commits had `23'h780E5` and FLAG RD/WR never fired as a result.
wire flag_word_hit = ram_cs && (A == 23'h780E65);
wire asic1_hit     = cchip_cs && (A == 23'h480401);

reg flag_hit_q, asic1_hit_q;
always @(posedge clk) begin
    flag_hit_q  <= flag_word_hit & ~ASn;
    asic1_hit_q <= asic1_hit & ~ASn;
    if (flag_word_hit & ~ASn & ~RnW) begin
        // Write to $F01CCA word — log full word + UDS/LDS so we see
        // which byte half hit.  Sources at 0x41C0/0x42D4/0x44EA/0x453C/
        // 0x4296 all do MOVE.W which asserts both UDS+LDS.
        $display("[%0t] FLAG WR @F01CCA  data=%04x  UDSn=%b LDSn=%b  rom=%0d",
                 $time, cpu_dout, UDSn, LDSn, rom_count);
    end
    if (flag_word_hit & ~ASn & RnW) begin
        $display("[%0t] FLAG RD @F01CCA  rom=%0d  pc_hint=%06x",
                 $time, rom_count, {main_addr, 1'b0});
    end
    if (asic1_hit & ~ASn) begin
        if (~RnW)
            $display("[%0t] ASIC1 WR @900803  data=%02x  rom=%0d",
                     $time, cpu_dout[7:0], rom_count);
        else
            $display("[%0t] ASIC1 RD @900803  rom=%0d", $time, rom_count);
    end
end

// Probe the 6 known callers of $2E6A (the error-screen-render entry).
// Whichever one fires tells us *which* fatal error the boot ran into:
//   $0828  BRA $2E6A  with D7=$44  → "INTERRUPT LEVEL 4 ERROR" (spurious IRQ?)
//   $083A  BRA $2E6A  with D7=$40  → "INTERRUPT LEVEL 2 ERROR"
//   $2D80  JMP $2E6A  with D7=$20  → "SOUND ERROR"
//   $2EF0  JMP $2E6A  with D7=$34  → "SERVICE SW ERROR"
//   $3B34  BRA $2E6A  D7=runtime   → varies
//   $3EEA  JMP $2E6A  with D7=$2C  → "COIN ERROR"
// SYT write idx histogram — figure out which SYT slots the 68k writes
// (idx 4 = latch data, idx 6 = enable NMI to Z80, idx 7 = soft reset, etc.)
// Useful for diagnosing the silent-audio path.
integer syt_idx_writes [0:15];
reg     syt_idx_init = 1'b0;
integer syt_i;
initial begin
    for (syt_i = 0; syt_i < 16; syt_i = syt_i + 1) syt_idx_writes[syt_i] = 0;
end
reg syt_we_q;
always @(posedge clk) begin
    syt_we_q <= syt_cs & ~RnW & ~LDSn & ~ASn;
    if ((syt_cs & ~RnW & ~LDSn & ~ASn) & ~syt_we_q) begin
        // Capture index written.  syt_addr=A[1].  Idx selection is via the
        // SYT module's internal pointer.  But the byte written IS sometimes
        // an idx value when targeting the index port.  We log both addr+data.
        syt_idx_writes[cpu_dout[3:0]] = syt_idx_writes[cpu_dout[3:0]] + 1;
        // Print EVERY SYT write so we can see the full sound-cmd sequence.
        // (Rate-limited version was hiding addr=1 writes that follow
        // mainmode=0 — exactly the bytes we need to see for music.)
        $display("[%0t] SYT WR  addr=%0d  data=%02x (idx-sel-ct=%0d)  rom=%0d",
                 $time, syt_addr, cpu_dout[7:0],
                 syt_idx_writes[cpu_dout[3:0]], rom_count);
    end
end

reg [13:0] caller_seen = 14'd0;
// main_addr is word-addressed (18 bits). Constants below are byte_addr >> 1.
wire f828  = rom_cs & rom_ok & (main_addr == 18'h00414) & RnW;  // $0828
wire f83a  = rom_cs & rom_ok & (main_addr == 18'h0041d) & RnW;  // $083A
wire f2d80 = rom_cs & rom_ok & (main_addr == 18'h016c0) & RnW;  // $2D80
wire f2ef0 = rom_cs & rom_ok & (main_addr == 18'h01778) & RnW;  // $2EF0
wire f3b34 = rom_cs & rom_ok & (main_addr == 18'h01d9a) & RnW;  // $3B34
wire f3eea = rom_cs & rom_ok & (main_addr == 18'h01f75) & RnW;  // $3EEA
// SYT command-send routine entry — MAME trace_sound.lua shows the 68k
// reaches this at frame 69 (Z80 reset assert) and frame 76 (first real
// sound command, port=00 + comm=EF + comm=0E). If our 68k never
// reaches it, all FM channels stay TL=$7F-muted and test.wav is silent.
wire f2df6 = rom_cs & rom_ok & (main_addr == 18'h016fb) & RnW;  // $2DF6
wire f2e0c = rom_cs & rom_ok & (main_addr == 18'h01706) & RnW;  // $2E0C poll loop
// 68k boot at PC=$002C54 copies 256 bytes from C-chip data port at
// $900001 into work RAM at $F01B20+ — the dispatcher code that
// `jmp ($1b20,A5)` at $2D8E later jumps into. If our C-chip serves
// the wrong bytes (or the copy doesn't run), the dispatcher is garbage
// and the music-enqueue path never runs.
wire f2c54 = rom_cs & rom_ok & (main_addr == 18'h0162a) & RnW;  // $2C54 copy-loop body
wire f2c68 = rom_cs & rom_ok & (main_addr == 18'h01634) & RnW;  // $2C68 rts after copy
// $2BC6 is `move.b D7, $900C01` inside the bank-switch routine $2BC2.
// If this fetches but $900C01 doesn't reach k68_wr_bank, our C-chip
// address decode is off.
wire f2bc6 = rom_cs & rom_ok & (main_addr == 18'h015e3) & RnW;  // $2BC6
// 68k executing FROM work RAM at $F01B20 (dispatcher entry) and
// $F01B70 (the queue-enqueue point per MAME trace). These probes
// confirm the dispatcher code uploaded to RAM is actually being run.
// rom_ok is NOT used here — that's the ROM-load-done signal, not
// relevant for RAM access; gating with it was masking real reads.
wire fF01B20 = ram_cs & (main_addr == 18'h00D90) & RnW;
wire fF01B70 = ram_cs & (main_addr == 18'h00DB8) & RnW;
// $2D8A is `jmp ($1B20,A5)` — the indirect dispatch that should jump
// into the uploaded RAM dispatcher at $F01B20 (when A5=$F00000).
// If this probe fires but fF01B20 doesn't, the jmp itself is reached
// but execution-from-RAM is failing somewhere downstream.
wire f2d8a = rom_cs & rom_ok & (main_addr == 18'h016c5) & RnW;
// $2D8E is the periodic SYT-poll-then-drain-queue routine entry.  If
// $2D8E fires periodically post-$2D8A but no $2DB0 hit follows, the
// poll is reaching the routine but bailing on the 0xE0/0xE1 byte
// check.  $2DB0 is the queue-pop entry (taken after cmpi.b #$E0).
wire f2d8e = rom_cs & rom_ok & (main_addr == 18'h016c7) & RnW;  // $2D8E
wire f2db0 = rom_cs & rom_ok & (main_addr == 18'h016d8) & RnW;  // $2DB0
wire f2da4 = rom_cs & rom_ok & (main_addr == 18'h016d2) & RnW;  // $2DA4 cmpi.b #$E0,D1
wire f2da8 = rom_cs & rom_ok & (main_addr == 18'h016d4) & RnW;  // $2DA8 beq $2DB0
always @(posedge clk) begin
    if (f828  && !caller_seen[0]) begin caller_seen[0] <= 1; $display("[%0t] CALLER $0828  -> INT-LV4 ERROR  rom=%0d", $time, rom_count); end
    if (f83a  && !caller_seen[1]) begin caller_seen[1] <= 1; $display("[%0t] CALLER $083A  -> INT-LV2 ERROR  rom=%0d", $time, rom_count); end
    if (f2d80 && !caller_seen[2]) begin caller_seen[2] <= 1; $display("[%0t] CALLER $2D80  -> SOUND ERROR    rom=%0d", $time, rom_count); end
    if (f2ef0 && !caller_seen[3]) begin caller_seen[3] <= 1; $display("[%0t] CALLER $2EF0  -> SERVICE SW    rom=%0d", $time, rom_count); end
    if (f3b34 && !caller_seen[4]) begin caller_seen[4] <= 1; $display("[%0t] CALLER $3B34  -> (D7 runtime)  rom=%0d", $time, rom_count); end
    if (f3eea && !caller_seen[5]) begin caller_seen[5] <= 1; $display("[%0t] CALLER $3EEA  -> COIN ERROR    rom=%0d", $time, rom_count); end
    if (f2df6 && !caller_seen[6]) begin caller_seen[6] <= 1; $display("[%0t] CALLER $2DF6  -> SYT command-send ENTRY  rom=%0d", $time, rom_count); end
    if (f2e0c && !caller_seen[7]) begin caller_seen[7] <= 1; $display("[%0t] CALLER $2E0C  -> SYT status-poll       rom=%0d", $time, rom_count); end
    if (f2c54 && !caller_seen[8]) begin caller_seen[8] <= 1; $display("[%0t] CALLER $2C54  -> dispatcher copy-loop body  rom=%0d", $time, rom_count); end
    if (f2c68 && !caller_seen[9]) begin caller_seen[9] <= 1; $display("[%0t] CALLER $2C68  -> rts after copy            rom=%0d", $time, rom_count); end
    if (f2bc6 && !caller_seen[10]) begin caller_seen[10] <= 1; $display("[%0t] CALLER $2BC6  -> bank-switch write to $900C01  rom=%0d", $time, rom_count); end
    // Gate fF01B20 / fF01B70 by caller_seen[13] ($2D8A) so RAM-test or
    // upload-read accesses BEFORE the dispatch don't burn the one-shot.
    // We want the FIRST access in the dispatcher area AFTER the jmp.
    if (fF01B20 && caller_seen[13] && !caller_seen[11]) begin caller_seen[11] <= 1; $display("[%0t] CALLER $F01B20 -> dispatcher ENTRY (running from RAM, post-jmp)  rom=%0d", $time, rom_count); end
    if (fF01B70 && caller_seen[13] && !caller_seen[12]) begin caller_seen[12] <= 1; $display("[%0t] CALLER $F01B70 -> dispatcher ENQUEUE (music push, post-jmp)         rom=%0d", $time, rom_count); end
    if (f2d8a   && !caller_seen[13]) begin
        caller_seen[13] <= 1;
        // Only the verilator-specific fx68k exposes A5 as an internal wire
        // (the synthesis fx68k uses an SV struct that hides it).  Guard the
        // hier-ref so Quartus parsers don't choke during synthesis builds.
`ifdef SIMULATION
        $display("[%0t] CALLER $2D8A   -> jmp ($1B20,A5)  A5=%08x  (target=%08x)  rom=%0d",
                 $time, u_cpu.u_cpu.excUnit.A5,
                 u_cpu.u_cpu.excUnit.A5 + 32'h00001B20, rom_count);
`else
        $display("[%0t] CALLER $2D8A   -> jmp ($1B20,A5)  rom=%0d", $time, rom_count);
`endif
    end
end

// Periodic-poll probes ($2D8E + $2DB0).  Count post-jmp hits, not just
// the first — we want to know how many polls run and how many of them
// reach the queue-drain branch.  Print every 10th hit so the log stays
// readable.
reg [15:0] f2d8e_ct = 16'd0;
reg [15:0] f2db0_ct = 16'd0;
reg [15:0] f2da4_ct = 16'd0;
always @(posedge clk) begin
    if (f2d8e && caller_seen[13]) begin
        if (f2d8e_ct < 16'hFFFF) f2d8e_ct <= f2d8e_ct + 16'd1;
        if (f2d8e_ct < 16'd5 || (f2d8e_ct[3:0] == 4'd0))
            $display("[%0t] POLL  $2D8E  hit#%0d  rom=%0d", $time, f2d8e_ct, rom_count);
    end
    if (f2db0 && caller_seen[13]) begin
        if (f2db0_ct < 16'hFFFF) f2db0_ct <= f2db0_ct + 16'd1;
        if (f2db0_ct < 16'd5 || (f2db0_ct[3:0] == 4'd0))
            $display("[%0t] DRAIN $2DB0  hit#%0d  rom=%0d", $time, f2db0_ct, rom_count);
    end
    // At $2DA4 (cmpi.b #$E0,D1), dump D1 so we can see what byte the
    // assembled-read routine $2E06 produced.  If D1.b != $E0 then the
    // ack-handshake comparison fails and we never reach $2DB0.
    // Sample at $2DA8 (next fetch) instead of $2DA4 so the or.w-at-
    // $2E22 commit has settled into regs68L/H first — sampling at the
    // cmpi fetch directly hit a hierarchical-read race in the sim.
    if (f2da8 && caller_seen[13]) begin
        if (f2da4_ct < 16'hFFFF) f2da4_ct <= f2da4_ct + 16'd1;
        if (f2da4_ct < 16'd8 || (f2da4_ct[3:0] == 4'd0)) begin
`ifdef SIMULATION
            $display("[%0t] CMPI  $2DA4-post  hit#%0d  D1=%08x (.b=%02x)  D0=%08x  rom=%0d",
                     $time, f2da4_ct,
                     u_cpu.u_cpu.excUnit.D1, u_cpu.u_cpu.excUnit.D1[7:0],
                     u_cpu.u_cpu.excUnit.D0, rom_count);
`else
            $display("[%0t] CMPI  $2DA4-post  hit#%0d  rom=%0d", $time, f2da4_ct, rom_count);
`endif
        end
    end
end

// Dump every 68k READ from work RAM around the dispatcher area
// $F01B20-$F01C1F so we can see whether the jmp at $2D8A actually
// causes the 68k to fetch opcodes from $F01B20+ (= A5 + $1B20 if
// A5 == $F00000), or from somewhere else entirely.
reg dispatch_r_seen = 1'b0;
// Print FIRST 16 reads in dispatcher area AFTER the $2D8A jmp.  Earlier
// reads (RAM test / copy / etc.) drowned out the actual execution-from-
// RAM trace, so gate on caller_seen[13] and count up to 16 unique events.
reg [4:0] dispatch_r_ct = 5'd0;
always @(posedge clk) begin
    if (ram_cs && RnW && ~ASn && caller_seen[13]
        && main_addr >= 18'h00D90 && main_addr <= 18'h00E0F
        && dispatch_r_ct < 5'd16) begin
        dispatch_r_ct <= dispatch_r_ct + 5'd1;
        $display("[%0t] DISPATCH_R[%0d]  main_addr=%05x  byte_addr=%06x  uds=%b lds=%b  rom=%0d",
                 $time, dispatch_r_ct, main_addr,
                 {6'b1111_00, main_addr, 1'b0}, ~UDSn, ~LDSn, rom_count);
    end
end

// Probe ALL writes the 68k makes to $900C00-$900C0F (the ASIC bank
// register area) so we can see what's happening at the bank set.
always @(posedge clk) begin
    if (cchip_cs && ~RnW && ~ASn
        && main_addr >= 18'h040600 && main_addr <= 18'h040607) begin
        $display("[%0t] CCHIP_BANK_W  main_addr=%05x  byte_addr=%06x  cpu_dout=%04x  uds=%b lds=%b  rom=%0d",
                 $time, main_addr, {6'b1001_00, main_addr, 1'b0},
                 cpu_dout, ~UDSn, ~LDSn, rom_count);
    end
end

// Dispatcher-staging write probe — 68k writes 256 bytes copied from
// C-chip at PC=$2C54 into work RAM at $F01B20-$F01C1F. main_addr is
// the word address bus [18:1]; $F01B20 byte = word offset $00D90,
// $F01C1F byte = word offset $00E0F.  Range widened to $F01B20-$F01C5F
// so we also catch writes to the music queue body ($F01C20-$F01C3F),
// head pointer ($F01C40), tail pointer ($F01C44), and counter slots.
always @(posedge clk) begin
    if (ram_cs && ~RnW && ~ASn
        && main_addr >= 18'h00D90
        && main_addr <= 18'h00E2F) begin
        $display("[%0t] DISPATCH_W  wordoff=%04x  byte_addr=%08x  data=%04x  uds=%b lds=%b  rom=%0d",
                 $time, main_addr[13:1], {6'b1111_00, main_addr, 1'b0},
                 cpu_dout, ~UDSn, ~LDSn, rom_count);
    end
end

// Music-queue activity probe — after the dispatch jmp ($2D8A,
// caller_seen[13]), log every byte the 68k writes into the queue
// buffer at $F01C20-$F01C3F (main_addr 0x00E10-0x00E1F) and every
// move.l to the head/tail pointer pair at $F01C40-$F01C47 (main_addr
// 0x00E20-0x00E23).  These tell us whether the dispatcher actually
// enqueues anything (vs. silently bailing) and whether the polling
// routine at $2DC2 (move.b (A0)+,D1) drains the queue afterwards.
reg [7:0] queue_w_ct = 8'd0;
reg [7:0] queue_r_ct = 8'd0;
always @(posedge clk) begin
    if (ram_cs && caller_seen[13]
        && main_addr >= 18'h00E10 && main_addr <= 18'h00E23
        && ~ASn) begin
        if (~RnW && queue_w_ct < 8'd64) begin
            queue_w_ct <= queue_w_ct + 8'd1;
            $display("[%0t] QUEUE_W[%0d]  wordoff=%04x  byte_addr=%06x  data=%04x  uds=%b lds=%b  rom=%0d",
                     $time, queue_w_ct, main_addr[13:1],
                     {6'b1111_00, main_addr, 1'b0},
                     cpu_dout, ~UDSn, ~LDSn, rom_count);
        end
        if (RnW && queue_r_ct < 8'd64) begin
            queue_r_ct <= queue_r_ct + 8'd1;
            $display("[%0t] QUEUE_R[%0d]  wordoff=%04x  byte_addr=%06x  uds=%b lds=%b  rom=%0d",
                     $time, queue_r_ct, main_addr[13:1],
                     {6'b1111_00, main_addr, 1'b0},
                     ~UDSn, ~LDSn, rom_count);
        end
    end
end

// Trace ALL RAM reads after first $2DB0 hit (limited) — diagnose why
// HEAD_RD / TAIL_RD probes weren't firing at $F01C40/$F01C44.  Also
// dump A5 alongside each read so we can spot when it stops pointing
// to $F00000.
reg [10:0] drain_trace_ct = 11'd0;
always @(posedge clk) begin
    if (ram_cs && RnW && ~ASn && caller_seen[13] && f2db0_ct > 16'd0
        && drain_trace_ct < 11'd40) begin
        drain_trace_ct <= drain_trace_ct + 11'd1;
`ifdef SIMULATION
        $display("[%0t] DRAIN_TR[%0d]  main_addr=%05x  data=%04x  A5=%08x  rom=%0d",
                 $time, drain_trace_ct, main_addr, ram_dout,
                 u_cpu.u_cpu.excUnit.A5, rom_count);
`else
        $display("[%0t] DRAIN_TR[%0d]  main_addr=%05x  data=%04x  rom=%0d",
                 $time, drain_trace_ct, main_addr, ram_dout, rom_count);
`endif
    end
end

// Sanity probe — when $2DB0 first fires, dump opcode/extension words
// at $2DB6 and $2DBA so we can verify the displacements in the move.l
// instructions.  Expected: $2DB6 = 242D (move.l (d16,A5),D2),
// $2DB8 = 1C40 (displacement), $2DBA = 206D (movea.l), $2DBC = 1C44.
// Sample only when main_addr changes so the bus dwell on each
// instruction doesn't burn the counter.
reg [17:0] rom_prev_addr = 18'h3FFFF;
reg [4:0]  rom_fetch_after_db0 = 5'd0;
always @(posedge clk) begin
    if (rom_cs && RnW && ~ASn && caller_seen[13] && f2db0_ct > 16'd0
        && rom_fetch_after_db0 < 5'd24
        && main_addr != rom_prev_addr) begin
        rom_prev_addr <= main_addr;
        rom_fetch_after_db0 <= rom_fetch_after_db0 + 5'd1;
        $display("[%0t] ROM_TR[%0d]  main_addr=%05x  byte_addr=%06x  data=%04x  rom=%0d",
                 $time, rom_fetch_after_db0, main_addr,
                 {6'b00, main_addr, 1'b0}, rom_data, rom_count);
    end
end

// Direct probe of the instruction stream at $2DB6 and $2DBA — read
// the SDRAM at those byte addresses (independent of CPU activity).
// If 68k ever fetches them, we'll see them in this stream.
wire fdb6 = rom_cs & rom_ok & (main_addr == 18'h016db) & RnW;  // $2DB6
wire fdba = rom_cs & rom_ok & (main_addr == 18'h016dd) & RnW;  // $2DBA
reg fdb6_seen, fdba_seen;
always @(posedge clk) begin
    if (fdb6 && !fdb6_seen) begin
        fdb6_seen <= 1;
        $display("[%0t] DB6_FETCH  byte_addr=002db6  data=%04x  rom=%0d", $time, rom_data, rom_count);
    end
    if (fdba && !fdba_seen) begin
        fdba_seen <= 1;
        $display("[%0t] DBA_FETCH  byte_addr=002dba  data=%04x  rom=%0d", $time, rom_data, rom_count);
    end
end
`endif

// Debug status: a few bits useful while bringing up; subject to change.
assign st_dout = { 3'h0, vram_cs|pal_cs|oram_cs, ~intn, syt_cs, cchip_cs, rom_cs };

// ============================================================================
// jtframe_68kdtack_cen — clock-enable + DTACK pacing
// ============================================================================
//
// 48 MHz × 1/6 = 8 MHz exactly (same ratio rastan uses). The helper holds
// DTACK high (= "not ready") while bus_busy is high — that's our knob for
// stalling the CPU during slow SDRAM reads.
// Only ROM is SDRAM-backed; BRAMs and registered I/O complete in 1-2 cycles
// so DTACK doesn't need to gate on them.
wire bus_cs    = rom_cs;
wire bus_busy  = rom_cs & ~rom_ok;
wire bus_legit = 1'b0;                        // no overlapping internal stalls

jtframe_68kdtack_cen #(.W(8)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( bus_legit ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    .num        ( 7'd1      ),                // 48 MHz × 1/6 = 8 MHz
    .den        ( 8'd6      ),
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    .fave       (           ),
    .fworst     (           )
);

// ============================================================================
// jtframe_m68k — FX68K-or-J68 wrapper (built-time selectable via JTFRAME_J68)
// ============================================================================
jtframe_m68k u_cpu(
    .clk      ( clk       ),
    .rst      ( rst       ),
    .RESETn   (           ),
    .cpu_cen  ( cpu_cen   ),
    .cpu_cenb ( cpu_cenb  ),

    .eab      ( A         ),
    .iEdb     ( cpu_din   ),
    .oEdb     ( cpu_dout  ),

    .eRWn     ( RnW       ),
    .LDSn     ( LDSn      ),
    .UDSn     ( UDSn      ),
    .ASn      ( ASn       ),
    .VPAn     ( VPAn      ),
    .FC       ( FC        ),

    .BERRn    ( 1'b1      ),                  // no bus errors
    .HALTn    ( dip_pause ),                  // OSD pause halts CPU
    .BRn      ( 1'b1      ),                  // no external DMA
    .BGACKn   ( 1'b1      ),
    .BGn      (           ),

    .DTACKn   ( DTACKn    ),
    .IPLn     ( IPLn      )
);

// ============================================================================
// Simulation-only instrumentation — counts and logs bus activity so we can
// verify against MAME debug traces. Patterned after cabal's sim block.
// Strip with `-d NOSIM_TRACE` if too noisy.
// ============================================================================
`ifdef SIMULATION
initial $display(">>>> jtsuperman_main: SIMULATION live <<<<");

integer rom_count   = 0;
integer ram_count   = 0;
integer pal_count   = 0;
integer vram_count  = 0;
integer oram_count  = 0;
integer syt_count   = 0;
integer dsw_count   = 0;
integer cchip_count = 0;
integer irq_count   = 0;
reg [18:1] last_rom_addr = 18'h3FFFF;
reg        rom_ok_d = 1'b0;

// Sample rom_data on the rising edge of rom_ok — that's when the SDRAM
// has actually delivered the word the CPU consumes. Sampling on rom_cs
// would catch stale bus state.
always @(posedge clk) rom_ok_d <= rom_ok & rom_cs;

always @(posedge clk) begin
    if (rom_cs && rom_ok && !rom_ok_d && main_addr != last_rom_addr) begin
        rom_count = rom_count + 1;
        last_rom_addr = main_addr;
        if (rom_count <= 16 || rom_count % 10000 == 0)
            $display("[%0t] ROM #%0d  addr=%06x  data=%04x  RnW=%b",
                     $time, rom_count, {main_addr, 1'b0}, rom_data, RnW);
    end
    if (ram_cs   & ~ASn) ram_count   = ram_count + 1;
    if (pal_cs   & ~ASn) pal_count   = pal_count + 1;
    if (vram_cs  & ~ASn) vram_count  = vram_count + 1;
    if (oram_cs  & ~ASn) oram_count  = oram_count + 1;
    if (syt_cs   & ~ASn) syt_count   = syt_count + 1;
    if (dsw_cs   & ~ASn) dsw_count   = dsw_count + 1;
    if (cchip_cs & ~ASn) cchip_count = cchip_count + 1;
    if (!VPAn)           irq_count   = irq_count + 1;

end

// Periodic status: edge-trigger every 100K ROM fetches.
integer prev_rom_count = 0;
always @(posedge clk) begin
    if (rom_count != prev_rom_count && (rom_count % 100000) == 0)
        $display("[%0t] STATUS rom=%0d ram=%0d pal=%0d vram=%0d oram=%0d syt=%0d dsw=%0d cchip=%0d irq=%0d",
                 $time, rom_count, ram_count, pal_count, vram_count, oram_count,
                 syt_count, dsw_count, cchip_count, irq_count);
    prev_rom_count <= rom_count;
end

final begin
    $display("=== jtsuperman_main FINAL ===");
    $display("  ROM fetches   : %0d", rom_count);
    $display("  Work RAM hits : %0d", ram_count);
    $display("  Pal RAM hits  : %0d", pal_count);
    $display("  VRAM hits     : %0d", vram_count);
    $display("  Obj RAM hits  : %0d", oram_count);
    $display("  SYT hits      : %0d", syt_count);
    $display("  DIP reads     : %0d", dsw_count);
    $display("  Cchip hits    : %0d", cchip_count);
    $display("  IRQ ACK cycles: %0d", irq_count);
    $display("  Last A: %06x  RnW=%b  ASn=%b  intn=%b",
             {A, 1'b0}, RnW, ASn, intn);
    $writememh("sim_pal.hex",  dbg_pal);
    $writememh("sim_vram.hex", dbg_vram);
    $writememh("sim_oram.hex", dbg_oram);
end

// Shadow arrays for end-of-sim BRAM dump.  We mirror every byte write
// to palette / VRAM / OBJ-RAM into these arrays so $writememh produces
// a complete contents dump comparable against MAME's $save'd binaries.
reg [15:0] dbg_pal  [0:2047];   // 4 KB palette ($B00000-$B00FFF)
reg [15:0] dbg_vram [0:1023];   // 2 KB VRAM    ($D00000-$D007FF)
reg [15:0] dbg_oram [0:8191];   // 16 KB OBJ    ($E00000-$E03FFF)

initial begin
    integer i;
    for (i = 0; i < 2048; i = i + 1) dbg_pal[i]  = 16'h0000;
    for (i = 0; i < 1024; i = i + 1) dbg_vram[i] = 16'h0000;
    for (i = 0; i < 8192; i = i + 1) dbg_oram[i] = 16'h0000;
end

always @(posedge clk) begin
    if (pal_cs  & ~ASn & ~RnW) begin
        if (~UDSn) dbg_pal[A[11:1]][15:8] <= cpu_dout[15:8];
        if (~LDSn) dbg_pal[A[11:1]][ 7:0] <= cpu_dout[ 7:0];
    end
    if (vram_cs & ~ASn & ~RnW) begin
        if (~UDSn) dbg_vram[A[10:1]][15:8] <= cpu_dout[15:8];
        if (~LDSn) dbg_vram[A[10:1]][ 7:0] <= cpu_dout[ 7:0];
    end
    if (oram_cs & ~ASn & ~RnW) begin
        if (~UDSn) dbg_oram[A[13:1]][15:8] <= cpu_dout[15:8];
        if (~LDSn) dbg_oram[A[13:1]][ 7:0] <= cpu_dout[ 7:0];
    end
end

// Periodic safety dump every 500K ROM fetches in case `final` doesn't run.
integer prev_dump_rom = 0;
always @(posedge clk) begin
    if (rom_count != prev_dump_rom && (rom_count % 500000) == 0) begin
        $writememh("sim_pal.hex",  dbg_pal);
        $writememh("sim_vram.hex", dbg_vram);
        $writememh("sim_oram.hex", dbg_oram);
        $display("[%0t] BRAM dump @ rom=%0d", $time, rom_count);
        prev_dump_rom <= rom_count;
    end
end
`endif

`else  // NOMAIN — tie CPU side off, replay scene from BRAM SIMFILE init

assign cpu_addr    = 23'd0;
assign main_addr   = 18'd0;
assign main_dsn    = 2'b11;
assign main_dout   = 16'h0;
assign main_rnw    = 1'b1;
assign syt_addr    = 1'b0;
assign syt_we      = 1'b0;
assign syt_din     = 4'h0;
assign cchip_addr  = 11'd0;
assign cchip_din   = 8'h0;
assign cchip_we    = 1'b0;
assign cchip_lds_n = 1'b1;
assign st_dout     = 8'h0;

initial begin
    rom_cs   = 1'b0;
    syt_cs   = 1'b0;
    cchip_cs = 1'b0;
end

// Scene-replay BRAMs.  These mirror u_pal, u_vram, u_oram (and u_oram_bg)
// from the non-NOMAIN branch but with write ports tied off and SIMFILE
// preset to load the captured scene at simulation start.  Sim.sh's `-s`
// flag copies <scene>/pal.bin, vram.bin, oram.bin into the working dir
// so $fopen resolves them.  ENDIAN=1 matches MAME's big-endian m68k
// byte order (high byte at even offsets, low byte at odd offsets) so
// the byte-split in jtframe_dual_ram16 lands in the right halves.
jtframe_dual_ram16 #(.AW(11), .ENDIAN(1), .SIMFILE("pal.bin")) u_pal_sim(
    .clk0  ( clk          ),
    .data0 ( 16'h0        ),
    .addr0 ( 11'd0        ),
    .we0   ( 2'b00        ),
    .q0    (              ),
    .clk1  ( clk          ),
    .data1 ( 16'h0        ),
    .addr1 ( pal_addr_b   ),
    .we1   ( 2'b00        ),
    .q1    ( pal_dout_b   )
);

jtframe_dual_ram16 #(.AW(10), .ENDIAN(1), .SIMFILE("vram.bin")) u_vram_sim(
    .clk0  ( clk          ),
    .data0 ( 16'h0        ),
    .addr0 ( 10'd0        ),
    .we0   ( 2'b00        ),
    .q0    (              ),
    .clk1  ( clk          ),
    .data1 ( 16'h0        ),
    .addr1 ( vram_addr_b  ),
    .we1   ( 2'b00        ),
    .q1    ( vram_dout_b  )
);

jtframe_dual_ram16 #(.AW(13), .ENDIAN(1), .SIMFILE("oram.bin")) u_oram_sim(
    .clk0  ( clk          ),
    .data0 ( 16'h0        ),
    .addr0 ( 13'd0        ),
    .we0   ( 2'b00        ),
    .q0    (              ),
    .clk1  ( clk          ),
    .data1 ( 16'h0        ),
    .addr1 ( oram_addr_b  ),
    .we1   ( 2'b00        ),
    .q1    ( oram_dout_b  )
);

// BG mirror of u_oram_sim — same SIMFILE so both copies have identical
// scene state, matching the structure used in the non-NOMAIN branch.
jtframe_dual_ram16 #(.AW(13), .ENDIAN(1), .SIMFILE("oram.bin")) u_oram_bg_sim(
    .clk0  ( clk            ),
    .data0 ( 16'h0          ),
    .addr0 ( 13'd0          ),
    .we0   ( 2'b00          ),
    .q0    (                ),
    .clk1  ( clk            ),
    .data1 ( 16'h0          ),
    .addr1 ( oram_bg_addr_b ),
    .we1   ( 2'b00          ),
    .q1    ( oram_bg_dout_b )
);

`endif
endmodule
