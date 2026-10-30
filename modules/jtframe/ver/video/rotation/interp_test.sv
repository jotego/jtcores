`timescale 1ns/1ps
module interp_test;
reg clk=0;
always #5 clk=~clk;
reg ce=0, blank=0;
reg [7:0] fraction=0;
reg [5:0] current=0, previous=0;
wire [4:0] out5;
wire [5:0] out6;
pixel_interp #(.signalwidth(5)) dut5(
 .clk(clk),.ce(ce),.blank(blank),.frac(fraction),
 .in(current[4:0]),.in_prev(previous[4:0]),.out(out5));
pixel_interp #(.signalwidth(6)) dut6(
 .clk(clk),.ce(ce),.blank(blank),.frac(fraction),
 .in(current),.in_prev(previous),.out(out6));
integer cycle, accepted=0, valid=0;
integer expected5[0:2], expected6[0:2];
initial begin
 for(cycle=0;accepted<8192;cycle=cycle+1) begin
  @(negedge clk);
  // Include consecutive enables and gaps of varying lengths.
  ce=cycle%7!=1 && cycle%7!=2 && cycle%7!=5;
  fraction=accepted/32;
  current=accepted%64;
  previous=(accepted*13+7)%64;
  blank=accepted%29==0;
  @(posedge clk);
  if(ce) begin
   expected5[2]=expected5[1]; expected5[1]=expected5[0];
   expected6[2]=expected6[1]; expected6[1]=expected6[0];
   expected5[0]=blank ? 0 : ((256-int'(fraction))*int'(current[4:0])+
                                      int'(fraction)*int'(previous[4:0]))/256;
   expected6[0]=blank ? 0 : ((256-int'(fraction))*int'(current)+
                                      int'(fraction)*int'(previous))/256;
   accepted=accepted+1; valid=valid+1;
  end
  #1;
  if(valid>=3 && (int'(out5)!=expected5[2] || int'(out6)!=expected6[2]))
   $fatal(1,"Interpolation mismatch at cycle %0d",cycle);
 end
 $display("PASS interpolation: 8192 pixels, all 256 weights, 5/6 bits, blanking and enable gaps");
 $finish;
end
endmodule
