/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

module jt8051(
    input             rst,
    input             clk,
    input             cen,
    input             int0n,
    input             int1n,
    input      [ 7:0] p0_i,
    input      [ 7:0] p1_i,
    input      [ 7:0] p2_i,
    input      [ 7:0] p3_i,
    output     [ 7:0] p0_o,
    output     [ 7:0] p1_o,
    output     [ 7:0] p2_o,
    output     [ 7:0] p3_o,
    input      [ 7:0] rom_data,
    output     [15:0] rom_addr,
    input      [ 7:0] ram_din,
    output     [ 7:0] ram_dout,
    output     [ 6:0] ram_addr,
    output            ram_we,
    input      [ 7:0] x_din,
    output     [ 7:0] x_dout,
    output     [15:0] x_addr,
    output            x_wr,
    output            x_acc
);

wire [ 7:0] ir, a, b, psw, sp, sfr_dout, sfr_addr, sfr_din;
wire [15:0] dptr, pc, irq_vec;
wire [ 7:0] lhs, rhs, alu_result, alu_aux;
wire [ 4:0] alu_sel, src_sel;
wire [ 4:0] dst_sel;
wire [ 3:0] pc_sel, cond_sel;
wire [ 2:0] flag_sel;
wire [ 2:0] addr_sel;
wire [ 2:0] bitno;
wire [ 1:0] code_sel, x_sel, xwr_sel;
wire        alu_cy, alu_ac, alu_ov, alu_neq, cond;
wire        wr, sp_inc, sp_dec, x_acc_i, latch, sfr_we, sfr_latch;
wire        irq, irq_take, reti, instruction_end, next_instruction;

`ifdef SIMULATION
reg         cen_l;
always @(posedge clk) begin
    if (rst) begin
        cen_l <= 0;
    end else begin
        if (cen && cen_l) begin
            $fatal(1,"jt8051 requires an idle clk cycle between cen pulses for timing constraints");
        end
        cen_l <= cen;
    end
end
`endif

jt8051_ctrl u_ctrl(
    .rst              ( rst              ),
    .clk              ( clk              ),
    .cen              ( cen              ),
    .ir               ( ir               ),
    .irq              ( irq              ),
    .alu_sel          ( alu_sel          ),
    .src_sel          ( src_sel          ),
    .dst_sel          ( dst_sel          ),
    .addr_sel         ( addr_sel         ),
    .pc_sel           ( pc_sel           ),
    .cond_sel         ( cond_sel         ),
    .flag_sel         ( flag_sel         ),
    .code_sel         ( code_sel         ),
    .x_sel            ( x_sel            ),
    .wr               ( wr               ),
    .sp_inc           ( sp_inc           ),
    .sp_dec           ( sp_dec           ),
    .x_acc            ( x_acc_i          ),
    .xwr_sel          ( xwr_sel          ),
    .latch            ( latch            ),
    .irq_take         ( irq_take         ),
    .reti             ( reti             ),
    .instruction_end  ( instruction_end  ),
    .next_instruction ( next_instruction )
);

jt8051_alu u_alu(
    .alu_sel   ( alu_sel        ),
    .lhs       ( lhs            ),
    .rhs       ( rhs            ),
    .carry     ( psw[7]         ),
    .aux_carry ( psw[6]         ),
    .bitno     ( bitno          ),
    .result    ( alu_result     ),
    .aux       ( alu_aux        ),
    .cy        ( alu_cy         ),
    .ac        ( alu_ac         ),
    .ov        ( alu_ov         ),
    .neq       ( alu_neq        )
);

jt8051_regs u_regs(
    .rst         ( rst         ),
    .clk         ( clk         ),
    .cen         ( cen         ),
    .src_sel     ( src_sel     ),
    .dst_sel     ( dst_sel     ),
    .addr_sel    ( addr_sel    ),
    .pc_sel      ( pc_sel      ),
    .cond_sel    ( cond_sel    ),
    .flag_sel    ( flag_sel    ),
    .wr          ( wr          ),
    .sp_inc      ( sp_inc      ),
    .sp_dec      ( sp_dec      ),
    .code_sel    ( code_sel    ),
    .x_sel       ( x_sel       ),
    .x_acc_i     ( x_acc_i     ),
    .x_wr_i      ( xwr_sel     ),
    .irq_vec     ( irq_vec     ),
    .rom_data    ( rom_data    ),
    .rom_addr    ( rom_addr    ),
    .ram_din     ( ram_din     ),
    .ram_dout    ( ram_dout    ),
    .ram_addr    ( ram_addr    ),
    .ram_we      ( ram_we      ),
    .x_din       ( x_din       ),
    .x_dout      ( x_dout      ),
    .x_addr      ( x_addr      ),
    .x_wr        ( x_wr        ),
    .x_acc       ( x_acc       ),
    .sfr_dout    ( sfr_dout    ),
    .sfr_addr    ( sfr_addr    ),
    .sfr_din     ( sfr_din     ),
    .sfr_we      ( sfr_we      ),
    .latch_read  ( latch       ),
    .sfr_latch   ( sfr_latch   ),
    .p2_latch    ( p2_o        ),
    .alu_result  ( alu_result  ),
    .alu_aux     ( alu_aux     ),
    .alu_cy      ( alu_cy      ),
    .alu_ac      ( alu_ac      ),
    .alu_ov      ( alu_ov      ),
    .alu_neq     ( alu_neq     ),
    .lhs         ( lhs         ),
    .rhs         ( rhs         ),
    .bitno       ( bitno       ),
    .ir          ( ir          ),
    .a           ( a           ),
    .b           ( b           ),
    .psw         ( psw         ),
    .sp          ( sp          ),
    .dptr        ( dptr        ),
    .pc          ( pc          ),
    .cond        ( cond        )
);

jt8051_periph u_periph(
    .rst             ( rst             ),
    .clk             ( clk             ),
    .cen             ( cen             ),
    .int0n           ( int0n           ),
    .int1n           ( int1n           ),
    .p0_i            ( p0_i            ),
    .p1_i            ( p1_i            ),
    .p2_i            ( p2_i            ),
    .p3_i            ( p3_i            ),
    .p0_o            ( p0_o            ),
    .p1_o            ( p1_o            ),
    .p2_o            ( p2_o            ),
    .p3_o            ( p3_o            ),
    .sfr_addr        ( sfr_addr        ),
    .sfr_din         ( sfr_din         ),
    .sfr_we          ( sfr_we          ),
    .latch_read      ( sfr_latch       ),
    .sfr_dout        ( sfr_dout        ),
    .irq_take        ( irq_take        ),
    .reti            ( reti            ),
    .instruction_end ( instruction_end ),
    .irq             ( irq             ),
    .irq_vec         ( irq_vec         )
);

endmodule
