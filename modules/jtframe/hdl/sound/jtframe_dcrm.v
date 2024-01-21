/*  This file is part of JTFRAME.

    JTFRAME is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 25-11-2020

    */

// This is pretty much a copy of jt49_dcrm2
// DC removal filter
// input is unsigned
// output is signed

/* verilator tracing_off */
module jtframe_dcrm #(parameter
    SW           = 8,
    SIGNED_INPUT = 0
)(
    input                   rst,
    input                   clk,
    input                   sample,
    input         [SW-1:0]  din,
    output signed [SW-1:0]  dout
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

assign dout = pre_dout[SW-1:0];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        samplel <= 0;
    end else begin
        samplel <= sample;
    end
end

always @(posedge clk, posedge rst) begin
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