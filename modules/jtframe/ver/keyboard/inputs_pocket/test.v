`timescale 1ns/1ps
module test;
reg clk=0, rst=1, joy_aux_en=1;
reg [15:0] board_joy1=0;
reg [3:0] board_coin=0;
wire game_test, game_service;

always #5 clk=~clk;
`include "test_tasks.vh"

initial begin
    repeat (4) @(negedge clk);
    rst=0;
    repeat (16) @(negedge clk);
    assert_msg(game_test===1'b1 && game_service===1'b1,"Pocket starts with Test and Service inactive");
    board_coin[0]=1;
    board_joy1[5]=1;
    repeat (8) @(negedge clk);
    assert_msg(game_test===1'b0,"Pocket front-button Test shortcut is preserved");
    board_coin[0]=0;
    board_joy1[5]=0;
    board_joy1[10]=1;
    repeat (8) @(negedge clk);
    assert_msg(game_test===1'b1 && game_service===1'b1,"extra pad Test/Service bits are ignored on Pocket");
    pass();
end

jtframe_inputs #(.BUTTONS(2)) uut(
    .rst(rst), .clk(clk), .vs(1'b0), .cab_active(1'b0), .cab_inputs(21'b0),
    .joy_aux_en(joy_aux_en), .board_joy1(board_joy1), .board_coin(board_coin),
    .key_service(1'b0), .key_test(1'b0), .ioctl_lock(1'b0),
    .game_test(game_test), .game_service(game_service)
);

endmodule

`ifndef VERILATOR
module jtframe_dial(input rst, clk, lhbl, lvbl, mouse_st,
    input [8:0] mouse_dx, mouse_dy, input [9:0] joystick1, joystick2,
    input [8:0] spinner_1, spinner_2, input [1:0] sensty,
    input raw, reverse, output [1:0] dial_x, dial_y);
assign dial_x=0;
assign dial_y=0;
endmodule
`endif
