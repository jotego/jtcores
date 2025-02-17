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
    Date: 22-11-2024 */

module jtflstory_video(
    input             rst,
    input             clk,
    input             pxl_cen,
                      priocfg, palwcfg, objcfg,

    input             ghflip,
    input             gvflip,
    output            lhbl,
    output            lvbl,
    output            vs,
    output            hs,

    // Scroll
    input      [ 1:0] scr_bank,
    output     [10:1] vram_addr,
    input      [15:0] vram_data,
    output     [16:2] scr_addr,
    input      [31:0] scr_data,
    output            scr_cs,
    input             scr_ok,
    input             scr_flen,

    // Objects
    //      RAM shared with CPU
    output     [ 7:0] oram_addr,
    output     [ 7:0] oram_din,
    output            oram_we,
    input      [ 7:0] oram_dout,
    //      ROM
    output     [16:2] obj_addr,
    input      [31:0] obj_data,
    output            obj_cs,
    input             obj_ok,

    // palette - color mixer
    input      [ 1:0] pal_bank,
    output     [ 9:0] pal_addr,
    input      [15:0] pal_dout,
    output     [ 3:0] red, green, blue,
    input       [3:0] gfx_en,
    input       [7:0] debug_bus
);

wire [ 8:0] vdump, hdump;
wire [ 7:0] scr_pxl, obj_pxl;
wire [ 2:0] obj_prio;
wire [ 1:0] scr_prio;
reg         lhbl_short;

always @(posedge clk) lhbl_short <= !(hdump>9'h9a && hdump<9'h100);

jtframe_vtimer #(
    .V_START    ( 9'h0f0    ),
    .VCNT_END   ( 9'h1ff    ),
    .VB_START   ( 9'h1ef    ),
    .VB_END     ( 9'h10f    ),
    .VS_START   ( 9'h0f8    ),

    .HCNT_START ( 9'h080    ),
    .HCNT_END   ( 9'h1ff    ),
    .HS_START   ( 9'h0ad    ),
    .HB_START   ( 9'h08a    ),
    .HB_END     ( 9'h10a    )
)   u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    (           ),
    .vrender1   (           ),
    .H          ( hdump     ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( lhbl      ),
    .LVBL       ( lvbl      ),
    .HS         ( hs        ),
    .VS         ( vs        )
);

// original video seems to draw the tile map on the fly, whereas the
// objects are written to a single buffer during HB and then dumped on
// the same line. There is no double-line buffer, despite being enough memory
// to implement it. This sets a harsh limit of 128/16=8 sprites per line

jtflstory_scroll u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .lvbl       ( lvbl      ),
    .hs         ( hs        ),

    .gvflip     ( gvflip    ),
    .ghflip     ( ghflip    ),
    .palwcfg    ( palwcfg   ),

    .bank       ( scr_bank  ),
    .flen       ( scr_flen  ),

    .vram_addr  ( vram_addr ),
    .vram_data  ( vram_data ),
    .oram_dout  ( oram_dout ),

    .rom_addr   ( scr_addr  ),
    .rom_data   ( scr_data  ),
    .rom_cs     ( scr_cs    ),
    .rom_ok     ( scr_ok    ),

    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .prio       ( scr_prio  ),
    .pxl        ( scr_pxl   )
);

jtflstory_obj u_obj(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .lvbl       ( lvbl      ),
    .lhbl       ( lhbl      ),
    .hs         ( hs        ),
    .gvflip     ( gvflip    ),
    .ghflip     ( ghflip    ),
    .layout     ( objcfg    ),

    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    // RAM shared with CPU
    .ram_addr   ( oram_addr ),
    .ram_dout   ( oram_dout ),
    .ram_din    ( oram_din  ),
    .ram_we     ( oram_we   ),
    // ROM
    .rom_addr   ( obj_addr  ),
    .rom_data   ( obj_data  ),
    .rom_cs     ( obj_cs    ),
    .rom_ok     ( obj_ok    ),
    .prio       ( obj_prio  ),
    .pxl        ( obj_pxl   )
);

jtflstory_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .priocfg    ( priocfg   ),

    .lvbl       ( lvbl      ),
    .lhbl       ( lhbl_short),
    .bank       ( pal_bank  ),

    .scr_prio   ( scr_prio  ),
    .obj_prio   ( obj_prio  ),

    .scr_pxl    ( scr_pxl   ),
    .obj_pxl    ( obj_pxl   ),

    .pal_addr   ( pal_addr  ),
    .pal_dout   ( pal_dout  ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .debug_bus  ( debug_bus ),
    .gfx_en     ( gfx_en    )
);

endmodule