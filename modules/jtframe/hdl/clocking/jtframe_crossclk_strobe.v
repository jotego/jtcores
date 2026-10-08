/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 12-8-2022 */

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