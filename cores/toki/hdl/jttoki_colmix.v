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

module jttoki_colmix(
    input             clk,
    input             pxl_cen,
    input             cabal,
    input      [8:0]  hdump,
    input             lhbl, lvbl,

    input      [7:0]  fix_pxl,
    input      [7:0]  scr1_pxl,
    input      [7:0]  scr2_pxl,
    input      [7:0]  obj_pxl,
    input             bg_order,

    output reg [10:1] pal_addr,
    input      [15:0] pal_data,

    output reg [3:0]  red = 0,
    output reg [3:0]  green = 0,
    output reg [3:0]  blue = 0,

    input      [3:0]  gfx_en
);

localparam [1:0] OBJ  = 2'd0,
                 VRAM = 2'd1,
                 SCR1 = 2'd2,
                 SCR2 = 2'd3;

wire blank = ~lvbl | (~lhbl & hdump > 9'd1);
wire fix_visible    = cabal ? fix_pxl[1:0] != 2'd3 : fix_pxl[3:0] != 4'hf;
wire obj_visible    = obj_pxl[3:0] != 4'hf;
wire scr1_visible   = scr1_pxl[3:0] != 4'hf;
wire scr2_visible   = scr2_pxl[3:0] != 4'hf;
wire [10:1] fix_pal_addr  = cabal ? {2'b00, fix_pxl[7:2], fix_pxl[1:0]} : {VRAM, fix_pxl};
wire [10:1] obj_pal_addr  = cabal ? {2'b01, obj_pxl} : {OBJ, obj_pxl};
wire [10:1] scr1_pal_addr = cabal ? {2'b10, scr1_pxl} : {SCR1, scr1_pxl};

always @(posedge clk) begin
    if (gfx_en[0] && fix_visible)
        pal_addr <= fix_pal_addr;
    else if (gfx_en[3] && obj_visible)
        pal_addr <= obj_pal_addr;
    else if (cabal) begin
        if (gfx_en[1])
            pal_addr <= scr1_pal_addr;
        else
            pal_addr <= 'h3ff;
    end else begin
        if (!bg_order) begin
            if (gfx_en[1] && scr1_visible)
                pal_addr <= scr1_pal_addr;
            else if (gfx_en[2] && scr2_visible)
                pal_addr <= {SCR2, scr2_pxl};
            else
                pal_addr <= 'h3ff;
        end else begin
            if (gfx_en[2] && scr2_visible)
                pal_addr <= {SCR2, scr2_pxl};
            else if (gfx_en[1] && scr1_visible)
                pal_addr <= scr1_pal_addr;
            else
                pal_addr <= 'h3ff;
        end
    end
end

always @(posedge clk) begin
    if (pxl_cen) begin
        red   <= blank ? 4'd0 : pal_data[ 3:0];
        green <= blank ? 4'd0 : pal_data[ 7:4];
        blue  <= blank ? 4'd0 : pal_data[11:8];
    end
end

endmodule
