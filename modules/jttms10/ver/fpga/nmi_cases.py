# SPDX-License-Identifier: GPL-3.0-or-later
"""Host-written, stacked NMI fixtures, independent of INTENB and status IE."""
import copy
import irq_cases
import irq_contract


def entries(base, oracle, offsets=None):
    offsets = list(range(16)) if offsets is None else list(offsets)
    if (not offsets or any(type(offset) is not int or not 0 <= offset <= 15 for offset in offsets)
            or len(offsets) != len(set(offsets))):
        raise ValueError('select unique NMI SP offsets0..15')
    rows = []
    originals = [row for row in irq_cases.entries(base, oracle)
                 if row['external_contract']['lint'] == 1]
    for offset in sorted(offsets):
        sp = 0x3000+offset
        for enabled in (False, True):
            for original in originals:
                row = copy.deepcopy(original)
                case = row['fixture']
                warm = row['external_contract']['handler_warm']
                waits = row['stimulus']['wait_states']
                row['name'] = f'nmi_scalar_ie{int(enabled)}_w{waits}_{"warm" if warm else "cold"}_sp{offset}'
                status = 0xd0000810 | (0x00200000 if enabled else 0)
                case['regs'][3] = case['expected_regs'][3] = status
                case.update(name=row['name'], expected_st=status, initial_sp=sp,
                    expected_extra_regs=dict(sp=sp), setup_io=[],
                    citation='SPVU001A 6-32/33;8-5..8;12-230/231',
                    conditions=dict(nmim=0, interrupt_enable=enabled, intenb=0,
                        handler_warm=warm, sp_alignment=offset,
                        refresh=False, host_indirect=False))
                memory = irq_contract.initial_stack(sp, warm)
                memory.update({0xfffffee0: 0x4000, 0xfffffef0: 0})
                case['initial_memory'] = sorted(memory.items())
                words, start, end = oracle.program(case)
                if warm:
                    prologue = oracle.movi(sp-64, 15)+oracle.movi(0x4000, 14)+[0x016e]
                    words = prologue+words
                    start += 16*len(prologue)
                    end += 16*len(prologue)
                case.update(test_pc=start, next_pc=end, follow_pc=0x4000 if warm else end+16*7)
                while len(words) < (0x4000-0x1000)//16:
                    words.append(0x0300)
                words += oracle.movi(0x12345678, 0)+[0x0940]+[0x0300]*12
                row.update(program_words=words, test_pc=start, next_pc=end,
                    external_contract=dict(kind='scalar_nmi', handler_warm=warm,
                        sp_offset=offset, interrupt_enable=enabled),
                    external_events=[dict(trigger=0, argument=16, control=0x110),
                                     dict(trigger=5, argument=1, control=0)])
                rows.append(row)
    return rows


def phase_entries(base, oracle):
    rows = []
    for original in entries(base, oracle, [0]):
        if not original['external_contract']['handler_warm']:
            continue
        for clock in range(16, 24):
            row = copy.deepcopy(original)
            row['name'] += f'_assert{clock}'
            row['fixture']['name'] = row['name']
            row['fixture']['conditions']['assert_clock'] = clock
            row['external_contract'].update(kind='scalar_nmi_phase', assert_clock=clock)
            row['external_events'][0]['argument'] = clock
            rows.append(row)
    return rows
