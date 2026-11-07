`timescale 1ns/1ps
module test;
`include "replay.vh"
reg clk=0, rst=1;
reg [3:0] pins;
reg [3:0] invert=4'(INVERT);
reg [15:0] stimulus[0:32767];
reg [16:0] expected[0:EXPECTED_COUNT-1];
wire [15:0] word;
wire word_valid, word_channel, bad_frame;
integer i,received=0,errors=0;
always #5 clk=~clk;
`ifdef TRACE
initial begin
    $dumpfile("test.fst");
    $dumpvars(0,test);
end
`endif
c96_yamaha_sampler uut(
    .clk          ( clk          ),
    .rst          ( rst          ),
    .clear        ( 1'b0         ),
    .pins         ( pins         ),
    .invert       ( invert       ),
    .word         ( word         ),
    .word_valid   ( word_valid   ),
    .word_channel ( word_channel ),
    .half_period  (              ),
    .bad_frame    ( bad_frame    )
);
always @(negedge clk) begin
    if(bad_frame) errors=errors+1;
    if(word_valid) begin
        if(received>=EXPECTED_COUNT || {word_channel,word}!==expected[received]) begin
            $display("FAIL: word %0d got %05x expected %05x",received,
                     {word_channel,word},expected[received]);
            $fatal;
        end
        received=received+1;
    end
end
initial begin
    $readmemh("replay.stimulus.hex",stimulus);
    $readmemh("replay.expected.hex",expected);
    pins=stimulus[0][3:0];
    repeat(8) @(negedge clk);
    rst=0;
    for(i=0;i<STIMULUS_COUNT;i=i+1) begin
        pins=stimulus[i][3:0];
        repeat(PERIOD_TICKS) @(negedge clk);
    end
    if(received!=EXPECTED_COUNT || errors!=0) begin
        $display("FAIL: replay received %0d/%0d words, %0d framing errors",received,EXPECTED_COUNT,errors);
        $fatal;
    end
    $display("PASS: raw hardware replay matches every independently decoded Yamaha word (%0d)",received);
    $finish;
end
initial begin #10000000; $display("FAIL: timeout"); $fatal; end
endmodule
