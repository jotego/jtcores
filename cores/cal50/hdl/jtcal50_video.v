/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 15-11-2025 */

module jtcal50_video(
    input               rst,
    input               clk,
    input               clk_cpu,
    input               pxl2_cen,
    input               pxl_cen,
    output reg          cen244,

    output              LHBL,
    output              LVBL,
    output              HS,
    output              VS,
    output              flip,
    output     [ 8:0]   hdump,
    // Palette
    output     [ 9:1]   pal_addr,
    input      [15:0]   pal_data,
    // CPU      interface
    input               cpu_rnw,
    input      [13:1]   cpu_addr,
    input      [15:0]   cpu_dout,
    input      [ 1:0]   cpu_dsn,
    input               tctrl_cs,
    input               vram_cs,
    input               vctrl_cs,
    input               vflag_cs,
    output     [15:0]   vram_dout,
    // Tilemap video RAM
    output     [13:1]   tvram_addr,
    input      [15:0]   tvram_dout,
    // Tile ROM
    output     [20:2]   tile_addr,
    input      [31:0]   tile_data,
    output              tile_cs,
    input               tile_ok,
    // X1-001 Internal RAM (defined in mem.yaml)
    output     [ 9:0]   col_addr,
    input      [ 7:0]   col_data, yram_dout,
    output              yram_we,
    // X1-001 External VRAM (defined in mem.yaml)
    output     [12:1]   dma_addr,
    output     [15:0]   dma_din,
    output     [ 1:0]   dma_we,
    input      [15:0]   dma_dout, code_dout,
    output     [11:0]   code_addr,
    // SDRAM interface
    output     [20:2]   scr_addr,
    input      [31:0]   scr_data,
    input               scr_ok,
    output              scr_cs,

    output     [20:2]   obj_addr,
    input      [31:0]   obj_data,
    input               obj_ok,
    output              obj_cs,
    // Colours
    output     [ 4:0]   red,
    output     [ 4:0]   green,
    output     [ 4:0]   blue,
    // IOCTL dump
    input      [ 3:0]   ioctl_addr,
    output     [ 7:0]   ioctl_din,
    // Test
    input      [ 3:0]   gfx_en,
    input      [ 7:0]   debug_bus,
    output reg [ 7:0]   st_dout
);

wire [ 8:0] vrender, vrender1, vdump;
wire [ 8:0] scr_pxl, obj_pxl, tiles_pxl;
wire [ 7:0] st_tiles, st_kiwi, x1012_ioctl_din, x1001_ioctl_din;

reg        LHBL_l;
reg  [5:0] cnt244;
wire [6:0] nx_244 = {1'b0,cnt244} + 6'd1;
localparam [8:0] OBJ_VOFF =  9'd18, OBJ_VOFF_F = -9'd4,
                 OBJ_HOFF = -9'd4,  OBJ_HOFF_F = -9'd7;

wire [8:0] hdump_gfx = hdump - 9'd7;
wire [8:0] vdump_gfx = vdump - 9'd1;

assign ioctl_din = ioctl_addr[3] ? x1001_ioctl_din : x1012_ioctl_din;

always @(posedge clk) begin
    LHBL_l <= LHBL;
    cen244 <= 0;
    if( ~LHBL & LHBL_l ) {cen244,cnt244} <= nx_244;
end

always @(posedge clk) begin
    st_dout <= debug_bus[6] ? st_tiles : st_kiwi;
end

// Measured on PCB
// 64us per line, 8us blanking
// 17.45ms per frame, 2.05ms blanking, 512.5us sync (centered)
jtframe_vtimer #(
    .HB_END  ( 9'd4   ),
    .HB_START( 9'd388 ),
    .HS_START( 9'd409 ),
    .HS_END  ( 9'd461 ),
    .HCNT_END( 9'd511 ),
    .V_START ( 9'd000 ),
    .VS_START( 9'd253 ),
    .VS_END  ( 9'd261 ),
    .VB_START( 9'd240 ),
    .VB_END  ( 9'd000 ),
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
/* verilator tracing_off */
jtx1012 u_tiles(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .cs         ( tctrl_cs      ),
    .addr       ( cpu_addr[2:1] ),
    .rnw        ( cpu_rnw       ),
    .din        ( cpu_dout      ),
    .dsn        ( cpu_dsn       ),

    .hs         ( HS            ),
    .flip       ( flip          ),
    .vdump      ( vdump_gfx     ),
    .hdump      ( hdump_gfx     ),
    // Video RAM
    .vram_addr  ( tvram_addr    ),
    .vram_dout  ( tvram_dout    ),

    // Tile ROM
    .rom_addr   ( tile_addr     ),
    .rom_data   ( tile_data     ),
    .rom_cs     ( tile_cs       ),
    .rom_ok     ( tile_ok       ),

    .pxl        ( tiles_pxl     ),
    // IOCTL dump
    .ioctl_addr ( ioctl_addr[2:0]),
    .ioctl_din  ( x1012_ioctl_din ),
    // Debug
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_tiles      )
);

wire [8:0] vdump_adj   = vdump   + (flip ? OBJ_VOFF : OBJ_VOFF_F),
           vrender_adj = vrender + (flip ? OBJ_VOFF : OBJ_VOFF_F),
           hdump_adj   = hdump   + (flip ? OBJ_HOFF : OBJ_HOFF_F);

/* verilator tracing_on */
jtkiwi_gfx #(
    .CPUW    ( 16      ),
    .OBJ_XOFF( 9'h1fe  ),
    .OBJ_YOFF( 8'hf5   ),
    .OBJ_YWRAP( 1'b1   ),
    .OBJ_LIMIT( 9'h1ff )
) u_gfx(
    .rst        ( rst            ),
    .clk        ( clk            ),
    .clk_cpu    ( clk_cpu        ),
    .pxl_cen    ( pxl_cen        ),
    .pxl2_cen   ( pxl2_cen       ),
    .drtoppel   ( 1'b0           ),
    // Screen
    .flip       ( flip           ),
    .LHBL       ( LHBL           ),
    .LVBL       ( LVBL           ),
    .vs         ( VS             ),
    .hs         ( HS             ),
    .vdump      ( vdump_adj      ),
    .vrender    ( vrender_adj    ),
    .hdump      ( hdump_adj      ),
    // CPU interface
    .vram_cs    ( vram_cs        ),
    .vctrl_cs   ( vctrl_cs       ),
    .vflag_cs   ( vflag_cs       ),
    .cpu_addr   ( cpu_addr       ),
    .cpu_rnw    ( cpu_rnw        ),
    .cpu_dout   ( cpu_dout       ),
    .cpu_din    ( vram_dout      ),
    // IOCTL dump
    .ioctl_addr ( ioctl_addr[1:0]),
    .ioctl_din  ( x1001_ioctl_din),
    // 16-bit interface
    .cpu_dsn    ( cpu_dsn        ),
    // X1-001 Internal RAM
    .yram_we    ( yram_we        ),
    .yram_dout  ( yram_dout      ),
    .col_data   ( col_data       ),
    .col_addr   ( col_addr       ),
    // External VRAM (defined in mem.yaml)
    .dma_addr   ( dma_addr       ),
    .dma_din    ( dma_din        ),
    .dma_we     ( dma_we         ),
    .dma_dout   ( dma_dout       ),
    .code_dout  ( code_dout      ),
    .code_addr  ( code_addr      ),
    // SDRAM
    .scr_addr   ( scr_addr       ),
    .scr_data   ( scr_data       ),
    .scr_ok     ( scr_ok         ),
    .scr_cs     ( scr_cs         ),

    .obj_addr   ( obj_addr       ),
    .obj_data   ( obj_data       ),
    .obj_ok     ( obj_ok         ),
    .obj_cs     ( obj_cs         ),
    // Color address to palette
    .scr_pxl    ( scr_pxl        ),
    .obj_pxl    ( obj_pxl        ),
    .debug_bus  ( debug_bus      ),
    .st_dout    ( st_kiwi        )
);
/* verilator tracing_on */
jtcal50_colmix u_colmix(
    .clk        ( clk            ),
    .clk_cpu    ( clk_cpu        ),
    .pxl_cen    ( pxl_cen        ),
    // Screen
    .LHBL       ( LHBL           ),
    .LVBL       ( LVBL           ),
    // RAM
    .pal_addr   ( pal_addr       ),
    .pal_data   ( pal_data       ),
    // Colour output
    .scr_pxl    ( scr_pxl        ),
    .obj_pxl    ( obj_pxl        ),
    .tiles_pxl  ( tiles_pxl      ),
    // output pixel
    .red        ( red            ),
    .green      ( green          ),
    .blue       ( blue           ),
    // debug
    .gfx_en     ( gfx_en         ),
    .debug_bus  ( debug_bus      )
);

endmodule
