/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_dac_lanes(
    input  [7:0] rout,
    input  [7:0] gout,
    input  [7:0] bout,
    input  [7:0] brout,
    input        cblk0,
    output [7:0] red,
    output [7:0] green,
    output [7:0] blue,
    output [7:0] bright,
    output       blank
);

assign red = rout;
assign green = gout;
assign blue = bout;
assign bright = brout;
assign blank = cblk0;

endmodule
