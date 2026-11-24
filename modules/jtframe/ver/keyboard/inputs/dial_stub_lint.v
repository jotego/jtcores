`ifdef VERILATOR
module jtframe_dial(input rst, clk, lhbl, lvbl, mouse_st,
    input [8:0] mouse_dx, mouse_dy, input [9:0] joystick1, joystick2,
    input [8:0] spinner_1, spinner_2, input [1:0] sensty,
    input raw, reverse, output [1:0] dial_x, dial_y);
assign dial_x=0;
assign dial_y=0;
endmodule
`endif
