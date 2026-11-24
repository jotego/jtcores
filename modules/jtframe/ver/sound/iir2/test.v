`timescale 1ns/1ps
module test;
reg clk=0, rst=1, sample=0;
reg signed [13:0] sin=0;
wire signed [13:0] sout;
integer i, delta;
integer expected [0:23];
always #5 clk=~clk;

jtframe_iir2 #(.WS(14), .WC(15), .G(1)) uut(
    .clk(clk), .rst(rst), .sample(sample), .sin(sin), .sout(sout),
    .a1(-15'sd10483), .a2(15'sd3912),
    .b0(15'sd405), .b1(15'sd811), .b2(15'sd405)
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    expected[0]=198; expected[1]=649; expected[2]=934; expected[3]=885;
    expected[4]=687; expected[5]=456; expected[6]=256; expected[7]=109;
    expected[8]=18; expected[9]=-29; expected[10]=-46; expected[11]=-45;
    expected[12]=-36; expected[13]=-24; expected[14]=-14; expected[15]=-6;
    expected[16]=-1; expected[17]=1; expected[18]=2; expected[19]=2;
    expected[20]=2; expected[21]=1; expected[22]=1; expected[23]=0;
    repeat(3) @(negedge clk);
    rst=0;
    for (i=0; i<24; i=i+1) begin
        sin = i==0 ? 4000 : 0;
        repeat(3) @(negedge clk);
        delta = $signed(sout)-expected[i];
        if (delta < -5 || delta > 5) begin
            $display("FAIL impulse[%0d]: got %0d expected %0d",i,$signed(sout),expected[i]);
            $finish;
        end
        sample=1;
        @(negedge clk);
        sample=0;
    end
    $display("PASS");
    $finish;
end
endmodule
