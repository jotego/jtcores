/*  This file is part of JTCORES. GPLv3. See jtcninja_game.v header.

    Palette + priority mixer for the Caveman Ninja hardware family
    (2x deco16ic = 4 playfields + decospr sprites).

    Composites the four playfield streams and the sprite stream into a palette
    pen index, looks it up in the (video-owned) palette RAM, and emits RGB.

    Palette format (both games, xBGR_888, 2 words/colour). cninja interleaves
    2 words/colour (even={x,B}, odd={G,R}); darkseal splits the RAM in half -
    GR {G,R} in the low 2048 (0x140000), B {x,B} in the high 2048 (0x141000).
    Either way the final {gr[15:8],gr[7:0],xb[7:0]} = {G,R,B} assembly is the same.

    pen = gfxdecode palette base + (deco_col_bank + tile_pal)*16 + colour.
    gfx region bases: chars 0x000, tiles1 0x100, tiles2 0x500 (cninja) /
    sprites 0x100, tiles1 0x300, tiles2 0x400 (darkseal).
*/
module jtcninja_colmix(
    input             clk,
    input             pxl_cen,
    input             dseal,             // game_id==2
    input             cbust,             // game_id==1 (Crude Buster)
    input             cbpri,             // cbuster TC-4 m_pri: swaps mg/pf1b order
    input      [15:0] vprio0,            // vaportra m_priority[0]: playfield order
    input      [15:0] vprio1,            // vaportra m_priority[1]: sprite threshold
    input             vapor,             // game_id==3 (Vapor Trail)
    input      [ 8:0] hdump,             // for the DSEAL_PALTEST diag ramp
    input             LHBL,
    input             LVBL,

    // layer pixels = {colour[3:0], pixel[3:0]} ; sprites = {pri,colour,pixel}
    input      [ 7:0] fg_pxl,
    input      [ 7:0] mg_pxl,
    input      [ 7:0] bg_pxl,
    input      [ 7:0] pf1b_pxl,
    input      [11:0] obj_pxl,           // {epri, pri[1:0], colour[4:0], pixel[3:0]}

    // palette RAM read port (RAM lives in jtcninja_video)
    output reg [11:0] pal_addr,
    input      [15:0] pal_data,

    // blanking delayed by the same pixel as rgb_out - these drive the core's
    // LHBL/LVBL so the window travels WITH the picture (else a pixel is eaten)
    output                           LHBL_o,
    output                           LVBL_o,

    output     [`JTFRAME_COLORW-1:0] red,
    output     [`JTFRAME_COLORW-1:0] green,
    output     [`JTFRAME_COLORW-1:0] blue
);

wire        mg_opaque   = mg_pxl[3:0]  !=4'd0;
wire        fg_opaque   = fg_pxl[3:0]  !=4'd0;
wire        bg_opaque   = bg_pxl[3:0]  !=4'd0;
wire        pf1b_opaque = pf1b_pxl[3:0]!=4'd0;
wire        obj_opaque  = obj_pxl[3:0] !=4'd0;
wire [ 1:0] obj_pri     = obj_pxl[10:9];
wire [10:0] obj_idx     = 11'h300 + { 2'b0, obj_pxl[8:0] }; // 0x300 + colour*16 + pixel

`ifdef DSEAL_PALTEST
wire [10:0] pal_idx = { 3'd0, hdump[7:0] };  // DIAG: palette colours 0-255 across X
`elsif BG_ONLY
wire [10:0] pal_idx = { 3'd5, bg_pxl };
`elsif FG_ONLY
wire [10:0] pal_idx = { 3'd0, fg_pxl };
`elsif MG_ONLY
wire [10:0] pal_idx = { 3'd1, mg_pxl };
`elsif PF1B_ONLY
wire [10:0] pal_idx = { 3'd2, pf1b_pxl };
`else
// Sprite priority (decospr pri_callback, x[15:14]): pri0 in front of all
// tilemaps; pri1 behind mg; pri2/3 behind mg+pf1b.
//   cninja front->back:  fg > obj0 > mg > obj1 > pf1b > obj23 > bg
wire obj_f = obj_opaque & (obj_pri==2'd0);
wire obj_m = obj_opaque & (obj_pri==2'd1);
wire obj_b = obj_opaque & (obj_pri[1]);          // pri 2 or 3
wire [10:0] cn_pal_idx = fg_opaque   ? { 3'd0, fg_pxl   } :
                         obj_f       ? obj_idx            :
                         mg_opaque   ? { 3'd1, mg_pxl   } :
                         obj_m       ? obj_idx            :
                         pf1b_opaque ? { 3'd2, pf1b_pxl } :
                         obj_b       ? obj_idx            :
                                       { 3'd5, bg_pxl   };
// Dark Seal (darkseal.cpp screen_update). Draw order back->front:
//   tilegen1 pf1 (pf1b) < tilegen1 pf2 (bg, marble) < tilegen0 pf1 (mg, tiles1)
//   < sprites < tilegen0 pf2 (fg, 8x8 chars/text, FRONT). Backdrop = black pen 0.
wire [10:0] ds_pal_idx = fg_opaque   ? { 3'd0, fg_pxl   } :              // pf2 chars (FRONT)
                         obj_opaque  ? 11'h100 + {2'b0, obj_pxl[8:0]} :  // sprites
                         mg_opaque   ? { 3'd3, mg_pxl   } :              // pf1 tiles1
                         bg_opaque   ? { 3'd4, bg_pxl   } :              // pf2 tiles2 (marble)
                         pf1b_opaque ? { 3'd4, pf1b_pxl } :              // pf1 tiles2
                                       11'd0;                            // black backdrop
// Crude Buster (cbuster.cpp screen_update). col_banks: fg(chip0 pf1)=0x00,
// mg(chip0 pf2)=0x20, pf1b(chip1 pf1)=0x30, bg(chip1 pf2)=0x40; sprites base
// 0x100 -> pen bases 0/0x200/0x300/0x400. Fixed priority for now (m_pri/sprite
// bands TODO): fg(front) > mg > pf1b > bg(opaque backdrop). Sprites not yet wired.
// cbuster.cpp screen_update: fg (chip0 pf1) FRONT; then mg(chip0 pf2) & pf1b
// (chip1 pf1) in an order set by the TC-4 PAL m_pri (cbpri): m_pri=0 -> pf1b then
// mg (mg on top); m_pri=1 -> mg then pf1b (pf1b on top). bg(chip1 pf2) is the
// opaque backdrop. (Sprite priority bands TODO when sprites land.)
// Sprite color-banded priority (decospr inefficient_copy_sprite_bitmap):
//   pen   = (colour[4] ? 0x500 : 0x100) + colour[3:0]*16 + pixel   (two palette bands)
//   epri  = sprite word0[15]: 1 -> behind mg+pf1b (early bands 0x0800/0x0900),
//                             0 -> in front of mg+pf1b (late bands 0x0000/0x0100).
// Layer order front->back: fg > obj(epri=0) > {mg,pf1b by cbpri} > obj(epri=1) > bg.
wire        obj_op2   = obj_pxl[3:0]!=4'd0;
wire        obj_epri  = obj_pxl[11];
wire [10:0] obj_cbidx = { obj_pxl[8] ? 3'b101 : 3'b001, obj_pxl[7:0] };
// mg + pf1b middle layers; cbpri (TC-4 m_pri) sets which is on top.
wire        mid_op    = mg_opaque | pf1b_opaque;
wire [10:0] cb_mid    = cbpri ? ( pf1b_opaque ? { 3'd3, pf1b_pxl } : { 3'd2, mg_pxl   } )
                              : ( mg_opaque   ? { 3'd2, mg_pxl   } : { 3'd3, pf1b_pxl } );
wire [10:0] cb_pal_idx =
    fg_opaque               ? { 3'd0, fg_pxl } :
    (obj_op2 & ~obj_epri)   ? obj_cbidx       :
    mid_op                  ? cb_mid          :
    (obj_op2 &  obj_epri)   ? obj_cbidx       :
                              { 3'd4, bg_pxl };
// Vapor Trail (vaportra.cpp screen_update). col_banks: fg(tg0 pf1)=0x00,
// mg(tg0 pf2)=0x20, pf1b(tg1 pf1)=0x30, bg(tg1 pf2)=0x40 -> pen bases
// 0/0x200/0x300/0x400; sprites base 0x100. FIRST-render fixed order (the runtime
// m_priority[0] 4-way mux is a refinement): fg(front) > obj > mg > pf1b > bg.
wire [10:0] obj_vp = 11'h100 + { 2'b0, obj_pxl[8:0] };
// vaportra.cpp screen_update picks the playfield draw order at RUNTIME from
// m_priority[0]&3. Drawn back->front with tilemap priorities 1 (opaque backdrop),
// 2 (middle) and 4 (top):
//   pri 0: bg(op) < pf1b < mg     pri 1: pf1b(op) < bg   < mg
//   pri 2: bg(op) < mg   < pf1b   pri 3: pf1b(op) < mg   < bg
// then sprites, then fg on top. colpri_cb pushes a sprite BEHIND the pri-4
// tilemap when its colour >= m_priority[1].
wire [1:0]  vp_pri   = vprio0[1:0];
wire [3:0]  vp_ocol  = obj_pxl[7:4];                   // MXC-06 pen = {pal,pixel}
wire        vp_oback = { 12'd0, vp_ocol } >= vprio1;
wire [10:0] vp_l3    = vp_pri==2'd2 ? { 3'd3, pf1b_pxl } :
                       vp_pri==2'd3 ? { 3'd4, bg_pxl   } : { 3'd2, mg_pxl };
wire        vp_l3op  = vp_pri==2'd2 ? pf1b_opaque :
                       vp_pri==2'd3 ? bg_opaque   : mg_opaque;
wire [10:0] vp_l2    = vp_pri==2'd0 ? { 3'd3, pf1b_pxl } :
                       vp_pri==2'd1 ? { 3'd4, bg_pxl   } : { 3'd2, mg_pxl };
wire        vp_l2op  = vp_pri==2'd0 ? pf1b_opaque :
                       vp_pri==2'd1 ? bg_opaque   : mg_opaque;
wire [10:0] vp_l1    = vp_pri[0] ? { 3'd3, pf1b_pxl } : { 3'd4, bg_pxl };
wire [10:0] vp_pal_idx =
    fg_opaque                ? { 3'd0, fg_pxl } :   // tg0 pf1 (fg, 8x8) FRONT
    (obj_opaque & ~vp_oback) ? obj_vp           :   // sprites above the tilemaps
    vp_l3op                  ? vp_l3            :   // top tilemap (pri 4)
    (obj_opaque &  vp_oback) ? obj_vp           :   // sprites behind the pri-4 layer
    vp_l2op                  ? vp_l2            :   // middle tilemap (pri 2)
                               vp_l1;               // opaque backdrop (pri 1)
wire [10:0] pal_idx = dseal ? ds_pal_idx : cbust ? cb_pal_idx :
                      vapor ? vp_pal_idx : cn_pal_idx;
`endif

// palette read: 2 words/colour, alternated by `phase`. q1 has 1-cyc latency.
// cbuster shares darkseal's SPLIT layout: main RAM (write16) = low half {G,R},
// ext RAM (write16_ext) = high half {x,B}, selected by the bit-12 address split.
wire splitpal = dseal | cbust | vapor;   // vapor: GR @0x300000 + B @0x304000, RGB888
reg        phase;
reg [15:0] xb_w, gr_w;
// A colour takes TWO cycles (phase 0 = {G,R}, phase 1 = {x,B}). pal_idx must be
// HELD across the pair, or when the priority mux moves to another pen between
// them the B half addresses a DIFFERENT colour than R/G - blue arrives late, worst
// at layer edges.
reg  [10:0] pal_idx_l;
wire [10:0] pal_idx_eff = phase ? pal_idx_l : pal_idx;
always @(posedge clk) begin
    phase    <= ~phase;
    if( !phase ) pal_idx_l <= pal_idx;   // latch when the first half is issued
    pal_addr <= splitpal ? { phase, pal_idx_eff } : { pal_idx_eff, phase };
    if( splitpal ) begin
        if( !phase ) gr_w <= pal_data;    // split low half  {G,R}
        else         xb_w <= pal_data;    // split high half {x,B}
    end else begin
        if( !phase ) xb_w <= pal_data;    // cninja even word {x,B}
        else         gr_w <= pal_data;    // cninja odd  word {G,R}
    end
end

// Crude Buster white-level clamp (cbuster.cpp ::xbgr_888): the analog white is
// set at 0x8e (resistors before the JAMMA output), so each 8-bit channel is
// clamped to 0x8e then scaled to full range: out = min(c,0x8e)*255/0x8e. Without
// this the image reads too bright. 255/0x8e ~= 460/256, so (clamped*460)>>8.
function [7:0] cbwclamp(input [7:0] c);
    reg [7:0]  cc;
    reg [16:0] sc;
    begin
        cc = (c > 8'h8e) ? 8'h8e : c;
        sc = cc * 17'd460;
        cbwclamp = sc[15:8];
    end
endfunction
wire [7:0] r_o = cbust ? cbwclamp(gr_w[ 7:0]) : gr_w[ 7:0];
wire [7:0] g_o = cbust ? cbwclamp(gr_w[15:8]) : gr_w[15:8];
wire [7:0] b_o = cbust ? cbwclamp(xb_w[ 7:0]) : xb_w[ 7:0];

// gr_w ({G,R}) and xb_w ({x,B}) are captured on OPPOSITE phases, so a
// combinational rgb path is only settled for part of each pixel - fine in sim, but
// on hardware the video stage can sample it mid-update and B lands one colour
// late. DLY=1 registers rgb_out. The delayed LHBL/LVBL MUST be routed out: leaving
// them unconnected keeps the core exporting the undelayed vtimer blanking while
// the RGB moves, which EATS the first visible pixel instead of shifting the
// picture (HOFFSET cannot compensate - it moves content, not the window).
jtframe_blank #(.DLY(1),.DW(24)) u_blank(
    .clk     ( clk     ),
    .pxl_cen ( pxl_cen ),
    .preLHBL ( LHBL    ),
    .preLVBL ( LVBL    ),
    .LHBL    ( LHBL_o  ),
    .LVBL    ( LVBL_o  ),
    .preLBL  (         ),
    .rgb_in  ( { g_o, r_o, b_o } ),  // {G, R, B}
    .rgb_out ( { green, red, blue } )
);

endmodule
