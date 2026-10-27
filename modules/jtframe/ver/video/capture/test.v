/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 26-10-2026 */

`timescale 1ns/1ps
module test;
reg clk=0,rst=1,game_reset=0,pxl_cen=0,lhbl=0,lvbl=0;
reg [3:0] red=0,green=0,blue=0;
reg irq_level=0,irq_taken_toggle=0,service_enable=0,dump_pause=0;
reg [31:0] cab_frame=0,cab_epoch=0;
reg rx_strobe=0;
reg [7:0] rx_cmd=0,rx_byte=0;
reg [4:0] rx_index=0;
wire pause_gate,capture_hold;
wire [1535:0] snapshot;
wire [767:0] line_snapshot;
wire [127:0] window_snapshot;
wire [1023:0] read_window;
integer phase=0,x=0,y=0,tries,b,lines,bytecount;
reg [191:0] packet;
reg [63:0] cap,first_raster,first_game;
reg [767:0] h;
reg [1023:0] saved;
reg [31:0] seen=0;
reg previous_lvbl=0;
reg [7:0] readybits;
localparam [63:0] COOKIE=64'h123456789a;
always #5 clk=~clk;
// A pixel every four cycles, five visible pixels and three visible lines.
always @(negedge clk) begin
 if(!rst) begin
  phase=(phase+1)%4; pxl_cen=phase==0;
  if(phase==0) begin
   lhbl=x<5;lvbl=y<3;red=x;green=y;blue=4'hb;
   if(lvbl && !previous_lvbl && !capture_hold) cab_frame=cab_frame+1;
   if(!lvbl && previous_lvbl && service_enable && !pause_gate) irq_taken_toggle=~irq_taken_toggle;
   previous_lvbl=lvbl;
   x=x+1; if(x==8) begin x=0;y=y+1;if(y==6)y=0;end
  end
 end
end
jtframe_capture #(
    .WIDTH    ( 5 ),
    .HEIGHT   ( 3 ),
    .FEEDBACK ( 1 )
) uut(
    .*
);
task tick; begin @(posedge clk); #1; @(negedge clk); #1; end endtask
task check; input ok; input[255:0] msg;
 begin if(!ok)begin $display("FAIL %0s state=%d error=%d",msg,snapshot[18:16],snapshot[31:24]);$finish;end end
endtask
task command;
 input [7:0] cmd;input integer count;input [191:0] data;
 integer i;
 begin
 rx_strobe=1;rx_cmd=cmd;rx_index=0;rx_byte=0;tick();rx_strobe=0;tick();
 for(i=0;i<count;i=i+1)begin rx_strobe=1;rx_index=i+1;rx_byte=data[i*8+:8];tick();rx_strobe=0;tick();end
 repeat(4)tick();
 end
endtask
task status;begin command(8'h90,0,0);end endtask
task drain;
 begin
 lines=0; tries=0;
 while(lines<3 && tries<1000) begin
  status();readybits=snapshot[1111:1104];
  if(readybits!=0) begin
   b=readybits[1] ? 1 : 0;
   command(8'h92,17,{56'd0,b[7:0],cap,COOKIE});command(8'h97,0,0);h=line_snapshot;
   check(h[15:0]==16'h4c56,"line header");check(h[511:496]==5,"native width");
   check(h[319:256]!=0,"source raster");
   check(!seen[h[495:480]],"no duplicate y");seen[h[495:480]]=1;
   bytecount=h[623:608];
   command(8'h93,24,{bytecount[7:0],16'd0,h[63:32],b[7:0],cap,COOKIE});
   repeat(100)tick();command(8'h96,0,0);check(window_snapshot[8],"window ready");saved=read_window;
   // Native pattern forces raw packing; first pixel is x=0, green=y, blue=b.
   check(h[631:624]==1,"raw mode");
   check(read_window[7:0]=={4'd0,h[483:480]},"first native pixel");
   command(8'h93,24,{bytecount[7:0],16'd0,h[63:32],b[7:0],cap,COOKIE});repeat(100)tick();
   check(saved==read_window,"immutable retry");
   command(8'h95,21,{24'd0,h[63:32],b[7:0],cap,COOKIE});lines=lines+1;
  end else repeat(40)tick();
  tries=tries+1;
 end
 check(lines==3,"all missing lines");
 repeat(400)tick();status();check(snapshot[18:16]==4,"capture complete");
 end
endtask
initial begin
 $dumpfile("test.lxt");$dumpvars;
 repeat(4)tick();rst=0;repeat(8)tick();status();
 command(8'h98,17,{56'd0,8'd1,snapshot[255:192],COOKIE});
 command(8'h91,12,{96'd0,32'd0,64'd1});status();cap=snapshot[319:256];
 check(cap==1,"begin identity");drain();check(!capture_hold,"unconfirmed never freezes");
 service_enable=1;seen=0;repeat(400)tick();status();
 command(8'h98,17,{56'd0,8'd1,snapshot[255:192],COOKIE});
 command(8'h91,12,{96'd0,32'd0,snapshot[447:384]+64'd1});status();cap=snapshot[319:256];
 repeat(1200)tick();status();first_raster=snapshot[383:320];first_game=snapshot[447:384];
 check(capture_hold,"validated hold");repeat(400)tick();status();
 check(snapshot[447:384]==first_game && snapshot[383:320]>first_raster,"raster independent");
 drain();check(!capture_hold,"resume releases pause");
 // A stale session/line cannot free a live buffer; abort clears owned pause.
 command(8'h98,17,{56'd0,8'd1,snapshot[255:192],COOKIE});
 command(8'h91,12,{96'd0,32'd0,snapshot[447:384]+64'd1});status();cap=snapshot[319:256];
 repeat(2000)tick();status();b=snapshot[1112-1:1104]==2 ? 1 : 0;
 command(8'h92,17,{56'd0,b[7:0],cap,COOKIE});command(8'h97,0,0);h=line_snapshot;
 command(8'h95,21,{24'd0,h[63:32],b[7:0],cap,COOKIE+64'd1});status();
 check(snapshot[31:24]==3 && snapshot[1103:1088]==3,"stale release retains missing lines");
 command(8'h98,17,{56'd0,8'd1,snapshot[255:192],COOKIE+64'd1});status();
 check(snapshot[191:128]==COOKIE,"active context cannot be stolen");
 command(8'h99,16,{64'd0,cap,COOKIE});repeat(8)tick();status();
 check(snapshot[18:16]==0 && !pause_gate,"abort clears pause and buffers");
 // An unexpected pending IRQ invalidates a formerly strict acquisition.
 command(8'h98,17,{56'd0,8'd1,snapshot[255:192],COOKIE});
 command(8'h91,12,{96'd0,32'd0,snapshot[447:384]+64'd1});repeat(1600)tick();
 irq_level=1;repeat(16)tick();status();
 check(snapshot[18:16]==5 && !pause_gate,"contract loss is explicit and resumes time");
 $display("PASS");$finish;
end
initial begin #10000000;$display("FAIL timeout");$finish;end
endmodule
