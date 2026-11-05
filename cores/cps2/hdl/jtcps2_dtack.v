/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

// External-bus acknowledge delay from DL-1827 control-states.sch by
// Loic "WydD" Petit (CC-BY), https://petitl.fr/cps2/DL-1827.pdf.
module jtcps2_dtack(
    input        rst,
    input        clk,
    input        cpu_cen,
    input        cpu_cenb,
    input        ASn,
    input        BGACKn,
    input [23:20] A,
    output       board_wait
);

wire active, external_bus;
reg  as_rise, as_fall, timed_ack;

assign external_bus = A[23] | ~A[22] | (~A[21] & ~A[20]);
assign active       = ~ASn & BGACKn;
assign board_wait   = active & external_bus & ~timed_ack;

always @(posedge clk) begin
    if(rst || !active) begin
        as_rise  <= 0;
        as_fall  <= 0;
        timed_ack <= 0;
    end else begin
        if(cpu_cen) as_rise <= 1;
        if(cpu_cenb) begin
            as_fall <= as_rise;
            if(as_rise && !as_fall) timed_ack <= external_bus;
        end
    end
end

endmodule
