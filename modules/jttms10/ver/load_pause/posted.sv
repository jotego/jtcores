/* SPDX-License-Identifier: GPL-3.0-or-later */
`timescale 1ns/1ps
// Posted fields acknowledge CPU acceptance before memory completes. Observe
// the first real memory response during the CPU pause; the original timing
// bench still checks every physical transfer, held CPU state and final data.
module posted_response;
    test cpu_test();
    reg response_seen=0;
    always @(posedge cpu_test.clk) begin
        if(cpu_test.rst) response_seen<=0;
        else if(cpu_test.measuring && !cpu_test.cen && cpu_test.cyc_ack && !response_seen) begin
            $display("PAUSE_DATA_ACK %0d",cpu_test.now);
            response_seen<=1;
        end
    end
endmodule
