/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

`timescale 1ns/1ps
module test;
reg clk=0, rst=1, vblank_n=0, mreq_n=1, rfsh_n=1;
reg [1:0] mode=0;
reg [8:0] h=128;
reg [15:0] addr=0;
wire wait_n;
reg [3:1] expected_mq;
integer a, control, normalized, checked=0, program_id;

always #5 clk=~clk;

jtseicro_wait dut(
    .rst      ( rst      ),
    .clk      ( clk      ),
    .mode     ( mode     ),
    .h        ( h        ),
    .vblank_n ( vblank_n ),
    .addr     ( addr     ),
    .mreq_n   ( mreq_n   ),
    .rfsh_n   ( rfsh_n   ),
    .wait_n   ( wait_n   )
);

task settle;
    begin repeat(3) @(negedge clk); end
endtask

task expect_wait;
    input expected;
    begin
        settle;
        if(wait_n!==expected)
            $fatal(1,"WAIT mode=%0d H=%0d addr=%h actual=%b expected=%b",
                mode,h,addr,wait_n,expected);
    end
endtask

task idle;
    begin
        @(negedge clk);
        rst=1; h=128; addr=0; mreq_n=1; rfsh_n=1; vblank_n=0;
        settle;
        rst=0;
        expect_wait(1);
    end
endtask

initial begin
    for(control=0;control<4;control=control+1) begin
        {mreq_n,rfsh_n}=control;
        for(a=0;a<65536;a=a+1) begin
            addr=a;
            normalized=a & 16'hbfff;
            expected_mq=0;
            if(!mreq_n && rfsh_n) begin
                expected_mq[1]=normalized>=16'h8800 && normalized<=16'h8fff;
                expected_mq[2]=normalized>=16'h9000 && normalized<=16'h97ff;
                expected_mq[3]=normalized>=16'h9800 && normalized<=16'h9fff;
            end
            #1;
            if(dut.mq!==expected_mq)
                $fatal(1,"MQ decode addr=%h mreq/rfsh=%b%b got=%b expected=%b",
                    addr,mreq_n,rfsh_n,dut.mq,expected_mq);
            checked=checked+1;
        end
    end

    for(program_id=0;program_id<3;program_id=program_id+1) begin
        mode=program_id;
        idle;
        h=132;
        settle;
        if(program_id==2) vblank_n=1;
        else begin addr=16'h9800; mreq_n=0; end
        expect_wait(0);
        h=128;
        expect_wait(0);
        h=132;
        expect_wait(1);
        h=128;
        settle;
        h=132;
        expect_wait(1);

        idle;
        if(program_id==2) begin
            h=132; vblank_n=1;
        end else begin
            h=132; addr=16'hd800; mreq_n=0;
        end
        expect_wait(1);

        idle;
        if(program_id==2) vblank_n=1;
        else begin addr=16'h9800; mreq_n=0; end
        expect_wait(0);
        rst=1;
        expect_wait(1);
    end

    mode=1;
    idle;
    vblank_n=1;
    expect_wait(1);
    addr=16'h9000; mreq_n=0;
    expect_wait(0);
    h=132;
    expect_wait(1);

    mode=0;
    idle;
    vblank_n=1;
    expect_wait(0);
    h=132;
    expect_wait(1);
    h=128; addr=16'h9000; mreq_n=0;
    expect_wait(1);

    mode=0;
    idle;
    h=239;
    settle;
    h=240;
    expect_wait(0);
    h=243;
    expect_wait(0);
    h=244;
    expect_wait(1);
    h=248;
    expect_wait(1);
    $display("PASS WAIT: %0d bus controls/addresses; mirrors, 3 programs, H2 edge, held clocks, reset and coincident-edge policy",checked);
    $finish;
end
endmodule
