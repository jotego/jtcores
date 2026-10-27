/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 26-10-2026 */

`timescale 1ns/1ps
module test;
reg clk=0, rst=1, start=0,sample=0,finish=0,release_line=0,read_start=0;
reg [11:0] pixel=0;
reg [735:0] tag=0;
reg [9:0] read_offset=0;
reg [7:0] read_length=0;
wire free,ready,read_ready;
wire [767:0] header;
wire [1023:0] window;
reg [11:0] expected[0:511];
reg [7:0] encoded[0:1023];
reg [767:0] retained;
integer n,pattern,i,j,b,total,mode,count,x,at;
reg [15:0] wordval;
reg [31:0] crc;
reg [11:0] decoded;
always #5 clk=~clk;
jtframe_capture_line uut(
    .*
);

task check;
 input ok;
 input [255:0] msg;
 begin if(!ok) begin $display("FAIL %0s n=%0d pattern=%0d",msg,n,pattern); $finish; end end
endtask

task tick;
 begin @(posedge clk); #1; @(negedge clk); end
endtask

task crcbyte;
 input [7:0] data;
 integer bitno;
 begin
 crc=crc^{24'd0,data};
 for(bitno=0;bitno<8;bitno=bitno+1) crc=crc[0] ? (crc>>1)^32'hedb88320 : crc>>1;
 end
endtask

task runline;
 begin
 start=1; sample=1;
 for(i=0;i<n;i=i+1) begin
   expected[i]=pattern==0 ? 12'habc : pattern==1 ? i[11:0] : (i<16 ? 12'h123 : i<31 ? 12'hfed : 12'h456);
   pixel=expected[i]; tick(); start=0;
 end
 sample=0; finish=1; tick(); finish=0;
 j=0;
 while(!ready && j<10000) begin tick(); j=j+1; end
 check(ready,"ready deadline");
 check(header[511:496]==n,"width");
 total=header[623:608]; mode=header[631:624]; retained=header;
 for(at=0;at<total;at=at+31) begin
   b=total-at>31 ? 31 : total-at;
   read_offset=at[9:0]; read_length=b[7:0]; read_start=1; tick(); read_start=0;
   j=0; while(!read_ready && j<1000) begin tick(); j=j+1; end
   check(read_ready,"window deadline");
   for(j=0;j<b;j=j+1) encoded[at+j]=window[j*8+:8];
   check(header==retained,"immutable header");
 end
 crc=32'hffffffff;
 for(i=0;i<92;i=i+1) crcbyte(header[i*8+:8]);
 for(i=0;i<total;i=i+1) crcbyte(encoded[i]);
 check(~crc==header[767:736],"metadata/payload CRC");
 x=0; at=0;
 if(mode==1) begin
   check(total==((n*3+1)>>1),"raw length");
   for(i=0;i<n;i=i+1) begin
     decoded=i[0] ? {encoded[at][3:0],encoded[at+1]} : {encoded[at],encoded[at+1][7:4]};
     check(decoded==expected[i],"raw pixel");
     at=at+(i[0] ? 2 : 1);
   end
   if(n[0]) check(encoded[total-1][3:0]==0,"odd padding");
 end else begin
   while(at<total) begin
     wordval={encoded[at+1],encoded[at]}; at=at+2;
     count=wordval[15:12]+1;
     if(wordval[15:12]==15) begin count=16+{encoded[at+1],encoded[at]}; at=at+2; end
     for(i=0;i<count;i=i+1) begin
       check(x<n,"run overflow"); check(wordval[11:0]==expected[x],"run pixel"); x=x+1;
     end
   end
   check(x==n,"decoded width");
 end
 // The odd offset must reproduce the original byte stream.
 read_offset=1; read_length=1; read_start=1; tick(); read_start=0;
 while(!read_ready) tick();
 check(window[7:0]==encoded[1],"repeat odd offset");
 release_line=1; tick(); release_line=0; check(free,"explicit release");
 end
endtask
initial begin
 $dumpfile("test.lxt"); $dumpvars;
 repeat(4) tick(); rst=0; tick();
 for(pattern=0;pattern<3;pattern=pattern+1) begin
   n=1; runline(); n=15; runline(); n=16; runline(); n=17; runline();
   n=31; runline(); n=32; runline(); n=511; runline(); n=512; runline();
 end
 start=1; tick(); start=0; sample=1; tick(); sample=0;
 release_line=1; tick(); release_line=0; check(free,"abort capture");
 $display("PASS"); $finish;
end
initial begin #20000000; $display("FAIL timeout"); $finish; end
endmodule
