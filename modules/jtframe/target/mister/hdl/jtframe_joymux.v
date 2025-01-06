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
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 24-10-2021 */

module jtframe_joymux(
    input             rst,
    input             clk,
    output reg        show_osd,

    // MiSTer pins
    input      [ 6:0] USER_IN,
    output     [ 6:0] USER_OUT,

    // joystick mux
    input             db15_en,
    input      [15:0] joyusb_1,
    input      [15:0] joyusb_2,
    output reg [15:0] joymux_1,
    output reg [15:0] joymux_2
);

parameter BUTTONS = 2;

// same as defined in jtframe_inputs
localparam START_BIT  = 6+(BUTTONS-2);
localparam COIN_BIT   = 7+(BUTTONS-2);


wire [15:0] joydb15_1,joydb15_2;
wire        joy_din, joy_clk, joy_load;

assign USER_OUT = db15_en ? { 5'h1f, joy_clk, joy_load } : 7'h7f;
assign joy_din  = USER_IN[5];

function [15:0] assign_joy(
    input [15:0] joydb,
    input [15:0] joyusb
);
    if( db15_en ) begin
        assign_joy = 0;
        assign_joy[BUTTONS+3:0] = joydb[BUTTONS+3:0];
        assign_joy[COIN_BIT]    = joydb[11]; // select
        assign_joy[START_BIT]   = joydb[10]; // start
    end else begin
        assign_joy = joyusb;
    end
endfunction

always @(posedge clk) begin
    joymux_1 <= assign_joy( joydb15_1, joyusb_1 );
    joymux_2 <= assign_joy( joydb15_2, joyusb_2 );
    show_osd <= db15_en & ((joydb15_1[10] & joydb15_1[6]) | (joydb15_2[10]&joydb15_2[6]));
end

joy_db15 u_db15
(
  .clk       ( clk       ), //48MHz
  .JOY_CLK   ( joy_clk   ),
  .JOY_DATA  ( joy_din   ),
  .JOY_LOAD  ( joy_load  ),
  .joystick1 ( joydb15_1 ),
  .joystick2 ( joydb15_2 )    
);

endmodule