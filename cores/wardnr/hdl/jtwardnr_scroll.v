/* SPDX-FileCopyrightText: 2026 Marc Emmerson / Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Wardner tile layer: CPU scroll registers and the matching tile renderer.
 */
module jtwardnr_scroll #(parameter TEXT=0,
    CW     = TEXT ? 11 : 12,
    VA     = TEXT ? 11 : 12,
    PW     = TEXT ?  9 :  8,
    MAP_VW = TEXT ?  8 :  9,
    ROM_AW = CW + 3
)(
    input                 rst,
    input                 clk,
    input                 pxl_cen,
    input                 hs,
    input      [ 8:0]     hdump,
    input      [ 8:0]     vdump,
    input                 flip,

    input                 cs,
    input      [ 2:0]     addr,
    input      [ 7:0]     din,
    output     [15:0]     offs,

    output     [VA-1:0]   vram_addr,
    input      [15:0]     vram_data,
    output     [ROM_AW-1:0] rom_addr,
    input      [31:0]     rom_data,
    output                rom_cs,
    input                 rom_ok,
    output     [PW-1:0]   pxl
);

localparam [MAP_VW-1:0] Y_FLIP_OFF = 29,
                        Y_NORM_OFF = 30;

wire [15:0] scrx, scry;
wire [ 8:0] scrx_eff;
wire [MAP_VW-1:0] scry_eff;
wire [31:0] rom_data_rev;

assign scrx_eff    = flip ? scrx[8:0] - 9'd67 : scrx[8:0] + 9'd64;
assign scry_eff    = flip ? scry[MAP_VW-1:0] - Y_FLIP_OFF :
                            scry[MAP_VW-1:0] + Y_NORM_OFF;
assign rom_data_rev = TEXT ? {8'd0, rom_data[7:0], rom_data[15:8], rom_data[23:16]} :
                             {rom_data[7:0], rom_data[15:8], rom_data[23:16], rom_data[31:24]};

jtwardnr_scroll_mmr u_mmr(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cs         ( cs        ),
    .addr       ( addr      ),
    .rnw        ( 1'b0      ),
    .din        ( din       ),
    .dout       (           ),
    .scrx       ( scrx      ),
    .scry       ( scry      ),
    .offs       ( offs      ),
    .ioctl_addr ( 3'd0      ),
    .ioctl_din  (           ),
    .debug_bus  ( 8'd0      ),
    .st_dout    (           )
);

jtframe_scroll #(
    .SIZE       ( 8         ),
    .CW         ( CW        ),
    .VA         ( VA        ),
    .PW         ( PW        ),
    .MAP_HW     ( 9         ),
    .MAP_VW     ( MAP_VW    ),
    .FLIP_HW    ( 9         ),
    .FLIP_VW    ( 9         ),
    .HJUMP      ( 1         ),
    .XOR_HFLIP  ( 1         )
) u_scroll(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .pxl_cen    ( pxl_cen           ),
    .hs         ( hs                ),
    .hdump      ( hdump             ),
    .vdump      ( vdump             ),
    .flip       ( flip              ),
    .blankn     ( 1'b1              ),
    .scrx       ( scrx_eff          ),
    .scry       ( scry_eff          ),
    .vram_addr  ( vram_addr         ),
    .code       ( vram_data[CW-1:0] ),
    .pal        ( vram_data[15:CW]  ),
    .hflip      ( 1'b0              ),
    .vflip      ( 1'b0              ),
    .rom_addr   ( rom_addr          ),
    .rom_data   ( rom_data_rev      ),
    .rom_cs     ( rom_cs            ),
    .rom_ok     ( rom_ok            ),
    .pxl        ( pxl               )
);

endmodule
