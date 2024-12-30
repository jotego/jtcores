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
    Date: 23-7-2023 */

module jtsimson_video(
    input             rst,
    output            rst8,     // reset signal at 8th frame
    input             clk,
    input             simson,
    input             paroda,

    // Base Video
    input             pxl_cen,
    input             pxl2_cen,
    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs,
    output            flip,

    // CPU interface
    input      [15:0] cpu_addr,
    input      [ 7:0] cpu_dout,
    input             cpu_we,
    input             pal_bank,

    output     [ 7:0] pal_dout,
    output     [ 7:0] tilesys_dout,
    output            tilesys_rom_dtack,
    output     [ 7:0] objsys_dout,

    input             pal_we,
    input             pcu_cs,   // priority control unit
    input             tilesys_cs,
    input             objsys_cs,
    input             objreg_cs,

    // control
    input             rmrd,     // Tile ROM read mode
    input             objcha_n, // object ROM read mode
    output            cpu_irqn,
    output            dma_bsy,

    // Tile ROMs
    output     [19:2] lyrf_addr,
    output     [19:2] lyra_addr,
    output     [19:2] lyrb_addr,
    output     [21:2] lyro_addr,

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

    // Color
    output     [ 7:0] red,
    output     [ 7:0] green,
    output     [ 7:0] blue,

    // Debug
    input      [15:0] ioctl_addr,
    input             ioctl_ram,
    output     [ 7:0] ioctl_din,

    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

wire [ 8:0] hdump, vdump, vrender, vrender1;
wire [ 7:0] lyrf_pxl, st_scr,
            dump_scr, scr_mmr, dump_obj, dump_pal, obj_mmr, pal_mmr;
wire [11:0] lyra_pxl, lyrb_pxl, pal_addr;
wire [ 8:0] lyro_pxl;
wire [ 1:0] obj_shd;
wire [ 4:0] obj_prio;
wire [15:0] obj16_dout;
wire [ 3:0] obj_amsb;

assign pal_addr    = { paroda ? pal_bank : cpu_addr[11], cpu_addr[10:0] };
assign objsys_dout = ~cpu_addr[0] ? obj16_dout[15:8] : obj16_dout[7:0]; // big endian

// Debug
jtriders_dump u_dump(
    .clk            ( clk             ),
    .dump_scr       ( dump_scr        ),
    .dump_obj       ( dump_obj        ),
    .dump_pal       ( dump_pal        ),
    .pal_mmr        ( pal_mmr         ),
    .scr_mmr        ( scr_mmr         ),
    .obj_mmr        ( obj_mmr         ),
    .other          ( 8'b0            ),

    .ioctl_addr     ( ioctl_addr      ),
    .ioctl_din      ( ioctl_din       ),
    .obj_amsb       ( obj_amsb        ),

    .debug_bus      ( debug_bus       ),
    .st_scr         ( st_scr          ),
    .st_dout        ( st_dout         )
);

/* verilator tracing_on */
jtsimson_scroll #(.HB_OFFSET(2)) u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    .paroda     ( paroda    ),
    .simson     ( simson    ),
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
    .cpu_rom_dtack ( tilesys_rom_dtack),

    // control
    .rmrd       ( rmrd      ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   ( vrender1  ),

    .irq_n      ( cpu_irqn  ),
    .firq_n     (           ),
    .nmi_n      (           ),
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
    .lyra_ok    ( lyra_ok   ),

    // Final pixels
    .lyrf_blnk_n(           ),
    .lyra_blnk_n(           ),
    .lyrb_blnk_n(           ),
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

localparam ORAMW=12;
wire [ORAMW:1] oram_a;
assign oram_a = { cpu_addr[12] & ~paroda, cpu_addr[11:1] };

/* verilator tracing_on  */
`ifdef SIMSON
jtsimson_obj #(.RAMW(ORAMW)) u_obj(    // sprite logic
    .simson     ( simson    ),
`else
assign obj_shd[1] = 1'b0;
jtriders_obj #(.RAMW(ORAMW)) u_obj(
`endif
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    // Base Video (inputs)
    .hs         ( hs        ),
    .vs         ( vs        ),
    .lvbl       ( lvbl      ),
    .lhbl       ( lhbl      ),
    .hdump      ( hdump     ),
    .vdump      ( vrender   ),
    // CPU interface
    .ram_cs     ( objsys_cs ),
    .ram_addr   ( oram_a    ),
    .ram_din    ({2{cpu_dout}}),
    .ram_we     ( {~cpu_addr[0],cpu_addr[0]}&{2{cpu_we}} ),
    .cpu_din    ( obj16_dout),

    .reg_cs     ( objreg_cs ),
    .mmr_addr   (cpu_addr[3:0]),
    .mmr_din    ({8'd0,cpu_dout}),
    .mmr_we     ( cpu_we    ),
    .mmr_dsn    ({1'b1,cpu_addr[0]}),

    .dma_bsy    ( dma_bsy   ),
    // ROM
    .rom_addr   ( lyro_addr ),
    .rom_data   ( lyro_data ),
    .rom_ok     ( lyro_ok   ),
    .rom_cs     ( lyro_cs   ),
    .objcha_n   ( objcha_n  ),
    // pixel output
    .pxl        ( lyro_pxl  ),
    `ifdef SIMSON
    .shd        ( obj_shd   ),
    `else
    .shd        ( obj_shd[0]),
    `endif
    .prio       ( obj_prio  ),
    // Debug
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_addr ( {obj_amsb[1:0],ioctl_addr[11:0]} ),
    .dump_ram   ( dump_obj  ),
    .dump_reg   ( obj_mmr   ),
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus )
);

function [6:0] lyrcol( input [7:0] pxl );
    lyrcol = paroda ? {       pxl[7:5], pxl[3:0] } :
                      { 1'b0, pxl[7:6], pxl[3:0] };
endfunction

/* verilator tracing_on */
jtsimson_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),

    // Base Video
    .pxl_cen    ( pxl_cen   ),
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),

    // CPU interface
    .cpu_addr   ( pal_addr  ),
    .cpu_din    ( pal_dout  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_we     ( pal_we    ),
    .pcu_cs     ( pcu_cs    ),

    // Final pixels
    .lyrf_pxl   ( lyrcol(lyrf_pxl) ),
    .lyra_pxl   ( lyrcol( paroda ? lyrb_pxl[7:0] : lyra_pxl[7:0] ) ), // scroll layers swapped in Parodius
    .lyrb_pxl   ( lyrcol( paroda ? lyra_pxl[7:0] : lyrb_pxl[7:0] ) ),
    .lyro_pxl   ( lyro_pxl  ),

    .obj_prio   ( obj_prio  ),
    .obj_shd    ( paroda ? 2'd0 : obj_shd ), // shadow resistors are not mounted in the Parodius PCB

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),

    // Debug
    .ioctl_addr ( ioctl_addr[11:0]),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_din  ( dump_pal  ),
    .dump_mmr   ( pal_mmr   ),

    .debug_bus  ( debug_bus )
);

endmodule