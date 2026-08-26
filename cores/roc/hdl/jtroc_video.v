/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 15-8-2022 */

module jtroc_video(
    input               rst,
    input               clk,        // 48 MHz
    input               clk24,      // 24 MHz

    input               pxl_cen,
    input               pxl2_cen,

    // configuration
    input               flip,

    // CPU interface
    input        [10:0] cpu_addr,
    input         [7:0] cpu_dout,
    input               cpu_rnw,

    input               vram_cs,
    output        [7:0] vcpu_din,

    output       [ 1:0] vramrw_we,
    input        [15:0] vramrw_dout,
    output       [10:1] vramrw_addr,

    input               objram_cs,
    output        [7:0] obj_dout,

    //VRAM read out
    output       [10:1] vram_addr,
    input        [15:0] vram_dout,

    // PROMs
    input         [7:0] prog_data,
    input         [9:0] prog_addr,
    input               prom_en,

    // Scroll
    output       [12:0] scr_addr,
    input        [31:0] scr_data,
    input               scr_ok,

    // Objects
    output       [13:0] obj_addr,
    input        [31:0] obj_data,
    output              obj_cs,
    input               obj_ok,

    output              HS,
    output              VS,
    output              LHBL,
    output              LVBL,
    output        [3:0] red,
    output        [3:0] green,
    output        [3:0] blue,
    input         [3:0] gfx_en,
    input         [7:0] debug_bus
);

parameter LAYOUT=5;

wire       preLHBL, preLVBL, hinit;
wire [8:0] vdump, vrender, hdump;
wire [3:0] obj_pxl, scr_pxl;
reg  [2:0] prom_we;
wire       obj1_cs, obj2_cs, prio, obj_en;
reg  [1:0] fix_addr;

assign obj1_cs = objram_cs &  cpu_addr[10];
assign obj2_cs = objram_cs & ~cpu_addr[10];
assign obj_en  = gfx_en[3] & ~prio;

always @* begin
    prom_we = 0;
    prom_we[ prog_addr[9:8] ] = prom_en;
end

// reg [10:0] vram_addr, objram_addr;

// always @(posedge clk) begin
//     if( vram_cs) vram_addr <= cpu_addr;
//     if( objram_cs ) objram_addr <= cpu_addr;
// end

jtkicker_vtimer #(.LAYOUT(LAYOUT)) u_vtimer(
    .clk    ( clk       ),
    .pxl_cen( pxl_cen   ),
    .vdump  ( vdump     ),
    .vrender( vrender   ),
    .hdump  ( hdump     ),
    .hinit  ( hinit     ),
    .LHBL   ( preLHBL   ),
    .LVBL   ( preLVBL   ),
    .HS     ( HS        ),
    .VS     ( VS        )
);

jtkicker_scroll #(.LAYOUT(LAYOUT),.NOSCROLL(1)) u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk24      ( clk24     ),

    .pxl_cen    ( pxl_cen   ),

    // CPU interface
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_rnw    ( cpu_rnw   ),
    .vram_cs    ( vram_cs   ),
    .vscr_cs    ( 1'b0      ),
    .vram_dout  ( vram_dout ),
    .vscr_dout  (           ),
    .cpu_din    ( vcpu_din  ),
    .vramrw_we  ( vramrw_we ),
    .vramrw_addr(vramrw_addr),
    .vramrw_dout(vramrw_dout),
    .rd_addr    ( vram_addr ),

    // video inputs
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .vdump      ( vdump[7:0] ),
    .hdump      ( hdump     ),
    .flip       ( flip      ),

    // PROMs
    .prog_data  ( prog_data[3:0] ),
    .prog_addr  ( prog_addr[7:0] ),
    .prog_en    ( prom_we[1]),

    // SDRAM
    .rom_addr   ( scr_addr  ),
    .rom_data   ( scr_data  ),
    .rom_ok     ( scr_ok    ),

    .prio       ( prio      ),
    .pxl        ( scr_pxl   ),
    .debug_bus  ( debug_bus )
);

jtkicker_obj #(.LAYOUT(LAYOUT)) u_obj(
    .rst        ( rst       ),
    .clk        ( clk       ),      // 48 MHz
    .clk24      ( clk24     ),      // 24 MHz

    .pxl_cen    ( pxl_cen   ),

    // CPU interface
    .cpu_addr   ( cpu_addr[9:0] ),
    .cpu_dout   ( cpu_dout  ),
    .obj1_cs    ( obj1_cs   ),
    .obj2_cs    ( obj2_cs   ),
    .cpu_rnw    ( cpu_rnw   ),
    .obj_dout   ( obj_dout  ),

    // video inputs
    .hinit      ( hinit     ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .vrender    (vrender[7:0]),
    .hdump      ( hdump     ),
    .flip       ( 1'd0      ),      // unconnected in the original

    // PROMs
    .prog_data  ( prog_data[3:0] ),
    // In order to keep the bit plane order in jtkicker_obj intact,
    // I am sorting the bits in the colour PROM
    .prog_addr  ( prog_addr[7:0] ),
    .prog_en    ( prom_we[0]),

    // SDRAM
    .rom_cs     ( obj_cs    ),
    .rom_addr   ( obj_addr  ),
    .rom_data   ( obj_data  ),
    .rom_ok     ( obj_ok    ),
    .debug_bus  ( debug_bus ),

    .pxl        ( obj_pxl   )
);

jtyiear_colmix #(.BLANK_DLY(9),.LOWONLY(1)) u_colmix(
    .clk        ( clk       ),

    .pxl_cen    ( pxl_cen   ),
    .scr_prio   ( 1'b0      ),

    // video inputs
    .obj_pxl    ( obj_pxl   ),
    .scr_pxl    ( scr_pxl   ),
    .preLHBL    ( preLHBL   ),
    .preLVBL    ( preLVBL   ),

    // PROMs
    .prog_data  (prog_data  ),
    .prog_addr  (prog_addr[4:0]),
    .prog_en    (prom_we[2] ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .gfx_en     ( { obj_en, gfx_en[2:0] } )
);

endmodule