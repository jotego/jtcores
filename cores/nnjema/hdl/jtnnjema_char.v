/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 8-9-2026 */

// text layer, 8x8, 32x32, column scan
module jtnnjema_char(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             m4_en,
    input             flip,
    input      [ 8:0] hdump,
    input      [ 8:0] vdump,
    input             blankn,

    // VRAM, code in low half, attributes in upper half
    output     [ 9:0] scan_addr,
    input      [ 7:0] code_dout,
    input      [ 7:0] attr_dout,

    output     [14:2] rom_addr,
    output            rom_cs,
    input             rom_ok,
    input      [31:0] rom_data,

    output     [ 7:0] pxl        // {pal[3:0],px[3:0]}
);

wire [ 9:0] vram_addr;
wire [ 9:0] code;
wire [ 3:0] pal;
wire [12:0] pre_addr;
wire [31:0] sorted;

// column scan
assign scan_addr = {vram_addr[4:0],vram_addr[9:5]};
// NB1414M4 parameter bytes are not drawn
assign code = m4_en && scan_addr<10'h12 ? 10'd0 : {attr_dout[1:0],code_dout};
assign pal  = m4_en ? {1'b0,attr_dout[4:2]} : attr_dout[6:3];
assign rom_addr = pre_addr;

// packed 4bpp, lsb nibble = leftmost pixel
genvar i;
generate
    for(i=0;i<8;i=i+1) begin : nibble2plane
        assign sorted[ 7-i] = rom_data[i*4+0];
        assign sorted[15-i] = rom_data[i*4+1];
        assign sorted[23-i] = rom_data[i*4+2];
        assign sorted[31-i] = rom_data[i*4+3];
    end
endgenerate

jtframe_tilemap #(
    .SIZE   (  8 ),
    .VA     ( 10 ),
    .CW     ( 10 ),
    .PW     (  8 ),
    .MAP_HW (  8 ),
    .MAP_VW (  8 ),
    .HJUMP  (  0 ),
    .HDUMP_OFFSET ( -9 )
) u_tilemap(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .blankn     ( blankn    ),
    .flip       ( flip      ),
    .vram_addr  ( vram_addr ),
    .code       ( code      ),
    .pal        ( pal       ),
    .hflip      ( 1'b0      ),
    .vflip      ( 1'b0      ),
    .rom_addr   ( pre_addr  ),
    .rom_data   ( sorted    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .pxl        ( pxl       )
);

endmodule
