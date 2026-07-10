/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 1-7-2025 */

module jttoki_video(
    input             rst,

    // Clock
    input             clk,
    input             pxl_cen,
    input             pxl2_cen,
    input             cabal,

    output            hsync,
    output            vsync,
    output            lhbl, lvbl,

    // RGB out
    output [3:0]      red,
    output [3:0]      green,
    output [3:0]      blue,

    // Shared video RAM
    output     [10:1] pal_addr,
    input      [15:0] pal_data,

    output     [10:1] vram_addr,
    input      [15:0] vram_out,

    output     [10:1] scr1_addr,
    input      [15:0] scr1_out,

    output     [10:1] scr2_addr,
    input      [15:0] scr2_out,

    output     [10:1] sprite_addr,
    input      [15:0] sprite_out,

    // ROM data
    input      [15:0] gfx1_data,
    input             gfx1_ok,
    output     [15:1] gfx1_addr,
    output            gfx1_cs,

    input      [15:0] gfx1_hi_data,
    input             gfx1_hi_ok,
    output     [15:1] gfx1_hi_addr,
    output            gfx1_hi_cs,

    input      [15:0] gfx2_data,
    input             gfx2_ok,
    output     [19:1] gfx2_addr,
    output            gfx2_cs,

    input      [31:0] gfx3_data,
    input             gfx3_ok,
    output     [18:2] gfx3_addr,
    output            gfx3_cs,

    input      [31:0] gfx4_data,
    input             gfx4_ok,
    output     [18:2] gfx4_addr,
    output            gfx4_cs,

    input      [8:0]  scr1_scroll_x,
    input      [8:0]  scr1_scroll_y,
    input      [8:0]  scr2_scroll_x,
    input      [8:0]  scr2_scroll_y,
    input             bg_order,

    // Debug
    input       [3:0] gfx_en
);

wire [7:0] fix_pxl, scr1_pxl, scr2_pxl, obj_pxl;
wire [8:0] hdump, vdump, vrender;
wire [7:0] line_number = vrender[7:0];
wire [10:1] toki_scr2_addr;
wire [18:2] toki_gfx4_addr;
wire        toki_gfx4_cs;

assign scr2_addr   = cabal ? 10'd0             : toki_scr2_addr;
assign gfx4_addr   = toki_gfx4_addr;
assign gfx4_cs     = cabal ? 1'b0              : toki_gfx4_cs;

jtframe_vtimer #(
    .V_START    ( 9'd0   ),
    .VB_START   ( 9'd240 ),
    .VB_END     ( 9'd16  ),
    .VS_START   ( 9'd250 ),
    .VS_END     ( 9'd253 ),
    .VCNT_END   ( 9'd261 ),

    .HB_START   ( 9'h189 ),
    .HB_END     ( 9'h009 ),
    .HS_START   ( 9'h1ab ),
    .HS_END     ( 9'h1cb ),
    .HJUMP      ( 1      ),
    .H_VB       ( 9'h1ff ),
    .H_VS       ( 9'h1ab ),
    .H_VNEXT    ( 9'h1ff ),
    .HCNT_END   ( 9'h1ff ),
    .HINIT      ( 9'h1ff )
) u_vtimer(
    .clk        ( clk     ),
    .pxl_cen    ( pxl_cen ),
    .vdump      ( vdump   ),
    .vrender    ( vrender ),
    .vrender1   (         ),
    .H          ( hdump    ),
    .Hinit      (         ),
    .Vinit      (         ),
    .LHBL       ( lhbl    ),
    .LVBL       ( lvbl    ),
    .HS         ( hsync   ),
    .VS         ( vsync   )
);

jttoki_fix u_fix(
    .rst          ( rst           ),
    .clk          ( clk           ),
    .pxl_cen      ( pxl_cen       ),
    .cabal        ( cabal         ),

    .hdump        ( hdump         ),
    .vdump        ( vdump         ),
    .blankn       ( lvbl          ),

    .ram_addr     ( vram_addr     ),
    .ram_out      ( vram_out      ),

    .gfx_data     ( gfx1_data     ),
    .gfx_ok       ( gfx1_ok       ),
    .gfx_addr     ( gfx1_addr     ),
    .gfx_cs       ( gfx1_cs       ),

    .gfx_hi_data  ( gfx1_hi_data  ),
    .gfx_hi_ok    ( gfx1_hi_ok    ),
    .gfx_hi_addr  ( gfx1_hi_addr  ),
    .gfx_hi_cs    ( gfx1_hi_cs    ),

    .pxl          ( fix_pxl       )
);

jttoki_scroll u_scr1(
    .rst          ( rst            ),
    .clk          ( clk            ),
    .pxl_cen      ( pxl_cen        ),
    .cabal        ( cabal          ),

    .hdump        ( hdump          ),
    .vdump        ( vdump          ),
    .hs           ( hsync          ),
    .line_number  ( line_number    ),

    .scroll_x     ( scr1_scroll_x ),
    .scroll_y     ( scr1_scroll_y ),

    .vram_addr    ( scr1_addr      ),
    .vram_out     ( scr1_out       ),

    .gfx_data     ( gfx3_data      ),
    .gfx_ok       ( gfx3_ok        ),
    .gfx_addr     ( gfx3_addr      ),
    .gfx_cs       ( gfx3_cs        ),

    .pxl          ( scr1_pxl       )
);

jttoki_scroll u_scr2(
    .rst          ( rst            ),
    .clk          ( clk            ),
    .pxl_cen      ( pxl_cen        ),
    .cabal        ( 1'b0           ),

    .hdump        ( hdump          ),
    .vdump        ( vdump          ),
    .hs           ( hsync          ),
    .line_number  ( line_number    ),

    .scroll_x     ( scr2_scroll_x ),
    .scroll_y     ( scr2_scroll_y ),

    .vram_addr    ( toki_scr2_addr ),
    .vram_out     ( scr2_out       ),

    .gfx_data     ( gfx4_data      ),
    .gfx_ok       ( gfx4_ok        ),
    .gfx_addr     ( toki_gfx4_addr ),
    .gfx_cs       ( toki_gfx4_cs   ),

    .pxl          ( scr2_pxl       )
);

jttoki_obj u_obj(
    .clk              ( clk                     ),
    .rst              ( rst                     ),
    .pxl_cen          ( pxl_cen                 ),
    .cabal            ( cabal                   ),
    .hs               ( hsync                   ),

    .hdump            ( hdump                   ),
    .vrender          ( vrender                 ),

    .lut_addr         ( sprite_addr             ),
    .lut_dout         ( sprite_out              ),

    .gfx_data         ( gfx2_data               ),
    .gfx_ok           ( gfx2_ok                 ),
    .gfx_addr         ( gfx2_addr               ),
    .gfx_cs           ( gfx2_cs                 ),

    .pxl              ( obj_pxl                 )
);

jttoki_colmix u_colmix(
    .clk          ( clk             ),
    .pxl_cen      ( pxl_cen         ),
    .cabal        ( cabal           ),
    .hdump        ( hdump           ),
    .lhbl         ( lhbl            ),
    .lvbl         ( lvbl            ),
    .gfx_en       ( gfx_en          ),

    .fix_pxl      ( fix_pxl         ),
    .scr1_pxl     ( scr1_pxl        ),
    .scr2_pxl     ( scr2_pxl        ),
    .obj_pxl      ( obj_pxl         ),
    .bg_order     ( bg_order        ),

    .pal_addr     ( pal_addr        ),
    .pal_data     ( pal_data        ),

    .red          ( red             ),
    .green        ( green           ),
    .blue         ( blue            )
);

endmodule
