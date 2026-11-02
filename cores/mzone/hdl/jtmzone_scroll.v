/* SPDX-FileCopyrightText: 2026 Ulf Skutnabba
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-10-2026 */

// JTFRAME helper comparison and retained PCB timing: doc/renderers.md.

module jtmzone_scroll(
    input              rst,
    input              clk,
    input              pxl_cen,
    input              HS,

    output     [ 9:0]  ram_addr,
    input      [ 7:0]  vram,
    input      [ 7:0]  cram,

    input      [ 8:0]  hdump,
    input      [ 8:0]  vdump,
    input      [ 7:0]  scrollx,
    input      [ 7:0]  scrolly,
    input              flip,

    input      [ 3:0]  prog_data,
    input      [ 7:0]  prog_addr,
    input              prog_en,

    output     [11:0]  rom_addr,
    output             rom_cs,
    input      [31:0]  rom_data,
    input              rom_ok,

    output     [ 3:0]  pxl
`ifdef MZONE_FETCH_DIAG
    ,output            fetch_late
`endif
);

// Sign-extend the PCB horizontal count through blanking, then align the
// native scroll pipeline. The helper applies global flip and scroll offsets.
wire [ 8:0]  hbase = hdump<9'd288 ? hdump : hdump-9'd384;
wire [ 8:0]  tile_h = hbase+9'd4-(flip ? 9'd0 : 9'd32);
wire [ 7:0]  vsum = vdump[8] ? vdump[7:0]-8'd8 : vdump[7:0];
wire [31:0]  planes;
wire [ 7:0]  raw_pxl;
genvar b;

`ifdef MZONE_FETCH_DIAG
wire [ 7:0]  heff = (tile_h[7:0] ^ {8{flip}})+scrolly;
reg          last_phase;
always @(posedge clk) if(pxl_cen) last_phase <= heff[3];
// Native tilemap policy: a missing word at the load boundary becomes zero.
assign fetch_late = !rst && pxl_cen && heff[3]!=last_phase && !rom_ok;
`endif

// Convert the PCB paired-nibble ROM format into JTFRAME bit planes.
generate for(b=0;b<4;b=b+1) begin: g_plane
    assign planes[b*8+:8] = {
        rom_data[b+4],rom_data[b],rom_data[b+12],rom_data[b+8],
        rom_data[b+20],rom_data[b+16],rom_data[b+28],rom_data[b+24]
    };
end endgenerate

jtframe_scroll #(
    .SIZE            ( 8                                    ),
    .VA              ( 10                                   ),
    .CW              ( 9                                    ),
    .PW              ( 8                                    ),
    .VR              ( 12                                   ),
    .MAP_HW          ( 8                                    ),
    .MAP_VW          ( 8                                    ),
    .FLIP_HW         ( 8                                    ),
    .FLIP_VW         ( 8                                    ),
    .HJUMP           ( 1                                    )
) u_scroll(
    .rst             ( rst                                  ),
    .clk             ( clk                                  ),
    .pxl_cen         ( pxl_cen                              ),
    .hs              ( HS                                   ),
    .hdump           ( tile_h                               ),
    .vdump           ( {1'b0,vsum}                          ),
    .blankn          ( 1'b1                                 ),
    .flip            ( flip                                 ),
    // Register names follow the vertically oriented PCB axes.
    .scrx            ( scrolly                              ),
    .scry            ( scrollx                              ),
    .vram_addr       ( ram_addr                             ),
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
