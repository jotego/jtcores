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

    Author: aCORES
    Version: 1.0
    Date: 18-8-2026 */

module jtdcastl_colmix(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             lvbl,
    input             lhbl,

    input             low_pen_priority,

    input       [3:0] tile_pen,
    input       [4:0] tile_color,

    input       [9:0] sprite_pixel,

    output      [7:0] pal_addr,
    input       [7:0] pal_dout,

    output reg  [3:0] red,
    output reg  [3:0] green,
    output reg  [3:0] blue,

    input       [7:0] debug_bus,
    input       [3:0] gfx_en
);

wire blank_n = lvbl & lhbl;

// Tile/sprite priority mux and PROM address (tile_attr renamed tile_color).
wire [3:0] tile_pen_en  = gfx_en[0] ? tile_pen : 4'd0;
wire [9:0] sprite_en    = gfx_en[3] ? sprite_pixel : 10'd0;
wire       tile_front   = low_pen_priority ? ~tile_pen[3] : tile_pen[3];
wire       use_sprite   = !tile_front && sprite_en[9] && sprite_en[8];
wire [4:0] final_color  = use_sprite ? sprite_en[7:3] : tile_color;
wire [2:0] final_pen    = use_sprite ? sprite_en[2:0] : tile_pen_en[2:0];

assign pal_addr = {final_color, final_pen};

// PROM resistor network, matching MAME's 0x23/0x4b/0x91 and 0x52/0xad.
// DO NOT alter these weights.
wire [7:0] r_full = (pal_dout[5] ? 8'h23 : 8'h00) + (pal_dout[6] ? 8'h4b : 8'h00) + (pal_dout[7] ? 8'h91 : 8'h00);
wire [7:0] g_full = (pal_dout[2] ? 8'h23 : 8'h00) + (pal_dout[3] ? 8'h4b : 8'h00) + (pal_dout[4] ? 8'h91 : 8'h00);
wire [7:0] b_full = (pal_dout[0] ? 8'h52 : 8'h00) + (pal_dout[1] ? 8'had : 8'h00);

always @(posedge clk) begin
    if (pxl_cen) begin
        red   <= blank_n ? r_full[7:4] : 4'd0;
        green <= blank_n ? g_full[7:4] : 4'd0;
        blue  <= blank_n ? b_full[7:4] : 4'd0;
    end
end

endmodule
