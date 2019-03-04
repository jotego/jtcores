/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 4-2-2019 */

// Based on MiST tutorials

module jtgng_keyboard(
    input clk,
    input rst,

    // ps2 interface
    input ps2_clk,
    input ps2_data,

    // decodes keys
    output reg [9:0] key_joy1,
    output reg [9:0] key_joy2,
    output reg [1:0] key_start,
    output reg [1:0] key_coin,
    output reg key_reset,
    output reg key_pause
);

wire valid;
wire error;

reg key_released;
reg key_extended;
reg [7:0] ps2byte;

/* Left e06b, right e074, up e075, down e072,
   CTRL 14, space 29, alt 11, "1" 16, "2" 1e
   "5" 2e, "F3" 4, P 4d, W 1d, a 1c, s 1b, d 23
   z 1a, x 22, c 21 */

always @(posedge clk) begin
    if(rst) begin
      key_released <= 1'b0;
      key_extended <= 1'b0;
      key_joy1 <=  'd0;
      key_joy2 <=  'd0;
      key_coin <= 2'd0;
      key_start<= 2'd0;
      key_reset<= 1'b0;
      key_pause<= 1'b0;
    end else begin
        // ps2 decoder has received a valid ps2byte
        if(valid) begin
            if(ps2byte == 8'he0)
                // extended key code
            key_extended <= 1'b1;
         else if(ps2byte == 8'hf0)
                // release code
            key_released <= 1'b1;
         else begin
                key_extended <= 1'b0;
                key_released <= 1'b0;

                case({key_extended, ps2byte})
                    // first joystick
                    9'h0_29: key_joy1[6] <= !key_released;   // Button 3
                    9'h0_11: key_joy1[5] <= !key_released;   // Button 2
                    9'h0_14: key_joy1[4] <= !key_released;   // Button 1
                    9'h1_75: key_joy1[3] <= !key_released;   // Up
                    9'h1_72: key_joy1[2] <= !key_released;   // Down
                    9'h1_6b: key_joy1[1] <= !key_released;   // Left
                    9'h1_74: key_joy1[0] <= !key_released;   // Right
                    // second joystick
                    9'h0_15: key_joy2[6] <= !key_released;   // Button 3
                    9'h0_1b: key_joy2[5] <= !key_released;   // Button 2
                    9'h0_1c: key_joy2[4] <= !key_released;   // Button 1
                    9'h0_2d: key_joy2[3] <= !key_released;   // Up
                    9'h0_2b: key_joy2[2] <= !key_released;   // Down
                    9'h0_23: key_joy2[1] <= !key_released;   // Left
                    9'h0_34: key_joy2[0] <= !key_released;   // Right
                    // coins
                    9'h2e: key_coin[0] <= !key_released;  // 1st coin
                    9'h36: key_coin[1] <= !key_released;  // 2nd coin
                    9'h16: key_start[0] <= !key_released; // 1P start
                    9'h1e: key_start[1] <= !key_released; // 2P start
                    // system control
                    9'h4d: key_pause <= !key_released;
                    9'h04: key_reset <= !key_released;
                endcase
            end
        end
    end
end

// the ps2 decoder has been taken from the zx spectrum core
ps2_intf ps2_keyboard (
    .CLK     ( clk           ),
    .nRESET  ( !rst          ),

    // PS/2 interface
    .PS2_CLK  ( ps2_clk         ),
    .PS2_DATA ( ps2_data        ),

    // ps2byte-wide data interface - only valid for one clock
    // so must be latched externally if required
    .DATA         ( ps2byte   ),
    .VALID    ( valid  ),
    .ERROR    ( error  )
);


endmodule