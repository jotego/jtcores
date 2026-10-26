/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 22-10-2026 */

// wheel/pedal mappings as in jtsysfl_ctrl; gas and brake leave as buttons
// because the board reads them as switches. Digital steering ramps once per
// frame like the MAME key delta (15) and autocenters
module jtroundu_ctrl(
    input             rst,
    input             clk,
    input             lvbl,
    input      [ 7:0] joystick,     // active low {b4,b3,b2,b1,up,down,left,right}
    input      [15:0] joyana_l, joyana_r,
    input      [ 2:0] ctrl_type,    // 0 stick, 1 triggers, 2 wheel
    output     [ 7:0] stick,
    output            gas_n,
    output            brake_n
);

reg  [7:0] wheel_d;
reg  [7:0] accel_a, brake_a;
wire [7:0] wheel_a = joyana_l[7:0] ^ 8'h80;
wire       wl_act  = joyana_l[7:4]!=4'h0 && joyana_l[7:4]!=4'hf; // +-16 deadzone
wire       frame, left, right;

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
        default: begin
            accel_a = 8'd0;
            brake_a = 8'd0;
        end
    endcase
end

assign stick   = wl_act ? wheel_a : wheel_d;
assign gas_n   = joystick[4] && !(accel_a > 8'd64);
assign brake_n = joystick[5] && !(brake_a > 8'd64);
assign left    = ~joystick[1];
assign right   = ~joystick[0];

jtframe_edge_pulse #(
    .NEGEDGE ( 1 )
) u_frame (
    .rst   ( rst   ),
    .clk   ( clk   ),
    .cen   ( 1'b1  ),
    .sigin ( lvbl  ),
    .pulse ( frame )
);

always @(posedge clk) begin
    if( rst ) wheel_d <= 8'h80;
    else if( frame ) begin
        if( right && !left )      wheel_d <= wheel_d > 8'd240 ? 8'hff : wheel_d + 8'd15;
        else if( left && !right ) wheel_d <= wheel_d < 8'd15  ? 8'h00 : wheel_d - 8'd15;
        else if( wheel_d > 8'h8f ) wheel_d <= wheel_d - 8'd15;
        else if( wheel_d < 8'h71 ) wheel_d <= wheel_d + 8'd15;
        else                       wheel_d <= 8'h80;
    end
end

endmodule
