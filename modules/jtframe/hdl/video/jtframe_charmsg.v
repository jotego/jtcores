/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-2-2019 */

// Alternative memory for on-screen message generation
// SW = width of the memory address/scan vectors
// msg_width output is a fixed value equal to HVAL

module jtframe_charmsg #(parameter SW=10, HVAL=8'd2, VERTICAL=1)(
    input            clk,
    input            pxl_cen,  /* synthesis direct_enable = 1 */

    input   [SW-1:0] scan,
    output reg [7:0] msg_low,
    output     [7:0] msg_high
);

wire [7:0] mem_msg;

jtframe_ram #(.AW(SW),.SYNFILE("msg.hex"),.SIMFILE("msg.bin")) u_char_msg(
    .clk    ( clk         ),
    .cen    ( pxl_cen     ),
    .data   ( 8'd0        ),
    .addr   ( scan        ),
    .we     ( 1'b0        ),
    .q      ( mem_msg     )
);

always @(*) msg_low = mem_msg;

assign msg_high = HVAL;

endmodule
