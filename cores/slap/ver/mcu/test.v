/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-10-2026 */
`timescale 1ns/1ps
module test;
reg clk=0, rst=1, host_wr=0, host_rd=0;
reg tigerh=0;
reg [7:0] host_dout=0;
wire [7:0] host_din, rom_data, slap_rom, tiger_rom;
wire [10:0] rom_addr;
wire ibf, obf, cen;
reg [3:0] divider=0;
assign cen=divider==0;
assign rom_data=tigerh ? tiger_rom : slap_rom;
always @(posedge clk) divider<=divider+4'd1;
integer cycles;
always #5 clk=~clk;
jtslap_mcu uut(
    .rst(rst), .clk(clk), .cen(cen), .tigerh(tigerh),
    .host_wr(host_wr), .host_rd(host_rd), .host_dout(host_dout),
    .host_din(host_din), .ibf(ibf), .obf(obf),
    .flip(), .scroll_data(), .scroll_wr(),
    .rom_addr(rom_addr), .rom_data(rom_data)
);
jtframe_ram #(.AW(11),.SIMHEXFILE("protocol.hex")) u_rom(
    .clk(clk), .cen(1'b1), .data(8'd0), .addr(rom_addr), .we(1'b0), .q(slap_rom)
);
jtframe_ram #(.AW(11),.SIMHEXFILE("tiger-protocol.hex")) u_tiger_rom(
    .clk(clk), .cen(1'b1), .data(8'd0), .addr(rom_addr), .we(1'b0), .q(tiger_rom)
);
task check;
    input condition;
    input [511:0] message;
    begin
        if(!condition) begin $display("FAIL: %s",message); $finish; end
    end
endtask
task exchange;
    input [7:0] command;
    begin
        @(negedge clk); host_dout=command; host_wr=1;
        @(negedge clk); host_wr=0;
        check(ibf,"host write must set full");
        check(uut.pc_in[0]==!tigerh,"MCU host-full polarity");
        cycles=0;
        while(!obf && cycles<30000) begin @(negedge clk); cycles=cycles+1; end
        check(obf,"MCU reply timeout");
        check(uut.pc_in[1]==tigerh,"MCU reply-full polarity");
        check(!ibf,"MCU acknowledgement must clear host full");
        check(host_din==~command,"MCU reply data");
        host_rd=1;
        @(negedge clk); host_rd=0;
        check(!obf,"host read must clear reply full");
        repeat(32) begin
            @(negedge clk);
            check(!obf,"PB2 held low must not duplicate reply");
            check(host_din==~command,"reply data must remain latched");
        end
        repeat(200) @(negedge clk);
    end
endtask
initial begin
    $dumpfile("test.lxt"); $dumpvars;
    repeat(20) @(negedge clk); rst=0;
    repeat(100) @(negedge clk);
    check(host_din==8'hff,"MCU data bus must read FF before its first reply");
    exchange(8'h3e); exchange(8'hd7);
    // MCU-side status is inverted on Tiger-Heli; host flags stay unchanged.
    @(negedge clk); rst=1; tigerh=1;
    repeat(20) @(negedge clk); rst=0;
    repeat(100) @(negedge clk);
    check(uut.pc_in==4'b1101,"Tiger-Heli idle semaphore polarity");
    exchange(8'ha5); exchange(8'h5a);
    check(uut.scroll_wr==0,"Tiger-Heli must not strobe MCU scroll outputs");
    $display("PASS: real MCU execution, command/ack/reply and no duplicate reply");
    $finish;
end
initial begin #1000000; $display("FAIL: timeout"); $finish; end
endmodule
