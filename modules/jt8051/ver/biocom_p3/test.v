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
reg saw_movx = 0;
reg DMAONn = 1'b1;
reg [7:0] snd_dout = 8'h00;
reg snd_mcu_wr = 1'b0;
reg snd_mcu_rd = 1'b0;

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
    if (!rst && uut.u_mcu.x_wr) begin
        saw_movx <= 1'b1;
        assert_msg(mcu_wr, "MOVX supplies the shared-bus write strobe");
        assert_msg(mcu_dout == 8'h5a, "MOVX uses the dedicated XDATA output");
    end
end

`include "test_tasks.vh"

jtbiocom_mcu uut(
    .rst, .rst_cpu(rst), .clk_rom, .clk_cpu(clk), .clk, .cen6a(cen),
    .DMAONn, .mcu_dout, .mcu_din(8'h00), .mcu_wr, .mcu_addr,
    .mcu_brn, .DMAn(dman),
    .snd_dout, .snd_din, .snd_mcu_wr, .snd_mcu_rd,
    .prog_addr, .prom_din, .prom_we
);

initial begin
    for (i = 0; i < 512; i = i + 1) rom[i] = 8'hff;
    rom['h000] = 8'h02; rom['h001] = 8'h01; rom['h002] = 8'h00;
    // MOV P1,#A5; CLR P3.5; MOV DPTR,#1234; MOV A,#5A; MOVX @DPTR,A; SJMP $.
    // MOVX uses the dedicated XDATA data path and also drives the physical
    // P3.6 /WR pin low, which clocks the board's sound latch.
    rom['h100] = 8'h75; rom['h101] = 8'h90; rom['h102] = 8'ha5;
    rom['h103] = 8'hc2; rom['h104] = 8'hb5;
    rom['h105] = 8'h90; rom['h106] = 8'h12; rom['h107] = 8'h34;
    rom['h108] = 8'h74; rom['h109] = 8'h5a;
    rom['h10a] = 8'hf0;
    rom['h10b] = 8'h80; rom['h10c] = 8'hfe;

    repeat (600) @(posedge clk_rom);
    rst = 1'b0;
    repeat (1000) @(posedge clk);
    assert_msg(saw_movx, "Bionic firmware executes MOVX write");
    assert_msg(snd_din == 8'ha5, "MOVX write clocks the Bionic sound latch");

    // P3.6 is still GPIO outside MOVX and can clock the same sound latch from
    // P1.  It must not be treated as a shared-main-bus write shortcut; main
    // bus writes are MOVX-only and gated by P3.5 DMA ownership.
    force uut.p1_o = 8'h3c;
    force uut.p0_o = 8'hc3;
    force uut.p3_o = 8'hff;
    @(posedge clk); #1;
    force uut.p3_o = 8'hbf;
    @(posedge clk); #1;
    assert_msg(!mcu_wr, "manual P3.6 low without DMA ownership does not write the shared bus");
    assert_msg(snd_din == 8'h3c, "manual P3.6 falling edge clocks sound latch");
    force uut.p3_o = 8'h9f;
    @(posedge clk); #1;
    assert_msg(!mcu_wr, "manual P3.6 low with DMA ownership does not write the shared bus");
    assert_msg(mcu_dout == 8'h5a, "manual P3.6 does not replace the MOVX data path");
    force uut.p3_o = 8'hff;
    @(posedge clk); #1;
    release uut.p1_o;
    release uut.p0_o;

    // Bionic's board puts an LS74 between the DMA request and INT0/RQBSQ.
    // Its asynchronous CLR and PRESET inputs are P3.0 and P3.1 respectively.
    // Force the MCU pins while testing the external board logic; the ROM keeps
    // running but cannot alter these three latch-control inputs.
    force uut.p3_o = 8'hff;
    DMAONn = 1'b0;
    @(posedge clk); #1;
    DMAONn = 1'b1;
    @(posedge clk); #1;
    assert_msg(!mcu_brn, "DMAON latches INT0 and asserts RQBSQ");
    force uut.p3_o = 8'hfe; // P3.0: /CLR
    @(posedge clk); #1;
    assert_msg(mcu_brn, "P3.0 clears the DMA/INT0 latch");
    force uut.p3_o = 8'hfd; // P3.1: /PRESET
    @(posedge clk); #1;
    assert_msg(!mcu_brn, "P3.1 presets the DMA/INT0 latch");

    // A main/sound CPU write clocks the second LS74 and asserts INT1.  P3.4
    // asynchronously clears it; its preset input is tied high on the PCB.
    force uut.p3_o = 8'hff;
    snd_dout = 8'h5a;
    snd_mcu_wr = 1'b1;
    @(posedge clk); #1;
    snd_mcu_wr = 1'b0;
    @(posedge clk); #1;
    assert_msg(!uut.int1n, "sound CPU write latches INT1 low");
    assert_msg(uut.snd_dout_latch == 8'h5a, "sound CPU write is captured");
    force uut.p3_o = 8'hef; // P3.4: /CLR
    @(posedge clk); #1;
    assert_msg(uut.int1n, "P3.4 clears the INT1 latch");
    release uut.p3_o;
    pass();
end

endmodule
