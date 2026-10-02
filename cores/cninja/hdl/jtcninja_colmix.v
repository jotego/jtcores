/*  This file is part of JTCORES. GPLv3. See jtcninja_game.v header.

    Palette + priority mixer for the Data East 16-bit family.

    Composites the four playfield streams and the sprite stream into a palette
    pen, reads the palette RAM (in mem.yaml) and emits RGB. Each board has its
    own layer order, taken from its screen_update in MAME.

    Palette is xBGR_888, two words per colour. cninja interleaves them
    (even={x,B}, odd={G,R}); the others split the RAM in half, {G,R} low and
    {x,B} high. Either way the final assembly is {G,R,B}.
*/
module jtcninja_colmix(
    input             clk,
    input             pxl_cen,
    input             dseal,             // Dark Seal
    input             cbust,             // Crude Buster
    input             vapor,             // Vapor Trail
    input             cbpri,             // cbuster TC-4 m_pri: swaps mg/pf1b order
    input      [15:0] vprio0,            // vaportra m_priority[0]: playfield order
    input      [15:0] vprio1,            // vaportra m_priority[1]: sprite threshold
    input             LHBL,
    input             LVBL,

    // layer pixels = {colour[3:0], pixel[3:0]} ; sprites = {epri,pri,colour,pixel}
    input      [ 7:0] fg_pxl,
    input      [ 7:0] mg_pxl,
    input      [ 7:0] bg_pxl,
    input      [ 7:0] pf1b_pxl,
    input      [11:0] obj_pxl,

    output reg [11:0] pal_addr,
    input      [15:0] pal_data,

    // blanking delayed by the same pixel as rgb_out; drives the core's LHBL/LVBL
    output                           LHBL_o,
    output                           LVBL_o,

    output     [`JTFRAME_COLORW-1:0] red,
    output     [`JTFRAME_COLORW-1:0] green,
    output     [`JTFRAME_COLORW-1:0] blue
);

wire mg_opaque   = mg_pxl[3:0]  !=4'd0;
wire fg_opaque   = fg_pxl[3:0]  !=4'd0;
wire bg_opaque   = bg_pxl[3:0]  !=4'd0;
wire pf1b_opaque = pf1b_pxl[3:0]!=4'd0;
wire obj_opaque  = obj_pxl[3:0] !=4'd0;

// ---- Caveman Ninja ----------------------------------------------------------
// decospr pri_callback on x[15:14]: pri 0 in front of everything, pri 1 behind
// mg, pri 2/3 behind mg and pf1b.
wire [ 1:0] obj_pri = obj_pxl[10:9];
wire [10:0] obj_idx = 11'h300 + { 2'b0, obj_pxl[8:0] };
wire        obj_f   = obj_opaque & obj_pri==2'd0;
wire        obj_m   = obj_opaque & obj_pri==2'd1;
wire        obj_b   = obj_opaque & obj_pri[1];
wire [10:0] cn_pal_idx = fg_opaque   ? { 3'd0, fg_pxl   } :
                         obj_f       ? obj_idx            :
                         mg_opaque   ? { 3'd1, mg_pxl   } :
                         obj_m       ? obj_idx            :
                         pf1b_opaque ? { 3'd2, pf1b_pxl } :
                         obj_b       ? obj_idx            :
                                       { 3'd5, bg_pxl   };

// ---- Dark Seal --------------------------------------------------------------
// Back to front: pf1b < bg < mg < sprites < fg. Backdrop is black, not a layer.
wire [10:0] obj_100 = 11'h100 + { 2'b0, obj_pxl[8:0] };
wire [10:0] ds_pal_idx = fg_opaque   ? { 3'd0, fg_pxl   } :
                         obj_opaque  ? obj_100           :
                         mg_opaque   ? { 3'd3, mg_pxl   } :
                         bg_opaque   ? { 3'd4, bg_pxl   } :
                         pf1b_opaque ? { 3'd4, pf1b_pxl } :
                                       11'd0;

// ---- Crude Buster -----------------------------------------------------------
// fg in front; mg and pf1b in the middle, ordered by the TC-4 PAL (cbpri); bg is
// the opaque backdrop. Sprites take two palette bands on colour[4], and word0[15]
// (epri) puts them in front of or behind the middle pair.
wire        obj_epri  = obj_pxl[11];
wire [10:0] obj_cbidx = { obj_pxl[8] ? 3'b101 : 3'b001, obj_pxl[7:0] };
wire        mid_op    = mg_opaque | pf1b_opaque;
wire [10:0] cb_mid    = cbpri ? ( pf1b_opaque ? { 3'd3, pf1b_pxl } : { 3'd2, mg_pxl   } )
                              : ( mg_opaque   ? { 3'd2, mg_pxl   } : { 3'd3, pf1b_pxl } );
wire [10:0] cb_pal_idx = fg_opaque                 ? { 3'd0, fg_pxl } :
                         (obj_opaque & ~obj_epri)  ? obj_cbidx       :
                         mid_op                    ? cb_mid          :
                         (obj_opaque &  obj_epri)  ? obj_cbidx       :
                                                     { 3'd4, bg_pxl };

// ---- Vapor Trail ------------------------------------------------------------
// The playfield order is picked at runtime by m_priority[0][1:0]; the three
// tilemap slots are the pri-4 (top), pri-2 (middle) and pri-1 (backdrop) layers:
//   0: bg(bd) pf1b mg      1: pf1b(bd) bg   mg
//   2: bg(bd) mg   pf1b    3: pf1b(bd) mg   bg
// A sprite whose colour >= m_priority[1] drops behind the pri-4 layer.
wire [1:0]  vp_pri   = vprio0[1:0];
wire        vp_oback = { 12'd0, obj_pxl[7:4] } >= vprio1;
wire [10:0] vp_l3    = vp_pri==2'd2 ? { 3'd3, pf1b_pxl } :
                       vp_pri==2'd3 ? { 3'd4, bg_pxl   } : { 3'd2, mg_pxl };
wire        vp_l3op  = vp_pri==2'd2 ? pf1b_opaque :
                       vp_pri==2'd3 ? bg_opaque   : mg_opaque;
wire [10:0] vp_l2    = vp_pri==2'd0 ? { 3'd3, pf1b_pxl } :
                       vp_pri==2'd1 ? { 3'd4, bg_pxl   } : { 3'd2, mg_pxl };
wire        vp_l2op  = vp_pri==2'd0 ? pf1b_opaque :
                       vp_pri==2'd1 ? bg_opaque   : mg_opaque;
wire [10:0] vp_l1    = vp_pri[0] ? { 3'd3, pf1b_pxl } : { 3'd4, bg_pxl };
wire [10:0] vp_pal_idx = fg_opaque                ? { 3'd0, fg_pxl } :
                         (obj_opaque & ~vp_oback) ? obj_100         :
                         vp_l3op                  ? vp_l3           :
                         (obj_opaque &  vp_oback) ? obj_100         :
                         vp_l2op                  ? vp_l2           :
                                                    vp_l1;

wire [10:0] pal_idx = dseal ? ds_pal_idx : cbust ? cb_pal_idx :
                      vapor ? vp_pal_idx : cn_pal_idx;

// ---- palette read -----------------------------------------------------------
// Two cycles per colour. pal_idx must be HELD across the pair, or when the
// priority mux moves to another pen between them the {x,B} half addresses a
// different colour than {G,R} - blue arrives late, worst at layer edges.
wire splitpal = dseal | cbust | vapor;
reg         phase;
reg  [15:0] xb_w, gr_w;
reg  [10:0] pal_idx_l;
wire [10:0] pal_idx_eff = phase ? pal_idx_l : pal_idx;

always @(posedge clk) begin
    phase    <= ~phase;
    if( !phase ) pal_idx_l <= pal_idx;
    pal_addr <= splitpal ? { phase, pal_idx_eff } : { pal_idx_eff, phase };
    if( splitpal ) begin
        if( !phase ) gr_w <= pal_data;
        else         xb_w <= pal_data;
    end else begin
        if( !phase ) xb_w <= pal_data;   // cninja interleaves the other way round
        else         gr_w <= pal_data;
    end
end

// Crude Buster analog white sits at 0x8e (resistors before the JAMMA output), so
// each channel is clamped there and rescaled: out = min(c,0x8e)*255/0x8e, and
// 255/0x8e ~= 460/256. Without it the image reads too bright.
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

// gr_w and xb_w are captured on opposite phases, so a combinational rgb path is
// only settled for part of each pixel: DLY=1 registers it. The delayed LHBL/LVBL
// must be routed out, else the window stays put while the picture moves and the
// first visible pixel is eaten (HOFFSET moves content, not the window).
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
