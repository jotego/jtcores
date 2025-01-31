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
    Date: 26-1-2025 */

module jtframe_ps2key_decoder(
    input            clk,
    input            rst,

    // PS2 parallel data
    input      [7:0] ps2byte,
    input            valid,
    input            shift,

    // decoded keys
    output reg [9:0] joy1,
    output reg [9:0] joy2,
    output reg [9:0] joy3,
    output reg [9:0] joy4,
    output reg [3:0] start,
    output reg [3:0] coin,
    output     [7:0] digit,
    output reg       reset,
    output reg       pause,
    output reg       tilt,
    output reg       test,
    output reg       service,
    output reg       vol_up,
    output reg       vol_down,    
    output reg [12:7]func_key,
    output reg       plus,
    output reg       minus
);

reg        released, extended;

/* Left e06b, right e074, up e075, down e072,
   CTRL 14, space 29, alt 11, "1" 16, "2" 1e
   "5" 2e, "F3" 4, P 4d, W 1d, a 1c, s 1b, d 23
   z 1a, x 22, c 21 */

assign digit = { coin, start };

always @(posedge clk) begin
    if(rst) begin
        released <= 0;
        extended <= 0;
        joy1     <= 0;
        joy2     <= 0;
        joy3     <= 0;
        joy4     <= 0;
        coin     <= 0;
        start    <= 0;
        reset    <= 0;
        pause    <= 0;
        service  <= 0;
        tilt     <= 0;
        test     <= 0;

        plus     <= 0;
        minus    <= 0;

        vol_up   <= 0;
        vol_down <= 0;

        func_key <= 0;
    end else begin
        // ps2 decoder has received a valid ps2byte
        if(valid) begin
            if(ps2byte == 8'he0 /*|| ps2byte == 8'h12*/)
                // extended key code
            extended <= 1;
         else if(ps2byte == 8'hf0)
                // release code
            released <= 1;
         else begin
                extended <= 0;
                released <= 0;

                case({extended, ps2byte})
                    `ifndef JTFRAME_LITE_KEYBOARD
                    // first joystick
                    9'h0_22: joy1[9] <= !released;   // Button 6 (X)
                    9'h0_1a: joy1[8] <= !released;   // Button 5 (Z)
                    9'h0_12: joy1[7] <= !released;   // Button 4 (L shift)
                    9'h0_29: joy1[6] <= !released;   // Button 3 (Space)
                    9'h0_11: joy1[5] <= !released;   // Button 2 (L alt)
                    9'h0_14: joy1[4] <= !released;   // Button 1 (L ctrl)
                    9'h1_75: joy1[3] <= !released;   // Up
                    9'h1_72: joy1[2] <= !released;   // Down
                    9'h1_6b: joy1[1] <= !released;   // Left
                    9'h1_74: joy1[0] <= !released;   // Right
                    // second joystick
                    9'h0_24: joy2[8] <= !released;   // Button 5 (E)
                    9'h0_1d: joy2[7] <= !released;   // Button 4 (W)
                    9'h0_15: joy2[6] <= !released;   // Button 3 (Q)
                    9'h0_1b: joy2[5] <= !released;   // Button 2 (S)
                    9'h0_1c: joy2[4] <= !released;   // Button 1 (A)
                    9'h0_2d: joy2[3] <= !released;   // Up       (R)
                    9'h0_2b: joy2[2] <= !released;   // Down     (F)
                    9'h0_23: joy2[1] <= !released;   // Left     (D)
                    9'h0_34: joy2[0] <= !released;   // Right    (G)
                    // third joystick
                    9'h0_5a: joy3[6] <= !released;   // Button 3 (return)
                    9'h0_59: joy3[5] <= !released;   // Button 2 (R shift)
                    9'h1_14: joy3[4] <= !released;   // Button 1 (R ctrl)
                    9'h0_43: joy3[3] <= !released;   // Up       (I)
                    9'h0_42: begin // K is used for both 2P and 3P
                        joy3[2] <= !released;        // 3P Down  (K)
                        joy2[9] <= !released;        // 2P Button 6
                    end
                    9'h0_3b: joy3[1] <= !released;   // Left  (J)
                    9'h0_4b: joy3[0] <= !released;   // Right (L)
                    // 4th joystick
                    9'h0_75: joy4[3] <= !released; // 4P Up
                    9'h0_72: joy4[2] <= !released; // 4P Down
                    9'h0_6b: joy4[1] <= !released; // 4P Left
                    9'h0_74: joy4[0] <= !released; // 4P Right
                    9'h0_70: joy4[4] <= !released; // 4P Button 1
                    9'h0_71: joy4[5] <= !released; // 4P Button 2
                    9'h1_5a: joy4[6] <= !released; // 4P Button 3
                    // coins
                    9'h2e: coin[0] <= !released;  // 1st coin
                    9'h36: coin[1] <= !released;  // 2nd coin
                    9'h3d: coin[2] <= !released;  // 3rd coin
                    9'h3e: coin[3] <= !released;  // 4th coin
                    // start
                    9'h16: start[0] <= !released; // 1P start (1)
                    9'h1e: start[1] <= !released; // 2P start (2)
                    9'h26: start[2] <= !released; // 3P start (3)
                    9'h25: start[3] <= !released; // 4P start (4)
                    `endif
                    // system control
                    9'h4d: pause    <= !released; //  P
                    9'h2c: tilt     <= !released; //  T
                    9'h06: test     <= !released; // F2
                    9'h04: reset    <= !released; // F3
                    9'h0c: vol_up   <= !released; // F4
                    9'h03: vol_down <= !released; // F5
                    9'h46: service  <= !released; //  9
                    // Debug keys
                    // GFX/Sound channels enable
                    9'h0_83: func_key[ 7] <= !released;
                    9'h0_0a: func_key[ 8] <= !released;
                    9'h0_01: func_key[ 9] <= !released;
                    9'h0_09: func_key[10] <= !released;
                    9'h0_78: func_key[11] <= !released;
                    9'h0_07: func_key[12] <= !released;

                    9'h0_5b: plus  <= !released;
                    9'h0_4a: minus <= !released;
                    default:;
                endcase
            end
        end
    end
end
endmodule