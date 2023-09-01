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
    Date: 27-8-2023 */

module jtfround_video(
    input             rst,
    input             clk,
    input             pxl_cen,

    output reg        tim,      // similar to tim1, tim2 in schematics. Goes low every 8 pixels
    // Base Video
    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs,

    // CPU interface
    input      [19:1] cpu_addr,
    input      [ 7:0] cpu_dout,

    // control
    input             crtkill,
    input      [ 1:0] cpu_prio,
    input      [15:0] scr_bank,
    input      [ 8:0] scra_x, scra_y, scrb_x, scrb_y,
    input      [ 9:0] obj_dx, obj_dy,

    input             dma_on,
    output            dma_bsy,

    input             hflip,
    input             vflip,
    output reg        flip,

    // PROMs
    input      [ 7:0] prog_addr,
    input      [ 2:0] prog_data,
    input             prom_we,

    // Video RAM
    output     [11:1] fram_addr,
    input      [15:0] fram_dout,
    output     [12:1] scra_addr,
    input      [15:0] scra_dout,
    output     [12:1] scrb_addr,
    input      [15:0] scrb_dout,
    output     [13:1] oram_addr,
    input      [15:0] oram_dout,
    output     [15:0] oram_din,
    output            oram_we,
    output     [11:0] pal_addr,
    input      [ 7:0] pal_dout,

    // Tile ROMs
    output     [13:2] lyrf_addr,
    output     [19:2] lyra_addr,
    output     [19:2] lyrb_addr,
    output     [19:2] lyro_addr,

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
    // output     [ 7:0] ioctl_din,

    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

localparam [8:0] HB_OFFSET=0;

wire [ 8:0] vdump, hdump, vrender, vrender1, hdump_off, hscr_off, vdump_scr;
wire [31:0] fsorted, asorted, bsorted, osorted;
wire [19:2] preo_addr;
wire [ 7:0] lyrf_pxl, lyro_pxl;
wire [ 6:0] lyra_pxl, lyrb_pxl;
wire [ 1:0] lyra_sel, lyrb_sel;
wire [15:0] scra_bank, scrb_bank;
wire [15:2] prea_addr;
wire        prea_cs, preb_cs, preo_cs;

function [31:0] sort( input [31:0] a );
    sort = {
        a[ 7], a[ 3], a[15], a[11], a[23], a[19], a[31], a[27],
        a[ 6], a[ 2], a[14], a[10], a[22], a[18], a[30], a[26],
        a[ 5], a[ 1], a[13], a[ 9], a[21], a[17], a[29], a[25],
        a[ 4], a[ 0], a[12], a[ 8], a[20], a[16], a[28], a[24]
    };
endfunction

function [31:0] scr_sort( input [31:0] a );
    scr_sort = {
        a[15], a[11], a[ 7], a[ 3], a[31], a[27], a[23], a[19],
        a[14], a[10], a[ 6], a[ 2], a[30], a[26], a[22], a[18],
        a[13], a[ 9], a[ 5], a[ 1], a[29], a[25], a[21], a[17],
        a[12], a[ 8], a[ 4], a[ 0], a[28], a[24], a[20], a[16]
    };
endfunction

assign fsorted     = sort( lyrf_data ),
       asorted     = scr_sort( lyra_data ),
       bsorted     = scr_sort( lyrb_data ),
       osorted     = scr_sort( lyro_data ),
       st_dout     = 0;

assign scra_bank = scr_bank >> { crtkill ? cpu_addr[17:16] : lyra_sel, 2'd0 };
assign scrb_bank = scr_bank >> { lyrb_sel, 2'd0 };
assign lyra_addr[19:16] = scra_bank[3:0];
assign lyrb_addr[19:16] = scrb_bank[3:0];
assign vdump_scr = vflip ? 9'h1-vdump : vdump ^ 9'h100;
assign hdump_off = hflip ? 9'h198-hdump : hdump-9'h60;
assign lyra_cs   =  crtkill | prea_cs;  // SCRA access used for ROM reading
assign lyrb_cs   = ~crtkill & preb_cs;
assign lyro_cs   =  crtkill | preo_cs;  // SCRA access used for ROM reading
assign lyra_addr[15:2] = crtkill ? cpu_addr[15:2] : prea_addr;
assign lyro_addr[19:2] = crtkill ? cpu_addr[19:2] : preo_addr;

always @(posedge clk) begin
    flip <= hflip & vflip;
    if( pxl_cen ) tim <= hdump[2:0]!=4;
end
// functionality done by 007782
// measured on PCB
/* verilator tracing_off */
jtframe_vtimer #(
    .HCNT_START ( 9'h020    ),
    .HCNT_END   ( 9'h19F    ),
    .HB_START   ( 9'h029+HB_OFFSET ), // 320 visible, 384 total (64 pxl=HB)
    .HB_END     ( 9'h069+HB_OFFSET ),
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

jtframe_tilemap #(
    .VA          (    11 ),
    .CW          (     9 ),
    .MAP_HW      (     9 ),
    .MAP_VW      (     8 )
)u_fix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .vdump      ( vdump^{1'b0,{8{vflip}}}     ),
    .hdump      ( hdump_off ),
    .blankn     ( gfx_en[0] ),  // if !blankn there are no ROM requests
    .flip       ( 1'b0      ),    // Screen flip

    .vram_addr  ( fram_addr ),

    .code       ( fram_dout[8:0] ),
    .pal        ( fram_dout[12:9]),
    .hflip      (fram_dout[13]^hflip),
    .vflip      (fram_dout[14]),

    .rom_addr   ( lyrf_addr ),
    .rom_data   ( fsorted   ),
    .rom_cs     ( lyrf_cs   ),
    .rom_ok     ( 1'b1      ),

    .pxl        ( lyrf_pxl  )
);

jtframe_scroll #(
    .VA(12),
    .CW(13),
    .PW( 7)
) u_scra (
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .hs         ( hs        ),

    .vdump      ( vdump_scr ),
    .hdump      ( hdump_off  ),
    .blankn     ( gfx_en[1] ),
    .flip       ( 1'b0      ),
    .scrx       ( scra_x    ),
    .scry       ( scra_y    ),

    .vram_addr  ( scra_addr ),

    .code       (scra_dout[12:0]),
    .pal        (scra_dout[15:13]),
    .hflip      ( hflip     ),
    .vflip      ( 1'b0      ),

    .rom_addr   ( { lyra_sel, prea_addr[15:2] } ),
    .rom_data   ( asorted   ),
    .rom_cs     ( prea_cs   ),
    .rom_ok     ( 1'b1      ),

    .pxl        ( lyra_pxl  )
);

jtframe_scroll #(
    .VA(12),
    .CW(13),
    .PW( 7)
) u_scrb (
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .hs         ( hs        ),

    .vdump      ( vdump_scr ),
    .hdump      ( hdump_off ),
    .blankn     ( gfx_en[2] ),
    .flip       ( 1'b0      ),
    .scrx       ( scrb_x    ),
    .scry       ( scrb_y    ),

    .vram_addr  ( scrb_addr ),

    .code       (scrb_dout[12:0]),
    .pal        (scrb_dout[15:13]),
    .hflip      ( hflip     ),
    .vflip      ( 1'b0      ),

    .rom_addr   ( { lyrb_sel, lyrb_addr[15:2] } ),
    .rom_data   ( bsorted   ),
    .rom_cs     ( preb_cs   ),
    .rom_ok     ( 1'b1      ),

    .pxl        ( lyrb_pxl  )
);

/* verilator tracing_on */
jtfround_obj u_obj(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),
    .hs         ( hs        ),
    .vs         ( vs        ),

    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .obj_dx     ( obj_dx    ),
    .obj_dy     ( obj_dy    ),

    .oram_addr  ( oram_addr ),
    .oram_dout  ( oram_dout ),
    .oram_din   ( oram_din  ),
    .oram_we    ( oram_we   ),

    .dma_on     ( dma_on    ),
    .dma_bsy    ( dma_bsy   ),

    .rom_addr   ( preo_addr ),
    .rom_data   ( osorted   ),
    .rom_cs     ( preo_cs   ),
    .rom_ok     ( lyro_ok   ),

    .pxl        ( lyro_pxl  ),

    .debug_bus  ( debug_bus )
);

/* verilator tracing_on */
jtfround_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    // CPU interface
    .crtkill    ( crtkill   ),
    .cpu_prio   ( cpu_prio  ),

    // Base Video
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),

    // BRAM
    .pal_dout   ( pal_dout  ),
    .pal_addr   ( pal_addr  ),

    // PROMs
    .prog_addr  ( prog_addr ),
    .prog_data  ( prog_data ),
    .prom_we    ( prom_we   ),

    // Final pixels
    .lyrf_pxl   ( lyrf_pxl  ),
    .lyra_pxl   ( lyra_pxl  ),
    .lyrb_pxl   ( lyrb_pxl  ),
    .lyro_pxl   ( lyro_pxl  ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),

    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus )
);

endmodule