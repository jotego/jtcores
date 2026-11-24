# autogenerate PLL clock names for use down below
derive_pll_clocks
derive_clock_uncertainty

# The Pocket-specific Cyclone V game PLL drives SDRAM from c0 at 56 MHz.
set jtframe_sdram_pll_out [get_nets -nowarn \
    {u_clocks|u_pll_game|jtframe_pllgame7000_inst|altera_pll_i|outclk_wire[0]}]
if { [get_collection_size $jtframe_sdram_pll_out] != 1 } {
    error "Expected one Pocket PLL7000 SDRAM clock source, found [get_collection_size $jtframe_sdram_pll_out]"
}
create_generated_clock -name dram_clk -source $jtframe_sdram_pll_out \
    -divide_by 1 [get_ports dram_clk]

set jtframe_sdram_pll_clock [get_clocks -nowarn \
    {u_clocks|u_pll_game|jtframe_pllgame7000_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
if { [get_collection_size $jtframe_sdram_pll_clock] != 1 } {
    error "Expected one derived Pocket PLL7000 SDRAM clock, found [get_collection_size $jtframe_sdram_pll_clock]"
}
set_multicycle_path -from [get_clocks {dram_clk}] -to \
    $jtframe_sdram_pll_clock \
    -setup -end 2
set_multicycle_path -from [get_clocks {dram_clk}] -to \
    $jtframe_sdram_pll_clock \
    -hold -end 2
