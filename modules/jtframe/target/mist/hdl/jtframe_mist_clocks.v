/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 22-2-2019 */

module jtframe_mist_clocks(
    input   clk_ext,    // 27MHz for MiST, 50MHz for Neptuno

    // PLL outputs
    output  clk96,
    output  clk48,
    output  clk24,
    output  pll_locked,

    // System clocks
    output  clk_sys,
    output  clk_rom,
    output  SDRAM_CLK,

    // reset signals
    input   game_rst,
    output  rst96,
    output  rst48,
    output  rst24
);

`ifndef JTFRAME_PLL
    `define JTFRAME_PLL jtframe_pll6000
`endif

// The PLL for 96MHz has a different phase shift for the SDRAM clock
// This phase is related to the SDRAM controller configuration set
// in jtframe_board.
`ifdef JTFRAME_SDRAM96
    `define JTFRAME_GAMEPLL jtframe_pllgame96
`else
    `define JTFRAME_GAMEPLL jtframe_pllgame
`endif

wire pll0_lock, pll1_lock, pll2_lock, pll_base, clk27;

assign pll_locked = pll0_lock & pll1_lock & pll2_lock;

`ifdef NEPTUNO
    pll_neptuno u_pllneptuno(
        .inclk0 ( clk_ext   ),
        .c0     ( clk27     ),
        .locked ( pll0_lock )
    );
`elsif POCKET
    pll_pocket u_pllpocket( // converts 74.25 to 27MHz
        .rst     ( 1'b0      ),
        .refclk  ( clk_ext   ),
        .outclk_0( clk27     ),
        .locked  ( pll0_lock )
    );
`else
    assign clk27 = clk_ext;
    assign pll0_lock = 1;
`endif

`JTFRAME_PLL u_basepll(
    .inclk0 ( clk27     ),
    .c0     ( pll_base  ),
    .locked ( pll2_lock )
);

// clk_rom is used for SDRAM access
// clk_sys is for video
// clk96, clk24 inputs to the core can be enabled via macros
`JTFRAME_GAMEPLL u_pll_game (
    .inclk0 ( pll_base    ),
    .c0     ( SDRAM_CLK   ), // 96 or 48 MHz (possibly phase shifted)
    .c1     ( clk48       ), // 48 MHz
    .c2     ( clk96       ),
    .c3     ( clk24       ),
    .c4     (             ),
    .locked ( pll1_lock   )
);

`ifdef JTFRAME_SDRAM96
    assign clk_rom = clk96;
`else
    assign clk_rom = clk48;
`endif
assign clk_sys = clk_rom;

jtframe_rst_sync u_reset96(
    .rst        ( game_rst  ),
    .clk        ( clk96     ),
    .rst_sync   ( rst96     )
);

jtframe_rst_sync u_reset48(
    .rst        ( game_rst  ),
    .clk        ( clk48     ),
    .rst_sync   ( rst48     )
);

jtframe_rst_sync u_reset24(
    .rst        ( game_rst  ),
    .clk        ( clk24     ),
    .rst_sync   ( rst24     )
);

endmodule