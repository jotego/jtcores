/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 22-11-2023 */
module jtseicro_m6802_cpu(
    input             rst,
    input             clk,
    input             cen,
    output            wr,
    output            fetch,
    output            instruction_end,
    output [7:0]      next_op,
    output     [15:0] addr,
    input      [ 7:0] din,
    output     [ 7:0] dout,

    input             ext_halt,
    output            ba,

    input             irq,
    input             nmi,
    input             irq_icf,
    input             irq_ocf,
    input             irq_tof,
    input             irq_sci,
    input             irq_cmf,
    input             irq2
);

wire [15:0] op0, op1, rslt,md;
wire [3:0] rslt_cc, alu_cc;
wire        h, rslt_h, c, i;

wire        alt;
wire        alu16;
wire        branch;
wire        brlatch;

wire        inc_pc;
wire        md_shift;

wire        op0inv;
wire [ 1:0] carry_sel;
wire [ 1:0] ea_sel;
wire [ 1:0] opnd_sel;
wire [ 3:0] iv;
wire [ 3:0] alu_sel;
wire [ 3:0] ld_sel;
wire [ 3:0] rmux_sel;
wire [ 4:0] cc_sel;

wire [8:0] cmp_hi = {1'b0,op0[15:8]}-{1'b0,op1[15:8]};
wire cmp_v = (op0[15]^op1[15]) & (op0[15]^cmp_hi[7]);
`include "6801_param.vh"
wire cmpx = alu16 && alu_sel==SUB_ALU && ld_sel!=D_LD && cc_sel==NZVC_CC;
assign rslt_cc = cmpx ? {cmp_hi[7],rslt==16'd0,cmp_v,c} : alu_cc;

assign next_op=md[7:0];

jtseicro_m6802_ctrl u_ctrl(
    .ni         ( instruction_end ),
    .rst        ( rst             ),
    .clk        ( clk             ),
    .cen        ( cen             ),
    .md         ( md              ),
    .ext_halt   ( ext_halt        ),
    .ba         ( ba              ),
    .nmi        ( nmi             ),
    .irq        ( irq             ),
    .irq_icf    ( irq_icf         ),
    .irq_ocf    ( irq_ocf         ),
    .irq_tof    ( irq_tof         ),
    .irq_sci    ( irq_sci         ),
    .irq_cmf    ( irq_cmf         ),
    .irq2       ( irq2            ),
    .i          ( i               ),
    .iv         ( iv              ),
    .alt        ( alt             ),
    .alu16      ( alu16           ),
    .branch     ( branch          ),
    .brlatch    ( brlatch         ),
    .fetch      ( fetch           ),
    .inc_pc     ( inc_pc          ),
    .md_shift   ( md_shift        ),
    .op0inv     ( op0inv          ),
    .ea_sel     ( ea_sel          ),
    .wr         ( wr              ),
    .carry_sel  ( carry_sel       ),
    .opnd_sel   ( opnd_sel        ),
    .alu_sel    ( alu_sel         ),
    .ld_sel     ( ld_sel          ),
    .rmux_sel   ( rmux_sel        ),
    .cc_sel     ( cc_sel          ),
    .stack_busy (                 )
);

jt680x_alu u_alu(
    .rst       ( rst       ),
    .clk       ( clk       ),
    .cen       ( cen       ),
    .alu16     ( alu16     ),
    .carry_sel ( carry_sel ),
    .alu_sel   ( alu_sel   ),
    .cin       ( c         ),
    .hin       ( h         ),
    .op0       ( op0       ),
    .op1       ( op1       ),
    .ho        ( rslt_h    ),
    .rslt      ( rslt      ),
    .rslt_cc   ( alu_cc    )
);

jt680x_regs u_regs(
    .rst      ( rst      ),
    .clk      ( clk      ),
    .cen      ( cen      ),
    .md       ( md       ),
    .alt      ( alt      ),
    .brlatch  ( brlatch  ),
    .branch   ( branch   ),
    .cc_sel   ( cc_sel   ),
    .ea_sel   ( ea_sel   ),
    .fetch    ( fetch    ),
    .ld_sel   ( ld_sel   ),
    .op0inv   ( op0inv   ),
    .opnd_sel ( opnd_sel ),
    .inc_pc   ( inc_pc   ),
    .rmux_sel ( rmux_sel ),
    .md_shift ( md_shift ),
    .i        ( i        ),
    .iv       ( iv       ),
    .rslt     ( rslt     ),
    .rslt_h   ( rslt_h   ),
    .rslt_cc  ( rslt_cc  ),
    .op0      ( op0      ),
    .op1      ( op1      ),
    .h        ( h        ),
    .c        ( c        ),
    .din      ( din      ),
    .addr     ( addr     ),
    .dout     ( dout     )
);

endmodule
