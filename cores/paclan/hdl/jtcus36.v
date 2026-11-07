/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-5-2025 */

// dual tilemap with independent scroll
module jtcus36(
    input               rst,
    input               clk, pxl_cen,
    input               flip, hs,
    output          reg fixed,
    input        [ 8:0] hdump, vdump, scr0_pos, scr1_pos,

    output       [11:1] vram0_addr, vram1_addr,
    input        [15:0] vram0_dout, vram1_dout,

    output              rom0_cs,   rom1_cs,
    output       [12:1] rom0_addr, rom1_addr,
    input        [15:0] rom0_data, rom1_data,   // upper byte not used
    input               rom0_ok,   rom1_ok,

    output              prio0,          // foreground has a priority bit
    output       [ 9:0] pxl0, pxl1,
    // debug
    input        [ 7:0] debug_bus
);

parameter ID=0;

wire [ 2:0] prioa, priob;
reg  [ 8:0] eff_pos0;

always @(posedge clk) begin
    eff_pos0 <= fixed ? 9'd0 : scr0_pos;
    fixed    <= vdump[7:3]<5 || vdump[7:3]>28;
end

// foreground
jtpaclan_scroll #(.LAYER(0)) u_scr0(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( hs            ),
    .flip       ( flip          ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),
    .scrx       ( eff_pos0      ),

    .vram_addr  ( vram0_addr    ),
    .vram_dout  ( vram0_dout    ),

    .rom_cs     ( rom0_cs       ),
    .rom_addr   ( rom0_addr     ),
    .rom_data   ( rom0_data     ),
    .rom_ok     ( rom0_ok       ),
    .debug_bus  ( debug_bus     ),

    .prio       ( prio0         ),
    .pxl        ( pxl0          )
);

// background
jtpaclan_scroll #(.LAYER(1),.HBASE(-9'd3)) u_scr1(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( hs            ),
    .flip       ( flip          ),
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),
    .scrx       ( scr1_pos      ),

    .vram_addr  ( vram1_addr    ),
    .vram_dout  ( vram1_dout    ),

    .rom_cs     ( rom1_cs       ),
    .rom_addr   ( rom1_addr     ),
    .rom_data   ( rom1_data     ),
    .rom_ok     ( rom1_ok       ),
    .debug_bus  ( debug_bus     ),

    .prio       (               ),
    .pxl        ( pxl1          )
);

endmodule