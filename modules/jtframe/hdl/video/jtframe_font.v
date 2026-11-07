/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-1-2025 */

module jtframe_font(
    input        clk,
    input  [6:0] ascii,
    input  [2:0] v,
    output [7:0] pxl
);

wire [9:0] addr = {ascii,v};

jtframe_ram #(.AW(10),.SYNFILE("font0.hex")) u_font(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( 8'd0      ),
    .addr   ( addr      ),
    .we     ( 1'b0      ),
    .q      ( pxl       )
);

endmodule