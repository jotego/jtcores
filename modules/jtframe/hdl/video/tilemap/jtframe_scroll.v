/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 15-12-2022 */


// Generic tile map generator with scroll
// The ROM data must be in these format
// code, H parts, V part
// pixel data is 4bpp, and arrives in four bytes. Each byte is for a plane

module jtframe_scroll #( parameter
    SIZE =  8,    // 8x8, 16x16 or 32x32
    VA   = 12,
    CW   = 12,
    PW   =  8,
    MAP_HW = 9,    // 2^MAP_HW = size of the map in pixels
    MAP_VW = 9,
    VR   = SIZE==8 ? CW+3 : SIZE==16 ? CW+5 : CW+7,
    // override VH and HW only for non rectangular tiles
    VW   = SIZE==8 ? 3 : SIZE==16 ? 4:5,
    HW   = VW,
    ROM_HFLIP = 1,
    XOR_HFLIP = 0, // set to 1 so hflip gets ^ with flip
    XOR_VFLIP = 0, // set to 1 so vflip gets ^ with flip
    HJUMP     = 1, // set to 0 for linear hdump starting at zero after HB
    HLOOP      = 0, // see jtframe_scroll_offset
    COL_SCROLL = 0, // set to 1 to enable 8-pixel column scroll
    LATCH_SCRX = 0, // set to 1 to latch scrx while hs is high
    FLIP_HW    = 8, // hdump bits inverted by flip
    FLIP_VW    = 8  // vdump bits inverted by flip
)(
    input              rst,
    input              clk,
    input              pxl_cen,

    input              hs,

    input        [8:0] vdump,
    input        [8:0] hdump,
    input              blankn,  // if !blankn there are no ROM requests
    input              flip,    // Screen flip
    input [MAP_HW-1:0] scrx,
    input [MAP_VW-1:0] scry,

    output     [VA-1:0]vram_addr,

    input      [CW-1:0]code,
    input      [PW-5:0]pal,
    input              hflip,
    input              vflip,

    output     [VR-1:0]rom_addr,
    input      [31:0]  rom_data,
    output             rom_cs,
    input              rom_ok,      // ignored. It assumes that data is always right

    output     [PW-1:0]pxl
);

// hdump/vdump dimensions can be larger than the screen for the scroll use case
// but the MSBs will be fixed
localparam HDUMPW = MAP_HW, VDUMPW = MAP_VW;

wire [VDUMPW-1:0] veff;
wire [HDUMPW-1:0] heff;

jtframe_scroll_offset #(
    .MAP_HW     ( MAP_HW    ),
    .MAP_VW     ( MAP_VW    ),
    .HDUMPW     ( HDUMPW    ),
    .VDUMPW     ( VDUMPW    ),
    .HLOOP      ( HLOOP      ),
    .COL_SCROLL ( COL_SCROLL ),
    .LATCH_SCRX ( LATCH_SCRX ),
    .FLIP_HW    ( FLIP_HW    ),
    .FLIP_VW    ( FLIP_VW    )
) u_offset(
    .clk        ( clk       ),
    .flip       ( flip      ),
    .scrx       ( scrx      ),
    .scry       ( scry      ),
    .hs         ( hs        ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .heff       ( heff      ),
    .veff       ( veff      )
);

jtframe_tilemap #(
    .SIZE       ( SIZE      ),
    .VA         ( VA        ),
    .CW         ( CW        ),
    .PW         ( PW        ),
    .MAP_HW     ( MAP_HW    ),
    .MAP_VW     ( MAP_VW    ),
    .HDUMPW     ( HDUMPW    ),
    .VDUMPW     ( VDUMPW    ),
    .FLIP_HDUMP ( 0         ), // hdump is already flipped, don't flip it again
    .FLIP_VDUMP ( 0         ), // same for vdump
    .FLIP_MSB   ( 0         ),
    .ROM_HFLIP  ( ROM_HFLIP ),
    .XOR_HFLIP  ( XOR_HFLIP ),
    .XOR_VFLIP  ( XOR_VFLIP ),
    .VW         ( VW        ),
    .HW         ( HW        ),
    .VR         ( VR        ),
    .HJUMP      ( HJUMP     )
)u_tilemap(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .vdump      ( veff      ),
    .hdump      ( heff      ),
    .blankn     ( blankn    ),
    .flip       ( flip      ),

    .vram_addr  ( vram_addr ),

    .code       ( code      ),
    .pal        ( pal       ),
    .hflip      ( hflip     ),
    .vflip      ( vflip     ),

    .rom_addr   ( rom_addr  ),
    .rom_data   ( rom_data  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),

    .pxl        ( pxl       )
);

endmodule
