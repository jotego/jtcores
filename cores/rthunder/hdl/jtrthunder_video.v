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
    Date: 15-3-2025 */

module jtrthunder_video(
    input             rst,
    input             clk,
    input             pxl_cen, flip,

    output            lvbl, lhbl, hs, vs,
    input      [ 8:0] scr0x, scr0y, scr1x, scr1y,
    input      [ 7:0] backcolor,

    // Tile ROM decoder PROM
    output     [ 4:0] dec0_addr, dec1_addr,
    input      [ 7:0] dec0_data, dec1_data,

    // ROMs
    output            scr0_cs,   scr1_cs,
    output     [15:2] scr0_addr, scr1_addr,
    input      [31:0] scr0_data, scr1_data,
    input             scr0_ok,   scr1_ok,

    // Palette PROMs
    output     [10:0] scrpal_addr,
    input      [ 7:0] scrpal_data,

    output     [ 8:0] rgb_addr,
    input      [ 7:0] rg_data,
    input      [ 3:0] b_data,
    output     [ 3:0] red, green, blue,
    // Debug
    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus
    // output reg [ 7:0] st_dout
);

wire [10:0] scr0_pxl, scr1_pxl;
wire [ 7:0] obj_pxl;
wire [ 2:0] obj_prio, scr_prio;


jtshouse_vtimer u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   ( vrender1  ),
    .hdump      ( hdump     ),
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),
    .hs         ( hs        ),
    .vs         ( vs        )
);

jtrthunder_scroll #(.ID(0)) u_scroll0(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .flip       ( flip          ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),
    .scrx       ( scr0x         ),
    .scry       ( scr0y         ),

    .vram_addr  ( vram0_addr    ),
    .vram_dout  ( vram0_dout    ),
    .dec_addr   ( dec0_addr     ),
    .dec_data   ( dec0_data     ),

    .rom_cs     ( scr0_cs       ),
    .rom_addr   ( scr0_addr     ),
    .rom_data   ( scr0_data     ),
    .rom_ok     ( scr0_ok       ),

    .pxl        ( scr0_pxl      )
);

jtrthunder_scroll #(.ID(1)) u_scroll1(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .flip       ( flip          ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),
    .scrx       ( scr1x         ),
    .scry       ( scr1y         ),

    .vram_addr  ( vram1_addr    ),
    .vram_dout  ( vram1_dout    ),
    .dec_addr   ( dec1_addr     ),
    .dec_data   ( dec1_data     ),

    .rom_cs     ( scr1_cs       ),
    .rom_addr   ( scr1_addr     ),
    .rom_data   ( scr1_data     ),
    .rom_ok     ( scr1_ok       ),

    .pxl        ( scr1_pxl      )
);

jtrthunder_colmix u_colmix(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    .scr0_prio  ( scr0_prio ),
    .scr1_prio  ( scr1_prio ),
    .backcolor  ( backcolor ),

    .scrpal_addr(scrpal_addr),
    .scrpal_data(scrpal_data),

    .scr0_pxl   ( scr0_pxl  ),
    .scr1_pxl   ( scr1_pxl  ),
    .obj_pxl    ( obj_pxl   ),
    .obj_prio   ( obj_prio  ),
    .scr_prio   ( scr_prio  ),

    .rgb_addr   ( rgb_addr  ),
    .rg_data    ( rg_data   ),
    .b_data     ( b_data    ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .gfx_en     ( gfx_en    )
);

endmodule    
