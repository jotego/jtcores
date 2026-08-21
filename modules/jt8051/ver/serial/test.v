/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

`timescale 1ns/1ps

module test;

reg clk=0, rst=1, cen=1, tick12=0, t1_ovf=0, sbuf_we=0, rxd=1;
reg [7:0] pcon=8'h80, scon=8'h50, sbuf_din=0;
wire rxd_o, txd, ti_set, rx_valid, ri_set, rx_rb8;
wire [7:0] rx_data;

always #5 clk=~clk;

task ticks;
    input integer count;
    integer n;
begin
    for (n=0;n<count;n=n+1) begin
        @(negedge clk); t1_ovf=1;
        @(posedge clk);
    end
    @(negedge clk); t1_ovf=0;
end
endtask

// With SMOD clear, the fixed mode-2 generator produces one 16x baud-clock
// edge for every six machine-cycle ticks.
task mode2_ticks;
    input integer count;
    integer n, m;
begin
    for (n=0; n<count; n=n+1) begin
        for (m=0; m<6; m=m+1) begin
            @(negedge clk); tick12 = 1;
            @(negedge clk); tick12 = 0;
        end
    end
end
endtask

task check_ok;
    input condition;
    input [8*64-1:0] text;
begin
    if (!condition) begin
        $display("FAIL: %0s", text);
        $fatal(1,"JT8051 serial test failed");
    end
end
endtask

jt8051_serial dut(
    .rst, .clk, .cen, .tick12, .t1_ovf, .pcon, .scon, .sbuf_we, .sbuf_din,
    .rxd, .rxd_o, .txd, .ti_set, .rx_valid, .ri_set, .rx_data, .rx_rb8
);

initial begin
    repeat (2) @(posedge clk);
    rst=0;

    // Mode 1, SMOD=1: each Timer-1 overflow advances the 16x baud clock.
    @(negedge clk); sbuf_din=8'ha5; sbuf_we=1;
    @(negedge clk); sbuf_we=0;
    ticks(16); check_ok(!txd, "mode 1 emits start bit");
    ticks(16); check_ok( txd, "mode 1 transmits data bit 0 LSB first");
    ticks(16); check_ok(!txd, "mode 1 transmits data bit 1");
    ticks(16); check_ok( txd, "mode 1 transmits data bit 2");
    ticks(16); check_ok(!txd, "mode 1 transmits data bit 3");
    ticks(16); check_ok(!txd, "mode 1 transmits data bit 4");
    ticks(16); check_ok( txd, "mode 1 transmits data bit 5");
    ticks(16); check_ok(!txd, "mode 1 transmits data bit 6");
    ticks(16); check_ok( txd, "mode 1 transmits data bit 7");
    ticks(16); check_ok(txd && ti_set, "mode 1 stop bit raises TI");

    // Receive a complete 8N1 frame.  Start is sampled after half a bit,
    // then each payload bit at the following bit centres.
    rxd=0;
    ticks(8);
    rxd=1; ticks(16);
    rxd=0; ticks(16);
    rxd=1; ticks(16);
    rxd=0; ticks(16);
    rxd=0; ticks(16);
    rxd=1; ticks(16);
    rxd=0; ticks(16);
    rxd=1; ticks(16);
    rxd=1; ticks(16);
    check_ok(rx_valid && ri_set && rx_data==8'ha5 && rx_rb8, "mode 1 receives 8N1 and sets RI/RB8");

    // Mode 3 retains the mode-2 frame format but obtains its baud clock
    // from Timer 1.  TB8 is emitted after eight data bits, then TI is set
    // with the stop bit.
    @(negedge clk); scon=8'hc8; sbuf_din=8'h00; sbuf_we=1;
    @(negedge clk); sbuf_we=0;
    ticks(16); check_ok(!txd, "mode 3 emits start bit");
    ticks(16*8); check_ok(!txd, "mode 3 emits all-zero payload");
    ticks(16); check_ok(txd, "mode 3 emits TB8");
    ticks(16); check_ok(txd && ti_set, "mode 3 stop bit raises TI");

    // Mode 2 uses its fixed fosc/64 baud source (SMOD clear) and the same
    // start/data/TB8/stop frame.  This checks that Timer 1 is not required.
    @(negedge clk); pcon=0; scon=8'h88; sbuf_din=8'h01; sbuf_we=1;
    @(negedge clk); sbuf_we=0;
    mode2_ticks(16); check_ok(!txd, "mode 2 emits start bit from fixed baud clock");
    mode2_ticks(16); check_ok(txd, "mode 2 emits data bit 0");

    // Mode 0 shifts data on P3.0/RxD and clocks it on P3.1/TxD.  It has
    // neither a UART start bit nor a stop bit, and completes in eight
    // machine cycles without Timer-1 overflow events.
    @(negedge clk); pcon=0; scon=8'h00; sbuf_din=8'h01; sbuf_we=1;
    @(negedge clk); sbuf_we=0;
    check_ok(rxd_o, "mode 0 presents data bit 0 on RxD before its clock edge");
    repeat (8) begin
        @(negedge clk); tick12=1;
        @(posedge clk); #1 check_ok(!txd, "mode 0 emits a TxD shift-clock pulse");
        @(negedge clk); tick12=0;
    end
    check_ok(rxd_o && ti_set, "mode 0 releases RxD and raises TI after eight bits");

    $display("PASS");
    $finish;
end

endmodule
