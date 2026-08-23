/*  This file is part of JTCORES. GPLv3. See jtcninja_game.v header.

    Video subsystem for the Data East 16-bit family (cninja.cpp and friends).

    Board-level parts live here: palette RAM, sprite RAM + its display buffer,
    the four row/column scroll tables, video timing, and the per-game address
    decoding. The two tile generators are jtcninja_deco16ic instances, which
    own their own playfield RAM and control registers (see that file).

    Layer naming. The chips expose pf1/pf2; which one is the 8x8 text layer is
    per game, so the routing sits at the bottom of this file:
        u_tg0 (pf0_cs)  cninja/cbuster/vaportra: pf1=fg (8x8)  pf2=mg (16x16)
                        darkseal:                pf1=mg        pf2=fg
        u_tg1 (pf1_cs)  all games:               pf1=pf1b      pf2=bg
    Palette is xBGR_888 (2 words/colour) on cninja - see jtcninja_colmix.
*/
module jtcninja_video(
    input             rst,
    input             clk,
    input             pxl2_cen,
    input             pxl_cen,
    input      [ 3:0] gfx_en,
    output            flip,
    // Board select, one boolean per game (MRA header -> jtcninja_header). The
    // tilegen data/control/rowscroll regions are exploded across the map on some
    // boards, so cpu_addr is widened to [19:1].
    input             dseal,
    input             cbust,
    input             vapor,
    input             cninja,
    input             cbpri,        // cbuster TC-4 layer priority (m_pri)
    input      [15:0] vprio0,       // vaportra m_priority[0]: playfield draw order
    input      [15:0] vprio1,       // vaportra m_priority[1]: sprite-behind-fg threshold
    // CPU interface
    input      [19:1] cpu_addr,
    input      [15:0] cpu_dout,
    input      [ 1:0] cpu_dsn,
    input             cpu_rnw,
    input             pf0_cs,
    input             pf1_cs,
    output     [15:0] pf0_dout,
    output     [15:0] pf1_dout,
    input             obj_copy,
    // sprite RAM lives in mem.yaml (bram: objram + oram); the engine reads the
    // display buffer and drives the DMA sweep that refreshes it
    output     [10:1] oram_addr,
    input      [15:0] oram_dout,
    output     [10:1] dma_addr,
    output     [ 1:0] dma_we,
    input             pal_cs,
    output     [12:1] palrw_addr,
    output     [ 1:0] palrw_we,
    // palette BRAM read port (jtcninja_colmix drives the address)
    output     [12:1] pal_addr,
    input      [15:0] pal_dout,
    // Vertical position (for deco_irq raster/vblank in main)
    output     [ 8:0] vdump,
    // Video output
    output            HS,
    output            VS,
    output            LHBL,
    output            LVBL,
    output     [`JTFRAME_COLORW-1:0] red,
    output     [`JTFRAME_COLORW-1:0] green,
    output     [`JTFRAME_COLORW-1:0] blue,
    // Char ROM
    output            char_cs,
    output     [16:2] char_addr,
    input      [31:0] char_data,
    input             char_ok,
    // Tile ROM 1 (tiles1)
    output            scr1_cs,
    output     [18:2] scr1_addr,
    input      [31:0] scr1_data,
    input             scr1_ok,
    // Tile ROM 2 (tiles2, copy 1)
    output            scr2_cs,
    output     [19:2] scr2_addr,
    input      [31:0] scr2_data,
    input             scr2_ok,
    // Tile ROM 2 (copy 2) - the second tiles2 reader
    output            scr3_cs,
    output     [19:2] scr3_addr,
    input      [31:0] scr3_data,
    input             scr3_ok,
    // Sprite ROM
    output            obj_cs,
    output     [20:2] obj_addr,
    input      [31:0] obj_data,
    input             obj_ok,
    // deco16ic register dump / peek. Bit 4 picks the tile generator.
    input      [ 4:0] ioctl_addr,
    output     [ 7:0] ioctl_din,
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

assign flip = 1'b0;     // TODO: from deco16ic control register

// ---------------------------------------------------------------------------
// Video timing
// ---------------------------------------------------------------------------
wire [8:0] hdump, vrender;
wire       pre_LHBL, pre_LVBL;   // vtimer blanking, before the colmix blank delay
// Horizontal alignment: read the line buffers HOFFSET px ahead to compensate the
// line-buffer -> colmix -> palette -> blank pipeline. jtframe_blank DLY=1 registers
// rgb_out, and its delayed LHBL/LVBL drive the core outputs, so picture and window
// move together and HOFFSET stays 0.
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
    .LHBL     ( pre_LHBL),
    .LVBL     ( pre_LVBL),
    .HS       ( HS      ),
    .VS       ( VS      )
);

// ---------------------------------------------------------------------------
// Scene replay (NOMAIN): `jtsim -s <scene>` renders with the CPU tied off, so
// every piece of video state has to come from the captured scene. rest2bin.sh
// splits dump.bin into the .bin images below; the deco16ic control registers
// are read straight out of rest.bin by their MMR block at these offsets.
// Empty / zero in normal runs. See ver/cninja/README.md for the dump layout.
// ---------------------------------------------------------------------------
`ifdef NOMAIN
localparam SF_T0P1="t0p1.bin", SF_T0P2="t0p2.bin", SF_RS0="rs0.bin",
           SF_T1P1="t1p1.bin", SF_T1P2="t1p2.bin", SF_RS1="rs1.bin";
`else
localparam SF_T0P1="", SF_T0P2="", SF_RS0="",
           SF_T1P1="", SF_T1P2="", SF_RS1="";
`endif
localparam MMR_TG0=0, MMR_TG1=16;   // rest.bin offsets, 16 bytes each

wire       wr    = ~cpu_rnw;
wire [1:0] wmask = ~cpu_dsn;

// ---------------------------------------------------------------------------
// Per-game address decode
//
// cninja  : each tilegen packed in a 64kB window, sub-decoded by A[15:13]:
//           pf1 data @010, pf2 data @011, control @000, rowscroll @110/111
// darkseal: exploded, sub-decoded by A[19:16]+A[13]. ONE rowscroll table per
//           chip, shared by both playfields (0x220000 tg0 / 0x222000 tg1).
// cbuster : data 0x0a0000-0x0affff (A[16]=0) + control 0x0b5000/0x0b6000
//           (A[16]=1); within the data window A[15:13] picks pf/rowscroll.
// vaportra: tg0 pf1 0x280000 pf2 0x282000 ctrl 0x2c0000
//           tg1 pf1 0x200000 pf2 0x202000 ctrl 0x240000; NO rowscroll.
// ---------------------------------------------------------------------------
wire t0p1_cs = pf0_cs & (dseal ? (cpu_addr[19:16]==4'h6 & ~cpu_addr[13]) :
                         cbust ? (~cpu_addr[16] & cpu_addr[15:13]==3'b000) :
                         vapor ? (cpu_addr[19:16]==4'h8 & ~cpu_addr[13]) :
                                 (cpu_addr[15:13]==3'b010));
wire t0p2_cs = pf0_cs & (dseal ? (cpu_addr[19:16]==4'h6 &  cpu_addr[13]) :
                         cbust ? (~cpu_addr[16] & cpu_addr[15:13]==3'b001) :
                         vapor ? (cpu_addr[19:16]==4'h8 &  cpu_addr[13]) :
                                 (cpu_addr[15:13]==3'b011));
wire t1p1_cs = pf1_cs & (dseal ? (cpu_addr[19:16]==4'h0 & ~cpu_addr[13]) :
                         cbust ? (~cpu_addr[16] & cpu_addr[15:13]==3'b100) :
                         vapor ? (cpu_addr[19:16]==4'h0 & ~cpu_addr[13]) :
                                 (cpu_addr[15:13]==3'b010));
wire t1p2_cs = pf1_cs & (dseal ? (cpu_addr[19:16]==4'h0 &  cpu_addr[13]) :
                         cbust ? (~cpu_addr[16] & cpu_addr[15:13]==3'b101) :
                         vapor ? (cpu_addr[19:16]==4'h0 &  cpu_addr[13]) :
                                 (cpu_addr[15:13]==3'b011));

wire ctl0_cs = pf0_cs & (dseal ? (cpu_addr[19:16]==4'ha)     // 0x2a0000
                       : cbust ? cpu_addr[16]                // 0x0b5000
                       : vapor ? (cpu_addr[19:16]==4'hc)     // 0x2c0000
                               : (cpu_addr[15:13]==3'b000)); // 0x14000x
wire ctl1_cs = pf1_cs & (dseal ? (cpu_addr[19:16]==4'h4)     // 0x240000
                       : cbust ? cpu_addr[16]                // 0x0b6000
                       : vapor ? (cpu_addr[19:16]==4'h4)     // 0x240000
                               : (cpu_addr[15:13]==3'b000)); // 0x15000x

// Row/column scroll selects, named by chip+playfield. vaportra calls
// pf_update(0,0) - no rowscroll - so gate them off, else they false-match a
// tilegen data write. darkseal's two playfields share one table per chip.
wire rs_t0p1_we = vapor ? 1'b0 : dseal ? (pf1_cs & cpu_addr[19:16]==4'h2 & ~cpu_addr[13])
                : cbust ? (pf0_cs & ~cpu_addr[16] & cpu_addr[15:13]==3'b010)  // 0x0a4000
                        : (pf0_cs & cpu_addr[15:13]==3'b110);                 // 0x14c000
wire rs_t0p2_we = vapor ? 1'b0 : dseal ? (pf1_cs & cpu_addr[19:16]==4'h2 & ~cpu_addr[13])
                : cbust ? (pf0_cs & ~cpu_addr[16] & cpu_addr[15:13]==3'b011)  // 0x0a6000
                        : (pf0_cs & cpu_addr[15:13]==3'b111);                 // 0x14e000
wire rs_t1p1_we = vapor ? 1'b0 : dseal ? (pf1_cs & cpu_addr[19:16]==4'h2 &  cpu_addr[13])
                : cbust ? (pf1_cs & ~cpu_addr[16] & cpu_addr[15:13]==3'b110)  // 0x0ac000
                        : (pf1_cs & cpu_addr[15:13]==3'b110);                 // 0x15c000
wire rs_t1p2_we = vapor ? 1'b0 : dseal ? (pf1_cs & cpu_addr[19:16]==4'h2 &  cpu_addr[13])
                : cbust ? (pf1_cs & ~cpu_addr[16] & cpu_addr[15:13]==3'b111)  // 0x0ae000
                        : (pf1_cs & cpu_addr[15:13]==3'b111);                 // 0x15e000

// Tile-RAM write offset: darkseal's 64x64 maps are 8kB (A[12:1]); the 64x32
// maps are 4kB (A[11:1]). AW=12 fits both - 64x32 uses the low half.
wire [11:0] tile_wa = dseal ? cpu_addr[12:1] : { 1'b0, cpu_addr[11:1] };

// ---------------------------------------------------------------------------
// Palette RAM lives in mem.yaml (bram: pal). Only the CPU-side address decode
// is board work: vaportra splits GR @0x300000 / B @0x304000 on byte-addr bit14
// (-> RAM bit 11) with the colour index in [11:1]; cninja packs 2 words per
// colour and darkseal/cbuster split on bit 12.
// ---------------------------------------------------------------------------
assign palrw_addr = vapor ? {cpu_addr[14], cpu_addr[11:1]} : cpu_addr[12:1];
assign palrw_we   = {2{pal_cs & wr}} & wmask;

// ---------------------------------------------------------------------------
// Row/column scroll tables. Board RAM (the driver's m_pf_rowscroll), read+write:
// the CPU reads back the accumulated value (cninja's boss-sink colscroll does
// `add.w (A4),D0` to ramp it), so q0 feeds the pf*_dout muxes below.
// ---------------------------------------------------------------------------
// One table per chip now lives inside jtcninja_deco16ic; the board only decodes
// the window. cninja/cbuster keep two distinct tables 0x2000 apart (A[13] picks
// the playfield's half); darkseal has a single shared table per chip.
wire [15:0] rs0_dout, rs1_dout;
wire [10:0] rs_wa = dseal ? cpu_addr[11:1] : { cpu_addr[13], cpu_addr[10:1] };
wire        rs0_we = rs_t0p1_we | rs_t0p2_we;
wire        rs1_we = rs_t1p1_we | rs_t1p2_we;

// ---------------------------------------------------------------------------
// The two tile generators
// ---------------------------------------------------------------------------
// gfx packing, per playfield (a download property, see game.v post_addr):
// tiles laid out row-major only for cninja; the 8x8 char layer is never
// row-major (no L/R half). pswap follows the RGN_FRAC plane-pair order.
wire rowmajor = cninja;

wire [15:0] tg0_bank, tg1_bank;
// deco16ic bank callback (driver-provided in MAME). cninja's tilegen1 needs it
// because its tiles2 ROM is 1MB (13-bit codes): cninja_bank_callback sets the
// high bit when the upper nibble of the per-pf bank byte is 0. darkseal/cbuster
// have 512kB tiles2 (12-bit codes) so the bit must stay 0, else rom_addr reads
// past the ROM. vaportra: ((reg>>4)&7)*0x1000, 1MB -> only the low bank bit.
wire t1p1_bank = (dseal|cbust) ? 1'b0 : vapor ? tg1_bank[ 4] : ~|tg1_bank[ 7:4];
wire t1p2_bank = (dseal|cbust) ? 1'b0 : vapor ? tg1_bank[12] : ~|tg1_bank[15:12];

wire [15:0] t0p1_dout, t0p2_dout, t1p1_dout, t1p2_dout;
wire [ 7:0] t0p1_pxl,  t0p2_pxl,  t1p1_pxl,  t1p2_pxl;
wire        t0p1_romcs, t0p2_romcs, t1p1_romcs, t1p2_romcs;
wire [19:2] t0p1_roma,  t0p2_roma,  t1p1_roma,  t1p2_roma;
wire [31:0] t0p1_romdata, t0p2_romdata;
wire        t0p1_romok,   t0p2_romok;

wire [ 7:0] tg0_iodin, tg1_iodin, tg0_st, tg1_st;
assign ioctl_din = ioctl_addr[4] ? tg1_iodin : tg0_iodin;
assign st_dout   = debug_bus[4]  ? tg1_st    : tg0_st;

jtcninja_deco16ic #(.SIMFILE1(SF_T0P1), .SIMFILE2(SF_T0P2), .SIMFILRS(SF_RS0),
                   .MMRSEEK(MMR_TG0)) u_tg0(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen), .hs(HS),
    .vrender(vrender), .hdump(hdump_rd), .flip(flip),
    .fullheight ( dseal      ),          // darkseal tg0 = DECO_64x64
    .cpu_addr   ( tile_wa    ),
    .cpu_dout   ( cpu_dout   ),
    .pf1_we     ( {2{t0p1_cs & wr}} & wmask ),
    .pf2_we     ( {2{t0p2_cs & wr}} & wmask ),
    .ctrl_addr  ( cpu_addr[3:1] ),
    .ctrl_cs    ( ctl0_cs    ),
    .cpu_rnw    ( cpu_rnw    ),
    .cpu_dsn    ( cpu_dsn    ),
    .pf1_dout   ( t0p1_dout  ),
    .pf2_dout   ( t0p2_dout  ),
    .bank_ctl   ( tg0_bank   ),
    // pf1 is the 8x8 char layer except on darkseal, where pf1/pf2 swap roles
    .pf1_pswap  ( dseal | vapor ),
    .pf2_pswap  ( dseal | vapor ),
    .pf1_rowmajor( 1'b0      ),
    .pf2_rowmajor( rowmajor  ),
    .pf1_bank   ( vapor ? tg0_bank[ 6: 4] : 3'd0 ),
    .pf2_bank   ( vapor ? tg0_bank[14:12] : 3'd0 ),
    .rs_split   ( ~dseal     ),
    .rs_addr    ( rs_wa      ),
    .rs_we      ( {2{rs0_we & wr}} & wmask ),
    .rs_dout    ( rs0_dout   ),
    .pf1_pxl    ( t0p1_pxl   ),
    .pf2_pxl    ( t0p2_pxl   ),
    .pf1_romcs  ( t0p1_romcs ),
    .pf1_roma   ( t0p1_roma  ),
    .pf1_romdata( t0p1_romdata ),
    .pf1_romok  ( t0p1_romok ),
    .pf2_romcs  ( t0p2_romcs ),
    .pf2_roma   ( t0p2_roma  ),
    .pf2_romdata( t0p2_romdata ),
    .pf2_romok  ( t0p2_romok ),
    .ioctl_addr ( ioctl_addr[3:0] ),
    .ioctl_din  ( tg0_iodin  ),
    .debug_bus  ( debug_bus  ),
    .st_dout    ( tg0_st     )
);

jtcninja_deco16ic #(.SIMFILE1(SF_T1P1), .SIMFILE2(SF_T1P2), .SIMFILRS(SF_RS1),
                   .MMRSEEK(MMR_TG1)) u_tg1(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen), .hs(HS),
    .vrender(vrender), .hdump(hdump_rd), .flip(flip),
    .fullheight ( 1'b0       ),
    .cpu_addr   ( tile_wa    ),
    .cpu_dout   ( cpu_dout   ),
    .pf1_we     ( {2{t1p1_cs & wr}} & wmask ),
    .pf2_we     ( {2{t1p2_cs & wr}} & wmask ),
    .ctrl_addr  ( cpu_addr[3:1] ),
    .ctrl_cs    ( ctl1_cs    ),
    .cpu_rnw    ( cpu_rnw    ),
    .cpu_dsn    ( cpu_dsn    ),
    .pf1_dout   ( t1p1_dout  ),
    .pf2_dout   ( t1p2_dout  ),
    .bank_ctl   ( tg1_bank   ),
    .pf1_pswap  ( dseal | vapor ),
    .pf2_pswap  ( dseal | vapor ),
    .pf1_rowmajor( rowmajor  ),
    .pf2_rowmajor( rowmajor  ),
    .pf1_bank   ( vapor ? tg1_bank[ 6: 4] : {2'd0, t1p1_bank} ),
    .pf2_bank   ( vapor ? tg1_bank[14:12] : {2'd0, t1p2_bank} ),
    .rs_split   ( ~dseal     ),
    .rs_addr    ( rs_wa      ),
    .rs_we      ( {2{rs1_we & wr}} & wmask ),
    .rs_dout    ( rs1_dout   ),
    .pf1_pxl    ( t1p1_pxl   ),
    .pf2_pxl    ( t1p2_pxl   ),
    .pf1_romcs  ( t1p1_romcs ),
    .pf1_roma   ( t1p1_roma  ),
    .pf1_romdata( scr3_data  ),
    .pf1_romok  ( scr3_ok    ),
    .pf2_romcs  ( t1p2_romcs ),
    .pf2_roma   ( t1p2_roma  ),
    .pf2_romdata( scr2_data  ),
    .pf2_romok  ( scr2_ok    ),
    .ioctl_addr ( ioctl_addr[3:0] ),
    .ioctl_din  ( tg1_iodin  ),
    .debug_bus  ( debug_bus  ),
    .st_dout    ( tg1_st     )
);

// CPU read-back. The rowscroll tables answer for their own address windows
// (see the accumulate note above); otherwise the playfield RAM does.
assign pf0_dout = rs0_we ? rs0_dout : ( t0p2_cs ? t0p2_dout : t0p1_dout );
assign pf1_dout = rs1_we ? rs1_dout : rs0_we ? rs0_dout :   // darkseal: tg0 rs under pf1_cs
                  ( t1p2_cs ? t1p2_dout : t1p1_dout );

// ---------------------------------------------------------------------------
// Layer routing: chip playfields -> named layers + gfx ROM buses.
//   fg   = 8x8 text     (char ROM)     mg   = 16x16 tiles1 (scr1)
//   pf1b = 16x16 tiles2 (scr3)         bg   = 16x16 tiles2 (scr2), backdrop
// darkseal runs tilegen0 with pf1=16x16 and pf2=8x8, the other way round.
// ---------------------------------------------------------------------------
wire [7:0] fg_pxl   = dseal ? t0p2_pxl : t0p1_pxl;
wire [7:0] mg_pxl   = dseal ? t0p1_pxl : t0p2_pxl;
wire [7:0] pf1b_pxl = t1p1_pxl;
wire [7:0] bg_pxl   = t1p2_pxl;

wire [19:2] fg_roma = dseal ? t0p2_roma : t0p1_roma;
wire [19:2] mg_roma = dseal ? t0p1_roma : t0p2_roma;
assign char_cs   = dseal ? t0p2_romcs : t0p1_romcs;
assign char_addr = fg_roma[16:2];   // chars 128kB
assign scr1_cs   = dseal ? t0p1_romcs : t0p2_romcs;
assign scr1_addr = mg_roma[18:2];   // tiles1 512kB
assign scr3_cs   = t1p1_romcs;
assign scr3_addr = t1p1_roma;
assign scr2_cs   = t1p2_romcs;
assign scr2_addr = t1p2_roma;

assign t0p1_romdata = dseal ? scr1_data : char_data;
assign t0p1_romok   = dseal ? scr1_ok   : char_ok;
assign t0p2_romdata = dseal ? char_data : scr1_data;
assign t0p2_romok   = dseal ? char_ok   : scr1_ok;

// ---------------------------------------------------------------------------
// Sprites (MXC-06) and the colour mixer
// ---------------------------------------------------------------------------
// cninja / cbuster / darkseal use decospr (DECO 52). vaportra uses the MXC-06
// instead (vaportra.cpp: "same as Bad Dudes") - a different chip with a different
// sprite word format, vendored from cores/cop as jtcninja_mxc06 with the dec0
// seallayout plane order. Both scan the same display buffer and share the obj ROM
// bus; jtcninja_obj stays instantiated either way because it owns the DMA sweep.
wire [11:0] obj_pxl, cn_pxl;
wire [ 9:0] cn_oaddr, vp_oaddr;
wire        cn_romcs, vp_romcs;
wire [20:2] cn_roma;
wire [18:1] vp_roma;   // MXC-06: {code[12:0], half, row} - 13-bit code (1MB sprite ROM)
wire [ 7:0] vp_pxl;    // MXC-06 pen = {pal[3:0], pixel[3:0]}

assign oram_addr = vapor ? vp_oaddr : cn_oaddr;
assign obj_cs    = vapor ? vp_romcs : cn_romcs;
assign obj_addr  = vapor ? { 1'd0, vp_roma } : cn_roma;
// colmix adds vaportra's 0x100 sprite base itself, so pass the raw pen
assign obj_pxl   = vapor ? { 4'd0, vp_pxl } : cn_pxl;

jtcninja_obj u_obj_eng(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen), .flip(flip), .dseal(dseal), .cbust(cbust),
    .HS(HS), .LHBL(pre_LHBL), .LVBL(pre_LVBL), .vrender(vrender), .hdump(hdump_rd),
    .obj_copy(obj_copy), .oram_addr(cn_oaddr), .oram_dout(oram_dout),
    .dma_addr(dma_addr), .dma_we(dma_we),
    .rom_cs(cn_romcs), .rom_addr(cn_roma), .rom_data(obj_data), .rom_ok(obj_ok),
    .pxl(cn_pxl)
);

jtcninja_mxc06 u_obj_mxc(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen),
    .HS(HS), .LHBL(pre_LHBL), .LVBL(pre_LVBL), .flip(flip),
    .hdump(hdump_rd), .vrender(vrender),
    .tbl_addr(vp_oaddr), .tbl_dout(oram_dout),
    .rom_cs(vp_romcs), .rom_addr(vp_roma), .rom_data(obj_data), .rom_ok(obj_ok),
    .pxl(vp_pxl)
);

jtcninja_colmix u_colmix(
    .clk     ( clk      ),
    .pxl_cen ( pxl_cen  ),
    .dseal   ( dseal    ),
    .cbust   ( cbust    ),
    .cbpri   ( cbpri    ),
    .vprio0  ( vprio0   ),
    .vprio1  ( vprio1   ),
    .vapor   ( vapor    ),
    .LHBL    ( pre_LHBL ),
    .LVBL    ( pre_LVBL ),
    .LHBL_o  ( LHBL     ),
    .LVBL_o  ( LVBL     ),
    .fg_pxl  ( fg_pxl   ),
    .mg_pxl  ( mg_pxl   ),
    .bg_pxl  ( bg_pxl   ),
    .pf1b_pxl( pf1b_pxl ),
    .obj_pxl ( obj_pxl  ),
    .pal_addr( pal_addr ),
    .pal_data( pal_dout ),
    .red     ( red      ),
    .green   ( green    ),
    .blue    ( blue     )
);

endmodule
