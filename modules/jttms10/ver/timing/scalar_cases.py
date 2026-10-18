#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Independent scalar timing/architectural fixtures from TI SPVU001A.

Uses integer arithmetic and bit_length, not the DUT's datapath algorithm.
Opcode encodings, flag masks and counts are cited per instruction form.
"""
from oracle import SHIFT_PAGES, shift_states

MASK32 = (1 << 32) - 1
N, C, Z, V = (1 << b for b in (31, 30, 29, 28))
SHIFT_BASES = {
    'SLA': (0x2000, 0x6000), 'SLL': (0x2400, 0x6200),
    'SRA': (0x2800, 0x6400), 'SRL': (0x2C00, 0x6600),
    'RL': (0x3000, 0x6800),
}

# Literal TI p.12-239 examples: source, count, result, NCZV. Both the
# mathematical model and the DUT are checked against these printed values.
TI_SLA_EXAMPLES = (
    (0x33333333, 0, 0x33333333, 0x0),
    (0xCCCCCCCC, 0, 0xCCCCCCCC, 0x8),
    (0xCCCCCCCC, 1, 0x99999998, 0xC),
    (0x33333333, 2, 0xCCCCCCCC, 0x9),
    (0xCCCCCCCC, 2, 0x33333330, 0x5),
    (0xCCCCCCCC, 3, 0x66666660, 0x1),
    (0xCCCCCCCC, 5, 0x99999980, 0xD),
    (0xCCCCCCCC, 30, 0, 0x7),
    (0xCCCCCCCC, 31, 0, 0x3),
    (0, 31, 0, 0x2),
)


def shift_result(name, value, count, status):
    signed = value - (1 << 32) if value & N else value
    carry = 0
    overflow = False
    if name in ('SLA', 'SLL'):
        exact = signed * (2 ** count)
        result = (value * (2 ** count)) & MASK32
        if count:
            carry = (value // (2 ** (32-count))) % 2
        overflow = not -(1 << 31) <= exact < (1 << 31)
    elif name in ('SRA', 'SRL'):
        result = ((signed if name == 'SRA' else value) // (2 ** count)) & MASK32
        if count:
            carry = (value // (2 ** (count-1))) % 2
    else:
        assert name == 'RL'
        result = ((value << count) | (value >> (32-count))) & MASK32
        if count:
            carry = result & 1
    status = (status & ~(C | Z)) | (carry << 30) | (int(result == 0) << 29)
    if name in ('SLA', 'SRA'):
        status = (status & ~N) | (result & N)
    if name == 'SLA':
        status = (status & ~V) | (int(overflow) << 28)
    return result, status


def shift_cases():
    for cache_disabled in (False, True):
        for name, bases in SHIFT_BASES.items():
            for register_count in (False, True):
                probes = [(q, 'mixed', 0xA0000003, False) for q in range(32)]
                probes += [(q, 'zero', 0, False) for q in (0, 31)]
                probes += [(q, 'positive', 0x10000003, False) for q in (0, 1, 31)]
                probes += [(q, 'minimum', 0x80000000, False) for q in (1, 31)]
                if name == 'SLA':
                    probes += [(q, f'guide_{value:08x}', value, False)
                               for value,q,result,flags in TI_SLA_EXAMPLES]
                if register_count:
                    probes += [(q, 'alias', None, True) for q in (0, 1, 31)]
                for count, tag, value, alias in probes:
                    raw = (-count if name in ('SRA', 'SRL') else count) & 31
                    if alias:
                        value = 0xA0000000 | raw
                    initial_st = (0x810 | (int(not (count & 1)) << 31) |
                                  (int(not (count & 4)) << 30) |
                                  (int(bool(count & 2)) << 29) |
                                  (int(not (count & 8)) << 28))
                    regs = [value, 0x11223344,
                            (0xFFFFFFE0 | raw) if register_count else 0x12345678,
                            initial_st]
                    expected = list(regs)
                    expected[0], expected_st = shift_result(name, value, count, initial_st)
                    if tag.startswith('guide_'):
                        result,flags = next((result,flags) for v,q,result,flags in TI_SLA_EXAMPLES
                                            if (v,q)==(value,count))
                        expected[0], expected_st = result, (flags << 28) | (initial_st & 0x0FFFFFFF)
                    form = 'RR' if register_count else 'K'
                    opcode = bases[int(register_count)]
                    opcode |= (0 if alias else 2 << 5) if register_count else raw << 5
                    yield dict(name=f"{name.lower()}_{form.lower()}_{tag}_n{count:02d}_{'off' if cache_disabled else 'hit'}",
                               coverage_id=f'{name}_{form}', opcode=opcode,
                               regs=regs, expected_regs=expected, expected_st=expected_st,
                               states=shift_states(name, count=count, cache_disabled=cache_disabled),
                               cache_disabled=cache_disabled,
                               citation='SPVU001A '+SHIFT_PAGES[name][int(register_count)],
                               conditions=dict(operation=name, form=form, count=count,
                                               encoded_count=raw, value=value, alias=alias))


def lmo_cases():
    values = [0, MASK32, *(1 << q for q in range(32)), 0x00ABCDEF]
    probes = [(value, False) for value in values] + [(value, True) for value in (0, 1, 0x80000000)]
    for cache_disabled in (False, True):
        for q, (value, alias) in enumerate(probes):
            initial_st = 0x810 | ((0xD if q % 2 else 0x5) << 28) | (Z if value else 0)
            regs = [value if alias else 0x11223344, 0xDEADBEEF, value, initial_st]
            expected = list(regs)
            expected[0] = 32-value.bit_length() if value else 0
            yield dict(name=f"lmo_{'alias' if alias else 'separate'}_{value:08x}_{'off' if cache_disabled else 'hit'}",
                       coverage_id='LMO_RR', opcode=0x6A00 | (0 if alias else 2 << 5),
                       regs=regs, expected_regs=expected,
                       expected_st=(initial_st & ~Z) | (Z if not value else 0),
                       states=4 if cache_disabled else 1, cache_disabled=cache_disabled,
                       citation='SPVU001A 12-108', conditions=dict(value=value, alias=alias))
