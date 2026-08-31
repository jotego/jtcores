/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_gfxrom_lanes(
    input  [19:0] gfxrom_addr,
    input  [15:0] t8_data,
    input  [15:0] t10_data,
    output [19:0] t8_addr,
    output [19:0] t10_addr,
    output [31:0] gfxrom_data
);

assign t8_addr      = gfxrom_addr;
assign t10_addr     = gfxrom_addr;
assign gfxrom_data  = {t10_data,t8_data};

endmodule
