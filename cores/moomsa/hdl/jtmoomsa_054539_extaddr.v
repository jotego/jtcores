/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_054539_extaddr(
    input  [7:0]  reg22e,
    input  [16:0] post_count,
    output [20:0] ext_addr,
    output        ext_ram
);

assign ext_addr = {reg22e[3:0],post_count};
assign ext_ram  = reg22e[7];

endmodule
