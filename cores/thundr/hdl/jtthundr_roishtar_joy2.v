/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-3-2025 */

module jtthundr_roishtar_joy2(
    input               rst, clk,
                        vs, roishtar,
    input        [ 6:0] joystick1, joystick2,
    input        [15:0] joyana_r1,
    output reg   [ 6:0] merged1, merged2
);

localparam JOY1_IS_KI=1'b0, JOY1_IS_GIL=1'b1;

wire sel;
reg [6:0] mux1,mux2;

jtframe_toggle #(.W(1)) u_toggle(
    .rst    ( rst       ),
    .clk    ( clk       ),

    .toggle ( joystick1[6] ),
    .q      ( sel       )
);

wire [15:0] multi;

always @(posedge clk) begin
    case(sel)
        JOY1_IS_KI:  {mux1,mux2} <= {joystick1,joystick2};
        JOY1_IS_GIL: {mux1,mux2} <= {joystick2,joystick1};
    endcase
    // buttons are not multiplexed as Ki is the only one that can use buttons
    merged1 <= { joystick1[6:4], roishtar ?  mux1 [3:0] : joystick1[3:0] };
    merged2 <= { joystick2[6:4], roishtar ? ~multi[3:0] : joystick2[3:0] };
end

jtframe_multiway u_multiway(
    .clk        ( clk               ),
    .vs         ( vs                ),
    .ana1       ( joyana_r1         ),
    .ana2       ( 16'd0             ),
    .raw1       ( {9'h0,~mux2}      ),
    .raw2       ( 16'hffff          ),
    .joy1       ( multi             ),
    .joy2       (                   )
);

endmodule