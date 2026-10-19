/* SPDX-License-Identifier: GPL-3.0-or-later */
`timescale 1ns/1ps
// A wrapper observes the real CPU output without changing
// the normal timing bench or replacing any CPU/cache/bus implementation.
module emu_events;
    test cpu_test();
    always @(posedge cpu_test.clk) begin
        if(!cpu_test.rst && cpu_test.measuring && cpu_test.dut.emu_ack) begin
            if(cpu_test.ir!==16'h0100) $fatal(1,"EMU acknowledge belongs to another instruction");
            $display("EMU_ACK %0d",cpu_test.now);
        end
    end
endmodule
