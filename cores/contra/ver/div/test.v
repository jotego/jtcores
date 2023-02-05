`timescale 1ns/1ps

module test;

reg              rst, clk, cs, wrn;
reg        [2:0] addr;
reg        [7:0] din;
wire   reg [7:0] dout;
reg       [15:0] uut_quo, uut_rmd;
reg       [15:0] divisor, dividend;

jtcontra_007452 uut(
    .rst    ( rst   ),
    .clk    ( clk   ),
    .cs     ( 1'b1  ),
    .wrn    ( wrn   ),
    .addr   ( addr  ),
    .din    ( din   ),
    .dout   ( dout  )
);

initial begin
    clk = 0;
    forever #10 clk = ~clk;
end

initial begin
    rst = 1;
    addr = 0;
    din  = 0;
    wrn  = 1;
    #20 rst = 0;
    repeat(200) begin
        divisor = $random;
        dividend= $random;
        // divisor
        @(negedge clk);
        addr=2;
        din=divisor[15:8];
        wrn = 0;
        @(negedge clk);
        addr=3;
        din=divisor[7:0];
        @(negedge clk);
        // dividend
        addr=4;
        din=dividend[15:8];
        @(negedge clk);
        addr=5;
        din=dividend[7:0];
        @(negedge clk);
        wrn = 1;
        repeat(20) @(negedge clk);  // wait for result
        addr=5;
        @(negedge clk);
        uut_quo[15:8] = dout;
        addr=4;
        @(negedge clk);
        uut_quo[7:0] = dout;
        addr=3;
        @(negedge clk);
        uut_rmd[15:8] = dout;
        addr=2;
        @(negedge clk);
        uut_rmd[7:0] = dout;
        @(negedge clk);
        if( uut_quo != dividend/divisor ) begin
            $display("Error: quotient is wrong. Expected %04X",dividend/divisor);
            $finish;
        end
        if( uut_rmd != dividend%divisor ) begin
            $display("Error: remainder is wrong. Expected %04X",dividend%divisor);
            $finish;
        end
    end
    $finish;
end

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end


endmodule