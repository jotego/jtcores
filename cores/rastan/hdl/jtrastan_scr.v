/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 2-4-2022 */

// This module implements the pc080sn logic
// The original clock was 26.686MHz/2 = 13.343MHz
// Using 48MHz as basis, the ratio is 1073/3860
// Measurements on Operation Wolf reported in MAME
//    VSync - 60.0551Hz
//    HSync - 15.6742kHz

module jtrastan_scr(
    input           rst,
    input           clk,
    output          pxl_cen,
    output          pxl2_cen,

    output          HS,
    output          VS,
    output          LHBL,
    output          LVBL,
    output          flip,
    output   [ 8:0] hdump,
    output   [ 8:0] vrender,

    input    [18:1] main_addr,
    input    [15:0] main_dout,
    input    [ 1:0] main_dsn,
    input           main_rnw,
    input           scr_cs,        // selection from address decoder
    output          dtackn,

    input    [ 4:0] ioctl_addr,
    output   [ 7:0] ioctl_din,

`ifdef RASTAN_SCRRAM_SDRAM
    output   [15:2] ram0_addr,
    input    [31:0] ram0_data,
    input           ram0_ok,
    output          ram0_cs,
    output   [15:2] ram1_addr,
    input    [31:0] ram1_data,
    input           ram1_ok,
    output          ram1_cs,
`else
    output   [15:2] ram_addr,
    input    [31:0] ram_data,
`endif

    output   [19:2] rom0_addr,
    input    [31:0] rom0_data,
    input           rom0_ok,
    output          rom0_cs,

    output   [19:2] rom1_addr,
    input    [31:0] rom1_data,
    input           rom1_ok,
    output          rom1_cs,

    output   [10:0] scr1_pxl,
    output   [10:0] scr0_pxl,

    input    [ 7:0] debug_bus,
    output   [ 7:0] debug_view
);

wire [ 8:0] vdump;
wire [15:0] scr0_hpos, scr1_hpos, scr0_vpos, scr1_vpos;
`ifndef RASTAN_SCRRAM_SDRAM
wire [15:2] ram0_addr, ram1_addr;
wire [31:0] ram0_data, ram1_data;
wire        ram0_cs, ram1_cs, ram0_ok, ram1_ok;
`endif

assign dtackn = 0;
assign debug_view = scr1_hpos[8:1];

jtrastan_mmr u_mmr(
    .rst        ( rst                                ),
    .clk        ( clk                                ),
    .cs         ( scr_cs                             ),
    .addr       ({main_addr[18:16],main_addr[1]}     ),
    .rnw        ( main_rnw                           ),
    .din        ( main_dout                          ),
    .dsn        ( main_dsn                           ),
    .scr0_vpos  ( scr0_vpos                          ),
    .scr1_vpos  ( scr1_vpos                          ),
    .scr0_hpos  ( scr0_hpos                          ),
    .scr1_hpos  ( scr1_hpos                          ),
    .flip       ( flip                               ),
    .ioctl_addr ( ioctl_addr                         ),
    .ioctl_din  ( ioctl_din                          ),
    .debug_bus  ( debug_bus                          ),
    .st_dout    (                                    )
);

jtframe_frac_cen #(
    .W (  2 )
) u_cen (
    .clk    ( clk       ),
    .n      ( 10'd1     ),         // numerator
    .m      ( 10'd4     ),         // denominator
    .cen    ({pxl_cen,pxl2_cen}),
    .cenb   (           )
);

// According to accurate PCB measurements
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
    .vdump      (           ),
    .vrender    ( vdump     ),
    .vrender1   ( vrender   ),
    .H          ( hdump     ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .HS         ( HS        ),
    .VS         ( VS        )
);

jtrastan_tilemap u_scr0( // background
    .rst        ( rst       ),
    .clk        ( clk       ),

    .flip       ( flip      ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),

    .hpos       ( scr0_hpos[8:0] ),
    .vpos       ( scr0_vpos[8:0] ),

    .ram_addr   ( ram0_addr ),
    .ram_data   ( ram0_data ),
    .ram_ok     ( ram0_ok   ),
    .ram_cs     ( ram0_cs   ),

    .rom_addr   ( rom0_addr ),
    .rom_data   ( rom0_data ),
    .rom_ok     ( rom0_ok   ),
    .rom_cs     ( rom0_cs   ),

    .pxl        ( scr0_pxl  ),
    .debug_bus  ( debug_bus )
);

jtrastan_tilemap #(1) u_scr1( // foreground
    .rst        ( rst       ),
    .clk        ( clk       ),

    .flip       ( flip      ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),

    .hpos       ( scr1_hpos[8:0] ),
    .vpos       ( scr1_vpos[8:0] ),

    .ram_addr   ( ram1_addr ),
    .ram_data   ( ram1_data ),
    .ram_ok     ( ram1_ok   ),
    .ram_cs     ( ram1_cs   ),

    .rom_addr   ( rom1_addr ),
    .rom_data   ( rom1_data ),
    .rom_ok     ( rom1_ok   ),
    .rom_cs     ( rom1_cs   ),

    .pxl        ( scr1_pxl  ),
    .debug_bus  ( debug_bus )
);

`ifndef RASTAN_SCRRAM_SDRAM
jtframe_ram_rdmux #(.AW(14),.DW(32)) u_vram_mux(
    .clk    ( clk       ),
    .addr   ( ram_addr  ),
    .data   ( ram_data  ),
    .addr_a ( ram0_addr ),
    .addr_b ( ram1_addr ),
    .cs_a   ( ram0_cs   ),
    .cs_b   ( ram1_cs   ),
    .douta  ( ram0_data ),
    .doutb  ( ram1_data ),
    .ok_a   ( ram0_ok   ),
    .ok_b   ( ram1_ok   )
);
`endif

endmodule
