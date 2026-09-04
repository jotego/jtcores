/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-12-2023 */
/* verilator coverage_off */
module jt6805_ctrl(
    input        rst,
    input        clk,
    input        cen,
    input [12:0] md,
    // interrupts
    input        i,
    input        irq,
    input        tirq,
    output reg [2:0] iv,
    // control
    output       branch,
    output       brlatch,
    output       fetch,
    output       inc_pc,
    output       md_shift,
    output       op0inv,
    output       stop,
    output       wr,
    output [1:0] brt_sel,
    output [1:0] carry_sel,
    output [1:0] ea_sel,
    output [1:0] opnd_sel,
    output [2:0] ld_sel,
    output [3:0] alu_sel,
    output [3:0] cc_sel,
    output [3:0] rmux_sel
);

`include "6805_param.vh"
`include "6805.vh"

wire [4:0] jsr_sel;
reg  [2:0] iv_sel;
wire       halt, swi, ni;
wire [3:0] nx_ualo = uaddr[3:0] + 1'd1;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        uaddr   <= IVRD_SEQA;
        jsr_ret <= 0;
        iv      <= 7;
    end else if(cen) begin
        if(~halt&~stop) uaddr[3:0] <= nx_ualo;
        if( swi ) iv <= 6;
        if( ni | halt | stop) begin
            uaddr <= { md[7:0], 4'd0 };
            if( ~i ) begin
                if( irq ) begin
                    iv     <= 5;
                    uaddr  <= ISRV_SEQA; // irq service
                end else if( tirq ) begin
                    iv    <= 4;
                    uaddr <= ISRV_SEQA;
                end
            end
        end
        if( jsr_en ) begin
            jsr_ret <= uaddr;
            jsr_ret[3:0] <= nx_ualo;
            uaddr   <= jsr_ua;
        end
    end
end

endmodule