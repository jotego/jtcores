`timescale 1ns/1ps
module test;
reg clk=0;
always #5 clk=~clk;
integer cycle=0, x=0, y=0, frame=0, outfd;
integer period=7, filter=0, fractional=0, realtiming=0, direction=1;
integer width=320, height=240, htotal=446, vtotal=286;
wire [1:0] cen;
jtframe_frac_cen #(.W(2)) cen_gen(.clk(clk),.n(10'd7),.m(10'd24),.cen(cen),.cenb());
wire pe=fractional ? cen[1] : (cycle%period)==0;
wire ppe=fractional ? cen[0] : ((cycle*2)%period)<2;
reg [14:0] picture[0:262143];
wire [8:0] th,tv;
wire tlh,tlv,ths,tvs;
jtframe_vtimer #(.HB_START(319),.HB_END(445),.HCNT_END(445),
.HS_START(352),.HS_END(382),.VB_START(239),.VB_END(285),
.VCNT_END(285),.VS_START(264),.VS_END(272)) timing(
.clk(clk),.pxl_cen(pe),.H(th),.vdump(tv),.vrender(),.vrender1(),
.Hinit(),.Vinit(),.LHBL(tlh),.LVBL(tlv),.HS(ths),.VS(tvs));
reg [1:0] lh_delay=0,lv_delay=0;
reg [14:0] rgb_delay[0:1];
always @(posedge clk) if(pe) begin
 lh_delay<={lh_delay[0],tlh}; lv_delay<={lv_delay[0],tlv};
 rgb_delay[0]<= (th<320 && tv<240) ? picture[tv*320+th] : 15'd0;
 rgb_delay[1]<=rgb_delay[0];
end
wire hb=realtiming ? !lh_delay[1] : x>=width;
wire vb=realtiming ? !lv_delay[1] : y>=height;
wire hs=realtiming ? ths : x>=htotal-94 && x<htotal-64;
wire vs=realtiming ? tvs : y>=vtotal-22 && y<vtotal-14;
wire [14:0] rgb=realtiming ? rgb_delay[1] :
 (x<width && y<height) ? picture[y*width+x] : 15'd0;
wire [14:0] out;
wire ohs,ovs,de,ohb,ovb;
wire [15:0] dq;
wire [12:0] addr;
wire [1:0] ba,dqm;
wire cs,we,ras,cas,cke;
jtframe_scan2x #(.COLORW(5),.HLEN(446)) dut(
.rst(cycle<32),.clk(clk),.pxl_cen(pe),.pxl2_cen(ppe),
.enb(1'b0),.sl_mode(2'd0),.blend_en(1'b0),.rotation(direction[1:0]),
.hfilter(filter!=0),.vfilter(filter!=0),.x1_pxl(rgb),
.x1_hs(hs),.x1_vs(vs),.x1_hb(hb),.x1_vb(vb),
.x2_pxl(out),.x2_hs(ohs),.x2_vs(ovs),.x2_de(de),.x2_HB(ohb),.x2_VB(ovb),
.init(cycle<32),.sd_data(dq),.sd_addr(addr),.sd_dqm(dqm),.sd_ba(ba),
.sd_cs(cs),.sd_we(we),.sd_ras(ras),.sd_cas(cas),.sd_cke(cke));
// Pin-level SDR SDRAM model. Sample the registered controller pins half a
// system clock later, as a phase-shifted SDRAM clock does on the board.
// The controller uses bank 3, CAS latency 2, BL8 reads and single writes.
reg [15:0] mem[0:8388607];
reg [12:0] row[0:3];
integer latency=0, burst=0, col=0, bank=0;
integer wx,wy,writes=0,errors=0;
reg [15:0] expected;
reg drive=0;
reg [15:0] data;
assign dq=drive ? data : 16'hzzzz;
always @(negedge clk) begin
 drive<=0;
 if(latency>0) latency<=latency-1;
 if(latency==1 || burst>0) begin
  drive<=1; data<=mem[row[bank]*1024+col]; col<=col+1;
  if(latency==1) burst<=7; else burst<=burst-1;
 end
 if(!cs) case({ras,cas,we})
  3'b000: if(addr[6:4]!=3'd2 || addr[2:0]!=3'd3 || !addr[9])
   $fatal(1,"Unexpected SDRAM mode");
  3'b011: begin
   if(ba!=3) $fatal(1,"Unexpected SDRAM bank");
   row[ba]<=addr;
  end
  3'b100: begin
   if(dqm!=0) $fatal(1,"Masked write");
   mem[row[ba]*1024+addr[9:0]]<=dq;
   if(frame==3 && !realtiming) begin
    wx={row[ba][10:6],addr[8:4]};
    wy=int'({row[ba][5:0],addr[3:0]});
    if(direction==1) wy=height-1-wy;
    if(wx<width && wy>=0 && wy<height) begin
     expected={picture[wy*width+wx][14:10],picture[wy*width+wx][9:5],picture[wy*width+wx][9],picture[wy*width+wx][4:0]};
     writes=writes+1;
     if(dq!==expected) begin
      errors=errors+1;
      if(errors<8) $display("write mismatch x=%0d y=%0d got=%h expected=%h",wx,wy,dq,expected);
     end
    end
   end
  end
  3'b101: begin bank<=ba; col<=addr[9:0]; latency<=2; end
 endcase
end
initial begin
 if($value$plusargs("period=%d",period)) begin end
 if($value$plusargs("direction=%d",direction)) begin end
 if($value$plusargs("width=%d",width)) begin end
 if($value$plusargs("height=%d",height)) begin end
 if($value$plusargs("htotal=%d",htotal)) begin end
 if($value$plusargs("vtotal=%d",vtotal)) begin end
 if($value$plusargs("filter=%d",filter)) begin end
 if($value$plusargs("fractional=%d",fractional)) begin end
 if($value$plusargs("realtiming=%d",realtiming)) begin end
 $readmemh("input.hex",picture,0,width*height-1);
 outfd=$fopen("output.txt","w");
end
always @(posedge clk) begin
 if(ppe && frame==4) $fwrite(outfd,"%d %d %04x\n",ohb,ovb,out);
 if(pe) begin
  if(x==htotal-1) begin x<=0;
   if(y==vtotal-1) begin
    y<=0; frame<=frame+1;
    $display("frame %0d measured %0d x %0d",frame,dut.u_rotate.in_xpos_max,dut.u_rotate.in_ypos_max);
    if(frame==4) begin
     $display("writes=%0d errors=%0d",writes,errors);
     if(!realtiming && (writes!=width*height || errors!=0)) $fatal(1,"Input pixels corrupted");
     $fclose(outfd); $finish;
    end
   end else y<=y+1;
  end else x<=x+1;
 end
 cycle<=cycle+1;
end
endmodule
