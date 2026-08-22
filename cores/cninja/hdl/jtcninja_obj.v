/*  This file is part of JTCORES. GPLv3. See jtcninja_game.v header.

    Sprite wrapper for the Caveman Ninja hardware family. Both cninja and
    darkseal use the DECO decospr / MXC-06 sprite chip with the SAME word
    format and colour bits; the only gfx difference is the plane-pair order
    (darkseal's seallayout swaps it vs cninja's tilelayout), so this wrapper
    just drives jtcninja_decospr's `pswap` from the game id. The per-game
    palette base + sprite priority live in jtcninja_colmix.
*/
module jtcninja_obj(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             flip,
    input             dseal,           // game_id==2 (darkseal plane order)
    input             cbust,           // game_id==1 (cbuster chunky plane reverse)

    input             HS,
    input             LHBL,
    input             LVBL,
    input      [ 8:0] vrender,
    input      [ 8:0] hdump,

    input             obj_copy,        // DMA-flag write: refresh the display buffer
    output     [ 9:0] oram_addr,
    input      [15:0] oram_dout,
    // buffered_spriteram16 copy: sweeps objram -> oram
    output     [ 9:0] dma_addr,
    output     [ 1:0] dma_we,

    output            rom_cs,
    output     [20:2] rom_addr,
    input      [31:0] rom_data,
    input             rom_ok,

    output     [11:0] pxl
);

// The display buffer is refreshed by sweeping the CPU sprite RAM into it, the
// same jtframe_bram_dma sweep jtkarnov_obj uses. Without it the engine reads
// the list mid-CPU-update and sprites tear in motion.
wire dma_wr;
assign dma_we = {2{dma_wr & pxl_cen}};

jtframe_bram_dma #(.AW(10)) u_dma(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( pxl_cen   ),          // cen cannot be 1'b1
    .addr   ( dma_addr  ),
    .start  ( obj_copy  ),
    .we     ( dma_wr    )
);

jtcninja_decospr u_spr(
    .rst      ( rst      ),
    .clk      ( clk      ),
    .pxl_cen  ( pxl_cen  ),
    .flip     ( flip     ),
    // Only darkseal's seallayout swaps the plane order. cninja and cbuster both
    // use MAME's tilelayout (dp straight) - cbuster verified at 98% vs screen.png.
    .pswap    ( dseal ),
    .HS       ( HS       ),
    .LHBL     ( LHBL     ),
    .LVBL     ( LVBL     ),
    .vrender  ( vrender  ),
    .hdump    ( hdump    ),
    .oram_addr( oram_addr),
    .oram_dout( oram_dout),
    .rom_cs   ( rom_cs   ),
    .rom_addr ( rom_addr ),
    .rom_data ( rom_data ),
    .rom_ok   ( rom_ok   ),
    .pxl      ( pxl      )
);

endmodule
