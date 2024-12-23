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
    Date: 15-4-2023 */

module jtaliens_scroll(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             pxl2_cen,

    // Base Video
    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs,
    output     [ 8:0] hdump, vdump, vrender, vrender1,

    // CPU interface
    input             gfx_cs,
    input             cpu_we,
    input      [15:0] cpu_addr,
    input      [ 7:0] cpu_dout,
    output     [ 7:0] tile_dout,
    output            rst8,     // reset signal at 8th frame

    // control
    input             rmrd,     // Tile ROM read mode
    output            irq_n,
    output            firq_n,
    output            nmi_n,
    output            flip,
    output            e, q,


    // Tile ROMs
    output     [12:0] lyra_addr,
    output     [12:0] lyrb_addr,
    output     [12:0] lyrf_addr,

    output            lyrf_cs,
    output            lyra_cs,
    output            lyrb_cs,

    input      [31:0] lyrf_data,
    input      [31:0] lyra_data,
    input      [31:0] lyrb_data,

    output     [ 7:0] lyrf_col,
    output     [ 7:0] lyra_col,
    output     [ 7:0] lyrb_col,

    input      [ 7:0] lyrf_cg,
    input      [ 7:0] lyra_cg,
    input      [ 7:0] lyrb_cg,

    // Final pixels
    output            lyrf_blnk_n,
    output            lyra_blnk_n,
    output            lyrb_blnk_n,
    output     [ 7:0] lyrf_pxl,
    output     [11:0] lyra_pxl,
    output     [11:0] lyrb_pxl,

    // Debug
    input      [14:0] ioctl_addr,
    input             ioctl_ram,
    output     [ 7:0] ioctl_din,
    output     [ 7:0] mmr_dump,

    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

parameter [8:0] HB_EXTRAL=0,
                HB_EXTRAR=0;

wire [ 7:0] tilemap_dout, tilerom_dout;
wire [ 2:0] hsub_a, hsub_b;
wire        hflip_en;

assign lyrf_cs = gfx_en[0];
assign lyra_cs = gfx_en[1];
assign lyrb_cs = gfx_en[2];

assign tile_dout = rmrd ? tilerom_dout : tilemap_dout;

jt052109 u_tilemap(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    .lvbl       ( lvbl      ),
    // CPU interface
    .cpu_addr   ( cpu_addr  ),
    .cpu_din    (tilemap_dout),
    .cpu_dout   ( cpu_dout  ),
    .gfx_cs     ( gfx_cs    ),
    .cpu_we     ( cpu_we    ),
    .rst8       ( rst8      ),

    // control
    .rmrd       ( rmrd      ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .q          ( q         ),
    .e          ( e         ),

    // Fine grain scroll
    .hsub_a     ( hsub_a    ),
    .hsub_b     ( hsub_b    ),

    .irq_n      ( irq_n     ),
    .firq_n     ( firq_n    ),
    .nmi_n      ( nmi_n     ),
    .flip       ( flip      ),
    .hflip_en   ( hflip_en  ),

    // tile ROM addressing
    // original pins: { CAB2,CAB1,VC[10:0] }
    // [2:0] tile row (8 lines)
    .lyrf_addr  ( lyrf_addr ),
    .lyra_addr  ( lyra_addr ),
    .lyrb_addr  ( lyrb_addr ),

    .lyrf_col   ( lyrf_col  ),
    .lyra_col   ( lyra_col  ),
    .lyrb_col   ( lyrb_col  ),

    // Debug
    .ioctl_addr ( ioctl_addr),
    .ioctl_din  ( ioctl_din ),
    .ioctl_ram  ( ioctl_ram ),

    .debug_bus  ( debug_bus ),
    .mmr_dump   ( mmr_dump  ),
    .st_dout    ( st_dout   )
);

/* verilator tracing_on */
jt051962 #(
    .HB_EXTRAL  ( HB_EXTRAL ),
    .HB_EXTRAR  ( HB_EXTRAR )
) u_draw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .flip       ( flip      ),
    .hflip_en   ( hflip_en  ),

    .cpu_addr   (cpu_addr[1:0]),
    .cpu_din    (tilerom_dout),

    .lyrf_data  ( lyrf_data ),
    .lyra_data  ( lyra_data ),
    .lyrb_data  ( lyrb_data ),

    .lyrf_col   ( lyrf_cg   ),
    .lyra_col   ( lyra_cg   ),
    .lyrb_col   ( lyrb_cg   ),

    // Fine grain scroll
    .hsub_a     ( hsub_a    ),
    .hsub_b     ( hsub_b    ),

    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   ( vrender1  ),
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),
    .hs         ( hs        ),
    .vs         ( vs        ),

    .lyrf_blnk_n(lyrf_blnk_n),
    .lyra_blnk_n(lyra_blnk_n),
    .lyrb_blnk_n(lyrb_blnk_n),
    .lyrf_pxl   ( lyrf_pxl  ),
    .lyra_pxl   ( lyra_pxl  ),
    .lyrb_pxl   ( lyrb_pxl  ),

    // Debug
    .gfx_en     ( gfx_en    ),
    // Debug
    .debug_bus  ( debug_bus )
);

endmodule