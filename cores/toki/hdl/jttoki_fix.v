module jttoki_fix(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             cabal,

    input       [8:0] hdump,
    input       [8:0] vdump,
    input             blankn,

    output     [10:1] ram_addr,
    input      [15:0] ram_out,

    input      [15:0] gfx_data,
    input             gfx_ok,
    output     [15:1] gfx_addr,
    output            gfx_cs,

    input      [15:0] gfx_hi_data,
    input             gfx_hi_ok,
    output     [15:1] gfx_hi_addr,
    output            gfx_hi_cs,

    output      [7:0] pxl
);

wire [31:0] toki_sorted;
wire [31:0] cabal_sorted, tile_data;
wire [ 9:0] tile_pxl;
wire [ 7:0] toki_pxl, cabal_pxl;
wire [11:0] code = cabal ? {2'b00, ram_out[9:0]} : ram_out[11:0];
wire [ 5:0] pal  = cabal ? ram_out[15:10] : {2'b00, ram_out[15:12]};
wire        rom_ok = cabal ? gfx_ok : gfx_ok && gfx_hi_ok;
wire [ 8:0] vdump_adj = vdump - 9'd1;

wire [7:0] plane3 = { gfx_hi_data[ 4], gfx_hi_data[ 5], gfx_hi_data[ 6], gfx_hi_data[ 7],
                      gfx_hi_data[12], gfx_hi_data[13], gfx_hi_data[14], gfx_hi_data[15] };
wire [7:0] plane2 = { gfx_hi_data[ 0], gfx_hi_data[ 1], gfx_hi_data[ 2], gfx_hi_data[ 3],
                      gfx_hi_data[ 8], gfx_hi_data[ 9], gfx_hi_data[10], gfx_hi_data[11] };
wire [7:0] plane1 = { gfx_data[ 4],    gfx_data[ 5],    gfx_data[ 6],    gfx_data[ 7],
                      gfx_data[12],    gfx_data[13],    gfx_data[14],    gfx_data[15] };
wire [7:0] plane0 = { gfx_data[ 0],    gfx_data[ 1],    gfx_data[ 2],    gfx_data[ 3],
                      gfx_data[ 8],    gfx_data[ 9],    gfx_data[10],    gfx_data[11] };

assign toki_sorted = { plane3, plane2, plane1, plane0 };
assign cabal_sorted = { 16'd0, plane1, plane0 };

assign tile_data = cabal ? cabal_sorted : toki_sorted;
assign toki_pxl  = tile_pxl[7:0];
assign cabal_pxl = { tile_pxl[9:4], tile_pxl[1:0] };

assign gfx_hi_addr = gfx_addr;
assign gfx_hi_cs   = cabal ? 1'b0 : gfx_cs;
assign pxl         = cabal ? cabal_pxl : toki_pxl;

jtframe_tilemap #(
    .SIZE         ( 8  ),
    .PW           ( 10 ),
    .BPP          ( 4  ),
    .CW           ( 12 ),
    .VA           ( 10 ),
    .MAP_HW       ( 8  ),
    .MAP_VW       ( 8  ),
    .HJUMP        ( 0  ),
    .HDUMP_OFFSET ( 0  )
) u_tilemap(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .vdump      ( vdump_adj ),
    .hdump      ( hdump     ),
    .blankn     ( 1'b1      ),
    .flip       ( 1'b0      ),

    .vram_addr  ( ram_addr   ),

    .code       ( code      ),
    .pal        ( pal       ),
    .hflip      ( 1'b0      ),
    .vflip      ( 1'b0      ),

    .rom_addr   ( gfx_addr  ),
    .rom_data   ( tile_data ),
    .rom_cs     ( gfx_cs    ),
    .rom_ok     ( rom_ok    ),

    .pxl        ( tile_pxl  )
);

endmodule
