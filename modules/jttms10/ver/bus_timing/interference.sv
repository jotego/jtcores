/* SPDX-License-Identifier: GPL-3.0-or-later */
`timescale 1ns/1ps
// Timed arbiter: HOLD after arbitration but before physical start, then
// reservation restart and a fresh read before the only permitted write.
module test;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,hold_req=0,cpu_req=0,word_we=0,word_lock=0,host_req=0;
    reg [15:0] word_wdata=0,memory=16'hbeef;
    wire hold_ack,word_ack,word_restart,cyc_req,host_ack;
    wire [15:0] host_data;
    wire [3:0] cyc_kind;
    wire [31:0] cyc_addr;
    wire [15:0] cyc_wdata,word_rdata;
    reg target_busy=0,target_done=0;
    integer now=0,age=0,reads=0,writes=0,restarts=0,completed=0,host_completed=0;
    integer physical_begin=0,second_end=0;
    reg [3:0] kind_q;
    reg [15:0] data_q;
    wire cyc_ack=target_busy && age==4;
    jttms10_bus #(.TIMING(1)) dut(
        .clk(clk),.rst(rst),.hold_req(hold_req),.hold_ack(hold_ack),
        .screen_req(1'b0),.screen_srfaddr(14'd0),.screen_dpytap(16'd0),
        .screen_org(1'b0),.screen_ack(),.refresh_req(1'b0),.refresh_row(8'd0),
        .refresh_cbr(1'b0),.host_mem_req(host_req),.host_mem_we(1'b0),
        .host_mem_addr(32'hc00000b0),.host_mem_wdata(16'd0),.host_mem_is_io(1'b1),
        .host_mem_io_rdata(16'h5a5a),.host_mem_rdata(host_data),.host_mem_ack(host_ack),
        .word_req(cpu_req && !word_restart),.word_pending(cpu_req),.word_early(1'b0),.word_we(word_we),.word_iaq(1'b0),
        .word_lock(word_lock),.word_pixel(1'b0),.word_addr(32'h200),
        .word_wdata(word_wdata),.is_io(1'b0),.pixel_srt(1'b0),.io_rdata(16'd0),
        .word_rdata(word_rdata),.word_ack(word_ack),.word_restart(word_restart),.word_wait(),
        .cyc_req(cyc_req),.cyc_kind(cyc_kind),.cyc_addr(cyc_addr),
        .cyc_wdata(cyc_wdata),.cyc_io_rdata(),.cyc_iaq(),.cyc_srfaddr(),
        .cyc_dpytap(),.cyc_org(),.cyc_dram_row(),.cyc_rdata(memory),.cyc_ack(cyc_ack)
    );
    always @(posedge clk) begin
        if(rst) now<=0;
        else begin
            now<=now+1;
            if(cyc_req && !target_busy && !target_done) begin
                target_busy<=1;age<=1;kind_q<=cyc_kind;data_q<=cyc_wdata;
                physical_begin=now;
                if(cyc_addr!=32'h200 || (cyc_kind!=0 && cyc_kind!=1))
                    $fatal(1,"unexpected physical request");
                if(cyc_kind==0) reads=reads+1;else writes=writes+1;
            end else if(target_busy) begin
                if(!cyc_req || cyc_kind!==kind_q || cyc_wdata!==data_q)
                    $fatal(1,"unstable target payload");
                if(age==4) begin
                    if(kind_q==1) memory<=data_q;
                    target_busy<=0;target_done<=1;
                end else age<=age+1;
            end
            if(!cyc_req) target_done<=0;
            if(word_restart) restarts=restarts+1;
            if(word_ack) begin
                completed=completed+1;
                if(completed<3 && now-physical_begin!=16)
                    $fatal(1,"nonqueued read did not occupy two states");
                if(completed==2) second_end=now;
                if(completed==3 && now-second_end!=16)
                    $fatal(1,"RMW write did not immediately follow its reserved read");
            end
            if(hold_ack && completed<1) $fatal(1,"HOLD interrupted an allocated cycle");
            if(host_ack) begin
                host_completed=host_completed+1;
                if(completed!=3 || now-second_end!=32 || host_data!==16'h5a5a)
                    $fatal(1,"host split RMW or did not take its own two-state I/O cycle");
            end
        end
    end
    task transfer;
        integer next_completion;
        begin
            next_completion=completed+1;
            wait(completed==next_completion);#1;
        end
    endtask
    initial begin
        repeat(3) @(negedge clk);rst=0;
        repeat(2) @(negedge clk);cpu_req=1;word_lock=1;
        // Grant occurs between state boundaries. A pending HOLD must not
        // prevent this allocated cycle from ever starting/completing.
        wait(dut.state==1);@(negedge clk);
        if(cyc_req) $fatal(1,"HOLD stimulus missed pre-start window");
        hold_req=1;
        transfer();
        if(word_rdata!==16'hbeef) $fatal(1,"first read data");
        @(negedge clk);word_we=1;word_wdata=16'h1234;
        wait(word_restart);@(negedge clk);cpu_req=0;word_we=0;word_lock=0;
        wait(hold_ack);#1;
        if(restarts!=1 || reads!=1 || writes!=0) $fatal(1,"HOLD/RMW cancellation");
        memory=16'hcafe;
        repeat(8) @(negedge clk);hold_req=0;
        wait(!hold_ack);@(negedge clk);cpu_req=1;word_lock=1;
        transfer();
        if(word_rdata!==16'hcafe) $fatal(1,"restart reused stale memory");
        @(negedge clk);word_we=1;word_wdata=16'h5678;host_req=1;
        transfer();
        @(negedge clk);cpu_req=0;word_lock=0;
        wait(host_completed==1);#1;
        @(negedge clk);host_req=0;
        repeat(8) @(negedge clk);
        if(memory!==16'h5678 || reads!=2 || writes!=1 || completed!=3 || host_completed!=1)
            $fatal(1,"duplicate/stale transaction after restart");
        $display("TI timed arbiter: HOLD pre-start, restart, reread, reserved write and queued host I/O PASS");
        $finish;
    end
    initial begin #20000;$fatal(1,"timed arbiter timeout");end
endmodule
