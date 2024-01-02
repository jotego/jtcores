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
    
/* Stripped down version of jtframe_neptuno_io.v for
   direct joystick management with DeMiSTify board targets  
   15-04-2023 by @somhi  */    
    

module jtframe_demistify_joy(
    input          sdram_init,
    input          clk_sys,
    input          hs,

    // DB9 Joysticks
    input    [5:0] joy1_bus,
    input    [5:0] joy2_bus,
    output         JOY_SELECT,

    output  [11:0] joystick1,
    output  [11:0] joystick2,

    //output         scan2x_enb,
    output         scan2x_toggle,
    output         osd_en
);


localparam [4:0] NEPT_KEY_UP     = 30,
                 NEPT_KEY_DOWN   = 29,
                 NEPT_KEY_LEFT   = 27,
                 NEPT_KEY_RIGHT  = 23,
                 NEPT_KEY_RETURN = 15;
localparam [2:0] NEPT_CMD_NOP = 3'b111,
                 NEPT_CMD_OSD = 3'b011;

reg [4:0] nept_key;
reg [2:0] nept_cmd;

wire [11:0] joy_mix = joystick1[11:0] | joystick2[11:0];

// Joy buttons position
// =S XY| CBA UDLR // tested  (= no M key on my gamepad,  | no response from Z)
// BA 987 654 3210

wire osd_en_in = joy_mix[10] & joy_mix[4];  // Start + A buttons of Megadrive controller
wire osd_en_filt;

jtframe_enlarger #(4) u_enlarger(
    .rst        ( sdram_init    ),
    .clk        ( clk_sys       ),
    .cen        ( hs            ),
    .pulse_in   ( osd_en_in     ),
    .pulse_out  ( osd_en_filt   )
);

assign osd_en = osd_en_filt;

always @(*) begin
    case( 1'b1 )
        joy_mix[0]: nept_key = NEPT_KEY_RIGHT;
        joy_mix[1]: nept_key = NEPT_KEY_LEFT;
        joy_mix[2]: nept_key = NEPT_KEY_DOWN;
        joy_mix[3]: nept_key = NEPT_KEY_UP;
        joy_mix[4]: nept_key = NEPT_KEY_RETURN;
        default: nept_key = 5'h1f;
    endcase
    // Bring up OSD if three buttons are pressed
    nept_cmd = osd_en_filt ? NEPT_CMD_OSD : NEPT_CMD_NOP;
end

assign scan2x_toggle = joy_mix[10] & joy_mix[9]; // Start + X buttons
// TODO: manage scan2x_toggle to toggle scan doubler  scan2x_enb  signal


//////////////////////////////////////////////////////
//  Next section extracte from jtframe_neptuno_joy  // 
//////////////////////////////////////////////////////

wire [11:0] inv1, inv2;

// MX YZS ACB UDLR // hid module joystick bus output
// MS XYZ ABC UDLR // default button positions for jtframe
// BA 987 654 3210

assign joystick1 = { inv1[11], inv1[7], inv1[10], inv1[9], inv1[8], inv1[5], inv1[4], inv1[6], inv1[3:0] };
assign joystick2 = { inv2[11], inv2[7], inv2[10], inv2[9], inv2[8], inv2[5], inv2[4], inv2[6], inv2[3:0] };


`ifdef JTFRAME_CLK96 
    `define CLK_SPEED 96000
`else
    `define CLK_SPEED 48000
`endif

MC2_HID_JOY #( .CLK_SPEED( `CLK_SPEED ) ) u_hid
(
    .clk_i          ( clk_sys          ),
    .reset_i        ( sdram_init        ),
    
    .joystick_0_i   ( joy1_bus     ),
    .joystick_1_i   ( joy2_bus     ),
      
    //-- fire12-1, up, down, left, right
    .player1_o      ( inv1         ),
    .player2_o      ( inv2         ),
    
    //-- sega joystick strobe pin
    .sega_strobe_o  ( JOY_SELECT  )
);



endmodule
