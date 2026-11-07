/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 31-10-2019 */

// Converts an input strobe (stin) defined in some clock gating domain
// to a strobe in the specified cen input domain
// both clock-enable signals belong to the same clock domain

module jtframe_cencross_strobe(
    input       rst,
    (* direct_enable *) input       cen,
    input       clk,
    input       stin,
    output reg  stout
);

reg  last, st_latch;
wire st_edge = stin && !last;

always @(posedge clk) begin
    if(rst) begin
        last     <= 1'b0;
        st_latch <= 1'b0;
    end else begin 
        last <= stin;
        if( st_edge ) st_latch <= 1'b1;
        if( stout ) st_latch <= 1'b0;
    end
end

always @(posedge clk) begin
    if(rst) begin
        stout    <= 1'b0;
    end else  if(cen) begin
        stout <= st_latch | st_edge;
    end
end

endmodule