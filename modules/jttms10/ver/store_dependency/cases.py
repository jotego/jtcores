#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Independent CD byte-store instruction-fetch dependencies.

SPVU001A 5.4.6 (5-24), 6.2 (6-4), 11.3 (11-4), 12-117/119:
CD fetches external instructions, a byte insertion preserves other bits, and
each physical RMW is indivisible. These are architectural/bus expectations,
not an instruction-duration interpretation or cached self-modifying policy.
"""
from copy_cases import fixture as copy_fixture
from store_cases import fixture as store_fixture, insert
from run import program
from store_dependency_oracle import transfers


def cases():
    for copy in (False, True):
        for offset in (0, 8, 9, 15):
            for preceding in (False, True):
                tag=f'cd_dependency_o{offset}_previous{int(preceding)}'
                case=(copy_fixture(8, 0, 0, 0, True, 0, byte=True,
                                   source=0, dest=1, tag=tag) if copy else
                      store_fixture('absolute', 8, offset, 0, True, 0,
                                    byte=True, source=2, tag=tag))
                case.update(measure_pass=0, drain_instructions=-2)
                if not copy:
                    case['regs'][2]=case['expected_regs'][2]=0xff
                words, start, following=program(case)
                address=following-16*int(preceding)+offset
                if copy:
                    case['regs'][1]=case['expected_regs'][1]=address
                    case['data_copy']['destination']=address
                else:
                    case['extensions']=[address & 65535, address >> 16]
                case['data_store'].update(address=address, value=0xff)
                # Instruction memory is writable with CD. Seed the affected
                # words with their literal program contents, including a
                # preceding opcode/address operand when the byte straddles.
                memory={following:0x0300}
                for bit in range(8):
                    word=(address+bit) & ~15
                    memory[word]=words[(word-0x1000)//16]
                if copy:
                    memory[case['data_copy']['source']]=0xa5ff
                case['initial_memory']=sorted(memory.items())
                case['expected_memory']=insert(case['initial_memory'], address, 8, 0xff)
                if copy:
                    case['memory_before_measured']=case['initial_memory']
                case['expected_next_opcode']=dict(case['expected_memory'])[following]
                words, start, following=program(case)
                case.update(test_pc=start, next_pc=following)
                case['dependency_conditions']=dict(destination=address,
                    preceding_word=preceding, offset=offset,
                    next_opcode_modified=any((address+b) & ~15 == following for b in range(8)))
                yield case, words
