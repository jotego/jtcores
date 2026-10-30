/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */
module jt8255(
    input rst, clk,
    input [1:0] addr,
    input [7:0] din,
    output [7:0] dout,
    input rdn, wrn, csn,
    input [7:0] porta_din, portb_din, portc_din,
    output [7:0] porta_dout, portb_dout, portc_dout
);
assign dout=8'h42;
assign porta_dout=0;
assign portb_dout=0;
assign portc_dout=0;
endmodule
