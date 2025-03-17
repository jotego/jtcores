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
    Date: 14-03-2025 */

module jtframe_lightgun_position(
    input             rst,
    input             clk,
    input             gun_border_en,
    input      [ 8:0] m_x, m_y, // mouse
    input             m_strobe,
    input      [ 8:0] a_x, a_y, // analog stick
    input             a_strobe,
    output reg [ 8:0] x,
    output reg [ 8:0] y,
    output reg [ 8:0] x_abs,
    output reg [ 8:0] y_abs,
    output reg        strobe
);

parameter XOFFSET=0, YOFFSET=0;

`ifndef JTFRAME_RELEASE
always @(posedge clk) strobe <= m_strobe | (a_strobe & gun_border_en);
`else
always @(posedge clk) strobe <= m_strobe;
`endif

always @(posedge clk) begin
    if(rst) begin
        x      <= 0; y      <= 0;
        x_abs  <= 0; y_abs  <= 0;
    end else begin
        x <= x_abs + XOFFSET[8:0];
        y <= y_abs + YOFFSET[8:0];

        if (a_strobe) begin
            x_abs <= a_x;
            y_abs <= a_y;
        end
        if (m_strobe) begin
            x_abs <= m_x;
            y_abs <= m_y;
        end
    end
end

endmodule
