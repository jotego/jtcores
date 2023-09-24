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
    Date: 22-9-2023 */

module jtshouse_video(
    input             rst,
    input             clk,

    input             pxl_cen,

    input      [14:0] cpu_addr,
    input             cpu_rnw,
    input      [ 7:0] cpu_dout,
    // Video RAM
    output     [11:1] oram_addr,
    input      [15:0] oram_dout,
    input      [ 7:0] red_dout,   rpal_dout,
                      green_dout, gpal_dout,
                      blue_dout,  bpal_dout,
    output     [12:0] rgb_addr, pal_addr,
    output            rpal_we, gpal_we, bpal_we,
    // color mixer
    input             pal_cs,
    output            raster_irqn,
    output     [ 7:0] pal_dout,

    output            lvbl, lhbl, hs, vs,
    output     [ 7:0] red, green, blue,
    // Debug
    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

localparam [8:0] HB_OFFSET=0;

wire [ 8:0] vdump, hdump, vrender, vrender1;

assign red   = 0;
assign green = 0;
assign blue  = 0;
assign oram_addr = 0;

// See https://github.com/jotego/jtcores/issues/348
jtframe_vtimer #(
    .HCNT_START ( 9'h020    ),
    .HCNT_END   ( 9'h19F    ),
    .HB_START   ( 9'h029+HB_OFFSET ), // 288 visible, 384 total (64 pxl=HB)
    .HB_END     ( 9'h089+HB_OFFSET ),
    .HS_START   ( 9'h02B    ), // HS starts 2 pixels after HB
    .HS_END     ( 9'h04B    ), // 32 pixel wide

    .V_START    ( 9'h0F8    ), // 224 visible, 40 blank, 264 total
    .VB_START   ( 9'h1EF    ),
    .VB_END     ( 9'h10F    ),
    .VS_START   ( 9'h1FF    ), // 8 lines wide, 16 lines after VB start
    .VS_END     ( 9'h0FF    ), // 60.6 Hz according to MAME
    .VCNT_END   ( 9'h1FF    )
) u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   ( vrender1  ),
    .H          ( hdump     ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( lhbl      ),
    .LVBL       ( lvbl      ),
    .HS         ( hs        ), // 16kHz
    .VS         ( vs        )
);

jtshouse_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .pxl_cen    ( pxl_cen   ),
    .lvbl       ( lvbl      ),
    .lhbl       ( lhbl      ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .raster_irqn(raster_irqn),

    .cpu_addr   ( cpu_addr  ),
    .cs         ( pal_cs    ),
    .cpu_rnw    ( cpu_rnw   ),
    .rgb_addr   ( rgb_addr  ),
    .pal_addr   ( pal_addr  ),
    .rpal_we    ( rpal_we   ),
    .gpal_we    ( gpal_we   ),
    .bpal_we    ( bpal_we   ),

    .cpu_dout   ( cpu_dout  ),
    .red_dout   ( red_dout  ),
    .rpal_dout  ( rpal_dout ),
    .green_dout ( green_dout),
    .gpal_dout  ( gpal_dout ),
    .blue_dout  ( blue_dout ),
    .bpal_dout  ( bpal_dout ),
    .pal_dout   ( pal_dout  ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_dout   )
);

endmodule