# autogenerate PLL clock names for use down below
derive_pll_clocks
derive_clock_uncertainty

create_generated_clock -name dram_clk -source \
	[get_nets {u_clocks|u_pll_game|altpll_component|auto_generated|wire_generic_pll1_outclk}] \
	-divide_by 1 \
	[get_ports dram_clk]