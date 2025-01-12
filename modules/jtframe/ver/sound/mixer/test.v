`timescale 1ns / 1ps

module test;

// input signals
reg  signed [15:0] ch0;
reg  signed [ 9:0] ch1;
reg  signed [ 4:0] ch2;
reg  signed [ 7:0] ch3;
wire signed [15:0] mixed;

reg  [7:0] gain;
wire       peak;

reg     clk, rst, error;
integer result,a, rlatch;

initial begin
    rst = 0;
    #15 rst = 1;
    #30 rst = 0;
end

initial begin
    clk = 0;
    forever #20 clk = ~clk;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ch0 <= 0;
        ch1 <= 0;
        ch2 <= 0;
        ch3 <= 0;
        gain<= 8'h1;
    end else begin
        rlatch <= result > 32767 ? 32767 : (result<-32768 ? -32768 : result);
        ch0 <= ch0 + 1;
        ch1 <= ch1 + 1;
        ch2 <= ch2 + 1;
        ch3 <= ch3 + 1;
        if( ch0==16'h7FFF ) begin
            gain <= {gain[6:0],1'b1};
            if( &gain ) $finish;
        end
    end
end

always @(*) begin
    result = 0;
    result = { {16{ch0[15]}}, ch0};
    a = { {16{ch1[9]}}, ch1, 6'd0};
    result = result + a;
    a = { {16{ch2[4]}}, ch2, 11'd0};
    result = result + a;
    a = { {16{ch3[7]}}, ch3, 8'd0};
    result = result + a;
    result = result * gain;
    result = result>>>4;

    error = rlatch[15:0] != mixed;
end

`define SIMULATION

jtframe_mixer #(.W0(16),.W1(10),.W2(5),.W3(8),.WOUT(16)) UUT(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    // input signals
    .ch0    ( ch0       ),
    .ch1    ( ch1       ),
    .ch2    ( ch2       ),
    .ch3    ( ch3       ),
    // gain for each channel in 4.4 fixed point format
    .gain0  ( gain      ),
    .gain1  ( gain      ),
    .gain2  ( gain      ),
    .gain3  ( gain      ),
    .mixed  ( mixed     ),
    .peak   ( peak      )
);

initial begin
`ifdef NCVERILOG
    $shm_open("test.shm");
    $shm_probe(test,"AS");
`else
    $dumpfile("test.lxt");
    $dumpvars;
`endif
end

endmodule