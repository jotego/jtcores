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
    Date: 28-1-2025 */

module jtframe_joysticks(
    input             rst, clk,
                      vs,  locked,
                      rot, rot_ccw,

    input       [3:0] board_coin, board_start,
                      key_coin,   key_start,
                      joy_coin,   joy_start,
    input             key_service,key_tilt,  key_reset,

    input      [15:0] ana1, ana2,
                      board_joy1, board_joy2, board_joy3, board_joy4,
    input       [9:0] key_joy1, key_joy2, key_joy3, key_joy4,
    input             joy_test, key_test,

    input       [2:0] mouse_but_1p, mouse_but_2p,

    output      [5:0] recjoy1,

    output      [9:0] game_joy1, game_joy2, game_joy3, game_joy4,
                      lock_joy1,
    output      [3:0] game_coin, game_start,
    output            game_test, game_service, game_tilt,
                      soft_rst
);

    wire [15:0] multi1, multi2;
    wire [ 9:0] rot_joy1,   rot_joy2,   rot_joy3,   rot_joy4,
                merge_joy1, merge_joy2, merge_joy3, merge_joy4,
                            lock_joy2,  lock_joy3,  lock_joy4;
    wire [ 3:0] merge_coin, merge_start;
    wire        merge_service;

    assign recjoy1 = ~merge_joy1[5:0];

    jtframe_edge u_rst(
        .rst    ( rst       ),
        .clk    ( clk       ),
        .edgeof ( key_reset ),
        .clr    ( vs        ),
        .q      ( soft_rst  )
    );

    jtframe_multiway u_multiway(
        .clk        ( clk        ),
        .vs         ( vs         ),
        .ana1       ( ana1       ),
        .ana2       ( ana2       ),
        .raw1       ( board_joy1 ),
        .raw2       ( board_joy2 ),
        .joy1       ( multi1     ),
        .joy2       ( multi2     )
    );

    jtframe_merge_keyjoy u_merge(
        .rst        ( rst           ),
        .clk        ( clk           ),

        .board_coin ( board_coin    ),
        .board_start( board_start   ),
        .key_coin   ( key_coin      ),
        .key_start  ( key_start     ),
        .key_tilt   ( key_tilt      ),
        .joy_coin   ( joy_coin      ),
        .joy_start  ( joy_start     ),

        .joy1       ( multi1        ),
        .joy2       ( multi2        ),
        .joy3       ( board_joy3    ),
        .joy4       ( board_joy4    ),

        .key_joy1   ( key_joy1      ),
        .key_joy2   ( key_joy2      ),
        .key_joy3   ( key_joy3      ),
        .key_joy4   ( key_joy4      ),
        .joy_test   ( joy_test      ),
        .key_test   ( key_test      ),
        .key_service( key_service   ),

        .mouse_but_1p(mouse_but_1p  ),
        .mouse_but_2p(mouse_but_2p  ),

        .game_joy1  ( merge_joy1    ),
        .game_joy2  ( merge_joy2    ),
        .game_joy3  ( merge_joy3    ),
        .game_joy4  ( merge_joy4    ),
        .game_coin  ( merge_coin    ),
        .game_start ( merge_start   ),
        .game_test  ( game_test     ),
        .game_tilt  ( game_tilt     ),
        .game_service(merge_service )
    );

    jtframe_joy_rotate u_rotate(
        .clk        ( clk           ),
        .rot        ( rot           ),
        .rot_ccw    ( rot_ccw       ),
        .raw1       ( merge_joy1    ),
        .raw2       ( merge_joy2    ),
        .raw3       ( merge_joy3    ),
        .raw4       ( merge_joy4    ),
        .joy1       ( rot_joy1      ),
        .joy2       ( rot_joy2      ),
        .joy3       ( rot_joy3      ),
        .joy4       ( rot_joy4      )
    );

    jtframe_joystick_lock u_lock(
        .clk        ( clk           ),
        .locked     ( locked        ),

        .raw1       ( rot_joy1      ),
        .raw2       ( rot_joy2      ),
        .raw3       ( rot_joy3      ),
        .raw4       ( rot_joy4      ),
        .raw_start  ( merge_start   ),
        .raw_coin   ( merge_coin    ),
        .raw_service( merge_service ),

        .joy1       ( lock_joy1     ),
        .joy2       ( lock_joy2     ),
        .joy3       ( lock_joy3     ),
        .joy4       ( lock_joy4     ),
        .service    ( game_service  ),
        .coin       ( game_coin     ),
        .start      ( game_start    )
    );

    jtframe_joy_reorder u_reorder(
        .raw1       ( lock_joy1     ),
        .raw2       ( lock_joy2     ),
        .raw3       ( lock_joy3     ),
        .raw4       ( lock_joy4     ),
        .joy1       ( game_joy1     ),
        .joy2       ( game_joy2     ),
        .joy3       ( game_joy3     ),
        .joy4       ( game_joy4     )
    );
endmodule

module jtframe_merge_keyjoy(
    input             rst, clk,

    input       [3:0] board_coin, board_start,
    input       [3:0] key_coin,   key_start,
                      joy_coin,   joy_start,

    input      [15:0] joy1,     joy2,     joy3,     joy4,
    input       [9:0] key_joy1, key_joy2, key_joy3, key_joy4,
    input             joy_test, key_test, key_tilt, key_service,

    input       [2:0] mouse_but_1p, mouse_but_2p,

    // game signals are active low
    output reg  [9:0] game_joy1, game_joy2, game_joy3, game_joy4,
    output reg  [3:0] game_coin, game_start,
    output reg        game_test, game_tilt, game_service
);
    always @(posedge clk) begin
        if(rst) begin
            game_test    <= 1;
            game_tilt    <= 1;
            game_service <= 1;
            game_coin    <= 4'hf;
            game_start   <= 4'hf;
            game_joy1    <= 10'h3ff;
            game_joy2    <= 10'h3ff;
            game_joy3    <= 10'h3ff;
            game_joy4    <= 10'h3ff;
        end else begin
            game_test    <= ~(key_test  | joy_test);
            game_tilt    <= ~ key_tilt;
            game_service <= ~ key_service;

            game_coin    <= ~(joy_coin  | key_coin  | board_coin);
            game_start   <= ~(joy_start | key_start | board_start);
            game_joy1    <= ~(joy1[9:0] | key_joy1  | { 3'd0, mouse_but_1p, 4'd0});
            game_joy2    <= ~(joy2[9:0] | key_joy2  | { 3'd0, mouse_but_2p, 4'd0});
            game_joy3    <= ~(joy3[9:0] | key_joy3);
            game_joy4    <= ~(joy4[9:0] | key_joy4);
        end
    end
endmodule

module jtframe_joy_rotate(
    input       clk,
                rot, rot_ccw,
    input      [9:0] raw1, raw2, raw3, raw4,
    output reg [9:0] joy1, joy2, joy3, joy4
);
    function [9:0] apply_rotation(input [9:0] joy_in); begin
        reg [3:0] flipped;
        flipped = rot_ccw ?
             { joy_in[0], joy_in[1], joy_in[3], joy_in[2] }:
             { joy_in[1], joy_in[0], joy_in[2], joy_in[3] };
        apply_rotation[9:4] = joy_in[9:4];
        apply_rotation[3:0] = rot ? flipped : joy_in[3:0];
    end endfunction

    always @(posedge clk) begin
        joy1 <= apply_rotation( raw1 );
        joy2 <= apply_rotation( raw2 );
        joy3 <= apply_rotation( raw3 );
        joy4 <= apply_rotation( raw4 );
    end
endmodule

module jtframe_joy_reorder(
    input  [9:0] raw1, raw2, raw3, raw4,
    output [9:0] joy1, joy2, joy3, joy4
);
    function [9:0] reorder;
        input [9:0] joy_in;
        begin
            reorder = joy_in; // default order up, down, left, right
    `ifdef JTFRAME_JOY_LRUD reorder[3:0]={joy_in[1:0], joy_in[3:2]}; `endif
    `ifdef JTFRAME_JOY_UDRL reorder[3:0]={joy_in[3:2], joy_in[0], joy_in[1]}; `endif
    `ifdef JTFRAME_JOY_RLDU reorder[3:0]={joy_in[0], joy_in[1], joy_in[2], joy_in[3]}; `endif
    `ifdef JTFRAME_JOY_DURL reorder[3:0]={joy_in[2], joy_in[3], joy_in[0], joy_in[1]}; `endif
    `ifdef JTFRAME_JOY_DULR reorder[3:0]={joy_in[2], joy_in[3], joy_in[1], joy_in[0]}; `endif
    `ifdef JTFRAME_JOY_B1B0 reorder[5:4]={joy_in[4], joy_in[5]}; `endif
        end
    endfunction

    assign joy1 = reorder(raw1);
    assign joy2 = reorder(raw2);
    assign joy3 = reorder(raw3);
    assign joy4 = reorder(raw4);
endmodule
