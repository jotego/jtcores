/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-8-2023 */

// Based on Skutis' RE work on die shots
// and MAME documentation

// 16 kB external RAM holding 76 sprites, 16 bytes each
// but separated $50 (80 bytes) from each other
// $3000 (3/4) of the RAM contain the data
// the latter $1000 keeps a prioritized copy in packets of 8 bytes
// or max $200 objects (512) in total
// but the priority seem to be encoded in one byte, so
// max objects is $100 = 256

// DMA clear phase lasts for 2 lines
// DMA copying takes 6.41 lines after DMA clear
// that's 400.625us -> 2461 pxl
// that's about 4 pxl/read -> 32 pxl/sprite

// the RAM is copied during the first x lines of VBLANK
// the process is only done if the sprite logic is enabled
// and it gets halted while the CPU tries to write to the memory
// only active sprites (bit 7 of byte 0 set) are copied

// sprite tiles are 16x16x4

module jt00778x#(parameter CW=17,PW=10)(    // sprite logic
    input             rst,
    input             clk,
    input             pxl_cen,

    // DMA memory
    output     [13:1] oram_addr,
    input      [15:0] oram_dout,
    output     [15:0] oram_din,
    output            oram_we,
    // control
    input             dma_on,
    output            dma_bsy,
    input      [ 8:0] vdump,    // generated internally.
                                // Hdump goes from 20 to 19F, 384 pixels
                                // Vdump goes from F8 to 1FF, 264 lines
    input             vs,
    input             hs,
    input             lvbl,
    input    [PW-1:0] obj_dx, obj_dy,
    input             gvflip,

    // draw module
    output   [CW-1:0] code,
    output     [ 3:0] attr,
    output            hflip,
    output   [PW-1:0] hpos,
    output     [ 1:0] hsize,
    output            dr_start,
    input             dr_busy,

    input      [ 7:0] debug_bus
    // output reg [ 7:0] st_dout
);

wire   [15:0] scan_dout;
wire   [13:1] dma_addr, copy_addr;
wire   [10:1] scan_addr;
wire          objbufinit, copy_bsy;

localparam NOLUTFB=`ifdef NOLUTFB 1 `else 0 `endif;

// NOLUTFB -> bypass LUT framebuffer for FPGAs with scarce BRAM
`ifndef NOLUTFB
// full operation
assign oram_addr = copy_bsy ? copy_addr :
                    dma_bsy ? dma_addr  :
                              {3'b110, scan_addr};
`else
// skip LUT
assign oram_addr = {3'b110, scan_addr};
`endif
// original equation from schematics, it is the same as the start of vblank
assign objbufinit = ~|{ (~&vdump[7:5] | ~&{vdump[4],~vdump[3]}), vdump[2:1] };

jt00778x_dma #(.PW(PW)) u_dma(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .objbufinit ( objbufinit    ),
    .lvbl       ( lvbl          ),

    .dma_on     ( dma_on        ),
    .dma_bsy    ( dma_bsy       ),
    .obj_dx     ( obj_dx        ),
    .obj_dy     ( obj_dy        ),

    .oram_addr  ( dma_addr      ),
    .oram_dout  ( oram_dout     ),
    .oram_din   ( oram_din      ),
    .oram_we    ( oram_we       )
);


`ifndef NOLUTFB
wire        copy_we;
wire [15:0] copy_din;
wire        lut_we   = copy_bsy ? copy_we         : oram_we;
wire [10:1] lut_addr = copy_bsy ? copy_addr[10:1] : dma_addr[10:1];
wire [15:0] lut_din  = copy_bsy ? copy_din        : oram_din;

jt00778x_copy_lut u_copy_lut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .objbufinit ( objbufinit    ),
    .dma_on     ( dma_on        ),
    .dma_bsy    ( copy_bsy      ),

    .oram_addr  ( copy_addr     ),
    .oram_dout  ( oram_dout     ),
    .oram_din   ( copy_din      ),
    .oram_we    ( copy_we       )
);

jt00778x_lut_buf#(.PW(PW)) u_lut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .objbufinit ( objbufinit    ),

    .lut_addr   ( lut_addr      ),
    .lut_din    ( lut_din       ),
    .lut_we     ( lut_we        ),

    .scan_addr  ( scan_addr     ),
    .scan_dout  ( scan_dout     )
);
`else
    assign scan_dout = oram_dout;
`endif

jt00778x_scan#(.PW(PW),.CW(CW)) u_scan(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( hs            ),
    .vdump      ( vdump         ),

    .gvflip     ( gvflip        ),

    .scan_addr  ( scan_addr     ),
    .scan_dout  ( scan_dout     ),

    // draw module
    .code       ( code          ),
    .attr       ( attr          ),
    .hflip      ( hflip         ),
    .hpos       ( hpos          ),
    .hsize      ( hsize         ),
    .dr_start   ( dr_start      ),
    .dr_busy    ( dr_busy       )
);

endmodule
