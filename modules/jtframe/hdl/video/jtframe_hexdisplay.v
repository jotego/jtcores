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
    Date: 8-5-2021 */

module jtframe_hexdisplay #(
    parameter [8:0] LENBYTES=8, // Number of bytes to display
                    H0,  // Display positions
                    V0   // only supports one row
) (
    input                      clk,
    input                      pxl_cen,
    input                [8:0] hcnt,
    input                [8:0] vcnt,
    input  [(LENBYTES<<3)-1:0] data,
    output reg                 pxl
);

reg  [19:0] font [0:15]; // 4x5 font
wire [ 3:0] display_nibble_bus, display_nibble_view;
reg  [ 4:0] font_pixel;
wire [19:0] char;
wire [ 3:0] nibble;
wire        inhzone, invzone;
reg  [(LENBYTES<<3)-1:0] ser;

localparam [8:0] HOVER = H0 + (LENBYTES<<4);

assign nibble  = ser[(LENBYTES<<3)-1-:4];
assign char    = font[ nibble ];
assign inhzone = hcnt[8:3]<HOVER[8:3] && hcnt[8:3] >= H0[8:3];
assign invzone = vcnt[8:3]==V0[8:3] && vcnt[2:0]<5;

// Inspired by TIC computer 6x6 font by nesbox
// https://fontstruct.com/fontstructions/show/1334143/tic-computer-6x6-font
initial begin
    font[4'd00] = 20'b0110_1001_1001_1001_0110; // MSB is the bottom row
    font[4'd01] = 20'b0111_0010_0010_0110_0010;
    font[4'd02] = 20'b1111_1000_0110_0001_1110;
    font[4'd03] = 20'b1110_0001_0110_0001_1111;
    font[4'd04] = 20'b0010_1111_1010_1010_0010;
    font[4'd05] = 20'b1110_0001_1110_1000_1111;
    font[4'd06] = 20'b0110_1001_1110_1000_0110;
    font[4'd07] = 20'b0100_0100_0010_0001_1111;
    font[4'd08] = 20'b0110_1001_0110_1001_0110;
    font[4'd09] = 20'b0110_0001_0111_1001_0110;
    font[4'd10] = 20'b1001_1111_1001_1001_0110;
    font[4'd11] = 20'b1110_1001_1110_1001_1110;
    font[4'd12] = 20'b0111_1000_1000_1000_0111;
    font[4'd13] = 20'b1110_1001_1001_1001_1110;
    font[4'd14] = 20'b1111_1000_1110_1000_1111;
    font[4'd15] = 20'b1000_1000_1110_1000_1111;
end

always @(posedge clk) begin
    font_pixel <= { vcnt[2:0], ~hcnt[1:0] };

    if( !inhzone )
        ser <= data;

    if( pxl_cen ) begin
        if( inhzone && invzone ) begin
            pxl <= hcnt[2:0]< 4 ? char[ font_pixel ] : 1'b0;
            if( &hcnt[2:0] ) ser <= ser<<4; // get next nibble ready
        end else begin
            pxl <= 0;
        end
    end
end

endmodule