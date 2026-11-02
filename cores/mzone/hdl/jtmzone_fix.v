/* SPDX-FileCopyrightText: 2026 Ulf Skutnabba
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-10-2026 */

// JTFRAME helper comparison and retained PCB timing: doc/renderers.md.

module jtmzone_fix #(
    // Align the FIX source and priority windows with FIX pixels at colmix.
    parameter          FIX_EN_DLY=6
)(
    input              rst,
    input              clk,
    input              pxl_cen,

    output     [ 9:0]  ram_addr,
    input      [ 7:0]  vram,
    input      [ 7:0]  cram,

    input      [ 8:0]  hdump,
    input      [ 8:0]  vdump,
    input              flip,
    input              dip_orig_hactive,

    input      [ 3:0]  prog_data,
    input      [ 7:0]  prog_addr,
    input              prog_en,

    output     [11:0]  rom_addr,
    output             rom_cs,
    input      [31:0]  rom_data,
    input              rom_ok,

    output     [ 3:0]  pxl,
    output             fix_src,
    output             fix_en
);

localparam [ 8:0]  FIX_WIDTH = 9'd48;
localparam [ 8:0]  FIX_FLIP_START = 9'd240;
localparam [ 8:0]  FIX_FLIP_END = 9'd288;
wire [ 8:0]  nonflip_hvisible = dip_orig_hactive ? 9'd287 : 9'd288;
wire [ 8:0]  hsum_limit = flip ? 9'd287 : nonflip_hvisible;
wire [ 8:0]  hbase = hdump < hsum_limit ? hdump : {6'b111111,hdump[2:0]};
wire [ 8:0]  origin = flip ? FIX_FLIP_START : 9'd0;
wire         blank_fetch = hdump>=9'd288 && hdump<=9'd375;
// PCB map coordinate plus the native helper's four-pixel pipeline lead.
// Keep the horizontal blank mapping and flipped FIX origin outside the helper.
wire [ 8:0]  pcb_h = blank_fetch ? hdump-(flip ? 9'd168 : 9'd160) :
                    flip ? FIX_WIDTH-9'd9-hbase+origin : hbase-origin;
wire [ 7:0]  tile_h = pcb_h[7:0];
wire [ 7:0]  vsum = vdump[8] ? vdump[7:0]-8'd8 : vdump[7:0];
wire [ 7:0]  tile_v = flip ? ~vsum : vsum;
wire [31:0]  planes;
wire [ 7:0]  raw_pxl;
wire [ 9:0]  map_addr;
genvar b;
wire         fix_en_pre = flip ? hdump>=FIX_FLIP_START && hdump<FIX_FLIP_END :
                        hdump>=nonflip_hvisible || hdump<9'd47;
wire         fix_src_pre = flip ? hdump>=FIX_FLIP_START && hdump<FIX_FLIP_END :
                            hdump>=nonflip_hvisible || hdump<9'd48;

// The blanking count primes the last tile before X=0. Keep its column
// mapping without an extra tile-boundary event at blanking exit.
// The flipped counter fold at raw H=287 maps to column 3; prime that
// word for the delayed FIX source window at the end of the visible line.
assign ram_addr = flip && hdump>=9'd284 && hdump<9'd288 ?
                    {map_addr[9:5],5'd3} :
                    blank_fetch && !flip ? {map_addr[9:5],map_addr[4:0]-5'd1} : map_addr;

// Convert the PCB paired-nibble ROM format into JTFRAME bit planes.
generate for(b=0;b<4;b=b+1) begin: g_plane
    assign planes[b*8+:8] = {
        rom_data[b+4],rom_data[b],rom_data[b+12],rom_data[b+8],
        rom_data[b+20],rom_data[b+16],rom_data[b+28],rom_data[b+24]
    };
end endgenerate

jtframe_sh #(.W(1),.L(FIX_EN_DLY)) u_fix_en_dly(
    .clk             ( clk                                  ),
    .clk_en          ( pxl_cen                              ),
    .din             ( fix_en_pre                           ),
    .drop            ( fix_en                               )
);
jtframe_sh #(.W(1),.L(FIX_EN_DLY)) u_fix_src_dly(
    .clk             ( clk                                  ),
    .clk_en          ( pxl_cen                              ),
    .din             ( fix_src_pre                          ),
    .drop            ( fix_src                              )
);

jtframe_tilemap #(
    .SIZE            ( 8                                    ),
    .VA              ( 10                                   ),
    .CW              ( 9                                    ),
    .PW              ( 8                                    ),
    .VR              ( 12                                   ),
    .MAP_HW          ( 8                                    ),
    .MAP_VW          ( 8                                    ),
    .HDUMPW          ( 8                                    ),
    .VDUMPW          ( 8                                    ),
    .FLIP_HDUMP      ( 0                                    ),
    .FLIP_VDUMP      ( 0                                    ),
    .HJUMP           ( 1                                    ),
    .HDUMP_OFFSET    ( -4                                   )
) u_tilemap(
    .rst             ( rst                                  ),
    .clk             ( clk                                  ),
    .pxl_cen         ( pxl_cen                              ),
    .hdump           ( tile_h                               ),
    .vdump           ( tile_v                               ),
    .blankn          ( 1'b1                                 ),
    .flip            ( 1'b0                                 ),
    .vram_addr       ( map_addr                             ),
    .code            ( {cram[7],vram}                       ),
    .pal             ( cram[3:0]                            ),
    .hflip           ( cram[6]^flip                         ),
    .vflip           ( cram[5]                              ),
    .rom_addr        ( rom_addr                             ),
    .rom_cs          ( rom_cs                               ),
    .rom_data        ( planes                               ),
    .rom_ok          ( rom_ok                               ),
    .pxl             ( raw_pxl                              )
);

jtframe_prom #(.DW(4),.AW(8)) u_palette(
    .clk             ( clk                                  ),
    .cen             ( pxl_cen                              ),
    .data            ( prog_data                            ),
    .wr_addr         ( prog_addr                            ),
    .we              ( prog_en                              ),
    .rd_addr         ( raw_pxl                              ),
    .q               ( pxl                                  )
);
endmodule
