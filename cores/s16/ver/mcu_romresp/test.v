`timescale 1ns/1ps

module test;

reg        clk = 1'b0, rst = 1'b1;
reg        mcu_bus = 1'b0, rom_ok = 1'b0, LDSn = 1'b0;
reg [15:0] rom_din = 16'hffff;
wire [7:0] mcu_din;

always #5 clk = ~clk;

`include "test_tasks.vh"

jts16_mcu_romresp uut(
    .rst, .clk, .mcu_bus, .rom_ok, .LDSn, .rom_din, .mcu_din
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;

    repeat (2) @(posedge clk);
    rst = 1'b0;
    mcu_bus = 1'b1;

    // The preceding 68k access remains visible while the MCU request is
    // decoded.  It must not become the MOVX result.
    rom_din = 16'hc014;
    @(posedge clk);
    assert_msg(mcu_din == 8'h00,
        "stale 68k data is ignored before rom_ok");

    rom_din = 16'h0000;
    rom_ok = 1'b1;
    @(posedge clk);
    rom_ok = 1'b0;
    assert_msg(mcu_din == 8'h00,
        "valid lower-byte ROM response is captured");

    LDSn = 1'b1;
    rom_din = 16'h3ca5;
    rom_ok = 1'b1;
    @(posedge clk);
    rom_ok = 1'b0;
    assert_msg(mcu_din == 8'h3c,
        "valid upper-byte ROM response is captured");

    mcu_bus = 1'b0;
    rom_din = 16'h7755;
    rom_ok = 1'b1;
    @(posedge clk);
    assert_msg(mcu_din == 8'h3c,
        "responses are ignored after the MCU releases the bus");
    pass();
end

endmodule
