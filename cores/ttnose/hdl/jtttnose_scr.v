/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 01-11-2026 */

module jtttnose_scr(
    input             rst, clk, pxl_cen, hs, en, flip,
    input      [8:0]  hdump, vdump,
    input      [1:0]  bank,
    input             pal_bank,
    output     [11:1] ram_addr,
    input      [15:0] ram_data,
    output     [19:2] rom_addr,
    output            rom_cs,
    input      [31:0] rom_data,
    input             rom_ok,
    output     [10:0] pxl
);

wire [31:0] planes;
wire [14:0] code = {bank,ram_data[12:0]};
wire [6:0] pal = {pal_bank ? 3'd7 : 3'd3,1'b0,ram_data[15:13]};
genvar p, x;
generate
    for(p=0;p<4;p=p+1) begin: g_plane
        for(x=0;x<8;x=x+1) begin: g_pixel
            assign planes[p*8+7-x] = rom_data[x*4+p];
        end
    end
endgenerate

jtframe_scroll #(
    .SIZE      ( 8  ),
    .VA        ( 11 ),
    .CW        ( 15 ),
    .PW        ( 11 ),
    .MAP_HW    ( 9  ),
    .MAP_VW    ( 8  ),
    .HJUMP     ( 0  ),
    .FLIP_HW   ( 9  ),
    .FLIP_VW   ( 8  ),
    .XOR_HFLIP ( 1  )
) u_scroll(
    .rst       ( rst                 ),
    .clk       ( clk                 ),
    .pxl_cen   ( pxl_cen             ),
    .hs        ( hs                  ),
    .vdump     ( vdump               ),
    .hdump     ( hdump               ),
    .blankn    ( en                  ),
    .flip      ( flip                ),
    .scrx      ( 9'd0                ),
    .scry      ( flip ? 8'hf8 : 8'd0 ),
    .vram_addr ( ram_addr            ),
    .code      ( code                ),
    .pal       ( pal                 ),
    .hflip     ( 1'b0                ),
    .vflip     ( 1'b0                ),
    .rom_addr  ( rom_addr            ),
    .rom_data  ( planes              ),
    .rom_cs    ( rom_cs              ),
    .rom_ok    ( rom_ok              ),
    .pxl       ( pxl                 )
);

endmodule
