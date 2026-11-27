/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

`timescale 1ns/1ps
module test;
reg clk=0, rst=1, e=0, vma=0, a15=0, release_clk=1;
wire request=e & vma & a15;
wire mr_n;
reg ref_request_q=0, ref_first_q=1, ref_last_q=1;
integer combination, phase, tick, checked=0;

always #5 clk=~clk;

always @(posedge request or negedge ref_last_q or posedge rst) begin
    if(rst || !ref_last_q) ref_request_q<=0;
    else ref_request_q<=1;
end

always @(posedge release_clk or negedge ref_request_q or posedge rst) begin
    if(rst || !ref_request_q) ref_first_q<=1;
    else ref_first_q<=0;
end

always @(negedge release_clk or negedge ref_request_q or posedge rst) begin
    if(rst || !ref_request_q) ref_last_q<=1;
    else ref_last_q<=ref_first_q;
end

jtseicro_mr dut(
    .rst         ( rst         ),
    .clk         ( clk         ),
    .e           ( e           ),
    .vma         ( vma         ),
    .a15         ( a15         ),
    .release_clk ( release_clk ),
    .mr_n        ( mr_n        )
);

task compare;
    begin
        if(mr_n!==!ref_request_q)
            $fatal(1,"MR reference mismatch request=%b C=%b actual=%b expected=%b",
                request,release_clk,mr_n,!ref_request_q);
        checked=checked+1;
    end
endtask

task settle;
    begin
        repeat(3) @(negedge clk);
        compare;
    end
endtask

task expect_ready;
    input expected;
    begin
        settle;
        if(mr_n!==expected)
            $fatal(1,"MR ready=%b expected=%b request=%b C=%b",
                mr_n,expected,request,release_clk);
    end
endtask

task idle;
    begin
        @(negedge clk);
        rst=1; e=0; vma=0; a15=0; release_clk=1;
        settle;
        rst=0;
        expect_ready(1);
    end
endtask

initial begin
    for(combination=0;combination<8;combination=combination+1) begin
        idle;
        {e,vma,a15}=combination;
        expect_ready(combination!=7);
        release_clk=0;
        expect_ready(combination!=7);
        release_clk=1;
        expect_ready(combination!=7);
        release_clk=0;
        expect_ready(1);
        release_clk=1;
        expect_ready(1);
        release_clk=0;
        expect_ready(1);
    end

    idle;
    release_clk=0;
    settle;
    {e,vma,a15}=7;
    expect_ready(0);
    repeat(8) settle;
    release_clk=1;
    expect_ready(0);
    release_clk=0;
    expect_ready(1);
    e=0;
    settle;
    e=1;
    expect_ready(0);
    rst=1;
    expect_ready(1);
    rst=0;
    expect_ready(1);

    for(phase=0;phase<8;phase=phase+1) begin
        idle;
        for(tick=0;tick<128;tick=tick+1) begin
            @(negedge clk);
            vma=1; a15=1;
            e=tick>=16+phase && tick<80;
            release_clk=(tick/4)%2;
            @(posedge clk);
            #1;
            compare;
        end
        expect_ready(1);
    end
    $display("PASS MR: %0d checks against three physical flip-flops; qualifiers, both edge phases, held request, reset and eight request phases",checked);
    $finish;
end
endmodule
