/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 22-11-2023 */
/* verilator coverage_off */
module jt680x_ctrl(
    input        rst,
    input        clk,
    input        cen,
    input [15:0] md,
`ifdef JT680X_6802
    input [7:0]  opcode,
    input        irq_cen,
    output       bus, valid, retire, halt, ni, illegal, entry, nscop, fccompat,
`endif
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
`ifdef JT680X_6802
    output [2:0] ea_sel,
`else
    output [1:0] ea_sel,
`endif
    output [1:0] opnd_sel,
    output [3:0] alu_sel,
    output [3:0] ld_sel,
    output [3:0] rmux_sel,
    output [4:0] cc_sel,
    // info
    output reg   stack_busy
);

wire [4:0] jsr_sel;
reg  [2:0] iv_sel;
`ifdef JT680X_6802
wire       swi, still;
`else
wire       halt, swi, ni, still;
`endif
reg        nmi_l, pendng;

`include "6801_param.vh"
`include "6801.vh"

localparam USTEP_W = $bits(uaddr)-8;
wire [USTEP_W-1:0] nx_ualo = uaddr[USTEP_W-1:0] + 1'd1;
`ifdef JT680X_6802
localparam WAKE_SEQA = IWAKE_SEQA;
wire boundary = retire | halt;
reg irq_l;
wire irq_request = irq_l;
`else
localparam WAKE_SEQA = IVRD_SEQA;
wire boundary = ni | halt;
wire irq_request = irq;
`endif

`ifdef JT680X_6802
assign still = retire & ext_halt;
assign brlatch = ni;
`else
assign still = ni & ext_halt;
`endif

// reg [255:0] ops, ops_old;
// integer k;

always @(posedge clk) begin
`ifdef JT680X_6802
    if(rst) begin
        nmi_l <= 0;
        irq_l <= 0;
    end else if(irq_cen) begin
        nmi_l <= nmi;
        irq_l <= irq;
    end
`else
    if(cen) nmi_l <= nmi;
`endif
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
`ifdef JT680X_6802
        if( irq_cen & nmi & ~nmi_l ) pendng <= 1;
`else
        if( nmi & ~nmi_l ) pendng <= 1;
`endif
        if(!halt && !still) uaddr[USTEP_W-1:0] <= nx_ualo;
        if( swi ) iv <= 4'o15; // lowest priority
        if(  halt | still ) ba<=1;
        if( ~halt & ~ext_halt       ) ba<=0;
`ifdef JT680X_6802
        if(ni) uaddr <= {opcode,5'd0};
`endif
        if( boundary ) begin
`ifdef JT680X_6802
            if(retire && !halt) begin
                uaddr <= ext_halt ? HLT_SEQA : FETCHOP_SEQA;
                stack_busy <= 0;
            end
            if(halt && !alt && !ext_halt) begin
                uaddr <= FETCHOP_SEQA;
                stack_busy <= 0;
            end
`else
            // A halt instruction is a wait state until an interrupt is
            // actually serviceable. Normal NI boundaries still dispatch the
            // next opcode when no interrupt is pending.
            if( !still && ( !halt || ( ~ext_halt &
                ( pendng | ( ~i & ( irq | irq_icf | irq_ocf | irq_tof | irq_sci | irq2 | irq_cmf ) ) |
                    ( uaddr[11:4]==8'h1a & ( irq | irq_icf | irq_ocf | irq_tof | irq_sci | irq2 | irq_cmf ) ) ) ) ) ) begin
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
`endif
            if( ~i & ~ext_halt ) begin // maskable interrupts by priority
                // alt signal used to bypass the register push to the stack (set by WAI instruction)
                if( irq_sci) begin iv <= 4'o10; uaddr <= alt ? WAKE_SEQA : ISRV_SEQA; stack_busy<=1; end // lowest priority
                if( irq_cmf) begin iv <= 4'o06; uaddr <= alt ? WAKE_SEQA : ISRV_SEQA; stack_busy<=1; end
                if( irq2   ) begin iv <= 4'o05; uaddr <= alt ? WAKE_SEQA : ISRV_SEQA; stack_busy<=1; end
                if( irq_tof) begin iv <= 4'o11; uaddr <= alt ? WAKE_SEQA : ISRV_SEQA; stack_busy<=1; end
                if( irq_ocf) begin iv <= 4'o12; uaddr <= alt ? WAKE_SEQA : ISRV_SEQA; stack_busy<=1; end
                if( irq_icf) begin iv <= 4'o13; uaddr <= alt ? WAKE_SEQA : ISRV_SEQA; stack_busy<=1; end
                if( irq_request ) begin iv <= 4'o14; uaddr <= alt ? WAKE_SEQA : ISRV_SEQA; stack_busy<=1; end // highest priority
            end
`ifdef JT680X_6802
            if( pendng && !ext_halt ) begin
`else
            if( pendng ) begin
`endif
                iv <= 4'o16;
                uaddr <= alt ? WAKE_SEQA : ISRV_SEQA;
                stack_busy <= 1;
                pendng <= 0;
            end
        end
        if( jsr_en ) begin
            jsr_ret <= uaddr;
            jsr_ret[USTEP_W-1:0] <= nx_ualo;
            uaddr   <= jsr_ua;
        end
    end
`ifdef JT680X_6802
    else if(irq_cen && nmi && !nmi_l) pendng <= 1;
`endif
end

endmodule
