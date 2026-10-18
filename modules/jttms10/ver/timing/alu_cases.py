#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Primary-spec scalar fixtures: mathematical arithmetic and full ST checks.

Instruction-entry citations are in oracle.FIXED. Arithmetic uses Python signed
range checks, independently of the DUT's carry chain and microcode. Aliases
(INC/DEC/CLR) retain their own TI coverage entries.
"""
from oracle import FIXED, fixed_states, setf_states
from scalar_cases import MASK32, N, C, Z, V


def signed(value):
    return value - (1 << 32) if value & N else value


def arithmetic(name, source, dest, status):
    carry = int(bool(status & C)) if name in ('ADDC', 'SUBB', 'NEGB') else 0
    if name in ('NEG', 'NEGB'):
        dest = 0
    subtract = name in ('SUB', 'SUBB', 'CMP', 'SUBK', 'DEC', 'NEG', 'NEGB')
    exact = dest-source-carry if subtract else dest+source+carry
    exact_signed = (signed(dest)-signed(source)-carry if subtract else
                    signed(dest)+signed(source)+carry)
    result = exact & MASK32
    flags = ((result & N) | (C if (exact < 0 if subtract else exact > MASK32) else 0) |
             (Z if result == 0 else 0) |
             (V if not -(1 << 31) <= exact_signed < (1 << 31) else 0))
    return result, (status & ~(N | C | Z | V)) | flags


def fixture(name, tag, opcode, regs, expected, status, cache_disabled, *, coverage=None,
            conditions=None):
    return dict(name=f"scalar_{name.lower()}_{tag}_{'off' if cache_disabled else 'hit'}",
                coverage_id=coverage or name+'_RR', opcode=opcode, regs=regs,
                expected_regs=expected, expected_st=status,
                states=fixed_states(name, cache_disabled=cache_disabled),
                cache_disabled=cache_disabled, citation='SPVU001A '+FIXED[name][2],
                conditions=conditions or {})


def initial_status(index):
    # Toggle initial NCZV and IE, retain unrelated field information.
    return 0x810 | ((index % 16) << 28) | ((index & 1) << 21)


def alu_cases():
    pairs = [(0, 0), (0, 1), (1, 0), (1, 1), (MASK32, 1), (1, MASK32),
             (MASK32, MASK32), (0x7FFFFFFF, 1), (0x7FFFFFFF, MASK32),
             (0x80000000, 1), (0x80000000, MASK32), (0x80000000, 0x80000000),
             (0x55555555, 0xAAAAAAAA), (0x12345678, 0x87654321)]
    rr_bases = dict(ADD=0x4000, ADDC=0x4200, SUB=0x4400, SUBB=0x4600,
                    CMP=0x4800, AND=0x5000, ANDN=0x5200, OR=0x5400,
                    XOR=0x5600, MOVE=0x4C00, MOVX=0xEC00, MOVY=0xEE00)
    for off in (False, True):
        for name, base in rr_bases.items():
            for q, (dest, source) in enumerate(pairs + [(v, v) for v in (0, MASK32, N)]):
                alias = q >= len(pairs)
                for carry in (0, 1):
                    st = (initial_status(q) & ~C) | (carry << 30)
                    regs = [dest, 0xDEADBEEF, source, st]
                    expected = list(regs)
                    status = st
                    if name in ('ADD', 'ADDC', 'SUB', 'SUBB', 'CMP'):
                        value, status = arithmetic(name, source, dest, st)
                    elif name in ('AND', 'ANDN', 'OR', 'XOR'):
                        value = {'AND': dest & source, 'ANDN': dest & ~source,
                                 'OR': dest | source, 'XOR': dest ^ source}[name] & MASK32
                        status = (st & ~Z) | (Z if value == 0 else 0)
                    elif name == 'MOVE':
                        value = source
                        status = (st & ~(N | Z | V)) | (source & N) | (Z if value == 0 else 0)
                    else:
                        value = ((dest & 0xFFFF0000) | (source & 0xFFFF) if name == 'MOVX' else
                                 (source & 0xFFFF0000) | (dest & 0xFFFF))
                    if name != 'CMP':
                        expected[0] = value
                    yield fixture(name, f'p{q}_c{carry}', base | (0 if alias else 2 << 5),
                                  regs, expected, status, off, conditions=dict(source=source,
                                  destination=dest, carry=carry, alias=alias))
        for name, base in (('ADDK', 0x1000), ('SUBK', 0x1400), ('MOVK', 0x1800)):
            for constant in range(1, 33):
                for q, dest in enumerate((0, 0x7FFFFFFF, MASK32)):
                    st = initial_status(constant+q)
                    regs = [dest, 0x11223344, 0xA5A5A5A5, st]
                    expected = list(regs)
                    if name == 'MOVK':
                        expected[0], status = constant, st
                    else:
                        expected[0], status = arithmetic(name, constant, dest, st)
                    yield fixture(name, f'k{constant}_d{q}', base | ((constant & 31) << 5),
                                  regs, expected, status, off, coverage=name+'_K',
                                  conditions=dict(constant=constant, destination=dest))
                    if constant == 1 and name != 'MOVK':
                        alias = 'INC' if name == 'ADDK' else 'DEC'
                        yield fixture(alias, f'd{q}', base | 0x20, regs, expected, status,
                                      off, coverage=alias+'_R')
        for name, base in (('ABS', 0x0380), ('NEG', 0x03A0), ('NEGB', 0x03C0),
                           ('NOT', 0x03E0), ('CLR', 0x5600)):
            for q, value in enumerate((0, 1, MASK32, N, N+1, N-1, 0xFFFA0011)):
                for carry in (0, 1):
                    st = (initial_status(q) & ~C) | (carry << 30)
                    regs = [value, 0x11223344, 0xA5A5A5A5, st]
                    expected = list(regs)
                    if name in ('NEG', 'NEGB'):
                        expected[0], status = arithmetic(name, value, 0, st)
                    elif name == 'ABS':
                        expected[0] = abs(signed(value)) & MASK32
                        status = ((st & ~(N | Z | V)) | ((-value) & N) |
                                  (Z if value == 0 else 0) | (V if value == N else 0))
                    else:
                        expected[0] = (~value & MASK32) if name == 'NOT' else 0
                        status = (st & ~Z) | (Z if expected[0] == 0 else 0)
                    yield fixture(name, f'v{q}_c{carry}', base, regs, expected, status, off,
                                  coverage=name+'_R', conditions=dict(value=value, carry=carry))
        for register in (False, True):
            name = 'BTST_RR' if register else 'BTST_K'
            for bit in range(32):
                for set_bit in (False, True):
                    value = (1 << bit) if set_bit else MASK32 ^ (1 << bit)
                    st = initial_status(bit)
                    regs = [value, 0x11223344, 0xFFFFFFE0 | bit, st]
                    status = (st & ~Z) | (Z if not set_bit else 0)
                    opcode = 0x4A40 if register else 0x1C00 | ((~bit & 31) << 5)
                    yield fixture(name, f'b{bit}_set{int(set_bit)}', opcode, regs, list(regs),
                                  status, off, coverage=name, conditions=dict(bit=bit, value=value))
        yield from field_cases(off)
        yield from status_cases(off)


def field_cases(off):
    for field in (0, 1):
        for fs in range(1, 33):
            for q, value in enumerate((0, MASK32, 0xCAFEBABE, 1 << (fs-1))):
                for name, base in (('SEXT', 0x0500), ('ZEXT', 0x0520)):
                    # Both FE bits deliberately disagree with SEXT/ZEXT semantics.
                    st = (initial_status(q+fs) & ~(31 << (6*field))) | ((fs & 31) << (6*field))
                    fe_bit = 5+6*field
                    st = (st & ~(1 << fe_bit)) | (int(name == 'ZEXT') << fe_bit)
                    regs = [value, 0x11223344, 0xA5A5A5A5, st]
                    expected = list(regs)
                    retained = value % (1 << fs)
                    exact = retained-(1 << fs) if name == 'SEXT' and retained & (1 << (fs-1)) else retained
                    expected[0] = exact & MASK32
                    status = (st & ~Z) | (Z if exact == 0 else 0)
                    if name == 'SEXT':
                        status = (status & ~N) | (expected[0] & N)
                    yield fixture(name, f'f{field}_fs{fs}_v{q}', base | (field << 9),
                                  regs, expected, status, off, coverage=name+'_R',
                                  conditions=dict(field=field, size=fs, value=value))
            for fe in (0, 1):
                st = initial_status(fs+fe)
                regs = [0x12345678, 0x11223344, 0xA5A5A5A5, st]
                status = (st & ~(63 << (6*field))) | (((fe << 5) | (fs & 31)) << (6*field))
                yield dict(name=f"scalar_setf_f{field}_fs{fs}_fe{fe}_{'off' if off else 'hit'}",
                           coverage_id='SETF', opcode=0x0540 | (field << 9) | (fe << 5) | (fs & 31),
                           regs=regs, expected_regs=list(regs), expected_st=status,
                           states=setf_states(field=field, cache_disabled=off), cache_disabled=off,
                           citation='SPVU001A 12-237', conditions=dict(field=field, size=fs, extension=fe))
        for value in (0, 1, 16, 31, 32, 63):
            st = initial_status(value) | 0xAB5
            regs = [0xDEADBE00 | value, 0x11223344, 0xA5A5A5A5, st]
            expected = list(regs)
            expected[0] = (st >> (6*field)) & 63
            status = (st & ~(63 << (6*field))) | (value << (6*field))
            yield fixture('EXGF', f'f{field}_v{value}', 0xD500 | (field << 9),
                          regs, expected, status, off, coverage='EXGF_R',
                          conditions=dict(field=field, value=regs[0]))


def status_cases(off):
    for q in range(16):
        st = initial_status(q)
        regs = [0xE0200A35 ^ (q << 28), 0x11223344, 0xA5A5A5A5, st]
        for name, opcode in (('CLRC', 0x0320), ('SETC', 0x0DE0), ('DINT', 0x0360),
                             ('EINT', 0x0D60), ('GETST', 0x0180), ('PUTST', 0x01A0),
                             ('REV', 0x0020), ('GETPC', 0x0140)):
            expected = list(regs)
            status = st
            if name == 'CLRC': status &= ~C
            if name == 'SETC': status |= C
            if name == 'DINT': status &= ~(1 << 21)
            if name == 'EINT': status |= 1 << 21
            if name == 'GETST': expected[0] = st
            if name == 'PUTST': status = regs[0]
            if name == 'REV': expected[0] = 8
            case = fixture(name, f'flags{q:x}', opcode, regs, expected, status, off,
                           coverage=name if name in ('CLRC', 'SETC', 'DINT', 'EINT') else name+'_R')
            if name == 'REV':
                # TI p.12-233 defines bits 15..3 only, shown as 0008h.
                case['expected_masks'] = [0xFFF8, MASK32, MASK32, MASK32]
            if name == 'GETPC':
                case['pc_result_register'] = 0  # Opcode bit-address + 16, p.12-89.
            yield case
