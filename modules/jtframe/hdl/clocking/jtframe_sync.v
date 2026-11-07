/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 6-9-2021 */

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