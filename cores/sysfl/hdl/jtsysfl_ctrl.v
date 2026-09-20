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

    Author: Andrea Bogazzi. email: andreabogazzi79@gmail.com
    Version: 1.0
    Date: 19-9-2026
*/

// digital controls -> pedal/wheel ADC values, stepped once per frame like
// MAME keyboard analog (ACCEL keydelta 20, WHEEL keydelta 4, both autocenter)
module jtsysfl_ctrl(
    input             rst,
    input             clk,
    input             lvbl,
    input      [ 7:0] joystick,     // active low {b4,b3,b2,b1,up,down,left,right}
    output reg [ 7:0] accel,
    output reg [ 7:0] wheel
);

wire frame, gas, left, right;

assign gas   = ~joystick[4];
assign left  = ~joystick[1];
assign right = ~joystick[0];

jtframe_edge_pulse #(.NEGEDGE(1)) u_frame(
    .rst    ( rst   ),
    .clk    ( clk   ),
    .cen    ( 1'b1  ),
    .sigin  ( lvbl  ),
    .pulse  ( frame )
);

always @(posedge clk) begin
    if( rst ) begin
        accel <= 0;
        wheel <= 8'h80;
    end else if( frame ) begin
        if( gas )
            accel <= accel > 8'd235 ? 8'hff : accel + 8'd20;
        else
            accel <= accel < 8'd20  ? 8'h00 : accel - 8'd20;
        if( right && !left )
            wheel <= wheel > 8'd251 ? 8'hff : wheel + 8'd4;
        else if( left && !right )
            wheel <= wheel < 8'd4   ? 8'h00 : wheel - 8'd4;
        else if( wheel > 8'h84 )
            wheel <= wheel - 8'd4;
        else if( wheel < 8'h7c )
            wheel <= wheel + 8'd4;
        else
            wheel <= 8'h80;
    end
end

endmodule
