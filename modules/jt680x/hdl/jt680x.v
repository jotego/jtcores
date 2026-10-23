/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 22-11-2023 */
/* verilator coverage_off */
module jt680x #(parameter FC_COMPAT=0)(
    input             rst,
    input             clk,
    input             cen,  // crystal clock freq. = 4x E pin freq.
`ifdef JT680X_6802
    input             cpu_rst, enable, ready, mr_n, nsc8105,
    output            e, vma, done, instruction_end, opcode_fetch,
`endif
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
wire [ 3:0] rslt_cc, alu_cc;
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

wire [15:0] cycle_addr;
wire [7:0] cycle_dout;
wire cycle_wr;
`ifdef JT680X_6802
wire bus, valid, retire, halt, fault, entry, nscop, fccompat;
wire bus_vma, bus_wr;
wire [15:0] bus_addr;
wire [7:0] decoded = nsc8105 ? {din[6],din[7],din[5:2],din[0],din[1]} : din;
// FC compatibility only; absent from MC6802 manual, real-chip behavior/timing unknown.
wire [7:0] next_op = FC_COMPAT && !nsc8105 && din==8'hfc ? 8'h03 : decoded;
reg illegal, check_entry, was_halt;
reg [7:0] raw_opcode;
wire invalid_entry = check_entry && (!entry || (nscop && !nsc8105) ||
    (fccompat && (nsc8105 || raw_opcode!=8'hfc)));
wire core_rst = rst || cpu_rst;
wire core_cen = !core_rst && enable && !illegal && !invalid_entry && (!bus || done);
wire [8:0] cmp_hi = {1'b0,op0[15:8]}-{1'b0,op1[15:8]};
wire cmp_v = (op0[15]^op1[15]) & (op0[15]^cmp_hi[7]);
`include "6801_param.vh"
wire cmpx = alu16 && alu_sel==SUB_ALU && ld_sel!=D_LD && cc_sel==NZVC_CC;
wire adcx = nsc8105 && ld_sel==X_LD && cc_sel==HNZVC_CC;
assign rslt_cc = cmpx ? {cmp_hi[7],rslt==16'd0,cmp_v,c} :
                adcx ? {alu_cc[3:1],rslt[8]} : alu_cc;
assign opcode_fetch = bus && ni;
assign instruction_end = core_cen && retire && (!halt || !was_halt);
assign vma = bus_vma && !ba;
assign wr = bus_wr && !ba;
assign addr = ba ? cycle_addr : bus_addr;
always @(posedge clk) begin
    if(core_rst) begin
        illegal <= 0;
        check_entry <= 0;
        was_halt <= 0;
        raw_opcode <= 0;
    end else if(invalid_entry) illegal <= 1;
    else if(core_cen) begin
        check_entry <= ni;
        was_halt <= halt;
        if(fault) illegal <= 1;
        if(ni) raw_opcode <= din;
    end
end
`ifdef SIMULATION
always @(posedge clk) if(!core_rst && illegal)
    $fatal(1,"MC6802 unsupported opcode %h at %h",raw_opcode,u_regs.op_pc);
`endif
`else
wire core_rst = rst;
wire core_cen = cen;
assign wr = cycle_wr;
assign addr = cycle_addr;
assign dout = cycle_dout;
assign rslt_cc = alu_cc;
`endif

jt680x_ctrl u_ctrl(
    .rst        ( core_rst  ),
    .clk        ( clk       ),
    .cen        ( core_cen  ),
    .md         ( md        ),
`ifdef JT680X_6802
    .opcode     ( next_op   ),
    .irq_cen    ( cen && e  ),
    .bus        ( bus       ),
    .valid      ( valid     ),
    .retire     ( retire    ),
    .halt       ( halt      ),
    .ni         ( ni        ),
    .illegal    ( fault     ),
    .entry      ( entry     ),
    .nscop      ( nscop     ),
    .fccompat   ( fccompat  ),
`endif
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
    .wr         ( cycle_wr  ),
    .carry_sel  ( carry_sel ),
    .opnd_sel   ( opnd_sel  ),
    .alu_sel    ( alu_sel   ),
    .ld_sel     ( ld_sel    ),
    .rmux_sel   ( rmux_sel  ),
    .cc_sel     ( cc_sel    ),
    .stack_busy (           )
);

jt680x_alu u_alu(
    .rst       ( core_rst  ),
    .clk       ( clk       ),
    .cen       ( core_cen  ),
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
`ifdef JT680X_6802
    .opcode   ( next_op    ),
    .ni       ( ni         ),
`endif
    .rst      ( core_rst   ),
    .clk      ( clk        ),
    .cen      ( core_cen   ),
    .md       ( md         ),
    .alt      ( alt        ),
    .brlatch  ( brlatch    ),
    .branch   ( branch     ),
    .cc_sel   ( cc_sel     ),
    .ea_sel   ( ea_sel     ),
    .fetch    ( fetch      ),
    .ld_sel   ( ld_sel     ),
    .op0inv   ( op0inv     ),
    .opnd_sel ( opnd_sel   ),
    .inc_pc   ( inc_pc     ),
    .rmux_sel ( rmux_sel   ),
    .md_shift ( md_shift   ),
    // interrupts
    .i        ( i          ),
    .iv       ( iv         ),
    // ALU
    .rslt     ( rslt       ),
    .rslt_h   ( rslt_h     ),
    .rslt_cc  ( rslt_cc    ),
    .op0      ( op0        ),
    .op1      ( op1        ),
    .h        ( h          ),
    .c        ( c          ),
    .din      ( din        ),
    .addr     ( cycle_addr ),
    .dout     ( cycle_dout )
);

`ifdef JT680X_6802
jt680x_bus u_bus(
    .rst          ( rst                               ),
    .abort        ( cpu_rst                           ),
    .clk          ( clk                               ),
    .cen          ( cen                               ),
    .enable       ( enable                            ),
    .ready        ( ready                             ),
    .mr_n         ( mr_n                              ),
    .cycle_active ( bus && !illegal && !invalid_entry ),
    .cycle_vma    ( valid                             ),
    .cycle_wr     ( cycle_wr                          ),
    .cycle_addr   ( cycle_addr                        ),
    .cycle_dout   ( cycle_dout                        ),
    .e            ( e                                 ),
    .vma          ( bus_vma                           ),
    .wr           ( bus_wr                            ),
    .addr         ( bus_addr                          ),
    .dout         ( dout                              ),
    .done         ( done                              )
);
`endif

endmodule
