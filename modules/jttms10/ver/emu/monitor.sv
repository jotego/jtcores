/* SPDX-License-Identifier: GPL-3.0-or-later */
// A separate simulation root observes the real CPU output without changing
// the normal timing bench or replacing any CPU/cache/bus implementation.
module emu_events;
    always @(posedge test.clk) begin
        if(!test.rst && test.measuring && test.dut.emu_ack) begin
            if(test.ir!==16'h0100) $fatal(1,"EMU acknowledge belongs to another instruction");
            $display("EMU_ACK %0d",test.now);
        end
    end
endmodule
