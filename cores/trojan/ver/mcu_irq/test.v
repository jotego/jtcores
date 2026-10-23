/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
`timescale 1ns/1ps
module test;
reg clk=0;
always #20.833 clk=~clk;
reg [1:0] div=0;
wire cen=div==0;
always @(posedge clk) div<=div+1'd1;
reg rst=1, mwr=0;
reg [11:0] prog_addr=0;
reg [7:0] prom_din=0, rom[0:1023];
reg prom_we=0;
wire [7:0] to_main,to_snd;
jttrojan_mcu #(.LATCH_INT0(1)) uut(
    .rst,.clk,.clk_rom(clk),.cen,.LVBL(1'b1),.vdump(9'd250),
    .mwr,.mrd(1'b0),.to_main,.from_main(8'hff),
    .swr(1'b0),.srd(1'b0),.to_snd,.from_snd(8'hff),
    .prog_addr,.prom_din,.prom_we
);
// 1943 shares this wrapper and keeps its original direct INT0 wiring.
jttrojan_mcu legacy(
    .rst,.clk,.clk_rom(clk),.cen,.LVBL(1'b1),.vdump(9'd250),
    .mwr,.mrd(1'b0),.to_main(),.from_main(8'hff),
    .swr(1'b0),.srd(1'b0),.to_snd(),.from_snd(8'hff),
    .prog_addr,.prom_din,.prom_we
);
integer responses=0;
reg p36l=1;
always @(posedge clk) begin
    p36l<=uut.p3_o[6];
    if(!rst && uut.p3_o[6] && !p36l) begin
        if(uut.p0_o!==8'ha5) $fatal(1,"Wrong interrupt response");
        responses=responses+1;
    end
end
integer i,phase,before_count;
initial begin
    for(i=0;i<1024;i=i+1) rom[i]=8'hff;
    // Reset: LJMP 0100. INT0: LJMP 0200.
    rom[0]=8'h02;rom[1]=8'h01;rom[2]=8'h00;
    rom[3]=8'h02;rom[4]=8'h02;rom[5]=8'h00;
    // MOV SP,#2F; MOV TCON,#01; MOV IE,#81; SJMP $.
    rom['h100]=8'h75;rom['h101]=8'h81;rom['h102]=8'h2f;
    rom['h103]=8'h75;rom['h104]=8'h88;rom['h105]=8'h01;
    rom['h106]=8'h75;rom['h107]=8'ha8;rom['h108]=8'h81;
    rom['h109]=8'h80;rom['h10a]=8'hfe;
    // CLR EA; MOV P0,#A5; CLR P3.7; SETB P3.7;
    // CLR P3.6; SETB P3.6; CLR IE0; SETB EA; RETI.
    rom['h200]=8'hc2;rom['h201]=8'haf;
    rom['h202]=8'h75;rom['h203]=8'h80;rom['h204]=8'ha5;
    rom['h205]=8'hc2;rom['h206]=8'hb7;
    rom['h207]=8'hd2;rom['h208]=8'hb7;
    rom['h209]=8'hc2;rom['h20a]=8'hb6;
    rom['h20b]=8'hd2;rom['h20c]=8'hb6;
    rom['h20d]=8'hc2;rom['h20e]=8'h89;
    rom['h20f]=8'hd2;rom['h210]=8'haf;rom['h211]=8'h32;
    for(i=0;i<1024;i=i+1) begin
        @(negedge clk);prog_addr=i;prom_din=rom[i];prom_we=1;
    end
    @(negedge clk);prom_we=0;rst=0;
    #100000;
    // Sweep all twelve MCU oscillator phases. A one-system-clock strobe
    // is shorter than a Z80 write and cannot rely on the INT0 sampling edge.
    for(phase=0;phase<12;phase=phase+1) begin
        while(!(cen && uut.u_mcu.u_mcu.u_periph.osc==phase)) @(negedge clk);
        before_count=responses;
        mwr=1;
        @(negedge clk);mwr=0;
        @(negedge clk);
        if(uut.p3_i[2]!==1'b0) $fatal(1,"Request lost before acknowledgement, phase %0d",phase);
        if(legacy.p3_i[2]!==1'b1) $fatal(1,"Default INT0 wiring changed");
        #100000;
        if(responses!=before_count+1) $fatal(1,"Expected one response at phase %0d",phase);
        if(to_main!==8'ha5 || uut.p3_i[2]!==1'b1) $fatal(1,"Response or acknowledgement failed");
    end
    // Reset also clears a pending request and both response latches.
    @(negedge clk);mwr=1;
    @(negedge clk);mwr=0;rst=1;
    repeat(4) @(negedge clk);
    if(uut.p3_i[2]!==1'b1 || to_main!==0 || to_snd!==0) $fatal(1,"Reset left a pending request");
    $display("PASS: short INT0 requests acknowledged at all twelve MCU phases");
    $finish;
end
endmodule
