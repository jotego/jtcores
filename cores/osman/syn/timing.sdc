# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 6-11-2026

# Both endpoints share fetch_stall; Wishbone errors are tied low in jtosman_main.
set osman_arm_bank [get_registers {*|jtosman_main:u_main|a23_core:u_arm|a23_execute:u_execute|a23_register_bank:u_register_bank|r*}]
set osman_arm_sources [add_to_collection $osman_arm_bank [get_registers {
    *|jtosman_main:u_main|a23_core:u_arm|a23_execute:u_execute|status_bits_mode*
    *|jtosman_main:u_main|a23_core:u_arm|a23_decode:u_decode|o_rm_sel*
    *|jtosman_main:u_main|a23_core:u_arm|a23_decode:u_decode|o_rds_sel*
    *|jtosman_main:u_main|a23_core:u_arm|a23_decode:u_decode|o_rn_sel*
}]]
set osman_arm_destinations [add_to_collection $osman_arm_bank [get_registers {*|jtosman_main:u_main|a23_core:u_arm|a23_execute:u_execute|o_address*}]]

if {[get_collection_size $osman_arm_bank] == 0 || [get_collection_size $osman_arm_sources] == 0 || [get_collection_size $osman_arm_destinations] == 0} {
    error "Osman ARM multicycle register collection is empty"
}
set_multicycle_path -from $osman_arm_sources -to $osman_arm_destinations -setup -end 2
set_multicycle_path -from $osman_arm_sources -to $osman_arm_destinations -hold -end 1
