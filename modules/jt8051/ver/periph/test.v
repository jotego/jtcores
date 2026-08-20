/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

`timescale 1ns/1ps

module test;

reg         clk = 0, rst = 1, cen = 1;
reg         int0n = 1, int1n = 1;
reg  [ 7:0] p0_i = 'hff, p1_i = 'hff, p2_i = 'hff, p3_i = 'hff;
wire [ 7:0] p0_o, p1_o, p2_o, p3_o;
reg  [ 7:0] sfr_addr = 0, sfr_din = 0;
reg         sfr_we = 0, latch_read = 0, irq_take = 0, reti = 0, instruction_end = 0;
wire [ 7:0] sfr_dout;
wire        irq;
wire [15:0] irq_vec;
reg  [ 7:0] tl0_start;

always #5 clk = ~clk;

task write_sfr;
    input [7:0] addr;
    input [7:0] data;
begin
    @(negedge clk);
    sfr_addr = addr;
    sfr_din  = data;
    sfr_we   = 1;
    @(negedge clk);
    sfr_we   = 0;
    // The direct peripheral test has no controller.  Retire the SFR write
    // and one following instruction so IE/IP writes observe the real 8051
    // interrupt deferral before later request-priority checks.
    if (addr==8'ha8 || addr==8'hb8) begin
        @(negedge clk); instruction_end = 1;
        @(negedge clk); instruction_end = 0;
        @(negedge clk); instruction_end = 1;
        @(negedge clk); instruction_end = 0;
    end
end
endtask

task reset_periph;
begin
    rst = 1;
    int0n = 1;
    int1n = 1;
    p3_i = 'hff;
    repeat (2) @(posedge clk);
    rst = 0;
    repeat (2) @(posedge clk);
end
endtask

task retire_following_instruction;
begin
    @(negedge clk); instruction_end = 1;
    @(negedge clk); instruction_end = 0;
    @(negedge clk); instruction_end = 1;
    @(negedge clk); instruction_end = 0;
end
endtask

task instruction_boundary;
begin
    @(negedge clk); instruction_end = 1;
    @(negedge clk); instruction_end = 0;
end
endtask

// jt8051_ctrl captures a request on one cen and asserts irq_take at a later
// instruction boundary.  Model that handoff here instead of acknowledging a
// newly-created peripheral request in the same cycle.
task take_irq;
begin
    @(negedge clk);
    @(negedge clk); irq_take = 1;
    @(negedge clk); irq_take = 0;
end
endtask

task next_tick;
begin
    while (dut.osc != 4'd11) @(negedge clk);
    @(posedge clk);
    #1;
end
endtask

task check_ok;
    input condition;
    input [8*72-1:0] text;
begin
    if (!condition) begin
        $display("FAIL: %0s", text);
        $display("tcon=%02h tmod=%02h th0=%02h tl0=%02h th1=%02h tl1=%02h service=%0d osc=%0d",
            dut.tcon, dut.tmod, dut.th0, dut.tl0, dut.th1, dut.tl1, dut.service, dut.osc);
        $fatal(1, "JT8051 peripheral test failed");
    end
end
endtask

jt8051_periph dut(
    .rst, .clk, .cen, .int0n, .int1n,
    .p0_i, .p1_i, .p2_i, .p3_i, .p0_o, .p1_o, .p2_o, .p3_o,
    .sfr_addr, .sfr_din, .sfr_we, .latch_read, .sfr_dout,
    .irq_take, .reti, .instruction_end, .irq, .irq_vec
);

initial begin
    // The timer prescaler is one 8051 machine cycle: exactly 12 cen pulses.
    // Keeping this separate from overflow tests catches an accidental
    // 4-bit/16-pulse rollover.
    reset_periph;
    write_sfr(8'h89, 8'h01);
    write_sfr(8'h88, 8'h10);
    while (dut.osc != 0) @(negedge clk);
    tl0_start = dut.tl0;
    repeat (11) @(posedge clk);
    #1 check_ok(dut.tl0==tl0_start, "timer prescaler waits for 12 cen pulses");
    @(posedge clk);
    #1 check_ok(dut.tl0==tl0_start+1'd1 && dut.osc==0, "timer prescaler ticks at 12 cen pulses");

    // Mode 1 overflow (16-bit timer).
    reset_periph;
    write_sfr(8'h89, 8'h01);
    write_sfr(8'h8c, 8'hff);
    write_sfr(8'h8a, 8'hfe);
    write_sfr(8'h88, 8'h10);
    next_tick;
    next_tick;
    check_ok(dut.tl0==0 && dut.th0==0 && dut.tcon[5], "timer 0 mode 1 overflow");

    // Mode 2 reloads TL0 from TH0 on overflow.
    reset_periph;
    write_sfr(8'h89, 8'h02);
    write_sfr(8'h8c, 8'haa);
    write_sfr(8'h8a, 8'hff);
    write_sfr(8'h88, 8'h10);
    next_tick;
    check_ok(dut.tl0==8'haa && dut.tcon[5], "timer 0 mode 2 reload");

    // Split mode: TL0 is timer 0 and TH0 is the independent timer 1 byte.
    reset_periph;
    write_sfr(8'h89, 8'h03);
    write_sfr(8'h8c, 8'hfe);
    write_sfr(8'h8a, 8'hff);
    write_sfr(8'h88, 8'h50);
    next_tick;
    check_ok(dut.tl0==0 && dut.th0==8'hff && dut.tcon[5], "timer 0 split first tick");
    next_tick;
    check_ok(dut.th0==0 && dut.tcon[7], "timer 0 split TH0 overflow");
    check_ok(dut.tl1==2, "timer 1 continues while timer 0 is split");

    // In split mode timer 1 ignores TR1/GATE/C/T; only mode 3 stops it.
    reset_periph;
    write_sfr(8'h89, 8'h13);
    write_sfr(8'h88, 8'h10);
    next_tick;
    check_ok(dut.tl1==1 && dut.th0==0, "split timer 1 ignores TR1 and runs independently");

    // A T0 counter edge in split mode is also retained until the next tick.
    reset_periph;
    write_sfr(8'h89, 8'h07);
    write_sfr(8'h88, 8'h10);
    while (dut.osc != 4'd0) @(negedge clk);
    p3_i[4] = 0;
    @(posedge clk);
    repeat (12) @(posedge clk);
    check_ok(dut.tl0==1, "split timer 0 retains a counter edge at an arbitrary phase");

    // Timer 1 mode 3 is stopped.
    reset_periph;
    write_sfr(8'h89, 8'h30);
    write_sfr(8'h88, 8'h40);
    next_tick;
    check_ok(dut.tl1==0 && dut.th1==0, "timer 1 mode 3 stops");

    // Counter mode advances only on the sampled falling transition at T0.
    reset_periph;
    write_sfr(8'h89, 8'h05);
    write_sfr(8'h88, 8'h10);
    while (dut.osc != 4'd11) @(negedge clk);
    p3_i[4] = 0;
    @(posedge clk);
    repeat (24) @(posedge clk);
    check_ok(dut.tl0==1, "timer 0 counter edge");

    // An external counter edge is retained until the next machine-cycle tick.
    reset_periph;
    write_sfr(8'h89, 8'h05);
    write_sfr(8'h88, 8'h10);
    while (dut.osc != 4'd0) @(negedge clk);
    p3_i[4] = 0;
    @(posedge clk);
    repeat (12) @(posedge clk);
    check_ok(dut.tl0==1, "timer 0 counter edge at an arbitrary oscillator phase");

    // Gate mode blocks the timer while INT0 is low.
    reset_periph;
    int0n = 0;
    write_sfr(8'h89, 8'h09);
    write_sfr(8'h88, 8'h10);
    repeat (24) @(posedge clk);
    check_ok(dut.tl0==0, "timer 0 gate blocks");
    int0n = 1;
    next_tick;
    check_ok(dut.tl0==1, "timer 0 gate releases");

    // INT0/INT1 share P3.2/P3.3 electrically.  A normal P3 read observes
    // the pin while a read-modify-write operation observes the latch.
    reset_periph;
    write_sfr(8'hb0, 8'hff);
    int0n = 0;
    sfr_addr = 8'hb0;
    latch_read = 0;
    #1 check_ok(sfr_dout==8'hfb, "P3 read reflects low INT0 pin");
    latch_read = 1;
    #1 check_ok(sfr_dout==8'hff, "P3 read-modify-write uses its latch");
    latch_read = 0;

    // Serial mode 0 drives its synchronous data through P3.0 and emits the
    // shift clock through P3.1.  Both alternate outputs remain gated by the
    // corresponding P3 latch bits.
    reset_periph;
    write_sfr(8'hb0, 8'hff);
    write_sfr(8'h98, 8'h00);
    write_sfr(8'h99, 8'ha5);
    #1 check_ok(dut.p3_o[1:0]==2'b11, "mode 0 presents bit 0 and idle TxD before its first clock");
    next_tick;
    check_ok(dut.p3_o[1:0]==2'b00, "mode 0 shifts P3.0 data and pulses P3.1 clock");

    // A high priority timer interrupt must win over a simultaneous low INT0.
    reset_periph;
    write_sfr(8'ha8, 8'h83);
    write_sfr(8'hb8, 8'h02);
    write_sfr(8'h88, 8'h20);
    int0n = 0;
    #1 check_ok(irq && irq_vec==16'h000b, "high priority source selects timer 0 vector");
    take_irq;
    @(negedge clk); reti = 1;
    @(negedge clk); reti = 0;
    retire_following_instruction;

    // RETI also defers a newly pending request through one complete mainline
    // instruction.  Reassert IE0 after the first service and count the two
    // instruction boundaries (RETI itself, then one mainline instruction).
    reset_periph;
    dut.ie = 8'h81;
    dut.tcon = 8'h03;
    take_irq;
    @(negedge clk); reti = 1;
    @(negedge clk); reti = 0;
    dut.tcon[1] = 1'b1;
    #1 check_ok(!irq, "RETI initially inhibits a re-pending interrupt");
    instruction_boundary;
    #1 check_ok(!irq, "RETI defers through one following instruction");
    instruction_boundary;
    #1 check_ok(irq && irq_vec==16'h0003, "RETI admits the request after one instruction");

    // Acknowledge only the selected source.  The pending timer must remain
    // pending after the higher-priority-by-order INT0 request is accepted.
    reset_periph;
    write_sfr(8'ha8, 8'h83);
    write_sfr(8'h88, 8'h21);
    int0n = 0;
    @(negedge clk);
    #1 check_ok(irq && irq_vec==16'h0003, "INT0 wins simultaneous low priority requests");
    take_irq;
    #1 check_ok(!dut.tcon[1] && dut.tcon[5], "INT0 acceptance clears only IE0");
    @(negedge clk); reti = 1;
    @(negedge clk); reti = 0;
    retire_following_instruction;
    #1 check_ok(irq && irq_vec==16'h000b, "remaining timer request is serviced next");
    take_irq;
    #1 check_ok(!dut.tcon[5], "timer acceptance clears TF0");

    // IRQ entry clears an edge-triggered flag, but the controller obtains
    // the vector after acknowledgement.  It must retain the acknowledged
    // INT0 vector rather than falling back to the serial vector.
    reset_periph;
    write_sfr(8'ha8, 8'h81);
    write_sfr(8'h88, 8'h01);
    int0n = 0;
    @(negedge clk);
    #1 check_ok(irq && irq_vec==16'h0003, "edge INT0 initially selects its vector");
    take_irq;
    #1 check_ok(!dut.tcon[1] && irq_vec==16'h0003, "acknowledged edge INT0 retains its vector");
    @(negedge clk); reti = 1;
    @(negedge clk); reti = 0;
    retire_following_instruction;

    // A high-priority ISR pre-empting an active low ISR restores low service.
    reset_periph;
    write_sfr(8'ha8, 8'h83);
    write_sfr(8'hb8, 8'h02);
    int0n = 0;
    #1 check_ok(irq && irq_vec==16'h0003, "low priority INT0 accepted");
    take_irq;
    write_sfr(8'h88, 8'h20);
    #1 check_ok(irq && irq_vec==16'h000b, "high priority timer pre-empts INT0");
    take_irq;
    @(negedge clk); reti = 1;
    @(negedge clk); reti = 0;
    retire_following_instruction;
    write_sfr(8'h88, 8'h00);
    #1 check_ok(!irq && dut.service==1, "RETI restores pre-empted low service");

    $display("PASS");
    $finish;
end

endmodule
