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
    Date: 27-10-2017 */

module jtgng_scroll #(parameter 
    ROM_AW   = 15,
    PALW     = 4,
    HOFFSET  = 9'd0,
    // bit field information
    IDMSB1   = 7,   // MSB of tile ID is
    IDMSB0   = 6,   //   { dout_high[IDMSB1:IDMSB0], dout_low }
    VFLIP    = 5,
    HFLIP    = 4,
    SCANW    = 10   // Tile map bit width, normally 10 bits, 9 bits for 1942
) (
    input              clk,     // 24 MHz
    input              pxl_cen  /* synthesis direct_enable = 1 */,    //  6 MHz
    input              cpu_cen,
    input              Asel,
    input  [SCANW-1:0] AB,
    input        [7:0] V, // V128-V1
    input        [8:0] H, // H256-H1
    input        [8:0] hpos,
    input        [8:0] vpos,
    input              scr_cs,
    input              flip,
    input        [7:0] din,
    output       [7:0] dout,
    input              wr_n,
    output             busy,

    // ROM
    output      [ROM_AW-1:0] scr_addr,
    input       [23:0]       rom_data,
    input                    rom_ok,
    output     [PALW-1:0]    scr_pal,
    output         [ 2:0]    scr_col
);

wire [8:0] Hfix = H + HOFFSET[8:0]; // Corrects pixel output offset
reg  [ 8:0] HS, VS;
wire [ 7:0] VF = {8{flip}}^V;
wire [ 7:0] HF = {8{flip}}^Hfix[7:0];

wire H7 = (~Hfix[8] & (~flip ^ HF[6])) ^HF[7];

reg [2:0] HSaux;

always @(posedge clk) begin
    VS = vpos + {1'b0, VF};
    { HS[8:3], HSaux } = hpos + { ~Hfix[8], H7, HF[6:0]};
    HS[2:0] = HSaux ^ {3{flip}};
end

wire [7:0] dout_low, dout_high;

localparam DATAREAD = 3'd1;

wire [7:0] Vtilemap = SCANW==10 ? VS[8:1] : VS[7:0];

jtgng_tilemap #(
    .SELBIT     ( 1         ),
    .INVERT_SCAN( 1         ),
    .DATAREAD   ( DATAREAD  ),
    .SCANW      ( SCANW     )
) u_tilemap(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .Asel       ( Asel      ),
    .AB         ( AB        ),
    .V          ( Vtilemap  ),
    .H          ( HS[8:1]   ),
    .flip       ( 1'b0      ),  // Flip is already done on HS and VS
    .din        ( din       ),
    .dout       ( dout      ),
    // Bus arbitrion
    .cs         ( scr_cs    ),
    .wr_n       ( wr_n      ),
    .busy       ( busy      ),
    // Pause screen -unused for scroll-
    .pause      ( 1'b0      ),
    .scan       (           ),
    .msg_low    ( 8'd0      ),
    .msg_high   ( 8'd0      ),
    // Current tile
    .dout_low   ( dout_low  ),
    .dout_high  ( dout_high )
);

jtgng_tile3 #(
    .DATAREAD   (  DATAREAD   ),
    .ROM_AW     (  ROM_AW     ),
    .PALW       (  PALW       ),
    .IDMSB1     (  IDMSB1     ),
    .IDMSB0     (  IDMSB0     ),
    .VFLIP      (  VFLIP      ),
    .HFLIP      (  HFLIP      ))
u_tile3(
    .clk        (  clk        ),
    .pxl_cen    (  pxl_cen    ),
    .HS         (  HS         ),
    .VS         (  VS         ),
    .attr       (  dout_high  ),
    .id         (  dout_low   ),
    .flip       (  flip       ),
    // Gfx ROM
    .scr_addr   (  scr_addr   ),
    .rom_data   (  rom_data   ),
    .rom_ok     (  rom_ok     ),
    .scr_pal    (  scr_pal    ),
    .scr_col    (  scr_col    )
);

endmodule // jtgng_scroll