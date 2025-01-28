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
    Date: 10-5-2021 */

module jtframe_inputs(
    input             rst,
    input             clk,
    input             vs,
    input             lvbl,
    input             LHBL,

    input             rot_ccw,
    input             autofire0,
    input             dial_raw_en,
    input             dial_reverse,
    input             dip_pause,

    output reg        soft_rst,
    output            game_pause,

    input      [15:0] board_joy1, board_joy2, board_joy3, board_joy4, ana1, ana2,
    input       [3:0] board_coin, board_start,

    input       [9:0] key_joy1, key_joy2, key_joy3, key_joy4,
    input       [3:0] key_start, key_coin,
    input             key_service,
    input             key_test,
    input             key_tilt,

    input             key_pause,
    input             osd_pause,
    input             key_reset,
    input             rot_control,

    output reg  [9:0] game_joy1, game_joy2, game_joy3, game_joy4,
    output reg  [3:0] game_coin, game_start,
    output reg        game_service,
    output reg        game_test,
    output reg        game_tilt,
    output reg        locked, // disable joystick inputs

    // Mouse & Paddle
    input signed [8:0] bd_mouse_dx, bd_mouse_dy,
    input        [7:0] bd_mouse_f,
    input              bd_mouse_st,     // a pulse signals a mouse update
    input              bd_mouse_idx,

    input       [ 7:0] board_paddle_1, board_paddle_2,
    input       [ 1:0] sensty,
    input       [ 8:0] spinner_1,      spinner_2,

    output      [15:0] mouse_1p, mouse_2p,
    output      [ 1:0] mouse_strobe,
    output      [ 7:0] game_paddle_1, game_paddle_2,
    output      [ 1:0] dial_x, dial_y,

    input       [ 7:0] debug_bus,
    input              ioctl_lock,

    // input data recording
    input       [12:0] ioctl_addr,
    input       [ 7:0] ioctl_din,
    input       [ 7:0] ioctl_dout,
    input              ioctl_wr,
    output      [ 7:0] ioctl_merged,
    // For simulation only
    input              ioctl_rom
);

parameter BUTTONS    = 2,
          ACTIVE_LOW = 1;

reg  [15:0] joy1_sync, joy2_sync, joy3_sync, joy4_sync;
wire [15:0] multi1, multi2;
wire [ 3:0] joy4way1p, joy4way2p, joy4way3p, joy4way4p;
wire [ 2:0] mouse_but_1p, mouse_but_2p;
wire [ 9:0] pre_order1;


// This one passes unfiltered
assign game_paddle_2 = board_paddle_2;

localparam START_BIT  = 6+(BUTTONS-2);
localparam COIN_BIT   = START_BIT+1;
localparam PAUSE_BIT  = COIN_BIT+1;

reg        last_reset;
wire       joy_pause, joy_test;
wire [3:0] joy_start, joy_coin;
wire       vbl_in, vbl_out;
reg        autofire;
reg  [2:0] firecnt;

`ifdef POCKET   // The Pocket only uses the small buttons at the front for these functions
    assign joy_pause = board_coin[0] & board_joy1[4];
    assign joy_test  = board_coin[0] & board_joy1[5];
    assign joy_start = 0;
    assign joy_coin  = 0;
`else
    assign joy_pause = multi1[PAUSE_BIT] | multi2[PAUSE_BIT] | joy3_sync[PAUSE_BIT] | joy4_sync[PAUSE_BIT];
    assign joy_start = { joy4_sync[START_BIT], joy3_sync[START_BIT], multi2[START_BIT], multi1[START_BIT]};
    assign joy_coin  = { joy4_sync[COIN_BIT] , joy3_sync[COIN_BIT] , multi2[COIN_BIT] , multi1[COIN_BIT]};
    assign joy_test  = 0;
`endif


jtframe_pause u_pause(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .key_pause  ( key_pause     ),
    .joy_pause  ( joy_pause     ),
    .osd_pause  ( osd_pause     ),
    .service    ( key_service   ),
    .lvbl       ( lvbl          ),
    .game_pause ( game_pause    )
);

// Dial emulation
jtframe_dial u_dial(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .LHBL       ( LHBL          ),

    // with spinner
    .spinner_1  ( spinner_1     ),
    .spinner_2  ( spinner_2     ),
    .sensty     ( sensty        ),
    .raw        ( dial_raw_en   ),
    .reverse    ( dial_reverse  ),

    // with joystick or mouse
    .joystick1  ( game_joy1     ),
    .joystick2  ( game_joy2     ),
    .mouse_st   ( bd_mouse_st    ),
    .mouse_dx   ( bd_mouse_dx   ),
    .mouse_dy   ( bd_mouse_dy   ),

    .dial_x     ( dial_x        ),
    .dial_y     ( dial_y        )
);

// Paddle emulation using the mouse
jtframe_paddle u_paddle(
    .rst        ( rst            ),
    .clk        ( clk            ),
    .hw_paddle  ( board_paddle_1 ),
    .mouse_dx   ( bd_mouse_dx    ),
    .mouse_st   ( bd_mouse_st    ),
    .paddle     ( game_paddle_1  )
);

jtframe_mouse u_mouse(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .lock       ( locked       ),

    // Mouse emulation
    .joy1       ( game_joy1[3:0] ^ {4{ACTIVE_LOW[0]}} ),
    .joy2       ( game_joy2[3:0] ^ {4{ACTIVE_LOW[0]}} ),

    // Actual mouse input
    .mouse_dx   ( bd_mouse_dx  ),
    .mouse_dy   ( bd_mouse_dy  ),
    .mouse_f    ( bd_mouse_f   ),
    .mouse_st   ( bd_mouse_st  ),
    .mouse_idx  ( bd_mouse_idx ),
    .mouse_1p   ( mouse_1p     ),
    .mouse_2p   ( mouse_2p     ),
    .mouse_strobe(mouse_strobe ),
    .but_1p     ( mouse_but_1p ),
    .but_2p     ( mouse_but_2p )
);

// Record user inputs
`ifndef JTFRAME_RELEASE
`ifdef JTFRAME_INPUT_RECORD
    localparam RECAW=`JTFRAME_INPUT_RECORD_AW;

jtframe_rec_inputs #(
    .RECAW     ( RECAW      ),
    .ACTIVE_LOW( ACTIVE_LOW )
) u_rec(
    .rst            ( rst           ),
    .clk            ( clk           ),

    .vs             ( vs            ),
    .dip_pause      ( dip_pause     ),

    .game_start     ( game_start    ),
    .game_coin      ( game_coin     ),
    .joystick       (pre_order1[5:0]),

    .ioctl_addr     ( ioctl_addr    ),
    .ioctl_merged   ( ioctl_merged  )
);

`else assign ioctl_merged = ioctl_din; `endif
`else assign ioctl_merged = ioctl_din; `endif

endmodule