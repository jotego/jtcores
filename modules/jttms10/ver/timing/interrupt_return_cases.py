#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Independent RETI stack/state model, SPVU001A pp3-6,12-230/231.

These probes cover PBX=0 and no pending interrupt. PBX graphics resumption
and immediate acceptance of an enabled last-state IRQ require event tests.
"""
from itertools import product
from return_cases import rets_fixture, following_cases as rets_following_cases
from store_cases import insert
from load_cases import extract

MASK32=(1<<32)-1


def reti_fixture(tag,off,offset=0,flags=0,*,address=None,target=0x1800,low=0,restored=None,initial=0x10000810,alignment=0):
    sp=(0x5000+offset if address is None else address)&MASK32
    status=(0x810|(flags<<28)) if restored is None else restored
    if status&(1<<25):raise ValueError('PBX=1 requires graphics-resumption event probes')
    row=rets_fixture(tag,off,offset,flags=flags,address=sp,target=target,low=low,initial=initial,alignment=alignment)
    addresses=sorted({((sp+bit)&MASK32)&~15 for bit in range(64)})
    memory=insert([(a,0xA55A) for a in addresses],sp,32,status)
    memory=insert(memory,(sp+32)&MASK32,32,(target&~15)|low)
    reset={0xFFFFFFE0:0x1000,0xFFFFFFF0:0}
    if any(a in reset and v!=reset[a] for a,v in memory):raise ValueError('saved RETI state conflicts with initial reset vector')
    row.update(name=f'stack_reti_{tag}_{"off" if off else "hit"}',coverage_id='RETI',opcode=0x0940,
        expected_st=status,initial_memory=memory,expected_memory=memory,
        states=11+4*bool(sp&15)+3*off,stack_load='RETI',data_load=dict(address=sp,width=64,mode='stack'),
        stack_fields=[dict(address=sp,width=32),dict(address=(sp+32)&MASK32,width=32)],
        stack_control_flow=dict(form='RETI',target=target&~15),
        citation='SPVU001A3-6/12-230/231; summary12-17; SPVS002C June1991p14',
        conditions=dict(source=sp,stack_alignment=sp&15,target=target&~15,return_operand=(target&~15)|low,
                        initial_status=initial,restored_status=status,pbx=False,irq_pending=False,opcode_offset=alignment))
    row['expected_extra_regs']['sp']=(sp+64)&MASK32
    assert extract(memory,sp,32,False)==status
    assert extract(memory,(sp+32)&MASK32,32,False)==(target&~15)|low
    return row


def interrupt_return_cases():
    for off,offset,flags,ie in product((False,True),range(16),range(16),(0,1)):
        yield reti_fixture(f'o{offset}_flags{flags}_ie{ie}',off,offset,flags,
                           restored=0x810|(flags<<28)|(ie<<21))
    for off,field,width,fe in product((False,True),(0,1),range(1,33),(0,1)):
        old=(0x60200810&~(63<<(6*field)))|(((width&31)|(fe<<5))<<(6*field))
        yield reti_fixture(f'ignored_f{field}_w{width}_fe{fe}',off,15,initial=old,restored=0xC0000010)
    for off,offset,low in product((False,True),(0,15),range(16)):
        yield reti_fixture(f'low{low}_o{offset}',off,offset,low=low)
    for off,alignment in product((False,True),range(4)):
        yield reti_fixture(f'phase_a{alignment}',off,15,15,alignment=alignment)
    for off,target in product((False,True),(0,0x80010000,0xFFFF0000)):
        yield reti_fixture(f'high_{target:08x}',off,15,target=target)
    for off in (False,True):
        yield reti_fixture('wrap_ffffffd0',off,address=0xFFFFFFD0,target=0x10000,restored=0x10000810)
        yield reti_fixture('wrap_fffffff0',off,address=0xFFFFFFF0,restored=0xC0000000)
        yield reti_fixture('guide',off,address=0x0CCC0000,target=0x0044FFF0,restored=0xC0000010)
    for previous in rets_following_cases():
        old=previous['expected_st'];sp=previous['initial_sp']
        row=reti_fixture(previous['name'].removeprefix('stack_rets_').removesuffix('_hit'),False,
                         address=sp,restored=old)
        for k in ('initial_b_regs','observe_implicit','target_opcode','expected_next_opcode','drain_instructions',
                  'control_follow','expected_follow_st'):
            row[k]=previous[k]
        row['regs']=list(previous['regs']);row['regs'][3]=row['conditions']['initial_status']
        row['expected_regs']=list(row['regs'])
        row['expected_extra_regs']=dict(previous['expected_extra_regs']);row['expected_extra_regs']['sp']=(sp+64)&MASK32
        row['initial_memory'] += [q for q in previous['initial_memory'] if q[0]>=0x6000]
        row['expected_memory']=row['initial_memory'];row['expected_follow_memory']=row['initial_memory']
        row['control_follow']['initial_memory']=row['initial_memory']
        row['expected_follow_regs']=list(previous['expected_follow_regs']);row['expected_follow_regs'][3]=row['regs'][3]
        row['expected_follow_extra_regs']=dict(previous['expected_follow_extra_regs']);row['expected_follow_extra_regs']['sp']=(sp+64)&MASK32
        yield row
