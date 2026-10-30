/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */

`timescale 1ns/1ps
module test;
reg clk=0, rst=1;
always #5 clk=~clk;
reg [14:0] cpu_addr=0, video_addr=0;
reg [15:0] cpu_din=0;
reg [1:0] cpu_dsn=0;
reg cpu_cs=0, cpu_we=0, video_cs=0;
wire [15:0] cpu_dout, video_dout;
wire cpu_ok, video_ok, initialized;
wire [14:0] ram_addr;
wire [15:0] ram_din, ram_dout;
wire [1:0] ram_dsn;
wire ram_cs, ram_we, ram_ok;
wire [21:0] sdram_addr;
wire [15:0] sdram_din;
wire [1:0] sdram_dsn;
wire rd, wr, hold_rst;
reg ack=0, dst=0, rdy=0;
reg [15:0] data=0;
reg [15:0] memory [0:32767];
reg pending=0, seen=0, pending_write=0;
reg [14:0] saved_addr;
reg [15:0] saved_data;
reg [1:0] saved_mask;
integer delay_count=0, writes=0, i, j;
`ifdef WAIT7
localparam WAIT=7;
`else
localparam WAIT=0;
`endif

jtapach3_groundbus #(
`ifdef SCENE
    .INIT ( 0 )
`else
    .INIT ( 1 )
`endif
) u_arb (
    .rst        ( rst             ),
    .clk        ( clk             ),
    .initialized ( initialized     ),
    .cpu_addr   ( cpu_addr        ),
    .cpu_din    ( cpu_din         ),
    .cpu_dsn    ( cpu_dsn         ),
    .cpu_cs     ( cpu_cs          ),
    .cpu_we     ( cpu_we          ),
    .cpu_dout   ( cpu_dout        ),
    .cpu_ok     ( cpu_ok          ),
    .video_addr ( video_addr      ),
    .video_cs   ( video_cs        ),
    .video_dout ( video_dout      ),
    .video_ok   ( video_ok        ),
    .ram_addr   ( ram_addr        ),
    .ram_din    ( ram_din         ),
    .ram_dsn    ( ram_dsn         ),
    .ram_cs     ( ram_cs          ),
    .ram_we     ( ram_we          ),
    .ram_dout   ( ram_dout        ),
    .ram_ok     ( ram_ok          )
);

jtframe_ram1_1slot #(
    .SDRAMW      ( 22 ),
    .SLOT0_AW    ( 15 ),
    .SLOT0_DW    ( 16 ),
    .SLOT0_ERASE (  0 )
) u_bank (
    .rst          ( rst        ),
    .clk          ( clk        ),
    .slot0_addr   ( ram_addr   ),
    .slot0_dout   ( ram_dout   ),
    .slot0_din    ( ram_din    ),
    .slot0_offset ( 22'd0      ),
    .slot0_cs     ( ram_cs     ),
    .slot0_ok     ( ram_ok     ),
    .slot0_wen    ( ram_we     ),
    .slot0_wrmask ( ram_dsn    ),
    .hold_rst     ( hold_rst   ),
    .sdram_ack    ( ack        ),
    .sdram_rd     ( rd         ),
    .sdram_wr     ( wr         ),
    .sdram_addr   ( sdram_addr ),
    .data_rdy     ( rdy        ),
    .data_dst     ( dst        ),
    .data_read    ( data       ),
    .data_write   ( sdram_din  ),
    .sdram_wrmask ( sdram_dsn  )
);

always @(posedge clk) begin
    ack <= 0;
    dst <= 0;
    rdy <= 0;
    if (rst) begin
        pending <= 0;
        seen <= 0;
    end else begin
        if (!rd && !wr) seen <= 0;
        if (!pending && !seen && (rd || wr)) begin
            if (sdram_addr >= 32768) $fatal(1,"ground address out of range");
            pending <= 1;
            seen <= 1;
            ack <= 1;
            saved_addr <= sdram_addr[14:0];
            saved_data <= sdram_din;
            saved_mask <= sdram_dsn;
            pending_write <= wr;
            delay_count <= WAIT + sdram_addr % 3;
            if (wr) writes <= writes + 1;
        end else if (pending) begin
            if (delay_count != 0) delay_count <= delay_count - 1;
            else begin
                if (pending_write) begin
                    if (!saved_mask[0]) memory[saved_addr][7:0] <= saved_data[7:0];
                    if (!saved_mask[1]) memory[saved_addr][15:8] <= saved_data[15:8];
                end
                data <= memory[saved_addr];
                dst <= 1;
                rdy <= 1;
                pending <= 0;
            end
        end
    end
end

task access_cpu;
    input [14:0] address;
    input writing;
    input [15:0] value;
    input [1:0] mask;
    begin
        @(negedge clk);
        cpu_addr=address; cpu_din=value; cpu_dsn=mask; cpu_we=writing; cpu_cs=1;
        while (!cpu_ok) @(negedge clk);
        if (!writing && cpu_dout !== value) $fatal(1,"CPU %h got %h expected %h",address,cpu_dout,value);
        repeat (3) @(negedge clk);
        cpu_cs=0; cpu_we=0;
        repeat (2) @(negedge clk);
    end
endtask

task access_video;
    input [14:0] address;
    input [15:0] value;
    begin
        @(negedge clk);
        video_addr=address; video_cs=1;
        while (!video_ok) @(negedge clk);
        if (video_dout !== value) $fatal(1,"video %h got %h expected %h",address,video_dout,value);
        repeat (3) @(negedge clk);
        video_cs=0;
        repeat (2) @(negedge clk);
    end
endtask

initial begin
    for (i=0;i<32768;i=i+1) memory[i]=16'ha55a;
    repeat (5) @(negedge clk);
    rst=0;
    while (!initialized || pending || rd || wr) @(negedge clk);
    repeat (4) @(negedge clk);
`ifdef SCENE
    for (i=0;i<32768;i=i+1)
        if (memory[i] !== 16'ha55a) $fatal(1,"scene memory changed at %h",i);
    if (writes != 0) $fatal(1,"scene reset wrote ground RAM");
    access_video(0,16'ha55a);
    access_video(15'h7fff,16'ha55a);
    $display("PASS scene ground memory preserved");
    $finish;
`else
    for (i=0;i<32768;i=i+1)
        if (memory[i] !== 0) $fatal(1,"erase %h got %h",i,memory[i]);
    if (writes != 32768) $fatal(1,"erase wrote %0d words",writes);
    access_cpu(0,1,16'h1234,0);
    access_cpu(0,1,16'h00ab,2'b10);
    access_cpu(0,1,16'hcd00,2'b01);
    access_video(0,16'hcdab);
    access_cpu(15'h7fff,1,16'hbeef,0);
    access_video(15'h7fff,16'hbeef);
    fork
        begin
            for (i=0;i<64;i=i+1) access_cpu(i+100,1,i+16'h5000,0);
        end
        begin
            for (j=0;j<64;j=j+1) access_video(0,16'hcdab);
        end
    join
    for (i=0;i<64;i=i+1) access_video(i+100,i+16'h5000);
    if (writes != 32836) $fatal(1,"lost or repeated writes: %0d",writes);
    $display("PASS ground bus wait=%0d, erase, byte lanes, contention and coherent reads",WAIT);
`endif
    $finish;
end

initial begin
    #20000000;
    $fatal(1,"ground bus test timed out");
end
endmodule
