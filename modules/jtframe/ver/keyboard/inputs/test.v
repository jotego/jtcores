`timescale 1ns/1ps
module test;
reg clk=0, rst=1, cab_active=0, joy_aux_en=1;
reg [20:0] cab_inputs=0;
reg [15:0] joy1=0, joy2=0, joy3=0, joy4=0;
reg [15:0] joy1_1=0, joy2_1=0, joy3_1=0, joy4_1=0;
reg [15:0] joy1_6=0, joy2_6=0, joy3_6=0, joy4_6=0;
reg key_service=0, key_test=0, key_pause=0, lvbl=0;
wire test1, test2, test6, service1, service2, service6;
wire pause2;

always #5 clk=~clk;
`include "test_tasks.vh"

initial begin
    repeat (4) @(negedge clk);
    rst=0;
    repeat (16) @(negedge clk);
    assert_msg(test1===1'b1 && test2===1'b1 && test6===1'b1,"Test starts inactive");
    assert_msg(service1===1'b1 && service2===1'b1 && service6===1'b1,"Service starts inactive");

    joy2_1[8]=1;
    joy3[9]=1;
    joy4_6[13]=1;
    repeat (8) @(negedge clk);
    assert_msg(test1===1'b0 && test2===1'b0 && test6===1'b0,"Test maps from different players for 1/2/6 buttons");
    assert_msg(service1===1'b1 && service2===1'b1 && service6===1'b1,"Test inputs do not trigger Service");
    joy2_1[8]=0;
    joy3[9]=0;
    joy4_6[13]=0;
    joy4_1[9]=1;
    joy1[10]=1;
    joy2_6[14]=1;
    repeat (8) @(negedge clk);
    assert_msg(test1===1'b1 && test2===1'b1 && test6===1'b1,"Service inputs do not trigger Test");
    assert_msg(service1===1'b0 && service2===1'b0 && service6===1'b0,"Service maps from different players for 1/2/6 buttons");

    joy2_1[8]=1;
    joy3[9]=1;
    joy4_6[13]=1;
    cab_active=1;
    cab_inputs=0;
    repeat (8) @(negedge clk);
    assert_msg(test1===1'b1 && test2===1'b1 && test6===1'b1,"CAB suppresses physical Test");
    assert_msg(service1===1'b1 && service2===1'b1 && service6===1'b1,"CAB suppresses physical Service");
    cab_inputs[11]=1;
    cab_inputs[1]=1;
    repeat (8) @(negedge clk);
    assert_msg(test1===1'b0 && test2===1'b0 && test6===1'b0,"CAB Test input remains active");
    assert_msg(service1===1'b0 && service2===1'b0 && service6===1'b0,"CAB Service input remains active");

    cab_active=0;
    cab_inputs=0;
    joy_aux_en=0;
    repeat (8) @(negedge clk);
    assert_msg(test1===1'b1 && test2===1'b1 && test6===1'b1,"joy_aux_en=0 suppresses Test utility decoding");
    assert_msg(service1===1'b1 && service2===1'b1 && service6===1'b1,"joy_aux_en=0 suppresses Service utility decoding");

    joy_aux_en=1;
    joy1=0; joy2=0; joy3=0; joy4=0;
    joy1_1=0; joy2_1=0; joy3_1=0; joy4_1=0;
    joy1_6=0; joy2_6=0; joy3_6=0; joy4_6=0;
    key_test=1;
    key_service=1;
    repeat (8) @(negedge clk);
    assert_msg(test2===1'b0 && service2===1'b0,"keyboard Test and Service merge with pad inputs");
    key_test=0;
    key_service=0;

    key_pause=1;
    repeat (8) @(negedge clk);
    key_pause=0;
    repeat (12) @(negedge clk);
    assert_msg(pause2===1'b1,"pause key enters paused state");
    joy4[10]=1;
    repeat (4) @(negedge clk);
    joy4[10]=0;
    lvbl=1;
    repeat (4) @(negedge clk);
    lvbl=0;
    repeat (8) @(negedge clk);
    assert_msg(pause2===1'b0,"joystick Service advances one frame");
    lvbl=1;
    repeat (4) @(negedge clk);
    lvbl=0;
    repeat (8) @(negedge clk);
    assert_msg(pause2===1'b1,"pause restores after the service frame");
    pass();
end

jtframe_inputs #(.BUTTONS(1)) uut_1(
    .rst(rst), .clk(clk), .vs(1'b0), .lvbl(lvbl), .cab_active(cab_active), .cab_inputs(cab_inputs),
    .joy_aux_en(joy_aux_en), .board_joy1(joy1_1), .board_joy2(joy2_1), .board_joy3(joy3_1), .board_joy4(joy4_1),
    .key_service(key_service), .key_test(key_test), .key_pause(key_pause), .osd_pause(1'b0), .ioctl_lock(1'b0),
    .game_test(test1), .game_service(service1)
);

jtframe_inputs #(.BUTTONS(2)) uut_2(
    .rst(rst), .clk(clk), .vs(1'b0), .lvbl(lvbl), .cab_active(cab_active), .cab_inputs(cab_inputs),
    .joy_aux_en(joy_aux_en), .board_joy1(joy1), .board_joy2(joy2), .board_joy3(joy3), .board_joy4(joy4),
    .key_service(key_service), .key_test(key_test), .key_pause(key_pause), .osd_pause(1'b0), .ioctl_lock(1'b0),
    .game_test(test2), .game_service(service2), .game_pause(pause2)
);

jtframe_inputs #(.BUTTONS(6)) uut_6(
    .rst(rst), .clk(clk), .vs(1'b0), .lvbl(lvbl), .cab_active(cab_active), .cab_inputs(cab_inputs),
    .joy_aux_en(joy_aux_en), .board_joy1(joy1_6), .board_joy2(joy2_6), .board_joy3(joy3_6), .board_joy4(joy4_6),
    .key_service(key_service), .key_test(key_test), .key_pause(key_pause), .osd_pause(1'b0), .ioctl_lock(1'b0),
    .game_test(test6), .game_service(service6)
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
