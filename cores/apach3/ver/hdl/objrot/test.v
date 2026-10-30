/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-10-2026 */
`timescale 1ns/1ps
module test;
reg clk=0, rst=1, rom_ok=0;
always #5 clk=~clk;
wire [13:1] ram_addr;
wire [8:1] ctrl_addr;
wire [20:3] rom_addr;
wire rom_cs, overflow;
wire [9:0] pxl;
reg [63:0] rom_data=0;
reg pending=0;
reg [17:0] pending_addr;
integer delay_count=0, i, j, writes=0, cycles=0, x, y, col, line, row, tile, addr, bitpos, pen;
reg wanted [0:319];
reg seen [0:319];
reg signed [59:0] sx, sy;
`ifdef WAIT7
localparam WAIT=7;
`else
localparam WAIT=0;
`endif

jtapach3_obj u_obj (
    .rst       ( rst              ),
    .clk       ( clk              ),
    .pxl_cen   ( 1'b0             ),
    .h         ( 9'd100           ),
    .v         ( 9'd16            ),
    .ram_addr  ( ram_addr         ),
    .ram_data  ( 16'hffff         ),
    .ctrl_addr ( ctrl_addr        ),
    .ctrl_data ( 16'd0            ),
    .rom_addr  ( rom_addr         ),
    .rom_cs    ( rom_cs           ),
    .rom_data  ( rom_data         ),
    .rom_ok    ( rom_ok           ),
    .pxl       ( pxl              ),
    .overflow  ( overflow         )
);
function [63:0] texture;
    input [17:0] a;
    integer k, bank, v;
    begin
        texture=0;
        for (k=0;k<16;k=k+1) begin
            bank=k/8;
            v=(a*13+bank*5+(k%8)*3)%16;
            texture[k*4+:4]=v[3:0];
        end
    end
endfunction
always @(posedge clk) begin
    rom_ok<=0;
    if (!pending && rom_cs && !rom_ok) begin
        pending<=1;
        pending_addr<=rom_addr;
        delay_count<=WAIT+rom_addr%3;
    end else if (pending) begin
        if (!rom_cs || rom_addr!==pending_addr) $fatal(1,"unstable texture request");
        if (delay_count!=0) delay_count<=delay_count-1;
        else begin
            rom_data<=texture(pending_addr);
            rom_ok<=1;
            pending<=0;
        end
    end
    if (u_obj.write_enable) begin
        if (!wanted[u_obj.write_x] || seen[u_obj.write_x] || u_obj.write_data[8:0]!==9'h135)
            $fatal(1,"unexpected pixel x=%0d data=%h",u_obj.write_x,u_obj.write_data);
        seen[u_obj.write_x]=1;
        writes=writes+1;
    end
end
always @(negedge clk)
    if (!rst && u_obj.u_pipe.count[3:0] !== (u_obj.u_pipe.wp-u_obj.u_pipe.rp))
        $fatal(1,"FIFO accounting mismatch");
initial begin
    force u_obj.clut_color=8'h35;
    sx=-(60'sd2<<<40)+(60'sd1<<<39);
    sy=(60'sd4<<<40)+(60'sd1<<<39);
    for (i=0;i<320;i=i+1) begin
        wanted[i]=0; seen[i]=0;
        x=sx>>>40; y=sy>>>40;
        if (x>=0 && y>=0 && y<512) begin
            col=x; line=y; row=line/8;
            col=col%((row%5+1)*8);
            tile=row*173+300+col/8;
            addr=((tile/2)%32768)*8+(line%8);
            bitpos=((tile%2)*8+((col%8)^3))*4;
            pen=(texture(addr)>>bitpos)&15;
            wanted[i]=pen!=0;
        end
        sx=sx+(60'sd5<<<37);
        sy=sy+(60'sd1<<<38);
    end
    repeat (5) @(negedge clk);
    rst=0;
    u_obj.loaded=1; u_obj.state=55; u_obj.drawing=1;
    u_obj.frame_valid=1; u_obj.frame_ready=1; u_obj.object_index=0;
    u_obj.draw_x=0; u_obj.last_x=319; u_obj.target_y=17;
    u_obj.attr[1]=16'h18; u_obj.attr[4]=128; u_obj.attr[5]=64;
    u_obj.scale_inverse_rom=33'h2000000; u_obj.scale_inverse=33'h2000000;
    u_obj.top_line=0; u_obj.bottom_line=512;
    u_obj.pixel_x_min=0; u_obj.pixel_x_max=2048;
    u_obj.pixel_y_min=0; u_obj.pixel_y_max=512; u_obj.repeat_line=1;
    u_obj.source_x=-(60'sd2<<<40)+(60'sd1<<<39);
    u_obj.source_y=(60'sd4<<<40)+(60'sd1<<<39);
    u_obj.step_x=60'sd5<<<37; u_obj.step_y=60'sd1<<<38;
    for (j=0;j<64;j=j+1) begin
        u_obj.u_pipe.left_ram[j]=0;
        u_obj.u_pipe.right_ram[j]=(j%5+1)*8;
        u_obj.u_pipe.base_ram[j]=j*173+300;
    end
    @(negedge clk);
    while (u_obj.state!=0 || u_obj.pipe_busy || u_obj.color_valid!=0 || u_obj.write_enable) begin
        @(negedge clk); cycles=cycles+1;
        if (cycles>20000) $fatal(1,"consumer timeout");
    end
    for (i=0;i<320;i=i+1) if (seen[i]!==wanted[i]) $fatal(1,"missing pixel %0d",i);
    if (writes<100) $fatal(1,"insufficient pixel coverage");
    $display("PASS queued rotated consumer WAIT=%0d writes=%0d cycles=%0d",WAIT,writes,cycles);
    $finish;
end
endmodule
