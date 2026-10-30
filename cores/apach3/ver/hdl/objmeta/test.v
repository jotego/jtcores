/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-10-2026 */
`timescale 1ns/1ps
module test;
reg clk=0, rst=1, rom_ok=0, pending=0;
always #5 clk=~clk;
wire [13:1] ram_addr;
wire [8:1] ctrl_addr;
wire [20:3] rom_addr;
wire rom_cs, overflow;
wire [9:0] pxl;
reg [63:0] rom_data=0;
reg [17:0] held;
integer i, j, cycles, reads=0, previous_reads, wait_count;
reg [207:0] frame_word;
jtapach3_obj u_obj (
    .rst       ( rst              ),
    .clk       ( clk              ),
    .pxl_cen   ( 1'b0             ),
    .h         ( 9'd100           ),
    .v         ( 9'd250           ),
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
always @(posedge clk) begin
    rom_ok<=0;
    if (!pending && rom_cs && !rom_ok) begin
        held<=rom_addr; pending<=1; wait_count<=3; reads<=reads+1;
    end else if (pending) begin
        if (!rom_cs || rom_addr!==held) $fatal(1,"metadata request changed");
        if (wait_count!=0) wait_count<=wait_count-1;
        else begin
            rom_data<=held[3:0]==0 ? 64'h12340003_00100000 : 64'h00000000_56780104;
            rom_ok<=1; pending<=0;
        end
    end
end
task walk;
    input [15:0] index;
    begin
        u_obj.loaded=1; u_obj.state=22; u_obj.frame_ready=0;
        u_obj.object_count=1; u_obj.walk_index=0;
        u_obj.walk_valid=0; u_obj.object_width=0; u_obj.object_left=4095;
        u_obj.attr[0]=index; u_obj.attr[1]=0; u_obj.attr[2]=0; u_obj.attr[3]=0;
        u_obj.attr[4]=128; u_obj.attr[5]=16'h1d0;
        @(negedge clk); cycles=0;
        while (!u_obj.frame_ready) begin
            @(negedge clk); cycles=cycles+1;
            if (cycles>200) $fatal(1,"metadata walk timeout");
        end
        repeat (3) @(negedge clk);
        frame_word=u_obj.u_frame_list.u_ram.mem[0];
    end
endtask
initial begin
    repeat (5) @(negedge clk); rst=0;
    for (i=0;i<35;i=i+1) begin
        walk((i+1)*16);
        if (frame_word[180:176] !== (i<31 ? i+1 : 0)) $fatal(1,"descriptor-page allocation %0d",i);
        if (i<31) begin
            j=(i+1)*64;
            if (u_obj.u_pipe.left_ram[j]!==0 || u_obj.u_pipe.right_ram[j]!==32 || u_obj.u_pipe.base_ram[j]!==18'h2468)
                $fatal(1,"even-bank descriptor packing");
            if (u_obj.u_pipe.left_ram[j+1]!==8 || u_obj.u_pipe.right_ram[j+1]!==48 || u_obj.u_pipe.base_ram[j+1]!==18'hacf0)
                $fatal(1,"odd-bank descriptor packing");
        end
    end
    previous_reads=reads;
    walk(160);
    if (frame_word[180:176]!==5'd10 || frame_word[156:144]!==13'd48 || frame_word[171:160]!==0)
        $fatal(1,"shared descriptor geometry lost");
    if (reads-previous_reads!=1) $fatal(1,"cached descriptors fetched again");
    u_obj.launch_pending=1; u_obj.launch_v=240;
    @(negedge clk);
    if (u_obj.page_valid!==0 || u_obj.page_count!==0) $fatal(1,"new frame retained stale page assignments");
    $display("PASS shared descriptor pages: 31 allocations, overflow fallback, ROM-bank packing, reuse and frame reset");
    $finish;
end
endmodule
