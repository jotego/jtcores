// SPDX-License-Identifier: GPL-3.0-or-later

`timescale 1ns/1ps
// Exercise real video timing and blanking, with pixel fetchers stubbed out.
// Compare sync against a fixed-288 reference across both width/flip settings.
module tb;
reg clk=0, rst=1, orig=0, flip=0;
always #5 clk=~clk;
reg [2:0] div=0;
always @(negedge clk) div<=div+1'b1;
wire pxl=div==0;
wire hs,vs,lh,lv,hs_ref,vs_ref;
wire [8:0] h,v;
jtmzone_video dut(.clk(clk),.clk24(clk),.rst(rst),.pxl_cen(pxl),.flip(flip),.dip_orig_hactive(orig),.HS(hs),.VS(vs),.LHBL(lh),.LVBL(lv),.hdump(h),.vdump(v),.gfx_en(4'b0),.prom_we(1'b0));
jtmzone_video reference(.clk(clk),.clk24(clk),.rst(rst),.pxl_cen(pxl),.flip(flip),.dip_orig_hactive(1'b0),.HS(hs_ref),.VS(vs_ref),.gfx_en(4'b0),.prom_we(1'b0));
integer count=0,lines=0,phase=0;
reg last=0,armed=0;
always @(posedge clk) if(!rst && pxl) begin
 if({hs,vs} !== {hs_ref,vs_ref}) $fatal(1,"SYNC changed");
 last<=lh;
 if(lh) count<=count+1;
 if(!last && lh) begin count<=1; armed<=1; end
 if(last && !lh && armed) begin
  if(count != ((orig&&!flip)?287:288)) $fatal(1,"width=%0d orig=%b flip=%b",count,orig,flip);
  lines<=lines+1;
 end
end
initial begin
 repeat(24) @(negedge clk); rst=0;
 for(phase=0;phase<4;phase=phase+1) begin
  wait(lines==600); @(negedge clk);
  $display("PASS orig=%b flip=%b width=%0d HS/VS unchanged",orig,flip,count);
  wait(h==330 && div==4); @(negedge clk);
  lines=0; {flip,orig}=phase+1;
 end
 $finish;
end
endmodule
