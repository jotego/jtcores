/*  jtddribble_colmix.v — colour mixer for Double Dribble (Konami GX690)
                          Konami 007327 palette LUT / RGB DAC
                          + LS157 H13/H14 layer-priority mux
                          + LS32 H12 / LS08 G11 PRI gate network
                          + LS32 OR-tree BLK gate
    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    GPL3 — see jtcores LICENSE

    HARDWARE WRAPPED IN THIS MODULE (SCHEMATIC page 0):
      - 007327 palette chip itself (designator I1)
      - LS157 H13 and H14 — 2:1 mux that picks between G1COL (chip 1, FG)
        and G2COL (chip 2, BG) based on PRI. Output is the 5-bit CB[4:0]
        color-code bus going into the 007327's color-code input.
        Per schematic (user-confirmed): input A = G2 (BG), input B = G1 (FG).
        LS157 truth: SEL=0 → A; SEL=1 → B. So PRI=0 → BG, PRI=1 → FG.
      - LS32 H12 + LS08 G11 — gate network that computes PRI from the
        FG color bits and BG bit-4 (full trace below).
      - LS32 OR-tree — BLK gate, OR of the post-mux COL[3:0].

    Why bundle them: on the real PCB these LS chips physically wrap the
    007327 to form the "color side" of the video pipeline. Encapsulating
    them here keeps jtddribble_video.v small and lets the module boundary
    match the chip-network boundary on the schematic.

    Placement: instantiated as u_colmix INSIDE jtddribble_video (beside the
    two 005885 chips that feed it). That is the jtcores house convention —
    jtcastle / jtaliens / jtbtiger / jt1942 / ... all put *_colmix in
    *_video.v (only taitob still keeps it in _game).

    RELATION TO jtcastle_colmix (the OTHER in-tree 007327 model)
    ----------------------------------------------------------------------
    Haunted Castle's jtcastle_colmix is ALSO "Equivalent to KONAMI 007327",
    so reusing it is tempting — but it shares only the palette-read KERNEL
    with this module (the pal_half byte-toggle -> 16-bit shift accumulator
    -> latch on pxl_cen, and the xBGR_555 word layout). Everything else here
    is Double-Dribble-specific, reverse-engineered from THIS PCB's schematic,
    so jtcastle's version can NOT be dropped in:
      - PRIORITY  castle uses a colour PROM (jtframe_prom + prio_addr lookup);
                  we use the hardwired schematic gate equation
                  pri = (|g1col[3:0]) & g2col[4]  (LS32 H12 + LS08 G11).
                  This board has no priority PROM.
      - LAYER MUX castle: prio ? gfx2 : gfx1.  Ours: LS157 H13/H14 selects
                  pri ? g1col(FG) : g2col(BG) (schematic-confirmed A/B order).
      - BLK       castle has none here; we add the LS32 OR-tree |col_mux[3:0]
                  + the blk_q pxl_cen re-alignment (the "thin text" fix; see
                  doc/fixes_journal.md).
      - PALETTE   castle AW=10 (1024 B); ours is the 128-byte `pal` BRAM (64
                  colours), whose CPU-write side is wired in game.v, not here.
      - RGB       castle 5:5:5; ours 4:4:4 (drop each field's LSB for the
                  JAMMA edge — the 007327's DAC width on this board).
      - SYNC      castle carries jtframe_blank + LHBL/LVBL; ours is PURE
                  colour — video sync is chip-owned by the 005885 upstream.

    007327 INPUT BUS (per direct schematic read 2026-06-02):
      Pin name   Wire from           Schematic note
      ----------------------------------------------------------------------
      CB6        GND                 always 0 — top palette half unused on
                                       the display side; CPU side can still
                                       write all 128 bytes
      CB5        PRI                 priority bit, becomes part of the
                                       palette index (selects FG vs BG
                                       palette half)
      CB4..CB0   LS157 H13/H14 out   muxed G1COL[4:0] vs G2COL[4:0]
      D7..D0     CPU bus             palette RAM write data (also re-read
                                       by CPU for sanity tests via CRTRD)
      CCS        /CORAM (007552 PAL pin 17) — chip select
      CWR        main 6809E R/W pin  — write strobe (active LOW for write)
      CRTRD      ~R/W via LS04 H8    — read strobe (active LOW for read);
                                       not modeled in HDL because the
                                       dual-port BRAM always serves data
      BLK        OR of post-mux COL[3:0] via LS32 gates (see below)

    007327 OUTPUT:
      RED[3:0], GREEN[3:0], BLUE[3:0] — drive JAMMA video edge directly.
      (Internal DAC; resistors not visible on the schematic — chip-internal.)

    PALETTE STORAGE — 64 colors × 16 bits = 128 bytes total.
      The chip stores 64 color words, each 16 bits wide. The CPU sees the
      same storage as 128 single bytes via its 8-bit data bus; consecutive
      byte addresses hold the high and low halves of a 16-bit color word.
      Byte order (empirically determined from the COLOR TEST page byte
      dump 2026-06-02 — see doc/fixes_journal.md): the LOWER CPU address
      holds the LOW byte of the 16-bit word, the HIGHER address holds the
      HIGH byte. So for the color at CPU address N, the word is
        word = (mem[N+1] << 8) | mem[N]
      The boot code apparently uses two single-byte STAs in low-then-high
      order rather than the 6809's STD (which would have stored big-endian).

      Word format: xBGR_555 — bit 15 unused, bits 14:10 = B[4:0], bits 9:5
      = G[4:0], bits 4:0 = R[4:0].

      JUSTIFICATION: the 007327 is an integrated chip — its internal SRAM
      layout and DAC are NOT visible on the schematic. The xBGR_555 layout
      and the byte-pair packing are the working assumption used by the
      existing `jtcastle_colmix.v` in jtcores for the same 007327 chip
      (Haunted Castle, comment "Equivalent to KONAMI 007327"). We verified
      the layout independently against the live PCB: dumping the palette
      bytes at $1800-$180F during the service-mode COLOR TEST page yields
      exactly the visible color sequence (white / yellow / cyan / green /
      magenta / red / blue) when decoded as xBGR_555 with low-byte-first
      storage. See doc/fixes_journal.md for the matching table.

    BRAM ADDRESSING (display side):
      pal_addr = { PRI, col_mux[4:0], pal_half } = 7 bits = 128 bytes.
        - PRI (= CB5 on real chip): selects FG palette (1) vs BG (0).
        - col_mux[4:0] (= CB4..CB0): post-LS157-mux color index.
        - pal_half: byte-half select. 0 = LOW byte of word (LOWER CPU
          addr); 1 = HIGH byte of word (HIGHER CPU addr).

      The chip reads BOTH bytes per pixel by toggling pal_half on each
      clock edge and shifting the bytes into a 16-bit accumulator; the
      assembled color word is latched on pxl_cen. This is the pattern
      that jtcastle_colmix.v uses for the same chip.

    SCHEMATIC TRACES FRONT page:
      PRI:
        LS32 H12 gate A:  pin1 = G1COL0 | G1COL1
                          pin2 = G1COL2 | G1COL3
                          pin3 = pin1 | pin2  = "G1COL[3:0] non-zero"
        LS08 G11 gate C:  pin8 = pin3 AND G2COL[4]  = PRI
        ⇒ PRI = (|G1COL[3:0]) & G2COL[4]

      BLK (placed AFTER the LS157 mux on the post-mux COL bus):
        gate B: COL[0] | COL[1]
        gate C: COL[2] | COL[3]
        gate D: pin6 | pin8        = BLK
        ⇒ BLK = | col_mux[3:0]
*/

module jtddribble_colmix(
    input               rst,
    input               clk,
    input               pxl_cen,

    // 5-bit color from each 005885 (lower 5 bits of the chip's 7-bit
    // pxl_out — only the 5 COL bits reach the LS157 muxes on the PCB).
    input      [ 4:0]   g1col,        // FG, from chip 1 (E16)
    input      [ 4:0]   g2col,        // BG, from chip 2 (H16)

    // Palette BRAM read port (mem.yaml `pal` region, 128 B, 8-bit wide).
    // CPU-write side is wired in game.v via pal_addr/pal_din/pal_we.
    output     [ 6:0]   pal_addr,
    input      [ 7:0]   pal_dout,

    // RGB to JAMMA — 4 bits per channel (5-bit xBGR_555 truncated to 4).
    output     [ 3:0]   red,
    output     [ 3:0]   green,
    output     [ 3:0]   blue
);

// --------------------------------------------------------------------
// PRI — schematic-traced (LS32 H12 + LS08 G11).
//   PRI = (|G1COL[3:0]) & G2COL[4]
// --------------------------------------------------------------------
wire pri = (|g1col[3:0]) & g2col[4];

// --------------------------------------------------------------------
// LS157 H13/H14 — layer mux. Per schematic:
//   input A = G2 (BG)    SEL=0 → output = A → BG
//   input B = G1 (FG)    SEL=1 → output = B → FG
// --------------------------------------------------------------------
wire [4:0] col_mux = pri ? g1col : g2col;

// --------------------------------------------------------------------
// BLK — schematic-traced LS32 OR-tree, AFTER the LS157 mux.
//   pri=1 → mux passes G1COL → BLK = |G1[3:0]
//   pri=0 → mux passes G2COL → BLK = |G2[3:0]
// Functionally equivalent to `|col_mux[3:0]` written per-branch for clarity.
// --------------------------------------------------------------------
wire blk = pri ? (|g1col[3:0]) : (|g2col[3:0]);

// blk is combinational from the CURRENT pixel's colour index, but col_in (below)
// is the palette word for the PREVIOUS pixel — it is latched on pxl_cen one pixel
// later. Gating col_in with the un-aligned blk blanks each lit pixel with the NEXT
// pixel's transparency, so every lit run lost its right column (the "thin text",
// ~38% of lit pixels — the chip's COL was already pixel-perfect). Register blk on
// pxl_cen so it lines up with col_in.
reg blk_q = 1'b0;
always @(posedge clk, posedge rst) begin
    if(rst)          blk_q <= 1'b0;
    else if(pxl_cen) blk_q <= blk;
end

// --------------------------------------------------------------------
// Byte-sequencing — read two consecutive palette bytes per pixel by
// toggling pal_half on each clock edge, accumulating into a 16-bit
// shift register, then latching the combined color word on pxl_cen.
// Same pattern as jtcastle_colmix.v (the in-tree reference HDL for the
// 007327 chip in Haunted Castle).
//
// Address bit assignment matches the chip's internal organization:
//   { PRI = CB5, col_mux[4:0] = CB4..CB0, pal_half = byte-select }
//
// pal_half polarity: 0 selects the LOW byte (lower CPU addr) of the
// 16-bit word, 1 selects the HIGH byte. We read LOW first on the edge
// right after pxl_cen, so the shift register accumulates {HIGH, LOW}
// in pxl_aux just in time for the next pxl_cen latch.
// --------------------------------------------------------------------
reg         pal_half;
reg  [15:0] pxl_aux;          // running shift accumulator
reg  [15:0] col_in;           // latched 16-bit color word

assign pal_addr = { pri, col_mux, pal_half };

always @(posedge clk, posedge rst) begin
    if (rst) begin
        pal_half <= 1'b0;
        pxl_aux  <= 16'h0000;
        col_in   <= 16'h0000;
    end else begin
        pxl_aux <= { pxl_aux[7:0], pal_dout };       // shift in current byte
        if (pxl_cen) begin
            col_in   <= pxl_aux;                      // latch full color word
            pal_half <= 1'b0;                         // realign: read LOW byte next
        end else begin
            pal_half <= ~pal_half;                    // alternate byte each clk
        end
    end
end

// --------------------------------------------------------------------
// xBGR_555 decode. Drop the LSB of each 5-bit field to fit the 4-bit
// JTFRAME RGB interface (LSB is the lowest-significance brightness bit).
// BLK gating zeroes the output for transparent pixels.
// --------------------------------------------------------------------
wire [4:0] r5 = col_in[ 4: 0];
wire [4:0] g5 = col_in[ 9: 5];
wire [4:0] b5 = col_in[14:10];

assign red   = blk_q ? r5[4:1] : 4'h0;
assign green = blk_q ? g5[4:1] : 4'h0;
assign blue  = blk_q ? b5[4:1] : 4'h0;

endmodule
