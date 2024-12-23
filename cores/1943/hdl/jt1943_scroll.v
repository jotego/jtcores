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
    Date: 19-2-2019 */

// 1943 Scroll Generation
// Schematics pages 8/15...

module jt1943_scroll #( parameter
    LAYOUT          = 0,   // 0 = 1943, 3 = Bionic Commando, 8 = Side Arms, 9=SF
                           // 11 = Exed Exes SCR1 (12 for SCR2)
    ROM_AW          = 17,
    SIMFILE_MSB     = "",
    SIMFILE_LSB     = "",
    AS8MASK         = 1'b1,
    PALETTE         = 1,
    PXLW            = (LAYOUT==3 || LAYOUT==8) ? 9 :
                      (LAYOUT==7 /*Trojan SCR2*/ ? 7 :  (PALETTE?6:8)),
    // MAP SIZE
    MAPAW           = LAYOUT==9 ? 16 : 14, // address width
    MAPDW           = LAYOUT==9 ? 32 : 16, // data width
    parameter [8:0] HOFFSET   = 9'd5,
    VPOSW           = (LAYOUT==3 || LAYOUT==8) ? 9'd16 : 9'd8  // vertical offset bit width,
)(
    input                rst,
    input                clk,  // >12 MHz
    input                cen6, //  6 MHz
    input         [ 8:0] V128, // V128-V1
    input         [ 8:0] H,    // H256-H1
    input                LHBL,

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
    output               map_cs,
    // Gfx ROM
    output  [ROM_AW-1:0] scr_addr,
    input         [15:0] scrom_data,
    output    [PXLW-1:0] scr_pxl,
    input       [7:0]   debug_bus
);

localparam SHW = (LAYOUT==8 || LAYOUT==9) ?  9 : 8;

wire [MAPDW/2-1:0] dout_high, dout_low;
wire         [4:0] HS, SVmap;
wire     [SHW-1:0] SH;
reg          [8:0] V128sh;
wire               row_start;
wire               LHBLd;

// Because we process the signal a bit ahead of time
// (exactly HOFFSET pixels ahead of time), this creates
// an unbalance between the vertical line counter change
// and the current output   at the end of each line. It wasn't
// noticeable in 1943, but it can be seen in GunSmoke
// In order to avoid it, the V counter must be delayed by the same
// HOFFSET amount
// This is not needed for games with more than 256 h width
generate
    if( LAYOUT!=8 && LAYOUT!=9 ) begin
        always @(posedge clk) if(cen6) begin
            if( !LHBL )
                V128sh <= V128;
        end

        jtframe_sh #(.W(1),.L(8)) u_lhbl(
            .clk    ( clk   ),
            .clk_en ( cen6  ),
            .din    ( LHBL  ),
            .drop   ( LHBLd )
        );
    end else begin
        always @(*) V128sh = V128;
        assign LHBLd = LHBL;
    end
endgenerate

wire             mapper_cen, cache_busy, tiler_en;
wire       [8:0] mapper_h;
wire [MAPDW-1:0] mapper_data;

assign tiler_en = ~cache_busy & SCxON;

jt1943_map_cache #(
    .MAPAW( MAPAW ),
    .MAPDW( MAPDW ),
    .SHW  ( SHW   )
) u_mapcache(
    .rst        ( rst       ),
    .clk        ( clk       ),  // >12 MHz
    .pxl_cen    ( cen6      ),
    .mapper_cen ( mapper_cen),
    .LHBL       ( LHBLd     ),
    .H          ( H         ),
    .SH         ( SH        ),

    .map_h      ( mapper_h  ), // H256-H1
    .busy       ( cache_busy),

    // Map ROM to SDRAM
    .map_data   ( map_data  ),
    .map_ok     ( map_ok    ),
    .map_cs     ( map_cs    ),
    .row_start  ( row_start ),
    // Map ROM from mapper
    .mapper_data(mapper_data)
);

jt1943_map #(
    .HOFFSET    ( HOFFSET   ),
    .LAYOUT     ( LAYOUT    ),
    .VPOSW      ( VPOSW     ),
    .MAPAW      ( MAPAW     ),
    .MAPDW      ( MAPDW     ),
    .SHW        ( SHW       )
) u_map(
    .rst        ( rst       ),
    .clk        ( clk       ),  // >12 MHz
    .pxl_cen    ( mapper_cen),
    .burst      ( cache_busy),
    .V128       ( V128sh    ), // V128-V1
    .H          ( mapper_h  ), // H256-H1
    .SH         ( SH        ),
    .hpos       ( hpos      ),
    .vpos       ( vpos      ),
    .SCxON      ( SCxON     ),
    .flip       ( flip      ),
    // Map ROM
    .map_addr   ( map_addr  ),
    .map_data   (mapper_data),
    .row_start  ( row_start ),
    // Current tile
    .dout_high  ( dout_high ),
    .dout_low   ( dout_low  ),
    .HS         ( HS        ),
    .SVmap      ( SVmap     ),
    .debug_bus  ( debug_bus )
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
    .SCxON      ( tiler_en      ),
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