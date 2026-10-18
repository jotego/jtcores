#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""PUSHST base/hidden counts from SPVU001A p12-228."""
from itertools import product
from store_cases import fixture,insert


def push_fixture(tag,off,offset=0,status=0xC0000010,*,address=None,alignment=0):
    address=(0x6000+offset if address is None else address)&0xFFFFFFFF
    offset=address&15
    row=fixture('pre',32,offset,0,off,0,dest=15,base=address&~15)
    reset={0xFFFFFFE0:0x1000,0xFFFFFFF0:0}
    row['initial_memory']=[(a,reset.get(a,v)) for a,v in row['initial_memory']]
    row.update(name=f'stack_pushst_{tag}_{"off" if off else "hit"}',coverage_id='PUSHST',opcode=0x01E0,
        expected_st=status,hidden_states=8 if offset else 3,states=2+((11 if offset else 6) if off else 0),
        citation='SPVU001A12-228; SPVS002C June1991p14')
    row['regs'][3]=status;row['expected_regs'][3]=status
    data=row['data_store'];data.update(value=status,write_start=0 if offset else 1,reverse=True)
    row['expected_memory']=insert(row['initial_memory'],data['address'],32,status)
    row['instruction_word_offset']=alignment
    row['conditions']=dict(stack_alignment=offset,status=status,target=address,initial_sp=row['initial_sp'],opcode_offset=alignment)
    return row


def push_cases():
    for off,offset,flags,ie in product((False,True),range(16),range(16),(0,1)):
        yield push_fixture(f'o{offset}_flags{flags}_ie{ie}',off,offset,(flags<<28)|(ie<<21)|0x810)
    for off,field,width,fe in product((False,True),(0,1),range(1,33),(0,1)):
        status=(0x60200810&~(63<<(6*field)))|(((width&31)|(fe<<5))<<(6*field))
        yield push_fixture(f'ignored_f{field}_w{width}_fe{fe}',off,15,status)
    for off,address in product((False,True),(0x80006000,0xFFFF600F,0xFFFFFFF0,0xFFFFFFF8)):
        yield push_fixture(f'address_{address:08x}',off,address=address)
    for off,alignment in product((False,True),range(4)):
        yield push_fixture(f'phase_a{alignment}',off,15,alignment=alignment)
    for off in (False,True):
        # Numeric output words at the address required by ST -> *(SP-32).
        # Printed example address labels are shifted16; not validated here.
        yield push_fixture('numeric_semantics',off,address=0x0FF00000)
    for source,offset,delay in product((0,15),range(16),(0,1,2,3,7,10,20)):
        status=((offset&15)<<28)|0x00200800
        row=push_fixture(f'following_s{source}_o{offset}_k{delay}',False,offset,status)
        target=row['data_store']['address']
        row['regs'][0]=target;row['expected_regs'][0]=target
        row['follow_delay']=delay;row['following_words']=[0x0300]*delay+[0x8401|(source<<5)]+[0x0300]*32
        row['drain_instructions']=24+delay
        for q in (4,5,6):
            value=0xB0102030+q*0x1020304
            row['initial_b_regs'][q]=value;row['expected_extra_regs']['b'+str(q)]=value
        row['observe_implicit']=True
        row['expected_follow_extra_regs']=dict(row['expected_extra_regs'])
        row['expected_follow_regs']=list(row['expected_regs']);row['expected_follow_regs'][1]=status
        row['expected_follow_st']=(status&~0xB0000000)|(status&0x80000000)|(0x20000000 if not status else 0)
        yield row
