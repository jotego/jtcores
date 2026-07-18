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

    Author: Andrea Bogazzi. Email: andreabogazzi79@gmail.com
    Version: 1.0
    Date: 1-5-2022 */

module jtmeikyu_scr1(
    input         rst,
    input         clk,
    input         clk_cpu,
    input         pxl_cen,
    input         flip,

    // VRAM
    output [11:0] scan_addr,
    input  [ 7:0] scan_dout,


    input  [ 8:0] h,
    input  [ 8:0] v,
    input         hs,
    output [17:2] rom_addr,
    input  [31:0] rom_data,
    output        rom_cs,
    input         rom_ok,
    input  [ 7:0] debug_bus,
    output [ 7:0] pxl
);

localparam [8:0] HOFF = 9'h1b6;

wire [10:0] tm_vram;
wire [14:0] tm_rom;
wire [ 8:0] heff = h - HOFF;
reg  [ 7:0] pre_code, code, attr;

wire [31:0] gfx = {
    rom_data[15:12], rom_data[31:28],
    rom_data[11: 8], rom_data[27:24],
    rom_data[ 7: 4], rom_data[23:20],
    rom_data[ 3: 0], rom_data[19:16]
};

assign scan_addr = { tm_vram, heff[0] };
assign rom_addr  = { 1'b0, tm_rom };

always @(posedge clk) if(pxl_cen) begin
    case( heff[2:0] )
        0: pre_code <= scan_dout;
        1: begin
            code <= pre_code;
            attr <= scan_dout;
        end
    endcase
end

jtframe_tilemap #(
    .SIZE        ( 8      ),
    .VA          ( 11     ),
    .CW          ( 12     ),
    .PW          ( 8      ),
    .BPP         ( 4      ),
    .MAP_HW      ( 9      ),
    .MAP_VW      ( 8      ),
    .VR          ( 15     ),
    .FLIP_HDUMP  ( 0      ),
    .FLIP_VDUMP  ( 0      ),
    .XOR_HFLIP   ( 1      ),
    .XOR_VFLIP   ( 0      ),
    .HJUMP       ( 1      ), // fetch on the 8-pixel grid only
    .HDUMP_OFFSET( HOFF   )
) u_tilemap(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .vdump      ( v         ),
    .hdump      ( h         ),
    .blankn     ( ~hs       ),
    .flip       ( flip      ),

    .vram_addr  ( tm_vram   ),

    .code       ( { attr[3:0], code } ),
    .pal        ( attr[7:4] ),
    .hflip      ( 1'b1      ),
    .vflip      ( 1'b0      ),

    .rom_addr   ( tm_rom    ),
    .rom_data   ( gfx       ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),

    .pxl        ( pxl       )
);

endmodule
