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

`ifndef VERILATOR_KEEP_CPU
/* verilator tracing_off */
`endif
/* verilator coverage_off */

module jt6805(
    input             rst,
    input             clk,
    input             cen,  // crystal clock freq. = 4x E pin freq.
    input             irq,  // external interrupt
    input             tirq, // timer interrupt
    output            wr,
    output            tstop,// timer stop
    output     [12:0] addr, // always valid
    input      [ 7:0] din,
    output     [ 7:0] dout
);

wire [12:0] op0, op1, rslt,md;
wire [ 2:0] rslt_cc, iv;
wire        h, rslt_h, c, i;

wire [3:0] alu_sel;
wire [1:0] brt_sel;
wire [3:0] cc_sel;
wire [1:0] ea_sel;
wire [2:0] ld_sel;
wire [1:0] opnd_sel;
wire [1:0] carry_sel;
wire [3:0] rmux_sel;

wire       branch;
wire       brlatch;
wire       fetch;
wire       op0inv;
wire       inc_pc;
wire       md_shift;
wire       swi;

jt6805_ctrl u_ctrl(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .md         ( md        ),
    // interrupt
    .irq        ( irq       ),
    .tirq       ( tirq      ),
    .i          ( i         ),
    .iv         ( iv        ),
    // control
    .branch     ( branch    ),
    .brlatch    ( brlatch   ),
    .fetch      ( fetch     ),
    .inc_pc     ( inc_pc    ),
    .md_shift   ( md_shift  ),
    .op0inv     ( op0inv    ),
    .stop       ( tstop     ),
    .wr         ( wr        ),
    .brt_sel    ( brt_sel   ),
    .carry_sel  ( carry_sel ),
    .ea_sel     ( ea_sel    ),
    .opnd_sel   ( opnd_sel  ),
    .ld_sel     ( ld_sel    ),
    .alu_sel    ( alu_sel   ),
    .cc_sel     ( cc_sel    ),
    .rmux_sel   ( rmux_sel  )
);

jt6805_alu u_alu(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
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

jt6805_regs u_regs(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .md         ( md        ),
    .branch     ( branch    ),
    .brlatch    ( brlatch   ),
    .fetch      ( fetch     ),
    .inc_pc     ( inc_pc    ),
    .md_shift   ( md_shift  ),
    .op0inv     ( op0inv    ),
    .wr         ( wr        ),
    .brt_sel    ( brt_sel   ),
    .ea_sel     ( ea_sel    ),
    .opnd_sel   ( opnd_sel  ),
    .ld_sel     ( ld_sel    ),
    .cc_sel     ( cc_sel    ),
    .rmux_sel   ( rmux_sel  ),
    // interrupts
    .irq        ( irq       ),
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