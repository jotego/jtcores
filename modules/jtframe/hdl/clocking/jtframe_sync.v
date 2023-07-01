/*  This file is part of JT_FRAME.
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
    Date: 6-9-2021 */

// Enable the LATCHIN parameter if the raw input comes
// from combinational logic

module jtframe_sync #( parameter
    W=1,        // input signal bit width
    LATCHIN=0,  // latch the input signal with the input clock
    SW =2,      // Number of synchronizing stages
    AND=0       // Adds one more bit to the shift register and
                // the output only goes high if the last two bits
                // were high.
)(
    input   clk_in,
    input   clk_out,
    input   [W-1:0] raw,
    output  [W-1:0] sync
);

localparam EW = SW + AND[0];

`ifdef SIMULATION
initial begin
    if( SW<2 ) begin $display("%m SW cannot be less than 2"); $finish; end
end
`endif

reg  [W-1:0] latched;
wire [W-1:0] eff;

always @(posedge clk_in) latched <= raw;
assign eff = LATCHIN ? latched : raw;

generate
    genvar i;
    for( i=0; i<W; i=i+1 ) begin : synchronizer
        reg [EW-1:0] s;
        assign sync[i] = AND ? &s[EW-1:EW-2] : s[EW-1];

        always @(posedge clk_out) begin
            s    <= s << 1; // two step assignment to avoid
            s[0] <= eff[i]; // warnings and errors in some tools
        end
    end
endgenerate

endmodule

module jtframe_sync_cen #(parameter W=1, LATCHIN=0)(
    input   clk_in,
    input   clk_out,
    input   cen,
    input   [W-1:0] raw,
    output  [W-1:0] sync
);

reg  [W-1:0] latched;
wire [W-1:0] eff;

always @(posedge clk_in) if(cen) latched <= raw;
assign eff = LATCHIN ? latched : raw;

generate
    genvar i;
    for( i=0; i<W; i=i+1 ) begin : synchronizer
        reg [1:0] s;
        assign sync[i] = s[1];

        always @(posedge clk_out) begin
            s <= { s[0], eff[i] };
        end
    end
endgenerate

endmodule