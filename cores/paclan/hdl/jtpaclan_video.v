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
    Date: 18-5-2025 */

module jtpaclan_video(
    input             rst,
    input             clk,
    input             pxl_cen, pxl2_cen, flip,

    output            lvbl, lhbl, hs, vs,
    input      [ 1:0] palbank,
    input      [ 8:0] scr0_pos, scr1_pos,

    output     [12:1] oram_addr,
    output     [11:1] vram0_addr, vram1_addr,
    input      [15:0] vram0_dout, vram1_dout, oram_dout,

    // ROMs
    output            scr0_cs,   scr1_cs,
    output     [12:1] scr0_addr, scr1_addr,
    input      [15:0] scr0_data, scr1_data,
    input             scr0_ok,   scr1_ok,
    output            obj_cs,
    output     [15:2] obj_addr,
    input      [31:0] obj_data,
    input             obj_ok,

    // Palette PROMs
    output     [ 9:0] scr0pal_addr, scr1pal_addr, objpal_addr,
    input      [ 7:0] scr0pal_data, scr1pal_data, objpal_data,

    output     [ 9:0] rgb_addr,
    input      [ 7:0] rg_data,
    input      [ 3:0] b_data,
    output     [ 3:0] red, green, blue,

    // Debug
    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

wire [ 9:0] scr0_pxl, scr1_pxl;
wire [ 7:0] obj_pxl;
wire [ 8:0] hdump, vdump, vrender, vrender1;
wire        scr0_prio, fixed;

assign st_dout   =0;

jtshouse_vtimer u_vtimer(
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .vrender1   ( vrender1      ),
    .hdump      ( hdump         ),
    .lhbl       ( lhbl          ),
    .lvbl       ( lvbl          ),
    .hs         ( hs            ),
    .vs         ( vs            )
);

jtcus36 u_scroll(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( hs            ),
    .flip       ( flip          ),
    .fixed      ( fixed         ),
    .scr0_pos   ( scr0_pos      ),
    .scr1_pos   ( scr1_pos      ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),

    .vram0_addr ( vram0_addr    ),
    .vram0_dout ( vram0_dout    ),

    .vram1_addr ( vram1_addr    ),
    .vram1_dout ( vram1_dout    ),

    .rom0_cs    ( scr0_cs       ),
    .rom0_addr  ( scr0_addr     ),
    .rom0_data  ( scr0_data     ),
    .rom0_ok    ( scr0_ok       ),

    .rom1_cs    ( scr1_cs       ),
    .rom1_addr  ( scr1_addr     ),
    .rom1_data  ( scr1_data     ),
    .rom1_ok    ( scr1_ok       ),

    .prio0      ( scr0_prio     ),
    .pxl0       ( scr0_pxl      ),
    .pxl1       ( scr1_pxl      ),
    // debug
    .debug_bus  ( debug_bus     )
);

jtpaclan_obj u_obj(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .lvbl       ( lvbl          ),
    .hs         ( hs            ),
    .flip       ( flip          ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),

    // Look-up table
    .ram_addr   ( oram_addr     ),
    .ram_dout   ( oram_dout     ),
    .pal_addr   ( objpal_addr   ),
    .pal_data   ( objpal_data   ),

    .rom_cs     ( obj_cs        ),
    .rom_addr   ( obj_addr      ),
    .rom_data   ( obj_data      ),
    .rom_ok     ( obj_ok        ),

    .pxl        ( obj_pxl       ),

    .debug_bus  ( debug_bus     )
);

jtpaclan_colmix u_colmix(
    .clk          ( clk             ),
    .pxl_cen      ( pxl_cen         ),
    .pxl2_cen     ( pxl2_cen        ),
    .palbank      ( palbank         ),
    .fixed        ( fixed           ),

    .scr0pal_addr ( scr0pal_addr    ),
    .scr1pal_addr ( scr1pal_addr    ),
    .scr0pal_data ( scr0pal_data    ),
    .scr1pal_data ( scr1pal_data    ),

    .scr0_pxl     ( scr0_pxl        ),
    .scr1_pxl     ( scr1_pxl        ),
    .obj_pxl      ( obj_pxl         ),
    .scr0_prio    ( scr0_prio       ),

    .rgb_addr     ( rgb_addr        ),
    .rg_data      ( rg_data         ),
    .b_data       ( b_data          ),

    .red          ( red             ),
    .green        ( green           ),
    .blue         ( blue            ),
    .gfx_en       ( gfx_en          )
);

endmodule    
