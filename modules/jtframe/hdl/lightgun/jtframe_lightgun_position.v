/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 14-03-2025 */

module jtframe_lightgun_position(
    input             rst,
    input             clk,
    input             gun_crossh_en,
    input      [ 8:0] m_x, m_y, // mouse
    input             m_strobe,
    input      [ 8:0] a_x, a_y, // analog stick
    input             a_strobe,
    input      [ 8:0] j_x, j_y, // dpad
    input             j_strobe,
    output reg [ 8:0] x,
    output reg [ 8:0] y,
    output reg [ 8:0] x_abs,
    output reg [ 8:0] y_abs,
    output reg        strobe
);

parameter XOFFSET=0, YOFFSET=0;

always @(posedge clk) strobe <= m_strobe | (a_strobe & gun_crossh_en) | j_strobe;

always @(posedge clk) begin
    if(rst) begin
        x      <= 0; y      <= 0;
        x_abs  <= 0; y_abs  <= 0;
    end else begin
        x <= x_abs + XOFFSET[8:0];
        y <= y_abs + YOFFSET[8:0];

        if (j_strobe) begin
            x_abs <= j_x;
            y_abs <= j_y;
        end
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
