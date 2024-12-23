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
    Date: 27-10-2017 */

module jtgng_scroll #(parameter
    ROM_AW   = 15,
    PALW     = 4,   // PALW must be manually defined to match what is needed by LAYOUT
    HOFFSET  = 9'd0,// Only positive numbers
    POSW     = 9,   // Scroll offset width, normally 9 bits
    // bit field information
    IDMSB1   = 7,   // MSB of tile ID is
    IDMSB0   = 6,   //   { dout_high[IDMSB1:IDMSB0], dout_low }
    VFLIP    = 5,
    HFLIP    = 4,
    SCANW    = 10,  // Tile map bit width, normally 10 bits, 9 bits for 1942,
    TILE4    = 0,   // Use 4 bpp instead of 3bpp
    LAYOUT   = 0,   // Only used for TILE 4
    SIMID    = 1    // scr1_lo/hi.bin for simulation files
) (
    input              clk,     // 24 MHz
    input              pxl_cen  /* synthesis direct_enable = 1 */,    //  6 MHz
    input              Asel,
    input  [SCANW-1:0] AB,
    input        [7:0] V, // V128-V1
    input        [8:0] H, // H256-H1
    input   [POSW-1:0] hpos,
    input   [POSW-1:0] vpos,
    input              scr_cs,
    input              flip,
    input        [7:0] din,
    output       [7:0] dout,
    input              wr_n,
    output             busy,

    // ROM
    output      [ROM_AW-1:0] scr_addr,
    input  [(TILE4?15:23):0] rom_data,
    input                    rom_ok,
    output        [PALW-1:0] scr_pal,
    output   [(TILE4?3:2):0] scr_col
);

localparam DATAREAD = 3'd1;

wire [ 8:0] Hfix;
wire [ 7:0] VF = {8{flip}}^V;
wire [ 8:0] HF = {9{flip}}^Hfix;
wire        H7;
wire [ 7:0] dout_low, dout_high;
reg  [ 2:0] HSaux;
reg  [POSW-1:0] HS, hpos_s;
wire [POSW-1:0] Hsum, VS;

assign H7   = (~Hfix[8] & (~flip ^ HF[6])) ^HF[7];
assign Hfix = H + HOFFSET[8:0]; // Corrects pixel output offset
assign VS   = vpos + { {POSW-8{1'b0}}, VF};
assign Hsum = hpos_s + ( LAYOUT==1 ?
            { {POSW-8{~Hfix[8]}}, HF[7:0]} : (
            LAYOUT==10 && SCANW==12 ?
            { {POSW-9{1'd0}}, HF} :
            { {POSW-8{~Hfix[8]}}, H7, HF[6:0]} ));
assign busy = (HS[2:0]<2) && scr_cs;

always @(posedge clk) if(pxl_cen) begin
    hpos_s <= hpos; // prevents a hold error in MiSTer
    if( Hsum[2:0]=={3{flip}} ) HS[POSW-1:3] <= Hsum[POSW-1:3];
    HS[2:0]      <= Hsum[2:0] ^ {3{flip}};
end

wire [7:0] Vtilemap = SCANW>=10 ? VS[POSW-1:POSW-8] : VS[7:0];
wire [7:0] Htilemap = HS[POSW-1:POSW-8];

jtgng_tilemap #(
    .INVERT_SCAN( 1         ),
    .DATAREAD   ( DATAREAD  ),
    .SCANW      ( SCANW     ),
    .SIMID      ( SIMID     )
) u_tilemap(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .Asel       ( Asel      ),
    .AB         ( AB        ),
    .V          ( Vtilemap  ),
    .H          ( Htilemap  ),
    .flip       ( 1'b0      ),  // Flip is already done on HS and VS
    .din        ( din       ),
    .dout       ( dout      ),
    // Bus arbitrion
    .cs         ( scr_cs    ),
    .wr_n       ( wr_n      ),
    // Current tile
    .dout_low   ( dout_low  ),
    .dout_high  ( dout_high ),
    // unused:
    .dseln      (           ),
    .layout     (           )
);

generate
    if ( TILE4 ) begin
         jtgng_tile4 #(
            .PALETTE    ( 0          ),
            .ROM_AW     ( ROM_AW     ),
            .LAYOUT     ( LAYOUT     ))
        u_tile4(
            .clk        (  clk        ),
            .cen6       (  pxl_cen    ),
            .HS         (  HS[4:0]    ),
            .SV         (  VS[4:0]    ),
            .attr       (  dout_high  ),
            .id         (  dout_low   ),
            .SCxON      (  1'b1       ),
            .flip       (  flip       ),
            // Gfx ROM
            .scr_addr   (  scr_addr   ),
            .rom_data   (  rom_data   ),
            .scr_pxl    (  { scr_pal, scr_col } ),
            // Palette inputs - unused. Filled here
            // to avoid tool warnings only
            .prog_addr  ( 8'd0        ),
            .prom_hi_we ( 1'b0        ),
            .prom_lo_we ( 1'b0        ),
            .prom_din   ( 4'd0        )
        );
    end else begin
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
    end
endgenerate

endmodule // jtgng_scroll