#============================================================
# SDIO      (Secondary SD)                 (DE10-nano GPIO 1)
#============================================================
set_location_assignment PIN_K7 -to SDIO_DAT[0]
set_location_assignment PIN_J9 -to SDIO_DAT[1]
set_location_assignment PIN_E7 -to SDIO_DAT[2]
set_location_assignment PIN_K8 -to SDIO_DAT[3]
set_location_assignment PIN_E3 -to SDIO_CMD
set_location_assignment PIN_E6 -to SDIO_CLK
set_instance_assignment -name CURRENT_STRENGTH_NEW "MAXIMUM CURRENT" -to SDIO_*

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDIO_*
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to SDIO_DAT[*]
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to SDIO_CMD

# HSMC J3 connector pin 16 / PMOD3[0];  HSMC_RX _n[4] PIN_K8    SDIO_DAT[3]
# HSMC J3 connector pin 17 / PMOD3[1];  HSMC_TX _p[5] PIN_E3    SDIO_CMD
# HSMC J3 connector pin 18 / PMOD3[2];  HSMC_RX _p[4] PIN_K7    SDIO_DAT[0]
# HSMC J3 connector pin 19 / PMOD3[3];  HSMC_CLKOUT_n1  PIN_E6  SDIO_CLK
# HSMC J3 connector pin 20 / PMOD3[4];  HSMC_RX _n[3] PIN_J9    SDIO_DAT[1]
# HSMC J3 connector pin 21 / PMOD3[5];  HSMC_CLKOUT_p1  PIN_E7  SDIO_DAT[2]
# HSMC J3 connector pin 22 / PMOD3[6];  HSMC_RX _p[3] PIN_J10   -->  SDCD_SPDIF  (sys.tcl)
# HSMC J3 connector pin 23 / PMOD3[7];  HSMC_TX _n[4] PIN_C4    -->  not used

#============================================================
# VGA (SOCKIT BOARD)
#============================================================
set_location_assignment PIN_AG5 -to VGA_R[0]
set_location_assignment PIN_AA12 -to VGA_R[1]
set_location_assignment PIN_AB12 -to VGA_R[2]
set_location_assignment PIN_AF6 -to VGA_R[3]
set_location_assignment PIN_AG6 -to VGA_R[4]
set_location_assignment PIN_AJ2 -to VGA_R[5]
set_location_assignment PIN_AH5 -to VGA_R[6]
set_location_assignment PIN_AJ1 -to VGA_R[7]

set_location_assignment PIN_Y21 -to VGA_G[0]
set_location_assignment PIN_AA25 -to VGA_G[1]
set_location_assignment PIN_AB26 -to VGA_G[2]
set_location_assignment PIN_AB22 -to VGA_G[3]
set_location_assignment PIN_AB23 -to VGA_G[4]
set_location_assignment PIN_AA24 -to VGA_G[5]
set_location_assignment PIN_AB25 -to VGA_G[6]
set_location_assignment PIN_AE27 -to VGA_G[7]

set_location_assignment PIN_AE28 -to VGA_B[0]
set_location_assignment PIN_Y23 -to VGA_B[1]
set_location_assignment PIN_Y24 -to VGA_B[2]
set_location_assignment PIN_AG28 -to VGA_B[3]
set_location_assignment PIN_AF28 -to VGA_B[4]
set_location_assignment PIN_V23 -to VGA_B[5]
set_location_assignment PIN_W24 -to VGA_B[6]
set_location_assignment PIN_AF29 -to VGA_B[7]

set_location_assignment PIN_AD12 -to VGA_HS
set_location_assignment PIN_AC12 -to VGA_VS

set_location_assignment PIN_AG2 -to VGA_SYNC_N
set_location_assignment PIN_AH3 -to VGA_BLANK_N
set_location_assignment PIN_W20 -to VGA_CLK

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to VGA_*
set_instance_assignment -name CURRENT_STRENGTH_NEW 8MA -to VGA_*

#============================================================
# AUDIO DELTA-SIGMA / SPDIF                (DE10-nano GPIO 1)
#============================================================
set_location_assignment PIN_D5  -to AUDIO_L
set_location_assignment PIN_G10 -to AUDIO_R
set_location_assignment PIN_F10 -to AUDIO_SPDIF
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to AUDIO_*
set_instance_assignment -name CURRENT_STRENGTH_NEW 8MA -to AUDIO_*

# HSMC J3 connector pin 24 HSMC_RX _n[2] PIN_F10  AUDIO_SPDIF
# HSMC J3 connector pin 25 HSMC_TX _p[4] PIN_D5   AUDIO_L
# HSMC J3 connector pin 26 HSMC_RX _p[2] PIN_G10  AUDIO_R

#============================================================
# AUDIO CODEC SOCKIT BOARD (I2S)
#============================================================
set_location_assignment PIN_AC27 -to AUD_ADCDAT
set_location_assignment PIN_AG30 -to AUD_ADCLRCK
set_location_assignment PIN_AE7 -to AUD_BCLK
set_location_assignment PIN_AG3 -to AUD_DACDAT
set_location_assignment PIN_AH4 -to AUD_DACLRCK
set_location_assignment PIN_AD26 -to AUD_MUTE
set_location_assignment PIN_AC9 -to AUD_XCK
set_location_assignment PIN_AH30 -to AUD_I2C_SCLK
set_location_assignment PIN_AF30 -to AUD_I2C_SDAT
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to AUD_*

#============================================================
# I/O #1                                   (DE10-nano GPIO 1)
#============================================================
set_location_assignment PIN_D6 -to LED_USER
set_location_assignment PIN_K12 -to LED_HDD
set_location_assignment PIN_F6 -to LED_POWER
# HSMC J3 connector pin 31 HSMC_TX _p[3] PIN_D6   LED_USER
# HSMC J3 connector pin 32 HSMC_RX _p[1] PIN_K12  LED_HDD
# HSMC J3 connector pin 33 HSMC_TX _n[2] PIN_F6   LED_POWER

set_location_assignment PIN_G11 -to BTN_USER
set_location_assignment PIN_G7 -to BTN_OSD
set_location_assignment PIN_AD27 -to BTN_RESET
# HSMC J3 connector pin 34 HSMC_RX _n[0]  PIN_G11   BTN_USER
# HSMC J3 connector pin 35 HSMC_TX _p[2]  PIN_G7    BTN_OSD
# HSMC J3 connector pin 36 HSMC_RX _p[0]  PIN_G12   provision for a future external reset button
# SOCKIT KEY4 button (KEY_RESET_n)        PIN_AD27  BTN_RESET

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LED_*
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to BTN_*
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to BTN_*
