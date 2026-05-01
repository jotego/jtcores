module jtargus_video(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             flip,
    input             bg1_en,
    input      [ 9:0] bg0_scrx,
    input      [ 8:0] bg0_scry,
    input      [ 7:0] bg0_vrom,
    input      [ 8:0] bg1_scrx,
    input      [ 8:0] bg1_scry,

    output     [ 9:0] tx_addr,
    input      [15:0] tx_data,
    output     [ 9:0] bg1_addr,
    input      [15:0] bg1_data,

    output     [12:0] objram_addr,
    input      [ 7:0] objram_data,

    output            bg0_cs,
    output     [16:2] bg0_addr,
    input      [31:0] bg0_data,
    input             bg0_ok,

    output            bg1rom_cs,
    output     [14:2] bg1rom_addr,
    input      [31:0] bg1rom_data,
    input             bg1rom_ok,

    output            txt_cs,
    output     [14:2] txt_addr,
    input      [31:0] txt_data,
    input             txt_ok,

    output            obj_cs,
    output     [16:2] obj_addr,
    input      [31:0] obj_data,
    input             obj_ok,

    output     [15:0] vrom_addr,
    input      [ 7:0] vrom_data,
    output            vrom_cs,
    input             vrom_ok,

    output     [ 9:0] pal_pxl,
    input      [11:0] pal_rgb,
    output     [ 9:0] blend_bg_pxl,
    output     [ 9:0] blend_obj_pxl,
    input      [11:0] blend_bg_rgb,
    input      [11:0] blend_obj_rgb,
    input      [ 3:0] blend_alpha,

    output     [ 3:0] red,
    output     [ 3:0] green,
    output     [ 3:0] blue,
    output            LHBL,
    output            LVBL,
    output            HS,
    output            VS,
    output reg        irq8,
    output reg        irq10,

    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus
);

wire [8:0] hdump, vdump, vrender;
wire [8:0] vdump_src   = vdump;
wire [8:0] vrender_src = vrender;
wire       view_flip = flip;
wire [9:0] bg0_scrx_view = bg0_scrx;
wire [8:0] bg0_scry_view = bg0_scry;
wire       blankn = LHBL & LVBL;
wire       tile_fetch = 1'b1;
wire       bg1_fetch = tile_fetch & bg1_en;
wire [7:0] bg0_pxl, bg1_pxl, tx_pxl;
wire [8:0] obj_pxl;

jtframe_vtimer #(
    .VB_START   ( 9'd239 ),
    .VB_END     ( 9'd15  ),
    .VS_START   ( 9'd240 ),
    .VS_END     ( 9'd244 ),
    .VCNT_END   ( 9'd287 ),
    .HB_START   ( 9'd255+9'd10 ),
    .HB_END     ( 9'd9   ),
    .HS_START   ( 9'd300 ),
    .HS_END     ( 9'd327 ),
    .HCNT_END   ( 9'd383 )
) u_timer(
    .clk        ( clk      ),
    .pxl_cen    ( pxl_cen  ),
    .vdump      ( vdump    ),
    .vrender    ( vrender  ),
    .vrender1   (          ),
    .H          ( hdump    ),
    .Hinit      (          ),
    .Vinit      (          ),
    .LHBL       ( LHBL     ),
    .LVBL       ( LVBL     ),
    .HS         ( HS       ),
    .VS         ( VS       )
);

always @(posedge clk) if( pxl_cen ) begin
    irq8  <= hdump==9'd0 && vdump==9'd16;
    irq10 <= hdump==9'd0 && vdump==9'd240;
end

jtargus_bg0 u_bg0(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( HS        ),
    .blankn     ( tile_fetch ),
    .flip       ( view_flip ),
    .vdump      ( vdump_src ),
    .hdump      ( hdump     ),
    .scrx       ( bg0_scrx_view ),
    .scry       ( bg0_scry_view ),
    .vrom_offset( bg0_vrom  ),
    .rom_cs     ( bg0_cs    ),
    .rom_addr   ( bg0_addr  ),
    .rom_data   ( bg0_data  ),
    .rom_ok     ( bg0_ok    ),
    .vrom_addr  ( vrom_addr ),
    .vrom_data  ( vrom_data ),
    .vrom_cs    ( vrom_cs   ),
    .vrom_ok    ( vrom_ok   ),
    .pxl        ( bg0_pxl   )
);

jtargus_scroll #(.CW(8),.TEXT(0)) u_bg1(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .pxl_cen    ( pxl_cen      ),
    .hs         ( HS           ),
    .blankn     ( bg1_fetch    ),
    .flip       ( view_flip    ),
    .vdump      ( vdump_src    ),
    .hdump      ( hdump        ),
    .scrx       ( bg1_scrx     ),
    .scry       ( bg1_scry     ),
    .ram_addr   ( bg1_addr     ),
    .ram_data   ( bg1_data     ),
    .rom_cs     ( bg1rom_cs    ),
    .rom_addr   ( bg1rom_addr ),
    .rom_data   ( bg1rom_data  ),
    .rom_ok     ( bg1rom_ok    ),
    .pxl        ( bg1_pxl      )
);

jtargus_scroll #(.CW(10),.TEXT(1)) u_text(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .pxl_cen    ( pxl_cen      ),
    .hs         ( HS           ),
    .blankn     ( tile_fetch   ),
    .flip       ( view_flip    ),
    .vdump      ( vdump_src    ),
    .hdump      ( hdump        ),
    .scrx       ( 9'd0         ),
    .scry       ( 9'd0         ),
    .ram_addr   ( tx_addr      ),
    .ram_data   ( tx_data      ),
    .rom_cs     ( txt_cs       ),
    .rom_addr   ( txt_addr ),
    .rom_data   ( txt_data     ),
    .rom_ok     ( txt_ok       ),
    .pxl        ( tx_pxl       )
);

jtargus_obj u_obj(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .pxl_cen    ( pxl_cen      ),
    .hs         ( HS           ),
    .blankn     ( blankn       ),
    .flip       ( view_flip    ),
    .hdump      ( hdump        ),
    .vrender    ( vrender_src  ),
    .ram_addr   ( objram_addr  ),
    .ram_data   ( objram_data  ),
    .rom_cs     ( obj_cs       ),
    .rom_addr   ( obj_addr     ),
    .rom_data   ( obj_data     ),
    .rom_ok     ( obj_ok       ),
    .pxl        ( obj_pxl      )
);

jtargus_colmix u_colmix(
    .clk        ( clk      ),
    .pxl_cen    ( pxl_cen  ),
    .blankn     ( blankn   ),
    .bg1_en     ( bg1_en   ),
    .bg0_pxl    ( bg0_pxl  ),
    .bg1_pxl    ( bg1_pxl  ),
    .tx_pxl     ( tx_pxl   ),
    .obj_pxl    ( obj_pxl  ),
    .pal_pxl    ( pal_pxl  ),
    .blend_bg_pxl( blend_bg_pxl ),
    .blend_obj_pxl( blend_obj_pxl ),
    .pal_rgb    ( pal_rgb  ),
    .blend_bg_rgb( blend_bg_rgb ),
    .blend_obj_rgb( blend_obj_rgb ),
    .blend_alpha( blend_alpha ),
    .red        ( red      ),
    .green      ( green    ),
    .blue       ( blue     ),
    .gfx_en     ( gfx_en   )
);

endmodule
