/*  jtddrbl_sound.v — sound CPU (MC6809E) for Double Dribble (Konami GX690)
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
      - 3x 4066 at D5 — each switches a 0.15uF low-pass cap (C20/C21/C22) onto one
        SSG channel (SSG-A/B/C), gated by YM2203 IOA[2:0]. Modeled as rc_en in mem.yaml.

    YM2203 + VLM5030 both run on the 3.58 MHz xtal — SCHEMATIC page 1.
    MAME ref (pinned 347fd2c) for things not directly readable from the sheets:
      - konami/ddribble.cpp:413-419  sound CPU memory map (exact ranges)
*/

module jtddrbl_sound(
    input               rst,
    input               clk,
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
    output  reg [16:0]  vlm_addr,
    input       [ 7:0]  vlm_data,
    input               vlm_ok,

    // Audio outputs (to mem.yaml mixer)
    output signed [15:0] fm_snd,    // YM2203 FM (matches mem.yaml channel 'fm')
    // 3 SSG channels, each with its own 4066-switched 0.15uF low-pass (gated by IOA[2:0])
    output        [ 7:0] psga, psgb, psgc,
    output               psga_rcen, psgb_rcen, psgc_rcen,
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
// Block decode = the LS138 itself: enable on A15=0 + bus phase, select on
// A[14:12]. The peripheral's own low-bit decode handles within-block addresses
// (e.g. YM2203 A0 = register/data), so each block mirrors as on the PCB.
// VMA is the jtframe_sys6809 equivalent of the NEQ bus-phase gate.
wire       en138   = VMA & ~addr[15];    // LS138 enabled (/G2A=A15 low, /G2B=NEQ)
wire [2:0] ls138_y = addr[14:12];        // pins A,B,C
always @(*) begin
    rom_cs     = VMA & addr[15];              // 0x8000-0xFFFF (sound ROM, outside the LS138)
    shared_cs  = en138 & (ls138_y==3'd0);     // Y0 0x0000-0x0FFF (2K SRAM mirrors in block)
    ym_cs      = en138 & (ls138_y==3'd1);     // Y1 0x1000-0x1FFF (YM2203, A0=reg/data)
    vlm_dlatch = en138 & (ls138_y==3'd3);     // Y3 0x3000-0x3FFF (VLM data latch)
    irqen_cs   = en138 & (ls138_y==3'd6);     // Y6 0x6000-0x6FFF (sound-IRQ ack)
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
wire       snd_irq, hs_tick;
wire       irq_ck = &snd_lcnt[7:4];          // bits 7..4 all 1 -> count in 0xF0..0xFF

// LS393 scanline counter: +1 per H-sync rising edge, cleared each frame by V-sync
jtframe_edge_pulse u_hs_tick(
    .rst   ( rst     ),
    .clk   ( clk     ),
    .cen   ( 1'b1    ),
    .sigin ( HS      ),
    .pulse ( hs_tick )
);
always @(posedge clk, posedge rst) begin
    if      (rst)     snd_lcnt <= 8'd0;
    else if (VS)      snd_lcnt <= 8'd0;          // ~NVSYNC clears the LS393
    else if (hs_tick) snd_lcnt <= snd_lcnt + 8'd1;
end

// LS74 IRQ latch: set when the count reaches 0xF0, cleared by the IRQEN (0x6000) write
jtframe_edge #(.QSET(1), .ATRST(0)) u_snd_irq(
    .rst    ( rst      ),
    .clk    ( clk      ),
    .edgeof ( irq_ck   ),
    .clr    ( irqen_cs ),
    .q      ( snd_irq  )
);

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

wire [7:0] ym_dout;
wire [7:0] ym_iob_in;
wire [7:0] ym_ioa_out;
wire       ym_irq_n;

assign ym_iob_in = { 7'h00, vlm_bsy };          // bit 0 = VLM BSY; rest unused

jt03 u_ym2203(
    .rst        ( rst       ),
    .clk        ( clk       ),                 // MUST match ym_cen's domain (gen'd on clk24).
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
    .psg_snd    (            ),     // unused — the 3 SSG channels are taken separately
    .psg_A      ( psga       ),     // CHA (pin 20) → R18 1k → mix; per-channel 4066 0.15uF switch
    .psg_B      ( psgb       ),     // CHB (pin 19) → R24
    .psg_C      ( psgc       ),     // CHC (pin 18) → R25
    .snd        (            ),     // unused — we use fm_snd and the 3 SSG taps
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

// Latch CPU data on writes to 0x3000 (VDATA strobe)
reg [7:0] vlm_data_latch;
always @(posedge clk, posedge rst) begin
    if (rst)
        vlm_data_latch <= 8'h00;
    else if (vlm_dlatch && !cpu_rnw)
        vlm_data_latch <= cpu_dout;
end

// VLM5030 control signals (routed via YM2203 IOA)
// SCHEMATIC: VLM5030 RST/ST/VCU are ACTIVE-HIGH (pins 40/31/32, labelled with NO "/"),
// wired straight from YM2203 IOA[6:4]. ST (pin 31) ← IOA5 confirmed by the user's trace.
wire        vlm_rst = ym_ioa_out[6];   // YM2203 IOA[6] → VLM RST (pin 40, active-HIGH)
wire        vlm_st  = ym_ioa_out[5];   // YM2203 IOA[5] → VLM ST  (pin 31, active-HIGH)
wire        vlm_vcu = ym_ioa_out[4];   // YM2203 IOA[4] → VLM VCU (pin 32, active-HIGH)
wire        vlm_bank  = ym_ioa_out[3];   // YM2203 IOA[3] → voice-ROM A16 (bank)

// SSG filter switches — IOA[2:0] drive the 3x 4066 (D5).
assign {psga_rcen, psgb_rcen, psgc_rcen} = ym_ioa_out[2:0];

// Bank latch bit forms MSB of voice-ROM address
wire        vlm_bsy;
wire        vlm_me_n, vlm_mte;
wire [15:0] vlm_internal_addr;


always @(posedge clk) vlm_addr <= { vlm_bank, vlm_internal_addr };

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
always @(posedge clk) begin
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

vlm5030_gl u_vlm(
    .i_clk     ( clk             ),       // 24 MHz (was clk/48 MHz — timing + cen alignment)
    .i_oscen   ( vlm_ceng        ),       // 3.58 MHz tick, held until voice-ROM byte ready
    .i_rst     ( vlm_i_rst       ),       // model is active-HIGH reset
    .i_start   ( vlm_i_start     ),       // active-HIGH ST (IOA5, schematic pin 31)
    .i_vcu     ( vlm_i_vcu       ),       // active-HIGH VCU (IOA4, schematic pin 32)
    .i_vref    ( 1'b1            ),       // normal operation
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
    .o_audio   ( vlm_snd         )
);


always @(*) begin
    cpu_din = 8'hff;
    if      (rom_cs)     cpu_din = rom_data;
    else if (shared_cs)  cpu_din = shared_dout;
    else if (ym_cs)      cpu_din = ym_dout;     // ← NEW: YM2203 register readback
    // vlm_cs is write-only
end

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