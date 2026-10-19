set_global_assignment -entity "pll_pocket" -library "lib_pll_pocket" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "pll_pocket" -library "lib_pll_pocket" -name IP_TOOL_VERSION "13.1"
set_global_assignment -entity "pll_pocket" -library "lib_pll_pocket" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_pll_pocket" -name SPD_FILE [file join $::quartus(sip_path) "pll_pocket.spd"]

set_global_assignment -library "lib_pll_pocket" -name MISC_FILE [file join $::quartus(sip_path) "pll_pocket_sim/pll_pocket.vo"]
