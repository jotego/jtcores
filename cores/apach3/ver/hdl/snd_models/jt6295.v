/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */
module jt6295(
    input rst, clk, cen, ss, wrn,
    input [7:0] din,
    output [7:0] dout,
    output reg [17:0] rom_addr=0,
    input [7:0] rom_data,
    input rom_ok,
    output signed [13:0] sound,
    output sample
);
assign dout=8'h63;
assign sound=0;
assign sample=0;
endmodule
