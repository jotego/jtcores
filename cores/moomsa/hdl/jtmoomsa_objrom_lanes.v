/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_objrom_lanes(
    input  [19:0] objrom_addr,
    input  [15:0] x_lo,
    input  [15:0] x_hi,
    input  [15:0] y_lo,
    input  [15:0] y_hi,
    output [19:0] x_addr,
    output [19:0] y_addr,
    output [31:0] x_data,
    output [31:0] y_data
);

assign x_addr = objrom_addr;
assign y_addr = objrom_addr;
assign x_data = {x_hi,x_lo};
assign y_data = {y_hi,y_lo};

endmodule
