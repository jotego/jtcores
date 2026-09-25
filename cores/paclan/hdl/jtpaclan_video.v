/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-5-2025 */

module jtpaclan_video(
    input             rst,
    input             clk,
    input             pxl_cen, pxl2_cen, flip, skykid, rot,

    output            lvbl, lhbl, hs, vs,
    input      [ 1:0] palbank,
    input      [ 8:0] scr0_pos, scr1_pos, scrx,
    input      [ 7:0] scry, pri,

    output     [12:1] oram_addr,
    output     [11:1] vram0_addr, vram1_addr,
    input      [15:0] vram0_dout, vram1_dout, oram_dout,

    // ROMs
    output            scr0_cs,   scr1_cs,
    output     [12:1] scr0_addr, scr1_addr,
    input      [15:0] scr0_data, scr1_data,
    input             scr0_ok,   scr1_ok,
    output            obj_cs,
    output     [15:2] obj_addr,
    input      [31:0] obj_data,
    input             obj_ok,

    // Palette PROMs
    output     [ 9:0] scr0pal_addr, scr1pal_addr, objpal_addr,
    input      [ 7:0] scr0pal_data, scr1pal_data, objpal_data,

    output     [ 9:0] rgb_addr,
    input      [ 7:0] rg_data,
    input      [ 3:0] b_data,
    output     [ 3:0] red, green, blue,

    // Debug
    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

wire [ 9:0] scr0_pxl, scr1_pxl, pl_scr0pal_addr, pl_scr1pal_addr, pl_rgb_addr;
wire [11:1] pl_vram0_addr, pl_vram1_addr, sk_vram1_addr;
wire [10:1] sk_vram0_addr;
wire [12:1] pl_scr0_addr, pl_scr1_addr, sk_scr0_addr, sk_scr1_addr;
wire [ 7:0] obj_pxl, sk_rgb_addr;
wire [ 8:0] hdump, vdump, vrender, vrender1;
wire [ 6:0] sk_scr_pal;
wire [ 5:0] sk_txt_pal;
wire [ 3:0] sk_txt_cat, pl_red, pl_green, pl_blue, sk_red, sk_green, sk_blue;
wire [ 1:0] sk_scr_pxl, sk_txt_pxl;
wire        scr0_prio, fixed, pl_scr0_cs, pl_scr1_cs, sk_scr0_cs, sk_scr1_cs;

assign st_dout      = 0;
assign vram0_addr   = skykid ? {1'b0,sk_vram0_addr} : pl_vram0_addr;
assign vram1_addr   = skykid ? sk_vram1_addr : pl_vram1_addr;
assign scr0_cs      = skykid ? sk_scr0_cs    : pl_scr0_cs;
assign scr1_cs      = skykid ? sk_scr1_cs    : pl_scr1_cs;
assign scr0_addr    = skykid ? sk_scr0_addr  : pl_scr0_addr;
assign scr1_addr    = skykid ? sk_scr1_addr  : pl_scr1_addr;
assign scr0pal_addr = skykid ? {2'd0,sk_rgb_addr} : pl_scr0pal_addr;
assign scr1pal_addr = skykid ? {1'b0,sk_scr_pal,sk_scr_pxl} : pl_scr1pal_addr;
assign rgb_addr     = skykid ? {2'd0,sk_rgb_addr} : pl_rgb_addr;
assign {red,green,blue} = skykid ? {sk_red,sk_green,sk_blue} : {pl_red,pl_green,pl_blue};

jtshouse_vtimer u_vtimer(
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .vrender1   ( vrender1      ),
    .hdump      ( hdump         ),
    .lhbl       ( lhbl          ),
    .lvbl       ( lvbl          ),
    .hs         ( hs            ),
    .vs         ( vs            )
);

jtcus36 u_scroll(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( hs            ),
    .flip       ( flip          ),
    .fixed      ( fixed         ),
    .scr0_pos   ( scr0_pos      ),
    .scr1_pos   ( scr1_pos      ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),

    .vram0_addr ( pl_vram0_addr ),
    .vram0_dout ( vram0_dout    ),

    .vram1_addr ( pl_vram1_addr ),
    .vram1_dout ( vram1_dout    ),

    .rom0_cs    ( pl_scr0_cs    ),
    .rom0_addr  ( pl_scr0_addr  ),
    .rom0_data  ( scr0_data     ),
    .rom0_ok    ( scr0_ok       ),

    .rom1_cs    ( pl_scr1_cs    ),
    .rom1_addr  ( pl_scr1_addr  ),
    .rom1_data  ( scr1_data     ),
    .rom1_ok    ( scr1_ok       ),

    .prio0      ( scr0_prio     ),
    .pxl0       ( scr0_pxl      ),
    .pxl1       ( scr1_pxl      ),
    // debug
    .debug_bus  ( debug_bus     )
);

jtpaclan_obj u_obj(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .lvbl       ( lvbl          ),
    .hs         ( hs            ),
    .flip       ( flip          ),
    .skykid     ( skykid        ),
    .rot        ( rot           ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),

    // Look-up table
    .ram_addr   ( oram_addr     ),
    .ram_dout   ( oram_dout     ),
    .pal_addr   ( objpal_addr   ),
    .pal_data   ( objpal_data   ),

    .rom_cs     ( obj_cs        ),
    .rom_addr   ( obj_addr      ),
    .rom_data   ( obj_data      ),
    .rom_ok     ( obj_ok        ),

    .pxl        ( obj_pxl       ),

    .debug_bus  ( debug_bus     )
);

jtpaclan_colmix u_colmix(
    .clk          ( clk             ),
    .pxl_cen      ( pxl_cen         ),
    .pxl2_cen     ( pxl2_cen        ),
    .palbank      ( palbank         ),
    .fixed        ( fixed           ),

    .scr0pal_addr ( pl_scr0pal_addr ),
    .scr1pal_addr ( pl_scr1pal_addr ),
    .scr0pal_data ( scr0pal_data    ),
    .scr1pal_data ( scr1pal_data    ),

    .scr0_pxl     ( scr0_pxl        ),
    .scr1_pxl     ( scr1_pxl        ),
    .obj_pxl      ( obj_pxl         ),
    .scr0_prio    ( scr0_prio       ),

    .rgb_addr     ( pl_rgb_addr     ),
    .rg_data      ( rg_data         ),
    .b_data       ( b_data          ),

    .red          ( pl_red          ),
    .green        ( pl_green        ),
    .blue         ( pl_blue         ),
    .gfx_en       ( gfx_en          )
);

jtskykid_text u_sktext(
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .flip       ( flip ^ rot    ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),

    .vram_addr  ( sk_vram0_addr ),
    .vram_dout  ( vram0_dout    ),

    .rom_cs     ( sk_scr0_cs    ),
    .rom_addr   ( sk_scr0_addr  ),
    .rom_data   ( scr0_data     ),
    .rom_ok     ( scr0_ok       ),

    .pal        ( sk_txt_pal    ),
    .cat        ( sk_txt_cat    ),
    .pxl        ( sk_txt_pxl    )
);

jtskykid_scroll u_skscroll(
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .flip       ( flip          ),
    .rot        ( rot           ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),
    .scrx       ( scrx          ),
    .scry       ( scry          ),

    .vram_addr  ( sk_vram1_addr ),
    .vram_dout  ( vram1_dout    ),

    .rom_cs     ( sk_scr1_cs    ),
    .rom_addr   ( sk_scr1_addr  ),
    .rom_data   ( scr1_data     ),
    .rom_ok     ( scr1_ok       ),

    .pal        ( sk_scr_pal    ),
    .pxl        ( sk_scr_pxl    )
);

jtskykid_colmix u_skcolmix(
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .pri        ( pri           ),

    .txt_pal    ( sk_txt_pal    ),
    .txt_cat    ( sk_txt_cat    ),
    .txt_pxl    ( sk_txt_pxl    ),
    .obj_pxl    ( obj_pxl       ),
    .scrpal_data( scr1pal_data  ),

    .rgb_addr   ( sk_rgb_addr   ),
    .r_data     ( rg_data[3:0]  ),
    .g_data     ( b_data        ),
    .b_data     ( scr0pal_data[3:0] ),
    .red        ( sk_red        ),
    .green      ( sk_green      ),
    .blue       ( sk_blue       ),
    .gfx_en     ( gfx_en        )
);

endmodule    
