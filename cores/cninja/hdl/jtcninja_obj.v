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

    output     [ 9:0] oram_addr,
    input      [15:0] oram_dout,

    output            rom_cs,
    output     [20:2] rom_addr,
    input      [31:0] rom_data,
    input             rom_ok,

    output     [11:0] pxl
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
