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
    Date: 9-8-2026 */

module jttrcdoc_video(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             flip,
    input      [ 7:0] scrx,

    // tile map RAM, column major (TILEMAP_SCAN_COLS)
    output     [ 9:0] vscan_addr,
    input      [ 7:0] vscan_dout,    // tile code LSBs
    input      [ 7:0] cscan_dout,    // colour, hflip and code MSBs
    output     [15:2] scr_addr,
    input      [31:0] scr_data,
    output            scr_cs,
    input             scr_ok,

    // sprite RAM
    output     [ 9:0] oscan_addr,
    input      [ 7:0] oscan_dout,
    output     [15:2] objrom_addr,
    input      [31:0] objrom_data,
    output            objrom_cs,
    input             objrom_ok,

    // Colour PROMs
    output     [ 7:0] pen,
    input      [ 3:0] rpal_data, gpal_data, bpal_data,

    output            HS, VS, LHBL, LVBL,
    output     [ 3:0] red, green, blue,
    input      [ 3:0] gfx_en
);

localparam [7:0] HOFFSET = 8'd8;

wire [15:2] obj_araw;
wire [ 9:0] scr_vaddr;
wire [ 8:0] vdump, vrender, hdump, obj_code, obj_hpos;
wire        preLHBL, preLVBL;
wire [31:0] scr_sorted;
wire [ 7:0] obj_pxl, scr_pxl;
wire [ 3:0] obj_ysub, obj_pal;
wire        obj_hflip, obj_vflip, dr_busy, dr_draw;

// Tiles are 32 bytes: 4 bytes per row with two pens per byte, the
// leftmost pen in the high nibble. jtframe_tilemap wants one plane per
// byte with the leftmost pen in the MSB
assign scr_sorted = {
    scr_data[ 7], scr_data[ 3], scr_data[15], scr_data[11], scr_data[23], scr_data[19], scr_data[31], scr_data[27],
    scr_data[ 6], scr_data[ 2], scr_data[14], scr_data[10], scr_data[22], scr_data[18], scr_data[30], scr_data[26],
    scr_data[ 5], scr_data[ 1], scr_data[13], scr_data[ 9], scr_data[21], scr_data[17], scr_data[29], scr_data[25],
    scr_data[ 4], scr_data[ 0], scr_data[12], scr_data[ 8], scr_data[20], scr_data[16], scr_data[28], scr_data[24]
};

// jtframe_scroll indexes the map by row, the PCB by column
assign vscan_addr = { scr_vaddr[4:0], scr_vaddr[9:5] };

// Sprite ROM holds four quarters, one per row modulo 4, and each quarter
// packs four rows of a sprite in 32 bytes:
//   byte = {3-(row&3), code, row[3:2], half, 2'd0}
assign objrom_addr = { ~obj_araw[3:2], obj_araw[15:7], obj_araw[5:4], obj_araw[6] };

jtframe_vtimer #(
    .V_START    ( 9'd0      ),
    .VB_START   ( 9'd239    ),
    .VB_END     ( 9'd15     ),
    .VCNT_END   ( 9'd279    ),
    .VS_START   ( 9'd250    ),
    .VS_END     ( 9'd253    ),
    .HJUMP      ( 1         ),
    .HB_START   ( 9'h0FF    ),
    .HB_END     ( 9'h1FF    ),
    .HS_START   ( 9'h1A0    ),
    .HS_END     ( 9'h1C0    )
) u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   (           ),
    .H          ( hdump     ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( preLHBL   ),
    .LVBL       ( preLVBL   ),
    .HS         ( HS        ),
    .VS         ( VS        )
);

jtframe_scroll #(
    .SIZE       (  8        ),
    .CW         ( 11        ),
    .PW         (  8        ),
    .VA         ( 10        ),
    .MAP_HW     (  8        ),
    .MAP_VW     (  8        ),
    .XOR_HFLIP  (  1        ),
    .XOR_VFLIP  (  1        ),
    .HJUMP      (  1        )
) u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .hs         ( HS        ),
    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .blankn     ( preLVBL   ),
    .flip       ( flip      ),
    .scrx       ( scrx + HOFFSET ),
    .scry       ( 8'd0      ),

    .vram_addr  ( scr_vaddr ),

    .code       ( { cscan_dout[2:0], vscan_dout } ),
    .pal        ( cscan_dout[7:4] ),
    .hflip      ( cscan_dout[3]   ),
    .vflip      ( 1'b0      ),

    .rom_addr   ( scr_addr  ),
    .rom_data   ( scr_sorted),
    .rom_cs     ( scr_cs    ),
    .rom_ok     ( scr_ok    ),

    .pxl        ( scr_pxl   )
);

jttrcdoc_objscan u_objscan(
    .clk        ( clk       ),
    .hs         ( HS        ),
    .blankn     ( preLVBL   ),
    .vrender    ( vrender   ),

    .code       ( obj_code  ),
    .hpos       ( obj_hpos  ),
    .ysub       ( obj_ysub  ),
    .pal        ( obj_pal   ),
    .hflip      ( obj_hflip ),
    .vflip      ( obj_vflip ),

    .ram_addr   ( oscan_addr),
    .ram_dout   ( oscan_dout),

    .dr_busy    ( dr_busy   ),
    .dr_draw    ( dr_draw   )
);

jtframe_objdraw #(
    .AW         (  9        ),
    .CW         (  9        ),
    .PW         (  8        ),
    .PACKED     (  1        ),
    .HJUMP      (  1        )
) u_objdraw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( HS        ),
    .flip       ( flip      ),
    .hdump      ( hdump     ),

    .draw       ( dr_draw   ),
    .busy       ( dr_busy   ),
    .code       ( obj_code  ),
    .xpos       ( obj_hpos  ),
    .ysub       ( obj_ysub  ),
    .hzoom      ( 6'd0      ),
    .hz_keep    ( 1'b0      ),

    .hflip      ( obj_hflip ),
    .vflip      ( obj_vflip ),
    .pal        ( obj_pal   ),

    .rom_addr   ( obj_araw  ),
    .rom_cs     ( objrom_cs ),
    .rom_ok     ( objrom_ok ),
    .rom_data   ( objrom_data),

    .pxl        ( obj_pxl   )
);

jttrcdoc_colmix u_colmix(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .obj_pxl    ( obj_pxl   ),
    .scr_pxl    ( scr_pxl   ),
    .preLHBL    ( preLHBL   ),
    .preLVBL    ( preLVBL   ),

    .pen        ( pen       ),
    .r_data     ( rpal_data ),
    .g_data     ( gpal_data ),
    .b_data     ( bpal_data ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .gfx_en     ( gfx_en    )
);

endmodule
