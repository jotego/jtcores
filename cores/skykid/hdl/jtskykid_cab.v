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

localparam [2:0] UNUSED=3'b111;

reg [2:0] sel=0;

always @(posedge clk) begin
    if( (p1_dout&8'he0)==8'h60 ) sel <= p1_dout[2:0];
    case(sel)
        0: cab <= {UNUSED,dipsw[15:11]};
        1: cab <= {UNUSED,dipsw[10:8],dipsw[7:6]};
        2: cab <= {UNUSED,dipsw[ 5:1]};
        3: cab <= {UNUSED,dipsw[0],joystick1[5],joystick2[5],dipsw[17:16]};
        4: cab <= {UNUSED,cab_1p,coin,service};
        5: cab <= {UNUSED,joystick2[4:0]};
        6: cab <= {UNUSED,joystick1[4:0]};
        default: cab <= 8'hff;
    endcase
end

endmodule
