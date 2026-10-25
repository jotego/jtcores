/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
`timescale 1ns/1ps
module test;
reg clk=0,rst=1,reset_n=0,cs=0,we=0,addr=0;
reg [7:0] din=0;
wire [7:0] dout;
reg [7:0] old_byte,new_byte,want;
integer sh,k,checks=0;
always #10 clk=~clk;
jtpopeye_prot uut(.rst(rst),.clk(clk),.reset_n(reset_n),.cs(cs),.we(we),.addr(addr),.din(din),.dout(dout));
task write(input a,input [7:0] d);
begin
    @(negedge clk);addr=a;din=d;cs=1;we=1;
    repeat(4) @(negedge clk);cs=0;we=0;
    repeat(2) @(negedge clk);
end
endtask
initial begin
    $dumpfile("test.lxt");$dumpvars(1,uut);
    repeat(4) @(negedge clk);rst=0;reset_n=1;
    addr=1;@(negedge clk);
    if(dout!==0)$fatal(1,"FAIL reset");
    for(sh=0;sh<8;sh=sh+1)for(k=0;k<256;k=k+1)begin
        old_byte=k[7:0];new_byte=(k*73+17)&255;
        write(1,sh[7:0]);write(0,old_byte);write(0,new_byte);
        addr=1;@(negedge clk);
        // The board returns bits 15:8 of {new,old} shifted left.
        want=((new_byte<<sh)|(old_byte>>(8-sh)))&255;
        if(dout!==want)$fatal(1,"FAIL shift %0d old=%h new=%h got=%h want=%h",sh,old_byte,new_byte,dout,want);
        checks=checks+1;
        addr=0;@(negedge clk);
        if(dout!==8'hf8)$fatal(1,"FAIL status");
        if(k==0)$dumpoff;
    end
    cs=0;we=1;din=8'hff;addr=0;repeat(5)@(negedge clk);we=0;
    addr=1;@(negedge clk);if(dout!==want)$fatal(1,"FAIL unselected write");
    reset_n=0;repeat(2)@(negedge clk);reset_n=1;
    if(dout!==0)$fatal(1,"FAIL board reset");
    $display("%0d nonzero-pattern shifter checks",checks);
    $display("PASS");$finish;
end
initial begin #10000000;$fatal(1,"FAIL timeout");end
endmodule
