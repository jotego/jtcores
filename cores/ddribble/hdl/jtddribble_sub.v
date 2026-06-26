/*  jtddribble_sub.v — SUB CPU (MC6809E) for Double Dribble (Konami GX690)
    GPL3 — see jtcores LICENSE

    Hardware on schematic page 1 (sub CPU + sound CPU + I/O):
      - MC6809E at designator A12 (top-left area of page 1), full 6809E pinout
        visible pins: HALT, NMI, IRQ, FIRQ, RESET, BS, BA, R/W,
                      CLKE (pin 34), CLKQ (pin 35), AVMA, BUSY, TSC,
                      A0..A15, D0..D7
      - Konami 007553 PAL at C11 — confirmed sub-side address decoder.
        JEDEC + decoded equations + pin-label mapping live in:
          cores/ddribble/doc/Konami_007553_equations.txt
      - LS245 J9  bus transceiver between sub-CPU data bus and shared SRAM
      - LS157 C14 address mux (CPU-side vs main-side select for shared SRAM)
      - LS244 G14 buffer (same chip that buffers CK18 and SCLK — different gates)
      - LS04  H8 inverter, LS74 D15 flip-flop, glue
      - 32 KB program EPROM (27256) somewhere near A19 — TBD which designator
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

    input  [`JTFRAME_BUTTONS+3:0] joystick1, joystick2,
    input       [ 3:0]  cab_1p,
    input       [ 3:0]  coin,
    input               service,
    input       [31:0]  dipsw,

    // Output strobes / registers
    output reg  [ 1:0]  coin_counter,  // 0x3400 W  — latched in this module

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
reg         coin_cs;
reg         dsw1_cs, dsw2_cs, dsw3_cs;
reg         p1_cs, p2_cs, sys_cs;

// I/O-port assembly: raw JTFRAME controls -> Konami port bytes (read mux below)
wire [7:0] p1_input = { 1'b1,
                        joystick1[5], joystick1[6], joystick1[4],   // B2, B3, B1
                        joystick1[0], joystick1[1],                 // DOWN, UP
                        joystick1[2], joystick1[3] };               // RIGHT, LEFT
wire [7:0] p2_input = { 1'b1,
                        joystick2[5], joystick2[6], joystick2[4],
                        joystick2[0], joystick2[1],
                        joystick2[2], joystick2[3] };
// SYSTEM: b0=COIN1 b1=COIN2 b2=SERVICE b3=START1 b4=START2
wire [7:0] system_input = { 3'b111, cab_1p[1], cab_1p[0], service, coin[1], coin[0] };
wire [7:0] dsw1 = dipsw[ 7: 0];
wire [7:0] dsw2 = dipsw[15: 8];
wire [7:0] dsw3 = dipsw[23:16];

assign A        = addr;
assign cpu_rnw  = RnW;
assign rom_addr = addr[14:0];          // 32 KB ROM, MSB always 1 in CPU view

wire a15=addr[15], a14=addr[14], a13=addr[13], a12=addr[12], a11=addr[11], a10=addr[10];

// /o12 /ROM fires 0x4000-0xFFFF; the 27512 /CE is narrowed by a downstream A15 gate
wire pal_rom = VMA & (a15 | (~a15 & a14));
wire ioin_cs = VMA & ~a15 & ~a14 & a13 & ~a12 & a11 & ~a10;       // /o18 0x2800-0x2BFF

always @(*) begin
    rom_cs       = pal_rom & a15;                                // /ROM  → 0x8000-0xFFFF
    shared_ms_cs = VMA & ~a15 & ~a14 & ~a13;                      // /CRAM 0x0000-0x1FFF
    shared_sa_cs = VMA & ~a15 & ~a14 &  a13 & ~a12 & ~a11;        // /SRAM 0x2000-0x27FF
    dsw2_cs      = VMA & ~a15 & ~a14 &  a13 & ~a12 &  a11 &  a10;  // /DIP2 0x2C00-0x2FFF
    dsw3_cs      = VMA & ~a15 & ~a14 &  a13 &  a12 & ~a11 & ~a10;  // /DIP3 0x3000-0x33FF
    coin_cs      = VMA & ~a15 & ~a14 &  a13 &  a12 & ~a11 &  a10 & ~RnW; // /SET 0x3400-0x37FF (write)
    dsw1_cs      = ioin_cs & (addr[1:0]==2'b00);                 // /IOIN + A[1:0]=00
    p1_cs        = ioin_cs & (addr[1:0]==2'b01);                 // /IOIN + A[1:0]=01
    p2_cs        = ioin_cs & (addr[1:0]==2'b10);                 // /IOIN + A[1:0]=10
    sys_cs       = ioin_cs & (addr[1:0]==2'b11);                 // /IOIN + A[1:0]=11
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