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

module jtaliens_video(
    input             rst,
    input             clk,
    input             pxl_cen,
    input      [ 1:0] cfg,
    input      [ 1:0] cpu_prio,

    // Base Video
    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs,

    // CPU interface
    input      [15:0] cpu_addr,
    input      [ 7:0] cpu_dout,
    output     [ 7:0] pal_dout,
    output     [ 7:0] tilesys_dout,
    output     [ 7:0] objsys_dout,
    input             pal_we,
    input             cpu_we,
    input             tilesys_cs,
    input             objsys_cs,
    output            rst8,     // reset signal at 8th frame

    // control
    input             rmrd,     // Tile ROM read mode

    output            cpu_irq_n,
    output            cpu_nmi_n,
    output            flip,

    // PROMs
    input      [ 7:0] prog_addr,
    input      [ 2:0] prog_data,
    input             prom_we,

    // Tile ROMs
    output     [20:2] lyrf_addr,
    output     [20:2] lyra_addr,
    output     [20:2] lyrb_addr,
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

`include "jtaliens.inc"

wire [ 8:0] hdump, vdump, vrender1;
wire [ 7:0] lyrf_pxl, st_scr, st_obj,
            dump_scr, dump_obj, dump_pal;
wire [11:0] lyra_pxl, lyrb_pxl;
wire [11:0] lyro_pxl;
wire        lyrf_blnk_n, lyra_blnk_n, lyrb_blnk_n, lyro_blnk_n;
wire        prio_we, tile_irqn, obj_irqn, tile_nmin, obj_nmin, shadow;

assign prio_we = prom_we & (cfg==SCONTRA | ~prog_addr[7]);
// Aliens programs the interrupts on the sprite chip, but
// the other games use the tilemapper chip instead
assign cpu_irq_n = cfg==ALIENS ? obj_irqn : tile_irqn;
assign cpu_nmi_n = cfg==ALIENS ? obj_nmin : tile_nmin;

// Debug
always @(posedge clk) begin
    st_dout <= debug_bus[5] ? st_obj : st_scr;
    // VRAM dumps - 16+2+3 = 19kB +16 bytes = 19472 bytes
    if( !ioctl_addr[14] )
        ioctl_din <= dump_scr;  // 16 kB 0000~3FFF
    else if( !ioctl_addr[11] )
        ioctl_din <= dump_pal;  // 2kB 4000~47FF
    else if( !ioctl_addr[10] )
        ioctl_din <= dump_obj;  // 1kB 4800~4C00
    else if( !ioctl_addr[3] )
        ioctl_din <= dump_scr;  // 8 bytes, MMR 4C07
    else if (ioctl_addr[2:0]!=7)
        ioctl_din <= dump_obj;  // 7 bytes, MMR 4C0E
    else
        ioctl_din <= { 6'd0, cpu_prio }; // 1 byte, 4C0F
end

/* verilator tracing_on */
jtaliens_scroll u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .cfg        ( cfg       ),

    // Base Video
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),
    .hs         ( hs        ),
    .vs         ( vs        ),

    // CPU interface
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_we     ( cpu_we    ),
    .gfx_cs     ( tilesys_cs),
    .rst8       ( rst8      ),
    .tile_dout  ( tilesys_dout ),

    // control
    .rmrd       ( rmrd      ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .vrender1   ( vrender1  ),

    .irq_n      ( tile_irqn ),
    .firq_n     (           ),
    .nmi_n      ( tile_nmin ),
    .flip       ( flip      ),


    // Tile ROMs
    .lyrf_addr  ( lyrf_addr ),
    .lyra_addr  ( lyra_addr ),
    .lyrb_addr  ( lyrb_addr ),

    .lyrf_cs    ( lyrf_cs   ),
    .lyra_cs    ( lyra_cs   ),
    .lyrb_cs    ( lyrb_cs   ),

    .lyrf_data  ( lyrf_data ),
    .lyra_data  ( lyra_data ),
    .lyrb_data  ( lyrb_data ),

    // Final pixels
    .lyrf_blnk_n(lyrf_blnk_n),
    .lyra_blnk_n(lyra_blnk_n),
    .lyrb_blnk_n(lyrb_blnk_n),
    .lyrf_pxl   ( lyrf_pxl  ),
    .lyra_pxl   ( lyra_pxl  ),
    .lyrb_pxl   ( lyrb_pxl  ),

    // Debug
    .ioctl_addr ( ioctl_addr[14:0]),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_din  ( dump_scr  ),

    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_scr    )
);

/* verilator tracing_on */
jtaliens_obj u_obj(    // sprite logic
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .cfg        ( cfg       ),
    // Base Video (inputs)
    .hs         ( hs        ),
    .vs         ( vs        ),
    .lvbl       ( lvbl      ),
    .lhbl       ( lhbl      ),
    .hdump      ( hdump     ),
    .vdump      ( vrender1  ),
    // CPU interface
    .cs         ( objsys_cs ),
    .cpu_addr   (cpu_addr[10:0]),
    .cpu_dout   ( cpu_dout  ),
    .cpu_we     ( cpu_we    ),
    .cpu_din    ( objsys_dout),

    .irq_n      ( obj_irqn  ),
    .nmi_n      ( obj_nmin  ),
    // ROM
    .rom_addr   ( lyro_addr ),
    .rom_data   ( lyro_data ),
    .rom_ok     ( lyro_ok   ),
    .rom_cs     ( lyro_cs   ),
    // pixel output
    .pxl        ( lyro_pxl  ),
    .blank_n    (lyro_blnk_n),
    .shadow     ( shadow    ),

    // Debug
    .ioctl_addr ( ioctl_addr[10:0]),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_din  ( dump_obj  ),

    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_obj    )
);

/* verilator tracing_off */
jtaliens_colmix u_colmix(
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