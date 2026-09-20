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
    Date: 31-1-2025 */

module jtframe_pocket_joystick(
    input             clk_sys,
    input      [15:0] cont1,     cont2,     cont3,     cont4,
    input      [31:0] cont1_joy, cont2_joy, cont3_joy, cont4_joy,
    input      [ 3:0] analog_en,
    output reg [15:0] joystick1, joystick2, joystick3, joystick4,
                      joyana_l1, joyana_l2, joyana_l3, joyana_l4,
                      joyana_r1, joyana_r2, joyana_r3, joyana_r4
);

// Convert Pocket inputs to JTFRAME standard
function [15:0] joyconv( input [15:0] joy_in );
    joyconv = { 2'd0,
        joy_in[13:4],  joy_in[0],  joy_in[1],  joy_in[2],  joy_in[3]  };
endfunction

function [31:0] joyanaconv( input [31:0] cont_joy, input en );
    joyanaconv[ 7: 0] = cont_joy[ 7: 0]-8'h80;
    joyanaconv[15: 8] = cont_joy[15: 8]-8'h80;
    joyanaconv[23:16] = cont_joy[23:16]-8'h80;
    joyanaconv[31:24] = cont_joy[31:24]-8'h80;
    if(!en) joyanaconv = 0;
endfunction

always @(posedge clk_sys) begin
    joystick1 <= joyconv(cont1);
    joystick2 <= joyconv(cont2);
    joystick3 <= joyconv(cont3);
    joystick4 <= joyconv(cont4);
    { joyana_r1, joyana_l1 } <= joyanaconv(cont1_joy, analog_en[0]);
    { joyana_r2, joyana_l2 } <= joyanaconv(cont2_joy, analog_en[1]);
    { joyana_r3, joyana_l3 } <= joyanaconv(cont3_joy, analog_en[2]);
    { joyana_r4, joyana_l4 } <= joyanaconv(cont4_joy, analog_en[3]);
end

endmodule