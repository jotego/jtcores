/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-10-2026 */

`timescale 1ns/1ps
module obj_tb;
reg clk=0, rst=1;
reg [2:0] phase=0;
wire pxl_cen=phase==0;
reg [8:0] h=0,v=0;
wire [13:1] ram_addr;
reg [15:0] ram_data;
wire [8:1] ctrl_addr;
wire [19:2] rom_l_addr,rom_h_addr;
wire rom_l_cs,rom_h_cs;
wire [31:0] rom_l_data,rom_h_data;
wire rom_l_ok,rom_h_ok;
wire [9:0] pxl;
wire overflow;
reg [15:0] ram [0:8191];
reg [7:0] rom0 [0:786431],rom1 [0:786431];
reg [9:0] expected [0:76799];
reg [17:0] pending_l,pending_h;
reg active_l=0,active_h=0;
integer delay_l,delay_h,waits=0,bank=0,fd,n,frames=0,pixels=0,sample_x,sample_y;
reg [15:0] ctrl;

jtroundu_obj u_obj (
    .rst        ( rst        ),
    .clk        ( clk        ),
    .pxl_cen    ( pxl_cen    ),
    .h          ( h          ),
    .v          ( v          ),
    .ram_addr   ( ram_addr   ),
    .ram_data   ( ram_data   ),
    .ctrl_addr  ( ctrl_addr  ),
    .ctrl_data  ( ctrl       ),
    .rom_l_addr ( rom_l_addr ),
    .rom_l_cs   ( rom_l_cs   ),
    .rom_l_data ( rom_l_data ),
    .rom_l_ok   ( rom_l_ok   ),
    .rom_h_addr ( rom_h_addr ),
    .rom_h_cs   ( rom_h_cs   ),
    .rom_h_data ( rom_h_data ),
    .rom_h_ok   ( rom_h_ok   ),
    .pxl        ( pxl        ),
    .overflow   ( overflow   )
);

assign rom_l_ok = active_l && rom_l_cs && pending_l == rom_l_addr && delay_l == 0;
assign rom_h_ok = active_h && rom_h_cs && pending_h == rom_h_addr && delay_h == 0;
assign rom_l_data = rom_l_ok ? {rom0[{pending_l,2'd3}],rom0[{pending_l,2'd2}],rom0[{pending_l,2'd1}],rom0[{pending_l,2'd0}]} : 32'd0;
assign rom_h_data = rom_h_ok ? {rom1[{pending_h,2'd3}],rom1[{pending_h,2'd2}],rom1[{pending_h,2'd1}],rom1[{pending_h,2'd0}]} : 32'd0;

always #5 clk=~clk;
always @(posedge clk) begin
    phase <= phase+1'b1;
    ram_data <= ram[ram_addr];
    if (!rom_l_cs) active_l <= 0;
    else if (!active_l || pending_l != rom_l_addr) begin
        active_l <= 1;
        pending_l <= rom_l_addr;
        delay_l <= waits + rom_l_addr % 3;
    end else if (delay_l > 0) delay_l <= delay_l-1;
    if (!rom_h_cs) active_h <= 0;
    else if (!active_h || pending_h != rom_h_addr) begin
        active_h <= 1;
        pending_h <= rom_h_addr;
        delay_h <= waits + rom_h_addr % 3;
    end else if (delay_h > 0) delay_h <= delay_h-1;
    if (!rst && pxl_cen) begin
        sample_x=h;
        sample_y=v;
        h <= h==399 ? 9'd0 : h+1'b1;
        if (h==399) begin
            v <= v==271 ? 9'd0 : v+1'b1;
            if (v==271) frames=frames+1;
        end
    end
    if (!rst && phase==5 && frames>=1 && sample_x<320 && sample_y<240) begin
        if (pxl !== expected[sample_y*320+sample_x])
            $fatal(1,"sprite bank=%0d waits=%0d x=%0d y=%0d got=%03x expected=%03x state=%0d",bank,waits,sample_x,sample_y,pxl,expected[sample_y*320+sample_x],u_obj.state);
        if (overflow) $fatal(1,"sprite line deadline missed");
        pixels=pixels+1;
        if (pixels==76800) begin
            $display("PASS: 76800 sprite pixels, RAM bank=%0d, ROM waits=%0d, affine/scale/flips/repeat/CLUT/shadow/overlap",bank,waits);
            $finish;
        end
    end
end
initial begin
    n=$value$plusargs("BANK=%d",bank);
    n=$value$plusargs("WAIT=%d",waits);
    ctrl=bank ? 16'h1000 : 0;
    $readmemh("objram.hex",ram);
    $readmemh($sformatf("expected-%0d.hex",bank),expected);
    fd=$fopen("obj-rom-0.bin","rb"); n=$fread(rom0,fd); $fclose(fd);
    fd=$fopen("obj-rom-1.bin","rb"); n=$fread(rom1,fd); $fclose(fd);
    repeat(16) @(negedge clk);
    rst=0;
end
initial begin
    #20000000;
    $fatal(1,"sprite test timed out");
end
endmodule
