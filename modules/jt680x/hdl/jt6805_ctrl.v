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

wire [4:0] jsr_sel;
reg  [2:0] iv_sel;
reg        irq_l, irq_pending;
wire       halt, swi, ni;

`include "6805_param.vh"
`include "6805.vh"

wire [3:0] nx_ualo = uaddr[3:0] + 1'd1;
wire       irq_rise = irq & ~irq_l;
// A CLI instruction clears I on its final NI edge. Include that same-edge
// status update in eligibility so a latched request is accepted as soon as
// the instruction completes, without dispatching one extra opcode.
// Resolve the interrupt mask using the status value written at this boundary.
// CLI makes a masked request eligible as soon as I clears; SEI must likewise
// keep it masked on the same edge that sets I.
wire       irq_unmasked = (ni && cc_sel==I0_CC) ? 1'b1 :
                          (ni && cc_sel==I1_CC) ? 1'b0 : ~i;
wire       irq_ack  = cen & (ni | halt | stop) & irq_unmasked & irq_pending;

// The external INT pin is falling-edge sensitive and latches requests while
// masked. `irq` is the asserted-high logical form used by this CPU interface.
// Track the level through reset so a pin held active during reset does not
// create a synthetic edge when reset is released.
always @(posedge clk) irq_l <= irq;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        irq_pending <= 0;
    end else begin
        if( irq_rise ) irq_pending <= 1;
        else if( irq_ack ) irq_pending <= 0;
    end
end

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
            if( irq_unmasked ) begin
                if( irq_pending ) begin
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
