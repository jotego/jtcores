/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 7-2-2026 */

module jtcps3_main_ram_adapter(
    input               word_cs,
    input       [ 1:0]  A,
    input       [31:0]  cpu_dout,
    input       [ 3:0]  we_n,
    input       [31:0]  cpuba0_data,
    output      [31:0]  cpuba0_din,
    output      [ 3:0]  cpuba0_dsn,
    output      [31:0]  word_data
);

assign cpuba0_din = word_cs ? (A[1] ? {16'd0, cpu_dout[15:0]} : {cpu_dout[15:0], 16'd0}) :
                                  cpu_dout;
assign cpuba0_dsn = word_cs ? (A[1] ? {2'b11, we_n[1:0]} : {we_n[1:0], 2'b11}) :
                                  we_n;
assign word_data  = A[1] ? {16'd0, cpuba0_data[15:0]} : {16'd0, cpuba0_data[31:16]};

endmodule
