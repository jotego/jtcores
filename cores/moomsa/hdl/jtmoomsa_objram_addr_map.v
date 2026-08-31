/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_objram_addr_map(
    input  [15:1] main_a,
    output  [4:0] ea,
    output        g5p11,
    output        g5p13,
    output  [7:0] en,
    output [12:0] ram_addr
);

assign ea       = main_a[5:1];
assign g5p11    = main_a[6];
assign g5p13    = main_a[7];
assign en       = {main_a[15:9],main_a[8]};
assign ram_addr = {en,ea[3:0],ea[4]};

endmodule
