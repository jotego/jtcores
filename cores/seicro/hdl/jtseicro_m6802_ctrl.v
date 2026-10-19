/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 22-11-2023 */
module jtseicro_m6802_ctrl(
    input             rst, clk, cen,
    input      [7:0]  opcode,
    output reg [3:0]  iv,
    output            alt, alu16, branch, fetch, ni, inc_pc, md_shift,
    output            op0inv, wr, bus, valid, retire, halt, illegal, entry, nscop, fccompat,
    output     [1:0]  carry_sel, opnd_sel,
    output     [2:0]  ea_sel,
    output     [3:0]  alu_sel, ld_sel, rmux_sel,
    output     [4:0]  cc_sel
);
`include "6801_param.vh"
wire [4:0] jsr_sel;
wire swi;
`include "6801.vh"
always @(posedge clk) begin
    if(rst) begin
        uaddr <= IVRD_SEQA;
        jsr_ret <= 0;
        iv <= 4'o17;
    end else if(cen) begin
        if(!halt) uaddr[4:0] <= uaddr[4:0]+5'd1;
        if(retire && !halt) uaddr <= FETCHOP_SEQA;
        if(swi) iv <= 4'o15;
        if(ni) uaddr <= {opcode,5'd0};
        if(jsr_en) begin
            jsr_ret <= {uaddr[12:5],uaddr[4:0]+5'd1};
            uaddr <= jsr_ua;
        end
    end
end
endmodule
