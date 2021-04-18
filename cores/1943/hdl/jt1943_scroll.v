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
    Date: 19-2-2019 */

// 1943 Scroll Generation
// Schematics pages 8/15...

module jt1943_scroll #( parameter
    [8:0] HOFFSET   = 9'd5,
    parameter
    LAYOUT          = 0,   // 0 = 1943, 3 = Bionic Commando, 8 = Side Arms, 9=SF
    ROM_AW          = 17,
    SIMFILE_MSB     = "",
    SIMFILE_LSB     = "",
    AS8MASK         = 1'b1,
    PALETTE         = 1,
    PXLW            = (LAYOUT==3 || LAYOUT==8) ? 9 :
                      (LAYOUT==7 /*Trojan SCR2*/ ? 7 :  (PALETTE?6:8)),
    VPOSW           = (LAYOUT==3 || LAYOUT==8) ? 16 : 8, // vertical offset bit width,
    // MAP SIZE
    MAPAW           = LAYOUT==9 ? 16 : 14, // address width
    MAPDW           = LAYOUT==9 ? 32 : 16  // data width
)(
    input                rst,
    input                clk,  // >12 MHz
    input                cen6  /* synthesis direct_enable = 1 */,    //  6 MHz
    input         [ 8:0] V128, // V128-V1
    input         [ 8:0] H, // H256-H1

    input         [15:0] hpos,
    input    [VPOSW-1:0] vpos,
    input                SCxON,
    input                flip,
    // Palette PROMs D1, D2
    input     [7:0]      prog_addr,
    input                prom_hi_we,
    input                prom_lo_we,
    input     [3:0]      prom_din,

    // Map ROM
    output   [MAPAW-1:0] map_addr,
    input    [MAPDW-1:0] map_data,
    input                map_ok,
    // Gfx ROM
    output  [ROM_AW-1:0] scr_addr,
    input         [15:0] scrom_data,
    output    [PXLW-1:0] scr_pxl
);

wire [MAPDW/2-1:0] dout_high, dout_low;
wire         [4:0] HS, SVmap;
jt1943_map #(
    .HOFFSET    ( HOFFSET   ),
    .LAYOUT     ( LAYOUT    ),
    .VPOSW      ( VPOSW     ),
    .MAPAW      ( MAPAW     ),
    .MAPDW      ( MAPDW     )
) u_map(
    .rst        ( rst       ),
    .clk        ( clk       ),  // >12 MHz
    .pxl_cen    ( cen6      ),
    .V128       ( V128      ), // V128-V1
    .H          ( H         ), // H256-H1
    .hpos       ( hpos      ),
    .vpos       ( vpos      ),
    .SCxON      ( SCxON     ),
    .flip       ( flip      ),
    // Map ROM
    .map_addr   ( map_addr  ),
    .map_data   ( map_data  ),
    .map_ok     ( map_ok    ),
    // Current tile
    .dout_high  ( dout_high ),
    .dout_low   ( dout_low  ),
    .HS         ( HS        ),
    .SVmap      ( SVmap     )
);

jtgng_tile4 #(
    .AS8MASK        ( AS8MASK       ),
    .PALETTE        ( PALETTE       ),
    .ROM_AW         ( ROM_AW        ),
    .SIMFILE_LSB    ( SIMFILE_LSB   ),
    .LAYOUT         ( LAYOUT        ),
    .SIMFILE_MSB    ( SIMFILE_MSB   ))
u_tile4(
    .clk        (  clk          ),
    .cen6       (  cen6         ),
    .HS         (  HS           ),
    .SV         (  SVmap        ),
    .attr       (  dout_high    ),
    .id         (  dout_low     ),
    .SCxON      ( SCxON         ),
    .flip       ( flip          ),
    // Palette PROMs
    .prog_addr  ( prog_addr     ),
    .prom_hi_we ( prom_hi_we    ),
    .prom_lo_we ( prom_lo_we    ),
    .prom_din   ( prom_din      ),
    // Gfx ROM
    .scr_addr   ( scr_addr      ),
    .rom_data   ( scrom_data    ),
    .scr_pxl    ( scr_pxl       )
);

endmodule