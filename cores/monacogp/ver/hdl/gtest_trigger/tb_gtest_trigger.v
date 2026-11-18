// SPDX-License-Identifier: GPL-3.0-or-later
// The accelerator stand-in (jtmonacogp_gtest.v) with the analog right trigger:
// the pedal's four positions at the same travel as the right stick, the larger
// of the two winning, one position at a time.
`timescale 1ns/1ps
module tb_gtest_trigger;
    reg clk=0, rst=1;
    always #5 clk=~clk;
    reg [7:0] stick=0, trig=0;
    reg [5:0] joy=6'h3f;
    wire [1:0] acce;
    jtmonacogp_gtest dut(.clk(clk),.rst(rst),.enable(1'b1),.joy_n(joy),.pedal_y(stick),.pedal_t(trig),
        .coin_n(1'b1),.start_n(1'b1),.service_n(1'b1),.tilt_in_n(1'b1),.dip_two_play(1'b0),
        .coin_sw(),.test_sw(),.credit_sw(),.two_play(),.tilt_n(),.acce_ab(acce),
        .shift_no(),.shift_nc(),.high_gear(),.ic27_3(),.ic51_3());
    reg [1:0] last=2'b11;
    always @(posedge clk) begin
        if(!rst && acce!==last && (acce^last)==2'b11) $fatal(1,"both pedal lines changed at once");
        last <= acce;
    end
    task check(input [7:0] t, input [7:0] s, input [1:0] want);
        begin
            trig=t; stick=s;
            repeat(4*65536+8) @(posedge clk);
            if(acce!==want) $fatal(1,"trigger %0d stick %h: pedal %b, expected %b",t,s,acce,want);
        end
    endtask
    initial begin
        repeat(4) @(posedge clk); rst=0;
        check(0,0,2'b11); check(63,0,2'b11); check(64,0,2'b01); check(127,0,2'b01);
        check(128,0,2'b00); check(191,0,2'b00); check(192,0,2'b10); check(255,0,2'b10);
        check(0,0,2'b11);
        check(0,-8'd64,2'b00);       // the stick alone, as before
        check(192,-8'd32,2'b10);     // the further of the two
        check(64,-8'd96,2'b10);
        check(0,8'd100,2'b11);       // stick down is nothing
        $display("PASS accelerator: analog trigger levels, stick, Gray-code steps"); $finish;
    end
endmodule
