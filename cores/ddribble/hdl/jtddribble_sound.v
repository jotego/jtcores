/*  jtddribble_sound.v — sound CPU (MC6809E) for Double Dribble (Konami GX690)
    GPL3 — see jtcores LICENSE

    Hardware on SCHEMATIC page 1 top-right (tile_p1_topR.png):
      - MC6809E sound CPU
      - 27256 sound program EPROM (32 KB) — adjacent to the CPU
      - 2128SL sound work RAM (2 KB) — but MAME's map uses it as the
        SUB↔SOUND shared RAM (0x0000-0x07FF), so we treat it as shared
      - YM2203C + YM3014 DAC (rendered on page 1 tile_p1_r0c2)
      - VLM5030 + MASK1M voice ROM at E7 (page 1 tile_p1_r0c2)
      - LS138 at A9 — sound I-O decoder
        visible output pins: IRQEN, VDATA, OPN, SWORK
          OPN  → YM2203 /CS  (mapped at 0x1000-0x1001)
          VDATA → VLM5030 data-latch /CS (mapped at 0x3000)
      - 3x 4066 at D5 — analog mute switches for SSG-A/B/C
        (driven by YM2203 IOA[2:0] per MAME ddribble.cpp:373-379)

    YM2203 + VLM5030 both run on the 3.58 MHz xtal — SCHEMATIC page 1.
    MAME ref (pinned 347fd2c) for things not directly readable from the sheets:
      - konami/ddribble.cpp:413-419  sound CPU memory map (exact ranges)
      - konami/ddribble.cpp:540      MC6809E sound CPU @ 18.432 MHz / 12
      - konami/ddribble.cpp:355-381  vlm5030_ctrl_w — bits 7..0 of YM2203 IOA
      - NO sound IRQ wired in MAME — sound CPU is polling-style on shared RAM
*/

module jtddribble_sound(
    input               rst,
    input               clk,
    input               clk24,         // 24 MHz — clocks the VLM5030 gate-level model.
                                       // Its internal clk2 logic is too slow for 48 MHz,
                                       // and its enable (vlm_cen) is already a clk24-domain
                                       // cen (mem.yaml). Matches the contra/ajax convention.
    input               cen,           // 1.5 MHz CPU clock-enable
    input               ym_cen,        // 3.58 MHz (from mem.yaml — SCLK source)
    input               vlm_cen,       // 3.58 MHz (same — SCLK fans to both)
    // Video sync — feeds the schematic sound-IRQ scanline counter (LS393 A16):
    // LS393 clock = NSYNC (H-sync), cleared each frame by NVSYNC (V-sync).
    input               HS,            // H-sync  (one count per scanline)
    input               VS,            // V-sync  (resets the scanline counter)
    output              cpu_cen,

    // ROM bus — 27256 = 32 KB (no banking)
    output      [14:0]  rom_addr,
    output reg          rom_cs,
    input       [ 7:0]  rom_data,
    input               rom_ok,

    // CPU bus (exposed)
    output      [15:0]  A,
    output              cpu_rnw,
    output      [ 7:0]  cpu_dout,

    // Shared RAM with SUB + YM2203/VLM5030 chip-selects (per LS138 A9 decode)
    output reg          shared_cs,
    output reg          ym_cs,         // 0x1000-0x1001  [LS138 A9 Y1 = OPN]
    output              vlm_cs,        // VLM voice-ROM SDRAM read request = ~/ME
                                       // (NOT the 0x3000 write — that is vlm_dlatch)
    input       [ 7:0]  shared_dout,

    // VLM5030 voice ROM bus (SDRAM region 'vlm' from mem.yaml, 128 KB)
    output      [16:0]  vlm_addr,
    input       [ 7:0]  vlm_data,
    input               vlm_ok,

    // Audio outputs (to mem.yaml mixer)
    output signed [15:0] fm_snd,    // YM2203 FM (matches mem.yaml channel 'fm')
    output        [ 9:0] psg_snd,   // YM2203 PSG/SSG (matches channel 'psg')
    output        [ 9:0] vlm_snd        // VLM5030 speech output (10-bit unsigned, matches auto-gen 'vlm' wire width)
);

// ---------------------------------------------------------------------------
// Internal signals
// ---------------------------------------------------------------------------
wire [15:0] addr;
wire        RnW, VMA;
reg  [ 7:0] cpu_din;
reg         irqen_cs;       // LS138 A9 Y6 (0x6000) — sound-IRQ acknowledge
reg         vlm_dlatch;     // 0x3000 write strobe — latches the phrase into the VLM

assign A        = addr;
assign cpu_rnw  = RnW;
assign rom_addr = addr[14:0];   // 15 bits for 32 KB ROM (MSB always 1 in CPU view)

// ---------------------------------------------------------------------------
// Address decoder
// ---------------------------------------------------------------------------
// HARDWARE: SCHEMATIC-traced (page 1, LS138 at A9 — sound I-O decoder).
// Confirmed wiring of LS138 A9:
//   Pin 1 A   = CPU A12 (CPU pin 20)     Pin 4 /G2A = CPU A15 (pin 23) — A15=0 to enable
//   Pin 2 B   = CPU A13 (CPU pin 21)     Pin 5 /G2B = NEQ (~(E|Q) — bus-phase gate)
//   Pin 3 C   = CPU A14 (CPU pin 22)     Pin 6  G1  = +5V             (always)
// Output map (active low when LS138 enabled, i.e. CPU addr in 0x0000-0x7FFF):
//   Y0 (0x0000-0x0FFF)  SWORK   → shared RAM with SUB CPU (only lower 2 KB used)
//   Y1 (0x1000-0x1FFF)  OPN     → YM2203 /CS    [MAME ddribble.cpp:416 = 0x1000-0x1001]
//   Y3 (0x3000-0x3FFF)  VDATA   → VLM5030 data latch  [MAME ddribble.cpp:417 = 0x3000]
//   Y6 (0x6000-0x6FFF)  IRQEN   → sound-IRQ ACKNOWLEDGE. SCHEMATIC-traced 2026-06-17:
//        accessing 0x6000 clears the LS74 (A10) scanline-IRQ latch. The IRQ source is
//        a LS393 (A16) scanline counter (clk=NSYNC, cleared each frame by NVSYNC) whose
//        bits[7:4]-all-1 decode (count 0xF0) sets the LS74 once per frame; LS74 /Q drives
//        the 6809 IRQ. NMI/FIRQ are pull-up only; YM2203 /IRQ (pin 25) is unconnected.
//   Y0=SWORK; Y2,Y4,Y5,Y7 unlabelled/unused on the schematic.
//
// In our HDL the *block-level* decode is 100% schematic-confirmed via this
// LS138. The fine address bits within each block (e.g. why YM2203 is at
// exactly 0x1000-0x1001 within Y1's 0x1000-0x1FFF block) come from MAME
// because the downstream sub-block decoders aren't fully visible on our tiles.
// VMA below is the jtframe_sys6809 equivalent of the NEQ bus-phase gate.
always @(*) begin
    rom_cs     = 0;
    shared_cs  = 0;
    ym_cs      = 0;
    vlm_dlatch = 0;
    irqen_cs   = 0;

    if (VMA) begin
        if      (addr >= 16'h8000)                          rom_cs     = 1;
        else if (addr <= 16'h07FF)                          shared_cs  = 1;  // 0x0000-0x07FF
        else if (addr[15:1] == 15'h0800)                    ym_cs      = 1;  // 0x1000-0x1001
        else if (addr == 16'h3000)                          vlm_dlatch = 1;  // 0x3000 W (VDATA)
        else if (addr[15:12] == 4'h6)                       irqen_cs  = 1;  // 0x6000 LS138 Y6 = IRQ ack
    end
end

// ---------------------------------------------------------------------------
// Sound IRQ — scanline-counted, SCHEMATIC-traced (page 1: LS393 A16 + LS74 A10)
// ---------------------------------------------------------------------------
// LS393 (A16) is a 1-per-scanline counter: 2A=NSYNC (H-sync) is the low nibble,
// 1A=2Q3 cascades into the high nibble (1Q0..1Q3 = count bits 4..7); both CLRs are
// driven by NAND(NVSYNC,+5)=~NVSYNC, so the count is cleared every frame at V-sync.
// The decode NOR(NAND(1Q3,1Q2),NAND(1Q1,1Q0)) = 1Q3·1Q2·1Q1·1Q0 = (count[7:4]==0xF)
// drives LS74 (A10) CK; with D=+5 the CK rising edge (count 0xF0=240) SETS the latch
// once per frame and /Q pulls the 6809 IRQ low. Writing IRQEN (0x6000) CLRs the latch.
reg  [7:0] snd_lcnt;
reg        hs_d, irq_ck_d, snd_irq;
wire       irq_ck = &snd_lcnt[7:4];          // bits 7..4 all 1 -> count in 0xF0..0xFF
always @(posedge clk, posedge rst) begin
    if (rst) begin
        snd_lcnt <= 8'd0; hs_d <= 1'b0; irq_ck_d <= 1'b0; snd_irq <= 1'b0;
    end else begin
        hs_d <= HS;
        if      (VS)          snd_lcnt <= 8'd0;              // ~NVSYNC clears the LS393
        else if (HS && !hs_d) snd_lcnt <= snd_lcnt + 8'd1;   // one count per H-sync line
        irq_ck_d <= irq_ck;
        if      (irqen_cs)            snd_irq <= 1'b0;        // IRQEN (0x6000) = acknowledge
        else if (irq_ck && !irq_ck_d) snd_irq <= 1'b1;        // CK rising = assert (line 240)
    end
end

/* verilator lint_off UNUSED */
wire cpu_irq_ack;   // sys6809 IRQ-acknowledge strobe — SIMULATION debug tap only
/* verilator lint_on UNUSED */


// ---------------------------------------------------------------------------
// YM2203 — Yamaha OPN sound chip (3-ch FM + 3-ch SSG)
// ---------------------------------------------------------------------------
// SCHEMATIC: YM2203 chip on page 1 r0c2, CLK pin → SCLK (3.58 MHz buffer).
//   /CS = OPN (LS138 A9 Y1 output, traced).
//   A0 = sub-block decode (low addr bit), R/W = CPU R/!W.
//   D7..D0 = sound-CPU data bus.
//   Outputs: SH1/SCLK/MO to YM3014 DAC, plus 3 SSG channels.
//   IOA[7:0] = VLM5030 control + 4066 filter switches (see vlm5030_ctrl below).
//   IOB[7]   = VLM5030 BSY readback.
// YM2203 runs on the 3.58 MHz xtal (SCHEMATIC page 1).
// MAME ref (chip-internal port routing, not on the sheets):
//   ddribble.cpp:566    port_b_read = vlm5030_busy_r
//   ddribble.cpp:567    port_a_write = vlm5030_ctrl_w

wire [7:0] ym_dout;
wire [7:0] ym_iob_in;
wire [7:0] ym_ioa_out;
wire       ym_irq_n;

// SCHEMATIC-CONFIRMED (user traced 2026-06-02): VLM5030 pin 6 (BSY) goes
// directly to YM2203 PB0 (port B, bit 0). Other PB pins are unused inputs
// on the real chip, default low.
//
// We previously had vlm_bsy at IOB[7] with 7'h7f filling — that broke
// the sound-CPU POST polling loop at 0x8A0C (LDA $1001; BITA #$01;
// BNE -7) which waits for IOB[0] to clear. The 7'h7f filler made bit 0
// always 1 → loop stuck forever → sound CPU never reached its ROM
// checksum → POST showed SOUND ROM A 6 BAD.
assign ym_iob_in = { 7'h00, vlm_bsy };          // bit 0 = VLM BSY; rest unused

jt03 #(.YM2203_LUMPED(1)) u_ym2203(
    .rst        ( rst       ),
    .clk        ( clk24     ),                 // MUST match ym_cen's domain (gen'd on clk24).
                                               // Clocking on clk48 made jt12_div count each
                                               // 1-clk24-wide cen pulse TWICE → FM ran 2× fast.
                                               // The VLM (also clk24) never had this bug.
    .cen        ( ym_cen    ),                 // real 3.58 MHz — on clk24, counted once/pulse
    .din        ( cpu_dout  ),
    .addr       ( A[0]      ),                  // 0 = address register, 1 = data
    .cs_n       ( ~ym_cs    ),
    .wr_n       ( cpu_rnw   ),
    .dout       ( ym_dout   ),
    .irq_n      ( ym_irq_n  ),                  // TODO: route to sound CPU IRQ via IRQEN latch (LS138 A9 Y2)
    .IOA_in     ( 8'h00     ),
    .IOA_out    ( ym_ioa_out),                  // → VLM ctrl + 4066 below
    .IOA_oe     (           ),                  // unused — port-A output enable not modelled
    .IOB_in     ( ym_iob_in ),
    .IOB_out    (           ),
    .IOB_oe     (           ),                  // unused
    .fm_snd     ( fm_snd     ),
    .psg_snd    ( psg_snd    ),
    .psg_A      (            ),     // unused — per-channel PSG taps not needed
    .psg_B      (            ),
    .psg_C      (            ),
    .snd        (            ),     // unused — we use fm_snd and psg_snd
    .snd_sample (            ),     // jt03 port name is 'snd_sample', not 'sample'
    .debug_view (            )      // unused
);

// ---------------------------------------------------------------------------
// VLM5030 — Sanyo speech synthesizer
// ---------------------------------------------------------------------------
// SCHEMATIC: VLM5030 + MASK1M voice ROM at E7 (page 1 r0c2).
//   On the PCB, the CPU data bus is latched onto VLM's i_d by a flip-flop
//   triggered by VDATA strobe (LS138 A9 Y3). We model that latch here as
//   the 'vlm_data_latch' register.
// VLM5030 runs on the 3.58 MHz xtal (SCHEMATIC page 1), gated by vlm_cen.
// MAME ref:
//   ddribble.cpp:417    VLM5030 data at 0x3000 W
//   ddribble.cpp:355    bit 7 = "vlm data bus OE"  (the latch's OE — we don't
//                       gate it because the latch's output is always valid in
//                       our HDL model; the OE just disconnects in real HW)

// Latch CPU data on writes to 0x3000 (VDATA strobe)
reg [7:0] vlm_data_latch;
always @(posedge clk, posedge rst) begin
    if (rst)
        vlm_data_latch <= 8'h00;
    else if (vlm_dlatch && !cpu_rnw)
        vlm_data_latch <= cpu_dout;
end

// VLM5030 control signals (routed via YM2203 IOA — see MAME ddribble.cpp:355-381)
// SCHEMATIC: VLM5030 RST/ST/VCU are ACTIVE-HIGH (pins 40/31/32, labelled with NO "/"),
// wired straight from YM2203 IOA[6:4]. ST (pin 31) ← IOA5 confirmed by the user's trace.
wire        vlm_rst = ym_ioa_out[6];   // YM2203 IOA[6] → VLM RST (pin 40, active-HIGH)
wire        vlm_st  = ym_ioa_out[5];   // YM2203 IOA[5] → VLM ST  (pin 31, active-HIGH)
wire        vlm_vcu = ym_ioa_out[4];   // YM2203 IOA[4] → VLM VCU (pin 32, active-HIGH)
wire        vlm_bank  = ym_ioa_out[3];   // YM2203 IOA[3] → voice-ROM A16 (bank)

// Bank latch bit forms MSB of voice-ROM address
wire        vlm_bsy;
wire        vlm_me_n, vlm_mte;
wire [15:0] vlm_internal_addr;
wire [ 9:0] vlm_audio_raw;
// --- Re-time the voice-ROM address from the VLM's 24 MHz domain to the 48 MHz SDRAM ---
// vlm_internal_addr is the VLM's voice-ROM address (its o_a output), produced
// COMBINATIONALLY by the chip's slow internal clk2 logic; vlm_bank is the A16 page
// bit. The voice ROM lives in SDRAM, whose controller runs on the 48 MHz clk — a
// faster clock domain than the VLM (clk24). Driving that combinational address
// straight across the boundary asks the VLM's ~37 ns path to settle within ONE
// 48 MHz period (20.8 ns); it can't, so the build failed timing on that hop
// (-13.6 ns, a clk24->clk48 setup violation).
// Latching the address into a clk24 register first makes the crossing a clean
// register-to-register transfer — the SDRAM only ever samples a stable, clock-
// aligned value. The one extra cycle of latency is harmless: vlm_ceng already
// stalls the VLM on vlm_ok until the SDRAM has served the byte. (Same approach as
// the sbaskt core.)
reg [16:0] vlm_addr_r;
always @(posedge clk24) vlm_addr_r <= { vlm_bank, vlm_internal_addr };  // capture o_a each clk24
assign vlm_addr = vlm_addr_r;                                            // stable address out to SDRAM

// VLM data pins are SHARED: the CPU command latch when loading a phrase, the voice
// ROM byte when the chip reads it (/ME asserted, o_me_l low). SCHEMATIC: the E7 MASK1M
// voice ROM hangs directly off the VLM's VD bus. Mux i_d on /ME, and gate the VLM clock
// on vlm_ok during a ROM read so the chip never samples before SDRAM serves the byte.
wire [7:0] vlm_din  = ~vlm_me_n ? vlm_data : vlm_data_latch;
wire       vlm_ceng = vlm_cen & (vlm_me_n | vlm_ok);

// SDRAM voice-ROM read request: the VLM asserts /ME (vlm_me_n low) when it wants a
// byte at o_a; that is what must drive the SDRAM 'vlm' read CS. (It was wired to the
// 0x3000 CPU-write strobe, so the ROM was never fetched during a speech -> the chip
// stalled on its first read, vlm_ok never came, no voice.)
assign vlm_cs = ~vlm_me_n;


// SIM-only forced-start harness: the attract driver never pulses /ST, so to test
// whether the VLM model reads the ROM at all in our integration we drive a clean
// reset-release -> real-phrase -> START edge ourselves.  -d VLM_FORCE_START
`ifdef VLM_FORCE_START
reg        vlmtst_rst = 1'b1, vlmtst_st = 1'b0;
reg [24:0] vlmtst_cnt = 25'd0;
always @(posedge clk24) begin
    vlmtst_cnt <= vlmtst_cnt + 25'd1;
    if (vlmtst_cnt==25'd2000000) vlmtst_rst <= 1'b0;   // release reset
    if (vlmtst_cnt==25'd3000000) vlmtst_st  <= 1'b1;   // START rising edge (held)
end
wire       vlm_i_rst   = vlmtst_rst;
wire       vlm_i_start = vlmtst_st;
wire       vlm_i_vcu   = 1'b0;
wire [7:0] vlm_i_d     = ~vlm_me_n ? vlm_data : 8'h03;  // ROM byte during /ME, else phrase 3
`else
// The model's i_rst/i_start/i_vcu are ACTIVE-HIGH and take the raw pin levels — the
// working sbaskt/yiear cores feed them un-inverted. The old `~` double-inverted them:
//   i_start was held HIGH (IOA5=0 → ~0=1) so the model never saw a clean ST rising
//     edge to latch the phrase and begin → BSY raised but synthesis never ran.
//   i_rst was RE-asserted right after the phrase load (~IOA6 went high at 0x00),
//     resetting the chip and discarding the just-loaded phrase.
wire       vlm_i_rst   = vlm_rst;
wire       vlm_i_start = vlm_st;
wire       vlm_i_vcu   = vlm_vcu;
wire [7:0] vlm_i_d     = vlm_din;
`endif

// Pass the raw 10-bit unsigned VLM audio straight through — JTFRAME's mixer
// handles unsigned-to-signed conversion via the channel's `unsigned: true`
// flag (which we'd add to mem.yaml if not auto-detected from module=vlm5030).
assign vlm_snd = vlm_audio_raw;

// The VLM5030 gate-level model runs in the clk24 domain (its internal clk2 logic
// won't close timing at 48 MHz; its vlm_cen is a clk24 cen). The CPU/ROM signals
// into it (vlm_din, vlm_ceng) are slow, stable-when-sampled levels — safe CDC.
vlm5030_gl u_vlm(
    .i_clk     ( clk24           ),       // 24 MHz (was clk/48 MHz — timing + cen alignment)
    .i_oscen   ( vlm_ceng        ),       // 3.58 MHz tick, held until voice-ROM byte ready
    .i_rst     ( vlm_i_rst       ),       // model is active-HIGH reset
    .i_start   ( vlm_i_start     ),       // active-HIGH ST (IOA5, schematic pin 31)
    .i_vcu     ( vlm_i_vcu       ),       // active-HIGH VCU (IOA4, schematic pin 32)
    .i_vref    ( 1'b1            ),       // normal operation
    // TST1 low = normal operation. The model gates its test address paths on
    // ntst1vref=(i_tst1 nand i_vref); with i_vref=1, tying TST1 high makes
    // ntst1vref=0 and can enable the test routing during start. Working sbaskt/
    // yiear VLM cores tie i_tst1=0. (was 1'b1 — a wrong "tie high" guess.)
    .i_tst1    ( 1'b0            ),       // test pin — tie LOW (normal op)
    .i_tst3    ( 1'b1            ),
    .i_d       ( vlm_i_d         ),       // command latch, or voice-ROM byte when /ME low
    .o_tst2    (                 ),
    .o_tst4    (                 ),
    .o_a       ( vlm_internal_addr ),
    .o_me_l    ( vlm_me_n        ),
    .o_mte     ( vlm_mte         ),
    .o_bsy     ( vlm_bsy         ),
    .o_dao     (                 ),       // 6-bit raw DAC — unused, we use o_audio
    .o_audio   ( vlm_audio_raw   )
);

// ---------------------------------------------------------------------------
// Data multiplexer update — now includes YM2203 readback
// ---------------------------------------------------------------------------
// (REPLACE the existing always block — add ym_cs case)
always @(*) begin
    cpu_din = 8'hff;
    if      (rom_cs)     cpu_din = rom_data;
    else if (shared_cs)  cpu_din = shared_dout;
    else if (ym_cs)      cpu_din = ym_dout;     // ← NEW: YM2203 register readback
    // vlm_cs is write-only
end

// ---------------------------------------------------------------------------
// MC6809E CPU core (unchanged from before)
// ---------------------------------------------------------------------------
jtframe_sys6809 #(.RAM_AW(0)) u_cpu(
    .rstn       ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .cpu_cen    ( cpu_cen   ),
    .nIRQ       ( ~snd_irq  ),   // LS74 A10 /Q — scanline IRQ (schematic-traced)
    .nFIRQ      ( 1'b1      ),   // pull-up only (R30) on the PCB
    .nNMI       ( 1'b1      ),   // pull-up only (R29) on the PCB
    .irq_ack    ( cpu_irq_ack ),
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