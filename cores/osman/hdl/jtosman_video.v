/*  This file is part of JTCORES. GPLv3. See jtosman_game.v header.
    Author: Andrea Bogazzi.

    Osman video. Data East Simple 156: one DECO16IC tilegen (pf1+pf2, via 2x
    jtframe_deco16 imported from cninja) + chip-52 sprites (jtframe_decospr, TODO)
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

    // CPU interface
    input    [16:1]   cpu_addr,
    input    [15:0]   cpu_dout,
    input             cpu_rnw,
    input    [ 1:0]   dsn,
    input             pf_cs,
    input             pfram_cs,
    input             pal_cs,
    input             oram_cs,
    input             rowscr_cs,
    input             obj_copy,
    output   [15:0]   pf_dout,
    output   [15:0]   pal_dout,
    output   [15:0]   oram_dout,

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


// ---- timing: 320x240, htotal 512, 240 rows at top 8 ----
jtframe_vtimer #(
    .VB_START ( 9'd247 ), .VB_END( 9'd7 ), .VCNT_END( 9'd273 ), .VS_START( 9'd254 ),
    .HB_START ( 9'd319 ), .HB_END( 9'd511 ), .HS_START( 9'd416 ), .HINIT( 9'd319 )
) u_vtimer(
    .clk( clk ), .pxl_cen( pxl_cen ),
    .vdump( vdump ), .vrender( vrender ), .vrender1(),
    .H( hdump ), .Hinit(), .Vinit(),
    .LHBL( LHBL ), .LVBL( LVBL ), .HS( HS ), .VS( VS )
);

// ---- deco16ic control registers : 0x1C0000, 8 x 16-bit (4-byte spaced) ----
// pf1: scrollx=r1 scrolly=r2 c0=r5[7:0] c1=r6[7:0] bank=(r7[7:0]>>4)&7
// pf2: scrollx=r3 scrolly=r4 c0=r5[15:8] c1=r6[15:8] bank=(r7[15:8]>>4)&7  (simpl156 bank_cb)
reg [15:0] pfctrl[0:7];
`ifdef SIMSCENE   // scene replay: preload control regs + BRAMs from the captured dump
localparam PAL_F="pal.bin", PF1_F="pf1.bin", PF2_F="pf2.bin", ORAM_F="oram.bin";
initial $readmemh("pfctrl.hex", pfctrl);
`else
localparam PAL_F="", PF1_F="", PF2_F="", ORAM_F="";
integer ci; initial for(ci=0;ci<8;ci=ci+1) pfctrl[ci]=16'd0;
always @(posedge clk) if( pf_cs & wr & (|wmask) ) pfctrl[cpu_addr[4:2]] <= cpu_dout;
`endif

// ---- palette RAM : 0x1A0000, xBGR-555, 1024 colours ----
wire [ 9:0] pal_rd;
wire [15:0] pal_vq;
jtframe_dual_ram16 #(.AW(10),.SIMFILE(PAL_F)) u_pal(
    .clk0(clk), .addr0(cpu_addr[11:2]), .data0(cpu_dout), .we0({2{pal_cs&wr}}&wmask), .q0(pal_dout),
    .clk1(clk), .addr1(pal_rd), .data1(16'd0), .we1(2'b0), .q1(pal_vq)
);

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
wire [10:0] obj_oaddr;
wire [15:0] obj_odout;
jtframe_dual_ram16 #(.AW(11),.SIMFILE(ORAM_F)) u_oram(
    .clk0(clk), .addr0(cpu_addr[12:2]), .data0(cpu_dout), .we0({2{oram_cs&wr}}&wmask), .q0(oram_dout),
    .clk1(clk), .addr1(obj_oaddr), .data1(16'd0), .we1(2'b0), .q1(obj_odout)
);

// ---- sprites: DECO chip-52 (jtframe_decospr, MXC-06). CODEW=16 for osman's 8MB gfx.
//      simpl156 set_flip_screen(true): sprite flip is inverted vs the tilemaps.
wire [11:0] obj_pxl;
wire [ 8:0] hdump_obj = hdump + 9'd2;   // sprite X align: shift the line-buffer read to move sprites 2px left
jtframe_decospr #(.CODEW(16),.SPRW(9),.LASTSPR(319)) u_obj(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen), .flip(~flip), .pswap(1'b1),
    .HS(HS), .LHBL(LHBL), .LVBL(LVBL), .vrender(vrender), .hdump(hdump_obj),
    .oram_addr(obj_oaddr), .oram_dout(obj_odout),
    .rom_cs(obj_cs), .rom_addr(obj_addr), .rom_data(obj_data), .rom_ok(obj_ok),
    .pxl(obj_pxl)
);

// ---- rowscroll RAM : 0x1E0000 / 0x1E4000 ----
wire        rs1_sel = rowscr_cs & ~cpu_addr[14];
wire        rs2_sel = rowscr_cs &  cpu_addr[14];
wire [10:0] pf1_rsa, pf2_rsa;
wire [15:0] pf1_rsq, pf2_rsq;
jtframe_dual_ram16 #(.AW(11)) u_rs1(
    .clk0(clk), .addr0(cpu_addr[12:2]), .data0(cpu_dout), .we0({2{rs1_sel&wr}}&wmask), .q0(),
    .clk1(clk), .addr1(pf1_rsa), .data1(16'd0), .we1(2'b0), .q1(pf1_rsq)
);
jtframe_dual_ram16 #(.AW(11)) u_rs2(
    .clk0(clk), .addr0(cpu_addr[12:2]), .data0(cpu_dout), .we0({2{rs2_sel&wr}}&wmask), .q0(),
    .clk1(clk), .addr1(pf2_rsa), .data1(16'd0), .we1(2'b0), .q1(pf2_rsq)
);

// ---- tilemaps: deco16ic draws BOTH 16x16 (a) and 8x8 (b) per pf. control1[7]=1 selects 8x8.
//      pf1 -> col bank 0x00, pf2 -> col bank 0x10. Each engine fetches through its own gfxdec.
localparam [15:0] HOFS = 16'd1;   // tilemap X align vs MAME visarea (graded)
wire [ 7:0] pf1a_pxl, pf1b_pxl, pf2a_pxl, pf2b_pxl;
wire [20:2] pf1a_roma, pf1b_roma, pf2a_roma, pf2b_roma;
wire        pf1a_gcs, pf1b_gcs, pf2a_gcs, pf2b_gcs;
wire [31:0] pf1a_gdata, pf1b_gdata, pf2a_gdata, pf2b_gdata;
wire        pf1a_gok, pf1b_gok, pf2a_gok, pf2b_gok;

// pf1 16x16
jtframe_deco16 #(.BANKW(2),.COLS(42)) u_pf1a_eng(
    .rst(rst),.clk(clk),.pxl_cen(pxl_cen),.flip(flip),.fullheight(1'b0),.pswap(1'b0),.rowmajor(1'b0),
    .scrollx(pfctrl[1]+HOFS),.scrolly(pfctrl[2]),.bank(pfctrl[7][6:4]),
    .control0(pfctrl[5][7:0]),.control1(pfctrl[6][7:0] & 8'h7f),
    .rsram_addr(pf1_rsa),.rsram_data(pf1_rsq),.vrender(vrender),.hdump(hdump),.hs(HS),
    .ram_addr(pf1a_va),.ram_data(pf1a_vq),
    .rom_cs(pf1a_gcs),.rom_addr(pf1a_roma),.rom_data(pf1a_gdata),.rom_ok(pf1a_gok),.pxl(pf1a_pxl)
);
jtosman_gfxdec u_pf1a_dec(.rst(rst),.clk(clk),.rom_cs(pf1a_gcs),.rom_addr(pf1a_roma),.rom_data(pf1a_gdata),.rom_ok(pf1a_gok),
    .sdr_cs(gfx1a_cs),.sdr_addr(gfx1a_addr),.sdr_data(gfx1a_data),.sdr_ok(gfx1a_ok));
// pf1 8x8
jtframe_deco16 #(.BANKW(2),.COLS(42)) u_pf1b_eng(
    .rst(rst),.clk(clk),.pxl_cen(pxl_cen),.flip(flip),.fullheight(1'b0),.pswap(1'b0),.rowmajor(1'b0),
    .scrollx(pfctrl[1]+HOFS),.scrolly(pfctrl[2]),.bank(pfctrl[7][6:4]),
    .control0(pfctrl[5][7:0]),.control1(pfctrl[6][7:0] | 8'h80),
    .rsram_addr(),.rsram_data(16'd0),.vrender(vrender),.hdump(hdump),.hs(HS),
    .ram_addr(pf1b_va),.ram_data(pf1b_vq),
    .rom_cs(pf1b_gcs),.rom_addr(pf1b_roma),.rom_data(pf1b_gdata),.rom_ok(pf1b_gok),.pxl(pf1b_pxl)
);
jtosman_gfxdec u_pf1b_dec(.rst(rst),.clk(clk),.rom_cs(pf1b_gcs),.rom_addr(pf1b_roma),.rom_data(pf1b_gdata),.rom_ok(pf1b_gok),
    .sdr_cs(gfx1c_cs),.sdr_addr(gfx1c_addr),.sdr_data(gfx1c_data),.sdr_ok(gfx1c_ok));
// pf2 16x16
jtframe_deco16 #(.BANKW(2),.COLS(42)) u_pf2a_eng(
    .rst(rst),.clk(clk),.pxl_cen(pxl_cen),.flip(flip),.fullheight(1'b0),.pswap(1'b0),.rowmajor(1'b0),
    .scrollx(pfctrl[3]+HOFS),.scrolly(pfctrl[4]),.bank(pfctrl[7][14:12]),
    .control0(pfctrl[5][15:8]),.control1(pfctrl[6][15:8] & 8'h7f),
    .rsram_addr(pf2_rsa),.rsram_data(pf2_rsq),.vrender(vrender),.hdump(hdump),.hs(HS),
    .ram_addr(pf2a_va),.ram_data(pf2a_vq),
    .rom_cs(pf2a_gcs),.rom_addr(pf2a_roma),.rom_data(pf2a_gdata),.rom_ok(pf2a_gok),.pxl(pf2a_pxl)
);
jtosman_gfxdec u_pf2a_dec(.rst(rst),.clk(clk),.rom_cs(pf2a_gcs),.rom_addr(pf2a_roma),.rom_data(pf2a_gdata),.rom_ok(pf2a_gok),
    .sdr_cs(gfx1b_cs),.sdr_addr(gfx1b_addr),.sdr_data(gfx1b_data),.sdr_ok(gfx1b_ok));
// pf2 8x8
jtframe_deco16 #(.BANKW(2),.COLS(42)) u_pf2b_eng(
    .rst(rst),.clk(clk),.pxl_cen(pxl_cen),.flip(flip),.fullheight(1'b0),.pswap(1'b0),.rowmajor(1'b0),
    .scrollx(pfctrl[3]+HOFS),.scrolly(pfctrl[4]),.bank(pfctrl[7][14:12]),
    .control0(pfctrl[5][15:8]),.control1(pfctrl[6][15:8] | 8'h80),
    .rsram_addr(),.rsram_data(16'd0),.vrender(vrender),.hdump(hdump),.hs(HS),
    .ram_addr(pf2b_va),.ram_data(pf2b_vq),
    .rom_cs(pf2b_gcs),.rom_addr(pf2b_roma),.rom_data(pf2b_gdata),.rom_ok(pf2b_gok),.pxl(pf2b_pxl)
);
jtosman_gfxdec u_pf2b_dec(.rst(rst),.clk(clk),.rom_cs(pf2b_gcs),.rom_addr(pf2b_roma),.rom_data(pf2b_gdata),.rom_ok(pf2b_gok),
    .sdr_cs(gfx1d_cs),.sdr_addr(gfx1d_addr),.sdr_data(gfx1d_data),.sdr_ok(gfx1d_ok));

// deco16_pf_update: control1[7] SELECTS the size per pf and DISABLES the other (enable(0)).
// So only the selected size contributes; the other is transparent.
wire        pf1_8x8 = pfctrl[6][7];    // pf1 control1[7]
wire        pf2_8x8 = pfctrl[6][15];   // pf2 control1[7]
wire [ 7:0] pf1a_g = pf1_8x8 ? 8'd0 : pf1a_pxl;   // 16x16 active when control1[7]==0
wire [ 7:0] pf1b_g = pf1_8x8 ? pf1b_pxl : 8'd0;   // 8x8   active when control1[7]==1
wire [ 7:0] pf2a_g = pf2_8x8 ? 8'd0 : pf2a_pxl;
wire [ 7:0] pf2b_g = pf2_8x8 ? pf2b_pxl : 8'd0;

// ---- colour mixer ----
jtosman_colmix u_colmix(
    .clk( clk ), .pxl_cen( pxl_cen ), .LHBL( LHBL ), .LVBL( LVBL ),
    .pf1a_pxl( pf1a_g ), .pf1b_pxl( pf1b_g ),
    .pf2a_pxl( pf2a_g ), .pf2b_pxl( pf2b_g ), .obj_pxl( obj_pxl ),
    .pal_addr( pal_rd ), .pal_data( pal_vq ),
    .red( red ), .green( green ), .blue( blue )
);

endmodule
