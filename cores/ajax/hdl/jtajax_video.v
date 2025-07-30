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
    Date: 28-6-2025 */

module jtajax_video(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             pxl2_cen,
    input             cen24,
    input             cpu_prio,

    // Base Video
    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs,

    // CPU interface
    input      [15:0] main_addr,
    input      [ 7:0] main_dout,

    input      [15:0] sub_addr,
    input      [ 7:0] sub_dout,
    input             sub_we, rio_cs, vr_cs,

    output     [ 7:0] pal_dout,
    output     [ 7:0] tilesys_dout,
    output            tilesys_rom_dtack, psacck_ok,
    output     [ 7:0] objsys_dout, psac_dout,
    input             pal_we,
    input             main_we,
    input             tilesys_cs,
    input             objsys_cs,
    output            rst8,     // reset signal at 8th frame

    // control
    input             rmrd,     // Tile ROM read mode
    input             rvo,      // enables blanking for rotator chip

    output            tile_irqn, obj_irqn,
    output            flip,

    // PROMs
    input      [ 8:0] prog_addr,
    input      [ 2:0] prog_data,
    input             prom_we,

    // Tile ROMs
    output     [18:2] lyrf_addr,
    output     [18:2] lyra_addr,
    output     [18:2] lyrb_addr,
    output     [19:2] lyro_addr,

    output            lyrf_cs,
    output            lyra_cs,
    output            lyrb_cs,
    output            lyro_cs,

    input             lyra_ok,
    input             lyro_ok,

    input      [31:0] lyrf_data,
    input      [31:0] lyra_data,
    input      [31:0] lyrb_data,
    input      [31:0] lyro_data,

    output     [18:0] psac_addr,
    output            psac_cs,
    input             psac_ok,
    input      [ 7:0] psac_data,

    // Color
    output     [ 7:0] red,
    output     [ 7:0] green,
    output     [ 7:0] blue,

    // Debug
    input      [14:0] ioctl_addr,
    input             ioctl_ram,
    output     [ 7:0] ioctl_din,

    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

wire [ 8:0] hdump, vdump, vrender, vrender1;
wire [ 7:0] lyrf_pxl, st_scr, st_obj, rot_pxl,
            dump_scr, dump_obj, dump_pal, dump_psac, dump_other,
            lyrf_col, lyra_col, lyrb_col, obj_mmr, psac_mmr, scr_mmr,
            opal;
wire [11:0] lyra_pxl, lyrb_pxl;
wire [11:0] lyro_pxl;
wire [12:0] pre_f, pre_a, pre_b, ocode;
wire [13:0] ocode_eff;
wire [ 4:0] nc;
wire        lyrf_blnk_n, lyra_blnk_n, lyrb_blnk_n, lyro_blnk_n, rot_blnk_n,
            e, q, shadow, nco;

assign ocode_eff = { 1'b0, ocode };

// Debug
assign dump_other = { 7'd0, cpu_prio };

jtajax_dump u_dump(
    .clk            ( clk           ),
    .dump_scr       ( dump_scr      ),
    .dump_obj       ( dump_obj      ),
    .dump_pal       ( dump_pal      ),
    .dump_psac      ( dump_psac     ),
    .psac_mmr       ( psac_mmr      ),
    .scr_mmr        ( scr_mmr       ),
    .obj_mmr        ( obj_mmr       ),
    .other          ( dump_other    ),

    .ioctl_addr     ( ioctl_addr    ),
    .ioctl_din      ( ioctl_din     ),

    .debug_bus      ( debug_bus     ),
    .st_scr         ( st_scr        ),
    .st_dout        ( st_dout       )
);

assign lyrf_addr = { pre_f[12:11], lyrf_col[3:0], pre_f[10:0] };
assign lyra_addr = { pre_a[12:11], lyra_col[3:0], pre_a[10:0] };
assign lyrb_addr = { pre_b[12:11], lyrb_col[3:0], pre_b[10:0] };
/* verilator tracing_on */
jt051316 u_psac(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .cen24      ( cen24     ),
    .vs         ( vs        ),
    .hs         ( hs        ),
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),

    .cpu_addr   (sub_addr[10:0]),
    .cpu_dout   ( sub_dout  ),
    .cpu_we     ( sub_we    ),
    .cpu_din    ( psac_dout ),
    .cpu_ok     ( psacck_ok ),
    .vr_cs      ( vr_cs     ),
    .io_cs      ( rio_cs    ),
    .rvo        ( rvo       ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),

    .rom_ok     ( psac_ok   ),
    .rom_cs     ( psac_cs   ),
    .rom_data   ( psac_data ),
    .rom_addr   ({nc,psac_addr}),

    .pxl        ( rot_pxl   ),
    .blnk_n     ( rot_blnk_n),
    // Debug
    .ioctl_addr (ioctl_addr[10:0]),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_din  ( dump_psac ),
    .mmr_dump   ( psac_mmr  )
);

/* verilator tracing_on */
jtaliens_scroll u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    // unused
    .q          (           ),
    .e          (           ),

    // Base Video
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),
    .hs         ( hs        ),
    .vs         ( vs        ),

    // CPU interface
    .cpu_addr   ( sub_addr  ),
    .cpu_dout   ( sub_dout  ),
    .cpu_we     ( sub_we    ),
    .gfx_cs     ( tilesys_cs),
    .rst8       ( rst8      ),
    .tile_dout  ( tilesys_dout ),
    .cpu_rom_dtack ( tilesys_rom_dtack),

    // control
    .rmrd       ( rmrd      ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   ( vrender1  ),

    .irq_n      ( tile_irqn ),
    .firq_n     (           ),
    .nmi_n      (           ),
    .flip       ( flip      ),

    // color byte connection
    .lyrf_extra (           ),
    .lyra_extra (           ),
    .lyrb_extra (           ),

    .lyrf_col   ( lyrf_col  ),
    .lyra_col   ( lyra_col  ),
    .lyrb_col   ( lyrb_col  ),

    .lyrf_cg    ( lyrf_col  ),
    .lyra_cg    ( lyra_col  ),
    .lyrb_cg    ( lyrb_col  ),

    // Tile ROMs
    .lyrf_addr  ( pre_f     ),
    .lyra_addr  ( pre_a     ),
    .lyrb_addr  ( pre_b     ),

    .lyrf_cs    ( lyrf_cs   ),
    .lyra_cs    ( lyra_cs   ),
    .lyrb_cs    ( lyrb_cs   ),

    .lyrf_data  ( lyrf_data ),
    .lyra_data  ( lyra_data ),
    .lyrb_data  ( lyrb_data ),

    .lyra_ok    ( lyra_ok   ),

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
    .mmr_dump   ( scr_mmr   ),

    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_scr    )
);

/* verilator tracing_on */
jtaliens_obj u_obj(    // sprite logic
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    // Base Video (inputs)
    .hs         ( hs        ),
    .vs         ( vs        ),
    .lvbl       ( lvbl      ),
    .lhbl       ( lhbl      ),
    .hdump      ( hdump     ),
    .vdump      ( vrender   ),
    // CPU interface
    .cs         ( objsys_cs ),
    .cpu_addr   (main_addr[10:0]),
    .cpu_dout   ( main_dout ),
    .cpu_we     ( main_we   ),
    .cpu_din    ( objsys_dout),

    .irq_n      ( obj_irqn  ),
    .nmi_n      (           ),
    .romrd      (           ),
    // external connection
    .pal        ( opal      ),
    .code       ( ocode     ),
    .code_eff   ( ocode_eff ),
    .pal_eff    ( opal      ),
    // ROM
    .rom_addr   ({nco,lyro_addr}),
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
    .dump_reg   ( obj_mmr   ),

    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_obj    )
);

/* verilator tracing_on */
jtajax_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .cpu_prio   ( cpu_prio  ),

    // Base Video
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),

    // CPU interface
    .cpu_addr   (main_addr[11:0]),
    .cpu_din    ( pal_dout  ),
    .cpu_dout   ( main_dout ),
    .cpu_we     ( pal_we    ),

    // PROMs
    .prog_addr  ( prog_addr ),
    .prog_data  ( prog_data ),
    .prom_we    ( prom_we   ),

    // Final pixels
    .lyrf_blnk_n(lyrf_blnk_n),
    .lyra_blnk_n(lyra_blnk_n),
    .lyrb_blnk_n(lyrb_blnk_n),
    .lyro_blnk_n(lyro_blnk_n),
    .rot_blnk_n (rot_blnk_n ),

    .lyrf_pxl   ( lyrf_pxl  ),
    .lyra_pxl   ( lyra_pxl  ),
    .lyrb_pxl   ( lyrb_pxl  ),
    .lyro_pxl   ( lyro_pxl  ),
    .rot_pxl    ( rot_pxl   ),
    .shadow     ( shadow    ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),

    // Debug
    .ioctl_addr ( ioctl_addr[11:0]),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_din  ( dump_pal  ),

    .debug_bus  ( debug_bus )
);

endmodule