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
    Date: 4-7-2025 */

module jtrungun_video(
    input              rst, clk,
    input              pxl_cen,
                       ghflip, gvflip, pri,
    output             disp,
    // Base Video
    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs,
    // fixed layer
    output      [12:1] vram_addr,
    input       [15:0] vram_dout,

    output      [16:2] fix_addr,
    input       [31:0] fix_data,
    output             fix_cs,
    input              fix_ok,
);

wire [11:0] fix_code;
wire [ 9:0] hdump, vdump, vf, hf;
wire [ 7:0] fix_pxl;
wire [ 3:0] fix_pal;

assign vram_addr[12] = vram_bank;
assign fix_pal  = vram_dout[15:12];
assign fix_code = vram_dout[11: 0];
assign vf       = {10{gvflip}}^vdump;
assign hf       = {10{ghflip}}^hdump;

jtframe_toggle #(.W(1)) u_disp(rst,clk,vs,disp);

jtframe_tilemap #(
    .VA(12),
    .MAP_HW(9),
    .FLIP_HDUMP(0),
    .FLIP_VDUMP(0)
)u_fix(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .vdump      ( vf            ),
    .hdump      ( hf            ),
    .blankn     ( 1'b1          ),
    .flip       ( 1'b0          ),    // Screen flip

    .vram_addr  ( vram_addr     ),

    .code       ( fix_code      ),
    .pal        ( fix_pal       ),
    .hflip      ( 1'b0          ),
    .vflip      ( 1'b0          ),

    .rom_addr   ( fix_addr      ),
    .rom_data   ( fix_data      ),    // expects data packed as plane3,plane2,plane1,plane0, each of 8 bits
    .rom_cs     ( fix_cs        ),
    .rom_ok     ( fix_ok        ), // zeros used if rom_ok is not high in time

    .pxl        ( fix_pxl       )
);

endmodule