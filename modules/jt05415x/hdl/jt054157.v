/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 2-9-2026 */

// K054157 scroll layer data combiner: four pixel pipelines (ACOL..DCOL) with HOFSA..HOFSD phases
// Each pipeline is a jtframe_tilemap instance, fetching one tile ahead as in jt051962.v

module jt054157(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             blankn,

    // Per-layer tile stream from the K054156. heff/veff are the layer
    // coordinates after scroll, wrap and global flip have been applied.
    input      [ 8:0] a_heff, b_heff, c_heff, d_heff,
    input      [ 8:0] a_veff, b_veff, c_veff, d_veff,
    input      [15:0] a_code, b_code, c_code, d_code,
    input      [ 7:0] a_pal,  b_pal,  c_pal,  d_pal,
    input             a_hflip, b_hflip, c_hflip, d_hflip,
    input             a_vflip, b_vflip, c_vflip, d_vflip,
    // 1 when this pipeline owns the fetched page, 0 when a higher-priority layer covers it
    input             a_assoc, b_assoc, c_assoc, d_assoc,

    // Graphics ROM. One 32-bit word holds eight 4-bit pixels, packed as MAME
    // stores them; jtframe_8x8x4_packed_msb turns them into planes
    output     [18:0] a_rom_addr, b_rom_addr, c_rom_addr, d_rom_addr,
    input      [31:0] a_rom_data, b_rom_data, c_rom_data, d_rom_data,
    output            a_rom_cs, b_rom_cs, c_rom_cs, d_rom_cs,
    input             a_rom_ok, b_rom_ok, c_rom_ok, d_rom_ok,

    // {palette, colour} for each pipeline
    output     [11:0] a_pxl, b_pxl, c_pxl, d_pxl,

    input      [ 3:0] gfx_en
);

wire [31:0] a_sort, b_sort, c_sort, d_sort;
wire [11:0] a_raw, b_raw, c_raw, d_raw;

assign a_pxl = (gfx_en[0] & a_assoc) ? a_raw : 12'd0;
assign b_pxl = (gfx_en[1] & b_assoc) ? b_raw : 12'd0;
assign c_pxl = (gfx_en[2] & c_assoc) ? c_raw : 12'd0;
assign d_pxl = (gfx_en[3] & d_assoc) ? d_raw : 12'd0;

jtframe_8x8x4_packed_msb u_asort( a_rom_data, a_sort );
jtframe_8x8x4_packed_msb u_bsort( b_rom_data, b_sort );
jtframe_8x8x4_packed_msb u_csort( c_rom_data, c_sort );
jtframe_8x8x4_packed_msb u_dsort( d_rom_data, d_sort );

// vram_addr unused: the K054156 owns the VRAM address
jtframe_tilemap #(
    .SIZE(8), .CW(16), .PW(12), .BPP(4),
    .VA(11), .MAP_HW(9), .MAP_VW(8),
    .HDUMPW(9), .VDUMPW(9),
    .FLIP_MSB(0), .FLIP_HDUMP(0), .FLIP_VDUMP(0)
) u_lyra(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen),
    .vdump      ( a_veff        ),
    .hdump      ( a_heff        ),
    .blankn     ( blankn        ),
    // Global screen flip is already folded into a_heff/a_veff and into the
    // hflip/vflip inputs below (jt05415x.v applies glob_ctrl[4:5] before
    // calling this module). With FLIP_HDUMP=0, FLIP_VDUMP=0 and the default
    // XOR_HFLIP=XOR_VFLIP=0 on this instance, jtframe_tilemap's own `flip`
    // input has no effect on heff/veff/hflip/vflip, so tying it low is
    // equivalent to any other value here, not a discarded signal.
    .flip       ( 1'b0          ),
    .vram_addr  (               ),
    .code       ( a_code        ),
    .pal        ( a_pal         ),
    .hflip      ( a_hflip       ),
    .vflip      ( a_vflip       ),
    .rom_addr   ( a_rom_addr    ),
    .rom_data   ( a_sort        ),
    .rom_cs     ( a_rom_cs      ),
    .rom_ok     ( a_rom_ok      ),
    .pxl        ( a_raw         )
);

jtframe_tilemap #(
    .SIZE(8), .CW(16), .PW(12), .BPP(4),
    .VA(11), .MAP_HW(9), .MAP_VW(8),
    .HDUMPW(9), .VDUMPW(9),
    .FLIP_MSB(0), .FLIP_HDUMP(0), .FLIP_VDUMP(0)
) u_lyrb(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen),
    .vdump      ( b_veff        ),
    .hdump      ( b_heff        ),
    .blankn     ( blankn        ),
    .flip       ( 1'b0          ),  // see u_lyra flip note above
    .vram_addr  (               ),
    .code       ( b_code        ),
    .pal        ( b_pal         ),
    .hflip      ( b_hflip       ),
    .vflip      ( b_vflip       ),
    .rom_addr   ( b_rom_addr    ),
    .rom_data   ( b_sort        ),
    .rom_cs     ( b_rom_cs      ),
    .rom_ok     ( b_rom_ok      ),
    .pxl        ( b_raw         )
);

jtframe_tilemap #(
    .SIZE(8), .CW(16), .PW(12), .BPP(4),
    .VA(11), .MAP_HW(9), .MAP_VW(8),
    .HDUMPW(9), .VDUMPW(9),
    .FLIP_MSB(0), .FLIP_HDUMP(0), .FLIP_VDUMP(0)
) u_lyrc(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen),
    .vdump      ( c_veff        ),
    .hdump      ( c_heff        ),
    .blankn     ( blankn        ),
    .flip       ( 1'b0          ),  // see u_lyra flip note above
    .vram_addr  (               ),
    .code       ( c_code        ),
    .pal        ( c_pal         ),
    .hflip      ( c_hflip       ),
    .vflip      ( c_vflip       ),
    .rom_addr   ( c_rom_addr    ),
    .rom_data   ( c_sort        ),
    .rom_cs     ( c_rom_cs      ),
    .rom_ok     ( c_rom_ok      ),
    .pxl        ( c_raw         )
);

jtframe_tilemap #(
    .SIZE(8), .CW(16), .PW(12), .BPP(4),
    .VA(11), .MAP_HW(9), .MAP_VW(8),
    .HDUMPW(9), .VDUMPW(9),
    .FLIP_MSB(0), .FLIP_HDUMP(0), .FLIP_VDUMP(0)
) u_lyrd(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen),
    .vdump      ( d_veff        ),
    .hdump      ( d_heff        ),
    .blankn     ( blankn        ),
    .flip       ( 1'b0          ),  // see u_lyra flip note above
    .vram_addr  (               ),
    .code       ( d_code        ),
    .pal        ( d_pal         ),
    .hflip      ( d_hflip       ),
    .vflip      ( d_vflip       ),
    .rom_addr   ( d_rom_addr    ),
    .rom_data   ( d_sort        ),
    .rom_cs     ( d_rom_cs      ),
    .rom_ok     ( d_rom_ok      ),
    .pxl        ( d_raw         )
);

endmodule
