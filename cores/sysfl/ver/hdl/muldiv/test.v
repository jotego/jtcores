/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-10-2026 */
`timescale 1ns/1ps
module test;
reg clk=0, rst=1, cen=0, start=0;
reg [2:0] op=0;
reg [31:0] s1=0, s2=0, s2h=0;
wire [31:0] r0, r1;
wire busy, done;
integer i, j, checks=0;
reg [31:0] a, b, h;
always #5 clk=~clk;

jt960_muldiv uut(
    .rst   ( rst   ),
    .clk   ( clk   ),
    .cen   ( cen   ),
    .start ( start ),
    .op    ( op    ),
    .s1    ( s1    ),
    .s2    ( s2    ),
    .s2h   ( s2h   ),
    .r0    ( r0    ),
    .r1    ( r1    ),
    .busy  ( busy  ),
    .done  ( done  )
);

task step(input en);
begin
    @(negedge clk); cen=en;
    @(posedge clk); #1;
end
endtask

task check_op(input [2:0] operation, input [31:0] divisor, dividend, high);
    reg [63:0] wide, product;
    reg signed [63:0] sa, sb, remainder;
    reg [31:0] expected0, expected1, held0, held1;
    reg en, held_busy, held_done;
    integer ticks, clocks, latency;
begin
    sa={{32{divisor[31]}},divisor};
    sb={{32{dividend[31]}},dividend};
    wide={high,dividend};
    product={32'd0,divisor}*{32'd0,dividend};
    expected0=0; expected1=0;
    latency=operation<2 ? 17 : divisor==0 ? 0 : operation==7 ? 65 : 33;
    case(operation)
    0: expected0=product[31:0];
    1: begin expected0=product[31:0]; expected1=product[63:32]; end
    2: if(divisor!=0) expected0=dividend/divisor;
    3: if(divisor!=0) expected0=dividend%divisor;
    4: if(divisor!=0) expected0=32'(sb/sa);
    5: if(divisor!=0) expected0=32'(sb%sa);
    6: if(divisor!=0) begin
        remainder=sb%sa;
        if(remainder!=0 && (remainder<0)!=(sa<0)) remainder=remainder+sa;
        expected0=remainder[31:0];
    end
    7: if(divisor!=0) begin expected0=32'(wide%divisor); expected1=32'(wide/divisor); end
    endcase
    @(negedge clk);
    op=operation; s1=divisor; s2=dividend; s2h=high; cen=1; start=1;
    @(posedge clk); #1;
    start=0; ticks=0; clocks=0;
    s1=~divisor; s2=~dividend; s2h=~high;
    while(!done && clocks<1000) begin
        en=($random & 3)!=0;
        held0=r0; held1=r1; held_busy=busy; held_done=done;
        step(en);
        clocks=clocks+1;
        if(en) ticks=ticks+1;
        else if({r0,r1,busy,done}!=={held0,held1,held_busy,held_done})
            $fatal(1,"state changed while cen=0");
    end
    if(!done || busy || ticks!=latency)
        $fatal(1,"op=%0d completion ticks=%0d expected=%0d",operation,ticks,latency);
    if(r0!==expected0 || ((operation==1 || operation==7) && r1!==expected1))
        $fatal(1,"op=%0d divisor=%h dividend=%h high=%h got=%h:%h expected=%h:%h",
            operation,divisor,dividend,high,r1,r0,expected1,expected0);
    step(0);
    if(!done) $fatal(1,"done lost while cen=0");
    step(1);
    if(done) $fatal(1,"done exceeded one enabled cycle");
    checks=checks+1;
end
endtask

initial begin
    repeat(3) @(posedge clk);
    @(negedge clk); rst=0;
    for(i=0;i<8;i=i+1) begin
        check_op(i[2:0],0,32'h87654321,32'h12345678);
        check_op(i[2:0],1,0,0);
        check_op(i[2:0],1,32'hffffffff,32'hffffffff);
        check_op(i[2:0],32'hffffffff,32'h80000000,0);
        check_op(i[2:0],32'h80000000,32'hffffffff,32'h7fffffff);
        check_op(i[2:0],3,32'h40000000,0);
        check_op(i[2:0],32'hfffffffd,32'h40000000,0);
        check_op(i[2:0],3,32'hc0000000,0);
        for(j=0;j<2000;j=j+1) begin
            a=$random; b=$random; h=$random;
            check_op(i[2:0],a,b,h);
        end
    end
    $display("PASS: %0d muldiv cases, cen stalls and exact completion latency",checks);
    $finish;
end
initial begin
    #50000000;
    $fatal(1,"timeout");
end
endmodule
