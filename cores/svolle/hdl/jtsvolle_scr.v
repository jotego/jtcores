/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-10-2026 */

module jtsvolle_scr(
    input             rst, clk, pxl_cen, hs, en,
    input      [8:0]  hdump, vdump, scrx, scry,
    input             code_bank, pal_bank,
    output     [12:1] ram_addr,
    input      [15:0] ram_data,
    output     [18:2] rom_addr,
    output            rom_cs,
    input      [31:0] rom_data,
    input             rom_ok,
    output     [7:0]  pxl
);

wire [11:0] va;
wire [13:0] code = code_bank ? {2'b10,ram_data[11:0]} :
                                             {1'b0,ram_data[12:0]};
wire [31:0] planes;
genvar p, x;
generate
    for(p=0; p<4; p=p+1) begin: g_plane
        for(x=0; x<8; x=x+1) begin: g_pixel
            assign planes[p*8+7-x] = rom_data[x*4+p];
        end
    end
endgenerate

assign ram_addr = {va[5:0],va[11:6]};

jtframe_scroll #(
    .SIZE       ( 8             ),
    .VA         ( 12            ),
    .CW         ( 14            ),
    .PW         ( 8             ),
    .MAP_HW     ( 9             ),
    .MAP_VW     ( 9             ),
    .HJUMP      ( 0             ),
    .HLOOP      ( 0             ),
    .LATCH_SCRX ( 1             )
) u_scroll(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( hs            ),
    .vdump      ( vdump         ),
    .hdump      ( hdump         ),
    .blankn     ( en            ),
    .flip       ( 1'b0          ),
    .scrx       ( scrx          ),
    .scry       ( scry          ),
    .vram_addr  ( va            ),
    .code       ( code          ),
    .pal        ( {pal_bank,ram_data[15:13]} ),
    .hflip      ( 1'b0          ),
    .vflip      ( 1'b0          ),
    .rom_addr   ( rom_addr      ),
    .rom_data   ( planes        ),
    .rom_cs     ( rom_cs        ),
    .rom_ok     ( rom_ok        ),
    .pxl        ( pxl           )
);

endmodule
