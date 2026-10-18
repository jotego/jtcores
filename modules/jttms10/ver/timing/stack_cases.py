#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Stack reads, independent bit-addressed model: SPVU001A p12-227."""
from itertools import product
from alu_cases import initial_status
from load_cases import extract
from store_cases import insert
from oracle import load_states

MASK32=(1<<32)-1


def popst_fixture(tag,off,offset=0,flags=0,*,initial=None,loaded=None,address=None,alignment=0):
    old=initial_status(flags+7) if initial is None else initial
    value=((flags&15)<<28)|((flags&1)<<21)|0x810 if loaded is None else loaded
    sp=(0x5000+offset if address is None else address)&MASK32
    addresses=sorted({((sp+bit)&MASK32)&~15 for bit in range(32)})
    memory=insert([(a,0xA55A) for a in addresses],sp,32,value)
    # Wrapped stack words may share reset-vector high; keep reset PC1000h.
    memory=[(a,0 if a==0xFFFFFFF0 else v) for a,v in memory]
    value=extract(memory,sp,32,False)
    regs=[0x11223344,0x55667788,0x99AABBCC,old]
    b={q:0xB0102030+q*0x1020304 for q in range(4)}
    return dict(name=f'stack_popst_{tag}_{"off" if off else "hit"}',coverage_id='POPST',opcode=0x01C0,
        regs=regs,expected_regs=list(regs),initial_b_regs=b,initial_sp=sp,
        expected_extra_regs={**{f'b{q}':v for q,v in b.items()},'sp':(sp+32)&MASK32},
        expected_st=value,cache_disabled=off,states=8+2*bool(sp&15)+3*off,
        initial_memory=memory,expected_memory=memory,drain_instructions=-1,
        data_load=dict(address=sp,width=32,mode='stack'),stack_load='POPST',
        instruction_word_offset=alignment,citation='SPVU001A12-227; summary12-17; SPVS002C June1991p14',
        conditions=dict(source=sp,stack_alignment=sp&15,initial_status=old,restored_status=value))


def stack_cases():
    for off,offset,flags in product((False,True),range(16),range(16)):
        yield popst_fixture(f'o{offset}_flags{flags}',off,offset,flags)
    for off,field,width,fe in product((False,True),(0,1),range(1,33),(0,1)):
        old=(0xF0200810&~(63<<(6*field)))|(((width&31)|(fe<<5))<<(6*field))
        yield popst_fixture(f'ignored_f{field}_w{width}_fe{fe}',off,15,initial=old,loaded=0x60000010)
    for off,alignment in product((False,True),range(4)):
        yield popst_fixture(f'phase_a{alignment}',off,15,15,alignment=alignment)
    for off,address in product((False,True),(0xFFFFFFF0,0xFFFFFFF8)):
        yield popst_fixture(f'wrap_{address:08x}',off,address=address,loaded=0xF0200000)
    for off in (False,True):
        yield popst_fixture('guide',off,address=0x0FF00000,loaded=0xC0000010)
    yield from following_cases()


def following_cases():
    for width,fe,stack_offset,source_offset in product((1,16,32),(0,1),(0,15),(0,15)):
        restored=0xF0200800|(width&31)|(fe<<5)
        row=popst_fixture(f'following_w{width}_fe{fe}_sp{stack_offset}_o{source_offset}',False,
                           stack_offset,loaded=restored)
        address=0x6000+source_offset
        row['regs'][2]=address;row['expected_regs'][2]=address
        memory=row['initial_memory']+[(0x6000,0x9B6D),(0x6010,0xA596),(0x6020,0x35C6)]
        row.update(initial_memory=memory,expected_memory=memory,expected_follow_memory=memory,
                   following_words=[0x8441]+[0x0300]*32,drain_instructions=2,
                   control_follow=dict(kind='stack-follow-load',states=load_states(address=address,width=width,signed=bool(fe)),
                                       transfers=((address&15)+width+15)//16,
                                       data_load=dict(address=address,width=width),initial_memory=memory))
        value=extract(memory,address,width,bool(fe))
        row['expected_follow_regs']=list(row['expected_regs']);row['expected_follow_regs'][1]=value
        row['expected_follow_st']=(restored&~0xB0000000)|(value&0x80000000)|(0x20000000 if not value else 0)
        yield row
