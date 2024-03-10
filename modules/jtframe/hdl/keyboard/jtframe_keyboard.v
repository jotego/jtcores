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
    Date: 4-2-2019 */

// Based on MiST tutorials

module jtframe_keyboard(
    input clk,
    input rst,

    // ps2 interface
    input ps2_clk,
    input ps2_data,

    // decodes keys
    output reg [9:0] key_joy1,
    output reg [9:0] key_joy2,
    output reg [9:0] key_joy3,
    output reg [9:0] key_joy4,
    output reg [3:0] key_start,
    output reg [3:0] key_coin,
    output     [7:0] key_digit,
    output reg key_reset,
    output reg key_pause,
    output reg key_tilt,
    output reg key_test,
    output reg key_service,

    output     shift,
    output     ctrl,
    output     alt,
    // debug features
    output reg [3:0] key_gfx,
    output reg [4:0] key_snd,
    output reg       debug_plus,
    output reg       debug_minus
);

wire       valid, error;
reg        key_released, key_extended;
wire [7:0] ps2byte;

/* Left e06b, right e074, up e075, down e072,
   CTRL 14, space 29, alt 11, "1" 16, "2" 1e
   "5" 2e, "F3" 4, P 4d, W 1d, a 1c, s 1b, d 23
   z 1a, x 22, c 21 */

assign shift = key_joy1[7] | key_joy3[5];
assign ctrl  = key_joy1[4] | key_joy3[4];
assign alt   = key_joy1[5];

assign key_digit = { key_coin, key_start };

always @(posedge clk) begin
    if(rst) begin
      key_released <= 0;
      key_extended <= 0;
      key_joy1     <= 0;
      key_joy2     <= 0;
      key_joy3     <= 0;
      key_joy4     <= 0;
      key_coin     <= 0;
      key_start    <= 0;
      key_reset    <= 0;
      key_pause    <= 0;
      key_service  <= 0;
      key_tilt     <= 0;
      key_test     <= 0;

      debug_plus   <= 0;
      debug_minus  <= 0;
    end else begin
        // ps2 decoder has received a valid ps2byte
        if(valid) begin
            if(ps2byte == 8'he0 /*|| ps2byte == 8'h12*/)
                // extended key code
            key_extended <= 1;
         else if(ps2byte == 8'hf0)
                // release code
            key_released <= 1;
         else begin
                key_extended <= 0;
                key_released <= 0;

                case({key_extended, ps2byte})
                    `ifndef JTFRAME_LITE_KEYBOARD
                    // first joystick
                    9'h0_22: key_joy1[9] <= !key_released;   // Button 6 (X)
                    9'h0_1a: key_joy1[8] <= !key_released;   // Button 5 (Z)
                    9'h0_12: key_joy1[7] <= !key_released;   // Button 4 (L shift)
                    9'h0_29: key_joy1[6] <= !key_released;   // Button 3 (Space)
                    9'h0_11: key_joy1[5] <= !key_released;   // Button 2 (L alt)
                    9'h0_14: key_joy1[4] <= !key_released;   // Button 1 (L ctrl)
                    9'h1_75: key_joy1[3] <= !key_released;   // Up
                    9'h1_72: key_joy1[2] <= !key_released;   // Down
                    9'h1_6b: key_joy1[1] <= !key_released;   // Left
                    9'h1_74: key_joy1[0] <= !key_released;   // Right
                    // second joystick
                    9'h0_24: key_joy2[8] <= !key_released;   // Button 5 (E)
                    9'h0_1d: key_joy2[7] <= !key_released;   // Button 4 (W)
                    9'h0_15: key_joy2[6] <= !key_released;   // Button 3 (Q)
                    9'h0_1b: key_joy2[5] <= !key_released;   // Button 2 (S)
                    9'h0_1c: key_joy2[4] <= !key_released;   // Button 1 (A)
                    9'h0_2d: key_joy2[3] <= !key_released;   // Up       (R)
                    9'h0_2b: key_joy2[2] <= !key_released;   // Down     (F)
                    9'h0_23: key_joy2[1] <= !key_released;   // Left     (D)
                    9'h0_34: key_joy2[0] <= !key_released;   // Right    (G)
                    // third joystick
                    9'h0_5a: key_joy3[6] <= !key_released;   // Button 3 (return)
                    9'h0_59: key_joy3[5] <= !key_released;   // Button 2 (R shift)
                    9'h1_14: key_joy3[4] <= !key_released;   // Button 1 (R ctrl)
                    9'h0_43: key_joy3[3] <= !key_released;   // Up       (I)
                    9'h0_42: begin // K is used for both 2P and 3P
                        key_joy3[2] <= !key_released;        // 3P Down  (K)
                        key_joy2[9] <= !key_released;        // 2P Button 6
                    end
                    9'h0_3b: key_joy3[1] <= !key_released;   // Left  (J)
                    9'h0_4b: key_joy3[0] <= !key_released;   // Right (L)
                    // 4th joystick
                    9'h0_75: key_joy4[3] <= !key_released; // 4P Up
                    9'h0_72: key_joy4[2] <= !key_released; // 4P Down
                    9'h0_6b: key_joy4[1] <= !key_released; // 4P Left
                    9'h0_74: key_joy4[0] <= !key_released; // 4P Right
                    9'h0_70: key_joy4[4] <= !key_released; // 4P Button 1
                    9'h0_71: key_joy4[5] <= !key_released; // 4P Button 2
                    9'h1_5a: key_joy4[6] <= !key_released; // 4P Button 3
                    // coins
                    9'h2e: key_coin[0] <= !key_released;  // 1st coin
                    9'h36: key_coin[1] <= !key_released;  // 2nd coin
                    9'h3d: key_coin[2] <= !key_released;  // 3rd coin
                    9'h3e: key_coin[3] <= !key_released;  // 4th coin
                    // start
                    9'h16: key_start[0] <= !key_released; // 1P start (1)
                    9'h1e: key_start[1] <= !key_released; // 2P start (2)
                    9'h26: key_start[2] <= !key_released; // 3P start (3)
                    9'h25: key_start[3] <= !key_released; // 4P start (4)
                    `endif
                    // system control
                    9'h4d: key_pause   <= !key_released; //  P
                    9'h2c: key_tilt    <= !key_released; //  T
                    9'h06: key_test    <= !key_released; // F2
                    9'h04: key_reset   <= !key_released; // F3
                    9'h46: key_service <= !key_released; //  9
                    // Debug keys
                    // GFX/Sound channels enable
                    9'h0_83: if( !shift ) key_gfx[0] <= !key_released; else key_snd[0] <= !key_released; // F7: CHAR enable
                    9'h0_0a: if( !shift ) key_gfx[1] <= !key_released; else key_snd[1] <= !key_released; // F8: SCR1 enable
                    9'h0_01: if( !shift ) key_gfx[2] <= !key_released; else key_snd[2] <= !key_released; // F9: SCR2 enable
                    9'h0_09: if( !shift ) key_gfx[3] <= !key_released; else key_snd[3] <= !key_released; // F10:OBJ  enable
                    9'h0_78: if(  shift ) key_snd[4] <= !key_released; // shift+F11:ch[4]  enable

                    9'h0_5b: debug_plus  <= !key_released;
                    9'h0_4a: debug_minus <= !key_released;
                endcase
            end
        end
    end
end

// the ps2 decoder has been taken from the zx spectrum core
ps2_intf_v ps2_keyboard (
    .CLK      (  clk      ),
    .nRESET   ( ~rst      ),

    // PS/2 interface
    .PS2_CLK  ( ps2_clk   ),
    .PS2_DATA ( ps2_data  ),

    // ps2byte-wide data interface - only valid for one clock
    // so must be latched externally if required
    .DATA     ( ps2byte   ),
    .VALID    ( valid     ),
    .ERROR    ( error     )
);

endmodule