`timescale 1ns/1ps

module jtgng_pll0(
    input    inclk0,
    output   reg c1,      // 12
    output   reg c2,      // 96
    output       c3,     // 96 (shifted by -2.5ns)
    output   locked
);

assign locked = 1'b1;

initial begin
    c2 = 1'b0;
    // forever c2 = #(10.417/2) ~c2; // 96 MHz
    forever c2 = #(9.259/2) ~c2; // 108 MHz
end

reg [3:0] div=5'd0;

initial c1=1'b0;

always @(posedge c2) begin
    div <= div=='d8 ? 'd0 : div+'d1;
    if ( div=='d0 ) c1 <= 1'b0;
    if ( div=='d4 ) c1 <= 1'b1;
end

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