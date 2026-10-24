/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 24-10-2026 */

`timescale 1ns/1ps
module test;
reg clk=0, rst=1;
always #5 clk=~clk;
reg [16:0] cpu_addr=0, gfx_addr=0;
reg [7:0] cpu_din=0;
reg cpu_cs=0, cpu_we=0, gfx_cs=0;
wire [7:0] cpu_dout, gfx_data;
wire cpu_ok, gfx_ok;
integer waits=0, i, j, expected_writes=0;
reg [16:0] address;
reg [7:0] expected [0:131071];

jtroundu_txram_model #(
    .ERASE (
`ifdef TXERASE
        1
`else
        0
`endif
    )
) u_mem (
    .rst      ( rst      ),
    .clk      ( clk      ),
    .cpu_addr ( cpu_addr ),
    .cpu_din  ( cpu_din  ),
    .cpu_dout ( cpu_dout ),
    .cpu_cs   ( cpu_cs   ),
    .cpu_we   ( cpu_we   ),
    .cpu_ok   ( cpu_ok   ),
    .gfx_addr ( gfx_addr ),
    .gfx_cs   ( gfx_cs   ),
    .gfx_data ( gfx_data ),
    .gfx_ok   ( gfx_ok   ),
    .waits    ( waits    )
);

task cpu_access;
    input [16:0] addr;
    input writing;
    input [7:0] value;
    begin
        @(negedge clk);
        cpu_addr=addr; cpu_din=value; cpu_we=writing; cpu_cs=1;
        while (!cpu_ok) @(negedge clk);
        if (writing) begin
            expected[addr]=value;
            expected_writes=expected_writes+1;
        end else if (cpu_dout !== expected[addr])
            $fatal(1,"CPU read %h got=%h expected=%h",addr,cpu_dout,expected[addr]);
        repeat(5) @(negedge clk);
        cpu_cs=0; cpu_we=0;
        repeat(2) @(negedge clk);
    end
endtask

task video_read;
    input [16:0] addr;
    begin
        @(negedge clk);
        gfx_addr=addr; gfx_cs=1;
        while (!gfx_ok) @(negedge clk);
        if (gfx_data !== expected[addr])
            $fatal(1,"video read %h got=%h expected=%h",addr,gfx_data,expected[addr]);
        gfx_cs=0;
        repeat(2) @(negedge clk);
    end
endtask

initial begin
`ifdef TXWAIT12
    waits=12;
`elsif TXWAIT3
    waits=3;
`endif
    for (i=0;i<131072;i=i+1) expected[i]=(i*37+(i>>8))&255;
    repeat(8) @(negedge clk);
    rst=0;
`ifdef TXERASE
    while (u_mem.hold_rst || u_mem.pending || u_mem.rd || u_mem.wr) @(negedge clk);
    repeat(4) @(negedge clk);
    for (i=0;i<65536;i=i+1)
        if (u_mem.mem[i] !== 16'd0) $fatal(1,"reset clear left poisoned word %h=%h",i,u_mem.mem[i]);
    for (i=0;i<131072;i=i+1) expected[i]=0;
    expected_writes=65536;
`endif
    for (i=0;i<64;i=i+1) begin
        address=(i*2081)&17'h1ffff;
        cpu_access(address,1,i[7:0]^8'ha5);
        cpu_access(address,0,0);
        cpu_access(address^17'd1,0,0);
        video_read(address);
        video_read(address^17'd1);
    end
    cpu_access(17'h00000,1,8'h12);
    cpu_access(17'h00001,1,8'h34);
    cpu_access(17'h1fffe,1,8'h56);
    cpu_access(17'h1ffff,1,8'h78);
    video_read(17'h00000); video_read(17'h00001);
    video_read(17'h1fffe); video_read(17'h1ffff);
    fork
        begin
            for (i=0;i<32;i=i+1) cpu_access(17'h10000+{12'd0,i[4:0]},1,i[7:0]);
        end
        begin
            for (j=0;j<96;j=j+1) video_read((j*1025)&17'h0ffff);
        end
    join
    for (i=0;i<32;i=i+1) video_read(17'h10000+{12'd0,i[4:0]});
    if (u_mem.writes != expected_writes) $fatal(1,"duplicated or lost CPU writes");
    $display("PASS txram WAIT=%0d writes=%0d transactions=%0d: byte masks, boundaries, coherent video and contending CPU",waits,u_mem.writes,u_mem.transactions);
    $finish;
end

initial begin
    #50000000;
    $fatal(1,"text RAM test timed out");
end
endmodule
