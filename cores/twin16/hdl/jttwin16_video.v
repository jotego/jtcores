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
    Date: 27-7-2023 */

module jttwin16_video(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             pxl2_cen,

    // Base Video
    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs,

    // CPU interface
    input      [15:0] cpu_addr,
    input      [ 7:0] cpu_dout,
    output     [ 7:0] pal_dout,
    output     [ 7:0] vram_dout,
    output     [ 7:0] oram_dout,
    input             pal_we,
    input             cpu_we,
    input             vram_cs,
    input             oram_cs,

    // control
    input      [ 1:0] cpu_prio,
    input      [ 2:0] hscr1, hscr2,
    input      [ 9:0] obj_offsetx, obj_offsety,

    input              hflip,
    input              vflip,

    // PROMs
    input      [ 7:0] prog_addr,
    input      [ 2:0] prog_data,
    input             prom_we,

    // Video RAM
    output     [11:1] fram_addr,
    input      [15:0] fram_data,

    // Tile ROMs
    output reg [20:2] lyrf_addr,
    output reg [20:2] lyra_addr,
    output reg [20:2] lyrb_addr,
    output     [20:2] lyro_addr,

    output            lyrf_cs,
    output            lyra_cs,
    output            lyrb_cs,
    output            lyro_cs,

    input             lyro_ok,

    input      [31:0] lyrf_data,
    input      [31:0] lyra_data,
    input      [31:0] lyrb_data,
    input      [31:0] lyro_data,

    // Color
    output     [ 7:0] red,
    output     [ 7:0] green,
    output     [ 7:0] blue,

    // Debug
    input      [14:0] ioctl_addr,
    input             ioctl_ram,
    output reg [ 7:0] ioctl_din,

    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output reg [ 7:0] st_dout
);

localparam [8:0] HB_OFFSET=0;

wire [ 8:0] vdump, hdump, vrender, vrender1;
wire        flip;
wire [31:0] fsorted;

assign flip = hflip & vflip;
assigned fsorted = {
    lyrf_data[31], lyrf_data[27], lyrf_data[23], lyrf_data[19], // plane 3
    lyrf_data[15], lyrf_data[11], lyrf_data[ 7], lyrf_data[ 3],
    lyrf_data[30], lyrf_data[26], lyrf_data[22], lyrf_data[18], // plane 2
    lyrf_data[14], lyrf_data[10], lyrf_data[ 6], lyrf_data[ 2],
    lyrf_data[29], lyrf_data[25], lyrf_data[21], lyrf_data[17], // plane 1
    lyrf_data[13], lyrf_data[ 9], lyrf_data[ 5], lyrf_data[ 1],
    lyrf_data[28], lyrf_data[24], lyrf_data[20], lyrf_data[16], // plane 0
    lyrf_data[12], lyrf_data[ 8], lyrf_data[ 4], lyrf_data[ 0]
};

// functionality done by 007782
jtframe_vtimer #(
    .HCNT_START ( 9'h020    ),
    .HCNT_END   ( 9'h19F    ),
    .HB_START   ( 9'h029+HB_OFFSET ),
    .HB_END     ( 9'h069+HB_OFFSET ),
    .HS_START   ( 9'h034    ),

    .V_START    ( 9'h0F8    ),
    .VB_START   ( 9'h1EF    ),
    .VB_END     ( 9'h10F    ),
    .VS_START   ( 9'h1FF    ),
    .VS_END     ( 9'h0FF    ), // 60.6 Hz according to MAME
    .VCNT_END   ( 9'h1FF    )
) u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   ( vrender1  ),
    .H          ( hdump     ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( lhbl      ),
    .LVBL       ( lvbl      ),
    .HS         ( hs        ), // 16kHz according to Skutis' schematics
    .VS         ( vs        )
);

jtframe_tilemap #(
    .VA     (  11 ),
    .CW     (   9 ),
    .MAP_HW (   9 ),
    .MAP_VW (   8 )
)u_fix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .blankn     ( gfx_en[0] ),  // if !blankn there are no ROM requests
    .flip       ( flip      ),    // Screen flip

    .vram_addr  ( fram_addr ),

    .code       ( fram_data[8:0] ),
    .pal        ( fram_data[12:9]),
    .hflip      ( 1'b0      ),
    .vflip      ( 1'b0      ),

    .rom_addr   ( lyrf_addr ),
    .rom_data   ( fsorted   ),
    .rom_cs     ( lyrf_cs   ),
    .rom_ok     ( 1'b1      ),

    .pxl        ( pxl       )
);

jtframe_scroll #( parameter
    SIZE =  8,    // 8x8, 16x16 or 32x32
    VA   = 10,
    CW   = 12,
    PW   =  8,
    MAP_HW = 9,    // size of the map in pixels
    MAP_VW = 9,
    VR   = SIZE==8 ? CW+3 : SIZE==16 ? CW+5 : CW+7,
    XOR_HFLIP = 0, // set to 1 so hflip gets ^ with flip
    XOR_VFLIP = 0  // set to 1 so vflip gets ^ with flip
)(
    input              rst,
    input              clk,
    input              pxl_cen,

    input              hs,

    input        [8:0] vdump,
    input        [8:0] hdump,
    input              blankn,  // if !blankn there are no ROM requests
    input              flip,    // Screen flip
    input      [ 8:0]  scrx,
    input      [ 8:0]  scry,

    output     [VA-1:0]vram_addr,

    input      [CW-1:0]code,
    input      [PW-5:0]pal,
    input              hflip,
    input              vflip,

    output     [VR-1:0]rom_addr,
    input      [31:0]  rom_data,
    output             rom_cs,
    input              rom_ok,      // ignored. It assumes that data is always right

    output     [PW-1:0]pxl
);

/* verilator tracing_off */
jttwin16_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .cfg        ( cfg       ),
    .cpu_prio   ( cpu_prio  ),

    // Base Video
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),

    // CPU interface
    .cpu_addr   (cpu_addr[10:0]),
    .cpu_din    ( pal_dout  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_we     ( pal_we    ),

    // PROMs
    .prog_addr  ( prog_addr ),
    .prog_data  ( prog_data ),
    .prom_we    ( prio_we   ),

    // Final pixels
    .lyrf_blnk_n(lyrf_blnk_n),
    .lyra_blnk_n(lyra_blnk_n),
    .lyrb_blnk_n(lyrb_blnk_n),
    .lyro_blnk_n(lyro_blnk_n),
    .lyrf_pxl   ( lyrf_pxl  ),
    .lyra_pxl   ( lyra_pxl  ),
    .lyrb_pxl   ( lyrb_pxl  ),
    .lyro_pxl   ( lyro_pxl  ),
    .shadow     ( shadow    ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),

    // Debug
    .ioctl_addr ( ioctl_addr[10:0]),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_din  ( dump_pal  ),

    .debug_bus  ( debug_bus )
);

endmodule