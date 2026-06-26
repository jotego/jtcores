//============================================================================
//  jtddribble_scroll.v — 005885 tilemap layer (E3/A3).
//
//  jtframe_scroll tile renderer. 005885 gfx is 8x8x4 PIXEL-PACKED, so the 32-bit
//  ROM word is run through jtframe_8x8x4_packed_msb to make the PLANAR word
//  jtframe_scroll expects.
//
//  Tile code:
//    FG (LAYER_BG=0): {1'b0, tile_ctrl[1], attr[5], attr[7:6], code}
//    BG (LAYER_BG=1): {tile_ctrl[1:0],      attr[5], attr[7:6], code}
//  hflip=attr[4], vflip=attr[5].
//
//  Author: Andrea Bogazzi <andreabogazzi79@gmail.com>   GPL3 (see jtcores LICENSE)
//============================================================================

module jtddribble_scroll #(
    parameter LAYER_BG = 0
)(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               hs,
    input               blankn,
    input               flip,
    input      [ 8:0]   vdump,
    input      [ 8:0]   hdump,

    input      [ 8:0]   scrx,        // {scroll_ctrl[0], scroll_x}
    input      [ 7:0]   scry,        // scroll_y
    input      [ 1:0]   tile_hi,     // FG: {1'b0,tile_ctrl[1]} | BG: tile_ctrl[1:0]

    output     [12:0]   vram_addr,
    input      [ 7:0]   vram_dout,

    output              rom_cs,
    output     [15:0]   rom_addr,    // {code[12:0], vrow[2:0]} -> 32-bit word
    input      [31:0]   rom_data,
    input               rom_ok,

    output     [ 4:0]   pxl          // COL[4:0] contribution to the colmix
);

// packed -> planar. SDRAM is byteswap16(MAME) and the converter wants MAME
// packed_msb, so byteswap each 16-bit half before the transpose.
wire [31:0] raw = { rom_data[23:16], rom_data[31:24], rom_data[7:0], rom_data[15:8] };
wire [31:0] sorted;
jtframe_8x8x4_packed_msb u_packed( raw, sorted );

// ---------------------------------------------------------------------------
// jtframe_scroll <-> 005885 tile fields
// ---------------------------------------------------------------------------
localparam CW = 13;          // tile code width (BG uses all 13; FG top bit = 0)
localparam PW = 9;
localparam VA = 11;          // 005885 tile map (64x32 tiles)
localparam VR = CW+3;        // 8x8 -> code + 3 row bits = 16
localparam [8:0] HOFS = 9'd508; // -4 (was 4): recenters the 8px (1-tile) left shift the
                               // single-pxl_cen plane reader introduced by feeding tile
                               // data ~2 pxl_cen earlier (jtframe_scroll latches at 8px).
localparam [7:0] VOFS = 8'd0;  // vertical centering offset

wire [VA-1:0] sc_vaddr;
wire [CW-1:0] sc_code;
wire [PW-5:0] sc_pal;
wire          sc_hflip, sc_vflip;
wire [VR-1:0] sc_romaddr;

// Plane reader — read ATTR then CODE within ONE pxl_cen (two back-to-back clk reads)
// so attr_l/code_l are fresh for the current tile with no 1-pxl_cen register lag. That
// lag left the first column of each line stale (the previous read's value), which
// fine-scroll exposed as the stray left column. BRAM latency = 1 clk (addr@subN ->
// dout@subN+1); pxl_cen is every 4 clk so both reads finish well inside one pixel.
reg  [ 1:0] rdsub;
reg  [ 7:0] attr_l, code_l;
always @(posedge clk) rdsub <= pxl_cen ? 2'd0 : (rdsub==2'd3 ? 2'd3 : rdsub + 2'd1);
wire        plane = (rdsub != 2'd0);    // sub0 = ATTR (plane 0), sub1.. = CODE (plane 1)
always @(posedge clk) begin
    if (rdsub==2'd1) attr_l <= vram_dout;   // ATTR issued at sub0, dout ready at sub1
    if (rdsub==2'd2) code_l <= vram_dout;   // CODE issued at sub1, dout ready at sub2
end
// 005885 VRAM tile-address layout:
//   {1'b0, h[8], plane(attr/code), v[4:0], h[4:0]}
// sc_vaddr = {veff[7:3]=v[4:0] (bits 10:6), heff[8:3]=h[5:0] (bits 5:0)}.
// h[8]=sc_vaddr[5], v[4:0]=sc_vaddr[10:6], h[4:0]=sc_vaddr[4:0].
assign vram_addr = { 1'b0, sc_vaddr[5], plane, sc_vaddr[10:6], sc_vaddr[4:0] };

assign sc_code  = { tile_hi, attr_l[5], attr_l[7:6], code_l };
assign sc_hflip = attr_l[4];
assign sc_vflip = attr_l[5];
assign sc_pal   = { 1'b0, attr_l[3:0] };  // 005885 tile colour bits (pad to PW-4)

assign rom_addr = sc_romaddr;

wire [PW-1:0] sc_pxl;

jtframe_scroll #(
    .SIZE   ( 8        ),
    .CW     ( CW       ),
    .PW     ( PW       ),
    .VA     ( VA       ),
    .MAP_HW ( 9        ),   // 64 tiles wide -> VA=(8-3)+(9-3)=11 (matches tilemap check)
    .MAP_VW ( 8        ),   // 32 tiles tall
    .HJUMP  ( 0        )
) u_scroll(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .pxl_cen    ( pxl_cen    ),
    .hs         ( hs         ),
    .vdump      ( vdump      ),
    .hdump      ( hdump      ),
    .blankn     ( blankn     ),
    .flip       ( flip       ),
    .scrx       ( scrx + HOFS ),
    .scry       ( scry + VOFS ),
    .vram_addr  ( sc_vaddr   ),
    .code       ( sc_code    ),
    .pal        ( sc_pal     ),
    .hflip      ( sc_hflip   ),
    .vflip      ( sc_vflip   ),
    .rom_addr   ( sc_romaddr ),
    .rom_data   ( sorted     ),
    .rom_cs     ( rom_cs     ),
    .rom_ok     ( rom_ok     ),
    .pxl        ( sc_pxl     )
);

assign pxl = { 1'b1, sc_pxl[3:0] };       // COL[4]=1 (tile), pen[3:0]

endmodule
