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
            Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-8-2026 */

module jttaitox_video(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             pxl2_cen,
    input             p051a,

    output            LHBL,
    output            LVBL,     // cropped, for the framework and the colmix
    output            lvbl_raw, // uncropped, for the CPU interrupt
    output            HS,
    output            VS,
    output            flip,

    // 68k side
    input             cpu_rnw,
    input      [ 1:0] cpu_dsn,
    input      [12:0] cpu_addr,     // A[13:1]
    input      [15:0] cpu_dout,
    input             oram_cs,      // e00000 ORAM CS
    input             vdcm_cs,      // d00000 VDCM CS
    output     [15:0] vid_dout,

    // X1-001 internal RAM (mem.yaml `yram`)
    output     [ 9:0] col_addr,
    input      [ 7:0] col_data, yram_dout,
    output            yram_we,
    // OBJ RAM (mem.yaml `dma`)
    output     [13:1] dma_addr,
    output     [15:0] dma_din,
    output     [ 1:0] dma_we,
    input      [15:0] dma_dout, code_dout,
    output     [13:1] code_addr,

    // palette (mem.yaml `pal`)
    output     [ 9:1] pal_addr,
    input      [15:0] pal_data,

    // gfx ROMs
    output     [20:2] scr_addr,
    input      [31:0] scr_data,
    input             scr_ok,
    output            scr_cs,
    output     [20:2] obj_addr,
    input      [31:0] obj_data,
    input             obj_ok,
    output            obj_cs,

    output     [ 4:0] red, green, blue,

    input      [ 1:0] ioctl_addr,
    output     [ 7:0] ioctl_din,
    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

wire [8:0] vdump, vrender, hdump;

// Vertical placement of the rendered content INSIDE the visible window,
// the same knob cal50 calls OBJ_VOFF. Distinct from the raster window:
// moving VB_END/VB_START changes which lines are shown and exposes a
// blank line, while this changes what the engine draws on each line, so
// the picture moves with no black band.
//
// Keep at 0. The sim is byte-identical to MAME here, so any non-zero
// value is a deliberate divergence from the only reference we have and
// needs evidence from a real board, not from a display.
//
// Note jtkiwi_gfx ignores its vrender input - internally it feeds vdump
// to the obj module - so vdump is the only counter that shifts anything.
localparam [8:0] OBJ_VOFF = 9'd0;
wire [8:0] vdump_adj = vdump + OBJ_VOFF;

// P0-051A shows 224 lines (MAME visarea 2*8..30*8-1) against 240 on the other
// boards. Crop 8 lines at each end of the visible window (vdump 7..246).
localparam [8:0] VCROP_START = 9'd16, VCROP_END = 9'd239;

assign LVBL = lvbl_raw & (~p051a | (vdump>=VCROP_START && vdump<=VCROP_END));
wire [8:0] scr_pxl, obj_pxl;

// TODO this timing needs to be verified on an original board
// mame notes have a different xtal clearly a different board
// of superman was used to measure timings, not the 039a.
jtframe_vtimer #(
    .HB_END  ( 9'd1   ),
    .HB_START( 9'd385 ),
    .HS_START( 9'd409 ),
    .HS_END  ( 9'd461 ),
    .HCNT_END( 9'd511 ),
    .V_START ( 9'd000 ),
    .VS_START( 9'd253 ),
    .VS_END  ( 9'd261 ),
    .VB_START( 9'd247 ),
    .VB_END  ( 9'd007 ),
    .VCNT_END( 9'd271 )
) u_timer(
    .clk        ( clk        ),
    .pxl_cen    ( pxl_cen    ),
    .vdump      ( vdump      ),
    .vrender    ( vrender    ),
    .vrender1   (            ),
    .H          ( hdump      ),
    .Hinit      (            ),
    .Vinit      (            ),
    .LHBL       ( LHBL       ),
    .LVBL       ( lvbl_raw   ),
    .HS         ( HS         ),
    .VS         ( VS         )
);

jtkiwi_gfx #(
    .CPUW ( 16 ),
    .OBJAW( 13 ),
    // The X1-001 compares an 8-bit line counter against an 8-bit sprite Y,
    // so a sprite parked near 0xFF wraps onto the first lines. MAME models
    // the same fact by drawing a second copy at row-256. cal50 and arbalest
    // set this too.
    .OBJ_YWRAP( 1'b1 )
) u_gfx(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk_cpu    ( clk       ),

    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),

    .LHBL       ( LHBL      ),
    .LVBL       ( lvbl_raw  ),
    .hs         ( HS        ),
    .vs         ( VS        ),
    .flip       ( flip      ),
    .drtoppel   ( 1'b0      ),

    .vdump      ( vdump_adj ),
    .vrender    ( vrender   ),
    .hdump      ( hdump     ),

    .cpu_rnw    ( cpu_rnw   ),
    .cpu_dsn    ( cpu_dsn   ),
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .vram_cs    ( oram_cs   ),

    .vctrl_cs   ( vdcm_cs   ),
    .vflag_cs   ( 1'b0      ),   // no flag register on this board
    .cpu_din    ( vid_dout  ),

    .ioctl_addr ( ioctl_addr),
    .ioctl_din  ( ioctl_din ),

    .col_addr   ( col_addr  ),
    .col_data   ( col_data  ),
    .yram_dout  ( yram_dout ),
    .yram_we    ( yram_we   ),

    .dma_addr   ( dma_addr  ),
    .dma_din    ( dma_din   ),
    .dma_we     ( dma_we    ),
    .dma_dout   ( dma_dout  ),
    .code_dout  ( code_dout ),
    .code_addr  ( code_addr ),

    .scr_addr   ( scr_addr  ),
    .scr_data   ( scr_data  ),
    .scr_ok     ( scr_ok    ),
    .scr_cs     ( scr_cs    ),

    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),
    .obj_ok     ( obj_ok    ),
    .obj_cs     ( obj_cs    ),

    .scr_pxl    ( scr_pxl   ),
    .obj_pxl    ( obj_pxl   ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_dout   )
);

jttaitox_colmix u_colmix(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .scr_pxl    ( scr_pxl   ),
    .obj_pxl    ( obj_pxl   ),
    .pal_addr   ( pal_addr  ),
    .pal_data   ( pal_data  ),
    .gfx_en     ( gfx_en    ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      )
);

endmodule
