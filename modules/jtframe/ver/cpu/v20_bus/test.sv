/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */
`timescale 1ns/1ps
module test;
reg clk=0, rst=1, cen=1, ready=0;
always #5 clk=~clk;
reg [19:0] cpu_addr=0;
reg [15:0] cpu_dout=0;
reg [2:0] cpu_bs=7;
reg cpu_rd_n=1, cpu_wr_n=1, cpu_ube_n=1;
wire [15:0] cpu_din;
wire cpu_ready, req, rd_n, wr_n;
wire [19:0] A;
wire [7:0] dout;
wire [2:0] bs;
reg [7:0] din=0;
integer cases=0;
`include "test_tasks.vh"
jtframe_v20_bus dut (
    .rst          ( rst          ),
    .clk          ( clk          ),
    .cen          ( cen          ),
    .cpu_addr     ( cpu_addr     ),
    .cpu_dout     ( cpu_dout     ),
    .cpu_bs       ( cpu_bs       ),
    .cpu_rd_n     ( cpu_rd_n     ),
    .cpu_wr_n     ( cpu_wr_n     ),
    .cpu_ube_n    ( cpu_ube_n    ),
    .cpu_din      ( cpu_din      ),
    .cpu_ready    ( cpu_ready    ),
    .A            ( A            ),
    .dout         ( dout         ),
    .din          ( din          ),
    .bs           ( bs           ),
    .req          ( req          ),
    .rd_n         ( rd_n         ),
    .wr_n         ( wr_n         ),
    .ready        ( ready        )
);
task tick;
    @(posedge clk); #1; @(negedge clk);
endtask
task transfer(input [19:0] addr, input bit ube, input [2:0] kind, input integer waits);
    integer n, count;
    reg [15:0] expected;
    reg [19:0] byte_addr;
    reg [7:0] value;
    begin
        cpu_addr=addr; cpu_ube_n=ube; cpu_bs=kind; cpu_dout=16'hb6a5;
        cpu_wr_n=!(kind==2 || kind==6); cpu_rd_n=!cpu_wr_n;
        count=(!addr[0] && !ube && kind!=0) ? 2 : 1;
        expected=0;
        tick();
        // Announcements for a later cycle must not change the owning request.
        cpu_addr=20'hffff0; cpu_bs=7; cpu_dout=0; cpu_ube_n=1;
        for(n=0;n<count;n=n+1) begin
            byte_addr=addr+20'(n);
            value=(addr[0] && kind!=0 || n==1) ? 8'hb6 : 8'ha5;
            assert_msg(req && A===byte_addr && bs===kind,"byte address/status");
            assert_msg(wr_n===cpu_wr_n && rd_n===cpu_rd_n,"direction");
            if(!wr_n) assert_msg(dout===value,"write lane");
            repeat(waits) begin
                tick();
                assert_msg(req && A===byte_addr && bs===kind && !cpu_ready,"wait stability");
                if(!wr_n) assert_msg(dout===value,"write wait stability");
            end
            // READY cannot consume a request when the CPU enable is low.
            cen=0; ready=1; din=8'h31+8'(n); tick(); tick();
            assert_msg(req && !cpu_ready,"enable pause");
            cen=1; tick(); ready=0;
            if(cpu_wr_n) begin
                if(addr[0] && kind!=0 || n==1) expected[15:8]=8'h31+8'(n);
                else expected[7:0]=8'h31+8'(n);
            end
            assert_msg(!req,"request gap");
            if(n+1<count) begin
                assert_msg(!cpu_ready,"no partial word completion");
                tick();
            end
        end
        assert_msg(cpu_ready,"completion");
        if(cpu_wr_n) assert_msg(cpu_din===expected,"read assembly");
        repeat(3) begin
            tick();
            assert_msg(cpu_ready && !req,"no duplicate request");
        end
        cpu_rd_n=1; cpu_wr_n=1; cpu_bs=7; tick();
        assert_msg(cpu_ready && !req,"rearm");
        cases=cases+1;
    end
endtask
integer kind, lane, waits;
initial begin
    tick(); rst=0;
    cpu_bs=3;
    repeat(10) begin
        tick();
        assert_msg(!req && cpu_ready,"HALT housekeeping is ready without a byte request");
    end
    cpu_bs=7;
    for(kind=0;kind<7;kind=kind+1) if(kind!=3)
        for(lane=0;lane<4;lane=lane+1)
            for(waits=0;waits<4;waits=waits+1)
                transfer(20'h23450+20'(lane&1),1'(lane>>1),3'(kind),waits);
    transfer(20'hfffff,0,5,2);
    // Abort an outstanding write without acknowledging it.
    cpu_wr_n=0; cpu_bs=6; tick();
    assert_msg(req,"reset setup");
    rst=1; #1; assert_msg(!req && !cpu_ready,"reset masks request");
    tick(); rst=0; cpu_wr_n=1; cpu_bs=7; tick();
    assert_msg(!req && cpu_ready,"reset discards transaction");
    $display("Checked %0d bus cases",cases);
    pass();
end
initial begin #1000000; fail(); end
endmodule
