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
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>. */

module jttoki_irq(
    input             rst,
    input             clk,

    input             fm_irq_n,
    input             main_irq_trig,
    input             z80_irq_ack,
    input             fm_eoi,
    input             main_eoi,

    output            z80_irq_n,
    output      [7:0] im0_opcode
);

localparam [7:0] FM_RST10_OPCODE   = 8'hd7;
localparam [7:0] MAIN_RST18_OPCODE = 8'hdf;

wire fm_irq_trig, fm_irq_pending, main_irq_pending;
wire fm_irq_eligible, main_irq_eligible;
wire z80_irq_ack_rise, fm_irq_accept, main_irq_accept;
reg  fm_irq_in_service, main_irq_in_service;
reg  z80_irq_ack_l, im0_main_sel;

assign fm_irq_trig       = ~fm_irq_n;
assign fm_irq_eligible   = fm_irq_pending & ~fm_irq_in_service;
assign main_irq_eligible = main_irq_pending & ~main_irq_in_service;
assign z80_irq_ack_rise  = z80_irq_ack & ~z80_irq_ack_l;
assign main_irq_accept   = z80_irq_ack_rise & main_irq_eligible;
assign fm_irq_accept     = z80_irq_ack_rise & fm_irq_eligible & ~main_irq_eligible;
assign z80_irq_n         = ~(fm_irq_eligible | main_irq_eligible);
assign im0_opcode        = z80_irq_ack & z80_irq_ack_l ?
                           (im0_main_sel ? MAIN_RST18_OPCODE : FM_RST10_OPCODE) :
                           main_irq_eligible ? MAIN_RST18_OPCODE :
                           fm_irq_eligible   ? FM_RST10_OPCODE : 8'hff;

always @(posedge clk) begin
    if (rst) begin
        fm_irq_in_service   <= 1'b0;
        main_irq_in_service <= 1'b0;
        z80_irq_ack_l       <= 1'b0;
        im0_main_sel        <= 1'b0;
    end else begin
        z80_irq_ack_l <= z80_irq_ack;
        if (fm_eoi)          fm_irq_in_service   <= 1'b0;
        if (main_eoi)        main_irq_in_service <= 1'b0;
        if (fm_irq_accept)   fm_irq_in_service   <= 1'b1;
        if (main_irq_accept) main_irq_in_service <= 1'b1;
        if (z80_irq_ack_rise) im0_main_sel <= main_irq_eligible;
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
    .clr    ( main_irq_accept ),
    .q      ( main_irq_pending )
);

endmodule
