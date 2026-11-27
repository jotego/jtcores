`timescale 1ns/1ps

module test;

`include "test_tasks.vh"

localparam MDIV=8, PDIV=3, K=400;

reg        clk=0, rst=1;
reg  [1:0] pcnt=0;
wire       cen_in = pcnt==PDIV-1 && !rst;
wire       cen_div, cen_da;
reg  [K*2-1:0] ref_seq, seq;
integer    i, j, nin, ndiv;

jtframe_cendiv #(.MDIV(MDIV)) uut(
    .rst    ( rst     ),
    .clk    ( clk     ),
    .cen_in ( cen_in  ),
    .cen_div( cen_div ),
    .cen_da ( cen_da  )
);

always #10 clk = ~clk;

always @(posedge clk) pcnt <= rst || pcnt==PDIV-1 ? 2'd0 : pcnt+2'd1;

task record(output [K*2-1:0] s);
    integer k;
    begin
        for( k=0; k<K; k=k+1 ) begin
            @(posedge clk) #1 s[k*2+:2] = {cen_da, cen_div};
        end
    end
endtask

initial begin
    repeat(5) @(posedge clk);
    #1 rst = 0;
    record(ref_seq);
    for( j=0; j<12; j=j+1 ) begin
        repeat(j*5+1) @(posedge clk);
        #1 rst = 1;
        repeat(j+2) @(posedge clk);
        #1 rst = 0;
        record(seq);
        assert_msg( seq==ref_seq, "cen_div/cen_da after reset must match the first run");
    end
    nin = 0; ndiv = 0;
    for( i=0; i<PDIV*MDIV*100; i=i+1 ) @(posedge clk) #1 begin
        if(cen_in)  nin  = nin+1;
        if(cen_div) ndiv = ndiv+1;
    end
    assert_msg( nin==ndiv*MDIV, "cen_div must divide cen_in by MDIV");
    pass();
end

endmodule
