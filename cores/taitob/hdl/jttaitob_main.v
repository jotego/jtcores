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

    Author: Andrea Bogazzi.
    Date: 5-2026 */

// ============================================================================
// jttaitob_main — 68000 main CPU subsystem for the Taito B System
// ============================================================================
//
// PCB ref: K1100419A / J1100178A (rastsag2/nastar/nastarw, ROM prefix b81).
// Two crystals on the board: 24 MHz drives the 68k; 16 MHz drives the
// Z80 and YM2610; a third 27.164 MHz crystal drives the TC0180VCU pixel
// clock. The 68k runs at 24/2 = 12 MHz.
//
//   • Motorola 68000  @ 24/2 = 12 MHz   ← this module
//   • Zilog Z80       @ 16/4 =  4 MHz   ← jttaitob_snd.v
//   • YM2610          @ 16/2 =  8 MHz   ← jt10 inside _snd.v
//
// Memory map (taito_b.cpp:369 rastsag2_map):
//
//   0x000000-0x07FFFF  68k ROM                  → SDRAM bank 0
//   0x200000-0x201FFF  palette RAM (4 KB)       → BRAM in this module
//   0x400000-0x47FFFF  TC0180VCU window         → BRAM in this module
//                      (decoded into sub-regions per tc0180vcu_memrw)
//   0x600000-0x607FFF  68k work RAM (32 KB)     → BRAM in this module
//   0x800000-0x800003  TC0140SYT                → jttaitob_syt.v
//   0xA00000-0xA0000F  TC0220IOC                → jttaitob_ioc.v
//
// IRQ source (taito_b.cpp:1895-1896): the TC0180VCU drives two interrupts:
//   inth_callback → 68k IRQ 4   (HOLD_LINE)
//   intl_callback → 68k IRQ 2   (HOLD_LINE)
// IRQ 2 just sets a flag the IRQ 4 ISR checks (taito_b.cpp:44). For
// first-cut bring-up we drive IRQ 4 on falling-edge LVBL (start of
// vblank) and leave IRQ 2 idle — that gets the game out of the
// "waiting for vblank" loop. When the VCU lands properly, swap
// these for the real chip's INTH/INTL outputs.
//
// Read alongside:
//   • cores/taitob/doc/taito_b.cpp          — MAME driver snapshot
//   • cores/taitob/doc/tc0180vcu.cpp + .h   — VCU register reference
//   • cores/taitob/doc/taitoio.cpp          — TC0220IOC reference
//   • cores/superman/hdl/jtsuperman_main.v  — Taito X cousin
//   • cores/rastan/hdl/jtrastan_main.v      — canonical Taito 68k spine
// ============================================================================

module jttaitob_main(
    input               rst,
    input               clk,                     // 48 MHz JTFRAME_CLK48

    // Video timing
    input               LVBL,
    input               LHBL,                    // for IRQ-2 8-line-after-vbl
    input               dip_pause,

    // Program ROM (SDRAM bank 0, "main" bus from mem.yaml)
    output       [23:1] cpu_addr,
    output       [18:1] main_addr,
    output       [ 1:0] main_dsn,                // {UDSn, LDSn}
    output       [15:0] main_dout,
    output              main_rnw,
    output reg          rom_cs,
    input        [15:0] rom_data,
    input               rom_ok,

    // Video subsystem port-B reads
    input        [11:0] pal_addr_b,
    output       [15:0] pal_dout_b,
    input        [14:0] vram_addr_b,
    output       [15:0] vram_dout_b,
    input        [12:0] oram_addr_b,             // sprite/scroll combined window
    output       [15:0] oram_dout_b,
    // VCU control register file — full 8×16-bit array exposed to video.v.
    // Layout per tc0180vcu.cpp (ctrl_w decoder):
    //   ctrl[0]  hi byte = FG rambank pair {fg_rambank[1]<<4, fg_rambank[0]}
    //   ctrl[1]  hi byte = BG rambank pair {bg_rambank[1]<<4, bg_rambank[0]}
    //   ctrl[2]  hi byte = FG scrolling-blocks divisor
    //   ctrl[3]  hi byte = BG scrolling-blocks divisor
    //   ctrl[4]  hi byte = text tile bank 0
    //   ctrl[5]  hi byte = text tile bank 1
    //   ctrl[6]  hi byte = text ram page
    //   ctrl[7]  hi byte = video_control (flip / fb page / sprite priority)
    output reg   [127:0] vcu_ctrl,                // {ctrl[7], ctrl[6], ..., ctrl[0]}

    // TC0140SYT master port
    output              syt_cs,
    output              syt_addr,                // = A[1] (0x800001 vs 0x800003)
    output              syt_we,
    output       [ 3:0] syt_din,
    input        [ 3:0] syt_dout,

    // TC0220IOC bus
    output              ioc_cs,
    output       [ 3:0] ioc_addr,                // = A[4:1]
    output              ioc_rnw,
    output              ioc_lds_n,
    output       [ 7:0] ioc_din,                 // low byte of cpu_dout
    input        [ 7:0] ioc_dout,

    input        [ 7:0] debug_bus,
    output reg   [ 7:0] st_dout
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
wire        allFC;                               // high when NOT in IACK cycle
reg         int4n, int2n;                        // IRQ 4 + IRQ 2 latched, active LOW
reg         LVBLl, LHBLl;                        // edge detectors
reg  [ 3:0] lines_since_vbl;                     // 0..15, saturates at 8
reg         intl_fired_this_vbl;                 // gate IRQ 2 to one fire per vbl

assign cpu_addr  = A;
assign main_addr = A[18:1];
assign main_dsn  = {UDSn, LDSn};
assign main_dout = cpu_dout;
assign main_rnw  = RnW;
assign allFC     = ~&FC;                         // FC==7 means IACK cycle

// IPL encoding: drive the lowest active level, idle = 3'b111.
//   IRQ 4 active, IRQ 2 idle → IPLn = ~4 = 3'b011
//   IRQ 2 active, IRQ 4 idle → IPLn = ~2 = 3'b101
//   both active              → 68k autoselects highest (4) → 3'b011
// The pin polarity on the 68k is "level encoded inverted", so
// IPLn = ~level. We compute level first then invert.
wire [2:0] irq_level = (~int4n) ? 3'd4 :
                       (~int2n) ? 3'd2 :
                                  3'd0;
assign IPLn = ~irq_level;

// VPAn: autovector IACK for any IRQ. Taito B uses level 2 and level 4 —
// both autovectored. Asserting VPAn during any IACK (FC==7, ASn low,
// RnW high) returns the autovector to the 68k.
assign VPAn = !(!ASn && FC==3'd7 && RnW);

// ============================================================================
// Address decoder — combinational, ASn-gated
// ============================================================================
//
// rastsag2_map (taito_b.cpp:369):
//   A[23:20] = 0x0  ROM (0x000000-0x07FFFF)
//   A[23:20] = 0x2  palette RAM   (0x200000-0x201FFF)  - 4 KB
//   A[23:20] = 0x4  TC0180VCU window (0x400000-0x47FFFF)
//     A[18:16] = 0     VRAM            (0x400000-0x40FFFF)  - 64 KB
//     A[18:16] = 1     spr/scroll/pad  (0x410000-0x413FFF)  - 16 KB
//     A[18:15] = 0011  ctrl regs       (0x418000-0x41801F)  - 32 bytes
//     A[18:18] = 1     framebuffer     (0x440000-0x47FFFF)  - 256 KB (HITICE)
//   A[23:20] = 0x6  work RAM (0x600000-0x607FFF)
//   A[23:20] = 0x8  TC0140SYT (0x800001 / 0x800003)
//   A[23:20] = 0xA  TC0220IOC (0xA00001-0xA0000F, byte at odd addresses)
reg         pal_cs;
reg         vram_cs;                             // 0x400000-0x40FFFF
reg         oram_cs;                             // 0x410000-0x413FFF (spr+scroll+pad)
reg         vcuctrl_cs;                          // 0x418000-0x41801F
reg         fb_cs;                               // 0x440000-0x47FFFF (framebuffer)
reg         ram_cs;                              // 0x600000-0x607FFF
reg         syt_cs_r;
reg         ioc_cs_r;

always @* begin
    rom_cs     = allFC && !ASn &&  A[23:19] == 5'h00;                 // 0x000000-0x07FFFF
    pal_cs     = allFC && !ASn &&  A[23:13] == 11'b0010_0000_000;     // 0x200000-0x201FFF
    vram_cs    = allFC && !ASn &&  A[23:16] == 8'h40;                 // 0x400000-0x40FFFF
    oram_cs    = allFC && !ASn &&  A[23:14] == 10'b0100_0001_00;      // 0x410000-0x413FFF
    vcuctrl_cs = allFC && !ASn &&  A[23: 5] == 19'b0100_0001_1000_0000_000; // 0x418000-0x41801F
    fb_cs      = allFC && !ASn &&  A[23:18] == 6'b0100_01;            // 0x440000-0x47FFFF
    ram_cs     = allFC && !ASn &&  A[23:15] == 9'b0110_0000_0;        // 0x600000-0x607FFF
    syt_cs_r   = allFC && !ASn &&  A[23:20] == 4'h8;                  // 0x800000
    ioc_cs_r   = allFC && !ASn &&  A[23:20] == 4'hA;                  // 0xA00000
end

// SYT bus drive (4-bit nibble on low lane, byte at A1 selects port vs comm)
// Taito B System maps SYT at EVEN addresses ($800000=port, $800002=comm),
// so the 4-bit byte data lands on the UPPER data lane (UDS) — bits 11:8 of
// cpu_dout.  (Superman's Taito X System uses ODD addresses with LDS; that
// drove the original copy here, which was wrong for the B-System bus.)
assign syt_cs   = syt_cs_r;
assign syt_addr = A[1];
assign syt_we   = syt_cs_r & ~RnW & ~UDSn;
assign syt_din  = cpu_dout[11:8];

// TC0220IOC: A[4:1] selects 1 of 16 registers, byte on high lane
// (umask16(0xff00) in MAME → reads/writes use UDSn, data is in
// cpu_dout[15:8] / cpu_din[15:8]).
assign ioc_cs    = ioc_cs_r;
assign ioc_addr  = A[4:1];
assign ioc_rnw   = RnW;
assign ioc_lds_n = UDSn;                         // IOC sits on UPPER byte lane
assign ioc_din   = cpu_dout[15:8];

// Byte-lane writes
wire [1:0] cpu_we = {~UDSn, ~LDSn} & {2{~RnW}};

// ============================================================================
// VCU ctrl register file — 16 bytes at 0x418000-0x41801F
// ============================================================================
//
// Full 8×16-bit register file mirroring MAME's m_ctrl[0..7].
//
// The chip is byte-addressable from the 68k: even addr → upper byte (UDS),
// odd addr → lower byte (LDS). A[3:1] selects which 16-bit word (0..7).
// Reads return the latched value; writes update the addressed byte lane.
//
// MAME ctrl_w decoder (tc0180vcu.cpp:223) extracts these fields:
//   ctrl[0] high byte : FG rambank pair  -> ((>>0)&0xf)<<12 / ((>>4)&0xf)<<12
//   ctrl[1] high byte : BG rambank pair  -> same encoding
//   ctrl[2..3] high   : per-block scroll-divisor counts (FG, BG)
//   ctrl[4..5] high   : text tile bank 0 / 1
//   ctrl[6] high      : text ram page  -> ((>>0)&0xf)<<11
//   ctrl[7] high      : video_control  (flip, fb_page, sprite priority)
//
// We store the full word so any future field outside the high byte is
// available without retro-fitting the latch.
reg [15:0] ctrl_word [0:7];
integer i;
always @(posedge clk, posedge rst) begin
    if (rst) begin
        for (i = 0; i < 8; i = i + 1) ctrl_word[i] <= 16'h0;
    end else if (vcuctrl_cs && ~RnW) begin
        if (~UDSn) ctrl_word[A[3:1]][15:8] <= cpu_dout[15:8];
        if (~LDSn) ctrl_word[A[3:1]][ 7:0] <= cpu_dout[ 7:0];
    end
end

always @* begin
    vcu_ctrl = { ctrl_word[7], ctrl_word[6], ctrl_word[5], ctrl_word[4],
                 ctrl_word[3], ctrl_word[2], ctrl_word[1], ctrl_word[0] };
end

// ============================================================================
// On-chip RAMs
// ============================================================================
wire [15:0] ram_dout, pal_dout_a, vram_dout_a, oram_dout_a;

// Work RAM — 16K words = 32 KB at 0x600000-0x607FFF
jtframe_dual_ram16 #(.AW(14)) u_workram(
    .clk0  ( clk          ),
    .data0 ( cpu_dout     ),
    .addr0 ( A[14:1]      ),
    .we0   ( cpu_we & {2{ram_cs}} ),
    .q0    ( ram_dout     ),
    .clk1  ( clk          ),
    .data1 ( 16'h0        ),
    .addr1 ( 14'd0        ),
    .we1   ( 2'b00        ),
    .q1    (              )
);

// Palette RAM — 2K words = 4 KB at 0x200000-0x201FFF
jtframe_dual_ram16 #(.AW(12)) u_pal(
    .clk0  ( clk          ),
    .data0 ( cpu_dout     ),
    .addr0 ( A[12:1]      ),
    .we0   ( cpu_we & {2{pal_cs}} ),
    .q0    ( pal_dout_a   ),
    .clk1  ( clk          ),
    .data1 ( 16'h0        ),
    .addr1 ( pal_addr_b   ),
    .we1   ( 2'b00        ),
    .q1    ( pal_dout_b   )
);

// VRAM — 32K words = 64 KB at 0x400000-0x40FFFF
// Holds BG/FG tile codes+attributes; the VCU bank-switches which
// sub-regions feed each tile plane. For first cut the 68k just reads
// and writes the whole window linearly.
jtframe_dual_ram16 #(.AW(15)) u_vram(
    .clk0  ( clk          ),
    .data0 ( cpu_dout     ),
    .addr0 ( A[15:1]      ),
    .we0   ( cpu_we & {2{vram_cs}} ),
    .q0    ( vram_dout_a  ),
    .clk1  ( clk          ),
    .data1 ( 16'h0        ),
    .addr1 ( vram_addr_b  ),
    .we1   ( 2'b00        ),
    .q1    ( vram_dout_b  )
);

// Sprite/scroll combined — 8K words = 16 KB at 0x410000-0x413FFF
// Layout (per tc0180vcu_memrw):
//   0x10000-0x1197F  sprite RAM (~3.2K words)
//   0x11980-0x137FF  unused/padding
//   0x13800-0x13FFF  scroll RAM (1K words, line-scroll for BG/FG)
// All 68k-readable as plain word RAM; the VCU pipeline carves up the
// regions on the display side.
jtframe_dual_ram16 #(.AW(13)) u_oram(
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

// Framebuffer (0x440000-0x47FFFF) is currently a black hole — the
// rastsag2 game doesn't touch it (it's a Hitice / Realpunc feature).
// Reads return 0, writes ignored. If a game in this family ever needs
// it, allocate ~256 KB of BRAM or external memory here.
/* verilator lint_off UNUSED */
wire _unused_fb = fb_cs;
/* verilator lint_on UNUSED */

// ============================================================================
// Read multiplexer
// ============================================================================
always @(posedge clk) begin
    cpu_din <= rom_cs     ? rom_data                          :
               ram_cs     ? ram_dout                          :
               pal_cs     ? pal_dout_a                        :
               vram_cs    ? vram_dout_a                       :
               oram_cs    ? oram_dout_a                       :
               vcuctrl_cs ? ctrl_word[A[3:1]]                 :
               syt_cs_r   ? {4'h0, syt_dout, 8'hFF}           :   // UDS lane on even addr
               ioc_cs_r   ? {ioc_dout, 8'hFF}                 :  // umask 0xff00
               16'hFFFF;
end

// ============================================================================
// IRQ generation
// ============================================================================
//
// Implements MAME tc0180vcu.cpp::vblank_callback + update_intl exactly:
//
//   At vblank start (LVBL 1→0):
//       INTH (= IRQ 4) asserted (HOLD_LINE).
//       Start an 8-scanline countdown.
//   8 scanlines later:
//       INTH cleared, INTL (= IRQ 2) asserted.
//   At vblank end (LVBL 0→1):
//       INTL cleared.
//
// HOLD_LINE in MAME means "line stays asserted until the 68k acknowledges
// the IACK or the chip explicitly clears it." We mirror that with VPAn-
// gated clearing per IRQ level.
//
// LHBL falling edge = start of a new horizontal line (LHBL goes low during
// HBLANK). We use that to tick the scanline counter while inside vblank.
//
// Without IRQ 2 the game's vblank handler runs but never completes its
// "phase B" frame-tick — the main loop at 0x59E spins forever. Wiring
// both IRQs is the precondition for the game to exit self-test and
// start writing tiles into VRAM (BOOT_TRACE.md §"Pre-vector landmark").
always @(posedge clk, posedge rst) begin
    if (rst) begin
        int4n               <= 1'b1;
        int2n               <= 1'b1;
        LVBLl               <= 1'b1;
        LHBLl               <= 1'b1;
        lines_since_vbl     <= 4'd0;
        intl_fired_this_vbl <= 1'b0;
    end else begin
        LVBLl <= LVBL;
        LHBLl <= LHBL;

        // ── Vblank entry: assert IRQ 4, reset line counter + intl gate ──
        if (LVBLl & ~LVBL) begin
            int4n               <= 1'b0;
            lines_since_vbl     <= 4'd0;
            intl_fired_this_vbl <= 1'b0;
        end

        // ── Inside vblank: count LHBL falling edges (one per scanline) ──
        if (~LVBL && LHBLl & ~LHBL && lines_since_vbl != 4'd15) begin
            lines_since_vbl <= lines_since_vbl + 4'd1;
        end

        // ── 8 lines after vblank entry: clear INTH (no-op if already ack'd
        //    via IACK), assert INTL. Fires once per vblank regardless of
        //    whether the 68k has yet acknowledged IRQ 4. This is the MAME
        //    timer-callback path: m_intl_timer->adjust(... +8 lines ...)
        //    then update_intl() unconditionally toggles inth→clear and
        //    intl→assert.
        if (~LVBL && lines_since_vbl == 4'd8 && !intl_fired_this_vbl) begin
            int4n               <= 1'b1;
            int2n               <= 1'b0;
            intl_fired_this_vbl <= 1'b1;
        end

        // ── Vblank exit: clear INTL ──
        if (~LVBLl & LVBL) begin
            int2n <= 1'b1;
        end

        // ── IACK clears acknowledged IRQ (HOLD_LINE semantics) ──
        if (!VPAn) begin
            if (irq_level == 3'd4) int4n <= 1'b1;
            if (irq_level == 3'd2) int2n <= 1'b1;
        end
    end
end

// ============================================================================
// DTACK helper — 48 MHz × 1/4 = 12 MHz (Taito B 68k clock)
// ============================================================================
wire bus_cs    = rom_cs;
wire bus_busy  = rom_cs & ~rom_ok;
wire bus_legit = 1'b0;

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
    .num        ( 7'd1      ),                   // 48 × 1/4 = 12 MHz
    .den        ( 8'd4      ),
    .DTACKn     ( DTACKn    ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    .fave       (           ),
    .fworst     (           )
);

// ============================================================================
// jtframe_m68k — FX68K or J68 wrapper
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

    .BERRn    ( 1'b1      ),
    .HALTn    ( dip_pause ),
    .BRn      ( 1'b1      ),
    .BGACKn   ( 1'b1      ),
    .BGn      (           ),

    .DTACKn   ( DTACKn    ),
    .IPLn     ( IPLn      )
);

// ============================================================================
// SIMULATION-gated PC dumper — load-bearing diagnostic per AGENTS.md §2b
// ============================================================================
//
// Sample cpu_din WHILE M1 / opcode-fetch is active and rom_ok is asserted —
// NOT on the rising edge of M1, because the bus floats to FF the instant
// MREQ goes back high. For 68k we approximate: pick up the address each
// time the CPU starts a bus cycle (ASn falling) in supervisor space.
`ifdef SIMULATION
// ── Parallel rst tracker so we can compare main vs snd module view ──
initial $display("[INIT] jttaitob_main debug block compiled in");
reg main_rst_d = 1'b0;
always @(posedge clk) begin
    main_rst_d <= rst;
    if (main_rst_d !== rst) begin
        $display("[%0t] MAIN rst: %b → %b  (rom_count=%0d)",
                 $time, main_rst_d, rst, rom_count);
    end
end
integer main_state_ctr = 0;
always @(posedge clk) begin
    main_state_ctr <= main_state_ctr + 1;
    if ((main_state_ctr & 32'h000FFFFF) == 32'h0) begin
        $display("[%0t] MAIN state @ctr=%0d: rst=%b  PC_addr=0x%h  rom_cs=%b",
                 $time, main_state_ctr, rst, {1'b0, A, 1'b0}, rom_cs);
    end
end

integer rom_count = 0;
integer irq_count = 0;
integer pal_count = 0;
integer vram_count = 0;
integer oram_count = 0;
integer syt_count = 0;
integer ioc_count = 0;
integer pal_w_count = 0, vram_w_count = 0, oram_w_count = 0;
reg ASn_d;
always @(posedge clk) begin
    ASn_d <= ASn;
    if (ASn_d & ~ASn) begin
        if (rom_cs)    rom_count  <= rom_count  + 1;
        if (pal_cs)    pal_count  <= pal_count  + 1;
        if (vram_cs)   vram_count <= vram_count + 1;
        if (oram_cs)   oram_count <= oram_count + 1;
        if (syt_cs_r)  syt_count  <= syt_count  + 1;
        if (ioc_cs_r)  ioc_count  <= ioc_count  + 1;
    end
    if (!VPAn) irq_count <= irq_count + 1;
    // Per-region write counters — only count when cpu_we actually fires
    if (pal_cs  && |cpu_we) pal_w_count  <= pal_w_count  + 1;
    if (vram_cs && |cpu_we) vram_w_count <= vram_w_count + 1;
    if (oram_cs && |cpu_we) oram_w_count <= oram_w_count + 1;
end

integer prev_print = 0;
always @(posedge clk) begin
    if (rom_count != prev_print && (rom_count % 250000) == 0) begin
        $display("[%0t] SIM rom=%0d  irq=%0d  pal=%0d  vram=%0d  oram=%0d  syt=%0d  ioc=%0d",
                 $time, rom_count, irq_count,
                 pal_count, vram_count, oram_count, syt_count, ioc_count);
        prev_print <= rom_count;
    end
end

// ----------------------------------------------------------------------------
// Validation-gate landmarks — one-shot $display on first hit of each gate.
// These match cores/taitob/doc/BOOT_TRACE.md gates 1-6 on the 68k side.
// ----------------------------------------------------------------------------
reg gate_seen_404, gate_seen_sp, gate_seen_vctl, gate_seen_ioc,
    gate_seen_syt, gate_seen_ramclr;
reg [15:0] last_ramclr_pc;
initial begin
    gate_seen_404    = 1'b0;
    gate_seen_sp     = 1'b0;
    gate_seen_vctl   = 1'b0;
    gate_seen_ioc    = 1'b0;
    gate_seen_syt    = 1'b0;
    gate_seen_ramclr = 1'b0;
    last_ramclr_pc   = 16'h0;
end

reg gate_seen_scroll;
initial gate_seen_scroll = 1'b0;

always @(posedge clk) begin
    if (ASn_d & ~ASn) begin
        // Gate 1 — first ROM fetch at PC=0x404 (post-reset, after the
        // implicit move #$2700,SR at 0x400 that MAME's trace skips).
        if (!gate_seen_404 && rom_cs && A == 23'h000202 /* PC>>1 = 0x404>>1 */) begin
            $display("[%0t] GATE 1: PC=0x000404 reached (first user fetch)", $time);
            gate_seen_404 <= 1'b1;
        end
        // Gate 3 — first VCU ctrl write
        if (!gate_seen_vctl && vcuctrl_cs && ~RnW) begin
            $display("[%0t] GATE 3: VCU ctrl write @ 0x%h (offs %0d) <= 0x%h",
                     $time, {1'b0, A, 1'b0}, A[3:1], cpu_dout);
            gate_seen_vctl <= 1'b1;
        end
        // Gate 4 — first scroll-RAM write (FG @ 0x413800 or BG @ 0x413C00).
        // oram_cs covers 0x410000-0x413FFF; gate fires on A[13:11] = 7 or higher.
        if (!gate_seen_scroll && oram_cs && ~RnW &&
            (A[13:11] == 3'b111 /* >= 0x413800 in the oram window */)) begin
            $display("[%0t] GATE 4: scroll RAM write @ 0x%h <= 0x%h",
                     $time, {1'b0, A, 1'b0}, cpu_dout);
            gate_seen_scroll <= 1'b1;
        end
        // Gate 5 — first IOC write
        if (!gate_seen_ioc && ioc_cs_r && ~RnW) begin
            $display("[%0t] GATE 5: IOC write @ 0x%h <= 0x%h", $time,
                     {1'b0, A, 1'b0}, cpu_dout[15:8]);
            gate_seen_ioc <= 1'b1;
        end
        // Gate 10 — first SYT write
        if (!gate_seen_syt && syt_cs_r && ~RnW) begin
            $display("[%0t] GATE 10: SYT write @ 0x%h <= 0x%h", $time,
                     {1'b0, A, 1'b0}, cpu_dout[15:8]);
            gate_seen_syt <= 1'b1;
        end
        // Gate 6 — work-RAM clear progress (poll PC after each ASn fall
        // for the loop body 0x486-0x48A). When we *stop* hitting that
        // range we know the loop finished.
        if (rom_cs && (A[18:1] == 18'h243 /* 0x486>>1 */)) begin
            last_ramclr_pc <= 16'h0486;
        end
        if (!gate_seen_ramclr && last_ramclr_pc == 16'h0486 &&
            rom_cs && A[18:1] > 18'h245 /* PC > 0x48A: loop exited */) begin
            $display("[%0t] GATE 6: work-RAM clear loop exited (next PC > 0x48A)",
                     $time);
            gate_seen_ramclr <= 1'b1;
        end
    end
end

// ----------------------------------------------------------------------------
// Live PC sampler — log every Nth ROM access AFTER gate 6 so we can see
// where the CPU is heading (helps diagnose stalls between gates).
// ----------------------------------------------------------------------------
integer post_clear_sample = 0;
reg seen_verify_loop = 1'b0;
reg seen_verify_exit = 1'b0;
integer verify_iter = 0;
always @(posedge clk) begin
    if (gate_seen_ramclr && ASn_d & ~ASn && rom_cs) begin
        post_clear_sample <= post_clear_sample + 1;
        // Print first hit outside the verify-loop body (PC<0x500 or PC>0x50E).
        // This tells us when the verify loop terminates.
        if (A[18:1] == 18'h281 /* 0x502 */) seen_verify_loop <= 1'b1;
        if (!seen_verify_exit && seen_verify_loop &&
            (A[18:1] >= 18'h288 /* 0x510 */)) begin
            $display("[%0t] VERIFY: loop exited, next PC=0x%h after %0d iters",
                     $time, {1'b0, A, 1'b0}, verify_iter);
            seen_verify_exit <= 1'b1;
        end
        // Count loop iterations (one per cmp.b at 0x502 entry)
        if (A[18:1] == 18'h281) verify_iter <= verify_iter + 1;
        // Print every 50000th ROM access — keeps log small but visible.
        // Include running PAL/VRAM counts so we can see if the game is
        // still drawing or just spinning on a non-existent condition.
        if ((post_clear_sample % 200000) == 0) begin
            $display("[%0t] sample=%0d PC=0x%h pal=%0d vram=%0d (p0=%0d p1=%0d p2=%0d p3=%0d) oram=%0d",
                     $time, post_clear_sample, {1'b0, A, 1'b0},
                     pal_count, vram_count,
                     vram_page_writes[0], vram_page_writes[1],
                     vram_page_writes[2], vram_page_writes[3],
                     oram_count);
        end
    end
end

// One-shot critical-path markers
reg pc_960_seen, pc_2c9c_seen, pc_2d44_seen, pc_2d56_seen, pc_c0c_seen;
initial begin
    pc_960_seen  = 1'b0; pc_2c9c_seen = 1'b0; pc_2d44_seen = 1'b0;
    pc_2d56_seen = 1'b0; pc_c0c_seen  = 1'b0;
end
always @(posedge clk) begin
    if (ASn_d & ~ASn && rom_cs) begin
        if (!pc_960_seen  && A == 23'h0004B0 /* 0x960>>1 */) begin
            $display("[%0t] PC=0x960  (release-Z80-reset chain entry!)", $time);
            pc_960_seen <= 1'b1;
        end
        if (!pc_2c9c_seen && A == 23'h00164E /* 0x2C9C>>1 */) begin
            $display("[%0t] PC=0x2C9C (calls 2D44 release reset)", $time);
            pc_2c9c_seen <= 1'b1;
        end
        if (!pc_2d44_seen && A == 23'h0016A2 /* 0x2D44>>1 */) begin
            $display("[%0t] PC=0x2D44 (RELEASE Z80 RESET)", $time);
            pc_2d44_seen <= 1'b1;
        end
        if (!pc_2d56_seen && A == 23'h0016AB /* 0x2D56>>1 */) begin
            $display("[%0t] PC=0x2D56 (ASSERT Z80 RESET — early boot)", $time);
            pc_2d56_seen <= 1'b1;
        end
        if (!pc_c0c_seen && A == 23'h000606 /* 0xC0C>>1 */) begin
            $display("[%0t] PC=0xC0C  (checksum-fail bra.)", $time);
            pc_c0c_seen <= 1'b1;
        end
    end
end

// One-shot IRQ entry markers — track when each handler first runs.
// IRQ 4 vector handler lives at 0x5C0; IRQ 2 vector handler at 0x5A4
// (from the ROM image at offset 0x68/0x70).
reg irq4_entered, irq2_entered;
integer irq4_hits = 0, irq2_hits = 0;
initial begin irq4_entered = 1'b0; irq2_entered = 1'b0; end
always @(posedge clk) begin
    if (ASn_d & ~ASn && rom_cs) begin
        if (A == 23'h0002E0 /* 0x5C0 >> 1 */) irq4_hits <= irq4_hits + 1;
        if (A == 23'h0002D2 /* 0x5A4 >> 1 */) irq2_hits <= irq2_hits + 1;
        if (!irq4_entered && A == 23'h0002E0) begin
            $display("[%0t] IRQ4 vector reached at PC=0x5C0 (sample=%0d)",
                     $time, post_clear_sample);
            irq4_entered <= 1'b1;
        end
        if (!irq2_entered && A == 23'h0002D2) begin
            $display("[%0t] IRQ2 vector reached at PC=0x5A4 (sample=%0d)",
                     $time, post_clear_sample);
            irq2_entered <= 1'b1;
        end
    end
end

// First VRAM / palette / sprite-RAM write — proves the game has started
// drawing. These should fire after IRQ 2 is running properly.
reg first_pal_seen, first_vram_seen, first_oram_seen;
// Per-VRAM-page write counters (each page = 0x1000 words).
// Page 0 = FG codes, page 1 = FG attrs, page 2 = BG codes, page 3 = BG attrs
// (with nastar's ctrl[0]=0x10, ctrl[1]=0x32 config).
integer vram_page_writes [0:7];
integer pi;
initial begin
    first_pal_seen  = 1'b0;
    first_vram_seen = 1'b0;
    first_oram_seen = 1'b0;
    for (pi = 0; pi < 8; pi = pi + 1) vram_page_writes[pi] = 0;
end
always @(posedge clk) begin
    if (ASn_d & ~ASn) begin
        if (!first_pal_seen && pal_cs && ~RnW) begin
            $display("[%0t] FIRST PAL write @ 0x%h <= 0x%h (sample=%0d)",
                     $time, {1'b0, A, 1'b0}, cpu_dout, post_clear_sample);
            first_pal_seen <= 1'b1;
        end
        if (!first_vram_seen && vram_cs && ~RnW) begin
            $display("[%0t] FIRST VRAM write @ 0x%h <= 0x%h (sample=%0d)",
                     $time, {1'b0, A, 1'b0}, cpu_dout, post_clear_sample);
            first_vram_seen <= 1'b1;
        end
        // Track VRAM writes per 4 KB page (A[15:13] selects page 0..7)
        if (vram_cs && ~RnW) begin
            vram_page_writes[A[15:13]] <= vram_page_writes[A[15:13]] + 1;
        end
        if (!first_oram_seen && oram_cs && ~RnW) begin
            $display("[%0t] FIRST OBJ write @ 0x%h <= 0x%h (sample=%0d)",
                     $time, {1'b0, A, 1'b0}, cpu_dout, post_clear_sample);
            first_oram_seen <= 1'b1;
        end
    end
end

// End-of-sim summary + BRAM dump (Superman pattern, adapted).
// Shadow arrays are mirrored to every CPU write so $writememh produces
// a complete contents dump at sim end — usable for scene-replay later.
reg [15:0] dbg_pal  [0:4095];      //  8 KB palette  ($200000-$201FFF)
reg [15:0] dbg_vram [0:32767];     // 64 KB VRAM     ($400000-$40FFFF)
reg [15:0] dbg_oram [0:8191];      // 16 KB OBJ/scr  ($410000-$413FFF)
integer si;
initial begin
    for (si = 0; si <  4096; si = si + 1) dbg_pal[si]  = 16'h0;
    for (si = 0; si < 32768; si = si + 1) dbg_vram[si] = 16'h0;
    for (si = 0; si <  8192; si = si + 1) dbg_oram[si] = 16'h0;
end
// Mirror writes using the same gate as the real BRAM (cpu_we, which
// requires UDS/LDS to be asserted — meaning data is valid). For byte
// writes we preserve the un-written lane from the previous shadow value.
reg first_vw_logged = 1'b0;

// IRQ assertion counters (separate from handler-entry counters above)
integer int4_assert_count = 0, int2_assert_count = 0, vbl_entry_count = 0;
reg int4n_prev = 1'b1, int2n_prev = 1'b1;
always @(posedge clk) begin
    int4n_prev <= int4n;
    int2n_prev <= int2n;
    if (int4n_prev & ~int4n) int4_assert_count <= int4_assert_count + 1;
    if (int2n_prev & ~int2n) int2_assert_count <= int2_assert_count + 1;
    if (LVBLl & ~LVBL)       vbl_entry_count   <= vbl_entry_count   + 1;
end
always @(posedge clk) begin
    if (pal_cs  && |cpu_we) begin
        if (cpu_we[0]) dbg_pal [A[12:1]][ 7:0] <= cpu_dout[ 7:0];
        if (cpu_we[1]) dbg_pal [A[12:1]][15:8] <= cpu_dout[15:8];
    end
    if (vram_cs && |cpu_we) begin
        if (cpu_we[0]) dbg_vram[A[15:1]][ 7:0] <= cpu_dout[ 7:0];
        if (cpu_we[1]) dbg_vram[A[15:1]][15:8] <= cpu_dout[15:8];
        if (!first_vw_logged) begin
            $display("[%0t] FIRST_VW: A=0x%h cpu_we=%b cpu_dout=0x%h",
                     $time, {1'b0, A, 1'b0}, cpu_we, cpu_dout);
            first_vw_logged <= 1'b1;
        end
    end
    if (oram_cs && |cpu_we) begin
        if (cpu_we[0]) dbg_oram[A[13:1]][ 7:0] <= cpu_dout[ 7:0];
        if (cpu_we[1]) dbg_oram[A[13:1]][15:8] <= cpu_dout[15:8];
    end
end

// Periodic BRAM dump — verilator's `final` block isn't reliably called
// when -video N terminates the sim, so we trigger writememh after the
// game has clearly passed self-test (IRQ 2 has been acked AND enough
// palette writes have accumulated to imply real-content drawing).
reg dump_done = 1'b0;
always @(posedge clk) begin
    if (!dump_done && irq2_hits > 250) begin
        $display("[%0t] DUMP: pal=%0d vram=%0d oram=%0d irq4=%0d irq2=%0d palW=%0d vramW=%0d oramW=%0d vbl=%0d int4!=%0d int2!=%0d",
                 $time, pal_count, vram_count, oram_count, irq4_hits, irq2_hits,
                 pal_w_count, vram_w_count, oram_w_count,
                 vbl_entry_count, int4_assert_count, int2_assert_count);
        $writememh("sim_pal.hex",  dbg_pal);
        $writememh("sim_vram.hex", dbg_vram);
        $writememh("sim_oram.hex", dbg_oram);
        dump_done <= 1'b1;
    end
end
`endif

// Debug status byte — exposed up to game.v
always @(posedge clk) begin
    case (debug_bus[2:0])
        3'd0: st_dout <= {int4n, int2n, 1'b0, 1'b0, ctrl_word[7][11:8]};
        3'd1: st_dout <= ioc_dout;
        3'd2: st_dout <= {4'h0, syt_dout};
        default: st_dout <= 8'hFF;
    endcase
end

`else  // NOMAIN — scene replay

// ============================================================================
// Scene replay: the 68k/sound side is stubbed and the video pipeline is fed
// from BRAMs preloaded with a MAME-captured scene.  See
//   cores/taitob/ver/rastan2/mame_scripts/dump_burst.lua  (capture)
//   cores/taitob/ver/game/rest2bin.sh                     (split dump.bin)
// jtsim's `-s <scene>` flag splits dump.bin into pal.bin / vram.bin /
// oram.bin / ctrl.hex in the working dir, which the loaders below pick up.
// ============================================================================

// Bus tie-offs for the stubbed CPU side.
assign cpu_addr  = 23'd0;
assign main_addr = 18'd0;
assign main_dsn  = 2'b11;
assign main_dout = 16'h0;
assign main_rnw  = 1'b1;
assign syt_cs    = 1'b0;
assign syt_addr  = 1'b0;
assign syt_we    = 1'b0;
assign syt_din   = 4'h0;
assign ioc_cs    = 1'b0;
assign ioc_addr  = 4'd0;
assign ioc_rnw   = 1'b1;
assign ioc_lds_n = 1'b1;
assign ioc_din   = 8'h0;
initial begin
    rom_cs  = 1'b0;
    st_dout = 8'h0;
end

// VCU ctrl[0..7] restored from the scene (ctrl.hex = 8 big-endian 16-bit
// words emitted by rest2bin.sh). Drives vcu_ctrl exactly like the live
// branch builds it from ctrl_word[].
reg [15:0] scene_ctrl [0:7];
integer sci;
initial begin
    for (sci = 0; sci < 8; sci = sci + 1) scene_ctrl[sci] = 16'h0;
    $readmemh("ctrl.hex", scene_ctrl);
end
always @* begin
    vcu_ctrl = { scene_ctrl[7], scene_ctrl[6], scene_ctrl[5], scene_ctrl[4],
                 scene_ctrl[3], scene_ctrl[2], scene_ctrl[1], scene_ctrl[0] };
end

// Scene palette / VRAM / OBJ-scroll RAMs — read-only, port-B to video.v.
// ENDIAN=1 matches MAME's big-endian 68k byte stream (even=hi, odd=lo).
jtframe_dual_ram16 #(.AW(12), .ENDIAN(1), .SIMFILE("pal.bin")) u_pal_sim(
    .clk0  ( clk          ),
    .data0 ( 16'h0        ),
    .addr0 ( 12'd0        ),
    .we0   ( 2'b00        ),
    .q0    (              ),
    .clk1  ( clk          ),
    .data1 ( 16'h0        ),
    .addr1 ( pal_addr_b   ),
    .we1   ( 2'b00        ),
    .q1    ( pal_dout_b   )
);

jtframe_dual_ram16 #(.AW(15), .ENDIAN(1), .SIMFILE("vram.bin")) u_vram_sim(
    .clk0  ( clk          ),
    .data0 ( 16'h0        ),
    .addr0 ( 15'd0        ),
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

`endif

endmodule
