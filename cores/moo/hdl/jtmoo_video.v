/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Author: Rafael Eduardo Paiva Feener. Copyright: Jose Tejada Gomez
 * Version: 1.0
 * Date: 17-6-2026 */

module jtmoo_video(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             pxl2_cen,

    // Base Video
    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs,

    // Object DMA
    input      [ 1:0] oram_we,
    // CPU interface
    input      [16:1] cpu_addr,
    input      [ 1:0] cpu_dsn,
    input      [15:0] cpu_dout,
    input             cpu_we,

    input             pcu_cs,
    input             k338_cs,
    input             pal_cs,
    output     [15:0] palsys_dout,
    output     [15:0] tilesys_dout,

    // Palette RAM, generated from cfg/mem.yaml
    output     [ 3:0] pal_we,
    output     [12:2] pal_addr,
    output     [31:0] pal_din,
    input      [31:0] pal_dout,
    output     [12:2] palrd_addr,
    input      [31:0] pal_data,

    input             cco_cs,
    input             rw,
    input      [ 3:0] vtimer_addr,
    output     [ 7:0] vtimer_mmr,

    output            dma_bsy,
    output     [15:0] objsys_dout,
    input             objsys_cs,
    input             objreg_cs,
    input             objcha_n,

    input             scrreg_cs,
    input             scr_cs,

    output            vdtac,
    input             tilesys_cs,
    input             rmrd_cs,  // graphics ROM read-back window

    // control
    output            flip,
    output            int1,
    // Tile ROMs
    output     [20:2] lyrf_addr,
    output     [20:2] lyra_addr,
    output     [20:2] lyrb_addr,
    output     [20:2] lyrc_addr,
    output     [22:2] lyro_addr,

    output            lyrf_cs,
    output            lyra_cs,
    output            lyrb_cs,
    output            lyrc_cs,
    output            lyro_cs,

    input             lyrf_ok,
    input             lyra_ok,
    input             lyrb_ok,
    input             lyrc_ok,
    input             lyro_ok,

    input      [31:0] lyrf_data,
    input      [31:0] lyra_data,
    input      [31:0] lyrb_data,
    input      [31:0] lyrc_data,
    input      [31:0] lyro_data,

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

wire [11:0] lyrf_pxl, lyra_pxl, lyrb_pxl, lyrc_pxl;
wire [ 8:0] hdump, vdump, lyro_pxl;
wire [ 7:0] dump_scr, st_scr, dump_obj, scr_mmr, obj_mmr, dump_pal, pal_mmr, ccu_mmr;
wire [ 4:0] lyro_pri;
wire [ 1:0] shadow;
wire [ 3:0] ommra;
wire [13:1] orama;
wire        cpu_weg;

assign cpu_weg = cpu_we && cpu_dsn!=2'b11;
// The read-back steals the first tile ROM port, so the CPU waits for it
assign vdtac   = lyrf_ok;

jtmoo_dump u_dump(
    .clk            ( clk             ),
    .dump_scr       ( dump_scr        ),
    .dump_obj       ( dump_obj        ),
    .dump_pal       ( dump_pal        ),
    .pal_mmr        ( pal_mmr         ),
    .scr_mmr        ( scr_mmr         ),
    .obj_mmr        ( obj_mmr         ),
    .ccu_mmr        ( ccu_mmr         ),

    .ioctl_addr     ( ioctl_addr      ),
    .ioctl_din      ( ioctl_din       ),

    .debug_bus      ( debug_bus       ),
    .st_scr         ( st_scr          ),
    .st_dout        ( st_dout         )
);

jtk053252 u_k053252(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .cs         ( cco_cs        ), // /CC0
    .addr       ( vtimer_addr   ),
    .rnw        ( rw            ),
    .din        ( cpu_dout[7:0] ),
    .dout       ( vtimer_mmr    ),

    .hs         ( hs            ),
    .vs         ( vs            ),
    .lhbl       ( lhbl          ),
    .lhbs       (               ),
    .lvbl       ( lvbl          ),
    .hld        (               ),
    .vld        (               ),
    // unused
    .vldi       ( 1'b1          ),
    .hldi       ( 1'b1          ),
    .sel        ( 3'd0          ),
    .int1       ( int1          ),
    .int2       (               ),
    // IOCTL dump
    .ioctl_addr ( ioctl_addr[3:0]),
    .ioctl_din  ( ccu_mmr       )
);

/* verilator tracing_on */
jtmoo_scroll u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),
    .hs         ( hs        ),
    .vs         ( vs        ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),

    // CPU interface
    .cpu_addr   (cpu_addr[12:1]),
    .cpu_dout   ( cpu_dout  ),
    .cpu_dsn    ( cpu_dsn   ),
    .cpu_we     ( cpu_weg   ),
    .reg_cs     ( scrreg_cs ),
    .gfx_cs     ( tilesys_cs),
    .vram_cs    ( scr_cs    ),
    .rmrd_cs    ( rmrd_cs   ),
    .tile_dout  ( tilesys_dout ),
    .flip       ( flip      ),

    // Tile ROMs
    .lyrf_addr  ( lyrf_addr ),
    .lyra_addr  ( lyra_addr ),
    .lyrb_addr  ( lyrb_addr ),
    .lyrc_addr  ( lyrc_addr ),
    .lyrf_cs    ( lyrf_cs   ),
    .lyra_cs    ( lyra_cs   ),
    .lyrb_cs    ( lyrb_cs   ),
    .lyrc_cs    ( lyrc_cs   ),
    .lyrf_data  ( lyrf_data ),
    .lyra_data  ( lyra_data ),
    .lyrb_data  ( lyrb_data ),
    .lyrc_data  ( lyrc_data ),
    .lyrf_ok    ( lyrf_ok   ),
    .lyra_ok    ( lyra_ok   ),
    .lyrb_ok    ( lyrb_ok   ),
    .lyrc_ok    ( lyrc_ok   ),

    .lyrf_pxl   ( lyrf_pxl  ),
    .lyra_pxl   ( lyra_pxl  ),
    .lyrb_pxl   ( lyrb_pxl  ),
    .lyrc_pxl   ( lyrc_pxl  ),

    // Debug
    .ioctl_addr ( ioctl_addr[14:0]),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_din  ( dump_scr  ),
    .mmr_dump   ( scr_mmr   ),

    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_scr    )
);

assign ommra = {cpu_addr[3:1],cpu_dsn[1]};
assign orama = {cpu_addr[15:8], cpu_addr[5:1]}; // A6/A7 not connected

/* verilator tracing_on */
jtsimson_obj #(.RAMW(13),.SHADOW(1),.ESTRIDE_LOG2(5),.ENTRY_LOG2(8),
    .HOFFSET(10'h3e1),                 // MAME dx=-47 at bitmap x 40, hdump base 56
    .FORCE16(1)) u_obj(     // F10 has both ~UDS/~LDS: board is 16-bit only
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),
    .simson     ( 1'b0      ),
    .ln_done    (           ),

    .voffset    ( 10'h117   ),        // MAME dy=23 at bitmap y 16, vdump base 0x110
    // Base Video (inputs)
    .hs         ( hs        ),
    .lvbl       ( lvbl      ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    // CPU interface
    .ram_cs     ( objsys_cs ),
    .ram_addr   ( orama     ),
    .ram_din    ( cpu_dout  ),
    .ram_we     ( oram_we   ),
    .cpu_din    (objsys_dout),

    .reg_cs     ( objreg_cs ),
    .mmr_addr   ( ommra     ),
    .mmr_din    ( cpu_dout  ),
    .mmr_we     ( cpu_we    ),
    .mmr_dsn    ( cpu_dsn   ),

    .dma_bsy    ( dma_bsy   ),
    // ROM
    .rom_addr   ( lyro_addr ),
    .rom_data   ( lyro_data ),
    .rom_ok     ( lyro_ok   ),
    .rom_cs     ( lyro_cs   ),
    .objcha_n   ( objcha_n  ),
    // pixel output
    .pxl        ( lyro_pxl  ),
    .shd        ( shadow    ),
    .prio       ( lyro_pri  ),
    // Debug
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_addr ( ioctl_addr[13:0] ),
    .dump_ram   ( dump_obj  ),
    .dump_reg   ( obj_mmr   ),
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus )
);

/* verilator tracing_on */
jtmoo_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),

    // CPU interface
    .cpu_addr   (cpu_addr[12:1]),
    .cpu_we     ( cpu_weg   ),
    .cpu_din    ( palsys_dout ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_dsn    ( cpu_dsn   ),
    .pal_cs     ( pal_cs    ),
    .pcu_cs     ( pcu_cs    ),
    .reg_cs     ( k338_cs   ),

    // Palette RAM pass-through
    .pal_we     ( pal_we      ),
    .pal_addr   ( pal_addr    ),
    .pal_din    ( pal_din     ),
    .pal_dout   ( pal_dout    ),
    .palrd_addr ( palrd_addr  ),
    .pal_data   ( pal_data    ),

    // Final pixels
    .lyrf_pxl   ( lyrf_pxl  ),
    .lyra_pxl   ( lyra_pxl  ),
    .lyrb_pxl   ( lyrb_pxl  ),
    .lyrc_pxl   ( lyrc_pxl  ),
    .lyro_pxl   ( lyro_pxl  ),
    .lyro_pri   ( lyro_pri  ),

    .shadow     ( shadow    ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),

    // Debug
    .ioctl_addr ( ioctl_addr[12:0]),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_din  ( dump_pal  ),
    .mmr_dump   ( pal_mmr   ),

    .debug_bus  ( debug_bus )
);

endmodule
