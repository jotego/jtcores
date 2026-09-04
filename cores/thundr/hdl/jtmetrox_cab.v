/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-5-2025 */

module jtmetrox_cab(
    input               clk,

    input        [ 7:0] p1_dout,

    input        [19:0] dipsw,
    input        [ 6:0] joystick1, joystick2,
    input        [ 1:0] cab_1p,
    input        [ 1:0] coin,
    input               service,

    output reg   [ 7:0] cab=0
);

localparam UP=3,DOWN=2,LEFT=1,RIGHT=0,B0=4,B1=5,B2=6;
localparam [2:0] UNUSED=3'b111;

reg [2:0] sel;

always @(posedge clk) begin
    if(&p1_dout[7:5]) sel=p1_dout[2:0];
    case(sel)
        0: cab <= {UNUSED,dipsw[4:0]};
        1: cab <= {UNUSED,dipsw[7:5],dipsw[9:8]};
        2: cab <= {UNUSED,dipsw[14:10]};
        3: cab <= {UNUSED,dipsw[15],dipsw[19:16]};
        4: cab <= {UNUSED,cab_1p,coin,service}; // IN0
        5: cab <= {UNUSED,joystick2[B0],joystick2[UP],joystick2[DOWN],joystick2[RIGHT],joystick2[LEFT]};  // IN1
        6: cab <= {UNUSED,joystick1[B0],joystick1[UP],joystick1[DOWN],joystick1[RIGHT],joystick1[LEFT]};  // IN2
        default: cab <= 8'hff;
    endcase
end

endmodule
