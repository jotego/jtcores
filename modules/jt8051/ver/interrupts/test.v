/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

`timescale 1ns/1ps

module test;

reg         rst = 1'b1;
reg         clk = 1'b0;
reg         cen = 1'b0;
reg         int0n = 1'b1, int1n = 1'b1;
reg  [ 7:0] p0_i = 8'hff, p1_i = 8'hff, p2_i = 8'hff, p3_i = 8'hff;
wire [ 7:0] p0_o, p1_o, p2_o, p3_o;
reg  [ 7:0] x_din = 8'd0;
wire [ 7:0] x_dout;
wire [15:0] x_addr;
wire        x_wr, x_acc;
reg  [11:0] prog_addr = 12'd0;
reg  [ 7:0] prom_din = 8'd0;
reg         prom_we = 1'b0;
reg  [15:0] saved_pc;
reg  [15:0] jb_stack_pc;
reg         saw_vector_isr = 1'b0;
reg  [ 1:0] cen_gap = 2'd0;
reg         priority_phase = 1'b0;
integer     priority_irqs = 0;
reg  [15:0] priority_first_vec;
reg  [15:0] priority_second_vec;
reg         priority_first_ie0;
reg         priority_first_tf0;

always #5 clk = ~clk;
// Match the 6 MHz MCU enable used by Bionic Commando on a 24 MHz wrapper
// clock: a cen pulse is followed by three idle wrapper clocks.
always @(posedge clk) begin
    if (rst) begin
        cen <= 1'b0;
        cen_gap <= 2'd0;
    end else if (cen) begin
        cen <= 1'b0;
        cen_gap <= 2'd2;
    end else if (cen_gap != 0) begin
        cen_gap <= cen_gap-1'd1;
    end else cen <= 1'b1;
end
always @(posedge clk) begin
    if (rst) saw_vector_isr <= 1'b0;
    else if (uut.u_mcu.pc == 16'h0200) saw_vector_isr <= 1'b1;
end

// Record arbitration before the peripheral clears the selected pending flag.
// The final test raises low-priority INT0 and high-priority Timer0 together.
always @(posedge uut.u_mcu.u_ctrl.irq_take) if (priority_phase) begin
    if (priority_irqs == 0) begin
        priority_first_vec <= uut.u_mcu.u_periph.irq_vec_l;
        priority_first_ie0 <= uut.u_mcu.u_periph.tcon[1];
        priority_first_tf0 <= uut.u_mcu.u_periph.tcon[5];
    end else if (priority_irqs == 1) begin
        priority_second_vec <= uut.u_mcu.u_periph.irq_vec_l;
    end
    priority_irqs <= priority_irqs + 1;
end

task put;
    input [11:0] addr;
    input [ 7:0] data;
begin
    @(negedge clk);
    prog_addr = addr;
    prom_din  = data;
    prom_we   = 1'b1;
    @(negedge clk);
    prom_we   = 1'b0;
end
endtask

`include "test_tasks.vh"

jtframe_8751mcu uut(
    .rst, .clk, .cen, .int0n, .int1n, .p0_i, .p1_i, .p2_i, .p3_i,
    .p0_o, .p1_o, .p2_o, .p3_o,
    .x_din, .x_dout, .x_addr, .x_wr, .x_acc,
    .clk_rom(clk), .prog_addr, .prom_din, .prom_we
);

initial begin
    // Reset jumps over the vector.  The ISR samples R0 so the first entry
    // proves that an IE write retires one following instruction first.
    put(12'h000,8'h02); put(12'h001,8'h00); put(12'h002,8'h08);
    // Exercise the synchronous-ROM vector path used by Bionic Commando:
    // the interrupt vector itself is an LJMP, not a one-byte ISR opcode.
    put(12'h003,8'h02); put(12'h004,8'h02); put(12'h005,8'h00); // LJMP $0200
    put(12'h200,8'he8); // MOV A,R0
    put(12'h201,8'hf5); put(12'h202,8'h90); // MOV P1,A
    put(12'h203,8'h32); // RETI
    put(12'h008,8'h75); put(12'h009,8'h88); put(12'h00a,8'h01); // edge INT0
    put(12'h00b,8'h00); // leave one instruction to latch the edge flag
    put(12'h00c,8'h75); put(12'h00d,8'ha8); put(12'h00e,8'h81);
    put(12'h00f,8'h08); // INC R0: must execute before the pending INT0 ISR
    put(12'h010,8'h80); put(12'h011,8'hfe); // main loop

    // This is the Body Slam VINT polling sequence.  P3.2 is high while
    // polling and the INT0 pin falls immediately after JB has been fetched.
    // The 8051 must finish that JB (the low P3.2 makes it fall through) and
    // push the address after all three bytes, 002Ah, on interrupt entry.
    put(12'h020,8'h75); put(12'h021,8'h88); put(12'h022,8'h00); // MOV TCON,#0
    put(12'h023,8'h75); put(12'h024,8'ha8); put(12'h025,8'h81); // MOV IE,#81
    put(12'h026,8'h00); // consume the architectural IE interrupt delay
    put(12'h027,8'h20); put(12'h028,8'hb2); put(12'h029,8'hfd); // JB P3.2,$0027
    put(12'h02a,8'h75); put(12'h02b,8'h90); put(12'h02c,8'h5a); // MOV P1,#5A
    put(12'h02d,8'h80); put(12'h02e,8'hfe); // main loop

    repeat (160) @(posedge clk); // leave reset long enough to clear IRAM
    rst = 1'b0;
    // Wait until TCON made INT0 edge-sensitive, then inject its edge flag
    // while IE is still disabled.  This isolates the architectural IE delay
    // from pad/synchronizer timing.
    while (uut.u_mcu.u_periph.tcon != 8'h01) @(posedge clk);
    @(negedge clk);
    uut.u_mcu.u_periph.tcon[1] = 1'b1;
    repeat (1200) @(posedge clk);
    assert_msg(p1_o == 8'h01, "IE write executes one instruction before taking INT0");
    assert_msg(saw_vector_isr, "INT0 vector LJMP reaches its synchronous-ROM ISR target");

    // A second short edge checks the source/vector latch and the saved
    // prefetch address independently of the IE-write deferral above.
    repeat (1200) @(posedge clk);
    int0n = 1'b0;
    // The pin pulse ends after the controller takes the request but before
    // the ISR can execute its first micro-operation.  This catches using a
    // live request to select the vector instead of the accepted source.
    @(posedge uut.u_mcu.u_ctrl.irq_take);
    saved_pc = uut.u_mcu.pc-1'd1;
    @(negedge clk) int0n = 1'b1;
    repeat (1000) @(posedge clk);
    assert_msg(p1_o == 8'h01, "INT0 vector executes through wrapper stack RAM");
    assert_msg(uut.u_mcu.sp == 8'h07, "RETI restores stack pointer");
    assert_msg(uut.u_ramu.u_ramu.mem[8'h08] == saved_pc[7:0], "IRQ stack saves prefetched opcode address low byte");
    assert_msg(uut.u_ramu.u_ramu.mem[8'h09] == saved_pc[15:8], "IRQ stack saves prefetched opcode address high byte");

    // Restart at the Body Slam polling loop.  Drive VINT low after the JB
    // opcode fetch but before its operand micro-operations.  This used to
    // enter the ISR immediately and save 0027, causing the stalled-countdown
    // path observed in the whole-core simulation.
    put(12'h000,8'h02); put(12'h001,8'h00); put(12'h002,8'h20);
    rst = 1'b1;
    int0n = 1'b1;
    repeat (160) @(posedge clk);
    rst = 1'b0;
    while (uut.u_mcu.ir != 8'h20 || uut.u_mcu.pc != 16'h0028) @(posedge clk);
    @(negedge clk) int0n = 1'b0;
    @(posedge uut.u_mcu.u_ctrl.irq_take);
    @(negedge clk) int0n = 1'b1;
    repeat (1000) @(posedge clk);
    jb_stack_pc = {uut.u_ramu.u_ramu.mem[8'h09], uut.u_ramu.u_ramu.mem[8'h08]};
    assert_msg(jb_stack_pc == 16'h002a, "INT0 after fetched JB P3.2 completes the instruction before saving PC");
    assert_msg(p1_o == 8'h5a, "RETI resumes after the Body Slam JB polling instruction");

    // Check priority arbitration and source-specific acknowledge.  INT0 and
    // Timer0 are both pending, but PT0 makes Timer0 high priority.  Its
    // acknowledge must clear TF0 only; the low-priority INT0 request then
    // runs after the Timer0 RETI rather than being discarded.
    put(12'h000,8'h02); put(12'h001,8'h00); put(12'h002,8'h40); // reset -> main
    put(12'h003,8'h02); put(12'h004,8'h03); put(12'h005,8'h00); // INT0 -> $0300
    put(12'h00b,8'h02); put(12'h00c,8'h03); put(12'h00d,8'h20); // T0 -> $0320
    put(12'h300,8'h75); put(12'h301,8'h90); put(12'h302,8'h10); // MOV P1,#$10
    put(12'h303,8'h32); // RETI
    put(12'h320,8'h75); put(12'h321,8'h90); put(12'h322,8'h20); // MOV P1,#$20
    put(12'h323,8'h32); // RETI
    put(12'h040,8'h00); put(12'h041,8'h80); put(12'h042,8'hfd); // NOP; SJMP $0040

    rst = 1'b1;
    int0n = 1'b1;
    repeat (160) @(posedge clk);
    rst = 1'b0;
    repeat (600) @(posedge clk);
    priority_irqs = 0;
    priority_phase = 1'b1;
    // IE: EA|ET0|EX0.  IP: PT0.  TCON: IT0|IE0|TF0.  Directly setting the
    // latched flags isolates peripheral arbitration from edge-pad timing.
    @(negedge clk);
    uut.u_mcu.u_periph.ie   = 8'h83;
    uut.u_mcu.u_periph.ip   = 8'h02;
    uut.u_mcu.u_periph.tcon = 8'h23;
    repeat (3000) @(posedge clk);
    priority_phase = 1'b0;
    assert_msg(priority_irqs == 2, "simultaneous high Timer0 and low INT0 each take exactly once");
    assert_msg(priority_first_vec == 16'h000b, "high-priority Timer0 wins initial interrupt arbitration");
    assert_msg(priority_second_vec == 16'h0003, "pending low-priority INT0 runs after Timer0 RETI");
    assert_msg(priority_first_ie0 && priority_first_tf0, "both pending flags are present when Timer0 is accepted");
    assert_msg(p1_o == 8'h10, "low-priority INT0 ISR executes after the Timer0 ISR");
    assert_msg(uut.u_mcu.sp == 8'h07, "both priority ISR RETIs restore stack pointer");
    pass();
end

endmodule
