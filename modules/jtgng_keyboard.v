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
    input reset,

    // ps2 interface    
    input ps2_clk,
    input ps2_data,
    
    // decodes keys
    output reg [7:0] keys
);

parameter ACTIVE_LOW=1'b1;

wire [7:0] byte;
wire valid;
wire error;

reg key_released;
reg key_extended;

always @(posedge clk) begin
    if(reset) begin
        keys <= 8'h00;
      key_released <= 1'b0;
      key_extended <= 1'b0;
    end else begin
        // ps2 decoder has received a valid byte
        if(valid) begin
            if(byte == 8'he0) 
                // extended key code
            key_extended <= 1'b1;
         else if(byte == 8'hf0)
                // release code
            key_released <= 1'b1;
         else begin
                key_extended <= 1'b0;
                key_released <= 1'b0;
                
                case(byte)
                    8'h29:  joy0[5] <= !key_released;   // Button 2
                    8'h1b:  joy0[4] <= !key_released;   // Button 1
                    8'h21:  joy0[3] <= !key_released;   // Up
                    8'h21:  joy0[2] <= !key_released;   // Down
                    8'h21:  joy0[1] <= !key_released;   // Left
                    8'h21:  joy0[0] <= !key_released;   // Right
                endcase
            end
        end
    end
end

// the ps2 decoder has been taken from the zx spectrum core
ps2_intf ps2_keyboard (
    .CLK         ( clk             ),
    .nRESET  ( !reset          ),
    
    // PS/2 interface
    .PS2_CLK  ( ps2_clk         ),
    .PS2_DATA ( ps2_data        ),
    
    // Byte-wide data interface - only valid for one clock
    // so must be latched externally if required
    .DATA         ( byte   ),
    .VALID    ( valid  ),
    .ERROR    ( error  )
);


endmodule