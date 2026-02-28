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
    Date: 21-2-2026 */

// X1-012, tilemap currently based on MAME information
// 64 columns, 32 rows, 16x16 tiles
// 1024x512 pixels
module jtx1012(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             cs,
    input      [ 2:1] addr,
    input             rnw,
    input      [15:0] din,
    input      [ 1:0] dsn,

    input              hs, flip,
    input        [8:0] vdump,
    input        [8:0] hdump,
    // Video RAM
    output     [13:1] vram_addr,
    input      [15:0] vram_dout,

    // Tile ROM
    output     [20:2] rom_addr,
    input      [31:0] rom_data,
    output            rom_cs,
    input             rom_ok,

    output     [ 8:0] pxl,
    // IOCTL dump
    input      [ 2:0] ioctl_addr,
    output     [ 7:0] ioctl_din,
    // Debug
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

wire [20:2] pre_addr;
wire [15:0] pre_hpos, vpos;
wire [31:0] rom_sorted,g;
wire        bank;
reg  [13:0] code;
reg  [15:0] hpos;
reg  [ 4:0] pal;
reg         attr, hflip, vflip;

assign vram_addr[13:12]={bank,attr};
assign rom_addr = {pre_addr[20:7],pre_addr[5],~flip^pre_addr[6],
    pre_addr[4],
    pre_addr[3],
    pre_addr[2]
};

always @(posedge clk) begin
    hpos <= pre_hpos+16'h20;
end

always @(posedge clk) begin
    attr <= ~attr;
    if(attr) begin
        code  <= vram_dout[13:0];
        hflip <= vram_dout[15]^flip;
        vflip <= vram_dout[14];
    end else begin
        pal   <= vram_dout[4:0];
    end
end

assign g = rom_data;
assign rom_sorted = {
    g[ 4], g[ 5], g[ 6], g[ 7], g[20], g[21], g[22], g[23],
    g[ 0], g[ 1], g[ 2], g[ 3], g[16], g[17], g[18], g[19],
    g[12], g[13], g[14], g[15], g[28], g[29], g[30], g[31],
    g[ 8], g[ 9], g[10], g[11], g[24], g[25], g[26], g[27]
};

jtx1012_mmr u_mmr(
    .rst        ( rst           ),
    .clk        ( clk           ),

    .cs         ( cs            ),
    .addr       ( addr          ),
    .rnw        ( rnw           ),
    .din        ( din           ),
    .dout       (               ),
    .dsn        ( dsn           ),

    .hpos       ( pre_hpos      ),
    .vpos       ( vpos          ),
    .bank       ( bank          ),

    // IOCTL dump
    .ioctl_addr ( ioctl_addr    ),
    .ioctl_din  ( ioctl_din     ),
    // Debug
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_dout       )
);

jtframe_scroll #(
    .SIZE   ( 16    ),
    .CW     ( 14    ),
    .VA     ( 11    ),
    .PW     ( 4+5   ),
    .MAP_HW ( 10    ),
    .MAP_VW (  9    ),
    .HJUMP  (  0    )
)u_scroll(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .hs         ( hs            ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),
    .flip       (~flip          ),
    .blankn     ( 1'b1          ),
    .scrx       ( hpos[9:0]     ),
    .scry       ( vpos[8:0]     ),

    .vram_addr  (vram_addr[11:1]),
    .code       ( code          ),
    .pal        ( pal           ),
    .hflip      ( hflip         ),
    .vflip      ( vflip         ),

    .rom_addr   ( pre_addr      ),
    .rom_data   ( rom_sorted    ),
    .rom_cs     ( rom_cs        ),
    .rom_ok     ( rom_ok        ),

    .pxl        ( pxl           )
);

endmodule
