/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_workram_bus(
    input  [15:1] main_addr,
    input  [15:0] main_dout,
    input         work_cs,
    input   [1:0] main_dsn,
    input         main_we,
    output [15:1] work_addr,
    output [15:0] work_din,
    output  [1:0] work_we
);

assign work_addr = main_addr;
assign work_din  = main_dout;
assign work_we   = {2{work_cs && main_we}} & ~main_dsn;

endmodule
