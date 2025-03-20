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
    input             lhbl,

    input             rot,
    input      [1:0]  rotate,
    input             dial_raw_en,
    input             dial_reverse,
    input             dip_pause,

    output            soft_rst,
    output            game_pause,

    input      [15:0] board_joy1, board_joy2, board_joy3, board_joy4, ana1, ana2,
    input       [3:0] board_coin, board_start,

    input       [9:0] key_joy1, key_joy2, key_joy3, key_joy4,
    input       [3:0] key_start,   key_coin,
    input             key_service, key_test, key_tilt,
                      key_ctrl,    key_shift, key_plus, key_minus,
    input      [12:7] func_key,

    input             key_pause,
    input             osd_pause,
    input             key_reset,

    output      [9:0] game_joy1, game_joy2, game_joy3, game_joy4,
    output      [3:0] game_coin, game_start,
    output            game_service,
    output            game_test,
    output            game_tilt,
    output            locked, // disable joystick inputs

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

    // Lightguns
    output      [ 8:0] gun_1p_x, gun_1p_y, gun_2p_x, gun_2p_y,
                       cross1_x, cross1_y, cross2_x, cross2_y,
    output      [ 1:0] cross_disable,
    input              gun_crossh_en,

    input       [ 7:0] debug_bus,
    input              ioctl_lock,

    // input data recording
    input       [12:0] ioctl_addr,
    input       [ 7:0] ioctl_din,
    input       [ 7:0] ioctl_dout,
    input              ioctl_wr,
    output      [ 7:0] ioctl_merged,
    // debug
    output       [3:0] gfx_en,
    output       [5:0] snd_en,

    output             debug_toggle,
    output       [1:0] debug_plus,
    output       [1:0] debug_minus,
    // For simulation only
    input              ioctl_rom
);

parameter BUTTONS    = 2, WIDTH = 384, HEIGHT = 224;

wire [ 2:0] mouse_but_1p, mouse_but_2p;
wire [ 5:0] recjoy1;
wire [ 9:0] lock_joy1;

// This one passes unfiltered
assign  game_paddle_2 = board_paddle_2;

localparam START_BIT  = 6+(BUTTONS-2);
localparam COIN_BIT   = START_BIT+1;
localparam PAUSE_BIT  = COIN_BIT+1;

reg        joy_pause=0, joy_test=0;
wire [3:0] joy_start, joy_coin;

`ifdef POCKET   // The Pocket only uses the small buttons at the front for these functions
    always @(posedge clk) begin
        joy_pause <= board_coin[0] & board_joy1[4];
        joy_test  <= board_coin[0] & board_joy1[5];
    end
    assign joy_start = 0;
    assign joy_coin  = 0;
`else
    always @(posedge clk) begin
        joy_pause <= board_joy1[PAUSE_BIT] | board_joy2[PAUSE_BIT] | board_joy3[PAUSE_BIT] | board_joy4[PAUSE_BIT];
    end
    assign joy_start = { board_joy4[START_BIT], board_joy3[START_BIT], board_joy2[START_BIT], board_joy1[START_BIT]};
    assign joy_coin  = { board_joy4[COIN_BIT] , board_joy3[COIN_BIT] , board_joy2[COIN_BIT] , board_joy1[COIN_BIT]};
`endif

jtframe_joysticks u_joysticks(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .vs         ( vs            ),
    .rot        ( rot           ),
    .rot_ccw    ( rotate[1]     ),
    .locked     ( locked        ),

    .board_coin ( board_coin    ),
    .board_start( board_start   ),
    .key_coin   ( key_coin      ),
    .key_start  ( key_start     ),
    .key_service( key_service   ),
    .key_reset  ( key_reset     ),
    .joy_coin   ( joy_coin      ),
    .joy_start  ( joy_start     ),

    .ana1       ( ana1          ),
    .ana2       ( ana2          ),
    .board_joy1 ( board_joy1    ),
    .board_joy2 ( board_joy2    ),
    .board_joy3 ( board_joy3    ),
    .board_joy4 ( board_joy4    ),
    .key_joy1   ( key_joy1      ),
    .key_joy2   ( key_joy2      ),
    .key_joy3   ( key_joy3      ),
    .key_joy4   ( key_joy4      ),
    .joy_test   ( joy_test      ),
    .key_test   ( key_test      ),
    .key_tilt   ( key_tilt      ),

    .mouse_but_1p( mouse_but_1p ),
    .mouse_but_2p( mouse_but_2p ),

    .recjoy1    ( recjoy1       ),
    .lock_joy1  ( lock_joy1     ),
    .game_joy1  ( game_joy1     ),
    .game_joy2  ( game_joy2     ),
    .game_joy3  ( game_joy3     ),
    .game_joy4  ( game_joy4     ),

    .game_coin  ( game_coin     ),
    .game_start ( game_start    ),
    .game_test  ( game_test     ),
    .game_tilt  ( game_tilt     ),
    .game_service(game_service  ),
    .soft_rst   ( soft_rst      )
);

jtframe_debug_keys u_debugkeys(
    .rst        ( rst           ),
    .clk        ( clk           ),

    .ctrl       ( key_ctrl      ),
    .shift      ( key_shift     ),
    .func_key   ( func_key      ),
    .coin_n     ( game_coin[0]  ),
    .start_n    ( game_start[0] ),
    .joy_n      ( lock_joy1     ),
    .plus       ( key_plus      ),
    .minus      ( key_minus     ),

    .gfx_en     ( gfx_en        ),
    .snd_en     ( snd_en        ),

    .debug_toggle( debug_toggle ),
    .debug_plus ( debug_plus    ),
    .debug_minus( debug_minus   )
);

jtframe_pause u_pause(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .key_pause  ( key_pause     ),
    .joy_pause  ( joy_pause     ),
    .osd_pause  ( osd_pause     ),
    .adv_frame  ( key_service   ),
    .lvbl       ( lvbl          ),
    .game_pause ( game_pause    )
);

// Dial emulation
jtframe_dial u_dial(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .lhbl       ( lhbl          ),

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
    .joyn1      (game_joy1[3:0]),
    .joyn2      (game_joy2[3:0]),

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

jtframe_lightgun #(.WIDTH(WIDTH), .HEIGHT(HEIGHT)
) u_lightgun(
    .rst          ( rst           ),
    .clk          ( clk           ),
    .vs           ( vs            ),
    .gun_crossh_en( gun_crossh_en ),
    .rotate       ( rotate        ),
    .cross_disable( cross_disable ),
    .mouse_1p     ( mouse_1p      ),
    .mouse_2p     ( mouse_2p      ),
    .joyana1      ( ana1          ),
    .joyana2      ( ana2          ),
    .mouse_strobe ( mouse_strobe  ),
    .gun_1p_x     ( gun_1p_x      ),
    .gun_1p_y     ( gun_1p_y      ),
    .gun_2p_x     ( gun_2p_x      ),
    .gun_2p_y     ( gun_2p_y      ),
    .cross1_x     ( cross1_x      ),
    .cross1_y     ( cross1_y      ),
    .cross2_x     ( cross2_x      ),
    .cross2_y     ( cross2_y      )
);

jtframe_beta_lock u_lock(
    .clk        ( clk           ),
    .ioctl_lock ( ioctl_lock    ),
    .ioctl_addr (ioctl_addr[1:0]),
    .ioctl_dout ( ioctl_dout    ),
    .ioctl_wr   ( ioctl_wr      ),
    .locked     ( locked        )
);

// Record user inputs
localparam RECAW=`ifdef JTFRAME_INPUT_RECORD_AW `JTFRAME_INPUT_RECORD_AW `else 8 `endif;

jtframe_rec_inputs #(
    .RECAW     ( RECAW      )
) u_rec(
    .rst            ( rst           ),
    .clk            ( clk           ),

    .vs             ( vs            ),
    .dip_pause      ( dip_pause     ),

    .game_start     ( game_start    ),
    .game_coin      ( game_coin     ),
    .joystick       ( recjoy1       ),

    .ioctl_addr     ( ioctl_addr    ),
    .ioctl_din      ( ioctl_din     ),
    .ioctl_merged   ( ioctl_merged  )
);

endmodule