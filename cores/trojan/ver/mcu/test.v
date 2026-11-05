/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
`timescale 1ns/1ps
module test;
reg clk=0;
always #20.833 clk=~clk;
reg [1:0] div=0;
wire cen=div==0; // 6 MHz oscillator from 24 MHz system clock
always @(posedge clk) div<=div+1'd1;
reg rst=1, mwr=0;
reg [7:0] from_main=0, from_snd=8'hff, vpos=249;
wire [7:0] to_main, to_snd;
reg [11:0] prog_addr=0;
reg [7:0] prom_din=0, rom[0:4095];
reg prom_we=0;
jttrojan_mcu #(.LATCH_INT0(1)) uut(
    .rst, .clk, .clk_rom(clk), .cen, .LVBL(1'b0), .vdump({1'b0,vpos}),
    .mwr, .mrd(1'b0), .to_main, .from_main,
    .swr(1'b0), .srd(1'b0), .to_snd, .from_snd,
    .prog_addr, .prom_din, .prom_we
);
`include "counts.vh"
integer expected_file, events_file, count=0, reads=0;
reg [7:0] expected_main, expected_sound;
reg p36l=1;
always @(posedge clk) begin
    p36l<=uut.p3_o[6];
    if(!rst && uut.p3_o[6] && !p36l) begin
        if($fscanf(expected_file,"%h %h\n",expected_main,expected_sound)!=2)
            $fatal(1,"Unexpected MCU output latch");
        if(uut.p0_o!==expected_main || uut.p2_o!==expected_sound)
            $fatal(1,"Latch %0d expected %02x/%02x got %02x/%02x, PC=%04x",
                count,expected_main,expected_sound,uut.p0_o,uut.p2_o,uut.u_mcu.u_mcu.pc);
        count=count+1;
    end
end
integer i, kind, data, scanned;
time event_time, previous_time;
initial begin
    expected_file=$fopen("expected.txt","r");
    events_file=$fopen("events.txt","r");
    if(!expected_file || !events_file) $fatal(1,"Missing prepared replay files");
    $readmemh("mcu.hex",rom);
    for(i=0;i<4096;i=i+1) begin
        @(negedge clk); prog_addr=i; prom_din=rom[i]; prom_we=1;
    end
    @(negedge clk); prom_we=0;
    repeat(5) @(negedge clk);
    rst=0;
    #1000000; // allow the MCU's real RAM-clear startup to finish
    previous_time=0;
    while(!$feof(events_file)) begin
        scanned=$fscanf(events_file,"%d %d %d\n",event_time,kind,data);
        if(scanned!=3) $fatal(1,"Malformed replay event");
        #(event_time-previous_time);
        previous_time=event_time;
        case(kind)
            1: begin from_main=data; mwr=1; end
            2: from_snd=data;
            3: begin
                if(to_main!==data[7:0])
                    $fatal(1,"Main read %0d expected %02x got %02x, PC=%04x",
                        reads,data[7:0],to_main,uut.u_mcu.u_mcu.pc);
                reads=reads+1;
            end
            4: vpos=data;
            5: mwr=0;
            6: begin end // reference output timestamp preserves MCU service time
            default: $fatal(1,"Unknown replay event %0d",kind);
        endcase
    end
    #1000000;
    if(count!=EXPECTED_COUNT) $fatal(1,"Expected %0d MCU outputs, got %0d",EXPECTED_COUNT,count);
    $display("PASS: %0d MCU latches and %0d main reads",count,reads);
    $finish;
end
endmodule
