/*  This file is part of JTCORES. GPLv3. See jtosman_game.v header.
    Author: Andrea Bogazzi.

    Osman video. Data East Simple 156: one DECO16IC tilegen (pf1+pf2, via 2x
    jtcninja_deco16 imported from cninja) + chip-52 sprites (jtcninja_decospr, TODO)
    + colmix (xBGR555). Palette / pf name / sprite / rowscroll RAM are BRAM here.
    The DE156 ARM addresses these 16-bit devices at 32-bit (4-byte) spacing, so the
    CPU index is cpu_addr[N:2].
    TODO: deco56 tile decrypt (jtosman_gfxdec) + tiles ROM_CONTINUE/plane MRA — the
    gfx is fed raw for now (tiles show layout/scroll but wrong pixels), and sprites.
*/
module jtosman_video(
    input             rst,
    input             clk,
    input             pxl2_cen,
    input             pxl_cen,
    input    [ 3:0]   gfx_en,
    input             flip,
    input             tile1mb,  // header: 1MB tile region for the decrypt fetch
    input             pal888,   // header: xBGR888 32-bit palette (hvysmsh)

    // CPU interface
    input    [16:1]   cpu_addr,
    input    [15:0]   cpu_dout,
    input             cpu_rnw,
    input    [ 1:0]   dsn,
    input             pf_cs,
    input             pfram_cs,
    input             obj_copy,
    output   [15:0]   pf_dout,
    // board BRAMs live in mem.yaml; the engines only drive the read buses
    output   [ 9:0]   pal_rd,
    input    [15:0]   pal_dout,     // low half (xBGR555 / RG of xBGR888)
    input    [15:0]   palh_dout,    // high half (B of xBGR888)
    output   [10:0]   obj_oaddr,
    input    [15:0]   oram_dout,
    output   [10:0]   pf1_rsa,
    input    [15:0]   rs1_dout,
    output   [10:0]   pf2_rsa,
    input    [15:0]   rs2_dout,

    // tile gfx ROM (BA1, 16-bit, deco56-encrypted; jtosman_gfxdec decrypts at fetch)
    output            gfx1a_cs,
    output   [20:1]   gfx1a_addr,
    input    [15:0]   gfx1a_data,
    input             gfx1a_ok,
    output            gfx1b_cs,
    output   [20:1]   gfx1b_addr,
    input    [15:0]   gfx1b_data,
    input             gfx1b_ok,
    output            gfx1c_cs,
    output   [20:1]   gfx1c_addr,
    input    [15:0]   gfx1c_data,
    input             gfx1c_ok,
    output            gfx1d_cs,
    output   [20:1]   gfx1d_addr,
    input    [15:0]   gfx1d_data,
    input             gfx1d_ok,

    // sprite gfx ROM (BA3)
    output            obj_cs,
    output   [22:2]   obj_addr,
    input    [31:0]   obj_data,
    input             obj_ok,

    output   [ 8:0]   vdump,
    output            HS,
    output            VS,
    output            LHBL,
    output            LVBL,
    output   [ 7:0]   red,
    output   [ 7:0]   green,
    output   [ 7:0]   blue
);

wire        wr    = ~cpu_rnw;
wire [ 1:0] wmask = ~dsn;
wire [ 8:0] hdump, vrender;


// ---- timing: 320x240 from nslasher's set_raw(28MHz/4, 442, 0, 320, 274, 8, 248)
//      (fghthist.cpp; same DECO video chips): 7 MHz dot clock, htotal 442, vtotal 274
//      -> H=15.84 kHz, 57.79 Hz. HS placed as in cninja (same 274-line house grid). ----
jtframe_vtimer #(
    .VB_START ( 9'd247 ), .VB_END( 9'd7 ), .VCNT_END( 9'd273 ), .VS_START( 9'd254 ),
    .HB_START ( 9'd319 ), .HB_END( 9'd441 ), .HS_START( 9'd364 ), .HINIT( 9'd319 )
) u_vtimer(
    .clk( clk ), .pxl_cen( pxl_cen ),
    .vdump( vdump ), .vrender( vrender ), .vrender1(),
    .H( hdump ), .Hinit(), .Vinit(),
    .LHBL( LHBL ), .LVBL( LVBL ), .HS( HS ), .VS( VS )
);

// ---- deco16ic control registers : 8 x 16-bit (4-byte spaced), cfg/mmr.yaml ----
// pf1: scrollx=r1 scrolly=r2 c0=r5[7:0] c1=r6[7:0] bank=(r7[7:0]>>4)&7
// pf2: scrollx=r3 scrolly=r4 c0=r5[15:8] c1=r6[15:8] bank=(r7[15:8]>>4)&7  (simpl156 bank_cb)
// NOMAIN scene replay restores them from rest.bin @SEEK 0 (jtdeco16ic_mmr), like cninja.
`ifdef SIMSCENE   // scene replay: preload the video BRAMs from the captured dump
localparam PF1_F="pf1.bin", PF2_F="pf2.bin";    // deco16ic-internal name tables
`else
localparam PF1_F="", PF2_F="";
`endif

wire [15:0] pf1_scrollx, pf1_scrolly, pf2_scrollx, pf2_scrolly, bank_ctl;
wire [ 7:0] pf1_ctrl0, pf2_ctrl0, pf1_ctrl1, pf2_ctrl1;
jtdeco16ic_mmr #(.SEEK(0)) u_mmr(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cs         ( pf_cs         ),
    .addr       ( cpu_addr[4:2] ),
    .rnw        ( cpu_rnw       ),
    .din        ( cpu_dout      ),
    .dsn        ( ~wmask        ),
    .pf1_scrollx( pf1_scrollx   ),
    .pf1_scrolly( pf1_scrolly   ),
    .pf2_scrollx( pf2_scrollx   ),
    .pf2_scrolly( pf2_scrolly   ),
    .pf1_ctrl0  ( pf1_ctrl0     ),
    .pf2_ctrl0  ( pf2_ctrl0     ),
    .pf1_ctrl1  ( pf1_ctrl1     ),
    .pf2_ctrl1  ( pf2_ctrl1     ),
    .bank_ctl   ( bank_ctl      ),
    .ioctl_addr ( 4'd0          ),
    .ioctl_din  (               ),
    .debug_bus  ( 8'd0          ),
    .st_dout    (               )
);

// ---- palette, sprite and rowscroll RAMs are mem.yaml board BRAMs; the colmix and
//      engines read them through the port buses. ----
wire [15:0] pal_vq   = pal_dout;
wire [15:0] palhi_vq = palh_dout;

// ---- pf1/pf2 name-table RAM : 0x1D0000 / 0x1D4000. Each pf is drawn by BOTH its 16x16 (a) and
//      8x8 (b) engine; dual_ram has one read port, so the name RAM is duplicated per pf. ----
wire        pf1_sel = pfram_cs & ~cpu_addr[14];
wire        pf2_sel = pfram_cs &  cpu_addr[14];
wire [15:0] pf1_q, pf2_q;
wire [11:0] pf1a_va, pf1b_va, pf2a_va, pf2b_va;
wire [15:0] pf1a_vq, pf1b_vq, pf2a_vq, pf2b_vq;
jtframe_dual_ram16 #(.AW(11),.SIMFILE(PF1_F)) u_pf1(     // pf1 16x16 read
    .clk0(clk), .addr0(cpu_addr[12:2]), .data0(cpu_dout), .we0({2{pf1_sel&wr}}&wmask), .q0(pf1_q),
    .clk1(clk), .addr1(pf1a_va[10:0]), .data1(16'd0), .we1(2'b0), .q1(pf1a_vq)
);
jtframe_dual_ram16 #(.AW(11),.SIMFILE(PF1_F)) u_pf1b(    // pf1 8x8 read (copy)
    .clk0(clk), .addr0(cpu_addr[12:2]), .data0(cpu_dout), .we0({2{pf1_sel&wr}}&wmask), .q0(),
    .clk1(clk), .addr1(pf1b_va[10:0]), .data1(16'd0), .we1(2'b0), .q1(pf1b_vq)
);
jtframe_dual_ram16 #(.AW(11),.SIMFILE(PF2_F)) u_pf2(     // pf2 16x16 read
    .clk0(clk), .addr0(cpu_addr[12:2]), .data0(cpu_dout), .we0({2{pf2_sel&wr}}&wmask), .q0(pf2_q),
    .clk1(clk), .addr1(pf2a_va[10:0]), .data1(16'd0), .we1(2'b0), .q1(pf2a_vq)
);
jtframe_dual_ram16 #(.AW(11),.SIMFILE(PF2_F)) u_pf2b(    // pf2 8x8 read (copy)
    .clk0(clk), .addr0(cpu_addr[12:2]), .data0(cpu_dout), .we0({2{pf2_sel&wr}}&wmask), .q0(),
    .clk1(clk), .addr1(pf2b_va[10:0]), .data1(16'd0), .we1(2'b0), .q1(pf2b_vq)
);
assign pf_dout = cpu_addr[14] ? pf2_q : pf1_q;

// ---- sprite RAM : 0x190000. port1 read by the sprite engine ----
wire [15:0] obj_odout = oram_dout;

// ---- sprites: DECO chip-52 (jtcninja_decospr, MXC-06). CODEW=16 for osman's 8MB gfx.
//      simpl156 set_flip_screen(true): sprite flip is inverted vs the tilemaps.
wire [11:0] obj_pxl;
wire [ 8:0] hdump_obj = hdump + 9'd2;   // sprite X align: shift the line-buffer read to move sprites 2px left
jtcninja_decospr #(.CODEW(16),.SPRW(9),.LASTSPR(319)) u_obj(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen), .flip(~flip), .pswap(1'b1),
    .HS(HS), .LHBL(LHBL), .LVBL(LVBL), .vrender(vrender), .hdump(hdump_obj),
    .oram_addr(obj_oaddr), .oram_dout(obj_odout),
    .rom_cs(obj_cs), .rom_addr(obj_addr), .rom_data(obj_data), .rom_ok(obj_ok),
    .pxl(obj_pxl)
);

// ---- rowscroll tables: mem.yaml BRAMs ----
wire [15:0] pf1_rsq = rs1_dout;
wire [15:0] pf2_rsq = rs2_dout;

// ---- tilemaps: deco16ic draws BOTH 16x16 (a) and 8x8 (b) per pf. control1[7]=1 selects 8x8.
//      pf1 -> col bank 0x00, pf2 -> col bank 0x10. Each engine fetches through its own gfxdec.
localparam [15:0] HOFS = 16'd1;   // tilemap X align vs MAME visarea (graded)
wire [ 7:0] pf1a_pxl, pf1b_pxl, pf2a_pxl, pf2b_pxl;
wire [20:2] pf1a_roma, pf1b_roma, pf2a_roma, pf2b_roma;
wire        pf1a_gcs, pf1b_gcs, pf2a_gcs, pf2b_gcs;
wire [31:0] pf1a_gdata, pf1b_gdata, pf2a_gdata, pf2b_gdata;
wire        pf1a_gok, pf1b_gok, pf2a_gok, pf2b_gok;

// pf1 16x16
jtcninja_deco16 #(.BANKW(2),.COLS(42),.HLAST(9'd441)) u_pf1a_eng(
    .rst(rst),.clk(clk),.pxl_cen(pxl_cen),.flip(flip),.fullheight(1'b0),.pswap(1'b0),.rowmajor(1'b0),
    .scrollx(pf1_scrollx+HOFS),.scrolly(pf1_scrolly),.bank(bank_ctl[6:4]),
    .control0(pf1_ctrl0),.control1(pf1_ctrl1 & 8'h7f),
    .rsram_addr(pf1_rsa),.rsram_data(pf1_rsq),.vdump(vdump),.hdump(hdump),.hs(HS),
    .ram_addr(pf1a_va),.ram_data(pf1a_vq),
    .rom_cs(pf1a_gcs),.rom_addr(pf1a_roma),.rom_data(pf1a_gdata),.rom_ok(pf1a_gok),.pxl(pf1a_pxl)
);
jtosman_gfxdec u_pf1a_dec(.rst(rst),.clk(clk),.tile1mb(tile1mb),.rom_cs(pf1a_gcs),.rom_addr(pf1a_roma),.rom_data(pf1a_gdata),.rom_ok(pf1a_gok),
    .sdr_cs(gfx1a_cs),.sdr_addr(gfx1a_addr),.sdr_data(gfx1a_data),.sdr_ok(gfx1a_ok));
// pf1 8x8
jtcninja_deco16 #(.BANKW(2),.COLS(42),.HLAST(9'd441)) u_pf1b_eng(
    .rst(rst),.clk(clk),.pxl_cen(pxl_cen),.flip(flip),.fullheight(1'b0),.pswap(1'b0),.rowmajor(1'b0),
    .scrollx(pf1_scrollx+HOFS),.scrolly(pf1_scrolly),.bank(bank_ctl[6:4]),
    .control0(pf1_ctrl0),.control1(pf1_ctrl1 | 8'h80),
    .rsram_addr(),.rsram_data(16'd0),.vdump(vdump),.hdump(hdump),.hs(HS),
    .ram_addr(pf1b_va),.ram_data(pf1b_vq),
    .rom_cs(pf1b_gcs),.rom_addr(pf1b_roma),.rom_data(pf1b_gdata),.rom_ok(pf1b_gok),.pxl(pf1b_pxl)
);
jtosman_gfxdec u_pf1b_dec(.rst(rst),.clk(clk),.tile1mb(tile1mb),.rom_cs(pf1b_gcs),.rom_addr(pf1b_roma),.rom_data(pf1b_gdata),.rom_ok(pf1b_gok),
    .sdr_cs(gfx1c_cs),.sdr_addr(gfx1c_addr),.sdr_data(gfx1c_data),.sdr_ok(gfx1c_ok));
// pf2 16x16
jtcninja_deco16 #(.BANKW(2),.COLS(42),.HLAST(9'd441)) u_pf2a_eng(
    .rst(rst),.clk(clk),.pxl_cen(pxl_cen),.flip(flip),.fullheight(1'b0),.pswap(1'b0),.rowmajor(1'b0),
    .scrollx(pf2_scrollx+HOFS),.scrolly(pf2_scrolly),.bank(bank_ctl[14:12]),
    .control0(pf2_ctrl0),.control1(pf2_ctrl1 & 8'h7f),
    .rsram_addr(pf2_rsa),.rsram_data(pf2_rsq),.vdump(vdump),.hdump(hdump),.hs(HS),
    .ram_addr(pf2a_va),.ram_data(pf2a_vq),
    .rom_cs(pf2a_gcs),.rom_addr(pf2a_roma),.rom_data(pf2a_gdata),.rom_ok(pf2a_gok),.pxl(pf2a_pxl)
);
jtosman_gfxdec u_pf2a_dec(.rst(rst),.clk(clk),.tile1mb(tile1mb),.rom_cs(pf2a_gcs),.rom_addr(pf2a_roma),.rom_data(pf2a_gdata),.rom_ok(pf2a_gok),
    .sdr_cs(gfx1b_cs),.sdr_addr(gfx1b_addr),.sdr_data(gfx1b_data),.sdr_ok(gfx1b_ok));
// pf2 8x8
jtcninja_deco16 #(.BANKW(2),.COLS(42),.HLAST(9'd441)) u_pf2b_eng(
    .rst(rst),.clk(clk),.pxl_cen(pxl_cen),.flip(flip),.fullheight(1'b0),.pswap(1'b0),.rowmajor(1'b0),
    .scrollx(pf2_scrollx+HOFS),.scrolly(pf2_scrolly),.bank(bank_ctl[14:12]),
    .control0(pf2_ctrl0),.control1(pf2_ctrl1 | 8'h80),
    .rsram_addr(),.rsram_data(16'd0),.vdump(vdump),.hdump(hdump),.hs(HS),
    .ram_addr(pf2b_va),.ram_data(pf2b_vq),
    .rom_cs(pf2b_gcs),.rom_addr(pf2b_roma),.rom_data(pf2b_gdata),.rom_ok(pf2b_gok),.pxl(pf2b_pxl)
);
jtosman_gfxdec u_pf2b_dec(.rst(rst),.clk(clk),.tile1mb(tile1mb),.rom_cs(pf2b_gcs),.rom_addr(pf2b_roma),.rom_data(pf2b_gdata),.rom_ok(pf2b_gok),
    .sdr_cs(gfx1d_cs),.sdr_addr(gfx1d_addr),.sdr_data(gfx1d_data),.sdr_ok(gfx1d_ok));

// deco16_pf_update: control1[7] SELECTS the size per pf and DISABLES the other (enable(0)).
// So only the selected size contributes; the other is transparent.
wire        pf1_8x8 = pf1_ctrl1[7];    // pf1 control1[7]
wire        pf2_8x8 = pf2_ctrl1[7];    // pf2 control1[7]
wire [ 7:0] pf1a_g = pf1_8x8 ? 8'd0 : pf1a_pxl;   // 16x16 active when control1[7]==0
wire [ 7:0] pf1b_g = pf1_8x8 ? pf1b_pxl : 8'd0;   // 8x8   active when control1[7]==1
wire [ 7:0] pf2a_g = pf2_8x8 ? 8'd0 : pf2a_pxl;
wire [ 7:0] pf2b_g = pf2_8x8 ? pf2b_pxl : 8'd0;

// ---- colour mixer ----
jtosman_colmix u_colmix(
    .clk( clk ), .pxl_cen( pxl_cen ), .LHBL( LHBL ), .LVBL( LVBL ),
    .pf1a_pxl( pf1a_g ), .pf1b_pxl( pf1b_g ),
    .pf2a_pxl( pf2a_g ), .pf2b_pxl( pf2b_g ), .obj_pxl( obj_pxl ),
    .pal_addr( pal_rd ), .pal_data( pal_vq ), .palhi_data( palhi_vq ), .pal888( pal888 ),
    .red( red ), .green( green ), .blue( blue )
);

endmodule
