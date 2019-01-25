
module jtgng_pll0(
    input    inclk0,
    output   reg c1,      // 24
    output   reg c2,      // 96
    output   reg c3,     // 96 (shifted by -2.5ns)
    output   locked
);

assign locked = 1'b1;
initial begin
    c1 = 1'b0;
    forever c1 = #20.833 ~c1;
end

initial begin
    c2 = 1'b0;
    forever c2 = #5.208 ~c2;
end

initial begin
    c3 = 1'b0;
    #2.5;
    forever c3 = #5.208 ~c3;
end

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