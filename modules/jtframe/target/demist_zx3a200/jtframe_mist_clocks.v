/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 22-2-2019 */

module jtframe_mist_clocks(
    input   clk_ext,    // 27MHz for MiST, 50MHz for Neptuno

    // PLL outputs
    output  clk96,
    output  clk48,
    output  clk24,
    output  clk6,
    output  pll_locked,

    // System clocks
    output  clk_sys,
    output  clk_rom,
    output  SDRAM_CLK,

    // reset signals
    input   game_rst,
    output  rst96,
    output  rst48,
    output  rst24,
    output  rst6
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

// TODO to be added pll 8 MHz for Turbo Chameleon 64 V1 
// C10LP-RefKit has a 25Mhz and 12Mhz clock

assign clk27 = clk_ext;
assign pll0_lock = 1;


`ifdef VIVADO
`JTFRAME_PLL u_basepll (			// Xilinx PLL
	// Clock in ports
	.clk_in1(clk27),                // input  clk_in1
	// Clock out ports
	.clk_out1(pll_base),                 
	// Status and control signals
	.reset(1'b0),                   // input reset
	.locked(pll2_lock)              // output locked
);

`else
`JTFRAME_PLL u_basepll(
    .inclk0 ( clk27     ),
    .c0     ( pll_base  ),
    .locked ( pll2_lock )
);
`endif



// clk_rom is used for SDRAM access
// clk_sys is for video
// clk96, clk24 and clk6 inputs to the core can be enabled via macros

`ifdef VIVADO
`JTFRAME_GAMEPLL u_pll_game	(	// Xilinx PLL
	// Clock in ports
	.clk_in1(pll_base),         // input  clk_in1
	// Clock out ports
	.clk_out1(clk96),        
	.clk_out2(clk48),    
	.clk_out3(SDRAM_CLK),
	.clk_out4(clk24),
	.clk_out5(clk6),
	// Status and control signals
	.reset(1'b0),              // input reset
	.locked(pll1_lock)         // output locked
);
`else
`JTFRAME_GAMEPLL u_pll_game (
    .inclk0 ( pll_base    ),
    .c0     ( clk96       ),
    .c1     ( clk48       ), // 48 MHz
    .c2     ( SDRAM_CLK   ), // 96 or 48 MHz shifted
    .c3     ( clk24       ),
    .c4     ( clk6        ),
    .locked ( pll1_lock   )
);
`endif

`ifdef JTFRAME_SDRAM96
    assign clk_rom = clk96;
`else
    assign clk_rom = clk48;
`endif
`ifdef JTFRAME_CLK96
    assign clk_sys   = clk96; // it is possible to use clk48 instead but
        // video mixer doesn't work well in HQ mode
`else
    assign clk_sys   = clk_rom;
`endif

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

jtframe_rst_sync u_reset6(
    .rst        ( game_rst ),
    .clk        ( clk6     ),
    .rst_sync   ( rst6     )
);


endmodule
