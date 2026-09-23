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

// pedal/wheel ADC values. Analog sticks/triggers/wheel take over per control
// (mappings as in jtoutrun); with the sticks idle, the digital buttons step
// the values once per frame like MAME keyboard analog (ACCEL keydelta 20,
// WHEEL keydelta 4, both autocenter)
module jtsysfl_ctrl(
    input             rst,
    input             clk,
    input             lvbl,
    input      [ 7:0] joystick,     // active low {b4,b3,b2,b1,up,down,left,right}
    input      [15:0] joyana_l, joyana_r,
    input      [ 2:0] ctrl_type,    // 0 stick, 1 triggers, 2 wheel
    output     [ 7:0] accel,
    output     [ 7:0] brake,
    output     [ 7:0] wheel,
    output reg        gear      // shifter toggle (MAME PORT_TOGGLE)
);

reg  [7:0] accel_d, brake_d, wheel_d;   // digital ramp
reg  [7:0] accel_a, brake_a;
wire [7:0] wheel_a = joyana_l[7:0] ^ 8'h80;
wire       wl_act  = joyana_l[7:3]!=5'h00 && joyana_l[7:3]!=5'h1f;

always @* begin
    case( ctrl_type )
        3'd1: begin // analog triggers
            accel_a = joyana_r[ 7] ? 8'd0 : {joyana_r[ 6:0], joyana_r[ 6]};
            brake_a = joyana_l[15] ? 8'd0 : {joyana_l[14:8], joyana_l[14]};
        end
        3'd2: begin // wheel pedals
            accel_a = joyana_l[15] ? ~{joyana_l[14:8], joyana_l[14]} : 8'd0;
            brake_a = joyana_r[15] ? ~{joyana_r[14:8], joyana_r[14]} : 8'd0;
        end
        default: begin // right stick Y: up = gas, down = brake
            accel_a = joyana_r[15] ? ~{joyana_r[14:8], joyana_r[14]} : 8'd0;
            brake_a = joyana_r[15] ? 8'd0 : {joyana_r[14:8], joyana_r[14]};
        end
    endcase
end

assign accel = accel_a > 8'd8 ? accel_a : accel_d;
assign brake = brake_a > 8'd8 ? brake_a : brake_d;
assign wheel = wl_act ? wheel_a : wheel_d;

wire frame, gas, stop, left, right, shift;
reg  shift_l;

assign gas   = ~joystick[4];
assign stop  = ~joystick[5];
assign left  = ~joystick[1];
assign right = ~joystick[0];
assign shift = ~joystick[7];

jtframe_edge_pulse #(.NEGEDGE(1)) u_frame(
    .rst    ( rst   ),
    .clk    ( clk   ),
    .cen    ( 1'b1  ),
    .sigin  ( lvbl  ),
    .pulse  ( frame )
);

always @(posedge clk) begin
    if( rst ) begin
        accel_d <= 0;
        brake_d <= 0;
        wheel_d <= 8'h80;
        gear  <= 0;
        shift_l <= 0;
    end else begin
        shift_l <= shift;
        if( shift && !shift_l ) gear <= ~gear;
    end
    if( !rst && frame ) begin
        if( gas )
            accel_d <= accel_d > 8'd235 ? 8'hff : accel_d + 8'd20;
        else
            accel_d <= accel_d < 8'd20  ? 8'h00 : accel_d - 8'd20;
        if( stop )
            brake_d <= brake_d > 8'd235 ? 8'hff : brake_d + 8'd20;
        else
            brake_d <= brake_d < 8'd20  ? 8'h00 : brake_d - 8'd20;
        if( right && !left )
            wheel_d <= wheel_d > 8'd251 ? 8'hff : wheel_d + 8'd4;
        else if( left && !right )
            wheel_d <= wheel_d < 8'd4   ? 8'h00 : wheel_d - 8'd4;
        else if( wheel_d > 8'h84 )
            wheel_d <= wheel_d - 8'd4;
        else if( wheel_d < 8'h7c )
            wheel_d <= wheel_d + 8'd4;
        else
            wheel_d <= 8'h80;
    end
end

endmodule
