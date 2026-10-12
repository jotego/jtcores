/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-10-2026 */
`timescale 1ns/1ps
module test;
reg clk=0, pxl_cen=1, LHBL=1, LVBL=1;
reg [7:0] fix_pxl=8'h35, scr_pxl=8'h72, obj_pxl=8'ha6;
reg [3:0] gfx_en=15, palr_data=0, palg_data=0, palb_data=0;
wire [7:0] pal_addr;
wire [3:0] red, green, blue;
integer mask, transparent, value;
reg [7:0] wanted;
always #5 clk=~clk;
jtslap_colmix uut(
    .clk(clk), .pxl_cen(pxl_cen), .LHBL(LHBL), .LVBL(LVBL),
    .fix_pxl(fix_pxl), .scr_pxl(scr_pxl), .obj_pxl(obj_pxl),
    .pal_addr(pal_addr), .palr_data(palr_data),
    .palg_data(palg_data), .palb_data(palb_data),
    .red(red), .green(green), .blue(blue), .gfx_en(gfx_en)
);
task check;
    input condition;
    input [255:0] message;
    begin
        if(!condition) begin $display("FAIL: %s",message); $finish; end
    end
endtask
task step;
    begin @(posedge clk); #1; @(negedge clk); end
endtask
initial begin
    for(transparent=0;transparent<4;transparent=transparent+1) begin
        fix_pxl=transparent[0] ? 8'h34 : 8'h35;
        obj_pxl=transparent[1] ? 8'ha0 : 8'ha6;
        for(mask=0;mask<16;mask=mask+1) begin
            gfx_en=mask;
            wanted=mask[0] && !transparent[0] ? fix_pxl :
                   mask[3] && !transparent[1] ? obj_pxl :
                   mask[1] ? scr_pxl : 8'd0;
            #1; check(pal_addr==wanted,"layer priority/transparency");
        end
    end
    for(value=0;value<16;value=value+1) begin
        palr_data=value; palg_data=15-value; palb_data=value^5;
        step(); check(red==palr_data && green==palg_data && blue==palb_data,"native PROM colours");
    end
    pxl_cen=0; palr_data=0; palg_data=15; palb_data=0;
    step(); check({red,green,blue}==12'hf0a,"pixel enable hold");
    LHBL=0; #1; check({red,green,blue}==0,"blank without pixel tick");
    LHBL=1; #1; check({red,green,blue}==12'hf0a,"first visible pixel");
    pxl_cen=1; LHBL=0; step(); check({red,green,blue}==0,"horizontal blank");
    LHBL=1; LVBL=0; step(); check({red,green,blue}==0,"vertical blank");
    $display("PASS: layer enables, priority, transparency, native colours and blanking");
    $finish;
end
endmodule
