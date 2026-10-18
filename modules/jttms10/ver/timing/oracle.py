#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""TI timing rules, independent of the implementation and microcode generator.

Source: TMS34010 User's Guide, June 1988, SPVU001A. Page numbers below
are printed page numbers, not PDF indices. Unimplemented rules raise rather
than silently falling back to an observed RTL latency.
"""

INPUT_CLOCKS_PER_STATE = 8  # §1.3.1.5 p.1-7; Appendix A p.A-41


def multiply_states(*, signed, fs1, source, cache_disabled=False):
    """MPYS p.12-165; MPYU p.12-167; paired-count convention p.12-34.

    The negative-source correction in MPYU refers to the top bit of the
    selected source FIELD (not necessarily bit 31 of the register).
    Destination parity changes result width, not the printed timing rule.
    """
    if fs1 == 0:
        fs1 = 32
    if fs1 not in range(2, 33, 2):
        raise ValueError("TI specifies multiply only for even FS1 widths 2..32")
    return (5 + fs1 // 2 +
            int(not signed and bool(source & (1 << (fs1 - 1)))) +
            3 * int(cache_disabled))


# Each entry contains (cache-hit states, cache-disabled states, printed page).
# Do not add entries inferred from the RTL, generated ROM, or measured runs.
FIXED = {
    "NOP": (1, 4, "12-170"),
    "ADD": (1, 4, "12-36"),
    "MOVK": (1, 4, "12-161"),
    "DINT": (3, 6, "12-62"),
    "EINT": (3, 6, "12-76"),
    "SEXT": (3, 6, "12-238"),
}


def fixed_states(name, *, cache_disabled=False):
    return FIXED[name][int(cache_disabled)]


# (K page, register-count page), SPVU001A Machine States and Status Bits.
SHIFT_PAGES = {
    'RL': ('12-234', '12-235'),
    'SLA': ('12-239', '12-240'),
    'SLL': ('12-241', '12-242'),
    'SRA': ('12-243', '12-244'),
    'SRL': ('12-245', '12-246'),
}


def shift_states(name, *, count, cache_disabled=False):
    """All counts, including zero, have the printed constant timing."""
    if name not in SHIFT_PAGES or count not in range(32):
        raise ValueError('undefined shift operation/count')
    return (3 if name == 'SLA' else 1) + 3 * int(cache_disabled)
