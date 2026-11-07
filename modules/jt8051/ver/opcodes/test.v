/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

`timescale 1ns/1ps

// Execute every opcode byte once from a known reset state.  This is a decode
// smoke test: detailed architectural results stay in vectors/tests.yaml,
// where each instruction and its expected state are readable together.
module test;

reg clk=0, rst=1, cen=0;
reg [7:0] rom [0:65535];
reg [7:0] iram [0:127];
reg [7:0] xram [0:65535];
reg [7:0] ram_din=0, rom_din=0;
wire [7:0] x_din, p0_o, p1_o, p2_o, p3_o, ram_dout, x_dout;
wire [15:0] rom_addr, x_addr;
wire [6:0] ram_addr;
wire ram_we, x_wr, x_acc;
integer opcode, index;

assign x_din = xram[x_addr];

always #5 clk=~clk;
always @(posedge clk) cen <= rst ? 1'b0 : ~cen;

always @(posedge clk) if (cen) begin
    rom_din <= rom[rom_addr];
    ram_din <= iram[ram_addr];
    if (ram_we) iram[ram_addr] <= ram_dout;
    if (x_wr) xram[x_addr] <= x_dout;
end

task fail_opcode;
    input [8*80-1:0] message;
begin
    $display("FAIL: opcode %02h %0s", opcode[7:0], message);
    $fatal(1, "JT8051 opcode smoke test failed");
end
endtask

initial begin
    for (index=0; index<65536; index=index+1) begin
        rom[index]=0;
        xram[index]=0;
    end
    for (index=0; index<128; index=index+1) iram[index]=0;

    for (opcode=0; opcode<256; opcode=opcode+1) begin
        rst=1;
        rom[0]=opcode[7:0];
        rom[1]=0;
        rom[2]=0;
        repeat (4) @(posedge clk);
        rst=0;

        // The first boundary is the fetch/decode handoff.  This verifies the
        // fetched opcode reaches its individual generated microcode address.
        @(posedge uut.next_instruction); #1;
        if (uut.ir !== opcode[7:0]) fail_opcode("was not fetched");
        if (uut.u_ctrl.uaddr !== {1'b0,opcode[7:0],6'd0})
            fail_opcode("did not enter its microcode sequence");

        // A second boundary proves that instruction sequence completed.  The
        // zero operands make all branches and calls terminate safely.
        @(posedge uut.next_instruction); #1;
    end
    $display("PASS");
    $finish;
end

initial begin
    repeat (200000) @(posedge clk);
    $fatal(1, "JT8051 opcode smoke test timed out");
end

jt8051 uut(
    .rst, .clk, .cen,
    .int0n(1'b1), .int1n(1'b1),
    .p0_i(8'hff), .p1_i(8'hff), .p2_i(8'hff), .p3_i(8'hff),
    .p0_o, .p1_o, .p2_o, .p3_o,
    .rom_data(rom_din), .rom_addr,
    .ram_din, .ram_dout, .ram_addr, .ram_we,
    .x_din, .x_dout, .x_addr, .x_wr, .x_acc
);

endmodule
