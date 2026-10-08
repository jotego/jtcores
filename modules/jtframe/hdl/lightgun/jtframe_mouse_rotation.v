/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 14-03-2025 */

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
