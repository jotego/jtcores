`timescale 1ns/1ps

module test;

`include "test_tasks.vh"

localparam [9:0] N=10'd5, M=10'd12;
localparam       K=200;

reg        clk=0, rst=0;
wire [1:0] cen, cenb;
reg  [K*4-1:0] ref_seq, seq;
integer    i, j, cnt, during;

jtframe_frac_cen uut(
    .rst    ( rst   ),
    .clk    ( clk   ),
    .n      ( N     ),
    .m      ( M     ),
    .cen    ( cen   ),
    .cenb   ( cenb  )
);

always #10 clk = ~clk;

task record(output [K*4-1:0] s);
    integer k;
    begin
        for( k=0; k<K; k=k+1 ) begin
            @(posedge clk) #1 s[k*4+:4] = {cenb, cen};
        end
    end
endtask

initial begin
    record(ref_seq);
    for( j=0; j<12; j=j+1 ) begin
        repeat(j*7+3) @(posedge clk);
        #1 rst = 1;
        during = 0;
        for( i=0; i<3*M+j; i=i+1 ) @(posedge clk) #1 if(cen[0]) during = during+1;
        assert_msg( during>0, "cen must keep running during reset");
        rst = 0;
        @(posedge clk) #1 assert_msg( {cenb,cen}==0, "no cen on the restart cycle");
        @(posedge clk) #1;
        record(seq);
        assert_msg( seq==ref_seq, "cen sequence after reset must match the power-up sequence");
    end
    cnt = 0;
    for( i=0; i<M*100; i=i+1 ) @(posedge clk) #1 if(cen[0]) cnt = cnt+1;
    assert_msg( cnt==N*100, "cen frequency must be N/M");
    pass();
end

endmodule
