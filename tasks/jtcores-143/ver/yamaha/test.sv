`timescale 1ns/1ps
module test;

reg clk=0, rst=1, clear=0;
reg [3:0] pins=4'h7, invert=0;
wire [15:0] word;
wire word_valid, word_channel, bad_frame;
reg [16:0] expected[0:255];
integer produced=0, received=0, errors=0, bit_time=0;
integer i, j, before_errors, before_received;
reg check_words=0;
reg [15:0] source;

always #5 clk=~clk;
initial begin
    $dumpfile("test.lxt");
    $dumpvars(0,test);
end
initial begin
    #10000000;
    $display("FAIL: timeout");
    $fatal;
end

c96_yamaha_sampler uut(
    .clk          ( clk          ),
    .rst          ( rst          ),
    .clear        ( clear        ),
    .pins         ( pins         ),
    .invert       ( invert       ),
    .word         ( word         ),
    .word_valid   ( word_valid   ),
    .word_channel ( word_channel ),
    .half_period  (              ),
    .bad_frame    ( bad_frame    )
);

always @(negedge clk) begin
    if (bad_frame) errors=errors+1;
    if (word_valid && check_words) begin
        if (received>=produced || {word_channel,word}!==expected[received]) begin
            $display("FAIL: sample %0d got %h expected %h",received,
                     {word_channel,word},expected[received]);
            $fatal;
        end
        received=received+1;
    end
end

task tick(input integer n);
    repeat(n) @(negedge clk);
endtask

task start_stream(input [3:0] polarity);
begin
    check_words=0;
    invert=polarity;
    pins=4'h3 ^ polarity;
    clear=1;
    tick(8);
    clear=0;
    tick(8);
    produced=0;
    received=0;
    errors=0;
    bit_time=0;
    check_words=1;
end
endtask

task emit(input integer index, input [15:0] value);
    integer k, duration;
    reg [3:0] corrected;
begin
    if (index>0) begin
        expected[produced]={index[0]^1'b1,value};
        produced=produced+1;
    end
    corrected=pins^invert;
    corrected[index%2]=0;
    for(k=0;k<16;k=k+1) begin
        if(k==8) corrected[(index+1)%2]=1;
        corrected[2]=value[k];
        pins=corrected^invert;
        // Fractional 55.875-clock bit cells exercise noninteger clock ratios.
        duration=bit_time%8==0 ? 55 : 56;
        bit_time=bit_time+1;
        tick(duration);
    end
end
endtask

initial begin
    tick(8);
    rst=0;
    for(j=0;j<2;j=j+1) begin
        start_stream(j==0 ? 4'd0 : 4'd15);
        for(i=0;i<128;i=i+1) begin
            // Exercise all exponent encodings, sign, mantissa and dummy bits.
            source={i[2:0],i[0],i[7:0],i[3:0]};
            emit(i,source);
        end
        if(received!=127 || errors!=0) begin
            $display("FAIL: polarity %0d produced=%0d received=%0d errors=%0d",
                     j,produced,received,errors);
            $fatal;
        end
        before_received=received;
        tick(2200);
        if(errors!=1 || received!=before_received) begin
            $display("FAIL: missing strobe error or fabricated sample");
            $fatal;
        end
    end
    check_words=0;
    start_stream(15);
    emit(0,16'h3000);
    // A repeated channel strobe is malformed and must lose alignment.
    pins[0]=0;
    tick(20);
    pins[0]=1;
    tick(20);
    if(errors!=1) begin
        $display("FAIL: repeated strobe was accepted");
        $fatal;
    end
    $display("PASS: Yamaha packing, channels, fractional bit timing, inversion, clear and framing errors");
    $finish;
end
endmodule
