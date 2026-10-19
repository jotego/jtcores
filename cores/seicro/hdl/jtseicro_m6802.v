/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-10-2026 */

module jtseicro_m6802(
    input             rst, cpu_rst, clk, cen, enable,
    input             ready, mr_n, nsc8105,
    input      [7:0]   din,
    output     [15:0]  addr,
    output     [7:0]   dout,
    output            e, vma, wr, done, instruction_end, opcode_fetch
);
// Bus contracts and provisional derivative timing: ../doc/pal.md.
wire bus, valid, cycle_wr, retire, halt, fault, ni, entry, nscop, fccompat, fetch;
wire [15:0] cycle_addr;
wire [7:0] cycle_dout, next_op, decoded;
reg waiting, illegal, check_entry;
reg [7:0] opcode, raw_opcode;
wire [15:0] op0, op1, rslt,md;
wire [3:0] rslt_cc, alu_cc;
wire        h, rslt_h, c, i;

wire        alt;
wire        alu16;
wire        branch;

wire        inc_pc;
wire        md_shift;

wire        op0inv;
wire [ 1:0] carry_sel;
wire [ 2:0] ea_sel;
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
wire adcx = nsc8105 && ld_sel==X_LD && cc_sel==HNZVC_CC;
assign rslt_cc = cmpx ? {cmp_hi[7],rslt==16'd0,cmp_v,c} :
                adcx ? {alu_cc[3:1],rslt[8]} : alu_cc;


wire core_rst=rst || cpu_rst;
wire invalid_entry=check_entry && (!entry || (nscop && !nsc8105) ||
    (fccompat && (nsc8105 || raw_opcode!=8'hfc)));
wire microstep=!core_rst && enable && !waiting && !illegal && !invalid_entry && (!bus || done);
assign opcode_fetch=bus && ni;
assign instruction_end=microstep && retire;
always @(posedge clk) begin
    if(core_rst) begin
        waiting <= 0;
        illegal <= 0;
        opcode <= 0;
        raw_opcode <= 0;
        check_entry <= 0;
    end else if(invalid_entry) illegal <= 1;
    else if(microstep) begin
        check_entry <= ni;
        if(halt) waiting <= 1;
        if(fault) illegal <= 1;
        if(ni) begin
            opcode <= next_op;
            raw_opcode <= din;
        end
    end
end
`ifdef SIMULATION
always @(posedge clk) if(!core_rst && illegal)
    $fatal(1,"Microcoded MCU unsupported opcode raw=%h decoded=%h at %h",raw_opcode,opcode,u_regs.op_pc);
`endif
// FC compatibility only; absent from MC6802 manual, real-chip behavior/timing unknown.
assign next_op=(!nsc8105 && din==8'hfc) ? 8'h03 : decoded;
jtseicro_nsc8105_decode u_decode(
    .enable ( nsc8105 ),
    .raw    ( din     ),
    .opcode ( decoded )
);

jtseicro_m6802_ctrl u_ctrl(
    .rst       ( core_rst  ),
    .clk       ( clk       ),
    .cen       ( microstep ),
    .opcode    ( next_op   ),
    .iv        ( iv        ),
    .alt       ( alt       ),
    .alu16     ( alu16     ),
    .branch    ( branch    ),
    .fetch     ( fetch     ),
    .ni        ( ni        ),
    .inc_pc    ( inc_pc    ),
    .md_shift  ( md_shift  ),
    .op0inv    ( op0inv    ),
    .wr        ( cycle_wr  ),
    .bus       ( bus       ),
    .valid     ( valid     ),
    .retire    ( retire    ),
    .halt      ( halt      ),
    .illegal   ( fault     ),
    .entry     ( entry     ),
    .nscop     ( nscop     ),
    .fccompat  ( fccompat  ),
    .ea_sel    ( ea_sel    ),
    .carry_sel ( carry_sel ),
    .opnd_sel  ( opnd_sel  ),
    .alu_sel   ( alu_sel   ),
    .ld_sel    ( ld_sel    ),
    .rmux_sel  ( rmux_sel  ),
    .cc_sel    ( cc_sel    )
);

jt680x_alu u_alu(
    .rst       ( core_rst  ),
    .clk       ( clk       ),
    .cen       ( microstep ),
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

jtseicro_m6802_regs u_regs(
    .rst      ( core_rst   ),
    .clk      ( clk        ),
    .cen      ( microstep  ),
    .opcode   ( next_op    ),
    .ni       ( ni         ),
    .md       ( md         ),
    .alt      ( alt        ),
    .brlatch  ( ni         ),
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
    .i        ( i          ),
    .iv       ( iv         ),
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

jtseicro_m6802_bus u_bus(
    .rst          ( rst                                           ),
    .abort        ( cpu_rst                                       ),
    .clk          ( clk                                           ),
    .cen          ( cen                                           ),
    .enable       ( enable                                        ),
    .ready        ( ready                                         ),
    .mr_n         ( mr_n                                          ),
    .cycle_active ( bus && !waiting && !illegal && !invalid_entry ),
    .cycle_vma    ( valid                                         ),
    .cycle_wr     ( cycle_wr                                      ),
    .cycle_addr   ( cycle_addr                                    ),
    .cycle_dout   ( cycle_dout                                    ),
    .e            ( e                                             ),
    .vma          ( vma                                           ),
    .wr           ( wr                                            ),
    .addr         ( addr                                          ),
    .dout         ( dout                                          ),
    .done         ( done                                          )
);
endmodule
