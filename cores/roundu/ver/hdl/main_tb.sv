/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-10-2026 */

`timescale 1ns/1ps
module main_tb;
reg clk=0, rst=1;
reg cen=0;
integer accumulator=0;
wire  vblank;
wire [15:0] dsw;
wire [15:0] control;
wire  sub_irq_set;
wire [9:0] text_scroll_y;
wire [15:0] audio_addr;
wire  audio_sel;
wire  audio_rd;
wire  audio_wr;
wire [7:0] audio_din;
wire [7:0] audio_dout;
wire  audio_ok;
wire [14:1] workram_addr;
wire [15:0] workram_din;
wire [15:0] workram_dout;
wire [1:0] workram_we;
wire [13:1] videoram_addr;
wire [15:0] videoram_din;
wire [15:0] videoram_dout;
wire [1:0] videoram_we;
wire [13:1] v30_shared_addr;
wire [15:0] v30_shared_din;
wire [15:0] v30_shared_dout;
wire [1:0] v30_shared_we;
wire [10:1] palette_addr;
wire [15:0] palette_din;
wire [15:0] palette_dout;
wire [1:0] palette_we;
wire [16:0] tx_gfxram_addr;
wire [7:0] tx_gfxram_din;
wire [7:0] tx_gfxram_dout;
wire  tx_gfxram_we;
wire [16:0] bg_gfxram_addr;
wire [7:0] bg_gfxram_din;
wire [7:0] bg_gfxram_dout;
wire  bg_gfxram_we;
wire [18:1] master_rom_addr;
wire  master_rom_cs;
wire [15:0] master_rom_data;
wire  master_rom_ok;
wire [18:1] v30_slave_rom_addr;
wire  v30_slave_rom_cs;
wire [15:0] v30_slave_rom_data;
wire  v30_slave_rom_ok;
reg [7:0] image [0:2949119];
integer fd, count, age=0, slave_age=0, latency=0, reads=0, resets=0, controls=0, text_writes=0, gfx_writes=0;
integer cycle=0, cen_count=0;
assign vblank=0;
assign dsw=16'h8000;
assign audio_dout=8'hff;
assign audio_ok=1;
reg [15:0] workram [0:16383];
reg [15:0] workram_q;
assign workram_dout=workram_q;
always @(posedge clk) begin
    workram_q <= workram[workram_addr];
    if (workram_we[0]) workram[workram_addr][7:0] <= workram_din[7:0];
    if (workram_we[1]) workram[workram_addr][15:8] <= workram_din[15:8];
end
reg [15:0] videoram [0:8191];
reg [15:0] videoram_q;
assign videoram_dout=videoram_q;
always @(posedge clk) begin
    videoram_q <= videoram[videoram_addr];
    if (videoram_we[0]) videoram[videoram_addr][7:0] <= videoram_din[7:0];
    if (videoram_we[1]) videoram[videoram_addr][15:8] <= videoram_din[15:8];
end
reg [15:0] v30_shared [0:8191];
reg [15:0] v30_shared_q;
assign v30_shared_dout=v30_shared_q;
always @(posedge clk) begin
    v30_shared_q <= v30_shared[v30_shared_addr];
    if (v30_shared_we[0]) v30_shared[v30_shared_addr][7:0] <= v30_shared_din[7:0];
    if (v30_shared_we[1]) v30_shared[v30_shared_addr][15:8] <= v30_shared_din[15:8];
end
reg [15:0] palette [0:1023];
reg [15:0] palette_q;
assign palette_dout=palette_q;
always @(posedge clk) begin
    palette_q <= palette[palette_addr];
    if (palette_we[0]) palette[palette_addr][7:0] <= palette_din[7:0];
    if (palette_we[1]) palette[palette_addr][15:8] <= palette_din[15:8];
end
reg [7:0] tx_gfxram [0:131071];
reg [7:0] tx_gfxram_q;
assign tx_gfxram_dout=tx_gfxram_q;
always @(posedge clk) begin
    tx_gfxram_q <= tx_gfxram[tx_gfxram_addr];
    if (tx_gfxram_we) tx_gfxram[tx_gfxram_addr] <= tx_gfxram_din;
end
reg [7:0] bg_gfxram [0:131071];
reg [7:0] bg_gfxram_q;
assign bg_gfxram_dout=bg_gfxram_q;
always @(posedge clk) begin
    bg_gfxram_q <= bg_gfxram[bg_gfxram_addr];
    if (bg_gfxram_we) bg_gfxram[bg_gfxram_addr] <= bg_gfxram_din;
end
assign master_rom_data=!master_rom_ok ? 16'h0000 : {image[{master_rom_addr,1'b1}],image[{master_rom_addr,1'b0}]};
assign v30_slave_rom_data=!v30_slave_rom_ok ? 16'h0000 : {image['h80000+{v30_slave_rom_addr,1'b1}],image['h80000+{v30_slave_rom_addr,1'b0}]};
assign master_rom_ok=age>=latency;
assign v30_slave_rom_ok=slave_age>=latency;
always #10 clk=~clk;
always @(posedge clk) begin
    accumulator=accumulator+8000000;
    cen<=accumulator>=50318176;
    if (accumulator>=50318176) accumulator=accumulator-50318176;
    if (!master_rom_cs) age<=0;
    else age<=age+1;
    if (!v30_slave_rom_cs) slave_age<=0;
    else slave_age<=slave_age+1;
    if (!rst) begin
        cycle<=cycle+1;
        if (cen && cen_count < 80) begin
            $display("CE %0d obs=%0d ts=%0d dage=%0d prev=%b ready=%b cs=%b ok=%b addr=%h din=%h pc=%h",cen_count,u_main.u_bus.state,u_main.u_cpu.u_cpu.u_biu.r_ts,u_main.u_cpu.u_cpu.u_biu.r_dage,u_main.u_cpu.u_cpu.u_biu.r_ready_prev,u_main.ready,master_rom_cs,master_rom_ok,u_main.addr,u_main.cpu_din,u_main.u_cpu.u_cpu.u_eu.pc);
            cen_count<=cen_count+1;
        end
        if (u_main.commit) begin
            if (reads<180) $display("BUS %d addr=%h rd=%b wr=%b lane=%b in=%h out=%h pc=%04x",reads,u_main.addr,u_main.rd,u_main.wr,u_main.lane,u_main.cpu_din,u_main.cpu_dout,u_main.u_cpu.u_cpu.u_eu.pc);
            reads<=reads+1;
            if (u_main.rd && u_main.addr==20'hffff0) resets<=resets+1;
            if (u_main.wr && u_main.cs[7]) controls<=controls+1;
        end
        if (|videoram_we) text_writes<=text_writes+1;
        if (tx_gfxram_we) gfx_writes<=gfx_writes+1;
        if (cycle==400000) begin
            $display("END latency=%d bus=%d resets=%d controls=%d text=%d gfx=%d addr=%h pc=%h",latency,reads,resets,controls,text_writes,gfx_writes,u_main.addr,u_main.u_cpu.u_cpu.u_eu.pc);
            if (resets != 1 || controls < 1 || reads < 1000) $fatal(1,"V30 early startup failed");
            $finish;
        end
    end
end
initial begin
    count=$value$plusargs("latency=%d",latency);
    fd=$fopen("../../../../rom/roundup5.rom","rb");
    count=$fread(image,fd);
    $fclose(fd);
    if (count!=2949120) $fatal(1,"missing validated ROM");
    repeat(64) @(negedge clk);
    rst=0;
end
jtroundu_main u_main (
    .rst                ( rst                ),
    .clk                ( clk                ),
    .cen                ( cen                ),
    .vblank             ( vblank             ),
    .dsw                ( dsw                ),
    .control            ( control            ),
    .sub_irq_set        ( sub_irq_set        ),
    .text_scroll_y      ( text_scroll_y      ),
    .audio_addr         ( audio_addr         ),
    .audio_sel          ( audio_sel          ),
    .audio_rd           ( audio_rd           ),
    .audio_wr           ( audio_wr           ),
    .audio_din          ( audio_din          ),
    .audio_dout         ( audio_dout         ),
    .audio_ok           ( audio_ok           ),
    .workram_addr       ( workram_addr       ),
    .workram_din        ( workram_din        ),
    .workram_dout       ( workram_dout       ),
    .workram_we         ( workram_we         ),
    .videoram_addr      ( videoram_addr      ),
    .videoram_din       ( videoram_din       ),
    .videoram_dout      ( videoram_dout      ),
    .videoram_we        ( videoram_we        ),
    .v30_shared_addr    ( v30_shared_addr    ),
    .v30_shared_din     ( v30_shared_din     ),
    .v30_shared_dout    ( v30_shared_dout    ),
    .v30_shared_we      ( v30_shared_we      ),
    .palette_addr       ( palette_addr       ),
    .palette_din        ( palette_din        ),
    .palette_dout       ( palette_dout       ),
    .palette_we         ( palette_we         ),
    .tx_gfxram_addr     ( tx_gfxram_addr     ),
    .tx_gfxram_din      ( tx_gfxram_din      ),
    .tx_gfxram_dout     ( tx_gfxram_dout     ),
    .tx_gfxram_we       ( tx_gfxram_we       ),
    .bg_gfxram_addr     ( bg_gfxram_addr     ),
    .bg_gfxram_din      ( bg_gfxram_din      ),
    .bg_gfxram_dout     ( bg_gfxram_dout     ),
    .bg_gfxram_we       ( bg_gfxram_we       ),
    .master_rom_addr    ( master_rom_addr    ),
    .master_rom_cs      ( master_rom_cs      ),
    .master_rom_data    ( master_rom_data    ),
    .master_rom_ok      ( master_rom_ok      ),
    .v30_slave_rom_addr ( v30_slave_rom_addr ),
    .v30_slave_rom_cs   ( v30_slave_rom_cs   ),
    .v30_slave_rom_data ( v30_slave_rom_data ),
    .v30_slave_rom_ok   ( v30_slave_rom_ok   )
);
endmodule
