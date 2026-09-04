/*  jtmnymny_scroll.v — 1B11140 background layer
    Schematic-exact column scroll around jtframe_tilemap: the row sum
    (V + column scroll, 1G/1H LS283) is latched once per 8-pixel group
    (1F LS374, /VPL from dumped 6K) and addresses both the tile RAM row
    and the ROM line. GPL3 — see jtcores LICENSE
*/

module jtmnymny_scroll(
    input               rst,
    input               clk,
    input               pxl_cen,
    input       [ 8:0]  hdump,
    input       [ 8:0]  vdump,
    input               blankn,
    input               flip,
    // attribute RAM (col scroll + col colour)
    output reg  [ 5:0]  attr_addr,
    input       [ 7:0]  attr_data,
    // tile RAM
    output reg  [10:0]  vram_addr,
    input       [ 7:0]  vram_data,
    // GFX ROM (SDRAM, 3 planes + padding in one word)
    output      [12:0]  rom_addr,
    output              rom_cs,
    input       [31:0]  rom_data,
    input               rom_ok,
    // pixel out: { pal[4:0], pix[3:0] }
    output      [ 8:0]  pxl
);

localparam [8:0] HLOOP = 9'd360;
localparam [7:0] SCRX  = 8'd16;  // fetch leads display: LS194 load + window

reg  [ 7:0] code_lo, vattr, colattr, vsum;
wire [ 9:0] code = { vattr[1:0], code_lo };
wire [ 4:0] pal  = { colattr[2:0], vattr[3:2] };
wire [ 7:0] hdfix, heff;
wire [ 9:0] va;
// visible window is V[7:0]=16..239 (5P VBLANK latch), so vdump maps directly
wire [ 4:0] col     = va[4:0];
wire [ 4:0] col_nx  = va[4:0] + ( flip ? 5'd31 : 5'd1 );

assign hdfix = hdump>HLOOP ? {1'b1, hdump[6:0]} : hdump[7:0];
assign heff  = (hdfix ^ {8{flip}}) + SCRX;
assign va    = { vsum[7:3], heff[7:3] };

// fetch sequence within the 8-pixel window. vsum latches at phase 0, the
// same pxl_cen edge where u_tilemap samples vsum[2:0] for the previous
// group's tile: it reads the old value, as the 1F latch does
always @(posedge clk) if(pxl_cen) begin
    case( hdump[2:0] )
        3'd0: vsum      <= (vdump[7:0]^{8{flip}}) + attr_data;
        3'd1: vram_addr <= { 1'b0, va };
        3'd2: begin
            code_lo   <= vram_data;
            vram_addr <= { 1'b1, va };
        end
        3'd3: begin
            vattr     <= vram_data;
            attr_addr <= { col, 1'b1 };       // column colour
        end
        3'd4: colattr  <= attr_data;
        3'd5: attr_addr<= { col_nx, 1'b0 };   // next column scroll
        default:;
    endcase
end

jtframe_tilemap #(
    .SIZE       (  8 ),
    .VA         ( 10 ),
    .CW         ( 10 ),
    .PW         (  9 ),
    .MAP_HW     (  8 ),
    .MAP_VW     (  8 ),
    .HDUMPW     (  8 ),
    .VDUMPW     (  8 ),
    .FLIP_HDUMP (  0 ),
    .FLIP_VDUMP (  0 ),
    .FLIP_MSB   (  0 ),
    .HJUMP      (  0 )
) u_tilemap(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vsum      ),
    .hdump      ( heff      ),
    .blankn     ( blankn    ),
    .flip       ( flip      ),
    .vram_addr  (           ),
    .code       ( code      ),
    .pal        ( pal       ),
    .hflip      ( 1'b0      ),
    .vflip      ( 1'b0      ),
    .rom_addr   ( rom_addr  ),
    .rom_data   ( rom_data  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .pxl        ( pxl       )
);

endmodule
