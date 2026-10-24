/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 22-11-2023 */
/* verilator coverage_off */
module jt680x #(parameter MC6800=0, EXT_DECODE=0)(
    input             rst,
    input             clk,
    input             cen,  // crystal clock freq. = 4x E pin freq.
    output            wr,
    output     [15:0] addr, // always valid
    input      [ 7:0] din,
    output     [ 7:0] dout,
    input      [ 7:0] opcode,
    output     [ 7:0] opcode_raw,
    output            ni, halt, vma,
    // bus sharing - 6301
    input             ext_halt, // active high
    output            ba,
    // interrupts
    input             irq,
    input             nmi,
    input             irq_icf,
    input             irq_ocf,
    input             irq_tof,
    input             irq_sci,
    input             irq_cmf,   // only 6301
    input             irq2       // only 6301
);

wire [15:0] op0, op1, rslt,md;
wire [ 3:0] rslt_cc, alu_cc;
wire        h, rslt_h, c, i;

wire        alt;
wire        alu16;
wire        branch;
wire        brlatch;
wire        fetch;
wire        inc_pc;
wire        md_shift;
wire [7:0] decoded = EXT_DECODE ? opcode : md[7:0];
wire [15:0] dec_md = {md[15:8],decoded};
assign opcode_raw = md[7:0];
wire        op0inv;
wire [ 1:0] carry_sel;
`ifdef JT680X_6802
wire [ 2:0] ea_sel;
`else
wire [ 1:0] ea_sel;
`endif
wire [ 1:0] opnd_sel;
wire [ 3:0] iv;
wire [ 3:0] alu_sel;
wire [ 3:0] ld_sel;
wire [ 3:0] rmux_sel;
wire [ 4:0] cc_sel;

wire [8:0] cmp_hi = {1'b0,op0[15:8]}-{1'b0,op1[15:8]};
`include "6801_param.vh"
wire cmpx = MC6800 && alu16 && alu_sel==SUB_ALU && ld_sel!=D_LD && cc_sel==NZVC_CC;
wire adcx = MC6800 && ld_sel==X_LD && cc_sel==HNZVC_CC;
assign rslt_cc = cmpx ? {cmp_hi[7],rslt==16'd0,(op0[15]^op1[15])&(op0[15]^cmp_hi[7]),c} :
                adcx ? {alu_cc[3:1],rslt[8]} : alu_cc;

jt680x_ctrl u_ctrl(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .md         ( dec_md    ),
    .ni         ( ni        ),
    .halt       ( halt      ),
    .vma        ( vma       ),
    // bus sharing - 6301
    .ext_halt   ( ext_halt  ),
    .ba         ( ba        ),
    // interrupt
    .nmi        ( nmi       ),
    .irq        ( irq       ),
    .irq_icf    ( irq_icf   ),
    .irq_ocf    ( irq_ocf   ),
    .irq_tof    ( irq_tof   ),
    .irq_sci    ( irq_sci   ),
    .irq_cmf    ( irq_cmf   ),
    .irq2       ( irq2      ),
    .i          ( i         ),
    .iv         ( iv        ),
    // control
    .alt        ( alt       ),
    .alu16      ( alu16     ),
    .branch     ( branch    ),
    .brlatch    ( brlatch   ),
    .fetch      ( fetch     ),
    .inc_pc     ( inc_pc    ),
    .md_shift   ( md_shift  ),
    .op0inv     ( op0inv    ),
    .ea_sel     ( ea_sel    ),
    .wr         ( wr        ),
    .carry_sel  ( carry_sel ),
    .opnd_sel   ( opnd_sel  ),
    .alu_sel    ( alu_sel   ),
    .ld_sel     ( ld_sel    ),
    .rmux_sel   ( rmux_sel  ),
    .cc_sel     ( cc_sel    ),
    .stack_busy (           )
);

jt680x_alu u_alu(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .alu16      ( alu16     ),
    .carry_sel  ( carry_sel ),
    .alu_sel    ( alu_sel   ),
    .cin        ( c         ),
    .hin        ( h         ),
    .op0        ( op0       ),
    .op1        ( op1       ),
    .ho         ( rslt_h    ),
    .rslt       ( rslt      ),
    .rslt_cc    ( alu_cc    )
);

jt680x_regs u_regs(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .md         ( md        ),
    .alt        ( alt       ),
    .brlatch    ( brlatch   ),
    .opcode     ( decoded   ),
    .ni         ( ni        ),
    .branch     ( branch    ),
    .cc_sel     ( cc_sel    ),
    .ea_sel     ( ea_sel    ),
    .fetch      ( fetch     ),
    .ld_sel     ( ld_sel    ),
    .op0inv     ( op0inv    ),
    .opnd_sel   ( opnd_sel  ),
    .inc_pc     ( inc_pc    ),
    .rmux_sel   ( rmux_sel  ),
    .md_shift   ( md_shift  ),
    // interrupts
    .i          ( i         ),
    .iv         ( iv        ),
    // ALU
    .rslt       ( rslt      ),
    .rslt_h     ( rslt_h    ),
    .rslt_cc    ( rslt_cc   ),
    .op0        ( op0       ),
    .op1        ( op1       ),
    .h          ( h         ),
    .c          ( c         ),
    .din        ( din       ),
    .addr       ( addr      ),
    .dout       ( dout      )
);

endmodule
