/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-11-2020 */

// This is pretty much a copy of jt49_dcrm2
// DC removal filter
// input is unsigned
// output is signed

/* verilator tracing_off */
module jtframe_dcrm #(parameter
    SW           = 8,
    SIGNED_INPUT = 0
)(
    input rst,
    input clk,
    input sample,
    input             [SW-1:0]  din,
    output reg signed [SW-1:0]  dout
);

localparam DW=10; // width of the decimal portion

reg signed [SW+DW:0] integ, exact, error;
reg signed [SW   :0] pre_dout, q;
reg samplel;

always @(*) begin
    exact = integ+error;
    q = exact[SW+DW:DW];
    pre_dout  = { SIGNED_INPUT ? din[SW-1] : 1'b0, din } - q;
end

always @(posedge clk) begin
    dout <= pre_dout[SW-1:0];
end

always @(posedge clk) begin
    if( rst ) begin
        samplel <= 0;
    end else begin
        samplel <= sample;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        integ <= {SW+DW+1{1'b0}};
        error <= {SW+DW+1{1'b0}};
    end else if( sample & ~samplel ) begin
        /* verilator lint_off WIDTH */
        integ <= integ + pre_dout;
        /* verilator lint_on WIDTH */
        error <= exact-{q, {DW{1'b0}}};
    end
end

endmodule