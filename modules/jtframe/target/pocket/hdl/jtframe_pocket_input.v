/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME. If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-8-2022 */

module jtframe_pocket_input(
    input         clk_rom,
    input         rst_rom,
    input         clk,
    input         rstn,

    inout         pad_1wire,

    output [15:0] cont1_key,
    output [15:0] cont2_key,
    output [15:0] cont3_key,
    output [15:0] cont4_key,
    // analog sticks
    output [31:0] cont1_joy,
    output [31:0] cont2_joy,
    output [31:0] cont3_joy,
    output [31:0] cont4_joy,
    output [15:0] cont1_trig,
    output [15:0] cont2_trig,
    output [15:0] cont3_trig,
    output [15:0] cont4_trig,

    // Mouse
    output reg [ 8:0] mouse_dx, mouse_dy,
    output reg [ 7:0] mouse_f,       // flags
    output reg        mouse_idx,
    output reg        mouse_st,
    output            key_en,        // only controller 3 is checked
    output     [ 3:0] analog_en,

    output     [7:0]  st_dout
);


wire [15:0] cont1_key_74m, cont2_key_74m, cont3_key_74m, cont4_key_74m,
            cont1_trig_74m, cont2_trig_74m, cont3_trig_74m, cont4_trig_74m;
wire [31:0] cont1_joy_74m, cont2_joy_74m, cont3_joy_74m, cont4_joy_74m;
wire [ 3:0] mouse_en,     keyb_en,
            mouse_en_74m, keyb_en_74m, analog_en_74m;
reg  [ 2:0] ms0, ms1; // controller index for each mouse. MSB = enable
wire        ms0_st, ms1_st;

assign st_dout = {keyb_en, mouse_en};
assign key_en  = keyb_en[2];

function ms_st( input [2:0] sel );
    ms_st = !sel[2] ? 1'b0 :
        sel[1:0]==0 ? cont1_key[0] :
        sel[1:0]==1 ? cont2_key[0] :
        sel[1:0]==2 ? cont3_key[0] : cont4_key[0];
endfunction

function [2:0] ms_but( input [1:0] sel );
    case( sel )
        0: ms_but = cont1_joy[16+:3];
        1: ms_but = cont2_joy[16+:3];
        2: ms_but = cont3_joy[16+:3];
        3: ms_but = cont4_joy[16+:3];
    endcase
endfunction

function [8:0] ms_dx( input [1:0] sel );
    reg [15:0] mx;
    case( sel )
        0: mx = cont1_joy[15:0];
        1: mx = cont2_joy[15:0];
        2: mx = cont3_joy[15:0];
        3: mx = cont4_joy[15:0];
    endcase
    ms_dx = ^mx[15:9] ? {mx[15],{8{~mx[15]}}} : mx[0+:9]; // saturate if needed
endfunction

function [8:0] ms_dy( input [1:0] sel );
    case( sel )
        0: ms_dy = cont1_trig[0+:9];
        1: ms_dy = cont2_trig[0+:9];
        2: ms_dy = cont3_trig[0+:9];
        3: ms_dy = cont4_trig[0+:9];
    endcase
endfunction

assign ms0_st = ms_st(ms0);
assign ms1_st = ms_st(ms1);

// Huge block (16*8+32*4)*2=512 flip flops to synchronize
// Gets synthesized as RAM, so it isn't that bad.
jtframe_sync #(.W(16*8+32*4+3*4)) u_sync(
    .clk_in ( clk     ),
    .clk_out( clk_rom ),
    .raw    ( {cont1_key_74m, cont2_key_74m, cont3_key_74m, cont4_key_74m,
               cont1_trig_74m, cont2_trig_74m, cont3_trig_74m, cont4_trig_74m,
               cont1_joy_74m, cont2_joy_74m, cont3_joy_74m, cont4_joy_74m,
               mouse_en_74m, keyb_en_74m, analog_en_74m } ),
    .sync   ( {cont1_key, cont2_key, cont3_key, cont4_key,
               cont1_trig, cont2_trig, cont3_trig, cont4_trig,
               cont1_joy, cont2_joy, cont3_joy, cont4_joy,
               mouse_en, keyb_en, analog_en } )
);

always @(posedge clk_rom) begin
    // mouse0 has priority
    mouse_st  <= ms0_st | ms1_st;
    mouse_f   <= {5'd0, ms0_st ? ms_but(ms0[1:0]) : ms_but(ms1[1:0]) };
    mouse_idx <= ms1_st & ~ms0_st;
    mouse_dx  <= ms0_st ? ms_dx(ms0[1:0]) : ms_dx(ms1[1:0]);
    mouse_dy  <= ms0_st ? ms_dy(ms0[1:0]) : ms_dy(ms1[1:0]);
end

always @(posedge clk_rom) begin
    casez( mouse_en )
        // only one mouse
        4'b0001: { ms1, ms0 } <= { 3'b000, 3'b100 };
        4'b0010: { ms1, ms0 } <= { 3'b000, 3'b101 };
        4'b0100: { ms1, ms0 } <= { 3'b000, 3'b110 };
        4'b1000: { ms1, ms0 } <= { 3'b000, 3'b111 };
        // more than one mouse
        4'b??11: { ms1, ms0 } <= { 3'b101, 3'b100 };
        4'b?110: { ms1, ms0 } <= { 3'b110, 3'b101 };
        4'b1100: { ms1, ms0 } <= { 3'b111, 3'b110 };
        default: { ms1, ms0 } <= 0;
    endcase

end

io_pad_controller u_spi(
    .clk         ( clk               ),
    .reset_n     ( rstn              ),

    .pad_1wire  ( pad_1wire         ),

    .cont1_key  ( cont1_key_74m     ),
    .cont2_key  ( cont2_key_74m     ),
    .cont3_key  ( cont3_key_74m     ),
    .cont4_key  ( cont4_key_74m     ),
    .cont1_joy  ( cont1_joy_74m     ),
    .cont2_joy  ( cont2_joy_74m     ),
    .cont3_joy  ( cont3_joy_74m     ),
    .cont4_joy  ( cont4_joy_74m     ),
    .cont1_trig ( cont1_trig_74m    ),
    .cont2_trig ( cont2_trig_74m    ),
    .cont3_trig ( cont3_trig_74m    ),
    .cont4_trig ( cont4_trig_74m    ),

    .mouse_en    (  mouse_en_74m    ),
    .keyb_en     (  keyb_en_74m     ),
    .analog_en   (  analog_en_74m   ),
    .rx_timed_out(                  )
);

endmodule
