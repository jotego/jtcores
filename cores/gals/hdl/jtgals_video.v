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
    Date: 12-7-2026 */

module jtgals_video(
    input              rst,
    input              clk,
    input              pxl_cen,
    input       [ 3:0] gfx_en,
    output      [ 7:0] game_vrender,
    output      [ 8:0] game_hdump,
    output      [ 8:0] ln_addr,
    output      [15:0] ln_data,
    output             ln_done,
    input              ln_hs,
    input       [15:0] ln_dout,
    input       [15:0] ln_pxl,
    input       [ 7:0] ln_v,
    input              ln_vs,
    input              ln_lvbl,
    output             ln_we,

    output      [16:1] fg_video_addr,
    input       [15:0] fg_video_dout,
    output      [16:1] bg_video_addr,
    input       [15:0] bg_video_dout,
    output      [10:1] pal_video_addr,
    input       [15:0] pal_video_dout,
    output      [12:1] objram_video_addr,
    input       [15:0] objram_video_dout,
    output             obj_cs,
    output      [19:2] obj_addr,
    input       [31:0] obj_data,
    input              obj_ok,

    output             LHBL,
    output             LVBL,
    output             HS,
    output             VS,
    output      [ 8:0] vdump,
    output      [ 4:0] red,
    output      [ 4:0] green,
    output      [ 4:0] blue
);

localparam [8:0] HB_END = 9'd383;

wire [ 8:0] hdump, h_addr, vrender;
wire [ 7:0] bmp_h_addr, bmp_v_addr;
wire [15:0] pal_data;
wire [ 7:0] obj_pxl, obj_pxl_raw;
wire        pxl_blank, h0_prefetch, h1_prefetch;

assign game_hdump        = h1_prefetch ? 9'h1ff :
                           h0_prefetch ? 9'd0 :
                           hdump + 9'd1;
assign game_vrender     = vrender[7:0];
assign h1_prefetch       = hdump == HB_END - 9'd1;
assign h0_prefetch       = hdump == HB_END;
assign h_addr            = h0_prefetch ? 9'd0 : hdump + 9'd1;
assign bmp_h_addr        = 8'hff - h_addr[7:0];
assign bmp_v_addr        = 8'd223 - vdump[7:0];
assign fg_video_addr     = { bmp_v_addr, bmp_h_addr };
assign bg_video_addr     = { bmp_v_addr, bmp_h_addr };
assign pxl_blank         = ~((LHBL | h0_prefetch) & LVBL);
assign pal_data          = pal_video_dout;
assign obj_pxl           = obj_pxl_raw;

jtframe_vtimer #(
    .VB_START   ( 9'd223 ),
    .VB_END     ( 9'd263 ),
    .VS_START   ( 9'd241 ),
    .VS_END     ( 9'd245 ),
    .HB_START   ( 9'd255 ),
    .HB_END     ( HB_END ),
    .HS_START   ( 9'd303 ),
    .HS_END     ( 9'd335 )
) u_vtimer(
    .clk        ( clk     ),
    .pxl_cen    ( pxl_cen ),
    .vdump      ( vdump   ),
    .vrender    ( vrender ),
    .vrender1   (         ),
    .H          ( hdump   ),
    .Hinit      (         ),
    .Vinit      (         ),
    .LHBL       ( LHBL    ),
    .LVBL       ( LVBL    ),
    .HS         ( HS      ),
    .VS         ( VS      )
);

jtgals_obj u_obj(
    .rst          ( rst               ),
    .clk          ( clk               ),
    .pxl_cen      ( pxl_cen           ),
    .lvbl         ( LVBL              ),
    .ln_addr      ( ln_addr           ),
    .ln_data      ( ln_data           ),
    .ln_done      ( ln_done           ),
    .ln_hs        ( ln_hs             ),
    .ln_dout      ( ln_dout           ),
    .ln_pxl       ( ln_pxl            ),
    .ln_v         ( ln_v              ),
    .ln_vs        ( ln_vs             ),
    .ln_lvbl      ( ln_lvbl           ),
    .ln_we        ( ln_we             ),
    .ram_addr     ( objram_video_addr ),
    .ram_dout     ( objram_video_dout ),
    .rom_cs       ( obj_cs            ),
    .rom_addr     ( obj_addr          ),
    .rom_data     ( obj_data          ),
    .rom_ok       ( obj_ok            ),
    .pxl          ( obj_pxl_raw       )
);

jtgals_colmix u_colmix(
    .clk        ( clk            ),
    .pxl_cen    ( pxl_cen        ),
    .gfx_en     ( gfx_en         ),
    .pxl_blank  ( pxl_blank      ),
    .fg_data    ( fg_video_dout  ),
    .bg_data    ( bg_video_dout  ),
    .obj_pxl    ( obj_pxl        ),
    .pal_data   ( pal_data       ),
    .pal_addr   ( pal_video_addr ),
    .red        ( red            ),
    .green      ( green          ),
    .blue       ( blue           )
);

endmodule
