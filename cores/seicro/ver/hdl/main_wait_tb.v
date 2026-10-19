/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

`timescale 1ns/1ps
module main_wait_tb;
parameter MODE=0;
reg clk=0, rst=1, h_run=0;
reg [5:0] count=0;
wire cpu_cen=count[3:0]==0;
reg [8:0] video_h=128;
reg lvbl=MODE==1 || MODE==3;
wire [15:0] addr;
wire [7:0] dout;
wire [14:0] rom_addr;
wire rom_cs, shared_we, video_we, scroll_we;
wire rom_ok=count>=20;
reg [7:0] rom[0:32767];
reg [7:0] rom_data;
reg seen_vram=0, seen_scroll=0, seen_readback=0, seen_rom_read=0;
integer i, ticks=0, held_steps=0, rom_stalls=0;
reg [15:0] held_addr;
reg [7:0] held_data;

always #5 clk=~clk;
always @(posedge clk) begin
    count<=count+6'd1;
    rom_data<=rom[rom_addr];
    if(h_run && count[2:0]==0) video_h<=video_h==511 ? 9'd128 : video_h+9'd1;
    if(!rst && rom_cs && cpu_cen && !dut.cpu_step) rom_stalls<=rom_stalls+1;
    if(video_we && addr==16'h9000 && dout==8'h5a) seen_vram<=1;
    if(scroll_we && addr==16'h9800 && dout==8'ha5) seen_scroll<=1;
    if(shared_we && addr==16'h7f00 && dout==8'h5a) seen_readback<=1;
    if(shared_we && addr==16'h7f01 && dout==8'h37) seen_rom_read<=1;
end

jtseicro_main dut(
    .rst             ( rst         ),
    .cpu_rst         ( rst         ),
    .clk             ( clk         ),
    .cpu_cen         ( cpu_cen     ),
    .dip_pause       ( 1'b1        ),
    .LVBL            ( lvbl        ),
    .irq_en          ( 1'b0        ),
    .frisky          ( MODE==3     ),
    .radial          ( MODE==1     ),
    .tecfri          ( MODE==2     ),
    .video_h         ( video_h     ),
    .cab_1p          ( 2'b11       ),
    .coin            ( 2'b11       ),
    .joystick1       ( 6'h3f       ),
    .joystick2       ( 6'h3f       ),
    .service         ( 1'b1        ),
    .dip_test        ( 1'b1        ),
    .test_dip        ( 8'hff       ),
    .cpu_addr        ( addr        ),
    .cpu_dout        ( dout        ),
    .sharedram_we    ( shared_we   ),
    .videoram_we     ( video_we    ),
    .row_scroll_we   ( scroll_we   ),
    .sharedram_dout  ( 8'd0        ),
    .videoram_dout   ( 8'h5a       ),
    .colorram_dout   ( 8'd0        ),
    .spriteram0_dout ( 8'd0        ),
    .row_scroll_dout ( 8'd0        ),
    .rom_addr        ( rom_addr    ),
    .rom_cs          ( rom_cs      ),
    .rom_data        ( rom_data    ),
    .rom_ok          ( rom_ok      ),
    .ay_data         ( 8'hff       )
);

initial begin
    for(i=0;i<32768;i=i+1) rom[i]=0;
    {rom[0],rom[1],rom[2]}=24'h31f07f;
    {rom[3],rom[4]}=16'h3e5a;
    {rom[5],rom[6],rom[7]}=24'h320090;
    {rom[8],rom[9],rom[10]}=24'h3a0090;
    {rom[11],rom[12],rom[13]}=24'h32007f;
    {rom[14],rom[15]}=16'h3ea5;
    {rom[16],rom[17],rom[18]}=24'h320098;
    {rom[19],rom[20],rom[21]}=24'h3a3412;
    {rom[22],rom[23],rom[24]}=24'h32017f;
    rom[25]=8'h76;
    rom[16'h1234]=8'h37;
    repeat(32) @(negedge clk);
    rst=0;
    wait(!dut.mreq_n && !dut.wr_n && addr==(MODE==0 ? 16'h9800 : 16'h9000));
    @(negedge clk);
    if(MODE==2) lvbl=1;
    wait(dut.wait_n===0);
    repeat(96) @(negedge clk);
    held_addr=addr;
    held_data=dout;
    repeat(160) begin
        @(negedge clk);
        if(dut.wait_n!==0 || addr!==held_addr || dout!==held_data ||
           dut.mreq_n!==0 || dut.wr_n!==0)
            $fatal(1,"WAIT bus changed mode=%0d addr=%h held=%h",MODE,addr,held_addr);
        if(dut.cpu_step) held_steps=held_steps+1;
    end
    if(held_steps<8) $fatal(1,"Board WAIT gated CPU enable: %0d",held_steps);
    video_h=132;
    h_run=1;
    wait(dut.wait_n===1);
    wait(dut.u_cpu.u_cpu.HALT_n===0);
    repeat(32) @(negedge clk);
    if(!seen_vram || !seen_scroll || !seen_readback || !seen_rom_read || rom_stalls==0)
        $fatal(1,"WAIT completion mode=%0d writes=%b%b reads=%b%b rom_stalls=%0d",
            MODE,seen_vram,seen_scroll,seen_readback,seen_rom_read,rom_stalls);
    if(dut.pal_mode!==(MODE==3 ? 2'd1 : MODE[1:0]))
        $fatal(1,"PAL selection mode=%0d selected=%0d",MODE,dut.pal_mode);
    $display("PASS Z80 WAIT mode=%0d: %0d live CPU steps held bus, H2 release, VRAM/IO writes, readback and %0d ROM stalls",MODE,held_steps,rom_stalls);
    $finish;
end

initial begin
    #2000000;
    $fatal(1,"Z80 WAIT timeout mode=%0d addr=%h wait_n=%b",MODE,addr,dut.wait_n);
end
endmodule
