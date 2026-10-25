# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 25-10-2026

# Both launch and capture registers advance only on fm2_cen.
set svolle_fm_pitch [get_registers {
    *|jtsvolle_snd:u_sound|jt51:u_fm|jt51_mmr:u_mmr|jt51_reg:u_reg|jt51_reg_ch:u_csr_ch|pms[*]
    *|jtsvolle_snd:u_sound|jt51:u_fm|jt51_lfo:u_lfo|pm[*]
}]
set svolle_fm_keycode [get_registers {*|jtsvolle_snd:u_sound|jt51:u_fm|jt51_pg:u_pg|keycode_II[*]}]

set_multicycle_path -from $svolle_fm_pitch -to $svolle_fm_keycode -setup -end 2
set_multicycle_path -from $svolle_fm_pitch -to $svolle_fm_keycode -hold  -end 1
