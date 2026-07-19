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
    Date: 18-7-2026 */

module jtpktgal_bac06(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             HS,
    input             LVBL,
    input      [ 8:0] hdump,
    input      [ 8:0] vdump,

    output     [10:1] vram_addr,
    input      [15:0] vram_dout,

    input      [ 4:0] mmr_addr,
    input      [ 7:0] mmr_din,
    output     [ 7:0] mmr_dout,
    input             mmr_cs,
    input             mmr_rnw,
    output            flip,
    input             char_orig,
    input             char_bootleg,

    output     [16:2] rom_addr,
    input      [31:0] rom_data,
    input             rom_ok,
    output            rom_cs,

    output     [ 7:0] pxl,

    input      [ 7:0] debug_bus,
    input      [ 4:0] ioctl_addr,
    output     [ 7:0] ioctl_din
);

localparam [8:0] HLOOP = 9'd369;

wire [14:0] raw_rom_addr;
wire [13:0] addr;
wire [11:0] addr0, addr1, addr2;
wire [ 9:0] scrx, scry;
wire [11:0] code;
wire [ 6:0] col, row;
wire [ 7:0] ctrl0, ctrl3, ctrl1_0, ctrl1_1;
wire [ 3:0] pal;
wire [ 1:0] shape;
wire        hflip;

assign scrx       = (char_bootleg ? 10'd0 : {2'b0, ctrl1_0}) + 10'd8;
assign scry       = char_bootleg ? 10'd0 : {2'b0, ctrl1_1};
assign code       = vram_dout[11:0];
assign pal        = vram_dout[15:12];
assign hflip      = !ctrl0[1];
assign shape      = char_bootleg ? 2'd2 :
                    ctrl3[1:0] == 2'd3 ? 2'd1 : ctrl3[1:0];
assign col        = addr[ 6:0];
assign row        = addr[13:7];
assign flip       = ctrl0[7];

assign addr0      = { col[6:5], row[4:0], col[4:0] };
assign addr1      = { col[5], row[5], row[4:0], col[4:0] };
assign addr2      = { row[6:5], row[4:0], col[4:0] };
assign vram_addr  = shape == 2'd0 ? addr0[9:0] :
                    shape == 2'd1 ? addr1[9:0] : addr2[9:0];

assign rom_addr   = raw_rom_addr ^ {10'd0, char_orig, 4'd0};

jtframe_scroll #(
    .SIZE       ( 8  ),
    .VA         ( 14 ),
    .CW         ( 12 ),
    .PW         ( 8  ),
    .MAP_HW     ( 10 ),
    .MAP_VW     ( 10 ),
    .ROM_HFLIP  ( 0  ),
    .HJUMP      ( 0  ),
    .HLOOP      ( HLOOP )
) u_scroll(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .pxl_cen    ( pxl_cen      ),
    .hs         ( HS           ),
    .vdump      ( vdump        ),
    .hdump      ( hdump        ),
    .blankn     ( LVBL         ),
    .flip       ( flip         ),
    .scrx       ( scrx         ),
    .scry       ( scry         ),
    .vram_addr  ( addr         ),
    .code       ( code         ),
    .pal        ( pal          ),
    .hflip      ( hflip        ),
    .vflip      ( 1'b0         ),
    .rom_addr   ( raw_rom_addr ),
    .rom_data   ( rom_data     ),
    .rom_cs     ( rom_cs       ),
    .rom_ok     ( rom_ok       ),
    .pxl        ( pxl          )
);

jtpktgal_bac06_mmr u_mmr(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .cs         ( mmr_cs     ),
    .addr       ( mmr_addr   ),
    .rnw        ( mmr_rnw    ),
    .din        ( mmr_din    ),
    .dout       ( mmr_dout   ),
    .ctrl0      ( ctrl0      ),
    .ctrl3      ( ctrl3      ),
    .ctrl1_0    ( ctrl1_0    ),
    .ctrl1_1    ( ctrl1_1    ),
    .ioctl_addr ( ioctl_addr ),
    .ioctl_din  ( ioctl_din  ),
    .debug_bus  ( debug_bus  ),
    .st_dout    (            )
);

endmodule
