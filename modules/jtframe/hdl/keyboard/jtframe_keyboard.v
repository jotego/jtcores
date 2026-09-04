/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-2-2019 */

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