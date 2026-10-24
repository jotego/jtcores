/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

`timescale 1ns/1ps
module test;

reg clk=0, pxl_cen=0, hblankn=1, vblankn=1;
reg [7:0] scr_pxl=0, obj_pxl=0, pal_data=0;
reg [3:0] gfx_en=15;
wire [5:0] pal_addr;
wire [3:0] red, green, blue;
wire LHBL, LVBL;
integer checked=0;
integer bank, row, pixel;
reg [7:0] palette;
reg [5:0] expected_addr;
integer a_pixel, b_pixel, swap_palette;
reg [3:0] a_palette, b_palette, selected_palette;
reg [1:0] selected_pixel;
reg select_b, c3, c6, a1, a0;

always #5 clk=~clk;
always @(posedge clk) pal_data <= pal_addr==6'h16 ? 8'h49 : 8'hff;

jtseicro_colmix dut(
    .clk      ( clk      ),
    .pxl_cen  ( pxl_cen  ),
    .hblankn  ( hblankn  ),
    .vblankn  ( vblankn  ),
    .scr_pxl  ( scr_pxl  ),
    .obj_pxl  ( obj_pxl  ),
    .gfx_en   ( gfx_en   ),
    .pal_addr ( pal_addr ),
    .pal_data ( pal_data ),
    .red      ( red      ),
    .green    ( green    ),
    .blue     ( blue     ),
    .LHBL     ( LHBL     ),
    .LVBL     ( LVBL     )
);

task draw;
    input [7:0] scr, obj;
    input [3:0] enables;
    input hb, vb;
    input [5:0] address;
    input [11:0] rgb;
    begin
        @(negedge clk);
        scr_pxl=scr;
        obj_pxl=obj;
        gfx_en=enables;
        hblankn=hb;
        vblankn=vb;
        pxl_cen=1;
        @(negedge clk); pxl_cen=0;
        repeat(4) @(negedge clk);
        if(pal_addr!==address || {red,green,blue}!==rgb ||
            LHBL!==hb || LVBL!==vb)
            $fatal(1,"Colmix case=%0d address=%h/%h RGB=%h/%h blank=%b%b/%b%b",
                checked,pal_addr,address,{red,green,blue},rgb,LHBL,LVBL,hb,vb);
        checked=checked+1;
        repeat(3) @(negedge clk);
    end
endtask

initial begin
    repeat(8) @(negedge clk);
    draw(8'hf0,8'h70,4'hf,1,1,6'h00,12'h000);
    draw(8'h31,8'h70,4'hf,1,1,6'h0d,12'hfff);
    draw(8'h31,8'h52,4'hf,1,1,6'h16,12'h225);
    draw(8'h31,8'h52,4'h1,1,1,6'h0d,12'hfff);
    draw(8'h31,8'h52,4'h0,1,1,6'h00,12'h000);
    draw(8'h30,8'h52,4'h1,1,1,6'h00,12'h000);
    draw(8'h31,8'h52,4'h8,1,1,6'h16,12'h225);
    draw(8'h31,8'h50,4'hf,1,1,6'h0d,12'hfff);
    draw(8'h31,8'h52,4'hf,0,1,6'h16,12'h000);
    draw(8'h31,8'h52,4'hf,1,0,6'h16,12'h000);
    draw(8'h31,8'h52,4'hf,1,1,6'h16,12'h225);
    draw(8'hf0,8'h70,4'hf,1,1,6'h00,12'h000);
    for(bank=0;bank<2;bank=bank+1) begin
        for(row=0;row<8;row=row+1) begin
            palette={bank[0],row[2:0],4'b0000};
            for(pixel=1;pixel<4;pixel=pixel+1) begin
                expected_addr=bank*32+row*4+pixel;
                draw(8'h00,{palette[7:2],pixel[1:0]},4'h8,1,1,
                    expected_addr,expected_addr==6'h16 ? 12'h225 : 12'hfff);
                draw({palette[7:2],pixel[1:0]},8'h00,4'h1,1,1,
                    expected_addr,expected_addr==6'h16 ? 12'h225 : 12'hfff);
            end
        end
    end
    for(bank=0;bank<2;bank=bank+1) begin
        for(row=0;row<8;row=row+1) begin
            palette={bank[0],row[2:0],4'b0000};
            draw(8'h00,palette,4'h8,1,1,6'h00,12'h000);
            draw(palette,8'h00,4'h1,1,1,6'h00,12'h000);
        end
    end
    for(a_pixel=0;a_pixel<4;a_pixel=a_pixel+1) begin
        for(b_pixel=0;b_pixel<4;b_pixel=b_pixel+1) begin
            for(swap_palette=0;swap_palette<2;swap_palette=swap_palette+1) begin
                a_palette=swap_palette ? 4'h5 : 4'ha;
                b_palette=swap_palette ? 4'ha : 4'h5;
                a1=a_pixel[1];
                a0=a_pixel[0];
                c3=a1 | ~(~b_pixel[1] | a0);
                c6=a0 | ~(~b_pixel[0] | a1);
                select_b=~(a1 | a0);
                selected_palette=select_b ? b_palette : a_palette;
                selected_pixel={c3,c6};
                expected_addr=(selected_palette*4)+selected_pixel;
                if(selected_pixel==0) expected_addr=0;
                draw({b_palette,2'b00,b_pixel[1:0]},
                    {a_palette,2'b00,a_pixel[1:0]},4'hf,1,1,expected_addr,
                    selected_pixel==0 ? 12'h000 :
                    expected_addr==6'h16 ? 12'h225 : 12'hfff);
            end
        end
    end
    $display("PASS colmix: %0d cases, nonblack palette zero, transparent pixels, layer masks, priority, blanking and recovery",checked);
    $finish;
end

initial begin
    #100000;
    $fatal(1,"Colmix test timeout");
end

endmodule
