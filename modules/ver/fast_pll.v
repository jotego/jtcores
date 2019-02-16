`timescale 1ns/1ps

module jtgng_pll0(
    input    inclk0,
    output   c1,      // 12
    output   reg c2,      // 96
    output       c3,     // 96 (shifted by -2.5ns)
    output   locked
);

assign locked = 1'b1;

initial begin
    c2 = 1'b0;
    forever c2 = #(10.417/2) ~c2;
end

reg [3:0] div=4'd0;
always @(posedge c2) div<=div+4'd1;
assign c1 = div[2];

assign #2.5 c3 = c2;

endmodule // jtgng_pll0


module jtgng_pll1 (
    input inclk0,
    output reg c0     // 25
);

initial begin
    c0 = 1'b0;
    forever c0 = #20 ~c0;
end

endmodule // jtgng_pll1