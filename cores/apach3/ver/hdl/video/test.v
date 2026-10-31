/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-10-2026 */

`timescale 1ns/1ps
module test;
reg clk=0, rst=1, pxl_cen=0;
always #5 clk=~clk;
wire [10:0] palette_addr;
reg [15:0] palette_data=0;
wire [4:0] red, green, blue;
wire lhbl, lvbl;
reg [6:0] text_pxl=0;
reg [9:0] obj_pxl=0;
integer scenario, layer, x, y, expected_addr;
reg [14:0] expected_rgb;

jtapach3_video dut (
    .rst                ( rst          ),
    .clk                ( clk          ),
    .pxl_cen            ( pxl_cen      ),
    .rotate_data        ( 16'd0        ),
    .rotate_we          ( 1'b0         ),
    .road_z             ( 8'd0         ),
    .ground_invalidate  ( 1'b0         ),
    .road_invalidate    ( 1'b0         ),
    .road_x_addr        (              ),
    .road_x_data        ( 16'd0        ),
    .prom_addr          (              ),
    .prom_data          ( 8'd0         ),
    .ground_addr        (              ),
    .ground_cs          (              ),
    .ground_data        ( 16'd0        ),
    .ground_ok          ( 1'b0         ),
    .objram_addr        (              ),
    .objram_data        ( 16'hffff     ),
    .obj_ctrl_addr      (              ),
    .obj_ctrl_data      ( 16'd0        ),
    .sprites_addr       (              ),
    .sprites_cs         (              ),
    .sprites_data       ( 64'd0        ),
    .sprites_ok         ( 1'b0         ),
    .txmap_addr         (              ),
    .txmap_data         ( 16'd0        ),
    .text_rom_addr      (              ),
    .text_rom_cs        (              ),
    .text_rom_data      ( 32'd0        ),
    .text_rom_ok        ( 1'b0         ),
    .palette_video_addr ( palette_addr ),
    .palette_video_data ( palette_data ),
    .red                ( red          ),
    .green              ( green        ),
    .blue               ( blue         ),
    .LHBL               ( lhbl         ),
    .LVBL               ( lvbl         ),
    .HS                 (              ),
    .VS                 (              )
);

function [14:0] color;
    input [10:0] addr;
    begin color = {addr[4:0]^5'h15,addr[6:2]^5'h0b,addr[9:5]^5'h17}; end
endfunction

always @(posedge clk) palette_data <= {1'b0,color(palette_addr)};

task tick;
    begin
        @(negedge clk); pxl_cen=1;
        @(negedge clk); pxl_cen=0;
        repeat (7) @(negedge clk);
    end
endtask

initial begin
    force dut.text_pxl=text_pxl;
    force dut.obj_pxl=obj_pxl;
    force dut.u_ground.state=0;
    repeat (6) @(negedge clk);
    rst=0;
    for (layer=0;layer<3;layer=layer+1) begin
        text_pxl=layer==2 ? 7'h39 : 0;
        obj_pxl=layer==1 ? 10'h15d : 0;
        for (scenario=0;scenario<4;scenario=scenario+1) begin
            y=scenario==0 ? 0 : scenario==3 ? 239 : scenario;
            for (x=0;x<1024;x=x+1) dut.u_ground.u_buffer.u_line.mem[x]=11'h100+(x&511)+(x>>9)*320;
            dut.u_ground.u_buffer.line=y[0];
            dut.u_vtimer.H=397;
            dut.u_vtimer.vdump=y==0 ? 279 : y-1;
            dut.u_vtimer.vrender=y;
            dut.u_vtimer.vrender1=y+1;
            dut.u_vtimer.LHBL=0;
            dut.u_vtimer.LVBL=1;
            repeat (8) @(negedge clk);
            tick();
            tick();
            for (x=0;x<320;x=x+1) begin
                tick();
                expected_addr=layer==2 ? 768+text_pxl : layer==1 ? obj_pxl[7:0] : 256+(y&1)*320+x;
                expected_rgb=color(expected_addr);
                if (!lhbl || !lvbl || {red,green,blue} !== expected_rgb)
                    $fatal(1,"video layer=%0d x=%0d y=%0d rgb=%h expected=%h blank=%b/%b",layer,x,y,{red,green,blue},expected_rgb,lhbl,lvbl);
            end
        end
    end
    $display("PASS all 320 ground columns, row banks, frame wrap and text/sprite priority");
    $finish;
end

initial begin
    #1000000;
    $fatal(1,"video test timed out");
end
endmodule
