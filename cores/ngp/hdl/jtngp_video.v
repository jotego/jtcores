/*  This file is part of JTNGP.
    JTNGP program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTNGP program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTNGP.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. https://patreon.com/jotego
    Version: 1.0
    Date: 22-3-2022 */

module jtngp_video(
    input               rst,
    input               clk,
    input               clk24,
    output              pxl_cen,
    output              pxl2_cen,

    input        [31:0] status,
    output              cpu_cen,
    output              snd_cen,

    // CPU
    input        [12:1] cpu_addr,
    input        [15:0] cpu_dout,
    input        [ 1:0] dsn,

    input               chram_cs,
    input               obj_cs,
    input               scr1_cs,
    input               scr2_cs,
    input               regs_cs,

    output       [15:0] regs_dout,
    output       [15:0] cha_dout,
    output       [15:0] obj_dout,
    output       [15:0] scr1_dout,
    output       [15:0] scr2_dout,

    output              hirq,
    output              virq,

    output              HS,
    output              VS,
    output              LHBL_dly,
    output              LVBL_dly,
    output       [ 3:0] red,
    output       [ 3:0] green,
    output       [ 3:0] blue,
    input        [ 3:0] gfx_en
);

wire [ 9:0] hcnt;
wire [ 7:0] vdump;
wire [ 7:0] vrender;
wire [ 8:0] hdump;
wire        LHBL, LVBL;
wire [ 4:0] multi_cen;
wire [ 1:0] video_cen;

// video access
wire [15:0] scr1_data, scr2_data, obj_data;
wire [12:1] scr1_addr, scr2_addr, obj_addr;
wire        obj_rd, obj_ok;

// video configuration
wire [ 7:0] hoffset, voffset,
            scr1_hpos, scr1_vpos,
            scr2_hpos, scr2_vpos,
            view_width, view_height,
            view_startx,view_starty;
wire        scr_order=0;

wire [ 4:0] obj_pxl;
wire [ 2:0] scr1_pxl, scr2_pxl;
wire        hint_en=1, vint_en=1;

assign snd_cen  = multi_cen[1];
assign cpu_cen  = multi_cen[0]; // fixed for now
assign hoffset  = 0;
assign voffset  = 0;

jtngp_clocks u_clocks(
    .status     ( status    ),
    // 24 MHz domain
    .clk24      ( clk24     ),
    .multi_cen  ( multi_cen ),
    // 48 MHz domain
    .clk        ( clk       ),
    .video_cen  ( video_cen )
);

jtngp_vtimer u_vtimer(
    .clk        ( clk       ),
    .video_cen  ( video_cen ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),
    .hint_en    ( hint_en   ),
    .vint_en    ( vint_en   ),
    // outputs:
    .hcnt       ( hcnt      ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .HS         ( HS        ),
    .VS         ( VS        ),
    .hirq       ( hirq      ),
    .virq       ( virq      )
);

jtngp_mmr u_mmr(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .hcnt       ( hcnt      ),
    .vdump      ( vdump     ),
    .LVBL       ( LVBL      ),
    // CPU access
    .cpu_addr   ( cpu_addr  ),
    .cpu_din    ( regs_dout ),
    .cpu_dout   ( cpu_dout  ),
    .dsn        ( dsn       ),
    .regs_cs    ( regs_cs   ),
    // video access
    .hoffset    ( hoffset   ),
    .voffset    ( voffset   ),
    .scr1_hpos  ( scr1_hpos ),
    .scr1_vpos  ( scr1_vpos ),
    .scr2_hpos  ( scr2_hpos ),
    .scr2_vpos  ( scr2_vpos ),
    .view_width ( view_width  ),
    .view_height( view_height ), // it influences when interrupts occur too
    .view_startx( view_startx ),
    .view_starty( view_starty ),
    .scr_order  ( scr_order )
);

jtngp_chram u_chram(
    .rst        ( rst       ),
    .clk        ( clk       ),
    // CPU access
    .cpu_addr   ( cpu_addr  ),
    .cpu_din    ( cha_dout  ),
    .cpu_dout   ( cha_dout  ),
    .dsn        ( dsn       ),
    .chram_cs   ( chram_cs  ),
    // video access
    .obj_rd     ( obj_rd    ),
    .obj_ok     ( obj_ok    ),
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),

    .scr1_addr  ( scr1_addr ),
    .scr1_data  ( scr1_data ),
    .scr2_addr  ( scr2_addr ),
    .scr2_data  ( scr2_data )
);

jtngp_scr #(
    .SIMFILE_LO("scr1_lo.bin"),
    .SIMFILE_HI("scr1_hi.bin")
) u_scr1 (
    .rst        ( rst       ),
    .clk        ( clk       ),
    .LHBL       ( LHBL      ),
    .pxl_cen    ( pxl_cen   ),

    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .hpos       ( scr1_hpos ),
    .vpos       ( scr1_vpos ),
    // CPU access
    .cpu_addr   ( cpu_addr[10:1] ),
    .cpu_din    ( scr1_dout ),
    .cpu_dout   ( cpu_dout  ),
    .dsn        ( dsn       ),
    .scr_cs     ( scr1_cs   ),
    // Character RAM
    .chram_addr ( scr1_addr ),
    .chram_data ( scr1_data ),
    // video output
    .pxl        ( scr1_pxl  )
);

jtngp_scr #(
    .SIMFILE_LO("scr2_lo.bin"),
    .SIMFILE_HI("scr2_hi.bin")
) u_scr2 (
    .rst        ( rst       ),
    .clk        ( clk       ),
    .LHBL       ( LHBL      ),
    .pxl_cen    ( pxl_cen   ),

    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .hpos       ( scr2_hpos ),
    .vpos       ( scr2_vpos ),
    // CPU access
    .cpu_addr   ( cpu_addr[10:1] ),
    .cpu_din    ( scr2_dout ),
    .cpu_dout   ( cpu_dout  ),
    .dsn        ( dsn       ),
    .scr_cs     ( scr2_cs   ),
    // Character RAM
    .chram_addr ( scr2_addr ),
    .chram_data ( scr2_data ),
    // video output
    .pxl        ( scr2_pxl  )
);

jtngp_obj u_obj(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .LHBL       ( LHBL      ),
    .pxl_cen    ( pxl_cen   ),
    .hdump      ( hdump     ),
    .vrender    (vrender[7:0]),
    // configuration
    .hoffset    ( hoffset   ),
    .voffset    ( voffset   ),
    // CPU access
    .cpu_addr   ( cpu_addr[7:1] ),
    .cpu_din    ( obj_dout  ),
    .cpu_dout   ( cpu_dout  ),
    .dsn        ( dsn       ),
    .obj_cs     ( obj_cs    ),
    // Character RAM
    .chram_addr ( obj_addr  ),
    .chram_data ( obj_data  ),
    .chram_rd   ( obj_rd    ),
    .chram_ok   ( obj_ok    ),
    // video output
    .pxl        ( obj_pxl   )
);

jtngp_colmix u_colmix(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .scr_order  ( scr_order ),

    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .LHBL_dly   ( LHBL_dly  ),
    .LVBL_dly   ( LVBL_dly  ),

    .scr1_pxl   ( scr1_pxl  ),
    .scr2_pxl   ( scr2_pxl  ),
    .obj_pxl    ( obj_pxl   ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .gfx_en     ( gfx_en    )
);

endmodule