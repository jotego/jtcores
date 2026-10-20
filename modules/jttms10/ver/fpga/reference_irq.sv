// SPDX-License-Identifier: GPL-3.0-or-later
// Independent bench observation: public PC/ST installation and retire only.
// No CPU control signal or FPGA observer is used to define these boundaries.
module reference_irq(
    input clk, rst, measuring, finished, retire,
    input [31:0] absolute_clock, pc, st
);
    reg [31:0] handler=0, old_pc=0, last_retire=0;
    reg [31:0] count=0, previous=0, complete=0, first=0;
    integer rc;
    initial rc=$value$plusargs("ENTRY_HANDLER=%h",handler);

    always @(posedge clk) begin
        if(rst) begin
            old_pc<=0; last_retire<=0;
            count<=0; previous<=0; complete<=0; first<=0;
        end else begin
            old_pc<=pc;
            if(measuring && retire) begin
                // Public retire and PC/ST are registered by the CPU. Both
                // expose the assigning edge one fast clock after it happened.
                last_retire<=absolute_clock-32'd1;
                if(count!=0 && first==0) first<=absolute_clock-32'd1;
            end
            if(measuring && handler!=0 && pc==handler && pc!=old_pc && st==32'h10) begin
                count<=count+32'd1;
                if(count==0) begin
                    previous<=retire ? absolute_clock-32'd1 : last_retire;
                    complete<=absolute_clock-32'd1;
                end
            end
        end
    end

    always @(posedge finished) begin
        #1;
        $display("IRQ_BOUNDARY count=%0d previous=%0d complete=%0d first=%0d",
                 count,previous,complete,first);
    end
endmodule
