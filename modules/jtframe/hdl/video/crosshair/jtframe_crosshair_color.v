/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
    Version: 1.0
    Date: 27-02-2025 */

module jtframe_crosshair_color #(parameter COLORW=4)(
    input                 clk,
    input                 draw_en,
    input  [         2:0] cross_disable,
    input  [         5:0] crosshair,
    input  [  COLORW-1:0] rin,
    input  [  COLORW-1:0] gin,
    input  [  COLORW-1:0] bin,
    output [3*COLORW-1:0] rgb_cross
    );

reg [COLORW-1:0] r_cross, g_cross, b_cross;

assign rgb_cross = {r_cross, g_cross, b_cross};

always @(posedge clk) begin
    if(draw_en && crosshair[0]) begin
        r_cross <= ~rin;
        g_cross <= ~gin;
        b_cross <= ~bin;
    end else begin 
        r_cross <= rin;
        g_cross <= gin;
        b_cross <= bin;
    end
end

endmodule