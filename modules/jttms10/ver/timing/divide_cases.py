#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Independent mathematical DIV/MOD fixtures and literal TI examples.

Uses Python integer quotient/remainder, not the hardware's restoring loop.
Timing is separately derived by oracle.divide_states from the printed TI
tables. See docs/divide.md for the MOD wording interpretations.
"""
from oracle import divide_states
from scalar_cases import MASK32, N, C, Z, V
from alu_cases import initial_status

BASES = dict(DIVS=0x5800, DIVU=0x5A00, MODS=0x6C00, MODU=0x6E00)
PAGES = dict(DIVS='12-63..64', DIVU='12-65..66', MODS='12-113', MODU='12-114')

# name, paired, high, low, divisor, expected-high, expected-low, NCZV.
# C is ignored in printed examples; N also unaffected for DIVU/MOD.
TI_DIV_EXAMPLES = (
    ('DIVS', True, 0x12345678, 0x87654321, 0x87654321, 0xD95BC60A, 0x15CA1DD7, 8),
    ('DIVS', True, 0xEDCBA987, 0x789ABCDF, 0x87654321, 0x26A439F6, 0xEA35E229, 0),
    ('DIVS', True, 0xEDCBA987, 0x789ABCDF, 0x789ABCDF, 0xD95BC60A, 0xEA35E229, 8),
    ('DIVS', True, 0x12345678, 0x87654321, 0x789ABCDF, 0x26A439F6, 0x15CA1DD7, 0),
    ('DIVS', True, 0x12345678, 0x87654321, 0, 0x12345678, 0x87654321, 1),
    ('DIVS', True, 0, 0, 0x87654321, 0, 0, 2),
    ('DIVS', True, 0x87654321, 0, 0x87654321, 0x87654321, 0, 1),
    ('DIVS', False, 0, 0x87654321, 0x12345678, 0, 0xFFFFFFFA, 8),
    ('DIVS', False, 0, 0x87654321, 0xEDCBA988, 0, 6, 0),
    ('DIVS', False, 0, 0x789ABCDF, 0xEDCBA988, 0, 0xFFFFFFFA, 8),
    ('DIVS', False, 0, 0x789ABCDF, 0x12345678, 0, 6, 0),
    ('DIVS', False, 0, 0x87654321, 0, 0, 0x87654321, 1),
    ('DIVU', True, 0x12345678, 0x87654321, 0x789ABCDF, 0x26A439F6, 0x15CA1DD7, 0),
    ('DIVU', True, 0x87654321, 0, 0x87654321, 0x87654321, 0, 1),
    ('DIVU', False, 0, 0x789ABCDF, 0x12345678, 0, 6, 0),
    ('DIVU', False, 0, 0x87654321, 0x87654321, 0, 1, 0),
    ('MODS', False, 4, 8, 4, 4, 0, 2),
    ('MODS', False, 4, 7, 4, 4, 3, 0),
    ('MODS', False, 4, 0xFFFFFFF9, 4, 4, 0xFFFFFFFD, 0),
    ('MODS', False, 0xFFFFFFFC, 8, 0xFFFFFFFC, 0xFFFFFFFC, 0, 2),
    ('MODS', False, 0xFFFFFFFC, 0xFFFFFFF9, 0xFFFFFFFC, 0xFFFFFFFC, 0xFFFFFFFD, 0),
    ('MODU', False, 4, 8, 4, 4, 0, 2),
    ('MODU', False, 4, 7, 4, 4, 3, 0),
    ('MODU', False, 4, 0xFFFFFFF9, 4, 4, 1, 0),
)


def operands(name, paired, regs, source):
    raw = (regs[0] << 32) | regs[1] if paired else regs[1]
    bits = 64 if paired else 32
    dividend = raw-(1 << bits) if name.endswith('S') and raw & (1 << (bits-1)) else raw
    divisor = regs[source]
    if name.endswith('S') and divisor & N:
        divisor -= 1 << 32
    return dividend, divisor


def divide_result(name, paired, regs, source=2):
    dividend, divisor = operands(name, paired, regs, source)
    result, status = list(regs), regs[3]
    early = divisor == 0
    quotient = remainder = 0
    if not early:
        quotient = abs(dividend) // abs(divisor)
        early = paired and quotient >= 1 << 32
        if (dividend < 0) != (divisor < 0):
            quotient = -quotient
        remainder = dividend-quotient*divisor
    overflow = early or (name.endswith('S') and not -(1 << 31) <= quotient < (1 << 31))
    status = (status & ~V) | (V if overflow else 0)
    if name.startswith('MOD'):
        if not early:
            result[1] = remainder & MASK32
            status = (status & ~Z) | (Z if remainder == 0 else 0)
    else:
        if not overflow:
            result[0 if paired else 1] = quotient & MASK32
            if paired:
                result[1] = remainder & MASK32
        status = (status & ~Z) | (Z if not overflow and quotient == 0 else 0)
        if name == 'DIVS':
            negative = not early and (quotient < 0 or abs(quotient) == 1 << 31)
            status = (status & ~N) | (N if negative else 0)
    return result, status


def divide_case(name, paired, high, low, divisor, index, off, *, source=2, tag='boundary'):
    # Fields/FE deliberately vary: division always uses full registers.
    status = (initial_status(index) & ~0xFFF) | ((index*37) & 0xFFF)
    regs = [high, low, divisor, status]
    expected, expected_st = divide_result(name, paired, regs, source)
    dividend, operand = operands(name, paired, regs, source)
    magnitude = abs(dividend)//abs(operand) if operand else 0
    rule = ('zero-divisor' if operand==0 else 'wide-overflow' if paired and magnitude>=1<<32 else
            'minimum-quotient-candidate' if name.endswith('S') and magnitude==1<<31 else 'normal')
    case = dict(name=f"{name.lower()}_{'even' if paired else 'odd'}_{tag}_{index}_{'off' if off else 'hit'}",
                coverage_id=name+'_RR' if name.startswith('DIV') else name,
                opcode=BASES[name] | (source << 5) | int(not paired), regs=regs,
                expected_regs=expected, expected_st=expected_st,
                states=divide_states(name, dividend=dividend, divisor=operand, paired=paired,
                                     cache_disabled=off),
                cache_disabled=off, citation='SPVU001A '+PAGES[name],
                conditions=dict(operation=name, paired=paired, dividend=dividend,
                                divisor=operand, source_register=source, timing_rule=rule))
    if name=='MODS' and rule=='minimum-quotient-candidate':
        case['conditions']['specification_note'] = 'p.12-113 result=80000000 interpreted as quotient candidate; remainder cannot reach that magnitude'
    if name.startswith('MOD'):
        case['conditions']['z_source'] = ('preserved Z: zero divisor' if operand==0 else
                                          'stored remainder: TI worked examples pp.12-113/114')
    return case


def divide_cases():
    modes = [('DIVS',False), ('DIVS',True), ('DIVU',False), ('DIVU',True),
             ('MODS',False), ('MODU',False)]
    for off in (False, True):
        for name, paired in modes:
            raw_pairs = []
            if not paired:
                raw_pairs = [(0x11223344,value,divisor)
                             for value in (0,1,3,7,8,MASK32,N,N-1,N+1)
                             for divisor in (0,1,4,7,MASK32,N,N-1)]
            else:
                raw_pairs = [(hi,lo,divisor) for hi,lo in
                             ((0,0), (0,100), (0,MASK32), (0,N), (MASK32,MASK32-99),
                              (N,0), (N-1,MASK32), (7,0), (6,MASK32))
                             for divisor in (0,1,7,MASK32,N,N-1)]
                magnitudes = (0,1,(1<<31)-1,1<<31,(1<<31)+1,(1<<32)-1,1<<32)
                for magnitude in magnitudes:
                    for sign in ((-1,1) if name=='DIVS' else (1,)):
                        for divisor in (3,-3) if name=='DIVS' else (7,):
                            raw = (sign*magnitude*abs(divisor)) & ((1<<64)-1)
                            raw_pairs.append((raw>>32,raw&MASK32,divisor&MASK32))
            for i,(high,low,divisor) in enumerate(raw_pairs):
                yield divide_case(name,paired,high,low,divisor,i,off)
            for source in ((0,1) if paired else (1,)):
                for i,value in enumerate((0,7,MASK32,N)):
                    yield divide_case(name,paired,value,value,value,1000+10*source+i,off,
                                      source=source,tag='alias')
        for i,(name,paired,high,low,divisor,expected_high,expected_low,flags) in enumerate(TI_DIV_EXAMPLES):
            case = divide_case(name,paired,high,low,divisor,2000+i,off,tag='ti_example')
            case['expected_regs'][:2] = [expected_high,expected_low]
            flag_mask = (N|Z|V) if name=='DIVS' else Z|V
            case['expected_st'] = (case['regs'][3] & ~flag_mask) | ((flags << 28) & flag_mask)
            yield case
