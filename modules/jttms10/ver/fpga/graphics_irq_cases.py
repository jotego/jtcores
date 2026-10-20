# SPDX-License-Identifier: GPL-3.0-or-later
"""Small native LINE interrupt continuation fixtures for protocol 5."""
import copy
import hashlib


def program_digest(words):
    return hashlib.sha256(b''.join(word.to_bytes(2, 'little') for word in words)).hexdigest()


def entries(oracle):
    from line_cases import fixture as line_fixture, program as line_program
    rows = []
    line = line_fixture(
        16, 4, 0, False, a=3, b=0, point=(2, 2), diagonal=(1, 0), major=(1, 0),
        convdp=24, offset=0x200, color=0x7fff, status=0xF0200810, tag='irq_restart')
    line['name'] = 'graphics_line_irq_resume'
    line['setup_io'].append((0xC0000110, 0x0002))  # INTENB.LINT1
    line['initial_all_regs']['sp'] = 0x3000
    line['expected_extra_regs']['sp'] = 0x3000
    base_words, start, end = line_program(line, oracle.movi)
    warm = oracle.movi(0x2fc0, 15) + oracle.movi(0x4000, 14) + [0x016e]
    shift = 16 * len(warm)
    words = warm + base_words
    start += shift
    end += shift
    # line_program's absolute skip branch must target the shifted LINE opcode.
    line_index = (start - 0x1000) // 16
    branch = line_index - 4
    words[branch + 1] = start & 0xffff
    words[branch + 2] = start >> 16
    return_pc = 0x1000 + shift
    stack = {address: 0xa55a for address in range(0x2f80, 0x3000, 16)}
    stack.update({0x2fc0: 0x00000010, 0x2fd0: 0,
                  0x2fe0: return_pc, 0x2ff0: 0})
    memory = dict(line['initial_memory'])
    memory.update(stack)
    memory.update({0xffffffc0: 0x4000, 0xffffffd0: 0})
    final_memory = memory.copy()
    final_memory.update(dict(line['expected_memory']))
    # LINE restart stacks its own opcode address and pre-interrupt ST.  The
    # aligned frame overwrites the warmup RETI frame but preserves neighbors.
    final_memory[0x2fc0] = line['expected_st'] & 0xffff
    final_memory[0x2fd0] = (line['expected_st'] >> 16) & 0xffff
    final_memory[0x2fe0] = start & 0xffff
    final_memory[0x2ff0] = (start >> 16) & 0xffff
    while len(words) < 768:
        words.append(0x0300)
    words.extend([0x0940])  # warmed RETI-only handler
    line.update(name='graphics_line_irq_resume', initial_sp=0x3000,
                regs=line['regs'], expected_regs=line['expected_regs'],
                expected_st=line['expected_st'], expected_extra_regs=line['expected_extra_regs'],
                initial_memory=sorted(memory.items()), expected_memory=sorted(final_memory.items()),
                observe_all=True, observe_implicit=True, drain_instructions=4,
                follow_pc=end + 16 * 3, test_pc=start, next_pc=end)
    fixture_hash = program_digest(words)
    row = dict(name=line['name'], fixture=line, program_words=words,
               test_pc=start, next_pc=end, stimulus=dict(wait_states=0),
               external_contract=dict(kind='graphics_line_irq', interrupt='lint1',
                                      duration='observed_only',
                                      program_sha256=fixture_hash),
               external_events=[dict(trigger=1, argument=1, control=1),
                                dict(trigger=1, argument=5, control=0)])
    rows.append(row)

    # The NMI variant uses the same independently calculated LINE image and
    # initialized frame, but selects the architectural NMI vector through the
    # existing host-write event path.  The event pin/data is released after
    # the registered host acknowledgement.
    nmi = copy.deepcopy(row)
    nmi['name'] = 'graphics_line_nmi_resume'
    nmi['fixture']['name'] = nmi['name']
    nmi['fixture']['initial_memory'] = [(a, v) for a, v in nmi['fixture']['initial_memory']
                                        if a not in (0xffffffc0, 0xffffffd0)]
    nmi['fixture']['initial_memory'] += [(0xfffffee0, 0x4000), (0xfffffef0, 0)]
    nmi['fixture']['initial_memory'].sort()
    nmi_memory = {a: v for a, v in nmi['fixture']['expected_memory']
                  if a not in (0xffffffc0, 0xffffffd0)}
    nmi_memory.update({0xfffffee0: 0x4000, 0xfffffef0: 0})
    nmi['fixture']['expected_memory'] = sorted(nmi_memory.items())
    nmi['external_contract'] = dict(kind='graphics_line_irq', interrupt='nmi',
                                     duration='observed_only',
                                     program_sha256=fixture_hash)
    nmi['external_events'] = [dict(trigger=1, argument=1, control=0x110),
                              dict(trigger=5, argument=1, control=0)]
    rows.append(nmi)
    return rows
