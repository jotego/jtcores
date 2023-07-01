/*  Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-4-2022 */

// Enable the LATCHIN parameter if the raw input comes
// from combinational logic

module mister_clksync #(parameter W=1, LATCHIN=0)(
    input   clk_in,
    input   clk_out,
    input   [W-1:0] raw,
    output  [W-1:0] sync
);

reg  [W-1:0] latched;
wire [W-1:0] eff;

always @(posedge clk_in) latched <= raw;
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