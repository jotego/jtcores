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

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 13-7-2025 */

module jtrungun_psac(
    input              rst, clk, pxl_cen, hs, vs, dtackn,
                       cs, // cs always writes

    input       [15:0] din,        // from CPU
    input       [ 4:1] addr,
    input       [ 1:0] dsn,
    output             dma_n,
    // Lines RAM
    output      [10:1] line_addr,
    input       [15:0] line_dout,
    // Tile map
    output      [13:0] vram_addr, // 14
    input       [23:0] vram_dout,

    // Tiles
    output      [20:0] rom_addr,
    input       [ 7:0] rom_data,
    output             rom_cs,
    input              rom_ok,

    output      [ 7:0] pxl,

    // IOCTL dump
    input      [4:0] ioctl_addr,
    output reg [7:0] ioctl_din
);

wire [ 8:0] la;
wire [ 2:1] lh;
wire [12:0] x, y;
wire        xh,yh,ob;
wire [12:0] code;
wire        hflip, vflip;
wire [ 3:0] pal, vf, hf;

assign line_addr = {la[7:0],lh};
assign vram_addr = {y[9:3], x[9:3]};
assign code      = vram_dout[12:0];
assign hflip     = vram_dout[14];
assign vflip     = vram_dout[15];
assign pal       = vram_dout[19:16];
assign vf        = {4{vflip}} ^ {y[2:0],yh};
assign hf        = {4{hflip}} ^ {x[2:0],xh};

assign rom_cs    = 1;
assign rom_addr  = {code,vf,hf}; // 13+4+4=21
assign pxl       = rom_data;

jt053936 u_xy(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( pxl_cen   ),

    .din        ( din       ),        // from CPU
    .addr       ( addr      ),

    .hs         ( hs        ),
    .vs         ( vs        ),
    .cs         ( cs        ),
    .dtackn     ( dtackn    ),
    .dsn        ( dsn       ),
    .dma_n      ( dma_n     ),

    .ldout      ( line_dout ),  // shared with CPU data pins on original
    .lh         ( lh        ),  // lh[0] always zero for 16-bit memories
    .la         ( la        ),

    .x          ( x         ),
    .xh         ( xh        ),
    .y          ( y         ),
    .yh         ( yh        ),
    .ob         ( ob        ), // out of bonds, original pin: NOB

    .ioctl_addr ( ioctl_addr),
    .ioctl_din  ( ioctl_din )
);

endmodule
