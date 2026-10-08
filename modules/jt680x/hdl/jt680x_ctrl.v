/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 22-11-2023 */
/* verilator coverage_off */
module jt680x_ctrl(
    input        rst,
    input        clk,
    input        cen,
    input [15:0] md,
    // interrupts
    input        i,
    input        irq,
    input        nmi,
    input        irq_icf,
    input        irq_ocf,
    input        irq_tof,
    input        irq_sci,
    input        irq2,      // only 6301
    input        irq_cmf,   // only 6301
    output reg [3:0] iv,
    // bus sharing - 6301
    input        ext_halt,  // active high
    output reg   ba,
    // control
    output       alt,
    output       alu16,
    output       branch,
    output       brlatch,
    output       fetch,
    output       inc_pc,
    output       md_shift,
    output       op0inv,
    output       wr,
    output [1:0] carry_sel,
    output [1:0] ea_sel,
    output [1:0] opnd_sel,
    output [3:0] alu_sel,
    output [3:0] ld_sel,
    output [3:0] rmux_sel,
    output [4:0] cc_sel,
    // info
    output reg   stack_busy
);

`include "6801_param.vh"
`include "6801.vh"

wire [4:0] jsr_sel;
reg  [2:0] iv_sel;
wire       halt, swi, ni, still;
reg        nmi_l, pendng;
wire [3:0] nx_ualo = uaddr[3:0] + 1'd1;

assign still = ni & ext_halt;

// reg [255:0] ops, ops_old;
// integer k;

always @(posedge clk) begin
    if(cen) nmi_l <= nmi;
end

always @(posedge clk) begin
    if( rst ) begin
        uaddr      <= IVRD_SEQA;
        jsr_ret    <= 0;
        iv         <= 4'o17; // reset vector
        ba         <= 0;
        stack_busy <= 1;
        pendng     <= 0;
    end else if(cen) begin
        if( nmi & ~nmi_l ) pendng <= 1;
        if(!halt && !still) uaddr[3:0] <= nx_ualo;
        if( swi ) iv <= 4'o15; // lowest priority
        if(  halt | (ni & ext_halt) ) ba<=1;
        if( ~halt & ~ext_halt       ) ba<=0;
        if( ni | halt ) begin
            if( !still ) begin
                uaddr <= { md[7:0], 4'd0 };
                stack_busy <= 0;
                // ops[md[7:0]] <= 1;
                // if( ops_old != ops ) begin
                //     $display("---------");
                //     for(k=0;k<16;k=k+1)
                //         $display("%02X: %X",k<<4,ops[(k<<4)+:16]);
                //     ops_old = ops;
                // end
            end
            if( ~i & ~ext_halt ) begin // maskable interrupts by priority
                // alt signal used to bypass the register push to the stack (set by WAI instruction)
                if( irq_sci) begin iv <= 4'o10; uaddr <= alt ? IVRD_SEQA : ISRV_SEQA; stack_busy<=1; end // lowest priority
                if( irq_cmf) begin iv <= 4'o06; uaddr <= alt ? IVRD_SEQA : ISRV_SEQA; stack_busy<=1; end
                if( irq2   ) begin iv <= 4'o05; uaddr <= alt ? IVRD_SEQA : ISRV_SEQA; stack_busy<=1; end
                if( irq_tof) begin iv <= 4'o11; uaddr <= alt ? IVRD_SEQA : ISRV_SEQA; stack_busy<=1; end
                if( irq_ocf) begin iv <= 4'o12; uaddr <= alt ? IVRD_SEQA : ISRV_SEQA; stack_busy<=1; end
                if( irq_icf) begin iv <= 4'o13; uaddr <= alt ? IVRD_SEQA : ISRV_SEQA; stack_busy<=1; end
                if( irq    ) begin iv <= 4'o14; uaddr <= alt ? IVRD_SEQA : ISRV_SEQA; stack_busy<=1; end // highest priority
            end
            if( pendng ) begin
                iv <= 4'o16;
                uaddr <= ISRV_SEQA;
                stack_busy <= 1;
                pendng <= 0;
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