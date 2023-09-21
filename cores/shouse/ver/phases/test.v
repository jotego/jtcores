// phase signals in schematic sheet 8A

`timescale 1ns/1ps

module test;
    reg cka, ckb, ckc, ckd;
    reg phasea, phaseb, phasec, phased;
    reg [1:0] H=0;
    wire H2 = H[1];

    reg clk6m;

    initial begin
        clk6m = 0;
        forever #83.333 clk6m = ~clk6m;
    end

    initial begin
        $dumpfile("test.lxt");
        $dumpvars;
        $dumpon;
        #2000 $finish;
    end

    always @(posedge clk6m) begin
        H <= H+2'd1;
        ckb <=  H2;
        ckd <= ~H2;
        ckc <=  ckb;
        cka <= ~ckb;
        phaseb <=  H2;
        phased <= ~H2;
        phasec <=  ckb;
        phasea <= ~ckb;
    end

endmodule
