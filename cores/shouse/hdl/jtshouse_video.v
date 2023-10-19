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
    input             pxl2_cen,
    output     [ 8:0] hdump,

    input      [14:0] cpu_addr,
    input             cpu_rnw,
    input      [ 7:0] cpu_dout,
    input             scfg_cs,
    output     [ 7:0] scfg_dout, // scroll MMR data
    // Video RAM
    output     [11:1] oram_addr,
    input      [15:0] oram_dout,
    output            oram_we,
    output     [15:0] oram_din,
    input             obus_cs,   // obj RAM access by CPU(s)
    input      [ 7:0] red_dout,   rpal_dout,
                      green_dout, gpal_dout,
                      blue_dout,  bpal_dout,
    output     [12:0] rgb_addr, pal_addr,
    output            rpal_we, gpal_we, bpal_we,
    // Tile map readout (BRAM)
    output     [14:1] tmap_addr,
    input      [15:0] tmap_data,
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
    // Object tile readout (SDRAM)
    output            obj_cs,
    input             obj_ok,
    output     [19:2] obj_addr,
    input      [31:0] obj_data,
    // color mixer
    input             pal_cs,
    output            raster_irqn,
    output     [ 7:0] pal_dout,

    output            lvbl, lhbl, hs, vs,
    output     [ 7:0] red, green, blue,
    // Dump MMR
    input      [ 5:0] ioctl_addr,
    output reg [ 7:0] ioctl_din,
    // Debug
    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output reg [ 7:0] st_dout
);

wire [ 8:0] vdump, vrender, vrender1;
wire [ 7:0] st_scr, st_obj, st_colmix,
            iodin_obj, iodin_scr;
wire [10:0] scr_pxl,  obj_pxl;
wire [ 2:0] scr_prio, obj_prio;
wire        flip, pre_scrcs, pre_maskcs;

assign flip = 0;
assign scr_cs  = pre_scrcs  & gfx_en[0];
assign mask_cs = pre_maskcs & gfx_en[0];

always @(posedge clk) begin
    case( debug_bus[6:5] )
        0: st_dout <= st_scr;
        1: st_dout <= st_obj;
        2: st_dout <= st_colmix;
        default: st_dout <= 0;
    endcase
    case(ioctl_addr[5])
        0: ioctl_din = iodin_scr;
        1: ioctl_din = iodin_obj;
    endcase
end

// See https://github.com/jotego/jtcores/issues/348
jtframe_vtimer #(
    .HCNT_START ( 9'h000    ),
    .HCNT_END   ( 9'h17F    ),
    .HB_START   ( 9'h160    ), // 288 visible, 384 total (96 pxl=HB)
    .HB_END     ( 9'h040    ), // Fixed layer is mapped for a counter that leaves blanking at $40
    .HS_START   ( 9'h17f    ), // HS starts 32 pixels after HB
    .HS_END     ( 9'h01f    ), // 32 pixel wide

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

    .hdump      ( hdump     ),
    .vrender    ( vrender   ),
    .hs         ( hs        ),
    .vs         ( vs        ),
    .flip       ( flip      ),

    .cs         ( scfg_cs   ),
    .addr       (cpu_addr[4:0]),
    .rnw        ( cpu_rnw   ),
    .din        ( cpu_dout  ),
    .dout       ( scfg_dout ),

    // Tile map readout (BRAM)
    .tmap_addr  ( tmap_addr ),
    .tmap_data  ( tmap_data ),
    // Mask readout (SDRAM)
    .mask_cs    ( pre_maskcs),
    .mask_ok    ( mask_ok   ),
    .mask_addr  ( mask_addr ),
    .mask_data  ( mask_data ),
    // Tile readout (SDRAM)
    .scr_cs     ( pre_scrcs ),
    .scr_ok     ( scr_ok    ),
    .scr_addr   ( scr_addr  ),
    .scr_data   ( scr_data  ),
    // Pixel output
    .pxl        ( scr_pxl   ),
    .prio       ( scr_prio  ),
    // IOCTL dump
    .ioctl_addr ( ioctl_addr[4:0]),
    .ioctl_din  ( iodin_scr ),
    // Debug
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_scr    )
);

jtshouse_obj u_obj(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .pxl_cen    ( pxl_cen   ),

    .cpu_dout   ( cpu_dout  ),
    .cpu_addr   (cpu_addr[11:0]),
    .cpu_rnw    ( cpu_rnw   ),
    .cs         ( obus_cs   ),

    .hs         ( hs        ),
    .lvbl       ( lvbl      ),
    .flip       ( flip      ),
    .vrender    ( vrender1  ),
    .hdump      ( hdump     ),

    // Video RAM
    .oram_addr  ( oram_addr ),
    .oram_dout  ( oram_dout ),
    .oram_we    ( oram_we   ),
    .oram_din   ( oram_din  ),

    // Object tile readout (SDRAM)
    .rom_cs     ( obj_cs    ),
    .rom_ok     ( obj_ok    ),
    .rom_addr   ( obj_addr  ),
    .rom_data   ( obj_data  ),

    // pixel output
    .pxl        ( obj_pxl   ),
    .prio       ( obj_prio  ),

    .debug_bus  ( debug_bus ),
    .st_dout    ( st_obj    ),
    // MMR dump
    .ioctl_addr ( ioctl_addr[2:0]),
    .ioctl_din  ( iodin_obj )
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
    .obj_pxl    ( obj_pxl   ),
    .obj_prio   ( obj_prio  ),

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
    // Debug
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_colmix )
);

endmodule