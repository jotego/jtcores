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
    output     [ 8:0] hdump,

    input      [14:0] cpu_addr,
    input             cpu_rnw,
    input      [ 7:0] cpu_dout,
    input             scfg_cs,
    output     [ 7:0] scfg_dout, // scroll MMR data
    // Video RAM
    output     [11:1] oram_addr,
    input      [15:0] oram_dout,
    input      [ 7:0] red_dout,   rpal_dout,
                      green_dout, gpal_dout,
                      blue_dout,  bpal_dout,
    output     [12:0] rgb_addr, pal_addr,
    output            rpal_we, gpal_we, bpal_we,
    // Tile map readout (BRAM)
    output     [14:1] tmap_addr,
    input      [15:0] tmap_dout,
    // Scroll mask readout (SDRAM)
    output            mask_cs,
    input             mask_ok,
    output     [16:0] mask_addr,
    input      [ 7:0] mask_data,
    // Scroll tile readout (SDRAM)
    output            scr_cs,
    input             scr_ok,
    output     [19:0] scr_addr,
    input      [ 7:0] scr_data,
    // color mixer
    input             pal_cs,
    output            raster_irqn,
    output     [ 7:0] pal_dout,

    output            lvbl, lhbl, hs, vs,
    output     [ 7:0] red, green, blue,
    // Debug
    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output reg [ 7:0] st_dout
);

localparam [8:0] HB_OFFSET=0;

wire [ 8:0] vdump, vrender, vrender1;
wire [ 7:0] st_scr, st_colmix;
wire [10:0] scr_pxl;
wire [ 2:0] scr_prio;
wire        flip;

assign oram_addr = 0;
assign flip = 0;

always @(posedge clk) begin
    case( debug_bus[0] )
        0: st_dout <= st_scr;
        1: st_dout <= st_colmix;
    endcase
end

// See https://github.com/jotego/jtcores/issues/348
jtframe_vtimer #(
    .HCNT_START ( 9'h020    ),
    .HCNT_END   ( 9'h19F    ),
    .HB_START   ( 9'h029+HB_OFFSET ), // 288 visible, 384 total (64 pxl=HB)
    .HB_END     ( 9'h089+HB_OFFSET ),
    .HS_START   ( 9'h049+HB_OFFSET ), // HS starts 32 pixels after HB
    .HS_END     ( 9'h069+HB_OFFSET ), // 32 pixel wide

    .V_START    ( 9'h0F8    ), // 224 visible, 40 blank, 264 total
    .VB_START   ( 9'h1EF    ),
    .VB_END     ( 9'h10F    ),
    .VS_START   ( 9'h1F7    ), // 8 lines wide, 8 lines after VB start
    .VS_END     ( 9'h1FF    ), // 60.6 Hz according to MAME
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

jtshouse_scr u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .pxl_cen    ( pxl_cen   ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .flip       ( flip      ),

    .cs         ( scfg_cs   ),
    .addr       (cpu_addr[4:0]),
    .rnw        ( cpu_rnw   ),
    .din        ( cpu_dout  ),
    .dout       ( scfg_dout ),

    // Tile map readout (BRAM)
    .tmap_addr  ( tmap_addr ),
    .tmap_dout  ( tmap_dout ),
    // Mask readout (SDRAM)
    .mask_cs    ( mask_cs   ),
    .mask_ok    ( mask_ok   ),
    .mask_addr  ( mask_addr ),
    .mask_data  ( mask_data ),
    // Tile readout (SDRAM)
    .scr_cs     ( scr_cs    ),
    .scr_ok     ( scr_ok    ),
    .scr_addr   ( scr_addr  ),
    .scr_data   ( scr_data  ),
    // Pixel output
    .pxl        ( scr_pxl   ),
    .prio       ( scr_prio  ),
    // Debug
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_scr    )
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

    // pixel input
    .scr_pxl    ( scr_pxl   ),
    .scr_prio   ( scr_prio  ),

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
    .st_dout    ( st_colmix )
);

endmodule