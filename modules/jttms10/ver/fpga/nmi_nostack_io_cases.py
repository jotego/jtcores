# SPDX-License-Identifier: GPL-3.0-or-later
"""NMIM=1 runtime fixtures that read initialized I/O state inside the ISR."""
import copy

import nmi_nostack_cases


IO_READS = (
    # address, expected value (None means check only the specified HSTCTL bits), destination
    (0xC00000B0, 0x0018, 6),   # CONTROL; refresh/video remain disabled
    (0xC0000080, 0x0001, 7),  # DPYCTL (bit 1 is reserved)
    (0xC0000130, 0x001B, 8),  # CONVSP
    (0xC0000140, 0x0014, 9),  # CONVDP
    (0xC0000150, 0x0010, 10), # PSIZE
    (0xC0000160, 0x2A5A, 11), # PMASK
    (0xC0000100, None, 12),   # HSTCTLH: NMI cleared, NMIM retained
)


def _read_sequence(oracle):
    words = []
    for address, _, destination in IO_READS:
        words += oracle.movi(address, 14) + [0x0550, 0x8400 | (14 << 5) | destination]
    return words


def entries(base, oracle, offsets=None, phase_sweep=False):
    rows = nmi_nostack_cases.entries(base, oracle, offsets, phase_sweep)
    for row in rows:
        case = row['fixture']
        # Keep the original corpus names and generated fixture objects intact;
        # identify this independent inventory separately for combined reports.
        name = row['name'].replace('nmi_nostack_', 'nmi_nostack_io_', 1)
        row['name'] = name
        case['name'] = name
        # These values are established by real CPU stores before measurement.
        case['setup_io'] = [[address, value] for address, value, _ in IO_READS[:6]]
        case['follow_pc'] = 0x4290
        case['drain_instructions'] = 48
        words, start, end = oracle.program(case)
        # Restore the pointer/value pair overwritten by setup_io before the
        # measured NMI, then perform warm-up as the last predecode sequence.
        restore = oracle.movi(0x18, 13) + oracle.movi(0xC00000B0, 14)
        putst = words.index(0x01A3)
        words[putst:putst] = restore
        start += 16 * len(restore)
        end += 16 * len(restore)
        warm = row['external_contract']['handler_warm']
        prefix = oracle.movi(0x4000, 4) + oracle.movi(0x4050, 5)
        prefix += [0x0300] * (16-len(prefix))
        words = prefix + words
        start += 16 * len(prefix)
        end += 16 * len(prefix)
        if warm:
            init_a0 = words.index(0x09e0)
            return_pc = 0x1000 + 16 * (init_a0 + 7)
            warmup = oracle.movi(return_pc, 5) + oracle.movi(0x4000, 4) + [0x0164] + oracle.movi(0x4050, 5)
            words[init_a0:init_a0] = warmup
            start += 16 * len(warmup)
            end += 16 * len(warmup)
        case.update(test_pc=start, next_pc=end)
        while len(words) < (0x4000-0x1000)//16:
            words.append(0x0300)
        # The first long MOVI remains the first ISR instruction. Its following
        # register jump returns from warm-up or enters the read sequence.
        words += oracle.movi(0x12345678, 0) + [0x0165]
        while len(words) < (0x4050-0x1000)//16:
            words.append(0x0300)
        words += _read_sequence(oracle) + [0x0300, 0x0300, 0x0300, 0xC0FF]
        row.update(program_words=words, test_pc=start, next_pc=end,
                   external_contract=dict(kind='scalar_nmi_nostack_io',
                       handler_warm=warm,
                       sp_offset=row['external_contract']['sp_offset'],
                       interrupt_enable=row['external_contract']['interrupt_enable'],
                       assert_clock=row['external_contract']['assert_clock']))
    return rows
