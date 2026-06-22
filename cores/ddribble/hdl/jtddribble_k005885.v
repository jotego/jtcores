//============================================================================
//
//  jtddribble_k005885.v — ground-up Konami 005885 for Double Dribble (GX690)
//
//  Faithful JTFRAME port of the MiSTer Iron Horse model
//  (doc/k005885_REFERENCE.sv, MIT © 2020,2022 Ace) — the authoritative
//  ground-up 005885 — adapted to JTFRAME conventions and to ddribble's
//  SDRAM gfx + single time-shared ROM bus. See doc/k005885_port.md for the
//  full design rationale (clock mapping, SDRAM-latency adaptation, the
//  one-bus time-share, RAM-primitive mapping, phase plan).
//
//  A full ground-up chip model (no separate wrapper): the port list carries the
//  SCHEMATIC-FAITHFUL pinout — every real pin name, number and contract traced
//  from the GX690 page-0 schematic (see doc/005885_implementation.md). It
//  replaced the contra-derived jtddribble_5885 path, whose direct-serializer
//  render had a pixel-cen phase bug (thin text); the tilemap here uses the
//  007121 line-buffer mechanism instead — see doc/005885_vs_007121_reuse.md.
//
//  Instantiated TWICE (E16=FG/gfx1, H16=BG/gfx2); each emits COL[4:0] into
//  jtddribble_colmix (the 007327 palette + LS157/LS32 priority network).
//
//----------------------------------------------------------------------------
//  Portions derived from the MIT-licensed k005885.sv by Ace. MIT notice:
//    Permission is hereby granted, free of charge, to any person obtaining a
//    copy of this software and associated documentation files (the
//    "Software"), to deal in the Software without restriction... The above
//    copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software. THE SOFTWARE IS
//    PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.
//  JTCORES integration is GPL-3 (see jtcores LICENSE).
//
//  Pin names below are the ACTUAL pin labels on the chip's die package as
//  drawn on the schematic; pin numbers in comments are the physical package
//  position. This is the contract for wiring the chip into the wider core.
//
//  Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
//============================================================================

module jtddribble_k005885 #(
    // Sprite-color PROM bypass selector (per MAME ddribble palette init):
    // chip 2 (H16) sprites use the 256-byte I15 lookup PROM (BYPASS_OPROM=0);
    // chip 1 (E16) maps pens 1:1 (BYPASS_OPROM=1). Set per-instance in game.v.
    parameter BYPASS_OPROM = 1,
    // Layer select: 0 = FG (chip 1, E16, gfx1) — 12-bit tile code, charbank bit 1
    //               1 = BG (chip 2, H16, gfx2) — 13-bit tile code, charbank[1:0]
    // (MAME ddribble.cpp get_fg/bg_tile_info — the ONLY per-chip render diff.)
    parameter        LAYER_BG = 0,
    // Sprite-ROM-bank routing (SCHEMATIC). Each chip's sprite patterns live in
    // the upper half of its gfx region; force the sprite fetch there:
    //   chip 1 (E16, gfx1 256 KB): OBJSTART=0x10000, OBJMASK=0x0FFFF
    //   chip 2 (H16, gfx2 512 KB): OBJSTART=0x20000, OBJMASK=0x1FFFF
    parameter [17:0] OBJSTART = 18'h0_0000,
    parameter [17:0] OBJMASK  = 18'h3_FFFF,
    // Screen-centering (model convenience — NOT real chip pins, like the
    // reference's HCTR/VCTR). Tunable per instance.
    parameter [3:0]  HCTR = 4'd0,
    parameter [3:0]  VCTR = 4'd0,
    // Scene-replay SIMFILE names (per chip, so FG/BG don't collide).
    parameter SIMATTR = "gfx_attr.bin",
    parameter SIMCODE = "gfx_code.bin",
    parameter SIMOBJ  = "gfx_obj.bin"
) (
    // ==================================================================
    // SCHEMATIC PINS — real 005885 package pins (GX690 page 0)
    // ==================================================================
    // ------------------------------------------------------------------
    // Clocks — the real 005885 clock pins are all UNUSED by this model: the
    // chip runs on the framework `clk` (48 MHz) + `pxl_cen`, not these. Kept
    // here as the schematic record:
    //   input  CK18  pin 1   — 18.432 MHz master video clock
    //   output NCPE  pin 104 — E clock to main MC6809E
    //   output NCPQ  pin 55  — Q clock to main MC6809E
    //   output NEQ   pin 56  — E·Q AND (feeds 007552 PAL G2B)
    //   output NCK2  pin 3   — buffered clock distribution
    //   (also disconnected on this PCB: NCK1 pin 2, 1H6 pin 58)
    // ------------------------------------------------------------------

    // ------------------------------------------------------------------
    // CPU bus
    // ------------------------------------------------------------------
    input      [13:0]  A,            // pins 50,49,98,48,97,138,47,96,137,46,95,136,45,94
    input      [ 7:0]  DBi,          // pins 52,101,142,51,100,141,99,139 (CD0..CD7) — data IN
    output     [ 7:0]  DBo,          //                                            — data OUT
    input              NXCS,         // pin 54  — chip select from main-CPU address decoder
    input              NRD,          // pin 102 — read enable (= CRTRD net); =1 means write
    // input           NREG,         // pin 44 — register-region select (UNUSED: registers decode from A/NXCS)
    input              NEXR,         // pin 43  — external reset input

    // ------------------------------------------------------------------
    // CPU interrupt outputs (raw chip pins; game.v applies the NFIR/NIRQ swap)
    // ------------------------------------------------------------------
    output             NIRQ,         // pin 41  — IRQ  to main CPU
    output             NNMI,         // pin 42  — NMI  to main CPU
    output             NFIR,         // pin 92  — FIRQ to main CPU

    // ------------------------------------------------------------------
    // Graphics-ROM bus (to external MASK1M pattern ROMs)
    //   chip #1 (E16) reaches 2 MASK1Ms = 256 KB (= mem.yaml `gfx1`)
    //   chip #2 (H16) reaches 4 populated MASK1Ms = 512 KB (= mem.yaml `gfx2`)
    // The 005885 emits 16 RA pins (R[15:0]); the high bits R16/R17 are made
    // EXTERNALLY by an LS74 chain (B15/A10/A11, page 0) latching the chip's
    // CHARA/CHAF2 outputs. We expose those two bits as RA16/RA17 so game.v
    // drives the SDRAM gfx-region MSBs (same role as the LS74 chain).
    // ------------------------------------------------------------------
    output             RA17,         // = internal rom_addr[17] (LS74 A10 Q on schematic)
    output             RA16,         // = internal rom_addr[16] (LS74 A11 Q on schematic)
    output     [15:0]  R,            // 16-bit ROM address (chip's RA0..RA15)
    input      [ 7:0]  RDU,          // pins 10,65,112,151,9,64,111,150 — upper byte
    input      [ 7:0]  RDL,          // pins 68,12,67,114,11,66,113,152 — lower byte

    // ------------------------------------------------------------------
    // Sync outputs (drive JAMMA video signal chain)
    // ------------------------------------------------------------------
    // output          NCSY,         // pin 4 — composite sync (UNUSED: video.v uses NHSY/NYSY/HBLK/VBLK)
    output             NYSY,         // pin 59  — vertical sync (active low; "NVSY" on schematic)

    // ------------------------------------------------------------------
    // Colour — the chip's final COL[4:0] is produced internally and exposed
    // to video.v via pxl_out (below). The raw COL pins + the tile/sprite
    // colour sub-buses are UNUSED here; kept as the schematic record:
    //   output [4:0] COL          pins 14,13,16,17,70  (final 5-bit colour)
    //   output [3:0] VCB,VCD      tile-colour sub-bus
    //   output [3:0] BCB,BCD,BCF  sprite-colour sub-bus
    //   (VCF pins 23,76,121,158 are GROUNDED externally — no port)
    // ------------------------------------------------------------------

    // ==================================================================
    // JTFRAME framework I/O — NOT present on the schematic
    // ==================================================================
    // No pin on the real 005885 corresponds to these. They exist because the
    // chip is hosted in JTFRAME: a fast SDRAM clock + clock-enables instead of
    // physically separate clocks, an SDRAM ready handshake (mask ROMs are
    // always-ready on real hw) and a PROM-load path for the boot ROM stream.
    // Wired to JTFRAME signals in game.v.
    // ------------------------------------------------------------------
    input              rst,
    input              clk,                 // JTFRAME 48 MHz (the reference's CK49)
    input              pxl_cen,             // pixel-rate clock-enable on `clk` (clk/8)
    input              cpu_cen,             // CPU-rate clock-enable on `clk`

    // SDRAM ready-handshake (graphics ROM fetch)
    input              rom_ok,              // SDRAM data valid for our R[]/RDU/RDL access
    output             rom_cs,              // request to JTFRAME's SDRAM controller

    // PROM-loading interface (JTFRAME MRA loader writes the sprite-lookup PROM)
    input      [ 8:0]  prog_addr,           // sprite-LUT PROM load addr ([8] gates the low 256 entries)
    input      [ 3:0]  prog_data,
    input              prom_we,

    // Video blanking — NOT on the real chip (the reference notes HBLK/VBLK are
    // "not exposed on the original chip"); exposed here so video.v can use the
    // chip's own timing and drop its jtframe_vtimer at integration (P10).
    output             HBLK,                // hblank (active high)
    output             VBLK,                // vblank (active high)
    output             NHSY,                // hsync  (active low)

    // ------------------------------------------------------------------
    // EXTERNAL RAM — the 8 KB 6264SL VRAM (tile attr/code + sprite list).
    // On the GX690 schematic this is a SEPARATE SRAM chip the 005885 drives
    // via its AX/VO/NVOW/NROE pins; the CPU has NO direct access — it reaches
    // it ONLY through this chip's bus interface. Per the design decision it is
    // modeled as a JTFRAME mem.yaml dual-port BRAM instantiated in
    // jtddribble_video.v (NOT inside this file). The chip drives BOTH BRAM
    // ports: port A = CPU-mediated access, port B = the render scanner. The
    // tile region is the lower 4 KB (AX[12]=0), the sprite list the upper
    // 4 KB (AX[12]=1).
    //   AX[12:0] schematic pins 36,87,37,88,131,166,38,89,132,167,39,90,133
    //   VO[7:0]  schematic pins 34,85,128,163,35,86,129,164
    //   NVOW pin 40   NROE pin 91
    // ------------------------------------------------------------------
    output     [12:0]  vram_cpu_addr,       // port A address (CPU-mediated, = A[12:0])
    output     [ 7:0]  vram_cpu_din,        // port A write data (= DBi)        — VO out
    output             vram_cpu_we,         // port A write enable              — NVOW
    input      [ 7:0]  vram_cpu_dout,       // port A read-back (→ DBo)         — VO in
    output     [12:0]  vram_scn_addr,       // port B address (render scanner)  — AX
    input      [ 7:0]  vram_scn_dout,       // port B read data                 — VO in

    // Colour output to the JTFRAME colour path (video.v's colmix): pxl_out[4:0] = COL.
    output     [ 6:0]  pxl_out
);

// Effective reset: framework rst (active high) OR external NEXR (active low).
wire chip_rst = rst | ~NEXR;

//------------------------------------------------------------------------
//  Clock
//------------------------------------------------------------------------
// The chip pixel clock is the framework pxl_cen (clk/8), in phase with the
// 007327's pxl_cen latch (one chip pixel per displayed pixel).
wire cen_6m = pxl_cen;

//------------------------------------------------------------------------
//  Video timing
//------------------------------------------------------------------------
// 384 horizontal x 262 vertical, active 256x224. h_cnt 0..383 (visible 0..255),
// v_cnt within [vcnt_start..vcnt_end]; v advances at end of line (h_cnt==383).
reg [8:0] h_cnt = 9'd0;
reg [8:0] v_cnt = 9'd0;

// ddribble HS sits inside the 256..383 hblank so it never fires during the
// 0..255 visible span (the Iron Horse 173..251 values would now land mid-screen).
// Matches the colmix HS_START/END (0x12F..0x14F) this chip-owned sync replaces.
localparam [8:0] HSYNC_START = 9'd303, HSYNC_END = 9'd335;
// V timing: clean 262-line frame (v_cnt 0..261), visible 16..239 (224 lines),
// vsync at 256. VCTR nudges the window vertically. This drives the framework's
// LVBL/VS directly (chip-owned sync), so it MUST be a stable 224-line frame
// every frame — the old Iron Horse 249..510 range ramped through 495 visible
// lines on frame 0 and tripped the framework's 256x224 size check.
localparam [8:0] VB_OFF  = 9'd239;   // last visible line  -> blank from 240
localparam [8:0] VB_ON   = 9'd15;    // last blanked line   -> visible from 16
localparam [8:0] VS_LINE = 9'd256;
localparam [8:0] HB_OPEN = 9'd14;    // visible window opens here (render latency)

reg hblank = 0;
reg vblank = 1;
reg frame_odd_even = 0;
// H timing: contiguous 256-wide visible (h_cnt 0..255), hblank 256..383, wrap at
// 383 — render columns (h_cnt[7:3] = col 0..31) line up with the display window.
// The Iron Horse layout put hblank mid-h_cnt, splitting the visible span and
// wrapping the columns (= the half-screen horizontal shift seen in scenes).
always @(posedge clk) if(cen_6m) begin
    if (h_cnt == 9'd383) begin
        h_cnt  <= 9'd0;
        if (v_cnt == 9'd261) v_cnt <= 9'd0;
        else                 v_cnt <= v_cnt + 9'd1;
        if (v_cnt == (VB_ON  - {5'd0,VCTR})) vblank <= 1'b0;
        if (v_cnt == (VB_OFF - {5'd0,VCTR})) begin vblank <= 1'b1; frame_odd_even <= ~frame_odd_even; end
    end else begin
        h_cnt <= h_cnt + 9'd1;
    end
    // LHBL window opens at h_cnt HB_OPEN (not 0) to absorb the render-pipeline
    // latency, so the displayed left edge lands on tile column 0. Measured: the
    // render led MAME by ~10 px when the window opened at h_cnt 0.
    if (h_cnt == (HB_OPEN - 9'd1)) hblank <= 1'b0;   // visible from HB_OPEN
    if (h_cnt == (HB_OPEN + 9'd255)) hblank <= 1'b1; // 256 px later -> blank
end

assign HBLK = hblank;
assign VBLK = vblank;
assign NHSY = ~(h_cnt >= (HSYNC_START - {6'd0,HCTR[2:0]}) && h_cnt < (HSYNC_END - {6'd0,HCTR[2:0]}));
assign NYSY = ~(v_cnt >= VS_LINE && v_cnt <= VS_LINE + 9'd2);

// Edge-detect for the interrupt logic (IRQ/NMI/FIRQ).
reg old_vcnt4, old_vcnt5, old_vblank;
always @(posedge clk) begin
    old_vcnt4  <= v_cnt[4];
    old_vcnt5  <= v_cnt[5];
    old_vblank <= vblank;
end

//------------------------------------------------------------------------
//  Control registers (5)
//------------------------------------------------------------------------
//  000: scroll y      001: scroll x low 8     002: bit0 scroll x hi; b3:1 row/col ctrl
//  003: b1:0 hi tile code; b3 sprite-buf sel  004: b0 nmi en, b1 irq en, b2 firq en, b3 flip
wire regs_cs = ~NXCS & (A[13:11] == 3'b000) & (A[6:3] == 4'd0);

reg [7:0] scroll_y   = 8'd0;
reg [7:0] scroll_x   = 8'd0;
reg [7:0] scroll_ctrl= 8'd0;
reg [7:0] tile_ctrl  = 8'd0;
reg nmi_mask = 0, irq_mask = 0, firq_mask = 0, flipscreen = 0;

always @(posedge clk) if(cpu_cen) begin
    if(regs_cs && NRD)              // NRD=1 => write cycle (registers clocked on cpu_cen)
        case(A[2:0])
            3'b000: scroll_y    <= DBi;
            3'b001: scroll_x    <= DBi;
            3'b010: scroll_ctrl <= DBi;
            3'b011: tile_ctrl   <= DBi;
            3'b100: begin
                nmi_mask   <= DBi[0];
                irq_mask   <= DBi[1];
                firq_mask  <= DBi[2];
                flipscreen <= DBi[3];
            end
            default:;
        endcase
end

//------------------------------------------------------------------------
//  Interrupts
//------------------------------------------------------------------------
reg vblank_irq = 1;
always @(posedge clk) begin
    if(chip_rst || !irq_mask)        vblank_irq <= 1;
    else if(!old_vblank && vblank)   vblank_irq <= 0;
end
assign NIRQ = vblank_irq;

reg nmi = 1;
always @(posedge clk) begin
    if(chip_rst || !nmi_mask) nmi <= 1;
    else if(tile_ctrl[2]) begin if(old_vcnt4 && !v_cnt[4]) nmi <= 0; end
    else                  begin if(old_vcnt5 && !v_cnt[5]) nmi <= 0; end
end
assign NNMI = nmi;

reg firq = 1;
always @(posedge clk) begin
    if(chip_rst || !firq_mask) firq <= 1;
    else if(frame_odd_even && !old_vblank && vblank) firq <= 0;
end
assign NFIR = firq;

//------------------------------------------------------------------------
//  Internal RAM (ZRAM + scratch; the 8 KB tile/sprite VRAM is external)
//------------------------------------------------------------------------
// ZRAM + scratch (0x05-0xDF) are INTERNAL chip RAM (row/col-scroll latches +
// register scratch) — they stay inside the chip. The 8 KB VRAM (tile +
// sprite) is the EXTERNAL 6264SL: no BRAM here, just the memory ports wired
// out to the mem.yaml BRAM in jtddribble_video.v (see the port list).
//   "Unknown"/scratch 0x05-0x1F, ZRAM0 0x20-0x3F (dual-port), ZRAM1 0x40-0x5F,
//   ZRAM2 0x60-0xDF, tile VRAM (A[13:12]=10), sprite VRAM (A[13:12]=11).
wire ram_cs      = ~NXCS & (A >= 14'h0005 && A <= 14'h001F);
wire zram0_cs    = ~NXCS & (A >= 14'h0020 && A <= 14'h003F);
wire zram1_cs    = ~NXCS & (A >= 14'h0040 && A <= 14'h005F);
wire zram2_cs    = ~NXCS & (A >= 14'h0060 && A <= 14'h00DF);
wire tile_cs     = ~NXCS & (A[13:12] == 2'b10);
wire spriteram_cs= ~NXCS & (A[13:12] == 2'b11);

wire [7:0] ram_Dout, zram0_Dout, zram1_Dout, zram2_Dout;

// ---- External 6264SL VRAM port drivers -------------------------------
// Port A — CPU-mediated (tile region A[12]=0, sprite region A[12]=1):
assign vram_cpu_addr = A[12:0];
assign vram_cpu_din  = DBi;
// Capture ONCE per CPU cycle (cpu_cen) — like the contra gfx_we. Without this
// the write fires every clk while selected, smearing data across cells as the
// CPU address transitions (the ~2^20 spurious writes). NRD=1 => write cycle.
assign vram_cpu_we   = (tile_cs | spriteram_cs) & NRD & cpu_cen;
// Port B — render scanner: driven by the tilemap render FSM below.

// ---- Internal scratch / ZRAM (NOT external on the schematic) ---------
jtframe_dual_ram #(.DW(8),.AW(5)) u_ram(
    .clk0(clk), .data0(DBi), .addr0(A[4:0]), .we0(ram_cs & NRD), .q0(ram_Dout),
    .clk1(clk), .data1(8'd0),.addr1(5'd0),   .we1(1'b0),         .q1()
);
jtframe_dual_ram #(.DW(8),.AW(5)) u_zram0(
    .clk0(clk), .data0(DBi), .addr0(A[4:0]), .we0(zram0_cs & NRD), .q0(zram0_Dout),
    .clk1(clk), .data1(8'd0),.addr1(5'd0),   .we1(1'b0),          .q1()
);
jtframe_dual_ram #(.DW(8),.AW(5)) u_zram1(
    .clk0(clk), .data0(DBi), .addr0(A[4:0]), .we0(zram1_cs & NRD), .q0(zram1_Dout),
    .clk1(clk), .data1(8'd0),.addr1(5'd0),   .we1(1'b0),          .q1()
);
jtframe_dual_ram #(.DW(8),.AW(7)) u_zram2(
    .clk0(clk), .data0(DBi), .addr0(A[6:0]), .we0(zram2_cs & NRD), .q0(zram2_Dout),
    .clk1(clk), .data1(8'd0),.addr1(7'd0),   .we1(1'b0),          .q1()
);

// CPU read mux (active during read cycles, NRD=0 => ~NRD=1). Tile + sprite
// reads both come from the external 6264SL (vram_cpu_dout).
assign DBo = (ram_cs       & ~NRD) ? ram_Dout      :
             (zram0_cs     & ~NRD) ? zram0_Dout    :
             (zram1_cs     & ~NRD) ? zram1_Dout    :
             (zram2_cs     & ~NRD) ? zram2_Dout    :
             ((tile_cs|spriteram_cs) & ~NRD) ? vram_cpu_dout :
             8'hFF;

//------------------------------------------------------------------------
//  Tilemap + sprite pixel pipeline
//------------------------------------------------------------------------
// Ground-up port of the Iron Horse reference tilemap (clean per-pixel shift
// output = the thin-text fix) with ddribble's PROVEN fetch addressing:
//  - tile code: MAME ddribble.cpp get_fg/bg_tile_info  (per-chip via LAYER_BG)
//  - scan:      vram_A = {hpos[8], code_sel, vpos[7:3], hpos[7:3]} (col[5]<<11)
//  - scroll:    solid X/Y only (ddribble never uses ZRAM row/col scroll)
//  - decode:    rom_data = 4 nibbles, one per h_cnt[1:0]  (charlayout 4bpp)
//  - colour:    COL = {1'b1, pixel} (MAME tile colour=0; 007327 does pri+palette)
// Fine (sub-tile) X scroll + H/V centering are handled by the line-buffer
// renderer below (007121 mechanism: fine scroll = the line-buffer write address).

// ====================  Tilemap line-buffer renderer (007121 / jtcontra)  ======
// The scanline is rendered into a DOUBLE-BUFFERED line buffer, each pixel written
// at the fine-scroll-offset column tm_hrender; the display reads it back at the
// screen column. This is jtcontra_gfx_tilemap's mechanism (fine scroll = the
// write address) — full 0..7px fine X scroll, no edge-priming, and auto-aligned
// with the sprites (same scheme). The render FSM (below) mirrors the sprite
// engine and time-shares the VRAM + gfx ROM ports with it (tilemap in the non-obj
// window h_cnt<272, sprites in obj_win >=272). Render leads display by one line
// (tm_vpos=v_cnt+1); the buffer's 1-line read latency cancels it.
reg  [3:0]  tm_st;
reg  [1:0]  tm_wait;
reg         tm_run, tm_sel, tm_line, old_tm_obj;
reg  [8:0]  tm_hn;          // scan h = {scroll_ctrl[0],scroll_x}, +4 per gfx half
reg  [8:0]  tm_hrender;     // line-buffer write column (fine offset applied)
reg  [5:0]  tm_col;         // tiles rendered this line
reg  [1:0]  tm_bank;
reg  [7:0]  tm_index;
reg         tm_hflip, tm_vflip, tm_a5;
reg  [15:0] tm_word;
reg  [1:0]  tm_dn;
reg         tm_we;
reg  [8:0]  tm_waddr;
reg  [3:0]  tm_wdata;

wire [11:0] obj_rd_addr;
wire        obj_win  = h_cnt >= 9'd272;
wire [8:0]  tm_vpos  = ((v_cnt + 9'd1) ^ {9{flipscreen}}) + {1'd0, scroll_y};
// SIM-only fine-scroll test hook: -d SIM_SCROLLX=N forces the render's X scroll
// (the scene-sim CPU is stubbed, so scroll_x is otherwise 0). Lets us confirm the
// picture shifts smoothly 0..7px per the line-buffer write address.
`ifdef SIM_SCROLLX
wire [7:0]  r_scroll_x = `SIM_SCROLLX;
`else
wire [7:0]  r_scroll_x = scroll_x;
`endif
// VRAM scan port: render FSM owns it in the non-obj window, sprite scan in obj_win
assign vram_scn_addr = obj_win ? { 1'b1, obj_rd_addr }
                               : { 1'b0, tm_hn[8], ~tm_sel, tm_vpos[7:3], tm_hn[7:3] };

// Tile gfx address for the current 4px half (tm_hn[2] selects the half)
wire [12:0] tm_code = { LAYER_BG ? tile_ctrl[1:0] : { 1'b0, tile_ctrl[1] },
                        tm_a5, tm_bank, tm_index };
wire [16:0] tm_rom_addr = { tm_code, tm_vpos[2:0] ^ {3{tm_vflip}}, tm_hn[2] ^ tm_hflip };
wire        tm_rom_cs   = tm_run && (tm_st==4'd2 || tm_st==4'd3);
wire [3:0]  tm_pixel    = tm_hflip ? tm_word[3:0] : tm_word[15:12];

// gfx ROM port — TIME-SHARED tilemap render (non-obj) / sprite (obj_win)
wire [17:0] spr_rom_addr;
wire        spr_rom_cs;
wire [17:0] rom_addr = obj_win ? spr_rom_addr : { 1'b0, tm_rom_addr };
assign R      = rom_addr[15:0];
assign RA16   = rom_addr[16];
assign RA17   = rom_addr[17];
assign rom_cs = obj_win ? spr_rom_cs : tm_rom_cs;

// Render FSM: per tile, read ATTR then CODE via the shared scan port, fetch the
// two 4px gfx halves, and dump each into the line buffer at tm_hrender. Coarse
// scroll = tm_hn start (tile + starting half via tm_hn[2]); fine scroll =
// scroll_x[1:0] offset on tm_hrender. Mirrors the sprite FSM's wait-state shape.
always @(posedge clk) begin
    old_tm_obj <= obj_win;
    tm_we      <= 1'b0;
    if (rst) begin
        tm_run<=0; tm_st<=0; tm_line<=0; tm_sel<=1; tm_wait<=0;
        tm_hn<=0; tm_hrender<=0; tm_col<=0;
    end else if (old_tm_obj && !obj_win) begin   // line start (obj_win falling)
        tm_run    <= 1'b1;
        tm_st     <= 4'd0;
        tm_sel    <= 1'b1;                         // attr byte first
        tm_wait   <= 2'd0;
        tm_col    <= 6'd0;
        tm_hn     <= { scroll_ctrl[0], r_scroll_x };
        tm_hrender<= TM_HSTART - { 7'd0, r_scroll_x[1:0] };
        tm_line   <= ~tm_line;                     // swap double buffer
    end else if (obj_win) begin
        tm_run    <= 1'b0;
    end else if (tm_run) case (tm_st)
        4'd0: if (tm_wait!=2'd2) tm_wait<=tm_wait+2'd1;   // read ATTR (tm_sel=1)
              else begin tm_wait<=2'd0;
                  tm_bank <= vram_scn_dout[7:6];
                  tm_hflip<= vram_scn_dout[4];
                  tm_vflip<= vram_scn_dout[5];
                  tm_a5   <= vram_scn_dout[5];
                  tm_sel  <= 1'b0; tm_st<=4'd1; end
        4'd1: if (tm_wait!=2'd2) tm_wait<=tm_wait+2'd1;   // read CODE (tm_sel=1)
              else begin tm_wait<=2'd0; tm_index<=vram_scn_dout; tm_st<=4'd2; end
        4'd2: tm_st<=4'd3;                                // issue gfx fetch
        4'd3: if (rom_ok) begin tm_word<={RDU,RDL}; tm_dn<=2'd0; tm_st<=4'd4; end
        4'd4: begin                                       // dump 4 px into the buffer
                  tm_we     <= 1'b1;
                  tm_waddr  <= tm_hrender;
                  tm_wdata  <= tm_pixel;
                  tm_hrender <= tm_hrender + 9'd1;
                  tm_word   <= tm_hflip ? {4'd0, tm_word[15:4]} : {tm_word[11:0], 4'd0};
                  tm_dn     <= tm_dn + 2'd1;
                  if (tm_dn==2'd3) begin
                      tm_hn <= tm_hn + 9'd4;
                      if (!tm_hn[2]) tm_st <= 4'd2;        // half0 done -> half1 (same tile)
                      else begin                          // half1 done -> next tile
                          tm_sel <= 1'b1; tm_st <= 4'd0;
                          tm_col <= tm_col + 6'd1;
                          if (tm_col >= 6'd33) tm_run <= 1'b0;
                      end
                  end
              end
        default: tm_run<=1'b0;
    endcase
end

// Tilemap line buffer — double-buffered: the render FSM writes bank tm_line, the
// display reads bank ~tm_line at the screen column (+TM_HSTART to match the render
// start, which carries the fine-scroll headroom). 9-bit column so the 34-tile
// render (+ fine offset) never wraps onto the visible columns.
localparam [8:0] TM_HSTART = 9'd6;      // render/display column offset (+2 = read-pipeline latency)
// Line-buffer read column. Algebraically this is obj_dcol + TM_HSTART + 2 (the
// +2 compensates the read-pipeline latency), BUT obj_dcol (= h_cnt - HB_OPEN)
// WRAPS to 0xFE/0xFF at h_cnt 12..13, immediately before the display window. The
// read pipeline then carried the buffer's RIGHT edge into the FIRST display pixel,
// so display col 0 showed right-edge content -> the "left wrap" (a stray right-edge
// column on the left; on the POST screen the right-guard tile is a constant green).
// Derive the column straight from h_cnt instead (HB_OPEN-TM_HSTART-2 = 6 = TM_HSTART,
// so this is identical inside the display region) so the pre-display columns count
// DOWN cleanly to the real left edge instead of wrapping high.
wire [8:0] tm_rdcol = h_cnt - TM_HSTART;
wire [3:0] tm_buf_px;
jtframe_dual_ram #(.DW(4), .AW(10)) u_tm_line(
    .clk0 ( clk ), .clk1 ( clk ),
    .data0( tm_wdata ), .addr0( { tm_line,  tm_waddr } ), .we0( tm_we ), .q0(),
    .data1( 4'd0 ),     .addr1( { ~tm_line, tm_rdcol } ), .we1( 1'b0 ), .q1( tm_buf_px )
);
reg [3:0] tilemap_px;
always @(posedge clk) if(cen_6m) tilemap_px <= tm_buf_px;

//------------------------------------------------------------------------
//  Sprite list scan + parse (005885 OBJ, ddribble format)
//------------------------------------------------------------------------
// Format: MAME konami/ddribble.cpp draw_sprites (doc/005885_sprite_format.md).
// The 005885 OBJ layout differs from the 007121 silicon, so it is MAME-grounded
// (same game) and graded against the scene captures (scenes/*/sprites.txt).
// 5 bytes/sprite, NSPR sprites (FG/chip1=25, BG/chip2=64):
//   byte0=code[7:0]  byte1={col[3:0],_,code[10:8]}  byte2=Y  byte3=X
//   byte4={_,flipy(6),flipx(5),size[4:2],x8(0)}
// The list is this chip's VRAM at A12=1, read on the render port during HBLANK
// (time-shared with the tilemap scan — see vram_scn_addr above).
localparam [8:0] OBJ_BYTES = LAYER_BG ? 9'd320 : 9'd125;  // 5*NSPR
// 007121 (jtcontra_gfx_obj.v:122) maps the sprite Y byte straight onto the render
// row (vsub = vrender - Y, no offset). Our tilemap renders one line ahead
// (tm_vpos=v_cnt+1) into a line buffer, so the sprite must use the same v_cnt+1
// basis to sit on the tilemap (basket on its pole). The old OBJ_DY=15 pushed
// sprites ~16px down. Tunable if a residual 1-2px shows on hardware.
localparam [8:0] OBJ_DY    = 9'd1;    // sprite render-ahead (vrr = v_cnt + OBJ_DY)

reg  [ 8:0] obj_base;      // byte offset of current sprite (0,5,10,...)
reg  [ 2:0] obj_byte;      // OBJ byte being addressed
reg  [ 3:0] obj_st;        // scan/render FSM state
reg  [ 2:0] obj_rp;        // pipelined OBJ-RAM read phase (0..6)
reg         obj_run;
reg  [ 7:0] s_y, s_b0, s_b1;
reg  [ 8:0] s_xpos;
reg  [ 3:0] s_col;
reg  [ 2:0] s_size;
reg         s_fx, s_fy, s_x8;
reg  [ 5:0] row_sp;        // sprite-space row (0..obj_h-1, vflip-adjusted)
reg  [ 5:0] spr_hp;        // screen-space column within the sprite (0..obj_w-1)
reg  [15:0] spr_word;      // fetched gfx word (4 px)
reg  [ 1:0] spr_dn;        // nibble counter for the dump
reg         old_hblk_obj;
reg         line_we;
reg  [ 7:0] line_addr;
reg  [ 3:0] line_data;     // OCD (looked-up sprite colour), 0 = transparent

assign obj_rd_addr = { 3'd0, obj_base } + { 9'd0, obj_byte };

wire [10:0] spr_num = { s_b1[2:0], s_b0 };                  // 11-bit sprite number
wire [ 8:0] vrr   = v_cnt + OBJ_DY;                         // render row (next line)
wire [ 5:0] obj_h = (s_size[2]|s_size[1]) ? 6'd32 : 6'd16;  // sprite height
wire [ 5:0] obj_w = (s_size[2]|s_size[0]) ? 6'd32 : 6'd16;  // sprite width
wire        y_hit = (vrr >= {1'b0,s_y}) && (vrr < ({1'b0,s_y} + {3'd0,obj_h}));

// MAME masks the base number per size (ddribble.cpp draw_sprites):
//   32x32 (s_size=100): &~3   16x32 (010): &~2   32x16 (001): &~1   16x16: &~0
wire [10:0] base_num = (s_size==3'b100) ? (spr_num & ~11'd3) :
                       (s_size==3'b010) ? (spr_num & ~11'd2) :
                       (s_size==3'b001) ? (spr_num & ~11'd1) : spr_num;
// Multi-tile expansion: tile = base + x_offset[ex] + y_offset[ey],
//   x_offset={0,1}, y_offset={0,2}.  ex/ey pick the 16x16 sub-tile within a
//   32px sprite. spr_hp is screen-space (left->right); row_sp is already
//   vflip-adjusted, so the sub-tile index follows it for free.
wire        sub_x   = (obj_w==6'd32) & spr_hp[4];
wire        sub_y   = (obj_h==6'd32) & row_sp[4];
wire [10:0] eff_num = base_num + {10'd0,sub_x} + {9'd0,sub_y,1'b0};

// Sprite gfx WORD address: eff_num*64 + quad*16 + vsub*2 + h4, masked into the
// chip's OBJ region. 16x16 layout (verified vs MAME spritelayout): quad TL=0/
// TR=16/BL=32/BR=48 = {row_sp[3],spr_hp[3]}, vsub=row_sp[2:0], h4=spr_hp[2].
// (hflip / colour-LUT: follow-ups.)
wire [16:0] spr_local = { eff_num, row_sp[3], spr_hp[3], row_sp[2:0], spr_hp[2] };
assign spr_rom_addr = OBJSTART | ({1'b0, spr_local} & OBJMASK);
assign spr_rom_cs   = obj_run && (obj_st==4'd6 || obj_st==4'd7);

// Screen column for the line-buffer write. MAME draws at sx + x*16 with NO wrap
// (clipped to the 256px screen) — so a sprite whose column lands >=256 is OFF
// screen and must be dropped, not folded onto column (sx&0xFF).
// h-flip: mirror the screen column within the sprite (MAME: ex = flipx ? w-1-x : x).
// Mirroring the line-buffer WRITE position flips both the sub-tile order and the
// intra-tile pixel order in one shot; the gfx is read in natural order.
wire [ 5:0] hp_scr   = s_fx ? (obj_w - 6'd1 - spr_hp) : spr_hp;
// -1: measured the sprite layer 1px right of MAME (cross-correlated mame_02700
// player sprites = dx+1), while the tilemap is positionally correct (static
// scenes mame_00300/00600/01500 = dx0). Shift the sprite screen column 1px left
// so sprites align with both the tilemap and MAME.
wire [ 9:0] full_col = ({1'b0, s_xpos} + {4'd0, hp_scr}) - 10'd1;

// Sprite colour LUT PROM (reference k005885: OCF=sprite_color, OCB=sprite_pixel,
// OCD=PROM[{OCF,OCB}]; verified on furrtek 007121 p14 COLOR LOOKUP + p15 COLOR
// OUTPUT). chip2 (gfx2) uses the I15 256x4 PROM; chip1 (gfx1) maps 1:1 (MAME
// GFXDECODE "gfx1" colours 32-47, 1 set vs "gfx2" colours 0-15, 16 sets w/ LUT).
reg  [3:0] oprom [0:255];
always @(posedge clk) if (prom_we && !prog_addr[8]) oprom[prog_addr[7:0]] <= prog_data;
wire [3:0] dump_nibble = spr_word[15:12];                 // OCB (sprite pixel)
wire [3:0] prom_ocd    = oprom[{s_col, dump_nibble}];     // OCD = PROM[{OCF,OCB}]
wire [3:0] obj_ocd     = BYPASS_OPROM ? dump_nibble : prom_ocd;

// Scan the OBJ list in the sprite window: size+Y first (skip non-overlap), else
// read code/colour/X and fetch+dump the 16x16 gfx row into the line buffer.
always @(posedge clk) begin
    old_hblk_obj <= obj_win;
    line_we <= 1'b0;
    if (rst) begin
        obj_run<=1'b0; obj_st<=4'd0; obj_base<=9'd0; obj_byte<=3'd4; obj_rp<=3'd0;
    end else if (!old_hblk_obj && obj_win) begin   // sprite-scan window start
        obj_run<=1'b1; obj_st<=4'd0; obj_base<=9'd0; obj_byte<=3'd4; obj_rp<=3'd0;
    end else if (!obj_win) begin
        obj_run<=1'b0;
    end else if (obj_run) case (obj_st)
        // Pipelined OBJ-RAM read. The five attribute bytes live at offsets
        // 4,2,0,1,3 in the VRAM (jtframe_dual_ram, single-register read =
        // 1-clk latency: q1@N = mem[addr@N-1]). Instead of waiting out the
        // latency per field (~15 clk), issue all five addresses back-to-back
        // and capture each datum 1 clk after its address — 6 clk total. This
        // lets far more sprites fit the fixed scan window, killing the
        // busy-line flicker / dropped-sprite-rows. byte4 is already presented
        // (obj_byte<=4 from window-start / st9), so phase 0 already addresses it.
        4'd0: begin
            obj_rp <= obj_rp + 3'd1;
            case (obj_rp)                          // present the next byte address
                3'd0: obj_byte <= 3'd2;            // (byte4 already on the bus)
                3'd1: obj_byte <= 3'd0;
                3'd2: obj_byte <= 3'd1;
                3'd3: obj_byte <= 3'd3;
                default:;
            endcase
            case (obj_rp)                          // capture the datum issued 1 clk ago
                3'd1: begin s_size<=vram_scn_dout[4:2]; s_fx<=vram_scn_dout[5];   // byte4
                            s_fy<=vram_scn_dout[6]; s_x8<=vram_scn_dout[0]; end
                3'd2: s_y  <= vram_scn_dout;                                      // byte2
                3'd3: s_b0 <= vram_scn_dout;                                      // byte0
                3'd4: begin s_col<=vram_scn_dout[7:4]; s_b1<=vram_scn_dout; end   // byte1
                3'd5: begin s_xpos<={s_x8,vram_scn_dout};                         // byte3
                    // sprite-space row within the (16 or 32)-tall sprite; vflip mirrors it.
                    row_sp <= s_fy ? (obj_h - 6'd1 - (vrr[5:0]-s_y[5:0])) : (vrr[5:0]-s_y[5:0]);
                    spr_hp <= 6'd0; obj_st <= 4'd6; end
                default:;
            endcase
            // y_hit valid once s_y is captured (phase 2); skip off-scanline sprites.
            if (obj_rp==3'd3 && !y_hit) obj_st <= 4'd9;
        end
        4'd6: obj_st<=4'd7;                                    // issue gfx fetch
        4'd7: if (rom_ok) begin spr_word<={RDU,RDL}; spr_dn<=2'd0; obj_st<=4'd8; end
        4'd8: begin                                            // dump 4 px (high-nibble first)
                  // write only if on-screen (clip) AND opaque (OCD!=0, per reference)
                  line_we   <= ~|full_col[9:8] & (obj_ocd != 4'd0);
                  line_addr <= full_col[7:0];
                  line_data <= obj_ocd;                        // looked-up sprite colour
                  spr_word  <= { spr_word[11:0], 4'd0 };
                  spr_hp    <= spr_hp + 6'd1;
                  spr_dn    <= spr_dn + 2'd1;
                  if (spr_dn==2'd3)
                      obj_st <= ((spr_hp+6'd1) >= obj_w) ? 4'd9 : 4'd6;
              end
        4'd9: begin                                            // next sprite
                  obj_byte<=3'd4; obj_st<=4'd0; obj_rp<=3'd0;
                  if (obj_base >= OBJ_BYTES-9'd5) obj_run<=1'b0;
                  else obj_base<=obj_base+9'd5;
              end
        default: obj_st<=4'd9;
    endcase
end

// Sprite line buffer (jtframe_obj_buffer, jotego standard, double-buffered with
// erase-on-read). P8a writes a fixed bright box; P8b will write gfx pixels.
wire [3:0] obj_pxl;     // looked-up sprite colour (OCD); 0 = transparent
wire [7:0] obj_dcol = h_cnt[7:0] - HB_OPEN[7:0];   // display column for read
// jtframe_obj_buffer is DOUBLE-buffered: it toggles an internal bank on LHBL's
// FALLING edge, reads/erases bank ~line, writes bank line. The bank must stay
// constant across BOTH the display read (h_cnt 14..269) and the obj_win write
// (h_cnt>=272), toggling only in the gap. ~HBLK falls at h_cnt 256 — mid-display
// — which split the read across two banks and put the write in the just-read
// bank (sprites duplicated down the screen). Toggle at the line start (h_cnt 0,
// before display) instead so display+write share one bank.
// Bank-toggle for the double buffer must (a) leave `line` CONSTANT across both
// the display read (h_cnt 14..269) and the obj_win write (272..383) so they hit
// opposite banks, and (b) NOT sit at the h_cnt 383->0 wrap (the combinational
// compare glitches there in Verilator). A low window at h_cnt 2..13 gives a
// clean mid-count falling edge inside the only gap that satisfies (a).
wire objbuf_lhbl = (h_cnt < 9'd2) || (h_cnt >= 9'd14);
jtframe_obj_buffer #(.DW(4), .AW(8), .ALPHA(4'h0)) u_objbuf(
    .clk     ( clk            ),
    .LHBL    ( objbuf_lhbl    ),   // falls at h_cnt 2 (in the post-obj_win / pre-display gap)
    .flip    ( 1'b0           ),
    .wr_data ( line_data      ),       // P8b: OCD (looked-up sprite colour)
    .wr_addr ( line_addr      ),
    .we      ( line_we        ),
    .rd_addr ( obj_dcol       ),
    // Erase-on-read MUST be gated to the visible window. obj_dcol = h_cnt-14
    // wraps mod-256, so during early blanking (h_cnt 2..13) it revisits cols
    // 244..255 and the buffer would erase them BEFORE they are displayed at
    // h_cnt 258..269 -> clean cut of the right ~12 px of every sprite. Gating
    // on ~hblank erases each column exactly once, as it is shown.
    .rd      ( pxl_cen & ~hblank ),
    .rd_data ( obj_pxl        )
);

//------------------------------------------------------------------------
//  Colour out — tilemap pixel + sprite mux into COL[4:0]
//------------------------------------------------------------------------
// Reference k005885 colour mixer (verified furrtek 007121 p15 COLOR OUTPUT):
//   tile_sprite_sel = ~(|sprite_D);   COL = {tile_sprite_sel, colour4}
// so an opaque SPRITE drives COL[4]=0, a TILE drives COL[4]=1. The 007327 then
// uses g2col[4] in PRI=(|g1col[3:0])&g2col[4] and col_mux[4]=CB4 of the palette
// address — i.e. COL[4] picks the sprite vs tile palette half. (Storing {1,nibble}
// before put sprites in the TILE half -> the all-green bug.)
wire [4:0] COL = (obj_pxl != 4'h0) ? { 1'b0, obj_pxl } : { 1'b1, tilemap_px };
assign pxl_out = { 2'b00, COL };

endmodule
