/*  jtddribble_main.v — main CPU (MC6809E) for Double Dribble (Konami GX690)
    GPL3 — see jtcores LICENSE

    Hardware on the same SCHEMATIC page that holds the MAIN MC6809E:
      - MC6809E main CPU (drawn as "6809E" — pin-compatible footprint)
        visible pins: HALT, NMI, IRQ, FIRQ, RESET, BS, BA, R/W, E, Q,
                      AVMA, BUSY, LIC, TSC, A0..A15, D0..D7
      - 27512 main program EPROM (64 KB) at designator C19
        /CE driven by 007552 PAL pin 12 (output /RBN)
      - 007552 address-decoder PAL at C15
        visible output pin names: /RBN, /GATE1, /GATE2, /CWORK, /DMP,
                                   /CORAM, /G2AB11, /SEL
        Pin labels confirmed by reading the schematic plus jedutil decode of
        the PAL JEDEC dump (cores/ddribble/doc/Konami_007552_equations.txt).
      - Two 005885 graphics chips (designators E16 + H16) also on this page
      - LS245 bus transceivers, LS157 address muxes
      - 3.58 MHz oscillator can near LS74 H9 (sound xtal, shared with YM2203)

    Address decoder: from the 007552 PAL equations (the schematic-side
    authority). See `cores/ddribble/doc/Konami_007552_equations.txt`.

    MAME ref (pinned commit 347fd2c) for things NOT visible on our sheets:
      - konami/ddribble.cpp:534     CPU clock = 18.432 MHz / 12 = 1.536 MHz
                                     (18.432 MHz osc-can is SCHEMATIC-confirmed
                                      on page 0 r0c1 → LS244 G14 → CK18 net;
                                      /12 divider chain not yet traced)
      - konami/ddribble.cpp:324     FIRQ-on-V-blank behaviour (HOLD_LINE)
      - konami/ddribble.cpp:331-334 bank-switch latch (3-bit, at 0x8000 W)
                                     — exact latch chip not yet located on schematic;
                                       MAY be the downstream consumer of 007552's
                                       /SEL strobe (pin 19, ungated by NEQ)
*/

module jtddribble_main(
    input               rst,
    input               clk,
    input               cen,           // 1.5 MHz CPU clock-enable (from mem.yaml cpu_cen)
    output              cpu_cen,       // CPU Q-phase strobe — for downstream registers

    // CPU bus (exposed so jtddribble_video etc. can decode sub-regions)
    output      [15:0]  A,
    output              cpu_rnw,
    output      [ 7:0]  cpu_dout,

    // Per-region chip-selects (active high; [brackets] = 007552 PAL pin)
    output              pal_cs,        // [/CORAM] palette
    output              shared_cs,     // [/CWORK] shared with SUB
    output              k5885_1_cs,    // [/GATE1] 005885 #1 (regs + VRAM/sprite window)
    output              k5885_2_cs,    // [/GATE2] 005885 #2

    // Per-region read-back data — back into CPU
    input       [ 7:0]  pal_dout,
    input       [ 7:0]  shared_dout,
    input       [ 7:0]  k5885_1_dout,  // 005885 #1 returns SRAM/register data when k5885_1_cs && RnW
    input       [ 7:0]  k5885_2_dout,  // 005885 #2 same

    // Bank-switch register — 3 bits latched on CPU write to 0x8000.
    // MAME ddribble.cpp:331-334 says `data & 0x07` (so 3 bits used).
    // On the real PCB this register's outputs are labelled R16, R17, R17N
    // and they gate the MASK1M chip-enables for the gfx ROM banking.
    // We expose them here so game.v can route them into the gfx2 (and
    // potentially gfx1) SDRAM address high bits.
    output      [ 2:0]  bank_out,

    // Interrupt inputs — all three come from the 005885 chip 1 (E16, page 0).
    //
    // SCHEMATIC FINDING (2026-06-01): the chip's pin labels are MISLEADING.
    // The wiring on the real PCB is:
    //    chip pin NFIR  →  CPU IRQ pin
    //    chip pin NIRQ  →  CPU FIRQ pin    ← swapped from what the name suggests
    //    chip pin NNMI  →  CPU NMI pin
    // Whoever named the chip pins chose names that match the chip's INTERNAL
    // logic semantics (e.g. once-per-2-frames pin was called NFIR), while the
    // PCB designer routed those signals to the CPU pin that best matches the
    // actual rate (once-per-2-frames goes to IRQ, which is the slower-handler
    // interrupt; once-per-frame goes to FIRQ for fast service).
    //
    // game.v wires this correctly via the port names below: cpu_firqn receives
    // chip 1 NIRQ, cpu_irqn receives chip 1 NFIR.
    //
    // cpu_firqn is then AND'd (active-low) with a direct LVBL→jtframe_ff
    // shortcut below, because boot code zeroes mmr[4] (gating the chip's
    // own outputs idle) and we need V-blank FIRQ to keep firing regardless.
    input               cpu_irqn,      // → IRQ pin   (game.v wires chip 1 NFIR here)
    input               cpu_nmin,      // → NMI pin   (chip 1 NNMI)
    input               cpu_firqn,     // → FIRQ pin  (chip 1 NIRQ — schematic-faithful, no LVBL fallback)

    // ROM bus to SDRAM — 27512 EPROM (64 KB); rom_cs = 007552 PAL /RBN (pin 12)
    output      [15:0]  rom_addr,
    output              rom_cs,
    input       [ 7:0]  rom_data,
    input               rom_ok
);

`ifndef NOMAIN
// ---------------------------------------------------------------------------
// Internal signals
// ---------------------------------------------------------------------------
wire [15:0] addr;        // CPU A0..A15 bus (visible on SCHEMATIC page 1 main CPU pins)
wire        RnW, VMA;    // R/!W pin (visible on schematic), VMA = Valid-Memory-Address
reg  [ 7:0] cpu_din;     // data fed back to CPU (multiplexed from peripherals)
reg  [ 2:0] bank;        // 3-bit bank-switch latch
                         // (see MAME ddribble.cpp:331-334 for the 3-bit & 0x07 width;
                         //  exact PCB latch chip not yet located)
wire        bank_cs;     // 1-cycle pulse when CPU writes to 0x8000

// Expose internals as module outputs
assign A        = addr;
assign cpu_rnw  = RnW;
assign bank_out = bank;     // 3-bit bank-switch register → gfx ROM high bits in game.v

// ROM address composition — physical chip is one 27512 (64 KB) on SCHEMATIC page 1.
// The 6809 only addresses 32 KB of ROM at a time (0x8000-0xFFFF) but the 27512
// holds 64 KB, so a bank latch picks the upper 16 KB window:
//   CPU 0x8000-0x9FFF  → banked window: rom_addr = { bank[2:0], addr[12:0] }
//   CPU 0xA000-0xFFFF  → fixed:         rom_addr = addr  (ROM offsets 0xA000..0xFFFF)
// Outside ROM (0x0000-0x7FFF) rom_addr can be anything — rom_cs will be 0 anyway.
assign rom_addr = (addr[15:13] == 3'b100)   // 0x8000-0x9FFF window?
                ? { bank, addr[12:0] }       // banked
                : addr;                      // fixed (or don't-care)

// ---------------------------------------------------------------------------
// Address decoder — combinational chip-select generation
// ---------------------------------------------------------------------------
// HARDWARE: the real PCB decodes addresses in 2 stages on the main CPU page:
//   1. 007552 PAL at C15 produces coarse strobes (/RBN, /GATE1, /GATE2,
//      /CWORK, /DMP, /CORAM, /G2AB11, /SEL).
//      ★ AUTHORITATIVE source: cores/ddribble/doc/Konami_007552_equations.txt
//        (decoded by jedutil from the JEDEC fuse dump on 2026-06-01).
//   2. Downstream LS-series chips (LS245 transceivers, LS157 muxes, plus
//      the 005885 chips' internal register decoders) take those coarse
//      strobes and refine them to specific addresses.
//
// PAL OUTPUTS (active-low) → HDL CHIP-SELECT MAPPING:
// ┌─────────┬───────────────────────────────────┬─────────────────────────────┐
// │ /pin    │ Equation (PAL)                    │ HDL signal — address range  │
// ├─────────┼───────────────────────────────────┼─────────────────────────────┤
// │ /o12 /RBN   = NEQ & A15                    │ rom_cs     0x8000-0xFFFF    │
// │ /o13 /GATE1 = NEQ & /A15&/A14&A13          │                             │
// │              | NEQ & /A15&/A14&/A13&       │                             │
// │                       /A12&/A11            │ k5885_1_cs 0x0000-0x07FF    │
// │                                            │             + 0x2000-0x3FFF │
// │ /o14 /GATE2 = NEQ & /A15& A14&A13          │                             │
// │              | NEQ & /A15&/A14&/A13&       │                             │
// │                       /A12& A11            │ k5885_2_cs 0x0800-0x0FFF    │
// │                                            │             + 0x6000-0x7FFF │
// │ /o15 /CWORK = NEQ & /A15& A14&/A13         │ shared_cs  0x4000-0x5FFF    │
// │ /o16 /DMP   = NEQ & /A15&/A14&/A13&        │                             │
// │                      A12&/A11              │ (unused — 0x1000-0x17FF;    │
// │                                            │  CPU never accesses this)   │
// │ /o17 /CORAM = NEQ & /A15&/A14&/A13&        │                             │
// │                      A12& A11              │ pal_cs     0x1800-0x1FFF    │
// │                                            │ (128 B BRAM; window mirrors │
// │                                            │  via pal_addr=main_A[6:0])  │
// │ /o18 /G2AB11= NEQ & /A15&/A14&/A13&        │ Forces chip 2 A11=0 in      │
// │                      /A12& A11   |  /A11   │ 0x0800-0x0FFF window —      │
// │                                            │ implemented in game.v as    │
// │                                            │ k5885_2_A11_masked          │
// │ /o19 /SEL   = A15 & /A14 & /A13            │ bank_cs    0x8000-0x9FFF    │
// │              (NOT NEQ-gated!)              │ (write-only — bank latch)   │
// └─────────┴───────────────────────────────────┴─────────────────────────────┘
//
// NOTE: each k5885_*_cs window spans the FULL 007552 GATE1/GATE2 range, not
// just the base register bytes — the 005885 also has scroll/strip registers
// at chip addr 0x20-0x5F (zure_cs in the gfx wrapper), written via main
// 0x0020-0x005F (chip 1) and 0x0820-0x085F (chip 2). The PAL equations decode
// the whole window; narrowing it would silently drop those writes.
//
// Each select is the literal PAL product-term on A15..A11; the within-window low
// bits are don't-cares (partial decode → mirrors, as on the PCB). Terms are
// mutually exclusive, so the assignments are flat (no priority ladder).
// /o16 /DMP (0x1000-0x17FF) is unused by the CPU → no select. /o18 /G2AB11 is an
// address-modify (chip-2 A11 mask), applied in game.v, not a select here.
wire a15=addr[15], a14=addr[14], a13=addr[13], a12=addr[12], a11=addr[11];

assign rom_cs     = VMA &  a15;                                                // /RBN   0x8000-0xFFFF
assign k5885_1_cs = VMA & ~a15 & ~a14 & ( a13 | (~a13 & ~a12 & ~a11) );        // /GATE1 0x0000-07FF + 0x2000-3FFF
assign k5885_2_cs = VMA & ~a15 & ( (a14 & a13) | (~a14 & ~a13 & ~a12 & a11) ); // /GATE2 0x0800-0FFF + 0x6000-7FFF
assign shared_cs  = VMA & ~a15 &  a14 & ~a13;                                  // /CWORK 0x4000-0x5FFF
assign pal_cs     = VMA & ~a15 & ~a14 & ~a13 & a12 & a11;                      // /CORAM 0x1800-0x1FFF
// /SEL (pin 19) is NOT NEQ-gated; we latch the bank on the write side only.
assign bank_cs    = VMA & a15 & ~a14 & ~a13 & ~RnW;                            // /SEL   0x8000-0x9FFF (write)

// ---------------------------------------------------------------------------
// Data multiplexer — pick which peripheral feeds the CPU on a read cycle
// ---------------------------------------------------------------------------
// HARDWARE: on the PCB, the bus mux is done by LS245 transceivers (visible
// on the schematic around the main CPU and 007552 PAL at C15) plus LS157
// address muxes that arbitrate between CPU side and CRT side of the shared
// video RAMs.
// The 8'hff default below mimics the open-bus behaviour of a real arcade PCB
// (TTL bus pull-ups + DRAM precharge sit around VCC when nothing drives).
always @(*) begin
    cpu_din = 8'hff;
    if      (rom_cs)     cpu_din = rom_data;
    else if (pal_cs)     cpu_din = pal_dout;
    else if (shared_cs)  cpu_din = shared_dout;
    else if (k5885_1_cs) cpu_din = k5885_1_dout;    // 005885 #1 returns data from its private 6264SL
    else if (k5885_2_cs) cpu_din = k5885_2_dout;    // 005885 #2 same
end

// ---------------------------------------------------------------------------
// Bank-switch register (3 bits)
// ---------------------------------------------------------------------------
// HARDWARE: the exact bank-latch chip is not yet located on the schematic.
// 007552 PAL exposes a '/SEL' strobe pin (pin 19, 0x8000-0x9FFF, NOT NEQ-gated)
// that is the most likely
// enable candidate — confirm by tracing 'SET' to the latch's clock input,
// or dump the PAL to see the truth table.
// MAME ref: konami/ddribble.cpp:331-334
//   void bankswitch_w(uint8_t data) { m_mainbank->set_entry(data & 0x07); }
// → 3-bit bank field, latched on write to 0x8000.
always @(posedge clk, posedge rst) begin
    if (rst)
        bank <= 3'd0;
    else if (cen && bank_cs)
        bank <= cpu_dout[2:0];
end

// ---------------------------------------------------------------------------
// FIRQ — schematic-faithful: directly from chip 1 NIRQ output (= cpu_firqn
// input per swap), via the 1 kΩ pull-up shared FIRQ bus on the schematic.
// ---------------------------------------------------------------------------
// MC6809E CPU core
// ---------------------------------------------------------------------------
// HARDWARE: the physical chip is the MC6809E (drawn as "6809E") visible on
// SCHEMATIC page front top-left.
// pins HALT, NMI, IRQ, FIRQ, RESET, BS, BA, R/W, E, Q, AVMA, BUSY, LIC, TSC,
// A0..A15, D0..D7 all visible on the schematic.

jtframe_sys6809 #(.RAM_AW(0)) u_cpu(
    .rstn       ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen       ),         // 1.5 MHz tick (24 MHz / 16, from mem.yaml)
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
`else
// Scene replay (NOMAIN): stub all outputs; cpu_rnw held high so the chip/
// palette write-enables downstream never assert.
assign cpu_cen=0, rom_addr=0, rom_cs=0, A=0, cpu_rnw=1'b1, cpu_dout=0,
       pal_cs=0, shared_cs=0, k5885_1_cs=0, k5885_2_cs=0, bank_out=0;
`endif

endmodule