/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 31-8-2026 */

// Flight-stick conditioning to ADC0/ADC1, CPU sheet 2/6 (IC126/IC125).
//
// Each byte must be pre-shaped to the window the ROM decodes (68000 dasm
// 0x5AD0); the raw swing pins the stick to a corner. X window 0x20..0xE0,
// reversed. Y is asymmetric about the 0x80 rest -- 0xC0 down, 0x60 up -- hence
// separate gains. Both axes latch once per frame: the MCU scans each twice into
// different slots.

module jtharier_cab(
    input             rst,
    input             clk,
    input             LVBL,

    input      [ 3:0] joystick1, // d-pad, active low
    input      [15:0] joyana_l1, // { Y, X }, signed bytes
    input      [15:0] joyana_r1, // { Y, X }, signed bytes
    input      [ 2:0] adc,       // header: number of populated ADC channels

    input             sprung,    // d-pad offset springs back to centre
    input             invert_y,  // aircraft stick: Arcade = inverted

    output reg [ 7:0] an_x,
    output reg [ 7:0] an_y,
    output reg [ 7:0] an_gas,
    output reg [ 7:0] an_brake
);

localparam signed [9:0] AN_LIMIT = 10'sd96;   // 0x80 +/- 0x60 = the 0x20..0xE0 window
localparam signed [9:0] AN_STEP  = 10'sd4;    // matches MAME PORT_KEYDELTA(4)

// The digital d-pad becomes a sprung analog offset summed into the stick, so a
// pad and an analog stick both work. Hold to ramp toward full deflection at
// AN_STEP per frame, springing back on release as the cabinet's stick does --
// the game treats stick position as an ABSOLUTE screen position.
wire dp_up    = ~joystick1[3];
wire dp_down  = ~joystick1[2];
wire dp_left  = ~joystick1[1];
wire dp_right = ~joystick1[0];
reg  signed [9:0] dig_x, dig_y;

wire signed [ 9:0] ana_x = { {2{joyana_l1[ 7]}}, joyana_l1[ 7:0] };
wire signed [ 9:0] ana_y = { {2{joyana_l1[15]}}, joyana_l1[15:8] };
wire signed [ 9:0] ana_ry= { {2{joyana_r1[15]}}, joyana_r1[15:8] };
wire signed [ 9:0] sum_x = ana_x + dig_x;    // analog stick + digital d-pad offset
wire signed [ 9:0] sum_y = ana_y + dig_y;
wire signed [ 9:0] clp_x = sum_x >  AN_LIMIT ?  AN_LIMIT : (sum_x < -AN_LIMIT ? -AN_LIMIT : sum_x);
wire signed [ 9:0] clp_y = sum_y >  AN_LIMIT ?  AN_LIMIT : (sum_y < -AN_LIMIT ? -AN_LIMIT : sum_y);
wire signed [ 9:0] clp_yf = invert_y ? -clp_y : clp_y;

// The 171/86 gains are COUPLED to AN_LIMIT(96): 96*171>>8 = 64 (0x80->0xC0) and
// 96*86>>8 = 32 (0x80->0x60). Change AN_LIMIT and both must be recomputed as
// endpoint*256/AN_LIMIT, or full travel stops reaching the window endpoints.
wire        [ 9:0] mag_y    = clp_yf[9] ? -clp_yf : clp_yf;           // 0..96
wire        [17:0] scl_y    = mag_y * (clp_yf[9] ? 18'd171 : 18'd86); // down x171 / up x86
wire        [ 7:0] off_y    = scl_y[15:8];                           // 0..64 / 0..32
wire        [ 7:0] an_x_raw = 8'h80 - clp_x[7:0];                    // PORT_REVERSE
wire        [ 7:0] an_y_raw = clp_yf[9] ? 8'h80 + off_y : 8'h80 - off_y;
// Enduro Racer's two pedal inputs are the opposite halves of the right-stick
// vertical axis: up accelerates and down brakes. ADC2 is the left-stick bank
// axis (0x20 at rest), while ADC3 is the reversed steering axis.
wire [ 7:0] enduro_gas   = ana_ry[9] ? -ana_ry[7:0] : 8'd0;
wire [ 7:0] enduro_brake = ana_ry[9] ? 8'd0 : ana_ry[7:0];
wire [ 7:0] enduro_bank  = 8'h20 + ana_y[7:0];
wire [ 7:0] enduro_steer = 8'h80 - ana_x[7:0];

reg anl_vbl;
always @(posedge clk) begin
    anl_vbl <= ~LVBL;
    if( rst ) begin
        an_x    <= 8'h80;
        an_y    <= 8'h80;                  // neutral is 0x80 on both axes
        an_gas  <= 8'h00;
        an_brake<= 8'h00;
        dig_x   <= 0;
        dig_y   <= 0;
    end else begin
        if( ~LVBL & ~anl_vbl ) begin        // once per frame at vblank (60 Hz tick)
            // X: right = positive. Springs back in Arcade; holds in Console.
            if( dp_right ^ dp_left )
                dig_x <= dp_right ? (dig_x + AN_STEP >  AN_LIMIT ?  AN_LIMIT : dig_x + AN_STEP)
                                  : (dig_x - AN_STEP < -AN_LIMIT ? -AN_LIMIT : dig_x - AN_STEP);
            else if( sprung ) begin
                if( dig_x >  AN_STEP ) dig_x <= dig_x - AN_STEP;   // spring back to centre
                else if( dig_x < -AN_STEP ) dig_x <= dig_x + AN_STEP;
                else                        dig_x <= 0;
            end
            // Y: down = positive offset
            if( dp_down ^ dp_up )
                dig_y <= dp_down ? (dig_y + AN_STEP >  AN_LIMIT ?  AN_LIMIT : dig_y + AN_STEP)
                                 : (dig_y - AN_STEP < -AN_LIMIT ? -AN_LIMIT : dig_y - AN_STEP);
            else if( sprung ) begin
                if( dig_y >  AN_STEP ) dig_y <= dig_y - AN_STEP;
                else if( dig_y < -AN_STEP ) dig_y <= dig_y + AN_STEP;
                else                        dig_y <= 0;
            end
            // sample-and-hold the shaped axes
            if( adc==3'd4 ) begin
                an_x     <= enduro_steer;
                an_y     <= enduro_bank;
                an_gas   <= enduro_gas;
                an_brake <= enduro_brake;
            end else begin
                an_x <= an_x_raw;
                an_y <= an_y_raw;
            end
        end
    end
end

endmodule
