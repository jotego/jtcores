# SPDX-License-Identifier: GPL-3.0-or-later
"""External LINT entry/RETI fixtures; ordinary NOP timing remains independent."""
import copy
import irq_contract


def entries(base, oracle):
    rows = []
    for warm in (False, True):
        for lint in (1, 2):
            for waits in (0, 1, 3):
                case = copy.deepcopy(base['fixture'])
                case['name'] = f'irq_scalar_lint{lint}_w{waits}_{"warm" if warm else "cold"}'
                # These are new conditions, not changed expectations of nop_hit.
                case['regs'][3] |= 0x00200000
                case['expected_regs'][3] = case['regs'][3]
                case['expected_st'] = case['regs'][3]
                case.update(initial_sp=0x3000, expected_extra_regs=dict(sp=0x3000),
                    observe_implicit=True, setup_io=[(0xc0000110, 1 << lint)],
                    drain_instructions=12, following_words=[0x1022]*12,
                    citation='SPVU001A 12-170;8-2..8;12-230/231',
                    conditions=dict(lint=lint, handler_warm=warm, sp_alignment=0,
                                    refresh=False, host_indirect=False))
                vector = 0xffffffc0 if lint == 1 else 0xffffffa0
                case['initial_memory'] = [(a, 0) for a in range(0x2fc0, 0x3000, 16)]
                case['initial_memory'] += [(vector, 0x4000), (vector+16, 0)]
                words, start, end = oracle.program(case)
                if warm:
                    # Execute the actual handler once before enabling IRQs.
                    # RETI consumes a reset-time frame and returns to setup.
                    prologue = oracle.movi(0x2fc0, 15)+oracle.movi(0x4000, 14)+[0x016e]
                    shift = 16*len(prologue)
                    words = prologue+words
                    start += shift
                    end += shift
                    frame = {0x2fc0: 0x10, 0x2fd0: 0, 0x2fe0: 0x1000+shift, 0x2ff0: 0}
                    case['initial_memory'] = [(a, frame.get(a, v)) for a, v in case['initial_memory']]
                case.update(test_pc=start, next_pc=end, follow_pc=0x4000 if warm else end+16*7)
                while len(words) < (0x4000-0x1000)//16:
                    words.append(0x0300)
                words += oracle.movi(0x12345678, 0)+[0x0940]+[0x0300]*12
                rows.append(dict(name=case['name'], fixture=case, program_words=words,
                    test_pc=start, next_pc=end, stimulus=dict(wait_states=waits),
                    external_contract=dict(kind='scalar_irq', lint=lint, handler_warm=warm),
                    external_events=[dict(trigger=0, argument=16, control=1 << (lint-1)),
                                     dict(trigger=1, argument=4, control=0)]))
    return rows


def phase_entries(base, oracle):
    """Sweep one complete eight-INCLK state without changing the base cases."""
    rows = []
    for entry in entries(base, oracle):
        if not entry['external_contract']['handler_warm']:
            continue
        for clock in range(16, 24):
            row = copy.deepcopy(entry)
            row['name'] += f'_assert{clock}'
            row['fixture']['name'] = row['name']
            row['fixture']['conditions']['assert_clock'] = clock
            row['external_contract'].update(kind='scalar_irq_phase', assert_clock=clock)
            row['external_events'][0]['argument'] = clock
            rows.append(row)
    return rows


def unaligned_entries(base, oracle, offsets=None):
    """TI8-8 note3: every nonzero SP bit offset, both pins and cache conditions."""
    offsets = list(range(1, 16)) if offsets is None else list(offsets)
    if (not offsets or any(type(offset) is not int or not 1 <= offset <= 15 for offset in offsets)
            or len(offsets) != len(set(offsets))):
        raise ValueError('select unique unaligned SP offsets1..15')
    rows = []
    for offset in sorted(offsets):
        sp = 0x3000+offset
        for original in entries(base, oracle):
            row = copy.deepcopy(original)
            case = row['fixture']
            warm = row['external_contract']['handler_warm']
            vector = 0xffffffc0 if row['external_contract']['lint'] == 1 else 0xffffffa0
            row['name'] += f'_sp{offset}'
            case.update(name=row['name'], initial_sp=sp, expected_extra_regs=dict(sp=sp),
                        citation='SPVU001A 8-8 Table8-4 note3;12-170;12-230/231;13-4')
            case['conditions']['sp_alignment'] = offset
            memory = irq_contract.initial_stack(sp, warm)
            memory.update({vector: 0x4000, vector+16: 0})
            case['initial_memory'] = sorted(memory.items())
            words, start, end = oracle.program(case)
            if warm:
                # RETI from a real unaligned reset-time frame warms the ISR.
                prologue = oracle.movi(sp-64, 15)+oracle.movi(0x4000, 14)+[0x016e]
                words = prologue+words
                start += 16*len(prologue)
                end += 16*len(prologue)
            case.update(test_pc=start, next_pc=end, follow_pc=0x4000 if warm else end+16*7)
            while len(words) < (0x4000-0x1000)//16:
                words.append(0x0300)
            words += oracle.movi(0x12345678, 0)+[0x0940]+[0x0300]*12
            row.update(program_words=words, test_pc=start, next_pc=end)
            row['external_contract'].update(kind='scalar_irq_unaligned', sp_offset=offset)
            # Each unaligned 32-bit push writes three physical words.
            row['external_events'][1]['argument'] = 6
            rows.append(row)
    return rows
