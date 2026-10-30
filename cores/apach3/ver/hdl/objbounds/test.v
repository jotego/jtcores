/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-10-2026 */
`timescale 1ns/1ps
module test;
reg clk=0, rst=1, start=0;
always #5 clk=~clk;
reg signed [31:0] ox=0, oy=0;
reg signed [9:0] slope=0;
reg [24:0] shrink=0;
reg fx=0, fy=0;
reg [31:0] top=0, bottom=100, width=1;
wire done, reject;
wire [31:0] extent;
integer scenario, x, y, corner, hits, rejected=0;
reg signed [63:0] dx,dy,sx,sy,px,py,cx,cy,ry,miny,maxy,lo,hi,square;

jtapach3_objbounds u_bounds (
    .rst      ( rst    ),
    .clk      ( clk    ),
    .start    ( start  ),
    .origin_x ( ox     ),
    .origin_y ( oy     ),
    .slope    ( slope  ),
    .shrink   ( shrink ),
    .flip_x   ( fx     ),
    .flip_y   ( fy     ),
    .top      ( top    ),
    .bottom   ( bottom ),
    .width    ( width  ),
    .done     ( done   ),
    .reject   ( reject ),
    .extent   ( extent )
);
initial begin
    repeat (4) @(negedge clk);
    rst=0;
    for (scenario=0;scenario<40;scenario=scenario+1) begin
        ox=(scenario*137)%900-450; oy=(scenario*79)%700-350;
        slope=scenario[0] ? -48 : 48;
        fx=scenario[1]; fy=scenario[2];
        top=(scenario*11)%80; bottom=top+20+(scenario*17)%500;
        width=1;
        case (scenario)
            0: begin ox=570; oy=-20; slope=-48; fx=0; fy=0; top=0; bottom=180; end
            1: begin ox=366; oy=58; slope=-48; fx=0; fy=0; top=0; bottom=101; end
            2: begin ox=-207; oy=217; slope=-48; fx=1; fy=0; top=0; bottom=36; end
            3: begin ox=-23; oy=155; slope=-48; fx=1; fy=0; top=0; bottom=54; end
            4: begin ox=-47; oy=164; slope=-48; fx=1; fy=0; top=0; bottom=44; end
            5: begin ox=-24; oy=164; slope=-48; fx=1; fy=0; top=0; bottom=37; end
            6: begin ox=-225; oy=147; slope=-48; fx=0; fy=0; top=31; bottom=78; end
            7: begin ox=-100; oy=-100; slope=0; fx=0; fy=0; top=0; bottom=1000; width=1000; end
            8: begin ox=320; oy=0; slope=0; fx=1; fy=0; top=0; bottom=240; end
            9: begin ox=0; oy=240; slope=0; fx=0; fy=1; top=0; bottom=240; end
            10: begin ox=0; oy=0; slope=-256; fx=0; fy=0; top=0; bottom=240; end
            11: begin ox=320; oy=240; slope=255; fx=1; fy=1; top=0; bottom=240; end
            default: ;
        endcase
        square=$signed(slope); square=square*square;
        shrink=(64'd1<<40)/(64'd65536+square);
        start=1; @(negedge clk); start=0;
        while (!done) @(negedge clk);
        if (scenario<6 && !reject) $fatal(1,"missed invisible scene object %0d",scenario);
        if (scenario==7 && reject) $fatal(1,"rejected sprite enclosing viewport");
        if (reject) rejected=rejected+1;
        miny=64'sh7fffffffffffffff;maxy=-64'sh7fffffffffffffff;
        for (corner=0;corner<4;corner=corner+1) begin
            cx=corner[0] ? extent : 0; cy=corner[1] ? bottom : top;
            if (fx) cx=-cx;
            if (fy) cy=-cy;
            ry=$signed(slope)*cx+(cy<<<8);
            if (ry<miny) miny=ry;
            if (ry>maxy) maxy=ry;
        end
        lo=oy+(miny>>>8)-1;hi=oy-((-maxy)>>>8)+2;
        hits=0;
        for (y=0;y<240;y=y+1) begin
            for (x=0;x<320;x=x+1) begin
                dx=(x-$signed(ox));dx=(dx<<<16)+32768;
                dy=(y-$signed(oy));dy=(dy<<<16)+32768;
                sx=(dx+(($signed(slope)*dy)>>>8))*$signed({1'b0,shrink});
                sy=(dy-(($signed(slope)*dx)>>>8))*$signed({1'b0,shrink});
                px=sx>>>40;py=sy>>>40;
                if (fx) px=-px-1;
                if (fy) py=-py-1;
                if (px>=0 && py>=$signed(top) && py<$signed(bottom)) begin
                    hits=hits+1;
                    if (reject) $fatal(1,"false rejection scenario=%0d pixel=%0d,%0d",scenario,x,y);
                    if (px>=$signed({1'b0,extent})) $fatal(1,"repeat extent too small");
                    if (y<lo || y>=hi) $fatal(1,"cached Y bounds lose pixel");
                end
            end
        end
        if (scenario==6 && hits==0) $fatal(1,"background vector has no coverage");
    end
    $display("PASS repeat bounds: six scene rejects, visible background, enclosing sprite, flips and all viewport pixels across 40 vectors; rejected=%0d",rejected);
    $finish;
end
endmodule
