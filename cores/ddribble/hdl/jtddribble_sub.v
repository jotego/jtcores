/*  jtddribble_sub.v — SUB CPU (MC6809E) for Double Dribble (Konami GX690)
    GPL3 — see jtcores LICENSE

    Hardware on schematic page 1 (sub CPU + sound CPU + I/O):
      - MC6809E at designator A12 (top-left area of page 1), full 6809E pinout
        visible pins: HALT, NMI, IRQ, FIRQ, RESET, BS, BA, R/W,
                      CLKE (pin 34), CLKQ (pin 35), AVMA, BUSY, TSC,
                      A0..A15, D0..D7
      - Konami 007553 PAL at C11 — confirmed sub-side address decoder.
        JEDEC + decoded equations + pin-label mapping live in:
          cores/ddribble/doc/Konami_007553.jed
          cores/ddribble/doc/Konami_007553_equations.txt
          cores/ddribble/doc/Konami_007553_pinout.md
        Outputs (active-low): /ROM (pin 12, sub ROM CE at C12),
          /CRAM (pin 13, shared with main 0x0000-0x1FFF),
          /AFE (pin 14, watchdog 0x3C00),
          /SET (pin 15, coin counter 0x3400),
          /DIP3 (pin 16), /DIP2 (pin 17),
          /IOIN (pin 18, joystick/system at 0x2800),
          /SRAM (pin 19, shared with sound 0x2000-0x27FF).
      - 27512 EPROM at designator C12 — physical chip is 64 KB but MAME's
        romset only loads 32 KB of data; the upper half is presumed unused
        or banking that we haven't yet investigated.
      - LS245 J9  bus transceiver between sub-CPU data bus and shared SRAM
      - LS157 C14 address mux (CPU-side vs main-side select for shared SRAM)
      - LS244 G14 buffer (same chip that buffers CK18 and SCLK — different gates)
      - LS04  H8 inverter, LS74 D15 flip-flop, glue
      - 32 KB program EPROM (27256) somewhere near A19 — TBD which designator

    MAME ref (pinned commit 347fd2c) for things NOT visible on the sheets:
      - konami/ddribble.cpp:537     MC6809E @ XTAL(18'432'000) / 12 = 1.536 MHz
      - konami/ddribble.cpp:327     FIRQ on V-blank fall (HOLD_LINE)
    (The address ranges below come from the 007553 PAL equations, not MAME.)
*/

module jtddribble_sub(
    input               rst,
    input               clk,
    input               cen,           // 1.5 MHz CPU clock-enable
    output              cpu_cen,

    // ROM bus to SDRAM — 27256 = 32 KB, no banking
    output      [14:0]  rom_addr,
    output reg          rom_cs,
    input       [ 7:0]  rom_data,
    input               rom_ok,

    // CPU bus (exposed for downstream BRAM address routing in game.v)
    output      [15:0]  A,
    output              cpu_rnw,
    output      [ 7:0]  cpu_dout,

    // BRAM chip-selects + read-back data (active high)
    output reg          shared_ms_cs,  // 0x0000-0x1FFF  shared with MAIN  [007553 /CRAM, pin 13]
    output reg          shared_sa_cs,  // 0x2000-0x27FF  shared with SOUND
    input       [ 7:0]  shared_ms_dout,
    input       [ 7:0]  shared_sa_dout,

    // I/O port inputs (8-bit each, supplied by game.v from JTFRAME signals)
    input       [ 7:0]  dsw1,          // 0x2800
    input       [ 7:0]  dsw2,          // 0x2C00
    input       [ 7:0]  dsw3,          // 0x3000
    input       [ 7:0]  p1_input,      // 0x2801  joystick1 + buttons
    input       [ 7:0]  p2_input,      // 0x2802  joystick2 + buttons
    input       [ 7:0]  system_input,  // 0x2803  coin/start/service

    // Output strobes / registers
    output reg  [ 1:0]  coin_counter,  // 0x3400 W  — latched in this module
    output reg          wdog_kick,     // 0x3C00 W  — 1-cycle pulse per write
                                       //            (game.v / framework decides what to do)

    // Interrupt inputs.
    //
    // Schematic finding (2026-06-01): the 005885 chip 1 (E16, page 0) fans
    // its NFIR/NIRQ/NNMI outputs out to BOTH CPUs (main A19 AND sub A12),
    // with a deliberate IRQ/FIRQ name swap:
    //    chip NFIR  →  CPU IRQ pin
    //    chip NIRQ  →  CPU FIRQ pin
    //    chip NNMI  →  CPU NMI pin
    // The chip outputs are gated by mmr[4][2:0] (firq_en, irq_en, nmi_en)
    // which boot code zeroes — so we AND cpu_firqn with a direct LVBL→jtframe_ff
    // shortcut (NVSY path on the schematic via the LS244+LS367 buffer chain).
    input               cpu_irqn,      // ← chip 1 NFIR (NOTE the swap)
    input               cpu_nmin,      // ← chip 1 NNMI
    input               cpu_firqn      // ← chip 1 NIRQ (NOTE the swap) — schematic-faithful, no LVBL fallback
);

// ---------------------------------------------------------------------------
// Internal signals
// ---------------------------------------------------------------------------
wire [15:0] addr;
wire        RnW, VMA;
// nFIRQ replaced by `combined_firqn` (chip 1 NIRQ AND vblank_firqn) below.
reg  [ 7:0] cpu_din;
reg         coin_cs, wdog_cs;
reg         dsw1_cs, dsw2_cs, dsw3_cs;
reg         p1_cs, p2_cs, sys_cs;

assign A        = addr;
assign cpu_rnw  = RnW;
assign rom_addr = addr[14:0];          // 32 KB ROM, MSB always 1 in CPU view

// ---------------------------------------------------------------------------
// Address decoder
// ---------------------------------------------------------------------------
// HARDWARE: real decode is the Konami 007553 PAL at C11 on schematic page 1.
// ★ AUTHORITATIVE source: cores/ddribble/doc/Konami_007553_equations.txt
//   (decoded by jedutil from the JEDEC fuse dump on 2026-06-01).
// Pin labels (which PAL input/output corresponds to which schematic net) in
//   cores/ddribble/doc/Konami_007553_pinout.md
//
// PAL OUTPUTS (active-low) → HDL CHIP-SELECT MAPPING:
// ┌─────────┬────────────────────────────────────────┬──────────────────────────┐
// │ /pin    │ Equation (PAL, with EN = NEQ asserted) │ HDL signal — addr range  │
// ├─────────┼────────────────────────────────────────┼──────────────────────────┤
// │ /o12 /ROM   = EN & (A15 | (/A15 & A14))          │ rom_cs       0x8000-FFFF │
// │              (PAL fires 0x4000-0xFFFF — narrowed │ (downstream A15 gating   │
// │               to 0x8000-0xFFFF by downstream LS  │  on the 27512 /CE pin    │
// │               combining /ROM with A15; we model  │  is implicit in our      │
// │               the combined net here.)            │  rom_cs polarity)        │
// │ /o13 /CRAM  = EN & /A15&/A14&/A13                │ shared_ms_cs 0x0000-1FFF │
// │ /o14 /AFE   = EN & /A15&/A14&A13&A12&A11&A10     │ wdog_cs      0x3C00-3FFF │
// │ /o15 /SET   = EN & /A15&/A14&A13&A12&/A11&A10    │ coin_cs      0x3400-37FF │
// │ /o16 /DIP3  = EN & /A15&/A14&A13&A12&/A11&/A10   │ dsw3_cs      0x3000-33FF │
// │ /o17 /DIP2  = EN & /A15&/A14&A13&/A12&A11&A10    │ dsw2_cs      0x2C00-2FFF │
// │ /o18 /IOIN  = EN & /A15&/A14&A13&/A12&A11&/A10   │ split by A[1:0] downstrm │
// │                                                  │ → dsw1/p1/p2/sys @       │
// │                                                  │   0x2800-0x2803          │
// │ /o19 /SRAM  = EN & /A15&/A14&A13&/A12&/A11       │ shared_sa_cs 0x2000-27FF │
// └─────────┴────────────────────────────────────────┴──────────────────────────┘
//
// 0x3800-0x3BFF: no PAL output fires → open bus (8'hff).
//
// Within the /IOIN 1 KB window (0x2800-0x2BFF), an external LS153/LS155
// mux decodes A[1:0] to pick which 8-bit source (DSW1/P1/P2/SYSTEM) drives
// the buffer onto the sub data bus. The CPU only ever touches 0x2800-0x2803
// (verified in 3000-frame attract-mode sim log 2026-06-02), so we model
// just those 4 exact bytes and ignore mirrors at 0x2804..0x2BFF.
//
// /SET and /AFE write-only at the SPECIFIC byte address inside their 1 KB
// windows is sufficient — boot code never touches 0x3401+ or 0x3C01+.
always @(*) begin
    rom_cs       = 0;
    shared_ms_cs = 0;
    shared_sa_cs = 0;
    dsw1_cs      = 0;
    dsw2_cs      = 0;
    dsw3_cs      = 0;
    p1_cs        = 0;
    p2_cs        = 0;
    sys_cs       = 0;
    coin_cs      = 0;
    wdog_cs      = 0;

    if (VMA) begin
        if      (addr >= 16'h8000)                          rom_cs       = 1;  // /ROM   0x8000-0xFFFF
        else if (addr <= 16'h1FFF)                          shared_ms_cs = 1;  // /CRAM  0x0000-0x1FFF
        else if (addr >= 16'h2000 && addr <= 16'h27FF)      shared_sa_cs = 1;  // /SRAM  0x2000-0x27FF
        else if (addr == 16'h2800)                          dsw1_cs      = 1;  // /IOIN + A[1:0]=00
        else if (addr == 16'h2801)                          p1_cs        = 1;  // /IOIN + A[1:0]=01
        else if (addr == 16'h2802)                          p2_cs        = 1;  // /IOIN + A[1:0]=10
        else if (addr == 16'h2803)                          sys_cs       = 1;  // /IOIN + A[1:0]=11
        else if (addr >= 16'h2C00 && addr <= 16'h2FFF)      dsw2_cs      = 1;  // /DIP2  0x2C00-0x2FFF
        else if (addr >= 16'h3000 && addr <= 16'h33FF)      dsw3_cs      = 1;  // /DIP3  0x3000-0x33FF
        else if (addr == 16'h3400 && !RnW)                  coin_cs      = 1;  // /SET   (write-only latch)
        else if (addr == 16'h3C00 && !RnW)                  wdog_cs      = 1;  // /AFE   (write-only kick)
    end
end

// ---------------------------------------------------------------------------
// Data multiplexer — CPU read path
// ---------------------------------------------------------------------------
always @(*) begin
    cpu_din = 8'hff;                                  // open bus
    if      (rom_cs)        cpu_din = rom_data;
    else if (shared_ms_cs)  cpu_din = shared_ms_dout;
    else if (shared_sa_cs)  cpu_din = shared_sa_dout;
    else if (dsw1_cs)       cpu_din = dsw1;
    else if (dsw2_cs)       cpu_din = dsw2;
    else if (dsw3_cs)       cpu_din = dsw3;
    else if (p1_cs)         cpu_din = p1_input;
    else if (p2_cs)         cpu_din = p2_input;
    else if (sys_cs)        cpu_din = system_input;
end


// ---------------------------------------------------------------------------
// Coin counter register — latched on write to 0x3400
// ---------------------------------------------------------------------------
// HARDWARE: real PCB has a flip-flop (LS174 or LS273 typical) gated by the
// 007553 PAL /SET strobe (pin 15). We register the low 2 bits — coin-counter outputs
// drive the JAMMA coin-counter solenoids.
always @(posedge clk, posedge rst) begin
    if (rst)
        coin_counter <= 2'b00;
    else if (cen && coin_cs)
        coin_counter <= cpu_dout[1:0];
end

// ---------------------------------------------------------------------------
// Watchdog kick pulse — 1 cycle high per write to 0x3C00
// ---------------------------------------------------------------------------
// HARDWARE: real PCB has a 555-or-monostable that resets the whole system
// if not kicked within ~200 ms. In HDL we just expose the kick pulse and
// let game.v / JTFRAME decide what to do (typically: nothing in MiSTer,
// the framework's own reset handling supersedes).
always @(posedge clk, posedge rst) begin
    if (rst)
        wdog_kick <= 1'b0;
    else
        wdog_kick <= cen && wdog_cs;
end

// ---------------------------------------------------------------------------
// FIRQ — pulsed on V-blank falling edge
// ---------------------------------------------------------------------------
// HARDWARE: sub CPU's FIRQ pin (pin 3) on A12 is visible on SCHEMATIC page 1.
// Source: same V-blank chain as the main CPU's FIRQ (the LS74 sync flops
// on page 0 produce NVSY which crosses pages and feeds both CPUs' FIRQ).
// Note: 007553 has no dedicated IRQ-mask output — the FIRQ path on this
// PCB is direct (V-blank → CPU FIRQ pin), not gated by the chip's MMR.
// MAME ddribble.cpp:327: m_subcpu->set_input_line(M6809_FIRQ_LINE, HOLD_LINE)
// FIRQ source: chip 1 NIRQ (= cpu_firqn input per the schematic IRQ/FIRQ
// pin swap). Previously combined with an LVBL→jtframe_ff bring-up shortcut;
// removed after the NRD inversion bug was fixed (2026-06-01) made the
// chip's interrupt-enable writes apply correctly. Chip-side FIRQ is now
// the schematic-faithful path.

// ---------------------------------------------------------------------------
// MC6809E CPU core
// ---------------------------------------------------------------------------
jtframe_sys6809 #(.RAM_AW(0)) u_cpu(
    .rstn       ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .cpu_cen    ( cpu_cen   ),
    .nIRQ       ( cpu_irqn  ),         // chip 1 NFIR (swap per schematic)
    .nFIRQ      ( cpu_firqn ),         // chip 1 NIRQ (swap per schematic)
    .nNMI       ( cpu_nmin  ),         // chip 1 NNMI
    .irq_ack    (           ),
    .bus_busy   ( 1'b0      ),
    .A          ( addr      ),
    .RnW        ( RnW       ),
    .VMA        ( VMA       ),
    .ram_cs     ( 1'b0      ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .ram_dout   (           ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_din    ( cpu_din   )
);

endmodule