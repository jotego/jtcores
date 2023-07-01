set_global_assignment -entity "jtframe_pll6671" -library "lib_jtframe_pll6671" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "jtframe_pll6671" -library "lib_jtframe_pll6671" -name IP_TOOL_VERSION "20.1"
set_global_assignment -entity "jtframe_pll6671" -library "lib_jtframe_pll6671" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_jtframe_pll6671" -name SPD_FILE [file join $::quartus(sip_path) "jtframe_pll6671.spd"]

set_global_assignment -library "lib_jtframe_pll6671" -name MISC_FILE [file join $::quartus(sip_path) "jtframe_pll6671_sim/jtframe_pll6671.vo"]
