/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
`timescale 1ns/1ps

module test;
reg clk=0, rst=1, tigerh=0, snd_cen=0;
reg [5:0] joystick1=6'h3f, joystick2=6'h3f;
reg previous_nmi;
integer i, falling;
always #5 clk=~clk;
jtslap_sound uut(
    .rst(rst), .clk(clk), .snd_cen(snd_cen), .free_cen(1'b1),
    .psg_cen(1'b0), .sound_en(1'b1), .tigerh(tigerh),
    .sha_cs(1'b0), .sha_ok(), .ram_addr(), .ram_dout(),
    .ram_data(8'd0), .ram_we(), .snd_addr(), .snd_cs(),
    .snd_data(8'd0), .snd_ok(1'b1), .dipsw(16'hffff),
    .joystick1(joystick1), .joystick2(joystick2), .cab_1p(2'b11),
    .coin(2'b11), .psg1(), .psg2()
);
task check;
    input condition;
    input [511:0] message;
    begin
        if(!condition) begin $display("FAIL: %s",message); $finish; end
    end
endtask
task divider;
    input mode;
    input integer expected;
    begin
        rst=1; tigerh=mode;
        repeat(4) @(negedge clk);
        rst=0;
        repeat(2) @(negedge clk);
        force uut.nmi_en=1;
        previous_nmi=uut.nmi_n; falling=0;
        for(i=0;i<32768;i=i+1) begin
            @(negedge clk);
            if(previous_nmi && !uut.nmi_n) falling=falling+1;
            previous_nmi=uut.nmi_n;
        end
        check(falling==expected,"sound NMI divider period");
        force uut.nmi_en=0;
        repeat(3) @(negedge clk);
        check(uut.nmi_count==0 && uut.nmi_n,"disabled sound NMI resets divider");
        release uut.nmi_en;
    end
endtask
initial begin
    $dumpfile("test.lxt"); $dumpvars;
    repeat(4) @(negedge clk);
    joystick1[4]=0; #1;
    check(uut.buttons==8'hfd,"Slap Fight P1 Fire wiring");
    tigerh=1; #1;
    check(uut.buttons==8'hfe,"Tiger-Heli P1 Fire wiring");
    joystick1=6'h1f; #1;
    check(uut.buttons==8'hfd,"Tiger-Heli P1 Bomb wiring");
    joystick1=6'h3f; joystick2[4]=0; #1;
    check(uut.buttons==8'hfb,"Tiger-Heli P2 Fire wiring");
    joystick2=6'h1f; #1;
    check(uut.buttons==8'hf7,"Tiger-Heli P2 Bomb wiring");
    joystick2=6'h3f;
    joystick1=6'h3e; #1; check(uut.directions==8'hfe,"P1 Up wiring");
    joystick1=6'h3d; #1; check(uut.directions==8'hfd,"P1 Down wiring");
    joystick1=6'h3b; #1; check(uut.directions==8'hfb,"P1 Right wiring");
    joystick1=6'h37; #1; check(uut.directions==8'hf7,"P1 Left wiring");
    joystick1=6'h3f;
    joystick2=6'h3e; #1; check(uut.directions==8'hef,"P2 Up wiring");
    joystick2=6'h3d; #1; check(uut.directions==8'hdf,"P2 Down wiring");
    joystick2=6'h3b; #1; check(uut.directions==8'hbf,"P2 Right wiring");
    joystick2=6'h37; #1; check(uut.directions==8'h7f,"P2 Left wiring");
    joystick2=6'h3f;
    force uut.mreq_n=0; force uut.rfsh_n=1;
    force uut.cpu_addr=16'hc000; #1;
    check(uut.ram_cs && uut.ram_addr==0,"sound RAM at C000");
    force uut.cpu_addr=16'hc800; #1;
    check(uut.ram_cs && uut.ram_addr==0,"sound RAM C800 alias");
    force uut.cpu_addr=16'hd000; #1;
    check(uut.ram_cs && uut.ram_addr==0,"sound RAM D000 alias");
    force uut.cpu_addr=16'hdfff; #1;
    check(uut.ram_cs && uut.ram_addr==11'h7ff,"sound RAM DFFF alias");
    force uut.cpu_addr=16'he000; #1;
    check(!uut.ram_cs,"sound RAM ends at DFFF");
    release uut.cpu_addr; release uut.mreq_n; release uut.rfsh_n;
    divider(0,2); divider(1,4);
    rst=1; repeat(4) @(negedge clk); rst=0;
    repeat(2) @(negedge clk);
    force uut.cpu_addr=16'ha0f0;
    force uut.mreq_n=0; force uut.rfsh_n=1; force uut.wr_n=0;
    snd_cen=1; repeat(2) @(negedge clk); snd_cen=0;
    check(uut.nmi_en,"A0F0 starts the sound timer");
    force uut.cpu_addr=16'ha0e0;
    snd_cen=1; repeat(2) @(negedge clk); snd_cen=0;
    check(uut.nmi_en,"A0E0 keeps sound timer enabled");
    // Repeated ISR writes while the divider output is high must not create
    // a new NMI edge or reset its phase (Tiger-Heli's real handler does this).
    force uut.wr_n=1;
    repeat(4096) @(negedge clk);
    check(!uut.nmi_n,"first Tiger-Heli timer assertion");
    force uut.wr_n=0; force uut.cpu_addr=16'ha0f0;
    snd_cen=1; repeat(2) @(negedge clk); snd_cen=0;
    check(!uut.nmi_n,"A0F0 does not mask an asserted divider output");
    force uut.cpu_addr=16'ha0e0;
    snd_cen=1; repeat(2) @(negedge clk); snd_cen=0;
    check(!uut.nmi_n,"A0E0 does not retrigger the NMI");
    release uut.cpu_addr; release uut.mreq_n; release uut.rfsh_n; release uut.wr_n;
    $display("PASS: both players' directions/buttons, RAM aliases and timer control/periods");
    $finish;
end
initial begin #1000000; $display("FAIL: timeout"); $finish; end
endmodule
