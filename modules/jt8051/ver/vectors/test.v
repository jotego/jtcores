/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

`timescale 1ns/1ps

module test;

reg clk = 0, rst = 1, cen = 0;
reg [7:0] rom [0:65535];
reg [7:0] iram [0:127];
reg [7:0] xram [0:65535];
reg [7:0] ram_din = 0, rom_din = 0;
wire [7:0] x_din;
wire [7:0] p0_o, p1_o, p2_o, p3_o, ram_dout, x_dout;
wire [15:0] rom_addr, x_addr;
wire [6:0] ram_addr;
wire ram_we, x_wr, x_acc;
integer file, bytes, i, boundaries = 0, enabled_ticks = 0;
reg failed = 0;

assign x_din = xram[x_addr];

always #5 clk = ~clk;
always @(posedge clk) cen <= rst ? 1'b0 : ~cen;

always @(posedge clk) if (cen) begin
    rom_din <= rom[rom_addr];
    ram_din <= iram[ram_addr];
    if (ram_we) iram[ram_addr] <= ram_dout;
    if (x_wr) xram[x_addr] <= x_dout;
end

always @(posedge clk) if (!rst && cen) enabled_ticks <= enabled_ticks + 1;

`include "test_checks.vh"

always @(posedge uut.next_instruction) if (!rst) begin
    if (boundaries != 0) begin
        check_state(boundaries-1);
        check_cycles(boundaries-1, enabled_ticks);
        if (failed) $fatal(1, "JT8051 vector check failed");
        if (boundaries == CHECK_COUNT) begin
            $display("PASS");
            $finish;
        end
    end
    boundaries = boundaries+1;
    enabled_ticks = 0;
end

initial begin
    for (i=0; i<65536; i=i+1) rom[i] = 8'd0;
    for (i=0; i<128; i=i+1) iram[i] = 8'd0;
    for (i=0; i<65536; i=i+1) xram[i] = 8'd0;
    file = $fopen("program.bin", "rb");
    if (file == 0) $fatal(1, "program.bin was not generated");
    bytes = $fread(rom, file);
    $fclose(file);
    if (bytes == 0) $fatal(1, "program.bin is empty");
    repeat (16) @(posedge clk);
    rst = 0;
    repeat (10000) @(posedge clk);
    $fatal(1, "JT8051 vector test timed out");
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
