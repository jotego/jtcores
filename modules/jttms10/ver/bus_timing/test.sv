/* SPDX-License-Identifier: GPL-3.0-or-later */
`timescale 1ns/1ps
module test;
    reg clk=0; always #5 clk=~clk;
    reg rst=1,req=0,queued=0,io_cycle=0;
    integer now=0,latency=4,launch_phase=0,block_until=0,held_ack=0,rc;
    integer accept_tick=-1,ack_count=0,targets=0,sequence_id=0;
    integer target_begin=-1,ready_tick=-1,release_tick=-1;
    reg responding=0,finished=0,second=0;
    reg [15:0] io_data=16'h1111;
    wire ack,ext_req;
    wire [15:0] data;
    wire blocked=now<block_until;
    wire ext_ack=io_cycle ? latency==0 : (responding && now<release_tick) ||
                 (ext_req && (latency==0 || (target_begin>=0 && now>=target_begin+latency)));
    wire [15:0] ext_data=ext_req ? 16'ha000+16'(sequence_id) : 16'hdead;
    jttms10_bus_timer dut(
        .clk(clk),.rst(rst),.req(req),.queued(queued),.blocked(blocked),
        .io_cycle(io_cycle),.io_rdata(io_data),.ack(ack),.rdata(data),
        .ext_req(ext_req),.ext_ack(ext_ack),.ext_rdata(ext_data)
    );
    always @(posedge clk) begin
        if(rst) now<=0;
        else begin
            now<=now+1;
            if(dut.start) begin
                accept_tick=now;
                $display("ACCEPT %0d",now);
            end
            if(ext_req && target_begin<0) begin
                target_begin=now;
                targets=targets+1;
                $display("TARGET %0d",now);
            end
            if(ext_req && ext_ack && !responding) begin
                ready_tick=now; release_tick=now+held_ack;
                responding=1;
                $display("READY %0d",now);
            end
            if(!ext_req && responding && now>=release_tick) begin
                responding=0; target_begin=-1;
            end
            if(io_cycle && ext_req) $fatal(1,"I/O attempted an external transaction");
            if(ack) begin
                ack_count=ack_count+1;
                $display("RESULT sequence=%0d accept=%0d end=%0d data=%04h targets=%0d",sequence_id,accept_tick,now,data,targets);
                if(ack_count>sequence_id+1) $fatal(1,"duplicate completion while req held");
                finished=1;
            end
            if(now>500) $fatal(1,"timer timeout");
        end
    end
    initial begin
        rc=$value$plusargs("LATENCY=%d",latency);
        rc=$value$plusargs("PHASE=%d",launch_phase);
        rc=$value$plusargs("BLOCK=%d",block_until);
        rc=$value$plusargs("HOLD_ACK=%d",held_ack);
        queued=$test$plusargs("QUEUED");
        io_cycle=$test$plusargs("IO");
        second=$test$plusargs("SECOND");
        repeat(3) @(negedge clk);
        rst=0;
        repeat(8+launch_phase) @(negedge clk);
        req=1;
        // Change I/O after Q1, then again after the Q4 data capture. A
        // grant-time snapshot or a live combinational result must both fail.
        if(io_cycle) begin
            wait(accept_tick>=0);
            while(now<((accept_tick/8)*8+12)) @(negedge clk);
            io_data=16'h2222;
            while(now<((accept_tick/8)*8+16)) @(negedge clk);
            io_data=16'h3333;
        end
        wait(finished);
        if(second) begin
            @(negedge clk);req=0;
            @(negedge clk);sequence_id=1;queued=0;finished=0;req=1;
            wait(finished);
        end
        // Held request/ACK may not duplicate an acknowledged transfer.
        repeat(20) @(negedge clk);
        req=0;
        @(negedge clk);
        $finish;
    end
endmodule
