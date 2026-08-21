/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

`timescale 1ns/1ps

module test;

reg clk_rom = 1'b0;
reg clk = 1'b0;
reg rst = 1'b1;
reg [1:0] cen_div = 0;
reg cen = 0;
reg [11:0] prog_addr = 0;
reg [7:0] prom_din = 0;
reg prom_we = 0;
reg [7:0] rom [0:511];
integer load_addr = 0;
integer i;
reg saw_strobe = 0;

wire [7:0] mcu_dout, snd_din;
wire [16:1] mcu_addr;
wire mcu_wr, mcu_brn, dman;

always #10 clk = ~clk;
always #5 clk_rom = ~clk_rom;

// 6 MHz 8051 oscillator enable from the 24 MHz MCU clock domain.
always @(posedge clk) begin
    if (rst) begin
        cen_div <= 0;
        cen <= 0;
    end else begin
        cen <= cen_div == 2'd3;
        cen_div <= cen_div + 1'd1;
    end
end

// This is deliberately the same registered programming interface used by
// the game wrapper, including its one-cycle output latency.
always @(posedge clk_rom) begin
    if (load_addr < 512) begin
        prog_addr <= load_addr[11:0];
        prom_din <= rom[load_addr];
        prom_we <= 1'b1;
        load_addr <= load_addr + 1;
    end else begin
        prom_we <= 1'b0;
    end
end

always @(posedge clk) begin
    if (!rst && !uut.p3_o[6]) begin
        saw_strobe <= 1'b1;
        assert_msg(!mcu_wr,
            "Bionic P3.6 sound strobe does not write shared RAM");
    end
end

`include "test_tasks.vh"

jtbiocom_mcu #(.SAME_CLK(1)) uut(
    .rst, .rst_cpu(rst), .clk_rom, .clk_cpu(clk), .clk, .cen6a(cen),
    .DMAONn(1'b1), .mcu_dout, .mcu_din(8'h00), .mcu_wr, .mcu_addr,
    .mcu_brn, .DMAn(dman),
    .snd_dout(8'h00), .snd_din, .snd_mcu_wr(1'b0), .snd_mcu_rd(1'b0),
    .prog_addr, .prom_din, .prom_we
);

initial begin
    for (i = 0; i < 512; i = i + 1) rom[i] = 8'hff;
    rom['h000] = 8'h02; rom['h001] = 8'h01; rom['h002] = 8'h00;
    // MOV P1,#A5; CLR P3.6; SETB P3.6; SJMP $0107
    // There is deliberately no MOVX write in this sequence.
    rom['h100] = 8'h75; rom['h101] = 8'h90; rom['h102] = 8'ha5;
    rom['h103] = 8'hc2; rom['h104] = 8'hb6;
    rom['h105] = 8'hd2; rom['h106] = 8'hb6;
    rom['h107] = 8'h80; rom['h108] = 8'hfe;

    repeat (600) @(posedge clk_rom);
    rst = 1'b0;
    repeat (1000) @(posedge clk);
    assert_msg(saw_strobe, "Bionic firmware pulses P3.6");
    pass();
end

endmodule
