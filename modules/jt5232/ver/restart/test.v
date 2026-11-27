`timescale 1ns/1ps

module test;

`include "test_tasks.vh"

localparam K=40000;

reg         clk=0, rst=1, we=0;
reg  [ 1:0] ccnt=0;
reg  [ 3:0] addr=0;
reg  [ 7:0] din=0;
wire        cen1 = ccnt==3 && !rst;
wire        cen2 = ccnt==1 && !rst;
wire [14:0] snd1, snd2;
reg  [31:0] ref_crc, crc;
integer     j;

jt5232 uut(
    .rst    ( rst   ),
    .clk    ( clk   ),
    .cen1   ( cen1  ),
    .cen2   ( cen2  ),
    .din    ( din   ),
    .addr   ( addr  ),
    .we     ( we    ),
    .snd1   ( snd1  ),
    .snd2   ( snd2  ),
    .clip   (       ),
    .no_used(       )
);

always #10 clk = ~clk;

always @(posedge clk) ccnt <= rst ? 2'd0 : ccnt+2'd1;

task wr(input [3:0] a, input [7:0] d);
    begin
        @(posedge clk) #1 begin addr=a; din=d; we=1; end
        @(posedge clk) #1 we=0;
        repeat(37) @(posedge clk);
    end
endtask

task play_and_hash(output [31:0] h);
    integer k;
    begin
        wr(4'd8, 8'd2); wr(4'd9, 8'd3);
        wr(4'd10,8'd5); wr(4'd11,8'd9);
        wr(4'd12,8'h3f); wr(4'd13,8'h3f);
        wr(4'd0, 8'hc0); wr(4'd2, 8'hb3); wr(4'd5, 8'hd7);
        wr(4'd3, 8'hdc);
        h = 0;
        for( k=0; k<K; k=k+1 ) begin
            @(posedge clk) #1;
            if( k==K/2 ) begin
                addr=4'd0; din=8'h40; we=1;
            end else we=0;
            h = {h[30:0],1'b0} ^ (h[31] ? 32'h04c11db7 : 32'd0) ^ {2'd0,snd1,snd2};
        end
    end
endtask

initial begin
    repeat(5) @(posedge clk);
    #1 rst = 0;
    play_and_hash(ref_crc);
    assert_msg( ref_crc!=0, "the output must not be silent");
    for( j=0; j<6; j=j+1 ) begin
        wr(4'd1, 8'h80|(j*13));
        wr(4'd6, 8'h80|(j*29));
        wr(4'd7, 8'hd8+j);
        repeat(j*1733+11) @(posedge clk);
        #1 rst = 1;
        repeat(j*7+3) @(posedge clk);
        #1 rst = 0;
        play_and_hash(crc);
        assert_msg( crc==ref_crc, "the output after reset must match the first run");
    end
    pass();
end

endmodule
