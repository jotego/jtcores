/*  jtmnymny_video.v — 1B11140 video board top
    vtimer + scroll/obj + palette PROM mixing. RAMs/PROMs live in mem.yaml.
    GPL3 — see jtcores LICENSE
*/

module jtmnymny_video(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               pxl2_cen,
    input               flip_x,
    input               flip_y,
    // tile RAM / attribute RAM / object RAM (video ports)
    output      [10:0]  vram_v_addr,
    input       [ 7:0]  vram_v_dout,
    output      [ 5:0]  attr_v_addr,
    input       [ 7:0]  attr_v_dout,
    output      [ 7:0]  objram_v_addr,
    input       [ 7:0]  objram_v_dout,
    // palette PROMs
    output      [ 8:0]  pal_addr,
    input       [ 3:0]  pal9f_data,
    input       [ 3:0]  pal9g_data,
    // SDRAM
    output      [12:0]  scr_addr,
    output              scr_cs,
    input       [31:0]  scr_data,
    input               scr_ok,
    output      [12:0]  objgfx_addr,
    output              objgfx_cs,
    input       [31:0]  objgfx_data,
    input               objgfx_ok,
    // video out
    output      [ 3:0]  red, green, blue,
    output              LHBL, LVBL, HS, VS
);

wire [ 8:0] vdump, vrender, hdump;
wire        hinit, preLHBL, preLVBL;
wire [ 8:0] obj_pxl, scr_pxl;
wire [ 3:0] pre_r, pre_g, pre_b;

jtframe_vtimer #(
    .VCNT_END   (  9'd263   ),
    .VB_START   (  9'd239   ),
    .VB_END     (  9'd015   ),
    // V counters reload at 248 (3N/4N presets); VSYNC = 256V low = 8 lines
    // right before active video (vdump 8-15)
    .VS_START   (  9'd8     ),
    .VS_END     (  9'd16    ),
    .HCNT_END   (  9'd383   ),
    .HB_START   (  9'd255   ),
    .HB_END     (  9'd383   ),
    // 5M/5J/5K: 16H edges at H=176/208 inside the 32H&/64H window (/PRE=/256H)
    .HS_START   (  9'h130   ),
    .HS_END     (  9'h150   )
) u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   (           ),
    .H          ( hdump     ),
    .Hinit      ( hinit     ),
    .Vinit      (           ),
    .LHBL       ( preLHBL   ),
    .LVBL       ( preLVBL   ),
    .HS         ( HS        ),
    .VS         ( VS        )
);

// data path lags the counters by 2 pxl (PROM read + output register)
jtframe_blank #(.DLY(2),.DW(12)) u_blank(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .preLHBL    ( preLHBL   ),
    .preLVBL    ( preLVBL   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .preLBL     (           ),
    .rgb_in     ( {pre_r, pre_g, pre_b} ),
    .rgb_out    ( {red, green, blue}    )
);

jtmnymny_scroll u_scroll(
    .rst       ( rst          ),
    .clk       ( clk          ),
    .pxl_cen   ( pxl_cen      ),
    .hs        ( HS           ),
    .hdump     ( hdump        ),
    .vdump     ( vdump        ),
    .blankn    ( LVBL         ),
    .flip      ( flip_x       ),
    .attr_addr ( attr_v_addr  ),
    .attr_data ( attr_v_dout  ),
    .vram_addr ( vram_v_addr  ),
    .vram_data ( vram_v_dout  ),
    .rom_addr  ( scr_addr     ),
    .rom_cs    ( scr_cs       ),
    .rom_data  ( scr_data     ),
    .rom_ok    ( scr_ok       ),
    .pxl       ( scr_pxl      )
);

jtmnymny_obj u_obj(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( HS            ),
    .hdump      ( hdump         ),
    .vrender    ( vrender       ),
    .flip       ( flip_x        ),
    .objram_addr( objram_v_addr ),
    .objram_data( objram_v_dout ),
    .rom_addr   ( objgfx_addr   ),
    .rom_cs     ( objgfx_cs     ),
    .rom_data   ( objgfx_data   ),
    .rom_ok     ( objgfx_ok     ),
    .pxl        ( obj_pxl       )
);

jtmnymny_colmix u_colmix(
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .scr_pxl    ( scr_pxl       ),
`ifdef NOOBJ
    .obj_pxl    ( 9'd0          ),
`else
    .obj_pxl    ( obj_pxl       ),
`endif
    .pal_addr   ( pal_addr      ),
    .pal9f_data ( pal9f_data    ),
    .pal9g_data ( pal9g_data    ),
    .red        ( pre_r         ),
    .green      ( pre_g         ),
    .blue       ( pre_b         )
);

endmodule
