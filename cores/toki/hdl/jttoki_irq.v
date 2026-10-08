/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-7-2026 */

module jttoki_irq(
    input             rst,
    input             clk,

    input             fm_irq_n,
    input             main_irq_trig,
    input             cpu_irq_ack,
    input             fm_eoi,
    input             main_eoi,

    output            cpu_irq_n,
    output      [7:0] im0_opcode
);

localparam [7:0] FM_RST10_OPCODE   = 8'hd7;
localparam [7:0] MAIN_RST18_OPCODE = 8'hdf;

wire fm_irq_trig, fm_irq_pending, main_irq_pending;
wire fm_irq_eligible, main_irq_eligible;
wire irq_ack_rise, main_irq_trig_rise;
wire fm_irq_accept, main_irq_accept, main_pending_clr;
reg  fm_irq_in_service, main_irq_in_service;
reg  cpu_irq_ack_l, main_irq_trig_l, im0_main_sel, im0_valid;

assign fm_irq_trig       = ~fm_irq_n;
assign fm_irq_eligible   = fm_irq_pending & ~fm_irq_in_service;
assign main_irq_eligible = main_irq_pending & ~main_irq_in_service;
assign irq_ack_rise      = cpu_irq_ack & ~cpu_irq_ack_l;
assign main_irq_trig_rise = main_irq_trig & ~main_irq_trig_l;
assign main_irq_accept   = irq_ack_rise & main_irq_eligible;
assign fm_irq_accept     = irq_ack_rise & fm_irq_eligible & ~main_irq_eligible;
assign main_pending_clr  = main_irq_accept & ~main_irq_trig_rise;
assign cpu_irq_n         = ~(fm_irq_eligible | main_irq_eligible);
assign im0_opcode        = cpu_irq_ack & cpu_irq_ack_l ?
                           (im0_valid ?
                               (im0_main_sel ? MAIN_RST18_OPCODE : FM_RST10_OPCODE) : 8'h00) :
                           main_irq_eligible ? MAIN_RST18_OPCODE :
                           fm_irq_eligible   ? FM_RST10_OPCODE : 8'h00;

always @(posedge clk) begin
    if (rst) begin
        fm_irq_in_service   <= 1'b0;
        main_irq_in_service <= 1'b0;
        cpu_irq_ack_l       <= 1'b0;
        main_irq_trig_l     <= 1'b0;
        im0_main_sel        <= 1'b0;
        im0_valid           <= 1'b0;
    end else begin
        cpu_irq_ack_l   <= cpu_irq_ack;
        main_irq_trig_l <= main_irq_trig;
        if (fm_eoi)          fm_irq_in_service   <= 1'b0;
        if (main_eoi)        main_irq_in_service <= 1'b0;
        if (fm_irq_accept)   fm_irq_in_service   <= 1'b1;
        if (main_irq_accept) main_irq_in_service <= 1'b1;
        if (irq_ack_rise) begin
            im0_main_sel <= main_irq_eligible;
            im0_valid    <= main_irq_eligible | fm_irq_eligible;
        end
    end
end

jtframe_edge u_fm_pending(
    .rst    ( rst            ),
    .clk    ( clk            ),
    .edgeof ( fm_irq_trig    ),
    .clr    ( fm_irq_n       ),
    .q      ( fm_irq_pending )
);

jtframe_edge u_main_pending(
    .rst    ( rst             ),
    .clk    ( clk             ),
    .edgeof ( main_irq_trig   ),
    .clr    ( main_pending_clr ),
    .q      ( main_irq_pending )
);

endmodule
