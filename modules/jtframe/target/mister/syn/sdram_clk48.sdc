# The standard PLL exposes the shifted 48 MHz clock as general[1].
# A reconfigurable game PLL is implemented as a Cyclone-V fPLL instead;
# its duplicated output is merged with counter[0].
# With JTFRAME_180SHIFT the pin is driven by an altddio_out cell from clk_rom,
# general[0], with its data inputs set to invert the clock. general[1] is then
# unused and optimised away, and the pin is general[0] shifted by 180 degrees.
set sdram_clk_src [get_pins {emu|pll|pll_inst|altera_pll_i|cyclonev_pll|counter[0].output_counter|divclk}]
if { [get_collection_size $sdram_clk_src] == 0 } {
    set sdram_clk_src [get_pins {emu|pll|pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}]
    if { [get_collection_size $sdram_clk_src] == 0 } {
        set sdram_clk_src [get_pins {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}]
        create_generated_clock -name SDRAM_CLK -source $sdram_clk_src -divide_by 1 -phase 180 [get_ports SDRAM_CLK]
    } else {
        create_generated_clock -name SDRAM_CLK -source $sdram_clk_src -divide_by 1 [get_ports SDRAM_CLK]
    }
} else {
    create_generated_clock -name SDRAM_CLK -source $sdram_clk_src -divide_by 1 -phase 180 [get_ports SDRAM_CLK]
}
