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
module jt680x(
    input             rst,
    input             clk,
    input             cen,  // crystal clock freq. = 4x E pin freq.
    output            wr,
    output     [15:0] addr, // always valid
    input      [ 7:0] din,
    output     [ 7:0] dout,
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
wire [ 3:0] rslt_cc;
wire        h, rslt_h, c, i;

wire        alt;
wire        alu16;
wire        branch;
wire        brlatch;
wire        fetch;
wire        inc_pc;
wire        md_shift;
wire        ni;
wire        op0inv;
wire [ 1:0] carry_sel;
wire [ 1:0] ea_sel;
wire [ 1:0] opnd_sel;
wire [ 3:0] iv;
wire [ 3:0] alu_sel;
wire [ 3:0] ld_sel;
wire [ 3:0] rmux_sel;
wire [ 4:0] cc_sel;

jt680x_ctrl u_ctrl(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .md         ( md        ),
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
    .stack_bsy  (           )
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
    .rslt_cc    ( rslt_cc   )
);

jt680x_regs u_regs(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .md         ( md        ),
    .alt        ( alt       ),
    .brlatch    ( brlatch   ),
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