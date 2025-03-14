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

    Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
*/

module jtframe_mouse_abspos(
    input            clk,
    input      [7:0] dx,
    input      [7:0] dy,
    input            strobe,
    output reg [8:0] x,
    output reg [8:0] y
);

parameter W = 384, H = 224;

wire [9:0] x_next, y_next;

assign x_next = {1'b0, x} + {{2{dx[7]}}, dx};
assign y_next = {1'b0, y} - {{2{dy[7]}}, dy};

always @(posedge clk) begin
    if (strobe) begin
        if (x_next[9] && dx[7])
            x <= 0;
        else if (x_next[8:0] > W[8:0])
            x <= W[8:0];
        else
            x <= x_next[8:0];

        if (y_next[9] && !dy[7])
            y <= 0;
        else if (y_next[8:0] > H[8:0])
            y <= H[8:0];
        else
            y <= y_next[8:0];
    end
end

endmodule

module jtframe_joyana_abspos(
    input             clk,
    input      [15:0] joyana,
    output reg        strobe,
    output reg [ 8:0] x,
    output reg [ 8:0] y
);

parameter W = 384, H = 224;

reg  [15:0] joya_l;
wire [ 9:0] x_next, y_next;

assign x_next = {joyana[ 7:0],1'b0} + {2'b0, W[8:1]};
assign y_next = {joyana[15:8],1'b0} + {2'b0, H[8:1]};

always @(posedge clk) begin
    strobe <= joyana != joya_l;
    joya_l <= joyana;

    if (~x_next[9] & joyana[7])
        x <= 0;
    else if (x_next[8:0] > W[8:0])
        x <= W[8:0];
    else
        x <= x_next[8:0];

    if (~y_next[9] & joyana[15])
        y <= 0;
    else if (y_next[8:0] > H[8:0])
        y <= H[8:0];
    else
        y <= y_next[8:0];
end

endmodule

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

module jtframe_mouse_rotation(
    input            clk,
    input            strobe,
    output reg       strobe_dly,
    input      [1:0] rotate,
    input      [7:0] dx_in, dy_in,
    output reg [7:0] dx,    dy
);

always @(posedge clk) begin
    dx <= dx_in;
    dy <= dy_in;
    strobe_dly <= strobe;
    if(rotate[0]) begin
        dx <= rotate[1] ?  dy_in : -dy_in;
        dy <= rotate[1] ? -dx_in :  dx_in;
    end
end

endmodule
