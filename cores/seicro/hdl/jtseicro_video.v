/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 15-10-2026 */

module jtseicro_video(
    input             rst, clk, pxl_cen, flip,
    output            HS, VS, LHBL, LVBL,
    output            cpu_lvbl,
    output      [8:0] video_h,
    output      [9:0] tile_vram_addr,
    output      [8:0] tile_color_addr,
    input       [7:0] tile_vram_data, tile_color_data,
    output      [4:0] scroll_video_addr,
    input       [7:0] scroll_video_data,
    output      [6:0] obj_ram0_addr,
    output      [4:0] obj_ram1_addr,
    input       [7:0] obj_ram0_data, obj_ram1_data,
    output     [13:1] scr_addr, obj_addr,
    output            scr_cs, obj_cs,
    input      [15:0] scr_data, obj_data,
    input             scr_ok, obj_ok,
    output      [5:0] proms_addr,
    input       [7:0] proms_data,
    output      [3:0] red, green, blue,
    input       [3:0] gfx_en
);

wire [8:0] hdump, vdump, vrender;
wire [8:0] tile_h = hdump+(hdump[8] ? 9'd128 : 9'd0)+9'd9;
wire [7:0] scroll_prefetch = tile_h[7:0]+8'd1;
wire [11:0] tile_addr;
wire [31:0] scr_planes;
wire [7:0] scr_pxl, obj_pxl;
wire hblankn;

assign video_h = hdump[8] ? hdump-9'd128 : hdump+9'd256;
assign tile_color_addr = {tile_vram_addr[9:6],tile_vram_addr[4:0]};
assign scroll_video_addr = scroll_prefetch[7:3]^{5{flip}};
assign scr_addr = {1'b0,tile_addr};
assign scr_planes = {16'd0,scr_data[7:4],scr_data[15:12],
                    scr_data[3:0],scr_data[11:8]};

jtframe_vtimer #(
    .HB_START ( 9'd255 ),
    .HB_END   ( 9'd383 ),
    .HCNT_END ( 9'd383 ),
    .HS_START ( 9'd288 ),
    .HS_END   ( 9'd320 ),
    .VB_START ( 9'd239 ),
    .VB_END   ( 9'd15  ),
    .VCNT_END ( 9'd263 ),
    .VS_START ( 9'd248 ),
    .VS_END   ( 9'd251 )
) u_timer(
    .clk      ( clk      ),
    .pxl_cen  ( pxl_cen  ),
    .vdump    ( vdump    ),
    .vrender  ( vrender  ),
    .vrender1 (          ),
    .H        ( hdump    ),
    .Hinit    (          ),
    .Vinit    (          ),
    .LHBL     ( hblankn  ),
    .LVBL     ( cpu_lvbl ),
    .HS       ( HS       ),
    .VS       ( VS       )
);

jtframe_scroll #(
    .SIZE       ( 8  ),
    .VA         ( 10 ),
    .CW         ( 9  ),
    .PW         ( 8  ),
    .MAP_HW     ( 8  ),
    .MAP_VW     ( 8  ),
    .COL_SCROLL ( 1  ),
    .HJUMP      ( 0  ),
    .XOR_HFLIP  ( 1  ),
    .XOR_VFLIP  ( 0  )
) u_scroll(
    .rst       ( rst                                 ),
    .clk       ( clk                                 ),
    .pxl_cen   ( pxl_cen                             ),
    .hs        ( HS                                  ),
    .hdump     ( tile_h                              ),
    .vdump     ( vdump                               ),
    .blankn    ( 1'b1                                ),
    .flip      ( flip                                ),
    .scrx      ( 8'd0                                ),
    .scry      ( scroll_video_data                   ),
    .vram_addr ( tile_vram_addr                      ),
    .code      ( {tile_color_data[4],tile_vram_data} ),
    .pal       ( tile_color_data[3:0]                ),
    .hflip     ( tile_color_data[6]                  ),
    .vflip     ( tile_color_data[7]                  ),
    .rom_addr  ( tile_addr                           ),
    .rom_data  ( scr_planes                          ),
    .rom_cs    ( scr_cs                              ),
    .rom_ok    ( scr_ok                              ),
    .pxl       ( scr_pxl                             )
);

jtseicro_obj u_obj(
    .rst       ( rst           ),
    .clk       ( clk           ),
    .pxl_cen   ( pxl_cen       ),
    .HS        ( HS            ),
    .flip      ( flip          ),
    .hdump     ( hdump         ),
    .vrender   ( vrender       ),
    .ram0_addr ( obj_ram0_addr ),
    .ram1_addr ( obj_ram1_addr ),
    .ram0_data ( obj_ram0_data ),
    .ram1_data ( obj_ram1_data ),
    .rom_addr  ( obj_addr      ),
    .rom_cs    ( obj_cs        ),
    .rom_data  ( obj_data      ),
    .rom_ok    ( obj_ok        ),
    .pxl       ( obj_pxl       )
);

jtseicro_colmix u_colmix(
    .clk      ( clk        ),
    .pxl_cen  ( pxl_cen    ),
    .hblankn  ( hblankn    ),
    .vblankn  ( cpu_lvbl   ),
    .scr_pxl  ( scr_pxl    ),
    .obj_pxl  ( obj_pxl    ),
    .gfx_en   ( gfx_en     ),
    .pal_addr ( proms_addr ),
    .pal_data ( proms_data ),
    .red      ( red        ),
    .green    ( green      ),
    .blue     ( blue       ),
    .LHBL     ( LHBL       ),
    .LVBL     ( LVBL       )
);

endmodule
