# SPDX-License-Identifier: GPL-3.0-or-later
"""NMIM=1 runtime programs: no stack use, then a register-only ISR exit."""
import copy


def entries(base, oracle, offsets=None, phase_sweep=False):
    offsets = ([0] if phase_sweep else list(range(16))) if offsets is None else list(offsets)
    if (not offsets or len(set(offsets)) != len(offsets) or
            any(type(q) is not int or not 0 <= q <= 15 for q in offsets)):
        raise ValueError('select unique no-stack NMI SP offsets0..15')
    rows = []
    for offset in sorted(offsets):
        for enabled in (False, True):
            for waits in (0, 1, 3):
                for warm in ((True,) if phase_sweep else (False, True)):
                    for clock in (range(16, 24) if phase_sweep else (16,)):
                        row = copy.deepcopy(base)
                        case = row['fixture']
                        sp = 0x3000+offset
                        status = 0xd0000810 | (0x00200000 if enabled else 0)
                        name = f'nmi_nostack_ie{int(enabled)}_w{waits}_{"warm" if warm else "cold"}_sp{offset}'
                        if phase_sweep:
                            name += f'_assert{clock}'
                        guards = {a: 0xa5a5 for a in range((sp-64) & ~15, ((sp+31) & ~15)+16, 16)}
                        guards.update({0xfffffee0: 0x4000, 0xfffffef0: 0})
                        case.update(name=name, regs=[0x80000003, 0x11223344, 2, status],
                            expected_regs=[0x80000003, 0x11223344, 2, status], expected_st=status,
                            initial_sp=sp, expected_extra_regs=dict(sp=sp, a4=0x4000, a5=0x4050, a13=0x18, a14=0xc00000b0),
                            observe_all=True, observe_implicit=True, setup_io=[],
                            initial_memory=sorted(guards.items()), following_words=[0x0300]*12,
                            drain_instructions=12, follow_pc=0x4030,
                            citation='SPVU001A 6-32/33;8-5..8;12-160',
                            conditions=dict(nmim=1, interrupt_enable=enabled, intenb=0,
                                handler_warm=warm, sp_alignment=offset, assert_clock=clock,
                                refresh=False, host_indirect=False,
                                context_duration='not separately specified for NMIM=1'))
                        words, start, end = oracle.program(case)
                        prefix = []
                        if warm:
                            # Warm the ISR without ever touching the suspect stack.
                            # The register JUMP returns here at 0x1070.
                            prefix = oracle.movi(0x1070, 5)+oracle.movi(0x4000, 4)+[0x0164]
                        prefix += oracle.movi(0x4000, 4)+oracle.movi(0x4050, 5)
                        prefix += [0x0300]*(16-len(prefix))
                        words = prefix+words
                        start += 16*len(prefix)
                        end += 16*len(prefix)
                        case.update(test_pc=start, next_pc=end)
                        while len(words) < (0x4000-0x1000)//16:
                            words.append(0x0300)
                        words += oracle.movi(0x12345678, 0)+[0x0165, 0x0300, 0xc0ff, 0x0300, 0x0300]
                        row.update(name=name, program_words=words, test_pc=start, next_pc=end,
                            stimulus=dict(wait_states=waits),
                            external_contract=dict(kind='scalar_nmi_nostack', handler_warm=warm,
                                sp_offset=offset, interrupt_enable=enabled, assert_clock=clock),
                            external_events=[dict(trigger=0, argument=clock, control=0x310),
                                             dict(trigger=5, argument=1, control=0)])
                        rows.append(row)
    return rows
