`timescale 1ns / 1ps

module test;

`include "test_tasks.vh"

reg        clk = 1'b0;
reg        rst = 1'b1;
reg        enable = 1'b0;
reg [15:0] joystick1 = 16'd0;
reg [15:0] joystick2 = 16'd0;
reg [ 8:0] board_gun_1p_x = 9'd0;
reg [ 8:0] board_gun_1p_y = 9'd0;
reg [ 8:0] board_gun_2p_x = 9'd0;
reg [ 8:0] board_gun_2p_y = 9'd0;
reg        p1_aim_valid = 1'b0;
reg [ 9:0] p1_x = 10'd0;
reg [ 7:0] p1_y = 8'd0;
reg        p1_trigger = 1'b0;
reg        p1_start = 1'b0;
reg        p1_button = 1'b0;
reg        p1_select = 1'b0;
reg        p2_aim_valid = 1'b0;
reg [ 9:0] p2_x = 10'd0;
reg [ 7:0] p2_y = 8'd0;
reg        p2_trigger = 1'b0;
reg        p2_start = 1'b0;
reg        p2_button = 1'b0;
reg        p2_select = 1'b0;
wire [15:0] joystick1_out, joystick2_out;
wire [ 8:0] gun_1p_x, gun_1p_y, gun_2p_x, gun_2p_y;

always #5 clk = ~clk;

jtframe_guncon_mux uut(
    .rst             ( rst             ),
    .clk             ( clk             ),
    .enable          ( enable          ),
    .joystick1       ( joystick1       ),
    .joystick2       ( joystick2       ),
    .board_gun_1p_x  ( board_gun_1p_x  ),
    .board_gun_1p_y  ( board_gun_1p_y  ),
    .board_gun_2p_x  ( board_gun_2p_x  ),
    .board_gun_2p_y  ( board_gun_2p_y  ),
    .p1_aim_valid    ( p1_aim_valid    ),
    .p1_x            ( p1_x            ),
    .p1_y            ( p1_y            ),
    .p1_trigger      ( p1_trigger      ),
    .p1_start        ( p1_start        ),
    .p1_button       ( p1_button       ),
    .p1_select       ( p1_select       ),
    .p2_aim_valid    ( p2_aim_valid    ),
    .p2_x            ( p2_x            ),
    .p2_y            ( p2_y            ),
    .p2_trigger      ( p2_trigger      ),
    .p2_start        ( p2_start        ),
    .p2_button       ( p2_button       ),
    .p2_select       ( p2_select       ),
    .joystick1_out   ( joystick1_out   ),
    .joystick2_out   ( joystick2_out   ),
    .gun_1p_x        ( gun_1p_x        ),
    .gun_1p_y        ( gun_1p_y        ),
    .gun_2p_x        ( gun_2p_x        ),
    .gun_2p_y        ( gun_2p_y        )
);

task tick;
begin
    @(posedge clk);
    #1;
end
endtask

initial begin
    tick;
    assert_msg(joystick1_out == 0 && joystick2_out == 0,
               "reset did not clear joystick outputs");
    assert_msg(gun_1p_x == 0 && gun_1p_y == 0 && gun_2p_x == 0 && gun_2p_y == 0,
               "reset did not clear gun outputs");

    rst = 1'b0;
    joystick1 = 16'h8001;
    joystick2 = 16'h4002;
    board_gun_1p_x = 9'd123;
    board_gun_1p_y = 9'd45;
    board_gun_2p_x = 9'd321;
    board_gun_2p_y = 9'd210;
    tick;
    assert_msg(joystick1_out == 16'h8001 && joystick2_out == 16'h4002,
               "board joysticks were not registered outside GunCon mode");
    assert_msg(gun_1p_x == 9'd123 && gun_1p_y == 9'd45 &&
               gun_2p_x == 9'd321 && gun_2p_y == 9'd210,
               "board gun coordinates were not registered outside GunCon mode");

    enable = 1'b1;
    p1_aim_valid = 1'b1;
    p1_x = 10'd588;
    p1_y = 8'd136;
    p1_trigger = 1'b1;
    p1_start = 1'b1;
    p1_button = 1'b1;
    p1_select = 1'b1;
    tick;
    assert_msg(joystick1_out == 16'h80f1,
               "GunCon P1 buttons were not registered");
    assert_msg(gun_1p_x == 9'd294 && gun_1p_y == 9'd136,
               "GunCon P1 coordinates were not narrowed and registered");
    assert_msg(gun_2p_x == 9'h1ff && gun_2p_y == 9'h1ff,
               "off-screen GunCon P2 coordinates were not registered");

    enable = 1'b0;
    board_gun_1p_x = 9'd12;
    board_gun_1p_y = 9'd34;
    tick;
    assert_msg(gun_1p_x == 9'd12 && gun_1p_y == 9'd34,
               "GunCon mode did not return to the board coordinates");
    assert_msg(joystick1_out == joystick1,
               "GunCon buttons were not cleared outside GunCon mode");

    pass();
end

endmodule
