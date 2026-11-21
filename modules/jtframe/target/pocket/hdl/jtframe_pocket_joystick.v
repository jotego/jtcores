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
    input      [23:0] button_map,
    input      [15:0] cont1,     cont2,     cont3,     cont4,
    input      [31:0] cont1_joy, cont2_joy, cont3_joy, cont4_joy,
    input      [ 3:0] analog_en,
    // SNAC analog sticks (jtframe_analogizer, JTFRAME joyana format) and the controller
    // paired with each player (jtframe_pocket_ctrlmux): a player paired with SNAC
    // controller n gets its sticks instead of the Pocket controller ones
    input      [15:0] snac_joyana_l1, snac_joyana_r1, snac_joyana_l2, snac_joyana_r2,
                      snac_joyana_l3, snac_joyana_r3, snac_joyana_l4, snac_joyana_r4,
    input      [11:0] act_plyr,     // { player 4 .. player 1 }, bit 2 = SNAC, [1:0] = SNAC index
    input      [ 3:0] paired_plyr,
    output reg [15:0] joystick1, joystick2, joystick3, joystick4,
                      joyana_l1, joyana_l2, joyana_l3, joyana_l4,
                      joyana_r1, joyana_r2, joyana_r3, joyana_r4
);

// Convert Pocket inputs to JTFRAME standard
function [15:0] joyconv( input [15:0] joy_in, input [23:0] mapping );
    integer k;
    reg [3:0] key;
begin
    joyconv = { 2'd0,
        joy_in[13:4],  joy_in[0],  joy_in[1],  joy_in[2],  joy_in[3]  };
    for( k=0; k<6; k=k+1 ) begin
        key = mapping[(k<<2)+:4];
        joyconv[k+4] = key<4'd6 ? joy_in[4'd4+key] : 1'b0;
    end
end
endfunction

function [31:0] joyanaconv( input [31:0] cont_joy, input en );
    joyanaconv[ 7: 0] = cont_joy[ 7: 0]-8'h80;
    joyanaconv[15: 8] = cont_joy[15: 8]-8'h80;
    joyanaconv[23:16] = cont_joy[23:16]-8'h80;
    joyanaconv[31:24] = cont_joy[31:24]-8'h80;
    if(!en) joyanaconv = 0;
endfunction

// Pocket controller sticks, or the SNAC ones for a player paired with a SNAC controller.
// Every signal used is an argument (functions in continuous logic, see Questa)
function [31:0] plyrana( input [31:0] pocket, input [31:0] snac1, input [31:0] snac2,
                         input [31:0] snac3, input [31:0] snac4, input [2:0] act, input paired );
    if( !paired || !act[2] ) plyrana = pocket;
    else case( act[1:0] )
        0: plyrana = snac1;
        1: plyrana = snac2;
        2: plyrana = snac3;
        3: plyrana = snac4;
    endcase
endfunction

wire [31:0] snac_joy1 = { snac_joyana_r1, snac_joyana_l1 },  // {right, left} of each SNAC player
            snac_joy2 = { snac_joyana_r2, snac_joyana_l2 },
            snac_joy3 = { snac_joyana_r3, snac_joyana_l3 },
            snac_joy4 = { snac_joyana_r4, snac_joyana_l4 };

always @(posedge clk_sys) begin
    joystick1 <= joyconv(cont1,button_map);
    joystick2 <= joyconv(cont2,button_map);
    joystick3 <= joyconv(cont3,button_map);
    joystick4 <= joyconv(cont4,button_map);
    { joyana_r1, joyana_l1 } <= plyrana( joyanaconv(cont1_joy, analog_en[0]),
                                snac_joy1, snac_joy2, snac_joy3, snac_joy4, act_plyr[ 2:0], paired_plyr[0] );
    { joyana_r2, joyana_l2 } <= plyrana( joyanaconv(cont2_joy, analog_en[1]),
                                snac_joy1, snac_joy2, snac_joy3, snac_joy4, act_plyr[ 5:3], paired_plyr[1] );
    { joyana_r3, joyana_l3 } <= plyrana( joyanaconv(cont3_joy, analog_en[2]),
                                snac_joy1, snac_joy2, snac_joy3, snac_joy4, act_plyr[ 8:6], paired_plyr[2] );
    { joyana_r4, joyana_l4 } <= plyrana( joyanaconv(cont4_joy, analog_en[3]),
                                snac_joy1, snac_joy2, snac_joy3, snac_joy4, act_plyr[11:9], paired_plyr[3] );
end

endmodule
