create_clock -name {clk_50} -period 20.000 -waveform {0.000 10.000} { MAX10_CLK1_50 }
create_generated_clock -name spiclk -source [get_ports {MAX10_CLK1_50}] -divide_by 16 [get_registers {substitute_mcu:controller|spi_controller:spi|sck}]

set hostclk { clk_50 }
set supportclk { clk_50 }

derive_pll_clocks -create_base_clocks
derive_clock_uncertainty

# Create a clock for i2s, audio-spi, i2c-hdmi
create_clock -name i2sclk -period 640.000 {audio_top:audio_i2s|tcount[4]}
create_clock -name audio-spi-clk-1m -period 2480.000  {AUDIO_SPI_CTL_RD:AUDIO_SPI_CTL_RD_inst|CLK_1M}
create_clock -name audio-spi-rom-ck -period 2480.000  {AUDIO_SPI_CTL_RD:AUDIO_SPI_CTL_RD_inst|ROM_CK}
#create_clock -name i2c-ctrl-clk -period 100000.000  {I2C_HDMI_Config:I2C_HDMI_Config_inst|mI2C_CTRL_CLK}


# Set pin definitions for downstream constraints
set RAM_CLK DRAM_CLK
set RAM_OUT {DRAM_DQ* DRAM_ADDR* DRAM_BA* DRAM_RAS_N DRAM_CAS_N DRAM_WE_N DRAM_*DQM DRAM_CS_N DRAM_CKE}
set RAM_IN {DRAM_D*}

set VGA_OUT {VGA_R[*] VGA_G[*] VGA_B[*] VGA_HS VGA_VS}

# non timing-critical pins would be in the "FALSE_IN/OUT" collection (IN inputs, OUT outputs)
set FALSE_OUT {LED[*] DETO1_PMOD2_6 DETO2_PMOD2_7 SIGMA_* PS2_* JOYX_SEL_O AUDIO* I2S_* HDMI_I2C* HDMI_LRCLK HDMI_MCLK HDMI_SCLK HDMI_I2S[*] UART_TXD SD_CS_N_O SD_MOSI_O SD_SCLK_O HDMI_TX*}
set FALSE_IN  {KEY[*] SW[*] PS2_* JOY1* AUDIO* HDMI_I2C* HDMI_LRCLK HDMI_MCLK HDMI_SCLK HDMI_I2S[*] EAR UART_RXD SD_MISO_I HDMI_TX_INT}
#the HDMI signals are probably fast enough to worth constraining properly at some point

# JTAG constraints for debug interface (if enabled)
#create_clock -name {altera_reserved_tck} -period 40 {altera_reserved_tck}
set_input_delay -clock altera_reserved_tck -clock_fall 3 altera_reserved_tdi
set_input_delay -clock altera_reserved_tck -clock_fall 3 altera_reserved_tms
set_output_delay -clock altera_reserved_tck 3 altera_reserved_tdo

set topmodule guest|
