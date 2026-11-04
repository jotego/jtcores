/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 9-8-2020 */

module jtsarms_video #(
    parameter SCRW  = 17,
    parameter OBJW  = 17,
    parameter STARW = 15
)(
    input               rst,
    input               clk,
    input               pxl2_cen,
    input               pxl_cen,
    input               cpu_cen,
    input       [11:0]  cpu_AB,
    output      [ 8:0]  V,
    output      [ 8:0]  H,
    input               RnW,
    input               flip,
    input       [ 7:0]  cpu_dout,
    // Enable bits
    input               CHON,
    input               SCRON,
    input               STARON,
    input               OBJON,
    // CHAR
    input               char_cs,
    output      [ 7:0]  char_dout,
    input               char_ok,
    output              char_busy,
    output      [13:0]  char_addr,
    input       [15:0]  char_data,
    // SCROLL - ROM
    output  [SCRW-1:0]  scr_addr,
    input       [15:0]  scr_data,
    input               scr_ok,
    input       [15:0]  scr_hpos,
    input       [15:0]  scr_vpos, // only 12 bits are used
    output      [13:0]  map_addr, // 32kB in 8 bits or 16kW in 16 bits
    input       [15:0]  map_data,
    input               map_ok,
    output              map_cs,
    // Star field
    output [STARW-1:0]  star_addr, // 64kB in 8 bits or 32kW in 16 bits
    input       [ 7:0]  star_data,
    input               star_ok,
    input               star_hscan,
    input               star_vscan,
    input               star_fix_n,
    // OBJ
    output      [12:0]  obj_AB,
    input       [ 7:0]  main_ram,
    input               OKOUT,
    output              bus_req, // Request bus
    input               bus_ack, // bus acknowledge
    output              blcnten, // bus line counter enable
    output  [OBJW-1:0]  obj_addr,
    input       [15:0]  obj_data,
    input               obj_ok,
    // Color Mix
    output              LHBL,
    output              LVBL,
    output              HS,
    output              VS,
    input               eres_n,        // clears palette error signal
    output              wrerr_n,       // marks an attempt to write in palette outside v-blanking
    // Palette RAM
    input               blue_cs,
    input               redgreen_cs,
    input       [3:0]   gfx_en,
    input       [7:0]   debug_bus,
    // Pixel output
    output      [3:0]   red,
    output      [3:0]   green,
    output      [3:0]   blue
);

localparam       LAYOUT      = 8;
localparam       PXL_CHRW    = 8;
localparam       SCR_OFFSET  = 0;
localparam       CHAR_OFFSET = -3;
localparam       OBJ_DLY     = 6;
localparam       BLANK_DLY   = 3;
localparam [9:0] OBJMAX      = 10'h200; // DMA buffer 512 bytes = 4*128
localparam [5:0] OBJMAX_LINE = 6'd32;

wire       preLHBL, preLVBL, HINIT;

wire [7:0] char_pxl, obj_pxl;
wire [8:0] scr_pxl;
wire [2:0] star_pxl;

// Frame rate and blanking as the original
// Sync pulses slightly adjusted
jtframe_vtimer #(
    .HB_START ( 9'h1CF ),
    .HB_END   ( 9'h04F ),
    .HCNT_END ( 9'h1FF ),
    .VB_START ( 9'hF0  ),
    .VB_END   ( 9'h10  ),
    .VCNT_END ( 9'hFF  ),
    //.VS_START ( 9'h0   ),
    .VS_START ( 9'hF5   ),
    //.VS_END   ( 9'h8   ),
    .HS_START ( 9'h1F2 ),
    .HS_END   ( 9'h01A ),
    .H_VB     ( 9'h7   ),
    .H_VS     ( 9'h1FF ),
    .H_VNEXT  ( 9'h1FF ),
    .HINIT    ( 9'h20 )
) u_timer(
    .clk       ( clk      ),
    .pxl_cen   ( pxl_cen  ),
    .vdump     ( V        ),
    .H         ( H        ),
    .Hinit     ( HINIT    ),
    .LHBL      ( preLHBL  ),
    .LVBL      ( preLVBL  ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          ),
    // unused
    .vrender   (          ),
    .vrender1  (          )
);

jtgng_char #(
    .HOFFSET ( CHAR_OFFSET ),
    .ROM_AW  ( 14          ),
    .PALW    (  6          ),
    .VFLIP_EN(  0          ),
    .HFLIP_EN(  0          ),
    .LAYOUT  (  LAYOUT     )
) u_char (
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .AB         ( cpu_AB        ),
    .V          ( V[7:0]        ),
    .H          ( H             ),
    .flip       ( flip          ),
    .din        ( cpu_dout      ),
    .dout       ( char_dout     ),
    // Bus arbitrion
    .char_cs    ( char_cs       ),
    .wr_n       ( RnW           ),
    .busy       ( char_busy     ),
    // ROM
    .char_addr  ( char_addr     ),
    .rom_data   ( char_data     ),
    .rom_ok     ( char_ok       ),
    // Pixel output
    .char_on    ( CHON          ),
    .char_pxl   ( char_pxl      ),
    // unused
    .dseln      (               ),
    .prog_addr  (               ),
    .prog_din   (               ),
    .prom_we    (               )
);

jt1943_scroll #(
    .HOFFSET    (SCR_OFFSET   ),
    .AS8MASK    ( 1'b0        ),
    .ROM_AW     ( SCRW        ),
    .PALETTE    ( 0           ),
    .LAYOUT     ( LAYOUT      ),
    .MAPCACHE   ( 0           )
) u_scroll (
    .rst          ( rst           ),
    .clk          ( clk           ),
    .cen6         ( pxl_cen       ),
    .V128         ( {1'b0, V[7:0]}),
    .LHBL         ( LHBL          ),
    .H            ( H             ),
    .SCxON        ( SCRON         ),
    .hpos         ( scr_hpos      ),
    .vpos         ( scr_vpos      ),
    .flip         ( flip          ),
    // Palette PROMs - unused in Side Arms
    .prog_addr    ( 8'd0          ),
    .prom_hi_we   ( 1'b0          ),
    .prom_lo_we   ( 1'b0          ),
    .prom_din     ( 4'd0          ),

    // ROM
    .map_addr     ( map_addr      ),
    .map_data     ( map_data      ),
    .map_ok       ( map_ok        ),
    .map_cs       ( map_cs        ),
    .scr_addr     ( scr_addr      ),
    .scrom_data   ( scr_data      ),
    .scr_pxl      ( scr_pxl       ),
    .debug_bus    ( 8'd0          )
);

jtsarms_star u_star(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .pxl_cen    ( pxl_cen    ),
    .V          ( V[7:0]     ),
    .H          ( H          ),
    .fixed_n    ( star_fix_n ),
    // From CPU
    .STARON     ( STARON     ),
    .flip       ( flip       ),
    .hscan      ( star_hscan ),
    .vscan      ( star_vscan ),
    // To SDRAM
    .rom_addr   ( star_addr  ),
    .rom_data   ( star_data  ),
    .rom_ok     ( star_ok    ),
    // Output star
    .debug_bus  ( debug_bus  ),
    .star_pxl   ( star_pxl   )
);

assign obj_AB[ 12] = 1'b1;
assign obj_AB[4:2] = 3'b0;

jtgng_obj #(
    .ROM_AW       ( OBJW        ),
    .PALW         (  4          ),
    .PXL_DLY      ( OBJ_DLY     ),
    .LAYOUT       ( LAYOUT      ),
    .OBJMAX       ( OBJMAX      ),
    .OBJMAX_LINE  ( OBJMAX_LINE )
) u_obj (
    .rst        ( rst         ),
    .clk        ( clk         ),
    .draw_cen   ( pxl2_cen    ),
    .dma_cen    ( pxl_cen     ),
    .pxl_cen    ( pxl_cen     ),
    .AB         ( {obj_AB[11:5], obj_AB[1:0]} ),
    .DB         ( main_ram    ),
    .OKOUT      ( OKOUT       ),
    .bus_req    ( bus_req     ),
    .bus_ack    ( bus_ack     ),
    .blen       ( blcnten     ),
    .LHBL       ( LHBL        ),
    .LVBL       ( LVBL        ),
    .LVBL_obj   ( LVBL        ),
    .HINIT      ( HINIT       ),
    .flip       ( flip        ),
    .alt        ( 1'b0        ),
    .V          ( V[7:0]      ),
    .H          ( H           ),
    // SDRAM interface
    .obj_addr   ( obj_addr    ),
    .obj_data   ( obj_data    ),
    .rom_ok     ( obj_ok      ),
    // pixel data
    .obj_pxl    ( obj_pxl     ),
    // unused
    .prog_addr  (             ),
    .prog_din   (             ),
    .prom_hi_we ( 1'b0        ),
    .prom_lo_we ( 1'b0        ),
    .OBJON      ( 1'b1        )
);

jtsarms_colmix #(
    .CHARW     ( PXL_CHRW  ),
    .BLANK_DLY ( BLANK_DLY )
)
u_colmix (
    .rst          ( rst           ),
    .clk          ( clk           ),
    .pxl2_cen     ( pxl2_cen      ),
    .pxl_cen      ( pxl_cen       ),
    .cpu_cen      ( cpu_cen       ),

    .char_pxl     ( char_pxl      ),
    .scr_pxl      ( scr_pxl       ),
    .star_pxl     ( star_pxl      ),
    .obj_pxl      ( obj_pxl       ),
    .preLHBL      ( preLHBL       ),
    .preLVBL      ( preLVBL       ),
    .LVBL         ( LVBL          ),
    .LHBL         ( LHBL          ),

    // Enable bits
    .CHON         ( CHON          ),
    .SCRON        ( SCRON         ),
    .OBJON        ( OBJON         ),

    // Priority PROM
    // .prog_addr    ( prog_addr     ),
    // .prom_prio_we ( prom_prio_we  ),
    // .prom_din     ( prom_din      ),

    // DEBUG
    .gfx_en       ( gfx_en        ),

    // CPU interface
    .AB           ( cpu_AB[9:0]   ),
    .blue_cs      ( blue_cs       ),
    .redgreen_cs  ( redgreen_cs   ),
    .DB           ( cpu_dout      ),
    .cpu_wrn      ( RnW           ),
    .eres_n       ( eres_n        ),
    .wrerr_n      ( wrerr_n       ),

    // colour output
    .red          ( red           ),
    .green        ( green         ),
    .blue         ( blue          )
);

endmodule
