#**************************************************************
# Set Input Delay
#**************************************************************

# set_input_delay -clock SPI_SCK -max 6.4 [get_ports SPI_DI[*]]
# set_input_delay -clock SPI_SCK -min 3.2 [get_ports SPI_DI[*]]
# set_input_delay -clock SPI_SCK -max 6.4 [get_ports SPI_SS[*]]
# set_input_delay -clock SPI_SCK -min 3.2 [get_ports SPI_SS[*]]
# set_input_delay -clock SPI_SCK -max 6.4 [get_ports CONF_DATA0]
# set_input_delay -clock SPI_SCK -min 3.2 [get_ports CONF_DATA0]
# 
# 
# set_output_delay -add_delay -max -clock [get_clocks { u_base|clk_gen2|altpll_component|auto_generated|pll1|clk[0] } ]  6.4 [get_ports VGA_R[*]]
# set_output_delay -add_delay -min -clock [get_clocks { u_base|clk_gen2|altpll_component|auto_generated|pll1|clk[0] } ]  3.2 [get_ports VGA_R[*]]
# set_output_delay -add_delay -max -clock [get_clocks { u_base|clk_gen2|altpll_component|auto_generated|pll1|clk[0] } ]  6.4 [get_ports VGA_G[*]]
# set_output_delay -add_delay -min -clock [get_clocks { u_base|clk_gen2|altpll_component|auto_generated|pll1|clk[0] } ]  3.2 [get_ports VGA_G[*]]
# set_output_delay -add_delay -max -clock [get_clocks { u_base|clk_gen2|altpll_component|auto_generated|pll1|clk[0] } ]  6.4 [get_ports VGA_B[*]]
# set_output_delay -add_delay -min -clock [get_clocks { u_base|clk_gen2|altpll_component|auto_generated|pll1|clk[0] } ]  3.2 [get_ports VGA_B[*]]
# set_output_delay -add_delay -max -clock [get_clocks { u_base|clk_gen2|altpll_component|auto_generated|pll1|clk[0] } ]  6.4 [get_ports VGA_HS]
# set_output_delay -add_delay -min -clock [get_clocks { u_base|clk_gen2|altpll_component|auto_generated|pll1|clk[0] } ]  3.2 [get_ports VGA_HS]
# set_output_delay -add_delay -max -clock [get_clocks { u_base|clk_gen2|altpll_component|auto_generated|pll1|clk[0] } ]  6.4 [get_ports VGA_VS]
# set_output_delay -add_delay -min -clock [get_clocks { u_base|clk_gen2|altpll_component|auto_generated|pll1|clk[0] } ]  3.2 [get_ports VGA_VS]
