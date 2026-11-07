`timescale 1ns/1ps
module test;
reg clk=0, rst=1, locked=0, cab_active=1;
reg [20:0] cab_inputs=0;
wire [9:0] joy1, joy2, joy3, joy4;
wire [3:0] coin, start;
wire service, game_test, tilt;
always #5 clk=~clk;
`include "test_tasks.vh"

initial begin
    $dumpfile("test.lxt"); $dumpvars;
    repeat(8) @(negedge clk); rst=0;
    repeat(12) @(negedge clk);
    assert_msg(joy1==10'h3ff && joy2==10'h3ff && coin==15 && start==15,"physical controls excluded");
    assert_msg(service && game_test && tilt,"neutral cabinet auxiliaries");
    cab_inputs[0]=1; cab_inputs[1]=1; cab_inputs[2]=1; cab_inputs[3]=1;
    cab_inputs[4]=1; cab_inputs[8]=1; cab_inputs[11]=1;
    cab_inputs[13]=1; cab_inputs[15]=1; cab_inputs[20]=1;
    repeat(12) @(negedge clk);
    assert_msg(joy1==10'h3ee,"P1 canonical right and button 1");
    assert_msg(joy2==10'h3bd,"P2 canonical left and button 3");
    assert_msg(joy3==10'h3ff && joy4==10'h3ff,"other players inactive");
    assert_msg(coin==12 && start==12,"both player coins and starts");
    assert_msg(!service && !game_test,"service and test follow CAB");
    locked=1; repeat(12) @(negedge clk);
    assert_msg(joy1==10'h3ff && joy2==10'h3ff && coin==15 && start==15 && service,"CAB must not bypass beta lock");
    pass();
end

jtframe_joysticks uut(
    .rst(rst), .clk(clk), .vs(1'b0), .locked(locked), .rot(1'b1), .rot_ccw(1'b1),
    .cab_active(cab_active), .cab_inputs(cab_inputs), .joy1_pos(2'd3),
    .board_coin(4'hf), .board_start(4'hf), .key_coin(4'hf), .key_start(4'hf),
    .joy_coin(4'hf), .joy_start(4'hf), .key_service(1'b1), .key_tilt(1'b1), .key_reset(1'b1),
    .ana1(16'h7f7f), .ana2(16'h7f7f), .board_joy1(16'hffff), .board_joy2(16'hffff),
    .board_joy3(16'hffff), .board_joy4(16'hffff), .key_joy1(10'h3ff), .key_joy2(10'h3ff),
    .key_joy3(10'h3ff), .key_joy4(10'h3ff), .joy_test(1'b1), .key_test(1'b1),
    .mouse_but_1p(3'd7), .mouse_but_2p(3'd7), .recjoy1(), .lock_joy1(),
    .game_joy1(joy1), .game_joy2(joy2), .game_joy3(joy3), .game_joy4(joy4),
    .game_coin(coin), .game_start(start), .game_test(game_test), .game_service(service),
    .game_tilt(tilt), .soft_rst()
);
endmodule
