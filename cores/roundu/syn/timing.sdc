# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 21-10-2026

# The V30 execution unit is a next-state cone feeding ce/ce_half-gated
# register banks (v30u_eu.sv). jtroundu_main generates cenb three clocks
# after each 8 MHz cen pulse, so EU registers load at least three clocks
# apart. The BIU has free-running registers and is excluded on purpose.
set_multicycle_path -from {*|v30u_eu:u_eu|*} -to {*|v30u_eu:u_eu|*} -setup -end 2
set_multicycle_path -from {*|v30u_eu:u_eu|*} -to {*|v30u_eu:u_eu|*} -hold -end 2
