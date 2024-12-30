/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 22-11-2023 */
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
    output reg   stack_bsy
);

`include "6801_param.vh"
`include "6801.vh"

wire [4:0] jsr_sel;
reg  [2:0] iv_sel;
wire       halt, swi, ni, still;
reg        nmi_l;
wire [3:0] nx_ualo = uaddr[3:0] + 1'd1;

assign still = ni & ext_halt;

// reg [255:0] ops, ops_old;
// integer k;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        uaddr     <= IVRD_SEQA;
        jsr_ret   <= 0;
        iv        <= 4'o17; // reset vector
        ba        <= 0;
        stack_bsy <= 1;
    end else if(cen) begin
        if(!halt && !still) uaddr[3:0] <= nx_ualo;
        if( swi ) iv <= 4'o15; // lowest priority
        if(  halt | (ni & ext_halt) ) ba<=1;
        if( ~halt & ~ext_halt       ) ba<=0;
        if( ni | halt ) begin
            nmi_l <= nmi;
            if( !still ) begin
                uaddr <= { md[7:0], 4'd0 };
                stack_bsy <= 0;
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
                if( irq_sci) begin iv <= 4'o10; uaddr <= alt ? IVRD_SEQA : ISRV_SEQA; stack_bsy<=1; end // lowest priority
                if( irq_cmf) begin iv <= 4'o06; uaddr <= alt ? IVRD_SEQA : ISRV_SEQA; stack_bsy<=1; end
                if( irq2   ) begin iv <= 4'o05; uaddr <= alt ? IVRD_SEQA : ISRV_SEQA; stack_bsy<=1; end
                if( irq_tof) begin iv <= 4'o11; uaddr <= alt ? IVRD_SEQA : ISRV_SEQA; stack_bsy<=1; end
                if( irq_ocf) begin iv <= 4'o12; uaddr <= alt ? IVRD_SEQA : ISRV_SEQA; stack_bsy<=1; end
                if( irq_icf) begin iv <= 4'o13; uaddr <= alt ? IVRD_SEQA : ISRV_SEQA; stack_bsy<=1; end
                if( irq    ) begin iv <= 4'o14; uaddr <= alt ? IVRD_SEQA : ISRV_SEQA; stack_bsy<=1; end // highest priority
            end
            if( nmi & ~nmi_l ) begin
                iv <= 4'o16;
                uaddr <= ISRV_SEQA;
                stack_bsy <= 1;
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