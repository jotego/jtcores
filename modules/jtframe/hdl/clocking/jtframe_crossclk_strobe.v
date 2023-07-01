/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 12-8-2022 */

// Converts an active-high strobe in one clock domain to
// a strobe in a different clock domain
//
// There is a max frequency for the strobe transfer, depending
// on the ratio of the two clocks and the synchronizer stages
//
// An optional DLY parameter will shift the output strobe a
// number of clock cycles

module jtframe_crossclk_strobe(
    input       clk_in,
    input       clk_out,
    input       stin,
    output      stout
);

parameter DLY=0;

reg [1:0] sclr=0;
reg [2:0] sset=0;
reg       set=0, pre_out=0;
wire      clr;

assign clr = sset[1];

always @(posedge clk_in) begin
    sclr <= { sclr[0], clr };
    if( stin ) set <= 1;
    if( sclr[1] ) set <= 0;
end

always @(posedge clk_out) begin
    sset    <= { sset[1:0], set };
    pre_out <= sset[2:1]==2'b01;
end

generate
    if (DLY==0) begin
        assign stout = pre_out;
    end else begin
        reg [DLY-1:0] dly;
        assign stout = dly[DLY-1];

        always @(posedge clk_out) begin
            dly    <= dly<<1;
            dly[0] <= pre_out;
        end
    end
endgenerate

endmodule