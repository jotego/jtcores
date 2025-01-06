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
    Date: 12-6-2021 */



module jtframe_neptuno_joy(
  
    input         clk,
    input         reset,

    input  [5:0]  joy1_bus,
    input  [5:0]  joy2_bus,
    output        joy_select,
    
    input         ps2_kbd_clk,
    input         ps2_kbd_data,
    input  [3:0]  BUTTON_n,

    output [11:0] joy1,
    output [11:0] joy2,
    output [8:0]  controls,
    
    output [7:0]  osd,
    output        mc_reset,
    output        toggle_scandb

);

wire [11:0] inv1, inv2;
wire [ 7:0] osd_s;
wire [ 8:0] controls_s;
wire [ 3:0] btn_n_s;

/*
wire P1coin_s, P2coin_s, P1start_s, P2start_s;

assign P1coin_s  = ~btn_n_s[2] | controls_s[4];
assign P2coin_s  = ~btn_n_s[2] | controls_s[5];
assign P1start_s = ~btn_n_s[0] | controls_s[0];
assign P2start_s = ~btn_n_s[1] | controls_s[1];

//assign joy1 = { inv1[11], inv1[7], inv1[10], inv1[9], inv1[8] | P1coin_s, inv1[5] | P1start_s, inv1[4], inv1[6], inv1[3:0] };
//assign joy2 = { inv2[11], inv2[7], inv2[10], inv2[9], inv2[8] | P2coin_s, inv2[5] | P2start_s, inv2[4], inv2[6], inv2[3:0] };
*/

// MX YZS ACB UDLR // hid module joystick bus output
// MS XYZ ABC UDLR // default button positions for jtframe
// BA 987 654 3210
assign joy1 = { inv1[11], inv1[7], inv1[10], inv1[9], inv1[8], inv1[5], inv1[4], inv1[6], inv1[3:0] };
assign joy2 = { inv2[11], inv2[7], inv2[10], inv2[9], inv2[8], inv2[5], inv2[4], inv2[6], inv2[3:0] };
assign controls = { controls_s[8:5], ~btn_n_s[2] | controls_s[4], controls_s[3:2], ~btn_n_s[1] | controls_s[1], ~btn_n_s[0] | controls_s[0] };

assign osd = osd_s;
assign mc_reset = ~btn_n_s[3];

`ifdef JTFRAME_CLK96 
    `define CLK_SPEED 96000
`else
    `define CLK_SPEED 48000
`endif

MC2_HID #( .CLK_SPEED( `CLK_SPEED ) ) u_hid
(
    .clk_i          ( clk          ),
    .reset_i        ( reset        ),
    .kbd_clk_i      ( ps2_kbd_clk  ),
    .kbd_dat_i      ( ps2_kbd_data ),
    
    .joystick_0_i   ( joy1_bus     ),
    .joystick_1_i   ( joy2_bus     ),
      
    //-- tilt, coin4-1, start4-1
    .controls_o     ( controls_s   ),

    //-- fire12-1, up, down, left, right

    .player1_o      ( inv1         ),
    .player2_o      ( inv2         ),

    //-- keys to the OSD
    .osd_o          ( osd_s        ),
    .osd_enable_i   ( 1'b1         ), //osd_enable ), //ideally we need to know when the OSD is open
    
    .toggle_scandb_o(toggle_scandb ),
    
    //-- sega joystick strobe pin
    .sega_strobe_o  ( joy_select  ),

    //-- Front buttons
    .front_buttons_i( BUTTON_n    ),
    .front_buttons_o( btn_n_s     )
);

endmodule
