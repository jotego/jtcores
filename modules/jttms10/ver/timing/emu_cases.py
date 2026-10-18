#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""EMU with RUN asserted: SPVS002C p14 and SPVU001A pp12-17/77.

The 1991 data sheet and guide summary give6/9; the guide entry gives8/11.
RUN-high acts as NOP. Data-sheet status dashes require full ST preservation;
the earlier guide's indeterminate NCZV permits that same chosen behavior.
Emulation-mode hold/resume is a separate event contract, not a fixed count.
"""
from itertools import product
from alu_cases import initial_status


def fixture(tag,status,off,offset=0):
    regs=[0x11223344,0x80000000,0xA5A55A5A,status]
    b={q:0xB0102030+q*0x1020304 for q in range(4)}
    return dict(name=f'emu_run_{tag}_{"off" if off else "hit"}',coverage_id='EMU',opcode=0x0100,
        regs=regs,expected_regs=list(regs),expected_st=status,cache_disabled=off,states=9 if off else 6,
        initial_b_regs=b,initial_sp=0x12345000,
        expected_extra_regs={**{f'b{q}':v for q,v in b.items()},'sp':0x12345000},
        instruction_word_offset=offset,citation='SPVS002C June1991 p14; SPVU001A12-17/77',
        conditions=dict(run=True,initial_status=status,opcode_offset=offset),
        source_values=dict(summary_cpu=6,summary_cd=9,entry_cpu=8,entry_cd=11,datasheet_cpu=6,policy_cpu=6,policy_cd=9),
        timing_source_status='primary-summary-consistent',
        source_notes='Guide entry8/11 conflicts with summary6/9 and later data-sheet minimum6. Keep the simple6/9 schedule under the owner direction. Data-sheet status dashes preserve fullST; guide indeterminateNCZV allows that result. RUN-low hold/resume is not a fixed-duration claim; no official TI correction is claimed.')


def emu_cases():
    for off,flags in product((False,True),range(16)):
        yield fixture(f'flags{flags}',(initial_status(flags)&0x0FFFFFFF)|(flags<<28),off)
    for off,field,width,fe in product((False,True),(0,1),range(1,33),(0,1)):
        status=(initial_status(width)&~(63<<(6*field)))|(((width&31)|(fe<<5))<<(6*field))
        yield fixture(f'ignored_f{field}_w{width}_fe{fe}',status,off)
    for off,offset in product((False,True),range(4)):
        yield fixture(f'phase_a{offset}',0xF0200FFF,off,offset)
