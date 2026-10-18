/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 12-10-2026 */

module jtpopeye_video(
    input             rst,
    input             clk,
    input             cen20,
    input             cen10,
    input             cen5,
    output            pxl2_cen,
    output reg        pxl_cen,
    input             rv,
    input      [12:0] ad,
    input      [ 7:0] dd,
    input             csv,
    input             csbw_n,
    input             dwrbk_n,
    input             memwr0,
    input      [ 7:0] dm,
    input      [ 3:0] dmcs_n,
    input             rohvs,
    input             rohvck,
    output            vb,
    output            hbd_n,
    output            ai_n,
    output            bi_n,
    output            initeo,
    output     [ 7:0] tprom_addr,
    input      [ 3:0] tprom_data,
    output     [11:0] char_addr,
    input      [ 7:0] char_data,
    output     [12:1] obj0_addr,
    input      [15:0] obj0_data,
    output     [12:1] obj1_addr,
    input      [15:0] obj1_data,
    output     [12:1] obj2_addr,
    input      [15:0] obj2_data,
    output     [12:1] obj3_addr,
    input      [15:0] obj3_data,
    output     [ 4:0] txtpal_addr,
    input      [ 7:0] txtpal_data,
    output     [ 4:0] bgpal_addr,
    input      [ 7:0] bgpal_data,
    output     [ 7:0] objpall_addr,
    input      [ 3:0] objpall_data,
    output     [ 7:0] objpalh_addr,
    input      [ 3:0] objpalh_data,
    input      [ 3:0] gfx_en,
    input             nibd7,
    input             boot,
    input             tnx1,
    input      [ 1:0] deflicker,
    input             narrow,
    input      [ 5:0] hpos,
    input      [ 4:0] vpos,
    output            HS,
    output            VS,
    output            LHBL,
    output            LVBL,
    output     [ 7:0] red,
    output     [ 7:0] green,
    output     [ 7:0] blue,
    output     [ 7:0] split_r,
    output     [ 7:0] split_g,
    output     [ 7:0] split_b,
    output            split_hs,
    output            split_vs,
    output            split_de,
    output            split_ce,
    output            split_field
);

wire [28:0] obj_do;
wire [17:0] dj;
wire [ 8:1] rovi;
wire [ 7:0] h_raw, h, v, objbuf_do, vcnt, vlatch;
wire [11:0] char_ad;
wire [ 4:0] bakc;
wire [ 3:0] txtc, dd_lo, bg_bakc;
wire [ 2:0] obj_clo, obj_chi;
wire [ 1:0] h_lo;
wire [ 1:0] obj_v, obj_vb, dbl_obj_v;
wire [ 2:0] obj_clob;
wire [ 5:0] dbl_obj_c;
wire [ 4:0] dbl_bakc;
wire [ 3:0] dbl_txtc;
wire        hb, h20, lhbl, txtv, bakc4, vtick, vhalf, initeo_a, initeo_b, fsel, dd7, do16,
            vs_raw, dbl_txtv, dbl_hbd_n, dbl_vb, dbl_lhbl, dbl_lvbl;

assign char_ad   = ad[11:0];
assign dd_lo     = dd[3:0];
assign objbuf_do = obj_do[7:0];
assign dd7       = dd[7];
assign do16      = obj_do[16];
assign bakc      = {bakc4, bg_bakc};
assign h_lo      = h_raw[1:0];
assign initeo_a  = ~rv;
assign initeo_b  = ~initeo_a;
assign fsel      = initeo ^ initeo_a;
assign pxl2_cen  = cen20 | pxl_cen;

always @(posedge clk) pxl_cen <= cen20;

jtpopeye_timing u_timing(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen10      ( cen10     ),
    .cen5       ( cen5      ),
    .rv         ( rv        ),
    .tprom_addr ( tprom_addr),
    .tprom_data ( tprom_data),
    .h_raw      ( h_raw     ),
    .hb         ( hb        ),
    .h          ( h         ),
    .h20        ( h20       ),
    .v          ( v         ),
    .vb         ( vb        ),
    .hbd_n      ( hbd_n     ),
    .ai_n       ( ai_n      ),
    .bi_n       ( bi_n      ),
    .initeo     ( initeo    ),
    .sy_n       (           ),
    .vtick      ( vtick     ),
    .vcnt       ( vcnt      ),
    .vlatch     ( vlatch    ),
    .vhalf      ( vhalf     ),
    .hs         (           ),
    .vs         ( vs_raw    ),
    .lhbl       ( lhbl      ),
    .lvbl       (           )
);

jtpopeye_char u_char(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen10      ( cen10     ),
    .cen5       ( cen5      ),
    .ad         ( char_ad   ),
    .dd         ( dd        ),
    .csv        ( csv       ),
    .memwr0     ( memwr0    ),
    .h_raw      ( h_raw     ),
    .hb         ( hb        ),
    .v          ( v         ),
    .vb         ( vb        ),
    .rv         ( rv        ),
    .char_addr  ( char_addr ),
    .char_data  ( char_data ),
    .txtv       ( txtv      ),
    .txtc       ( txtc      )
);

jtpopeye_bg u_bg(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen5       ( cen5      ),
    .cen10      ( cen10     ),
    .nibd7      ( nibd7     ),
    .tnx1       ( tnx1      ),
    .ad         ( ad        ),
    .dd         ( dd_lo     ),
    .dd7        ( dd7       ),
    .csbw_n     ( csbw_n    ),
    .dwrbk_n    ( dwrbk_n   ),
    .memwr0     ( memwr0    ),
    .rohvck     ( rohvck    ),
    .obj_do     ( objbuf_do ),
    .do16       ( do16      ),
    .rovi       ( rovi      ),
    .bakc       ( bg_bakc   )
);

jtpopeye_objbuf u_objbuf(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen5       ( cen5      ),
    .cen10      ( cen10     ),
    .h          ( h         ),
    .h20        ( h20       ),
    .hb         ( hb        ),
    .v          ( v         ),
    .rv         ( rv        ),
    .dm         ( dm        ),
    .dmcs_n     ( dmcs_n    ),
    .dd         ( dd        ),
    .rohvs      ( rohvs     ),
    .rohvck     ( rohvck    ),
    .obj_do     ( obj_do    ),
    .rovi       ( rovi      ),
    .dj         ( dj        ),
    .obj_c      ( obj_chi   ),
    .bakc4      ( bakc4     )
);

jtpopeye_obj u_obj(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen20      ( cen20     ),
    .cen10      ( cen10     ),
    .cen5       ( cen5      ),
    .h          ( h_lo      ),
    .hb         ( hb        ),
    .vb         ( vb        ),
    .rv         ( rv        ),
    .initeo     ( initeo_a  ),
    .dj         ( dj        ),
    .obj0_addr  ( obj0_addr ),
    .obj0_data  ( obj0_data ),
    .obj1_addr  ( obj1_addr ),
    .obj1_data  ( obj1_data ),
    .obj2_addr  ( obj2_addr ),
    .obj2_data  ( obj2_data ),
    .obj3_addr  ( obj3_addr ),
    .obj3_data  ( obj3_data ),
    .obj_v      ( obj_v     ),
    .obj_c      ( obj_clo   )
);

jtpopeye_obj u_objb(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen20      ( cen20     ),
    .cen10      ( cen10     ),
    .cen5       ( cen5      ),
    .h          ( h_lo      ),
    .hb         ( hb        ),
    .vb         ( vb        ),
    .rv         ( rv        ),
    .initeo     ( initeo_b  ),
    .dj         ( dj        ),
    .obj0_addr  (           ),
    .obj0_data  ( obj0_data ),
    .obj1_addr  (           ),
    .obj1_data  ( obj1_data ),
    .obj2_addr  (           ),
    .obj2_data  ( obj2_data ),
    .obj3_addr  (           ),
    .obj3_data  ( obj3_data ),
    .obj_v      ( obj_vb    ),
    .obj_c      ( obj_clob  )
);

jtpopeye_dbl u_dbl(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen20      ( cen20     ),
    .cen10      ( cen10     ),
    .cen5       ( cen5      ),
    .vtick      ( vtick     ),
    .vcnt       ( vcnt      ),
    .vlatch     ( vlatch    ),
    .vhalf      ( vhalf     ),
    .vs         ( vs_raw    ),
    .lhbl       ( lhbl      ),
    .txtv       ( txtv      ),
    .txtc       ( txtc      ),
    .bakc       ( bakc      ),
    .hbd_n      ( hbd_n     ),
    .vb         ( vb        ),
    .obj_chi    ( obj_chi   ),
    .obj_va     ( obj_v     ),
    .obj_ca     ( obj_clo   ),
    .obj_vb     ( obj_vb    ),
    .obj_cb     ( obj_clob  ),
    .txtv_o     ( dbl_txtv  ),
    .txtc_o     ( dbl_txtc  ),
    .bakc_o     ( dbl_bakc  ),
    .hbd_n_o    ( dbl_hbd_n ),
    .vb_o       ( dbl_vb    ),
    .obj_v_o    ( dbl_obj_v ),
    .obj_c_o    ( dbl_obj_c ),
    .lhbl_o     ( dbl_lhbl  ),
    .lvbl_o     ( dbl_lvbl  ),
    .hs_o       ( HS        ),
    .vs_o       ( VS        )
);

jtpopeye_colmix u_colmix(
    .rst          ( rst          ),
    .clk          ( clk          ),
    .pxl_cen      ( cen20        ),
    .hbd_n        ( dbl_hbd_n    ),
    .vb           ( dbl_vb       ),
    .lhbl         ( dbl_lhbl     ),
    .lvbl         ( dbl_lvbl     ),
    .txtv         ( dbl_txtv     ),
    .txtc         ( dbl_txtc     ),
    .obj_v        ( dbl_obj_v    ),
    .obj_c        ( dbl_obj_c    ),
    .bakc         ( dbl_bakc     ),
    .boot         ( boot         ),
    .tnx1         ( tnx1         ),
    .txtpal_addr  ( txtpal_addr  ),
    .txtpal_data  ( txtpal_data  ),
    .bgpal_addr   ( bgpal_addr   ),
    .bgpal_data   ( bgpal_data   ),
    .objpall_addr ( objpall_addr ),
    .objpall_data ( objpall_data ),
    .objpalh_addr ( objpalh_addr ),
    .objpalh_data ( objpalh_data ),
    .red          ( red          ),
    .green        ( green        ),
    .blue         ( blue         ),
    .LHBL         ( LHBL         ),
    .LVBL         ( LVBL         ),
    .gfx_en       ( gfx_en       )
);

jtpopeye_ana u_ana(
    .rst       ( rst         ),
    .clk       ( clk         ),
    .cen10     ( cen10       ),
    .cen20     ( cen20       ),
    .lhbl      ( lhbl        ),
    .vs        ( vs_raw      ),
    .vtick     ( vtick       ),
    .vlatch    ( vlatch      ),
    .fsel      ( fsel        ),
    .red       ( red         ),
    .green     ( green       ),
    .blue      ( blue        ),
    .LHBL      ( LHBL        ),
    .LVBL      ( LVBL        ),
    .deflicker ( deflicker   ),
    .narrow    ( narrow      ),
    .hpos      ( hpos        ),
    .vpos      ( vpos        ),
    .ana_r     ( split_r     ),
    .ana_g     ( split_g     ),
    .ana_b     ( split_b     ),
    .ana_hs    ( split_hs    ),
    .ana_vs    ( split_vs    ),
    .ana_de    ( split_de    ),
    .ana_ce    ( split_ce    ),
    .ana_field ( split_field )
);

endmodule
