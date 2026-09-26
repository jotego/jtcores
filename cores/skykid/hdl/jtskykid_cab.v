/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-9-2026 */

module jtskykid_cab(
    input               clk,

    input        [ 7:0] p1_dout,
    input        [19:0] dipsw,
    input        [ 5:0] joystick1, joystick2,
    input        [ 1:0] cab_1p, coin,
    input               service,

    output reg   [ 7:0] cab=8'hff
);

localparam UP=3,DOWN=2,LEFT=1,RIGHT=0,B0=4,B1=5;
localparam [2:0] UNUSED=3'b111;

reg [2:0] sel=0;

always @(posedge clk) begin
    if( (p1_dout&8'he0)==8'h60 ) sel <= p1_dout[2:0];
    case(sel)
        0: cab <= {UNUSED,dipsw[15:11]};
        1: cab <= {UNUSED,dipsw[10:8],dipsw[7:6]};
        2: cab <= {UNUSED,dipsw[ 5:1]};
        3: cab <= {UNUSED,dipsw[0],joystick1[B1],joystick2[B1],dipsw[17:16]};
        4: cab <= {UNUSED,cab_1p,coin,service};
        5: cab <= {UNUSED,joystick2[B0],joystick2[UP],joystick2[DOWN],joystick2[RIGHT],joystick2[LEFT]};
        6: cab <= {UNUSED,joystick1[B0],joystick1[UP],joystick1[DOWN],joystick1[RIGHT],joystick1[LEFT]};
        default: cab <= 8'hff;
    endcase
end

endmodule
