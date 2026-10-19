/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

`timescale 1ns/1ps
module pal_phase_tb;
reg clk=0, rst=1;
reg [2:0] divider=0;
wire pxl_cen=divider==0;
wire [8:0] video_h;
wire lvbl;
reg lvbl_l;
integer expected_h, expected_v, pixel, checked=0, transitions=0;

always #5 clk=~clk;
always @(posedge clk) divider<=divider+3'd1;

jtseicro_video dut(
    .rst               ( rst     ),
    .clk               ( clk     ),
    .pxl_cen           ( pxl_cen ),
    .flip              ( 1'b0    ),
    .cpu_lvbl          ( lvbl    ),
    .video_h           ( video_h ),
    .tile_vram_data    ( 8'd0    ),
    .tile_color_data   ( 8'd0    ),
    .scroll_video_data ( 8'd0    ),
    .obj_ram0_data     ( 8'd0    ),
    .obj_ram1_data     ( 8'd0    ),
    .scr_data          ( 16'd0   ),
    .obj_data          ( 16'd0   ),
    .scr_ok            ( 1'b1    ),
    .obj_ok            ( 1'b1    ),
    .proms_data        ( 8'd0    ),
    .gfx_en            ( 4'hf    )
);

initial begin
    repeat(32) @(negedge clk);
    rst=0;
    wait(dut.vdump==0 && dut.hdump==1);
    expected_h=257;
    expected_v=0;
    lvbl_l=lvbl;
    for(pixel=0;pixel<4*264*384;pixel=pixel+1) begin
        @(posedge clk);
        while(!pxl_cen) @(posedge clk);
        if(expected_h==511) begin
            expected_h=128;
            expected_v=expected_v==263 ? 0 : expected_v+1;
        end else expected_h=expected_h+1;
        #1;
        if(video_h!==expected_h[8:0])
            $fatal(1,"Physical H got=%0d expected=%0d",video_h,expected_h);
        if(lvbl!==(expected_v>=16 && expected_v<240))
            $fatal(1,"VBLK phase H=%0d V=%0d lvbl=%b",expected_h,expected_v,lvbl);
        if(lvbl!==lvbl_l) begin
            if(video_h!=128 || (expected_v!=16 && expected_v!=240))
                $fatal(1,"VBLK transition H=%0d V=%0d",video_h,expected_v);
            transitions=transitions+1;
        end
        lvbl_l=lvbl;
        checked=checked+1;
    end
    if(transitions!=8) $fatal(1,"VBLK transition count=%0d",transitions);
    $display("PASS PAL phase: %0d pixels, VBLK transitions at H128 / V16,V240",checked);
    $finish;
end

initial begin
    #100000000;
    $fatal(1,"PAL phase timeout");
end
endmodule
