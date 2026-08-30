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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Version: 1.0
    Date: 28-8-2026 */

// ROZ layer: the Konami 053936 walks a rotated/zoomed (x,y) over a 64x64 map
// of 16x16 tiles. jt053936 is imported from cores/rungun.
//
//   rozvram[y[9:4]*64 + x[9:4]] -> code = [10:0], colour = [15:12]
//   rozgfx  16x16x4 packed MSB, 128 bytes a tile, in CPU-written BRAM
//   palette base 0x300, opaque (only f1gp2 makes the ROZ transparent)
//
// The 053936 offsets come from MAME's set_offsets(-58,-2). The line RAM is
// not used: the game leaves mmr[7][6] (ln_en) clear - checked in the captured
// scene registers - so ldout ties off and la/lh go nowhere.

module jtf1grpr_roz(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             hs, vs,

    // CPU write port, fff040-fff05f
    input             cs,
    input      [ 4:1] addr,
    input      [15:0] din,
    input      [ 1:0] dsn,

    // tilemap RAM, 64x64 of 16x16
    output     [12:1] rozv_addr,
    input      [15:0] rozv_dout,
    // tile graphics, written by the CPU
    output     [17:1] rozg_addr,
    input      [15:0] rozg_dout,

    output     [ 7:0] pxl,         // {colour[3:0], pixel[3:0]}
    output            on           // in bounds: the layer is opaque there
);

wire [12:0] x, y;
wire        xh, yh, ob;

// TEST: MAME's set_offsets is (-58,-2). The chip biases the map start by
// hstep*-XOFFSET and vstep*-YOFFSET, so raising XOFFSET moves the picture
// right and lowering YOFFSET moves it up.
//   X: -58 + 44 = -14   Y: -2 - 6 = -8
jt053936 #(.XOFFSET(-14),.YOFFSET(-8)) u_xy(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( pxl_cen   ),

    .din        ( din       ),
    .addr       ( addr      ),

    .hs         ( hs        ),
    .vs         ( vs        ),
    .cs         ( cs        ),
    .dtackn     ( 1'b0      ),
    .dsn        ( dsn       ),
    .dma_n      (           ),

    .ldout      ( 16'd0     ),  // no line RAM on this board
    .lh         (           ),
    .la         (           ),

    .x          ( x         ),
    .xh         ( xh        ),
    .y          ( y         ),
    .yh         ( yh        ),
    .nx         (           ),
    .ny         (           ),
    .ob         ( ob        ),

    .ioctl_addr ( 5'd0      ),
    .ioctl_din  (           )
);

// map lookup, then the tile row. Both are BRAM reads and each takes a
// pxl_cen to come back, so the pixel trails the coordinate by two
assign rozv_addr = { y[9:4], x[9:4] };

reg  [10:0] code;
reg  [ 3:0] col;
reg  [ 3:0] xl, yl;
reg         ob_l, ob_l2;

always @(posedge clk) begin
    if( rst ) begin
        code <= 0; col <= 0; xl <= 0; yl <= 0; ob_l <= 1; ob_l2 <= 1;
    end else if( pxl_cen ) begin
        code  <= rozv_dout[10:0];
        col   <= rozv_dout[15:12];
        xl    <= x[3:0];
        yl    <= y[3:0];
        ob_l  <= ob;
        ob_l2 <= ob_l;
    end
end

// 128 bytes a tile: row is 8 bytes, a 16-bit word is four pixels
assign rozg_addr = { code, yl, xl[3:2] };

reg [3:0] pix;
always @* begin
    case( xl[1:0] )                 // packed MSB, leftmost in the high nibble
        2'd0: pix = rozg_dout[15:12];
        2'd1: pix = rozg_dout[11: 8];
        2'd2: pix = rozg_dout[ 7: 4];
        2'd3: pix = rozg_dout[ 3: 0];
    endcase
end

assign on  = ~ob_l2;
assign pxl = ob_l2 ? 8'd0 : { col, pix };

endmodule
