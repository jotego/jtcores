/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 3-11-2026 */

`timescale 1ns/1ps

module test;

localparam CLK_MHZ = `ifdef JTFRAME_SDRAM96 96 `else 48 `endif;
localparam PXL_PERIOD = CLK_MHZ / `JTFRAME_PXLCLK;

reg clk=0;
wire pxl_cen, pxl2_cen;
integer cycle, last_pxl=-1, last_pxl2=-1, pixels=0, double_pixels=0;

always #5 clk=~clk;

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
    for(cycle=0; cycle<960; cycle=cycle+1) begin
        @(negedge clk);
        if(pxl_cen!==1'b0 && pxl_cen!==1'b1) $fatal(1,"FAIL: unknown pxl_cen");
        if(pxl2_cen!==1'b0 && pxl2_cen!==1'b1) $fatal(1,"FAIL: unknown pxl2_cen");
        if(pxl_cen) begin
            if(pxl2_cen!==1'b1) $fatal(1,"FAIL: pixel enables are not aligned");
            if(last_pxl>=0 && cycle-last_pxl!=PXL_PERIOD)
                $fatal(1,"FAIL: pixel cadence %0d, expected %0d",cycle-last_pxl,PXL_PERIOD);
            last_pxl=cycle;
            pixels=pixels+1;
        end
        if(pxl2_cen) begin
            if(last_pxl2>=0 && cycle-last_pxl2!=PXL_PERIOD/2)
                $fatal(1,"FAIL: double-pixel cadence %0d, expected %0d",cycle-last_pxl2,PXL_PERIOD/2);
            last_pxl2=cycle;
            double_pixels=double_pixels+1;
        end
    end
    if(pixels!=960/PXL_PERIOD || double_pixels!=2*pixels)
        $fatal(1,"FAIL: incorrect pulse counts: pixels=%0d double_pixels=%0d",pixels,double_pixels);
    $display("PASS: %0d MHz reference, %0d MHz pixels, %0d pixels and %0d double pixels",CLK_MHZ,`JTFRAME_PXLCLK,pixels,double_pixels);
    $finish;
end

jtframe_pxlcen uut(
    .clk        ( clk      ),
    .pxl_cen    ( pxl_cen  ),
    .pxl2_cen   ( pxl2_cen )
);

endmodule
