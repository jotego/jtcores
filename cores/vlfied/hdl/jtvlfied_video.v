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
    Version: 1.0
    Date: 7-8-2026 */

module jtvlfied_video(
    input           rst,
    input           clk,
    input           pxl_cen,

    output          HS,
    output          VS,
    output          LHBL,
    output          LVBL,
    input           flip,

    // CPU buses
    input    [18:1] main_addr,
    input    [15:0] main_dout,
    output   [15:0] fb_dout,
    output   [15:0] vctrl_dout,
    input    [ 1:0] main_dsn,
    input           main_rnw,
    input           fb_cs,
    output          fb_ok,          // -> 68k DTACK
    input           vmask_cs,
    input           vctrl_cs,
    input    [ 3:0] obj_pal,

    // palette RAM read port (BRAM declared in mem.yaml)
    output   [12:0] pal_addr,
    input    [15:0] pal_data,

    output   [12:1] objram_addr,
    input    [15:0] objram_dout,

    // sprite graphics ROM (PC090OJ) — SDRAM bank 2
    output   [19:2] orom_addr,
    input    [31:0] orom_data,
    output          orom_cs,
    input           orom_ok,

    // bitmap framebuffer — SDRAM bank 3 (CPU RW port + video read port)
    output   [18:1] fbram_addr,
    output   [ 1:0] fbram_dsn,
    output          fbram_we,
    output          fbram_cs,
    output   [15:0] fb_wdata,
    input    [15:0] fbram_data,
    input           fbram_ok,
    output   [18:1] fbrd_addr,
    output          fbrd_cs,
    input    [15:0] fbrd_data,
    input           fbrd_ok,

    output    [4:0] red,
    output    [4:0] green,
    output    [4:0] blue,

    input     [3:0] gfx_en,
    input     [7:0] debug_bus,
    output    [7:0] st_dout
);

wire        preLHBL, preLVBL;
wire [ 8:0] H, vdump, vrender, vrender1;
wire [ 7:0] obj_pxl;
wire [11:0] fb_pxl;
wire        dummy_dtack;

// 424x263 at the 6.671 MHz pixel clock -> 15.73 kHz line rate, 59.8 Hz.
// Both layers render from vrender1 rather than vrender, i.e. one scanline
// earlier, matching how rastan feeds its own object engine.
jtframe_vtimer #(
    .VB_START   ( 9'd239          ),
    .VB_END     ( 9'd239+9'd23    ),
    .VS_START   ( 9'd239+9'd7     ),
    .HB_END     ( 9'hA            ),
    .HB_START   ( 9'h14A          ),
    .HCNT_END   ( 9'd319+9'd104   ),
    .HS_START   ( 9'd320+9'd44    )
) u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   ( vrender1  ),
    .H          ( H         ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( preLHBL   ),
    .LVBL       ( preLVBL   ),
    .HS         ( HS        ),
    .VS         ( VS        )
);

jtvlfied_fb u_fb(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hdump      ( H         ),
    .vrender    ( vrender1  ),
    .HS         ( HS        ),

    .main_addr  ( main_addr ),
    .main_dout  ( main_dout ),
    .main_din   ( fb_dout   ),
    .main_dsn   ( main_dsn  ),
    .main_rnw   ( main_rnw  ),
    .fb_cs      ( fb_cs     ),
    .fb_ok      ( fb_ok     ),

    .vmask_cs   ( vmask_cs  ),
    .vctrl_cs   ( vctrl_cs  ),
    .vctrl_dout ( vctrl_dout),

    // SDRAM bank 3
    .fbram_addr ( fbram_addr),
    .fbram_dsn  ( fbram_dsn ),
    .fbram_we   ( fbram_we  ),
    .fbram_cs   ( fbram_cs  ),
    .fb_wdata   ( fb_wdata  ),
    .fbram_data ( fbram_data),
    .fbram_ok   ( fbram_ok  ),
    .fbrd_addr  ( fbrd_addr ),
    .fbrd_cs    ( fbrd_cs   ),
    .fbrd_data  ( fbrd_data ),
    .fbrd_ok    ( fbrd_ok   ),

    .fb_pxl     ( fb_pxl    ),

    .debug_bus  ( debug_bus ),
    .st_dout    ( st_dout   )
);

jtrastan_obj u_obj(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .HS         ( HS        ),
    .flip       ( flip      ),
    .hdump      ( H         ),
    .vrender    ( vrender1  ),

    .ram_addr   ( objram_addr ),
    .ram_data   ( objram_dout ),
    .dtackn     ( dummy_dtack),

    .rom_addr   ( orom_addr ),
    .rom_data   ( orom_data ),
    .rom_cs     ( orom_cs   ),
    .rom_ok     ( orom_ok   ),
    .pxl        ( obj_pxl   ),
    .debug_bus  ( debug_bus )
);

jtvlfied_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .pal_addr   ( pal_addr  ),
    .pal_data   ( pal_data  ),

    .preLHBL    ( preLHBL   ),
    .preLVBL    ( preLVBL   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),

    .fb_pxl     ( fb_pxl    ),
    .obj_pxl    ( obj_pxl   ),
    .obj_pal    ( obj_pal   ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),

    .gfx_en     ( gfx_en    )
);

endmodule
