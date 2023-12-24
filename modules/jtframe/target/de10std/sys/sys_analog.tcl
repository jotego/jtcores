#============================================================
# SDIO (Secondary SD)                
#============================================================
#set_location_assignment PIN_AF25 -to SDIO_DAT[0]
#set_location_assignment PIN_AF23 -to SDIO_DAT[1]
#set_location_assignment PIN_AD26 -to SDIO_DAT[2]
#set_location_assignment PIN_AF28 -to SDIO_DAT[3]
#set_location_assignment PIN_AF27 -to SDIO_CMD
#set_location_assignment PIN_AH26 -to SDIO_CLK
#set_instance_assignment -name CURRENT_STRENGTH_NEW "MAXIMUM CURRENT" -to SDIO_*

#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDIO_*
#set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to SDIO_DAT[*]
#set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to SDIO_CMD

#============================================================
# VGA (DE10-Standard BOARD)
#============================================================
set_location_assignment PIN_AK29 -to VGA_R[0]
set_location_assignment PIN_AK28 -to VGA_R[1]
set_location_assignment PIN_AK27 -to VGA_R[2]
set_location_assignment PIN_AJ27 -to VGA_R[3]
set_location_assignment PIN_AH27 -to VGA_R[4]
set_location_assignment PIN_AF26 -to VGA_R[5]
set_location_assignment PIN_AG26 -to VGA_R[6]
set_location_assignment PIN_AJ26 -to VGA_R[7]

set_location_assignment PIN_AK26 -to VGA_G[0]
set_location_assignment PIN_AJ25 -to VGA_G[1]
set_location_assignment PIN_AH25 -to VGA_G[2]
set_location_assignment PIN_AK24 -to VGA_G[3]
set_location_assignment PIN_AJ24 -to VGA_G[4]
set_location_assignment PIN_AH24 -to VGA_G[5]
set_location_assignment PIN_AK23 -to VGA_G[6]
set_location_assignment PIN_AH23 -to VGA_G[7]

set_location_assignment PIN_AJ21 -to VGA_B[0]
set_location_assignment PIN_AJ20 -to VGA_B[1]
set_location_assignment PIN_AH20 -to VGA_B[2]
set_location_assignment PIN_AJ19 -to VGA_B[3]
set_location_assignment PIN_AH19 -to VGA_B[4]
set_location_assignment PIN_AJ17 -to VGA_B[5]
set_location_assignment PIN_AJ16 -to VGA_B[6]
set_location_assignment PIN_AK16 -to VGA_B[7]

set_location_assignment PIN_AK19 -to VGA_HS
set_location_assignment PIN_AK18 -to VGA_VS

set_location_assignment PIN_AJ22 -to VGA_SYNC_N
set_location_assignment PIN_AK22 -to VGA_BLANK_N
set_location_assignment PIN_AK21 -to VGA_CLK


set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to VGA_*
set_instance_assignment -name CURRENT_STRENGTH_NEW 8MA -to VGA_*

#============================================================
# AUDIO DELTA-SIGMA / SPDIF
#============================================================
#set_location_assignment PIN_D5  -to AUDIO_L
#set_location_assignment PIN_G10 -to AUDIO_R
#set_location_assignment PIN_F10 -to AUDIO_SPDIF
#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to AUDIO_*
#set_instance_assignment -name CURRENT_STRENGTH_NEW 8MA -to AUDIO_*


#============================================================
# AUDIO CODEC (DE10-Standard BOARD) (I2S)
#============================================================
set_location_assignment PIN_AJ29 -to AUD_ADCDAT
set_location_assignment PIN_AH29 -to AUD_ADCLRCK
set_location_assignment PIN_AF30 -to AUD_BCLK
set_location_assignment PIN_AF29 -to AUD_DACDAT
set_location_assignment PIN_AG30 -to AUD_DACLRCK
set_location_assignment PIN_AH30 -to AUD_XCK
set_location_assignment PIN_Y24 -to AUD_I2C_SCLK
set_location_assignment PIN_Y23 -to AUD_I2C_SDAT
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to AUD_*

#============================================================
# I/O #1
#============================================================
#set_location_assignment PIN_AC23 -to LED_USER
#set_location_assignment PIN_AA24 -to LED_HDD
#set_location_assignment PIN_AB23 -to LED_POWER

#set_location_assignment PIN_AK4 -to BTN_USER
#set_location_assignment PIN_AA14 -to BTN_OSD
set_location_assignment PIN_AA15 -to BTN_RESET

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LED_*
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to BTN_*
set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to BTN_*
