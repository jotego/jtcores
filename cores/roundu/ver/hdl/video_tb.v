/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

`timescale 1ns/1ps
module video_tb;
reg clk=0, rst=1;
reg [2:0] phase=0;
wire pxl_cen = phase == 0;
wire [13:1] txmap_addr;
reg [15:0] txmap_data;
wire [16:0] tx_gfx_addr;
reg [7:0] tx_gfx_data;
wire [10:1] palette_video_addr;
reg [15:0] palette_video_data;
wire [4:0] red, green, blue;
wire LHBL, LVBL, HS, VS;
reg [9:0] text_scroll_y=10'h1ab;
integer last_h=0, last_v=0;
integer pixels=0;
reg valid=0;
integer x,y,tile,attr,index,pen;
reg [7:0] b0,b1,b2;
reg [15:0] color;

function [15:0] tile_word(input integer a);
    tile_word = ((a*37+19)&4095) | (((a*5+3)&15)<<12);
endfunction
function [7:0] gfx_byte(input integer a);
    gfx_byte = (a*73) ^ (a>>8) ^ (a>>13) ^ 8'h96;
endfunction
function [15:0] pal_word(input integer a);
    pal_word = ((a*197) ^ (a<<9) ^ 16'h5a39) & 16'h7fff;
endfunction

jtroundu_video #(
    .OBJECTS   ( 0 ),
    .LANDSCAPE ( 0 ),
    .ROAD      ( 0 )
) u_video (
    .control            ( 16'd0              ),
    .rst                ( rst                ),
    .clk                ( clk                ),
    .pxl_cen            ( pxl_cen            ),
    .text_scroll_y      ( text_scroll_y      ),
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

always #5 clk=~clk;
always @(posedge clk) begin
    phase <= phase+1'd1;
    txmap_data <= tile_word(txmap_addr);
    tx_gfx_data <= gfx_byte(tx_gfx_addr);
    palette_video_data <= pal_word(palette_video_addr);
    if (!rst && pxl_cen) begin
        if (valid && pixels > 400*272) begin
            x=(last_h+24)%1024;
            y=(last_v+text_scroll_y)%512;
            attr=tile_word((y/8)*128+x/8);
            tile=attr&4095;
            index=tile*8+(y%8);
            b0=gfx_byte(index);
            b1=gfx_byte(index+'h8000);
            b2=gfx_byte(index+'h10000);
            pen=(b0>>(7-x%8)&1) | ((b1>>(7-x%8)&1)<<1) | ((b2>>(7-x%8)&1)<<2);
            color=pal_word(pen == 0 ? 384 : (attr>>12)*8+pen);
            if (last_h>=320 || last_v>=240) color=0;
            #1;
            if ({red,green,blue} !== color[14:0])
                $fatal(1,"pixel h=%0d v=%0d got=%h expected=%h",last_h,last_v,{red,green,blue},color);
            if (LHBL !== (last_h<320) || LVBL !== (last_v<240)
                || HS !== !(last_h>=336 && last_h<368) || VS !== !(last_v>=244 && last_v<248))
                $fatal(1,"video timing mismatch");
        end
        if (!valid || pixels <= 400*272) #1;
        last_h=u_video.h == 0 ? 399 : u_video.h-1;
        last_v=u_video.h == 0 ? (u_video.v == 0 ? 271 : u_video.v-1) : u_video.v;
        valid=1;
        pixels=pixels+1;
        if (pixels==400*272*3) begin
            $display("PASS: two full text frames, 320x240 active, scroll/wrap/planes/palette/blanking");
            $finish;
        end
    end
end
initial begin
    repeat(16) @(negedge clk);
    rst=0;
end
endmodule
