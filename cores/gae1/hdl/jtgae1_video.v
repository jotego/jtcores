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
    Date: 2-7-2026 */

module jtgae1_video #(
    parameter integer LAT    = 13,
    parameter integer DEADJ  = 0,
    parameter integer VTOTAL = 272
)(
    input        clk,
    input        rst,
    input        pxl_cen,
    input [3:0]  gfx_en,
    input        gfx_4m,
    input        squash,
    input        bigkarnk,
    input [5:0]  spr_force_high,

    input [15:0] scr0_y, scr0_x, scr1_y, scr1_x,

    output [10:0] tile_a0, input [31:0] tile_q0,
    output [21:2] rom_a0,  input [31:0] gfx0_data, input gfx0_ok,
    output [10:0] tile_a1, input [31:0] tile_q1,
    output [21:2] rom_a1,  input [31:0] gfx1_data, input gfx1_ok,

    output [9:0]  color_addr,     input [15:0] color_data,
    output [9:0]  spr_color_addr, input [15:0] spr_color_data,

    output [10:0] spr_a,   input [15:0] spr_q,
    output        obj_cs,
    output [21:2] obj_addr,
    input [31:0]  obj_data,
    input         obj_ok,

    output [4:0]  red, green, blue,
    output        hsync, vsync, hblank, vblank
);

localparam HVIS     = 320;
localparam HFP      = 18;
localparam HSW      = 28;
localparam HBP      = 18;
localparam VVIS     = 240;
localparam VFP      = 8;
localparam VSW      = 8;
localparam HS_START = HVIS + HFP;
localparam HS_END   = HVIS + HFP + HSW;
localparam VS_START = VVIS + VFP;
localparam VS_END   = VVIS + VFP + VSW;
localparam HTOTAL   = HVIS + HFP + HSW + HBP;
localparam HCNT_END = HTOTAL[8:0] - 9'd1;
localparam VCNT_END = VTOTAL[8:0] - 9'd1;
localparam SD       = LAT + DEADJ;

wire [ 9:0] hpos;
wire [ 8:0] vpos;
wire [ 8:0] render_hpos;
wire [ 8:0] render_vpos;
wire [ 8:0] hdump;
wire [ 8:0] vdump;
wire [12:0] obj_pxl;
wire        hs_i, vs_i, hb_i, vb_i;
wire        hblank_n, vblank_n;
wire        frame_vblank;

jtframe_vtimer #(
    .HCNT_END ( HCNT_END      ),
    .HB_START ( HVIS[8:0]    ),
    .HB_END   ( 9'd0         ),
    .HS_START ( HS_START[8:0] ),
    .HS_END   ( HS_END[8:0]   ),
    .VCNT_END ( VCNT_END      ),
    .VB_START ( VVIS[8:0]    ),
    .VB_END   ( 9'd0         ),
    .VS_START ( VS_START[8:0] ),
    .VS_END   ( VS_END[8:0]   )
) u_vtimer (
    .clk      ( clk     ),
    .pxl_cen  ( pxl_cen ),
    .vdump    ( vdump   ),
    .vrender  (         ),
    .vrender1 (         ),
    .H        ( hdump   ),
    .Hinit    (         ),
    .Vinit    (         ),
    .LHBL     ( hblank_n ),
    .LVBL     ( vblank_n ),
    .HS       ( hs_i    ),
    .VS       ( vs_i    )
);

reg hblank_r, vblank_r;
always @(posedge clk) if (pxl_cen) begin
    hblank_r <= ~hblank_n;
    vblank_r <= ~vblank_n;
end

assign hpos        = {1'b0, hdump};
assign vpos        = vdump;
assign render_hpos = hpos[8:0] - 9'd4;
assign render_vpos = vpos - 9'd1;
assign hb_i        = hblank_r;
assign vb_i        = vblank_r;
assign frame_vblank = (vdump == 9'd0) || (vdump > VVIS[8:0]);

wire [11:0] scr0_pxl, scr1_pxl;
jtgae1_scroll u_scroll (
    .clk       ( clk       ),
    .rst       ( rst       ),
    .pxl_cen   ( pxl_cen   ),
    .gfx_4m    ( gfx_4m     ),
    .hsync     ( hs_i      ),
    .hpos      ( render_hpos ),
    .vpos      ( render_vpos ),
    .scr0_y    ( scr0_y    ),
    .scr0_x    ( scr0_x    ),
    .scr1_y    ( scr1_y    ),
    .scr1_x    ( scr1_x    ),
    .tile_a0   ( tile_a0   ),
    .tile_q0   ( tile_q0   ),
    .rom_a0    ( rom_a0    ),
    .gfx0_data ( gfx0_data ),
    .gfx0_ok   ( gfx0_ok   ),
    .tile_a1   ( tile_a1   ),
    .tile_q1   ( tile_q1   ),
    .rom_a1    ( rom_a1    ),
    .gfx1_data ( gfx1_data ),
    .gfx1_ok   ( gfx1_ok   ),
    .scr0_pxl  ( scr0_pxl  ),
    .scr1_pxl  ( scr1_pxl  )
);

jtgae1_obj #(
    .VTOTAL ( VTOTAL )
) u_obj (
    .clk            ( clk            ),
    .rst            ( rst            ),
    .pxl_cen        ( pxl_cen        ),
    .hs             ( hs_i           ),
    .vpos           ( render_vpos    ),
    .hpos           ( render_hpos    ),
    .spr_force_high ( spr_force_high ),
    .spr_a          ( spr_a          ),
    .spr_q          ( spr_q          ),
    .rom_cs         ( obj_cs         ),
    .rom_addr       ( obj_addr       ),
    .rom_data       ( obj_data       ),
    .rom_ok         ( obj_ok         ),
    .pxl            ( obj_pxl        )
);

jtgae1_colmix u_colmix (
    .clk            ( clk            ),
    .pxl_cen        ( pxl_cen        ),
    .squash         ( squash         ),
    .bigkarnk       ( bigkarnk       ),
    .gfx_en         ( gfx_en         ),
    .scr0_pxl       ( scr0_pxl       ),
    .scr1_pxl       ( scr1_pxl       ),
    .color_addr     ( color_addr     ),
    .color_data     ( color_data     ),
    .obj_pxl        ( obj_pxl        ),
    .spr_color_addr ( spr_color_addr ),
    .spr_color_data ( spr_color_data ),
    .red            ( red            ),
    .green          ( green          ),
    .blue           ( blue           )
);

reg [SD-1:0] hs_sr, vs_sr, hb_sr, vb_sr;
always @(posedge clk) if (pxl_cen) begin
    hs_sr <= {hs_sr[SD-2:0], hs_i};
    vs_sr <= {vs_sr[SD-2:0], vs_i};
    hb_sr <= {hb_sr[SD-2:0], hb_i};
    vb_sr <= {vb_sr[SD-2:0], vb_i};
end
assign hsync  = hs_sr[SD-1];
assign vsync  = vs_sr[SD-1];
assign hblank = hb_sr[SD-1];
assign vblank = frame_vblank;

endmodule
