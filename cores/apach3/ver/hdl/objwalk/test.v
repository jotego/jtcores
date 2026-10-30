/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-10-2026 */
`timescale 1ns/1ps
module test;
reg clk=0, rst=1;
always #5 clk=~clk;
wire [13:1] ram_addr;
wire [8:1] ctrl_addr;
wire [20:3] rom_addr;
wire rom_cs, overflow;
wire [9:0] pxl;
integer scenario, cycles, x, y, source_line;
reg signed [63:0] dx, dy, sx, sy, px, py, sh;
reg [207:0] cached;

jtapach3_obj u_obj (
    .rst       ( rst       ),
    .clk       ( clk       ),
    .pxl_cen   ( 1'b0      ),
    .h         ( 9'd100    ),
    .v         ( 9'd250    ),
    .ram_addr  ( ram_addr  ),
    .ram_data  ( 16'd0     ),
    .ctrl_addr ( ctrl_addr ),
    .ctrl_data ( 16'd0     ),
    .rom_addr  ( rom_addr  ),
    .rom_cs    ( rom_cs    ),
    .rom_data  ( 64'd0     ),
    .rom_ok    ( 1'b0      ),
    .pxl       ( pxl       ),
    .overflow  ( overflow  )
);
initial begin
    for (scenario=0;scenario<8;scenario=scenario+1) begin
        rst=1; repeat (5) @(negedge clk); rst=0;
        u_obj.state=25;
        u_obj.walk_index=0;
        u_obj.object_count=1;
        u_obj.frame_ready=0;
        u_obj.walk_valid=1;
        u_obj.repeat_line=1;
        u_obj.top_line=0;
        u_obj.bottom_line=192;
        u_obj.object_width=48;
        u_obj.attr[0]=1;
        u_obj.attr[1]=0;
        u_obj.attr[4]=128;
        u_obj.attr[5]=9'h1d0;
        case (scenario)
            0: begin u_obj.attr[2]=570; u_obj.attr[3]=-20; end
            1: begin u_obj.attr[2]=366; u_obj.attr[3]=58; end
            2: begin u_obj.attr[2]=-207; u_obj.attr[3]=217; u_obj.attr[1]=16'h8000; u_obj.attr[5]=48; end
            3: begin u_obj.attr[2]=-23; u_obj.attr[3]=155; u_obj.attr[1]=16'h8000; u_obj.attr[5]=48; end
            4: begin u_obj.attr[2]=-47; u_obj.attr[3]=164; u_obj.attr[1]=16'h8000; u_obj.attr[5]=48; end
            5: begin u_obj.attr[2]=-24; u_obj.attr[3]=164; u_obj.attr[1]=16'h8000; u_obj.attr[5]=48; end
            6: begin u_obj.attr[2]=-225; u_obj.attr[3]=147; u_obj.attr[4]=124; u_obj.top_line=32; u_obj.bottom_line=80; end
            7: begin u_obj.attr[2]=-100; u_obj.attr[3]=-100; u_obj.attr[5]=0; u_obj.object_width=1000; u_obj.bottom_line=512; end
        endcase
        cycles=0;
        while (!u_obj.frame_ready) begin
            @(negedge clk); cycles=cycles+1;
            if (cycles>100) $fatal(1,"vblank bounds did not complete");
        end
        repeat (2) @(negedge clk);
        cached=u_obj.u_frame_list.u_ram.mem[0];
        sh=(64'sd1<<<40)/(65536+$signed(u_obj.slope)*$signed(u_obj.slope));
        for (y=0;y<240;y=y+1) for (x=0;x<320;x=x+1) begin
            dx=x-$signed(u_obj.attr[2]); dx=(dx<<<16)+32768;
            dy=y-$signed(u_obj.attr[3]); dy=(dy<<<16)+32768;
            sx=(dx+(($signed(u_obj.slope)*dy)>>>8))*sh;
            sy=(dy-(($signed(u_obj.slope)*dx)>>>8))*sh;
            px=sx>>>40; py=sy>>>40;
            if (u_obj.flip_x) px=-px-1;
            if (u_obj.flip_y) py=-py-1;
            source_line=(py*128)/u_obj.attr[4][8:0];
            if (px>=0 && py>=0 && source_line>=u_obj.top_line && source_line<u_obj.bottom_line)
                if (x<cached[190:182] || x>cached[199:191] || y<cached[135:128] || y>=cached[143:136])
                    $fatal(1,"cached XY bounds lost scenario=%0d x=%0d y=%0d",scenario,x,y);
        end
        if (scenario<6 && cached[143:128]!==16'd0) $fatal(1,"invisible repeat cached as visible");
        if (scenario>=6 && cached[143:136]<=cached[135:128]) $fatal(1,"visible repeat lost");
        if (scenario==6 && cached[143:136]>=240) $fatal(1,"repeat Y bounds not tightened");
        if (scenario==7 && cached[143:128]!=={8'd240,8'd0}) $fatal(1,"enclosing sprite clipped");
    end
    $display("PASS vblank frame-list integration: invisible repeats cached empty, background retained, Y bounds tightened, enclosing repeat retained");
    $finish;
end
endmodule
