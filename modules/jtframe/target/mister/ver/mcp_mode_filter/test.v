`timescale 1ns / 1ps

module test;

reg clk = 0;
always #10 clk = ~clk;

wire [2:0] btn;
wire sd_cd, present, mode;
wire scl;
tri1 sda;
wire [31:0] read_count;

`include "test_tasks.vh"

mcp23009 uut (
    .clk        ( clk     ),
    .btn        ( btn     ),
    .led        ( 3'b000  ),
    .flg_sd_cd  ( sd_cd   ),
    .flg_present( present ),
    .flg_mode   ( mode    ),
    .scl        ( scl     ),
    .sda        ( sda     )
);

assign read_count = uut.i2c.read_count;

initial begin
    wait (read_count == 1);
    @(posedge clk);
    @(negedge clk);
    assert_msg(mode === 1'b1, "one mode-0 read must not change the initial mode");

    wait (read_count == 2);
    @(posedge clk);
    @(negedge clk);
    assert_msg(mode === 1'b1, "one mode-1 read after mode 0 must not switch mode");

    wait (read_count == 3);
    @(posedge clk);
    @(negedge clk);
    assert_msg(mode === 1'b1, "matching mode-1 reads must preserve mode 1");

    wait (read_count == 4);
    @(posedge clk);
    @(negedge clk);
    assert_msg(mode === 1'b1, "one mode-0 read must not switch from mode 1");

    wait (read_count == 5);
    @(posedge clk);
    @(negedge clk);
    assert_msg(mode === 1'b0, "two successful matching mode-0 reads must switch mode");
    assert_msg(sd_cd === 1'b1 && btn === 3'b101 && present === 1'b1,
        "successful reads must continue updating card, buttons and presence");

    wait (read_count == 6);
    @(posedge clk);
    @(negedge clk);
    assert_msg(mode === 1'b0, "a failed mode-1 read must not change the accepted mode");
    assert_msg(sd_cd === 1'b1 && btn === 3'b101,
        "a failed read with different card/button bits must preserve prior state");

    wait (read_count == 7);
    @(posedge clk);
    @(negedge clk);
    assert_msg(mode === 1'b0, "one successful mode-1 read after a failure must not switch mode");

    wait (read_count == 8);
    @(posedge clk);
    @(negedge clk);
    assert_msg(mode === 1'b1, "two successful matching mode-1 reads must switch mode");
    pass();
end

endmodule
