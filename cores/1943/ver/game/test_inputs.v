`timescale 1ns/1ps

module test_inputs(
    input   loop_rst,
    input   LVBL,
    output  reg [6:0] game_joystick1,
    output  reg       button_1p,
    output  reg       coin_left
);

localparam FIRE = 4;
localparam DOWN = 2;

integer framecnt=0;

always @(negedge loop_rst)
    $display("INFO: loop_rst over.");

always @(negedge LVBL)
    if( loop_rst ) begin
        game_joystick1 <= ~7'd0;
        button_1p      <= 1'b1;
        coin_left      <= 1'b0;
    end else begin
        framecnt <= framecnt + 1;
        case( framecnt>>3 )
            0: coin_left <= 1'b0;   // enable all test modes
            4: begin
                coin_left <= 1'b1;
                game_joystick1[DOWN] <= 1'b0;
            end
            8: begin
                game_joystick1[DOWN] <= 1'b1;
                game_joystick1[FIRE] <= 1'b0;
            end
            9: game_joystick1[FIRE] <= 1'b1;
        endcase // framecnt
    end

endmodule // test_inputs