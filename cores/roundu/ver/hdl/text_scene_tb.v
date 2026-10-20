/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-10-2026 */

`timescale 1ns/1ps
module text_scene_tb;
reg clk=0, rst=1;
reg [2:0] phase=0;
wire pxl_cen=phase==0;
wire [13:1] txmap_addr;
wire [15:0] txmap_data;
wire [16:0] tx_gfx_addr;
wire [7:0] tx_gfx_data;
wire [10:1] palette_video_addr;
wire [15:0] palette_video_data;
wire [4:0] red,green,blue;
wire LHBL,LVBL,HS,VS;
reg [9:0] scroll [0:0];
reg [14:0] expected [0:76799];
integer last_h=0,last_v=0,pixels=0,fd;
reg valid=0;
reg [14:0] color;

jtroundu_video #(
    .OBJECTS   ( 0 ),
    .LANDSCAPE ( 0 ),
    .ROAD      ( 0 )
) u_video (
    .control            ( 16'd0              ),
    .rst                ( rst                ),
    .clk                ( clk                ),
    .pxl_cen            ( pxl_cen            ),
    .text_scroll_y      ( scroll[0]          ),
    .txmap_addr         ( txmap_addr         ),
    .txmap_data         ( txmap_data         ),
    .tx_gfx_addr        ( tx_gfx_addr        ),
    .tx_gfx_data        ( tx_gfx_data        ),
    .palette_video_addr ( palette_video_addr ),
    .palette_video_data ( palette_video_data ),
    .red                ( red                ),
    .green              ( green              ),
    .blue               ( blue               ),
    .LHBL               ( LHBL               ),
    .LVBL               ( LVBL               ),
    .HS                 ( HS                 ),
    .VS                 ( VS                 )
);

jtframe_dual_ram16 #(
    .AW      ( 13             ),
    .SIMFILE ( "videoram.bin" )
) u_map (
    .clk0  ( clk         ),
    .data0 ( 16'd0       ),
    .addr0 ( 13'd0       ),
    .we0   ( 2'd0        ),
    .q0    (             ),
    .clk1  ( clk         ),
    .data1 ( 16'd0       ),
    .addr1 ( txmap_addr  ),
    .we1   ( 2'd0        ),
    .q1    ( txmap_data  )
);

jtframe_dual_ram #(
    .AW      ( 17              ),
    .DW      ( 8               ),
    .SIMFILE ( "tx_gfxram.bin" )
) u_gfx (
    .clk0  ( clk         ),
    .data0 ( 8'd0        ),
    .addr0 ( 17'd0       ),
    .we0   ( 1'b0        ),
    .q0    (             ),
    .clk1  ( clk         ),
    .data1 ( 8'd0        ),
    .addr1 ( tx_gfx_addr ),
    .we1   ( 1'b0        ),
    .q1    ( tx_gfx_data )
);

jtframe_dual_ram16 #(
    .AW      ( 10            ),
    .SIMFILE ( "palette.bin" )
) u_palette (
    .clk0  ( clk                ),
    .data0 ( 16'd0              ),
    .addr0 ( 10'd0              ),
    .we0   ( 2'd0               ),
    .q0    (                    ),
    .clk1  ( clk                ),
    .data1 ( 16'd0              ),
    .addr1 ( palette_video_addr ),
    .we1   ( 2'd0               ),
    .q1    ( palette_video_data )
);

always #5 clk=~clk;
always @(posedge clk) begin
    phase<=phase+1'd1;
    if (!rst && pxl_cen) begin
        if (valid && pixels > 400*272) begin
            color=last_h<320 && last_v<240 ? expected[last_v*320+last_h] : 15'd0;
            #1;
            if ({red,green,blue} !== color)
                $fatal(1,"captured pixel h=%0d v=%0d actual=%h expected=%h",last_h,last_v,{red,green,blue},color);
            if (last_h<320 && last_v<240)
                $fwrite(fd,"%c%c%c",{red,red[4:2]},{green,green[4:2]},{blue,blue[4:2]});
        end
        if (!valid || pixels <= 400*272) #1;
        last_h=u_video.h==0 ? 399 : u_video.h-1;
        last_v=u_video.h==0 ? (u_video.v==0 ? 271 : u_video.v-1) : u_video.v;
        valid=1;
        pixels=pixels+1;
        if (pixels==400*272*2+1) begin
            $fclose(fd);
            $display("PASS: 76800 captured-state pixels through actual JTFRAME BRAM and text RTL");
            $finish;
        end
    end
end
initial begin
    $readmemh("scroll.hex",scroll);
    $readmemh("expected.hex",expected);
    fd=$fopen("rtl.ppm","wb");
    $fwrite(fd,"P6\n320 240\n255\n");
    repeat(16) @(negedge clk);
    rst=0;
end
endmodule
