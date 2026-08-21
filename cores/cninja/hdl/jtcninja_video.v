/*  This file is part of JTCORES. GPLv3. See jtcninja_game.v header.

    Video subsystem (v0) for Data East cninja.cpp (Joe & Mac).

    This v0 provides the boot-critical pieces:
      - jtframe_vtimer: real 256x240 @ ~58Hz timing so LVBL toggles and the
        68000 VBLANK IRQ (IPL5) actually fires (the stub held LVBL=1, which
        stalled boot).
      - VRAM read-back: palette (0x19c000), the two deco16ic playfield data
        RAMs per tilegen, and sprite RAM (0x1a4000) as real dual-port RAM so
        the CPU's read-back / RAM tests behave.

    NOT yet implemented (renders black): the deco16ic tilemap fetch + sprite
    drawing + colmix priority. Palette is xBGR_888 (2 words/colour), 2048
    colours - see doc/cninja.cpp PALETTE set_format.
*/
module jtcninja_video(
    input             rst,
    input             clk,
    input             pxl2_cen,
    input             pxl_cen,
    input      [ 3:0] gfx_en,
    output            flip,
    // Caveman Ninja Hardware family selector (0=cninja, 2=darkseal). Dark Seal's
    // tilegen data/control/rowscroll are exploded across the map (needs A[19:16]
    // to tell apart), so cpu_addr is widened to [19:1].
    input      [ 3:0] game_id,
    input             cbpri,        // cbuster TC-4 layer priority (m_pri)
    // CPU interface
    input      [19:1] cpu_addr,
    input      [15:0] cpu_dout,
    input      [ 1:0] cpu_dsn,
    input             cpu_rnw,
    input             pf0_cs,
    input             pf1_cs,
    output     [15:0] pf0_dout,
    output     [15:0] pf1_dout,
    input             objram_cs,
    input             obj_copy,
    output     [15:0] obj_dout,
    input             pal_cs,
    output     [15:0] pal_dout,
    // Char ROM (BA2)
    output            char_cs,
    output     [16:2] char_addr,
    input      [31:0] char_data,
    input             char_ok,
    // Tile ROM 1 (BA2)
    output            scr1_cs,
    output     [18:2] scr1_addr,
    input      [31:0] scr1_data,
    input             scr1_ok,
    // Tile ROM 2 (BA2)
    output            scr2_cs,
    output     [19:2] scr2_addr,
    input      [31:0] scr2_data,
    input             scr2_ok,
    // Tile ROM 2 second reader (BA2) - tilegen1 pf1 shares the tiles2 ROM
    output            scr3_cs,
    output     [19:2] scr3_addr,
    input      [31:0] scr3_data,
    input             scr3_ok,
    // Sprite ROM (BA3)
    output            obj_cs,
    output     [20:2] obj_addr,
    input      [31:0] obj_data,
    input             obj_ok,
    // Vertical position (for deco_irq raster/vblank in main)
    output     [ 8:0] vdump,
    // Video output
    output            HS,
    output            VS,
    output            LHBL,
    output            LVBL,
    output     [`JTFRAME_COLORW-1:0] red,
    output     [`JTFRAME_COLORW-1:0] green,
    output     [`JTFRAME_COLORW-1:0] blue
);

assign flip = 1'b0;     // TODO: from deco16ic control register

// ---- ROM buses: scr2=bg (tilegen1 pf2), scr1=mg (tilegen0 pf2),
//      char=fg (tilegen0 pf1, 8x8 text), obj=sprites (decospr) ----

// ---- timing ----
wire [8:0] hdump, vrender;
// Horizontal alignment: read the line buffers HOFFSET px ahead to compensate the
// line-buffer -> colmix -> palette -> blank pipeline. With the combinational
// blank (jtframe_blank DLY=0) the pipeline is 1px shorter, so HOFFSET=0 keeps the
// picture pixel-aligned to MAME (HOFFSET=1 + DLY=2 was the earlier registered combo).
localparam [8:0] HOFFSET = 9'd0;
wire [8:0] hdump_rd = hdump + HOFFSET;
jtframe_vtimer #(
    .VB_START ( 9'd247 ),
    .VB_END   ( 9'd7   ),
    .VCNT_END ( 9'd273 ),  // 274 lines total
    .VS_START ( 9'd254 ),
    .HB_START ( 9'd255 ),
    .HB_END   ( 9'd375 ),  // 376 pixels total
    .HS_START ( 9'd300 ),
    .HINIT    ( 9'd255 )
) u_vtimer(
    .clk      ( clk     ),
    .pxl_cen  ( pxl_cen ),
    .vdump    ( vdump   ),
    .vrender  ( vrender ),
    .vrender1 (         ),
    .H        ( hdump   ),
    .Hinit    (         ),
    .Vinit    (         ),
    .LHBL     ( LHBL    ),
    .LVBL     ( LVBL    ),
    .HS       ( HS      ),
    .VS       ( VS      )
);

// ---- CPU write strobes (byte lanes) ----
wire        wr    = ~cpu_rnw;
wire [1:0]  wmask = ~cpu_dsn;

// ---- scene-replay (NOMAIN): the video RAMs preload MAME's captured state
// from <scene>/{pal,t0p1,t0p2,t1p1,t1p2,oram}.bin (ENDIAN=1 = m68k byte order),
// so `jtsim -s <scene>` renders the scene with the CPU tied off. SIMFILE is
// empty in normal runs (CPU fills the RAMs). See ver/cninja/README.md.
`ifdef NOMAIN
localparam SF_PAL="pal.bin", SF_T0P1="t0p1.bin", SF_T0P2="t0p2.bin",
           SF_T1P1="t1p1.bin", SF_T1P2="t1p2.bin", SF_ORAM="oram.bin";
`else
localparam SF_PAL="", SF_T0P1="", SF_T0P2="", SF_T1P1="", SF_T1P2="", SF_ORAM="";
`endif

// ---- palette RAM : 0x19c000-0x19dfff, xBGR_888 (2 words/colour) ----
// Stored as raw 16-bit words; jtcninja_colmix combines the word pair into RGB.
wire [15:0] pal_vq;
wire [11:0] palrd_a;        // palette read address (driven by jtcninja_colmix)
jtframe_dual_ram16 #(.AW(12), .ENDIAN(1), .SIMFILE(SF_PAL)) u_pal(
    // vapor: GR @0x300000 / B @0x304000 split on byte-addr bit14 -> u_pal bit11;
    // colour index in [11:1]. Others: cninja 2w/colour & darkseal/cbuster bit12.
    .clk0 ( clk ), .addr0( vapor ? {cpu_addr[14], cpu_addr[11:1]} : cpu_addr[12:1] ), .data0( cpu_dout ),
    .we0  ( {2{pal_cs & wr}} & wmask ), .q0( pal_dout ),
    .clk1 ( clk ), .addr1( palrd_a ), .data1( 16'd0 ), .we1( 2'b0 ), .q1( pal_vq )
);

wire dseal = game_id==4'd2;
// Crude Buster (game_id==1): tilegen data/control/rowscroll exploded across the
// 0x0a/0x0b map. chip0 (pf0_cs) data 0x0a0000-0x0a7fff (A[16]=0) + ctrl 0x0b5000
// (A[16]=1); chip1 (pf1_cs) data 0x0a8000-0x0affff + ctrl 0x0b6000. Within the
// data window A[15:13] selects: chip0 pf1=000 pf2=001 rs0=010 rs1=011;
// chip1 pf1=100 pf2=101 rs2=110 rs3=111. Maps cninja-style (pf1=fg, pf2=mg).
wire cbust = game_id==4'd1;
// Super Burger Time (game_id==4): single tilegen at 0x300000 (ctrl) / 0x320000
// (pf1 8x8) / 0x322000 (pf2 16x16) / 0x340000,0x342000 (rowscroll). main.v's
// pf0_cs gates the {0x30,0x32,0x34} pages; within it A[17]=pf-data (0x32),
// A[18]=rowscroll (0x34), A[13]=pf1(0)/pf2(1). cpu_addr is [19:1] so A[17:18]
// are visible. Like cninja, pf1=fg(8x8)/pf2=mg(16x16) -> default vaddr routing.
wire supbt = game_id==4'd4;
// Vapor Trail (game_id==3): 2x deco16ic, NO rowscroll (pf_update(0,0)). Map (the
// video cpu_addr is [19:1] so [19:16] = byte-addr nibble):
//   tilegen0 (pf0_cs): pf1 0x280000(A19_16=8,~A13) pf2 0x282000(A13) ctrl 0x2c0000(=c)
//   tilegen1 (pf1_cs): pf1 0x200000(A19_16=0,~A13) pf2 0x202000(A13) ctrl 0x240000(=4)
// tilegen0 feeds BOTH playfields from tiles1; tilegen1 from tiles2 (see ROM routing).
wire vapor = game_id==4'd3;

// ---- deco16ic playfield data RAM (read-back), muxed per game_id ----
// cninja  : packed in a 64kB window, sub-decoded by A[15:13]
//           tilegen0/1 pf1 data @010, pf2 data @011, control @000, rowscroll @110/111
// darkseal: exploded across the map, sub-decoded by A[19:16]+A[13]
//   tilegen1: pf1 0x200000(A19_16=0,A13=0)  pf2 0x202000(A13=1)
//             rowscroll 0x222000(A19_16=2)  control 0x240000(A19_16=4)
//   tilegen0: pf1 0x260000(A19_16=6,A13=0)  pf2 0x262000(A13=1)
//             rowscroll 0x220000(A19_16=2)  control 0x2a0000(A19_16=a)
wire [15:0] t0p1_q, t0p2_q, t1p1_q, t1p2_q;
wire t0p1 = pf0_cs & (dseal ? (cpu_addr[19:16]==4'h6 & ~cpu_addr[13]) :
                      cbust ? (~cpu_addr[16] & cpu_addr[15:13]==3'b000) :
                      supbt ? ( cpu_addr[17] & ~cpu_addr[13]) :    // 0x320000-0x321fff pf1
                      vapor ? (cpu_addr[19:16]==4'h8 & ~cpu_addr[13]) :  // 0x280000
                              (cpu_addr[15:13]==3'b010));
wire t0p2 = pf0_cs & (dseal ? (cpu_addr[19:16]==4'h6 &  cpu_addr[13]) :
                      cbust ? (~cpu_addr[16] & cpu_addr[15:13]==3'b001) :
                      supbt ? ( cpu_addr[17] &  cpu_addr[13]) :    // 0x322000-0x323fff pf2
                      vapor ? (cpu_addr[19:16]==4'h8 &  cpu_addr[13]) :  // 0x282000
                              (cpu_addr[15:13]==3'b011));
wire t1p1 = pf1_cs & (dseal ? (cpu_addr[19:16]==4'h0 & ~cpu_addr[13]) :
                      cbust ? (~cpu_addr[16] & cpu_addr[15:13]==3'b100) :
                      vapor ? (cpu_addr[19:16]==4'h0 & ~cpu_addr[13]) :  // 0x200000
                              (cpu_addr[15:13]==3'b010));
wire t1p2 = pf1_cs & (dseal ? (cpu_addr[19:16]==4'h0 &  cpu_addr[13]) :
                      cbust ? (~cpu_addr[16] & cpu_addr[15:13]==3'b101) :
                      vapor ? (cpu_addr[19:16]==4'h0 &  cpu_addr[13]) :  // 0x202000
                              (cpu_addr[15:13]==3'b011));

// deco16ic rowscroll/colscroll RAM is READ+WRITE: the CPU reads back the
// accumulated value (e.g. cninja boss-sink colscroll @0x15c400 does
// `add.w (A4),D0` to ramp it). Route each rowscroll RAM's CPU port (q0) into
// the data mux for its address region, else the read-back returns tile data /
// 0 and the accumulation never ramps (platform never sinks). The rs_*_we
// selects already encode the per-game rowscroll address decode.
assign pf0_dout = rs_fg_we   ? fg_rsq0   : rs_mg_we ? mg_rsq0 :
                  ( t0p2 ? t0p2_q : t0p1_q );

assign pf1_dout = rs_pf1b_we ? pf1b_rsq0 : rs_bg_we ? bg_rsq0 :
                  rs_fg_we   ? fg_rsq0   : rs_mg_we ? mg_rsq0 :  // darkseal: fg/mg rs under pf1_cs
                  ( t1p2 ? t1p2_q : t1p1_q );

// Tile-RAM write address: darkseal's 64x64 tilegen0 maps are 8kB (A[12:1]);
// cninja's 64x32 maps are 4kB (A[11:1], high bit 0). AW=12 fits both - 64x32
// just uses the low half.
wire [11:0] tile_wa = dseal ? cpu_addr[12:1] : { 1'b0, cpu_addr[11:1] };
wire [11:0] t0p1_vaddr, t0p2_vaddr, t1p1_vaddr, t1p2_vaddr;
wire [15:0] t0p1_vq, t0p2_vq, t1p1_vq, t1p2_vq;
// tilegen0 tile-size is per-playfield (deco16ic control[6]). cninja runs
// pf1=8x8 chars / pf2=16x16 tiles1; darkseal runs pf1=16x16 tiles1 / pf2=8x8
// chars (the intro story text is the 8x8 pf2, drawn FRONT). The two tilegen0
// engines below are wired by CAPABILITY - u_fg = 8x8/chars, u_mg = 16x16/tiles1
// - so for darkseal we route pf2 RAM+scroll to u_fg and pf1 RAM+scroll to u_mg.
wire [11:0] mg_vaddr, fg_vaddr;
assign t0p1_vaddr = dseal ? mg_vaddr : fg_vaddr;   // pf1 RAM read address
assign t0p2_vaddr = dseal ? fg_vaddr : mg_vaddr;   // pf2 RAM read address
jtframe_dual_ram16 #(.AW(12), .ENDIAN(1), .SIMFILE(SF_T0P1)) u_t0p1(
    .clk0(clk), .addr0(tile_wa), .data0(cpu_dout),
    .we0({2{t0p1 & wr}} & wmask), .q0(t0p1_q),
    .clk1(clk), .addr1(t0p1_vaddr), .data1(16'd0), .we1(2'b0), .q1(t0p1_vq));
jtframe_dual_ram16 #(.AW(12), .ENDIAN(1), .SIMFILE(SF_T0P2)) u_t0p2(
    .clk0(clk), .addr0(tile_wa), .data0(cpu_dout),
    .we0({2{t0p2 & wr}} & wmask), .q0(t0p2_q),
    .clk1(clk), .addr1(t0p2_vaddr), .data1(16'd0), .we1(2'b0), .q1(t0p2_vq));
jtframe_dual_ram16 #(.AW(12), .ENDIAN(1), .SIMFILE(SF_T1P1)) u_t1p1(
    .clk0(clk), .addr0(tile_wa), .data0(cpu_dout),
    .we0({2{t1p1 & wr}} & wmask), .q0(t1p1_q),
    .clk1(clk), .addr1(t1p1_vaddr), .data1(16'd0), .we1(2'b0), .q1(t1p1_vq));
jtframe_dual_ram16 #(.AW(12), .ENDIAN(1), .SIMFILE(SF_T1P2)) u_t1p2(
    .clk0(clk), .addr0(tile_wa), .data0(cpu_dout),
    .we0({2{t1p2 & wr}} & wmask), .q0(t1p2_q),
    .clk1(clk), .addr1(t1p2_vaddr), .data1(16'd0), .we1(2'b0), .q1(t1p2_vq));

// ---- sprite RAM : 0x1a4000-0x1a47ff (0x400 words). CPU r/w on port0.
// Double-buffered like the real buffered_spriteram16: a write to the sprite DMA
// flag (obj_copy, 0x1b4000) snapshots the CPU spriteram into u_objbuf, which the
// obj engine scans. Without it the engine reads the list mid-CPU-update and
// sprites tear / drop rows in motion (scene replay reads a static dump, so the
// bug only shows in live play). Copy via jtframe_bram_dma (karnov pattern):
// objdma_addr sweeps 0..0x3ff reading u_obj port1, writing u_objbuf port0.
wire [ 9:0] oram_vaddr;
wire [15:0] oram_vq;
wire [ 9:0] objdma_addr;
wire        objdma_we;
wire [15:0] oram_dmaq;       // word read from CPU spriteram during the copy
jtframe_dual_ram16 #(.AW(10), .ENDIAN(1)) u_obj(
    .clk0(clk), .addr0(cpu_addr[10:1]), .data0(cpu_dout),
    .we0({2{objram_cs & wr}} & wmask), .q0(obj_dout),
    .clk1(clk), .addr1(objdma_addr), .data1(16'd0), .we1(2'b0), .q1(oram_dmaq));

jtframe_bram_dma #(.AW(10)) u_objdma(
    .rst(rst), .clk(clk), .cen(pxl_cen),    // cen cannot be 1'b1
    .addr(objdma_addr), .start(obj_copy), .we(objdma_we));

// Display buffer the obj engine scans. SIMFILE lives HERE (not u_obj) so scene
// replay - which never strobes obj_copy - still preloads the engine-visible RAM.
jtframe_dual_ram16 #(.AW(10), .ENDIAN(1), .SIMFILE(SF_ORAM)) u_objbuf(
    .clk0(clk), .addr0(objdma_addr), .data0(oram_dmaq),
    .we0({2{objdma_we & pxl_cen}}), .q0(),
    .clk1(clk), .addr1(oram_vaddr), .data1(16'd0), .we1(2'b0), .q1(oram_vq));

// ---- tilegen0 pf control registers (scroll) ----
// pf2 scrollx=ctrl[3], scrolly=ctrl[4]; ctrl[5]=control0, ctrl[6]=control1
// (pf1 in low byte, pf2 in high byte)
reg [15:0] ctrl[0:7], ctrl1[0:7];
integer ci;
initial begin
    for(ci=0;ci<8;ci=ci+1) begin ctrl[ci]=0; ctrl1[ci]=0; end
`ifdef NOMAIN
    // Scene replay has no CPU to write the deco16ic control regs, so preload the
    // captured per-scene scroll/mode/bank from ctrl0.hex (tilegen0) + ctrl1.hex
    // (tilegen1), produced by rest2bin.sh.  Gives correct layer scroll positions.
    $readmemh("ctrl0.hex", ctrl);
    $readmemh("ctrl1.hex", ctrl1);
`endif
end
wire ctrl_cs  = pf0_cs & (dseal ? (cpu_addr[19:16]==4'ha)    // darkseal t0 ctrl 0x2a0000
                        : cbust ? cpu_addr[16]              // cbuster  t0 ctrl 0x0b5000
                        : supbt ? (~cpu_addr[17] & ~cpu_addr[18]) // supbtime t0 ctrl 0x300000
                        : vapor ? (cpu_addr[19:16]==4'hc)   // vapor    t0 ctrl 0x2c0000
                                : (cpu_addr[15:13]==3'b000));// cninja   t0 ctrl 0x14000x
wire ctrl1_cs = pf1_cs & (dseal ? (cpu_addr[19:16]==4'h4)    // darkseal t1 ctrl 0x240000
                        : cbust ? cpu_addr[16]              // cbuster  t1 ctrl 0x0b6000
                        : vapor ? (cpu_addr[19:16]==4'h4)   // vapor    t1 ctrl 0x240000
                                : (cpu_addr[15:13]==3'b000));// cninja   t1 ctrl 0x15000x
always @(posedge clk) begin
    if( ctrl_cs  & wr & wmask[0] ) ctrl [cpu_addr[3:1]] <= cpu_dout;
    if( ctrl1_cs & wr & wmask[0] ) ctrl1[cpu_addr[3:1]] <= cpu_dout;
end

// ---- row/column scroll (deco16ic control[5]=style, control[6]=enable) ----
// Per playfield, control0 = control[5] byte, control1 = control[6] byte (pf1 in
// the low byte, pf2 in the high byte). Mode: control1&0x60==0x40 rowscroll,
// ==0x20 colscroll. rowscroll style = control0[6:3]; colscroll style = control0[2:0]
// (columns = 8<<style px wide -> shift 3+style, index mask = (0x40>>style)-1).
// The code's pf1/pf2 use control[1]/[2] vs [3]/[4] scroll (header naming is swapped).
//   u_fg   = tg0 pf1 (cn) / tg0 pf2 (ds)   u_mg   = tg0 pf2 (cn) / tg0 pf1 (ds)
//   u_bg   = tg1 pf2                        u_pf1b = tg1 pf1
wire [7:0] fg_c0   = dseal ? ctrl [5][15:8] : ctrl [5][7:0];
wire [7:0] fg_c1   = dseal ? ctrl [6][15:8] : ctrl [6][7:0];
wire [7:0] mg_c0   = dseal ? ctrl [5][ 7:0] : ctrl [5][15:8];
wire [7:0] mg_c1   = dseal ? ctrl [6][ 7:0] : ctrl [6][15:8];
wire [7:0] bg_c0   = ctrl1[5][15:8];
wire [7:0] bg_c1   = ctrl1[6][15:8];
wire [7:0] pf1b_c0 = ctrl1[5][ 7:0];
wire [7:0] pf1b_c1 = ctrl1[6][ 7:0];

// ---- row/column scroll RAMs (one per engine; AW=11 covers darkseal's 2KW) ----
// cninja:  tg0 pf1 0x14c000 / pf2 0x14e000 ; tg1 pf1 0x15c000 / pf2 0x15e000
// darkseal: tg0 0x220000 (shared pf1+pf2) ; tg1 0x222000 (shared) - both via pf1_cs
wire [10:0] fg_rsa, mg_rsa, bg_rsa, pf1b_rsa;
wire [15:0] fg_rsq, mg_rsq, bg_rsq, pf1b_rsq;           // engine read (port 1)
wire [15:0] fg_rsq0, mg_rsq0, bg_rsq0, pf1b_rsq0;       // CPU read-back (port 0)
wire [10:0] rs_wa  = dseal ? cpu_addr[11:1] : { 1'b0, cpu_addr[10:1] };
// vaportra has NO rowscroll (screen_update calls pf_update(0,0)) -> gate all
// rowscroll selects off so they can't false-match a tilegen data write.
wire rs_fg_we   = vapor ? 1'b0 : dseal ? (pf1_cs & cpu_addr[19:16]==4'h2 & ~cpu_addr[13])
                : cbust ? (pf0_cs & ~cpu_addr[16] & cpu_addr[15:13]==3'b010)  // 0x0a4000
                        : (pf0_cs & cpu_addr[15:13]==3'b110);
wire rs_mg_we   = vapor ? 1'b0 : dseal ? (pf1_cs & cpu_addr[19:16]==4'h2 & ~cpu_addr[13])
                : cbust ? (pf0_cs & ~cpu_addr[16] & cpu_addr[15:13]==3'b011)  // 0x0a6000
                        : (pf0_cs & cpu_addr[15:13]==3'b111);
wire rs_bg_we   = vapor ? 1'b0 : dseal ? (pf1_cs & cpu_addr[19:16]==4'h2 &  cpu_addr[13])
                : cbust ? (pf1_cs & ~cpu_addr[16] & cpu_addr[15:13]==3'b111)  // 0x0ae000
                        : (pf1_cs & cpu_addr[15:13]==3'b111);
wire rs_pf1b_we = vapor ? 1'b0 : dseal ? (pf1_cs & cpu_addr[19:16]==4'h2 &  cpu_addr[13])
                : cbust ? (pf1_cs & ~cpu_addr[16] & cpu_addr[15:13]==3'b110)  // 0x0ac000
                        : (pf1_cs & cpu_addr[15:13]==3'b110);
jtframe_dual_ram16 #(.AW(11), .ENDIAN(1)) u_rs_fg(
    .clk0(clk), .addr0(rs_wa), .data0(cpu_dout), .we0({2{rs_fg_we & wr}} & wmask), .q0(fg_rsq0),
    .clk1(clk), .addr1(fg_rsa), .data1(16'd0), .we1(2'b0), .q1(fg_rsq));
jtframe_dual_ram16 #(.AW(11), .ENDIAN(1)) u_rs_mg(
    .clk0(clk), .addr0(rs_wa), .data0(cpu_dout), .we0({2{rs_mg_we & wr}} & wmask), .q0(mg_rsq0),
    .clk1(clk), .addr1(mg_rsa), .data1(16'd0), .we1(2'b0), .q1(mg_rsq));
jtframe_dual_ram16 #(.AW(11), .ENDIAN(1)) u_rs_bg(
    .clk0(clk), .addr0(rs_wa), .data0(cpu_dout), .we0({2{rs_bg_we & wr}} & wmask), .q0(bg_rsq0),
    .clk1(clk), .addr1(bg_rsa), .data1(16'd0), .we1(2'b0), .q1(bg_rsq));
jtframe_dual_ram16 #(.AW(11), .ENDIAN(1)) u_rs_pf1b(
    .clk0(clk), .addr0(rs_wa), .data0(cpu_dout), .we0({2{rs_pf1b_we & wr}} & wmask), .q0(pf1b_rsq0),
    .clk1(clk), .addr1(pf1b_rsa), .data1(16'd0), .we1(2'b0), .q1(pf1b_rsq));

// deco16ic tilegen1 bank callback (cninja_bank_callback): the high tile bit
// (0x1000) is set when the upper nibble of the per-pf bank-control byte is 0.
// control[7] low byte -> pf1 bank, high byte -> pf2 bank.
// cninja's tilegen1 uses a runtime bank callback (cninja_bank_callback) because
// its tiles2 ROM is 1MB (13-bit codes); the high code bit comes from ctrl1[7].
// Dark Seal has NO bank callback (darkseal.cpp) - fixed banks, 12-bit codes into
// a 512kB tiles2 - so the high bit must be 0, else rom_addr reads past the ROM
// (the "different tiles" + gappy render).
// cbuster bank callback ((bank&0x70)<<8) deferred: its tiles2 is 512kB (12-bit
// codes) so the high bit is 0 for a first render (like darkseal).
// vapor bank_callback = ((reg>>4)&7)*0x1000; tiles2 is 1MB (2 banks) so only the
// low bank bit is used. pf1 bank = ctrl1[7] low byte bit4; pf2 bank = high byte
// bit4 (=ctrl1[7][12]). m02100: ctrl1[7]=0x1101 -> bg needs bank 1, pf1b bank 0.
wire pf1b_bank = (dseal|cbust) ? 1'b0 : vapor ? ctrl1[7][ 4] : ~|ctrl1[7][ 7:4];
wire bg_bank   = (dseal|cbust) ? 1'b0 : vapor ? ctrl1[7][12] : ~|ctrl1[7][15:12];

// ---- background = tilegen1 pf2 (16x16 tiles2), opaque backdrop ----
wire [7:0]  bg_pxl;
wire        bg_romcs;
wire [19:2] bg_roma;
// supbtime has one tilegen fed by one 512KB ROM (mae02). mg(16x16) reads it via
// scr1(GFX2); the fg(8x8) needs it too but the char/GFX1 slot is only 128KB, so
// route the fg engine onto the (otherwise-unused) scr2 bus = mae02@GFX3.
assign scr2_cs   = supbt ? fg_romcs : bg_romcs;
assign scr2_addr = supbt ? fg_roma  : bg_roma;

// TEST: cninja tiles laid out row-major in SDRAM (L/R 8px halves adjacent) so the
// 2nd half-read is a 64-bit cache hit. Only cninja (game.v post_addr + this engine
// addr swap); darkseal/supbtime/cbuster stay half-major.
wire rowmajor = ~dseal & ~cbust & ~supbt & ~vapor;   // vapor download is half-major (identity)

jtcninja_deco16 u_bg(   // tilegen1 pf2 (64x32, 16x16 tiles2)
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen), .flip(flip),
    .fullheight(1'b0), .pswap(dseal), .rowmajor(rowmajor),
    .scrollx(ctrl1[3]), .scrolly(ctrl1[4]), .bank({2'd0,bg_bank}),
    .control0(bg_c0), .control1(bg_c1),
    .rsram_addr(bg_rsa), .rsram_data(bg_rsq),
    .vrender(vrender), .hdump(hdump_rd), .hs(HS),
    .ram_addr(t1p2_vaddr), .ram_data(t1p2_vq),
    .rom_cs(bg_romcs), .rom_addr(bg_roma), .rom_data(scr2_data), .rom_ok(scr2_ok),
    .pxl(bg_pxl)
);

// ---- pf1b = tilegen1 pf1 (16x16, shares tiles2 ROM), col bank 0x00 -> pal 0x200
//      a detail/foreground tilemap (palms, foliage). Transparent on pen 0. ----
wire [7:0]  pf1b_pxl;
wire        pf1b_romcs;
wire [19:2] pf1b_roma;
assign scr3_cs   = pf1b_romcs;
assign scr3_addr = pf1b_roma;

jtcninja_deco16 u_pf1b(   // tilegen1 pf1 (64x32, 16x16) - cninja foliage (colscroll)
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen), .flip(flip),
    .fullheight(1'b0), .pswap(dseal), .rowmajor(rowmajor),
    .scrollx(ctrl1[1]), .scrolly(ctrl1[2]), .bank({2'd0,pf1b_bank}),
    .control0(pf1b_c0), .control1(pf1b_c1),
    .rsram_addr(pf1b_rsa), .rsram_data(pf1b_rsq),
    .vrender(vrender), .hdump(hdump_rd), .hs(HS),
    .ram_addr(t1p1_vaddr), .ram_data(t1p1_vq),
    .rom_cs(pf1b_romcs), .rom_addr(pf1b_roma), .rom_data(scr3_data), .rom_ok(scr3_ok),
    .pxl(pf1b_pxl)
);

// ---- midground = tilegen0 pf2 (16x16 tiles1), transparent on pen 0 ----
wire [7:0]  mg_pxl;
wire        mg_romcs;
wire [19:2] mg_roma;
assign scr1_cs   = mg_romcs;
assign scr1_addr = mg_roma[18:2];   // tiles1 512kB; tilegen0 has no bank cb (bit19=0)

jtcninja_deco16 u_mg(   // tilegen0: cninja pf2 (64x32 16x16) / darkseal pf1 (64x64 16x16)
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen), .flip(flip),
    .fullheight(dseal), .pswap(dseal), .rowmajor(rowmajor),   // darkseal tg0 = DECO_64x64
    .scrollx(dseal?ctrl[1]:ctrl[3]), .scrolly(dseal?ctrl[2]:ctrl[4]), .bank(3'd0),
    .control0(mg_c0), .control1(mg_c1),
    .rsram_addr(mg_rsa), .rsram_data(mg_rsq),
    .vrender(vrender), .hdump(hdump_rd), .hs(HS),
    .ram_addr(mg_vaddr), .ram_data(dseal?t0p1_vq:t0p2_vq),
    .rom_cs(mg_romcs), .rom_addr(mg_roma), .rom_data(scr1_data), .rom_ok(scr1_ok),
    .pxl(mg_pxl)
);

// ---- foreground = tilegen0 pf1 (8x8 chars), transparent on pen 0 ----
wire [7:0]  fg_pxl;
wire        fg_romcs;
wire [19:2] fg_roma;
// vaportra fg (tilegen0 pf1, 8x8) reads its 8x8 chars from the char ROM region
// (GFX1), same bus cninja/darkseal use - vaportra loads a char-major copy there.
assign char_cs   = supbt ? 1'b0 : fg_romcs;   // supbtime fg reads scr2, not char
assign char_addr = fg_roma[16:2];   // chars 128kB (8x8)

jtcninja_deco16 u_fg(   // tilegen0: cninja pf1 (8x8 chars) / darkseal pf2 (8x8 text)
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen), .flip(flip),
    .fullheight(dseal), .pswap(dseal | vapor), .rowmajor(1'b0),   // darkseal tg0 = 64x64 (chars 8x8: no L/R half)
    .scrollx(dseal?ctrl[3]:ctrl[1]), .scrolly(dseal?ctrl[4]:ctrl[2]), .bank(3'd0),
    .control0(fg_c0), .control1(fg_c1),
    .rsram_addr(fg_rsa), .rsram_data(fg_rsq),
    .vrender(vrender), .hdump(hdump_rd), .hs(HS),
    .ram_addr(fg_vaddr), .ram_data(dseal?t0p2_vq:t0p1_vq),
    .rom_cs(fg_romcs), .rom_addr(fg_roma),
    .rom_data(supbt ? scr2_data : char_data), .rom_ok(supbt ? scr2_ok : char_ok),
    .pxl(fg_pxl)
);

// ---- sprites = decospr (MXC-06). Pen = 0x300 + colour*16 + pixel. ----
wire [11:0] obj_pxl;   // {epri, pri[1:0], colour[4:0], pixel[3:0]}
jtcninja_obj u_obj_eng(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen), .flip(flip), .dseal(dseal), .cbust(cbust),
    .HS(HS), .LHBL(LHBL), .LVBL(LVBL), .vrender(vrender), .hdump(hdump_rd),
    .oram_addr(oram_vaddr), .oram_dout(oram_vq),
    .rom_cs(obj_cs), .rom_addr(obj_addr), .rom_data(obj_data), .rom_ok(obj_ok),
    .pxl(obj_pxl)
);

// ---- colmix: priority composite of the 4 playfields + sprites, palette
//      (xBGR_888) -> RGB. Palette RAM (u_pal) stays here; colmix drives its
//      read port (palrd_a / pal_vq). ----
jtcninja_colmix u_colmix(
    .clk     ( clk      ),
    .pxl_cen ( pxl_cen  ),
    .dseal   ( dseal    ),
    .cbust   ( cbust    ),
    .cbpri   ( cbpri    ),
    .supbt   ( supbt    ),
    .vapor   ( vapor    ),
    .hdump   ( hdump_rd ),
    .LHBL    ( LHBL     ),
    .LVBL    ( LVBL     ),
    .fg_pxl  ( fg_pxl   ),
    .mg_pxl  ( mg_pxl   ),
    .bg_pxl  ( bg_pxl   ),
    .pf1b_pxl( pf1b_pxl ),
    .obj_pxl ( obj_pxl  ),
    .pal_addr( palrd_a  ),
    .pal_data( pal_vq   ),
    .red     ( red      ),
    .green   ( green    ),
    .blue    ( blue     )
);

endmodule
