# SPDX-License-Identifier: GPL-3.0-or-later
"""Four bounded native FILL continuation fixtures for protocol 5."""
import copy
import hashlib


def _digest(words):
    return hashlib.sha256(b''.join(word.to_bytes(2, 'little') for word in words)).hexdigest()


def entries(oracle):
    import sys
    from pathlib import Path
    timing = Path(__file__).resolve().parents[1] / 'timing'
    sys.path.insert(0, str(timing))
    from fill_cases import fixture as fill_fixture, program as fill_program

    rows = []
    for xy, interrupt in ((False, 'lint1'), (False, 'nmi'),
                          (True, 'lint1'), (True, 'nmi')):
        fill = fill_fixture(16, 2, 8, xy, False, point=0x00010000,
                            offset=0x6000, convdp=23, pitch=0x100)
        fill['expected_st'] = 0xf0200810
        fill['initial_all_regs']['a3'] = 0xf0200810
        fill['regs'][3] = 0xf0200810
        fill['expected_regs'][3] = 0xf0200810
        fill['name'] = f'graphics_fill_{"xy" if xy else "l"}_{interrupt}_resume'
        fill['initial_all_regs']['sp'] = 0x3000
        fill['expected_extra_regs']['sp'] = 0x3000
        fill['register_overrides']['sp'] = 0x3000
        if interrupt == 'lint1':
            fill['setup_io'].append((0xc0000110, 0x0002))
        base_words, start, end = fill_program(fill, oracle.movi)
        warm = oracle.movi(0x2fc0, 15) + oracle.movi(0x4000, 14) + [0x016e]
        shift = 16 * len(warm)
        words = warm + base_words
        start += shift
        end += shift
        # The setup program's absolute branch skips the measured FILL on warm-up.
        opcode_index = (start - 0x1000) // 16
        branch = opcode_index - 4
        words[branch + 1] = end & 0xffff
        words[branch + 2] = end >> 16
        tail_jump = opcode_index + 18
        words[tail_jump + 1] = (start - 16) & 0xffff
        words[tail_jump + 2] = (start - 16) >> 16

        event_after_writes = 2 if xy else 1
        events = ([dict(trigger=1, argument=event_after_writes, control=1),
                   dict(trigger=1, argument=5, control=0)]
                  if interrupt == 'lint1' else
                  [dict(trigger=1, argument=event_after_writes, control=0x110),
                   dict(trigger=5, argument=1, control=0)])

        stack = {address: 0xa55a for address in range(0x2f80, 0x3000, 16)}
        return_pc = 0x1000 + shift
        stack.update({0x2fc0: 0x0010, 0x2fd0: 0,
                      0x2fe0: return_pc, 0x2ff0: 0})
        vector = 0xffffffc0 if interrupt == 'lint1' else 0xfffffee0
        memory = dict(fill['initial_memory'])
        memory.update(stack)
        memory.update({vector: 0x4000, vector + 16: 0})
        final_memory = dict(fill['expected_memory'])
        final_memory.update(stack)
        final_memory.update({0x2fc0: fill['expected_st'] & 0xffff,
                             0x2fd0: (fill['expected_st'] >> 16) | 0x0200,
                             0x2fe0: end & 0xffff,
                             0x2ff0: end >> 16,
                             vector: 0x4000, vector + 16: 0})
        while len(words) < 768:
            words.append(0x0300)
        words.append(0x0940)  # warmed RETI-only interrupt handler at 0x4000

        fill.update(name=f'graphics_fill_{"xy" if xy else "l"}_{interrupt}_resume',
                    initial_sp=0x3000, initial_memory=sorted(memory.items()),
                    expected_memory=sorted(final_memory.items()), observe_all=True,
                    observe_implicit=True, drain_instructions=12,
                    follow_pc=end + 16 * 8, test_pc=start, next_pc=end)
        digest = _digest(words)
        entry = dict(name=fill['name'], fixture=fill, program_words=words,
                     test_pc=start, next_pc=end, stimulus=dict(wait_states=0),
                     external_contract=dict(kind='graphics_fill_irq',
                         interrupt=interrupt, engine='xy' if xy else 'l',
                         duration='observed_only', program_sha256=digest),
                     external_events=events)
        rows.append(entry)
    return rows
