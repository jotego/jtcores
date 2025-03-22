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
    output            scr0a_cs,   scr0b_cs,   scr1a_cs,   scr1b_cs,
    output     [15:2] scr0a_addr, scr0b_addr, scr1a_addr, scr1b_addr,
    input      [31:0] scr0a_data, scr0b_data, scr1a_data, scr1b_data,
    input             scr0a_ok,   scr0b_ok,   scr1a_ok,   scr1b_ok,

    // Palette PROMs
    output     [10:0] scrpal_addr,
    input      [ 7:0] scrpal_data,

    output     [ 8:0] rgb_addr,
    input      [ 7:0] rg_data,
    input      [ 3:0] b_data,
    output     [ 3:0] red, green, blue,

    input      [ 2:0] ioctl_addr,
    output     [ 7:0] ioctl_din,
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

jtrthunder_cus42 #(.ID(0)) u_scroll0(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .flip       ( flip          ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),

    .cs         ( mmr0_cs       ),
    .rnw        ( rnw           ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_dout   ( cpu_dout      ),

    .vram_addr  ( vram0_addr    ),
    .vram_dout  ( vram0_dout    ),
    .dec_addr   ( dec0_addr     ),
    .dec_data   ( dec0_data     ),

    .roma_cs    ( scr0a_cs      ),
    .roma_addr  ( scr0a_addr    ),
    .roma_data  ( scr0a_data    ),
    .roma_ok    ( scr0a_ok      ),

    .romb_cs    ( scr0b_cs      ),
    .romb_addr  ( scr0b_addr    ),
    .romb_data  ( scr0b_data    ),
    .romb_ok    ( scr0b_ok      ),

    .ioctl_addr ( ioctl_addr    ),
    .ioctl_din  ( ioctl_din     ),

    .prio       ( scr0_prio     ),
    .pxl        ( scr0_pxl      )
);

jtrthunder_cus42 #(.ID(1)) u_scroll1(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .flip       ( flip          ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),

    .cs         ( mmr1_cs       ),
    .rnw        ( rnw           ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_dout   ( cpu_dout      ),

    .vram_addr  ( vram1_addr    ),
    .vram_dout  ( vram1_dout    ),
    .dec_addr   ( dec1_addr     ),
    .dec_data   ( dec1_data     ),

    .roma_cs    ( scr1a_cs      ),
    .roma_addr  ( scr1a_addr    ),
    .roma_data  ( scr1a_data    ),
    .roma_ok    ( scr1a_ok      ),

    .romb_cs    ( scr1b_cs      ),
    .romb_addr  ( scr1b_addr    ),
    .romb_data  ( scr1b_data    ),
    .romb_ok    ( scr1b_ok      ),

    .ioctl_addr ( ioctl_addr    ),
    .ioctl_din  ( ioctl_din     ),

    .prio       ( scr1_prio     ),
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
