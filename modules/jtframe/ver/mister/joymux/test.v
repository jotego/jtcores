`timescale 1ns/1ps
module test;
reg clk=0, rst=1, db15_en=1, combo_off=0;
reg [6:0] user_in=7'h7f;
reg [15:0] joyusb_1=0, joyusb_2=0;
wire [6:0] user_out;
wire [15:0] joymux_1, joymux_2;
wire show_osd;
wire osd_combo_en = ~combo_off;

always #5 clk=~clk;
`include "test_tasks.vh"

initial begin
    force uut.joydb15_1 = 16'h0440;
    force uut.joydb15_2 = 16'h0000;
    repeat(4) @(negedge clk);
    rst=0;
    repeat(4) @(negedge clk);
    assert_msg(show_osd===1'b1,"default status value enables P1 Start+Button 3 OSD chord");
    assert_msg(joymux_1===16'h0440,"P1 Start and Button 3 reach a six-button game");

    force uut.joydb15_1 = 16'h0400;
    repeat(4) @(negedge clk);
    assert_msg(show_osd===1'b0,"P1 Start alone does not open the OSD");
    assert_msg(joymux_1===16'h0400,"P1 Start alone still reaches the game");

    force uut.joydb15_1 = 16'h0040;
    repeat(4) @(negedge clk);
    assert_msg(show_osd===1'b0,"P1 Button 3 alone does not open the OSD");
    assert_msg(joymux_1===16'h0040,"P1 Button 3 alone still reaches the game");

    force uut.joydb15_1 = 16'h0440;
    combo_off=1;
    repeat(4) @(negedge clk);
    assert_msg(show_osd===1'b0,"status-bit Off suppresses the OSD chord");
    assert_msg(joymux_1===16'h0440,"disabling the OSD chord leaves P1 game buttons unchanged");

    combo_off=0;
    force uut.joydb15_1 = 16'h0000;
    force uut.joydb15_2 = 16'h0440;
    repeat(4) @(negedge clk);
    assert_msg(show_osd===1'b1,"P2 Start+Button 3 opens the OSD");
    assert_msg(joymux_2===16'h0440,"P2 Start and Button 3 reach a six-button game");

    combo_off=1;
    repeat(4) @(negedge clk);
    assert_msg(show_osd===1'b0,"status-bit Off suppresses P2's OSD chord");
    assert_msg(joymux_2===16'h0440,"disabling the OSD chord leaves P2 game buttons unchanged");

    combo_off=0;
    force uut.joydb15_1 = 16'h0440;
    repeat(4) @(negedge clk);
    assert_msg(show_osd===1'b1,"either player's chord can open the OSD");

    db15_en=0;
    joyusb_1=16'h1234;
    joyusb_2=16'h5a5a;
    repeat(4) @(negedge clk);
    assert_msg(show_osd===1'b0,"USB user-port mode cannot open the DB15 OSD");
    assert_msg(joymux_1===joyusb_1 && joymux_2===joyusb_2,"USB joystick values pass through unchanged");
    release uut.joydb15_1;
    release uut.joydb15_2;
    pass();
end

jtframe_joymux #(.BUTTONS(6)) uut(
    .rst          ( rst           ),
    .clk          ( clk           ),
    .show_osd     ( show_osd      ),
    .USER_IN      ( user_in       ),
    .USER_OUT     ( user_out      ),
    .db15_en      ( db15_en       ),
    .osd_combo_en ( osd_combo_en  ),
    .joyusb_1     ( joyusb_1      ),
    .joyusb_2     ( joyusb_2      ),
    .joymux_1     ( joymux_1      ),
    .joymux_2     ( joymux_2      )
);

endmodule
