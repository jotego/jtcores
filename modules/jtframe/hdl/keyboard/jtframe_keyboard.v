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
    Date: 4-2-2019 */

module jtframe_keyboard(
    input            clk,
    input            rst,
    // ps2 interface
    input            ps2_clk,
    input            ps2_data,
    // decoded keys
    output     [9:0] joy1,
    output     [9:0] joy2,
    output     [9:0] joy3,
    output     [9:0] joy4,
    output     [3:0] start,
    output     [3:0] coin,
    output     [7:0] digit,
    output    [12:7] func_key,
    output           reset,
    output           pause,
    output           tilt,
    output           test,
    output           service,
    output           vol_up,
    output           vol_down,

    output           shift,
    output           ctrl,
    output           alt,
    output           plus,
    output           minus
);

wire       valid, error;
wire [7:0] ps2byte;

assign shift = joy1[7] | joy3[5];
assign ctrl  = joy1[4] | joy3[4];
assign alt   = joy1[5];

jtframe_ps2key_decoder u_ps2key_decoder(
    .clk            ( clk           ),
    .rst            ( rst           ),

    .ps2byte        ( ps2byte       ),
    .valid          ( valid         ),
    .shift          ( shift         ),

    .joy1           ( joy1          ),
    .joy2           ( joy2          ),
    .joy3           ( joy3          ),
    .joy4           ( joy4          ),
    .start          ( start         ),
    .coin           ( coin          ),
    .digit          ( digit         ),
    .reset          ( reset         ),
    .pause          ( pause         ),
    .tilt           ( tilt          ),
    .test           ( test          ),
    .service        ( service       ),
    .vol_up         ( vol_up        ),
    .vol_down       ( vol_down      ),
    .func_key       ( func_key      ),
    .plus           ( plus          ),
    .minus          ( minus         )
);

// the ps2 decoder has been taken from the zx spectrum core
ps2_intf_v ps2_keyboard (
    .CLK      (  clk      ),
    .nRESET   ( ~rst      ),

    // PS/2 interface
    .PS2_CLK  ( ps2_clk   ),
    .PS2_DATA ( ps2_data  ),

    // ps2byte-wide data interface - only valid for one clock
    // so must be latched externally if required
    .DATA     ( ps2byte   ),
    .VALID    ( valid     ),
    .ERROR    ( error     )
);

endmodule