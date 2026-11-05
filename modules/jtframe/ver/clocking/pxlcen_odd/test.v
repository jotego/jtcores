/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 5-11-2026 */

`timescale 1ns/1ps

module test;

localparam DIV = `JTFRAME_PXL_DIV;

reg clk=0;
wire pxl_cen, pxl2_cen;
integer cycle, last_pxl=-1, last_pxl2=-1, pixels=0, double_pixels=0;
integer interval, previous_interval=0;
always #5 clk=~clk;

initial begin
    for(cycle=0; cycle<1000*DIV; cycle=cycle+1) begin
        @(negedge clk);
        if(pxl_cen!==1'b0 && pxl_cen!==1'b1) $fatal(1,"FAIL: unknown pixel enable");
        if(pxl2_cen!==1'b0 && pxl2_cen!==1'b1) $fatal(1,"FAIL: unknown double-pixel enable");
        if(pxl_cen) begin
            if(pxl2_cen!==1'b1) $fatal(1,"FAIL: unaligned enables");
            if(last_pxl>=0 && cycle-last_pxl!=DIV) $fatal(1,"FAIL: pixel cadence");
            last_pxl=cycle;
            pixels=pixels+1;
        end
        if(pxl2_cen) begin
            if(last_pxl2>=0) begin
                interval=cycle-last_pxl2;
                if(interval!=DIV/2 && interval!=(DIV+1)/2) $fatal(1,"FAIL: double-pixel cadence");
                if(previous_interval!=0 && interval+previous_interval!=DIV)
                    $fatal(1,"FAIL: double-pixel intervals do not alternate");
                previous_interval=interval;
            end
            last_pxl2=cycle;
            double_pixels=double_pixels+1;
        end
    end
    if(pixels!=1000 || double_pixels!=2000) $fatal(1,"FAIL: pulse counts");
    $display("PASS: divide-%0d pixels and alternating double-pixel cadence",DIV);
    $finish;
end

jtframe_pxlcen uut(
    .clk        ( clk      ),
    .pxl_cen    ( pxl_cen  ),
    .pxl2_cen   ( pxl2_cen )
);

endmodule
