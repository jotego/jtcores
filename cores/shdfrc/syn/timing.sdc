# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 26-11-2026

# Both ends update on the same cen_fm2 pulse.
set shdfrc_lfo_pm [get_registers {*|jt51:u_jt51|jt51_lfo:u_lfo|pm[*]*}]
set shdfrc_channel_pms [get_registers {*|jt51:u_jt51|jt51_mmr:u_mmr|jt51_reg:u_reg|jt51_reg_ch:u_csr_ch|pms[*]*}]
set shdfrc_phase_keycode [get_registers {*|jt51:u_jt51|jt51_pg:u_pg|keycode_II[*]*}]

if {[get_collection_size $shdfrc_lfo_pm] == 0 || [get_collection_size $shdfrc_channel_pms] == 0 || [get_collection_size $shdfrc_phase_keycode] == 0} {
    error "Shadow Force JT51 phase timing register collection is empty"
}

set shdfrc_phase_sources [add_to_collection $shdfrc_lfo_pm $shdfrc_channel_pms]
set_multicycle_path -from $shdfrc_phase_sources -to $shdfrc_phase_keycode -setup -end 2
set_multicycle_path -from $shdfrc_phase_sources -to $shdfrc_phase_keycode -hold -end 1
