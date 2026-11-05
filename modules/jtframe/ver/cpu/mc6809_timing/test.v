`timescale 1ns/1ps
module test;

reg         rst, clk;
reg         cpu_reset_n = 0;
reg  [1:0]  phase = 0;
wire        cen_E = phase == 2'b00;
wire        cen_Q = phase == 2'b10;
reg         irq_n = 1;
wire [7:0]  dout, cpu_dout;
wire [15:0] addr;
wire        rnw, bs, ba, avma, busy, lic, op;
wire [111:0] regs;
reg [7:0] code_mem[0:255];
reg [7:0] stack_mem[0:31];
reg [7:0] vector_mem[0:15];
integer i;
integer stack_write_count;

`include "test_tasks.vh"

wire nreset = ~rst & cpu_reset_n;
always @(posedge clk or negedge nreset) begin
    if(!nreset) phase <= 0;
    else phase <= phase + 1'b1;
end

function [7:0] read_byte(input [15:0] a);
    begin
        read_byte=8'h12;
        if(a >= 16'h0100 && a <= 16'h01ff) read_byte=code_mem[a-16'h0100];
        else if(a >= 16'h2fe0 && a <= 16'h301f) read_byte=stack_mem[a-16'h2fe0];
        else if(a >= 16'hfff0) read_byte=vector_mem[a-16'hfff0];
    end
endfunction
assign dout = read_byte(addr);
always @(posedge clk) if(nreset && cen_Q && !rnw) begin
    if(addr >= 16'h0100 && addr <= 16'h01ff) code_mem[addr-16'h0100] <= cpu_dout;
    else if(addr >= 16'h2fe0 && addr <= 16'h301f) begin
        stack_mem[addr-16'h2fe0] <= cpu_dout;
        stack_write_count=stack_write_count+1;
    end
    else if(addr >= 16'hfff0) vector_mem[addr-16'hfff0] <= cpu_dout;
end

mc6809i #(.ILLEGAL_INSTRUCTIONS("STOP"), .HD6309(0)) uut(
    .D(dout), .DOut(cpu_dout), .ADDR(addr), .RnW(rnw),
    .clk(clk), .cen_E(cen_E), .cen_Q(cen_Q), .BS(bs), .BA(ba),
    .nIRQ(irq_n), .nFIRQ(1'b1), .nNMI(1'b1), .AVMA(avma), .BUSY(busy), .LIC(lic),
    .nHALT(1'b1), .nRESET(nreset), .nDMABREQ(1'b1), .OP(op), .RegData(regs),
    .RegData6309()
);

task put(input [15:0] a, input [7:0] value);
    begin
        if(a >= 16'h0100 && a <= 16'h01ff) code_mem[a-16'h0100]=value;
        else if(a >= 16'h2fe0 && a <= 16'h301f) stack_mem[a-16'h2fe0]=value;
        else if(a >= 16'hfff0) vector_mem[a-16'hfff0]=value;
    end
endtask

task load_test_program(input [7:0] b0, input [7:0] b1);
    integer k;
    begin
        cpu_reset_n = 0;
        irq_n = 1;
        stack_write_count=0;
        // Only the setup stream, target, and vectors are read before checks stop.
        for(k=0;k<32;k=k+1) stack_mem[k]=8'h00;
        // Establish S/U/X/Y, A/B, DP, and unmasked interrupt state.
        put(16'h0100,8'h10); put(16'h0101,8'hce); put(16'h0102,8'h30); put(16'h0103,8'h00);
        put(16'h0104,8'hce); put(16'h0105,8'h40); put(16'h0106,8'h00);
        put(16'h0107,8'h8e); put(16'h0108,8'h20); put(16'h0109,8'h00);
        put(16'h010a,8'h10); put(16'h010b,8'h8e); put(16'h010c,8'h21); put(16'h010d,8'h00);
        put(16'h010e,8'h86); put(16'h010f,8'h11);
        put(16'h0110,8'hc6); put(16'h0111,8'h22);
        put(16'h0112,8'h1f); put(16'h0113,8'h8b);
        put(16'h0114,8'h1c); put(16'h0115,8'h00);
        put(16'h0116,8'h1a); put(16'h0117,8'h00);
        put(16'h0120,b0); put(16'h0121,b1);
        // IRQ/SWI vector -> 0150, SWI2 -> 0160, SWI3 -> 0170.
        put(16'hfff2,8'h01); put(16'hfff3,8'h70);
        put(16'hfff4,8'h01); put(16'hfff5,8'h60);
        put(16'hfff8,8'h01); put(16'hfff9,8'h50);
        put(16'hfffa,8'h01); put(16'hfffb,8'h50);
        put(16'hfffe,8'h01); put(16'hffff,8'h00);
        repeat(8) @(posedge clk);
        @(negedge clk); cpu_reset_n=1;
    end
endtask

task check_irq_full_frame;
    integer watchdog;
    reg target_seen, handler_seen;
    begin
        load_test_program(8'h12,8'h12);
        watchdog=0; target_seen=0;
        while(!target_seen && watchdog<1000) begin
            @(posedge clk);
            if(cen_E && op && addr==16'h0120) target_seen=1;
            watchdog=watchdog+1;
        end
        assert_msg(target_seen,"MC6809 IRQ frame did not reach target");
        @(negedge clk); irq_n=0;
        watchdog=0; handler_seen=0;
        while(!handler_seen && watchdog<1000) begin
            @(posedge clk);
            if(cen_E && op && addr==16'h0150) handler_seen=1;
            watchdog=watchdog+1;
        end
        @(negedge clk); irq_n=1;
        assert_msg(handler_seen,"MC6809 IRQ frame did not vector");
        assert_msg(stack_write_count==12,
            $sformatf("MC6809 IRQ stack writes=%0d expected 12",stack_write_count));
        assert_msg(regs[63:48]==16'h2ff4,
            $sformatf("MC6809 IRQ S=%04x expected 2ff4",regs[63:48]));
        assert_msg(stack_mem[8'h14][7] && stack_mem[8'h15]==8'h11 &&
                   stack_mem[8'h16]==8'h22 && stack_mem[8'h17]==8'h11,
            $sformatf("MC6809 IRQ CC/A/B/DP=%02x/%02x/%02x/%02x",
                      stack_mem[8'h14],stack_mem[8'h15],stack_mem[8'h16],stack_mem[8'h17]));
        assert_msg(stack_mem[8'h18]==8'h20 && stack_mem[8'h19]==8'h00 &&
                   stack_mem[8'h1a]==8'h21 && stack_mem[8'h1b]==8'h00 &&
                   stack_mem[8'h1c]==8'h40 && stack_mem[8'h1d]==8'h00,
            $sformatf("MC6809 IRQ X/Y/U frame=%02x%02x/%02x%02x/%02x%02x",
                      stack_mem[8'h18],stack_mem[8'h19],stack_mem[8'h1a],stack_mem[8'h1b],
                      stack_mem[8'h1c],stack_mem[8'h1d]));
        assert_msg(stack_mem[8'h1e]==8'h01 && stack_mem[8'h1f]==8'h22,
            $sformatf("MC6809 IRQ PC frame=%02x%02x expected 0122",stack_mem[8'h1e],stack_mem[8'h1f]));
    end
endtask

task measure_case(input integer expected_cycles, input integer expected_pc,
                  input integer max_cycles, input string label);
    integer watchdog, interval, result_cycles;
    reg running, done, started, prefixed;
    reg [15:0] result_pc;
    begin
        watchdog=0; interval=0; result_cycles=-1; result_pc=16'hffff;
        running=0; done=0;
        prefixed=(code_mem[16'h20]==8'h10 || code_mem[16'h20]==8'h11);
        while(!done && watchdog<max_cycles) begin
            @(posedge clk);
            if(cen_E) begin
                watchdog=watchdog+1; started=0;
                if(op && addr==16'h0120) begin
                    if(!running) begin running=1; interval=0; started=1; end
                end else if(running && op && !(prefixed && addr==16'h0121)) begin
                    result_pc=addr; result_cycles=interval+1; done=1;
                end
                if(running && !done && !started) interval=interval+1;
            end
        end
        if(!done) begin $display("FAIL: %s timed out",label); fail(); end
        if(expected_cycles>=0)
            assert_msg(result_cycles==expected_cycles,$sformatf("%s cycles measured %0d expected %0d",label,result_cycles,expected_cycles));
        if(expected_pc>=0)
            assert_msg(result_pc==expected_pc[15:0],$sformatf("%s closed at %04x expected %04x",label,result_pc,expected_pc[15:0]));
    end
endtask

task wait_for_opcode_fetch(input [15:0] expected_pc, input string label);
    integer watchdog;
    reg seen;
    begin
        watchdog=0; seen=0;
        while(!seen && watchdog<1000) begin
            @(posedge clk);
            if(cen_E && op && addr==expected_pc) seen=1;
            watchdog=watchdog+1;
        end
        assert_msg(seen,$sformatf("%s did not fetch at %04x",label,expected_pc));
    end
endtask

task check_page10_extension_decode;
    integer watchdog;
    reg seen;
    begin
        watchdog=0; seen=0;
        while(!seen && watchdog<1000) begin
            @(posedge clk);
            if(cen_E && uut.InstPage2 && uut.Inst1==8'h8b) begin
                seen=1;
                assert_msg(!uut.IsALU16Opcode && uut.ALU16Reg==3'b111,
                    "$10/$8B entered the 6809 word-ALU decoder");
            end
            watchdog=watchdog+1;
        end
        assert_msg(seen,"did not reach unsupported $10/$8B encoding");
    end
endtask

task check_page10_word_decode;
    begin
        load_test_program(8'h12,8'h12);
        put(16'h0120,8'h10); put(16'h0121,8'h83); put(16'h0122,8'h11); put(16'h0123,8'h22);
        put(16'h0124,8'h10); put(16'h0125,8'h8c); put(16'h0126,8'h21); put(16'h0127,8'h00);
        put(16'h0128,8'h10); put(16'h0129,8'h8e); put(16'h012a,8'h12); put(16'h012b,8'h34);
        put(16'h012c,8'h10); put(16'h012d,8'hce); put(16'h012e,8'h23); put(16'h012f,8'h45);
        put(16'h0130,8'h11); put(16'h0131,8'h8c); put(16'h0132,8'h23); put(16'h0133,8'h45);
        put(16'h0134,8'h10); put(16'h0135,8'h8b);

        wait_for_opcode_fetch(16'h0124,"CMPD immediate");
        assert_msg(regs[82],"CMPD #$1122 did not set Z");
        wait_for_opcode_fetch(16'h0128,"CMPY immediate");
        assert_msg(regs[82],"CMPY #$2100 did not set Z");
        wait_for_opcode_fetch(16'h012c,"LDY immediate");
        assert_msg(regs[47:32]==16'h1234,$sformatf("LDY result=%04x expected 1234",regs[47:32]));
        wait_for_opcode_fetch(16'h0130,"LDS immediate");
        assert_msg(regs[63:48]==16'h2345,$sformatf("LDS result=%04x expected 2345",regs[63:48]));
        wait_for_opcode_fetch(16'h0134,"CMPS immediate");
        assert_msg(regs[82],"CMPS #$2345 did not set Z");
        check_page10_extension_decode();
    end
endtask

// Measure cycles from the target opcode fetch through entry into its stable
// wait state. Then assert IRQ and wait for the handler's opcode fetch. SYNC can
// fetch the sequential opcode before it vectors, so the handler fetch is the
// wake criterion rather than the first fetch after the target.
task measure_wait_and_wake(input [6:0] wait_state, input integer expected_entry,
                           input integer handler_pc, input string label);
    integer watchdog, interval, entry_cycles;
    reg running, entered, handler_seen, started;
    begin
        watchdog=0; interval=0; entry_cycles=-1;
        running=0; entered=0; handler_seen=0;
        while(!entered && watchdog<500) begin
            @(posedge clk);
            if(cen_E) begin
                watchdog=watchdog+1; started=0;
                if(op && addr==16'h0120 && !running) begin
                    running=1; interval=0; started=1;
                end
                if(running && !entered && !started) interval=interval+1;
                #1;
                if(running && uut.CpuState==wait_state) begin
                    entered=1; entry_cycles=interval+1;
                end
            end
        end
        if(!entered) begin $display("FAIL: %s did not enter wait state",label); fail(); end
        assert_msg(entry_cycles==expected_entry,$sformatf("%s entry measured %0d expected %0d",label,entry_cycles,expected_entry));
        assert_msg(avma==1'b0,$sformatf("%s wait state unexpectedly asserts AVMA",label));
        if(wait_state==7'd113)
            assert_msg(ba==1'b1,$sformatf("%s SYNC wait state did not assert BA",label));
        @(negedge clk); irq_n=0;
        watchdog=0;
        while(!handler_seen && watchdog<500) begin
            @(posedge clk);
            if(cen_E) begin
                watchdog=watchdog+1;
                if(op && addr==handler_pc[15:0]) handler_seen=1;
            end
        end
        assert_msg(handler_seen,$sformatf("%s IRQ did not reach handler %04x",label,handler_pc[15:0]));
        @(negedge clk); irq_n=1;
    end
endtask

initial begin
    for(i=0;i<256;i=i+1) code_mem[i]=8'h12;
    for(i=0;i<32;i=i+1) stack_mem[i]=8'h00;
    for(i=0;i<16;i=i+1) vector_mem[i]=8'h00;
    @(negedge rst);
    load_test_program(8'h34,8'h00); measure_case(5,16'h0122,500,"PSHS mask 00");
    load_test_program(8'h36,8'h00); measure_case(5,16'h0122,500,"PSHU mask 00");
    load_test_program(8'h3f,8'h12); measure_case(19,16'h0150,500,"SWI");
    load_test_program(8'h10,8'h3f); measure_case(20,16'h0160,500,"SWI2 vector $FFF4");
    load_test_program(8'h11,8'h3f); measure_case(20,16'h0170,500,"SWI3 vector $FFF2");
    check_page10_word_decode();
    load_test_program(8'h13,8'h12); measure_wait_and_wake(7'd113,4,16'h0150,"SYNC IRQ wake");
    load_test_program(8'h3c,8'h00); measure_wait_and_wake(7'd110,20,16'h0150,"CWAI entry and IRQ wake");
    check_irq_full_frame();
    pass();
end

initial begin
    clk=0; rst=1;
    forever #10 clk=~clk;
end
initial begin
    #100 rst=0;
    #100000 $display("FAIL: testbench timeout"); $finish;
end
initial begin
    $dumpfile("test.lxt");
    $dumpvars(0,clk,rst,cpu_reset_n,phase,irq_n,addr,op,ba,avma);
    $dumpvars(0,uut.CpuState);
end
endmodule
