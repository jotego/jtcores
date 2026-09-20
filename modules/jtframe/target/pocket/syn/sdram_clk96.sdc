# autogenerate PLL clock names for use down below
derive_pll_clocks
derive_clock_uncertainty

create_generated_clock -name dram_clk -source \
	{u_clocks|u_pll_game|altpll_component|auto_generated|generic_pll1~PLL_OUTPUT_COUNTER|divclk} \
	-divide_by 1 \
	[get_ports dram_clk]

set_multicycle_path -from [get_clocks {dram_clk}] -to [get_clocks {u_clocks|u_pll_game|altpll_component|auto_generated|generic_pll1~PLL_OUTPUT_COUNTER|divclk}] -setup -end 2

set_multicycle_path -from [get_clocks {dram_clk}] -to [get_clocks {u_clocks|u_pll_game|altpll_component|auto_generated|generic_pll1~PLL_OUTPUT_COUNTER|divclk}] -hold -end 2