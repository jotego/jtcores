project_open adc_test

# Files
set_global_assignment -name QIP_FILE source.qip

# Pins
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LED[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LED[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LED[2]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LED[3]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LED[4]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LED[5]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LED[6]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LED[7]
set_location_assignment PIN_W15 -to LED[0]
set_location_assignment PIN_AA24 -to LED[1]
set_location_assignment PIN_V16 -to LED[2]
set_location_assignment PIN_V15 -to LED[3]
set_location_assignment PIN_AF26 -to LED[4]
set_location_assignment PIN_AE26 -to LED[5]
set_location_assignment PIN_Y16 -to LED[6]
set_location_assignment PIN_AA23 -to LED[7]

#============================================================
# I/O
#============================================================
set_location_assignment PIN_Y15 -to LED_USER
set_location_assignment PIN_AA15 -to LED_HDD
set_location_assignment PIN_AG28 -to LED_POWER

#set_location_assignment PIN_AH24 -to BTN_USER
#set_location_assignment PIN_AG25 -to BTN_OSD
#set_location_assignment PIN_AG23 -to BTN_RESET

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LED_*
#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to BTN_*
#set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to BTN_*


set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to FPGA_CLK1_50
set_location_assignment PIN_V11 -to FPGA_CLK1_50
set_global_assignment -name POWER_PRESET_COOLING_SOLUTION "23 MM HEAT SINK WITH 200 LFPM AIRFLOW"
set_global_assignment -name POWER_BOARD_THERMAL_MODEL "NONE (CONSERVATIVE)"


#============================================================
# ADC
#============================================================
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ADC_CONVST
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ADC_SCK
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ADC_SDI
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ADC_SDO
set_location_assignment PIN_U9 -to ADC_CONVST
set_location_assignment PIN_V10 -to ADC_SCK
set_location_assignment PIN_AC4 -to ADC_SDI
set_location_assignment PIN_AD4 -to ADC_SDO
set_instance_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top