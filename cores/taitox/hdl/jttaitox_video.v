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
    Date: 8-2026 */

/*  X1-001 + X1-002. There is no tilemap chip on this board: MAME's single
    gfxdecode entry is "sprites & playfield", and the playfield is the
    X1-001's background COLUMN mode, which jtkiwi_gfx already implements.

    taito_x calls draw_sprites with bank_size 0x1000 -> the metafox/arbalest
    "setac" case, so jtkiwi_gfx is instantiated with OBJAW=13 (16 kB OBJ RAM,
    bank selected by spritectrl[1] rather than a 0x800 page split).

    512x272 grid at an 8 MHz dot clock = 15.625 kHz H, 57.44 Hz V. Same
    numbers as cal50, which runs the same chip off the same 16 MHz crystal.

    X1-001 alignment constants, from taito_x.cpp machine_config. Note the
    setter order is set_*_yoffsets(FLIP, NOFLIP) - seta001.h:52 - so the
    argument that differs per game is the FLIPPED one; every set in the
    family shares noflip fg=+0x0e / bg=-0x01.

      set                fg_y flip  fg_y noflip  bg_y flip  bg_y noflip
      superman            -0x12       +0x0e       +0x01       -0x01
      daisenpu/twinhawk   -0x12       +0x0e       +0x01       -0x01
      gigandes(a)         -0x0a       +0x0e       +0x01       -0x01
      ballbros            -0x0a       +0x0e       +0x01       -0x01
      kyustrkr            -0x0a       +0x0e       +0x01       -0x01   (= ballbros)

      set                 screen size   visarea          refresh
      superman             416x256      0-383, 8-247     57.43
      gigandes/ballbros/   416x256      0-383, 8-247     60
      kyustrkr
      daisenpu/twinhawk    416x256      0-383, 16-239    60

    x offsets are never set on this driver, so all four are 0.
    colorbase is 0 (GFXDECODE_ENTRY "gfx1",0,tilelayout,0,128).
    bank_size is 0x1000 for every set (one shared screen_update).

    Y is computed as, foreground (seta001.cpp draw_foreground):
        max_y = screen.height() = 256
        sy    = spriteylow[i] & 0xff
        row   = max_y - ((sy + yoff) & 0xff)      (plus a -256 wrap copy)
    background (draw_background) uses a HARDCODED max_y = 0xf0, not the
    screen height, and only applies it when flipped.

    These are MAME's numbers in MAME's coordinate convention. jtkiwi_gfx
    has its own OBJ_XOFF/OBJ_YOFF convention, so they are reference values
    to calibrate against, not constants to paste into the parameters.  */

module jttaitox_video(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             pxl2_cen,

    output            LHBL,
    output            LVBL,
    output            HS,
    output            VS,
    output     [ 8:0] hdump,
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

wire [8:0] vdump, vrender, vrender1;
wire [8:0] scr_pxl, obj_pxl;

// 512x272 total. The visible window phase was measured against a MAME
// screenshot of the static title screen: with HB_END=4 / VB_END=0 the picture
// landed 7 lines low and 3 pixels left, and was otherwise pixel-identical, so
// the window moves by exactly that and nothing else changes.
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
    .vrender1   ( vrender1   ),
    .H          ( hdump      ),
    .Hinit      (            ),
    .Vinit      (            ),
    .LHBL       ( LHBL       ),
    .LVBL       ( LVBL       ),
    .HS         ( HS         ),
    .VS         ( VS         )
);

jtkiwi_gfx #(
    .CPUW ( 16 ),
    .OBJAW( 13 )   // 16 kB OBJ RAM + setac bank
) u_gfx(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk_cpu    ( clk       ),

    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),

    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .hs         ( HS        ),
    .vs         ( VS        ),
    .flip       ( flip      ),
    .drtoppel   ( 1'b0      ),

    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .hdump      ( hdump     ),

    .cpu_rnw    ( cpu_rnw   ),
    .cpu_dsn    ( cpu_dsn   ),
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .vram_cs    ( oram_cs   ),
    // spriteylow at d00000-d005ff and spritectrl at d00600-d00607 land on
    // the same 0x400-word window jtkiwi_gfx decodes with cpu_addr[9:8]
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
