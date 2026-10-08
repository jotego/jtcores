module test;

reg nRES, AM32;

initial begin
    AM32=0;
    forever #5 AM32=~AM32;
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
end

initial begin
    nRES=0;
    #100;
    nRES=1;
    #10000;
    $finish;
end

reg C248, B214, C216, C204, C254;
wire AB248;

YFD2 Cell_AM254(AM32, nAM254, nRES, , nAM254);
YFD2 Cell_AS254(nAM254, nAS254, nRES, , nAS254);
YFD2 Cell_AT254(nAS254, nAT254, nRES, , nAT254);
YFD2 Cell_AV218(nAT254, nAV218, nRES, , nAV218);
assign AB248 = ~|{nAM254, nAS254, nAT254, nAV218};

assign B236 = ~&{AB248, C248};
assign A217 = ~|{B236, ~B214};
assign C210 = ~&{A217, C216};
assign C211 = ~|{C210, ~C204};
assign B220 = ~C211;

always @(posedge AM32 or negedge nRES) begin
    // Second counter block
    if (!nRES) begin
        {C248, B214, C216, C204, C254} <= 5'd0;
    end else begin
        C248 <= ~&{B220, ~C248 ^ AB248};
        B214 <= &{B220, ~(B214 ^ B236)};
        C216 <= &{B220, ~(~C216 ^ A217)};
        C204 <= ~&{B220, C204 ^ C210};
        C254 <= C211;
    end
end

assign TIM2 = C254; // input clock divided by 112

endmodule // test

module YFD2(
    input clk, d, rstn,
    output reg q, qn
);

always @(posedge clk, negedge rstn) begin
    if(!rstn) begin
        q  <= 1;
        qn <= 0;
    end else begin
        q  <= d;
        qn <= ~d;
    end
end

endmodule