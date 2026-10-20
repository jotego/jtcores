/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

`timescale 1ns/1ps
module bg_tb;
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
reg [9:0] text_scroll_y=0;
wire [16:0] bg_addr;
reg [7:0] bg_data;
reg [15:0] scroll=355;
integer local_y,local_x,bg_index;
reg [7:0] data_byte;
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
    .LANDSCAPE ( 1 ),
    .ROAD      ( 0 )
) u_video (
    .control            ( 16'd0              ),
    .bg_back_x          ( 16'd499            ),
    .bg_scroll_x        ( 16'd505            ),
    .bg_scroll_y        ( scroll             ),
    .bg_gfx_addr        ( bg_addr            ),
    .bg_gfx_data        ( bg_data            ),
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
    txmap_data <= 0;
    tx_gfx_data <= 0;
    bg_data <= gfx_byte(bg_addr);
    palette_video_data <= pal_word(palette_video_addr);
    if (!rst && pxl_cen) begin
        if (valid && pixels > 400*272) begin
            bg_index=384;
            local_y=last_v-(384-(scroll&511));
            local_x=(last_h+499)&511;
            if (local_y>=0 && local_y<128) begin
                data_byte=gfx_byte('h10000+local_y*256+local_x/2);
                pen=(data_byte>>(local_x%2*4))&15;
                if(pen!=0) bg_index='h110+pen;
            end
            local_y=last_v-(448-(scroll&511));
            local_x=(last_h+505)&511;
            if (local_y>=0 && local_y<64) begin
                data_byte=gfx_byte('h18000+local_y*256+local_x/2);
                pen=(data_byte>>(local_x%2*4))&15;
                if(pen!=0) bg_index='h100+pen;
            end
            color=pal_word(bg_index);
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
            $display("PASS: two full landscape frames, packed nibbles, both layers, priority, scroll/wrap, transparency, clipping and palette");
            $finish;
        end
    end
end
initial begin
    x=$value$plusargs("SCROLL=%d",scroll);
    repeat(16) @(negedge clk);
    rst=0;
end
endmodule
