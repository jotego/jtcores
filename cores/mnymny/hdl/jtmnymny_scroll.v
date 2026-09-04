/*  jtmnymny_scroll.v — 1B11140 background layer
    Thin shim around jtframe_scroll (COL_SCROLL): resolves the 8-bit tile RAM
    (code + attribute byte) and the attribute RAM (column scroll + colour)
    within each 8-pixel window. GPL3 — see jtcores LICENSE
*/

module jtmnymny_scroll(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               hs,
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

wire [ 9:0] va;
reg  [ 7:0] code_lo, vattr, colattr, scry;
wire [ 9:0] code = { vattr[1:0], code_lo };
wire [ 4:0] pal  = { colattr[2:0], vattr[3:2] };
// visible window is V[7:0]=16..239 (5P VBLANK latch), so vdump maps directly
wire [ 4:0] col     = va[4:0];
wire [ 4:0] col_nx  = va[4:0] + ( flip ? 5'd31 : 5'd1 );

// resolve code/pal during the 8-pixel window
always @(posedge clk) if(pxl_cen) begin
    case( hdump[2:0] )
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
        3'd6: scry     <= attr_data;
        default:;
    endcase
end

jtframe_scroll #(
    .SIZE       (  8 ),
    .VA         ( 10 ),
    .CW         ( 10 ),
    .PW         (  9 ),
    .MAP_HW     (  8 ),
    .MAP_VW     (  8 ),
    .HJUMP      (  0 ),
    // hw prefetches during the last blank clocks (H 240-255 = hdump 368-383)
    .HLOOP      ( 368 ),
    .COL_SCROLL (  1 )
) u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .blankn     ( blankn    ),
    .flip       ( flip      ),
    // fetch leads the display by one 8-pixel group (cab shows col0 first, col31 last)
    .scrx       ( 8'd8      ),
    .scry       ( scry      ),
    .vram_addr  ( va        ),
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
