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
    Date: 28-11-2025 */

`ifndef VERILATOR_KEEP_CPU
/* verilator tracing_off */
`endif
/* verilator coverage_off */

module jt65c02(
    input             rst,
    input             clk,
    input             cen,  // crystal clock freq. = 4x E pin freq.
    input             irq,
    input             nmi,
    output            wr,
    output            rd,
    output     [15:0] addr, // always valid
    input      [ 7:0] din,
    output     [ 7:0] dout
);

wire [7:0] op0, op1, rslt,md, ir;
wire [3:0] rslt_cc;
wire [2:0] iv;
wire       d, c, i, calt, brcy, stcy;

wire [3:0] alu_sel;
wire [3:0] cc_sel;
wire [1:0] ea_sel;
wire [3:0] ld_sel;
wire [1:0] opnd_sel;
wire [1:0] carry_sel;
wire [3:0] rmux_sel;

wire       branch, branch_lo;
wire       brlatch, brok;
wire       fetch, ni;
wire       inc_pc;
wire       swi, pcpage;

jt65c02_ctrl u_ctrl(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .md         ( md        ),
    .ir         ( ir        ),
    // interrupt
    .irq        ( irq       ),
    .nmi        ( nmi       ),
    .i          ( i         ),
    .iv         ( iv        ),
    // control
    .pcpage     ( pcpage    ),
    .d          ( d         ),
    .branch     ( branch    ),
    .branch_lo  ( branch_lo ),
    .brok       ( brok      ),
    .ni         ( ni        ),
    .calt       ( calt      ),
    .brlatch    ( brlatch   ),
    .fetch      ( fetch     ),
    .inc_pc     ( inc_pc    ),
    .wr         ( wr        ),
    .brcy       ( brcy      ),
    .stcy       ( stcy      ),
    .carry_sel  ( carry_sel ),
    .ea_sel     ( ea_sel    ),
    .opnd_sel   ( opnd_sel  ),
    .ld_sel     ( ld_sel    ),
    .alu_sel    ( alu_sel   ),
    .cc_sel     ( cc_sel    ),
    .rmux_sel   ( rmux_sel  )
);

jt65c02_alu u_alu(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .ir         ( ir        ),
    .carry_sel  ( carry_sel ),
    .alu_sel    ( alu_sel   ),
    .cin        ( c         ),
    .calt       ( calt      ),
    .op0        ( op0       ),
    .op1        ( op1       ),
    .rslt       ( rslt      ),
    .rslt_cc    ( rslt_cc   )
);

jt65c02_regs u_regs(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .md         ( md        ),
    .d          ( d         ),
    .branch     ( branch    ),
    .branch_lo  ( branch_lo ),
    .brok       ( brok      ),
    .brlatch    ( brlatch   ),
    .ni         ( ni        ),
    .fetch      ( fetch     ),
    .inc_pc     ( inc_pc    ),
    .wr         ( wr        ),
    .rd         ( rd        ),
    .ea_sel     ( ea_sel    ),
    .brcy       ( brcy      ),
    .stcy       ( stcy      ),
    .opnd_sel   ( opnd_sel  ),
    .ld_sel     ( ld_sel    ),
    .cc_sel     ( cc_sel    ),
    .rmux_sel   ( rmux_sel  ),
    .pcpage     ( pcpage    ),
    // interrupts
    .irq        ( irq       ),
    .i          ( i         ),
    .iv         ( iv        ),
    // ALU
    .rslt       ( rslt      ),
    .rslt_cc    ( rslt_cc   ),
    .op0        ( op0       ),
    .op1        ( op1       ),
    .c          ( c         ),
    .calt       ( calt      ),
    .din        ( din       ),
    .addr       ( addr      ),
    .dout       ( dout      )
);

endmodule