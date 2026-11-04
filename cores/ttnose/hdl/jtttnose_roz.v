/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 01-11-2026 */

module jtttnose_roz #(
    parameter YOFFSET=0
)(
    input             rst, clk, pxl_cen, pxl2_cen,
    input             hs, vs, lhbl, lvbl,
    input      [8:0]  hdump, vdump, h_last,
    input             ctrl_we,
    input      [3:0]  ctrl_addr,
    input      [7:0]  ctrl_din,
    input             map_cs, map_we,
    input      [10:0] map_addr,
    input      [7:0]  map_din,
    output     [7:0]  map_dout,
    output            map_ok,
    output     [16:1] gfx_addr,
    input      [15:0] gfx_data,
    input      [10:0] ioctl_addr,
    input             ioctl_ram,
    output     [7:0]  ioctl_din, mmr_dump,
    output     [6:0]  pxl
);

wire [23:0] byte_addr;
wire [8:0] read_h = hdump==h_last ? 9'd0 : hdump+9'd1;
wire [7:0] raw_pxl;
wire [7:0] gfx_byte = byte_addr[0] ? gfx_data[7:0] : gfx_data[15:8];
wire [10:0] cpu_addr = ctrl_we ? {7'd0,ctrl_addr} : map_addr;

assign gfx_addr = byte_addr[16:1];
assign pxl = raw_pxl[6:0];

jt051316 #(
    .WR_STRT ( 9'd0      ),
    .VB_END  ( 9'd255    ),
    .RST_CT  ( 9'd0      ),
    .RD_DLY  ( 9'd1      ),
    .RD_END  ( 9'd321    ),
    .BPP     ( 4         ),
    .ROLLERG ( 0         ),
    .YOFFSET ( 2-YOFFSET )
) u_psac(
    .rst        ( rst                          ),
    .clk        ( clk                          ),
    .pxl_cen    ( pxl_cen                      ),
    .cen24      ( pxl2_cen                     ),
    .hs         ( hs                           ),
    .vs         ( vs                           ),
    .lhbl       ( lhbl                         ),
    .lvbl       ( lvbl                         ),
    .cpu_addr   ( cpu_addr                     ),
    .cpu_dout   ( ctrl_we ? ctrl_din : map_din ),
    .cpu_din    ( map_dout                     ),
    .cpu_ok     ( map_ok                       ),
    .cpu_we     ( ctrl_we | map_we             ),
    .io_cs      ( ctrl_we                      ),
    .vr_cs      ( map_cs & ~ctrl_we            ),
    .pxl        ( raw_pxl                      ),
    .blnk_n     (                              ),
    .rvo        ( 1'b0                         ),
    .wrap       ( 1'b1                         ),
    .hdump      ( read_h                       ),
    .vdump      ( vdump                        ),
    .rom_addr   ( byte_addr                    ),
    .rom_cs     (                              ),
    .rom_ok     ( pxl2_cen                     ),
    .rom_data   ( gfx_byte                     ),
    .ioctl_addr ( ioctl_addr                   ),
    .ioctl_ram  ( ioctl_ram                    ),
    .ioctl_din  ( ioctl_din                    ),
    .mmr_dump   ( mmr_dump                     )
);

endmodule
