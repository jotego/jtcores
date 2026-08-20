/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

module jt8051_ctrl(
    input             rst,
    input             clk,
    input             cen,
    input      [ 7:0] ir,
    input             irq,
    output     [ 4:0] alu_sel,
    output     [ 4:0] src_sel,
    output     [ 4:0] dst_sel,
    output     [ 2:0] addr_sel,
    output     [ 3:0] pc_sel,
    output     [ 3:0] cond_sel,
    output     [ 2:0] flag_sel,
    output     [ 1:0] code_sel,
    output     [ 1:0] x_sel,
    output            wr,
    output            sp_inc,
    output            sp_dec,
    output            x_acc,
    output     [ 1:0] xwr_sel,
    output            latch,
    output            irq_take,
    output            reti,
    output            instruction_end,
    output reg        next_instruction
);

`include "jt8051_param.vh"

wire [ 5:0] jsr_sel;
wire         ni;
reg          irq_pending;

`include "jt8051.vh"

assign irq_take = ni && irq_pending;
assign instruction_end = ni;

always @(posedge clk) begin
    if (rst) begin
        uaddr            <= FETCH0_SEQA;
        jsr_ret          <= 0;
        next_instruction <= 0;
        irq_pending      <= 0;
    end else if (cen) begin
        next_instruction <= 0;
        if (irq) irq_pending <= 1;
        if (irq_take) irq_pending <= 0;
        if (ni) begin
            next_instruction <= 1;
            uaddr <= irq_take ? ISR_SEQA : {1'b0,ir,6'd0};
        end else begin
            uaddr <= uaddr+1'd1;
        end
        if (jsr_en) begin
            jsr_ret <= uaddr+1'd1;
            uaddr   <= jsr_ua;
        end
    end
end

endmodule
