#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""PIXT Rs,*Rd replace, PMASK0/T0: SPVU001A12-213/214.

Initial subset only; Boolean/arithmetic/masking/transparency use the existing
functional graphics path until their exact timing is implemented and tested.
"""
from itertools import product
from pixel_read_cases import program as pixel_program
from store_cases import insert,transactions


def fixture(size,lane,bank,off,*,source=2,pointer=0,value=0xE1709B6D,status=0xF0200810,tag='base',control=0,alignment=None,address=None):
    if size not in (1,2,4,8,16) or lane not in range(0,16,size):raise ValueError('legal aligned pixel required')
    address=0x6000+lane if address is None else address
    if address%size:raise ValueError('linear pixel address must be aligned')
    if control&0x7C20:raise ValueError('prototype timing subset is replace/T0')
    seed=0x13579B00
    regs={f'a{q}':seed+q for q in range(15)};regs.update({f'b{q}':seed+16+q for q in range(15)});regs['sp']=seed+15
    key=lambda q:'sp' if q==15 else f'{"b" if bank else "a"}{q}'
    holder=next(q for q in range(3,7) if bank or q not in (source,pointer))
    overrides={key(source):value,key(pointer):address};regs.update(overrides);regs[f'a{holder}']=status
    memory=[(address&~15,0xA596),(0x6500,0xBEEF),(0x6600,0x35C6)]
    final=insert(memory,address,size,regs[key(source)])
    row=dict(name=f'pixel_store_ps{size}_o{lane}_r{bank}_{tag}_{"off" if off else "hit"}',coverage_id='PIXT_R_LIN',opcode=0xF800|(source<<5)|(bank<<4)|pointer,
        regs=[regs[f'a{q}'] for q in range(4)],expected_regs=[regs[f'a{q}'] for q in range(4)],
        expected_extra_regs={k:v for k,v in regs.items() if k not in ('a0','a1','a2','a3')},observe_all=True,
        initial_all_regs=regs,seed=seed,status_holder=holder,source_register=pointer,bank=bank,register_overrides=overrides,
        expected_st=status,cache_disabled=off,pixel_store=True,initial_memory=memory,expected_memory=final,
        data_store=dict(address=address,width=size,value=regs[key(source)],cpu=2,mode='pixel_replace'),
        setup_io=[(0xC0000150,size),(0xC0000160,0)],control=control,drain_instructions=-1 if off else 12,
        citation='SPVU001A12-213/214',conditions=dict(size=size,lane=lane,bank=bank,source=source,pointer=pointer,ppop=0,pmask=0,transparency=False))
    if alignment is not None:row['instruction_word_offset']=alignment
    row['hidden_states']=2*len(transactions(row))-1;row['states']=2+(row['hidden_states']+3 if off else 0)
    return row


def program(case,movi):
    proxy=dict(case,data_load=dict(address=case['data_store']['address']))
    if 'follow_delay' in case:
        proxy['following_words']=[0x0300]*case['follow_delay']+[case['follow_opcode']]+[0x0300]*4
    else:proxy['following_words']=[0x0300]*16
    return pixel_program(proxy,movi)


def following(case,delay):
    from load_cases import extract
    bank=case['bank'];pointer=case['source_register'];dest=1 if pointer==0 else 0
    value=extract(case['expected_memory'],case['data_store']['address'],case['data_store']['width'],False)
    case.update(follow_delay=delay,follow_opcode=0x8400|(pointer<<5)|(bank<<4)|dest,drain_instructions=delay+2)
    case['expected_follow_regs']=list(case['expected_regs']);extra=dict(case['expected_extra_regs'])
    if bank:extra[f'b{dest}']=value
    else:case['expected_follow_regs'][dest]=value
    case['expected_follow_extra_regs']=extra
    case['expected_follow_st']=(case['expected_st']&~0xB0000000)|(0x20000000 if not value else 0)
    return case


def pixel_store_cases():
    for size in (1,2,4,8,16):
        for lane,bank,off in product(range(0,16,size),(0,1),(False,True)):
            yield fixture(size,lane,bank,off)
        for field,width,fe,off in product((0,1),range(1,33),(0,1),(False,True)):
            status=(0xF2200810&~(63<<(6*field)))|(((width&31)|(fe<<5))<<(6*field))
            yield fixture(size,16-size,0,off,status=status,tag=f'ignored_f{field}_w{width}_fe{fe}')
        for flags,ie,off in product(range(16),(0,1),(False,True)):
            yield fixture(size,0,0,off,status=(flags<<28)|(ie<<21)|0x810,tag=f'flags{flags}_ie{ie}')
        for value,bank,off in product((0,0xFFFFFFFF,0x55555555,0xAAAAAAAA,1,0x80000000),(0,1),(False,True)):
            yield fixture(size,16-size,bank,off,value=value,tag=f'value{value:08x}')
        for reg,bank,off in product(range(16),(0,1),(False,True)):
            yield fixture(size,0,bank,off,source=reg,pointer=1 if reg!=1 else 0,tag=f'source{reg}')
            yield fixture(size,0,bank,off,source=2,pointer=reg,tag=f'pointer{reg}')
        for bank,off,alignment in product((0,1),(False,True),range(4)):
            yield fixture(size,0,bank,off,alignment=alignment,tag=f'phase_{alignment}')
        for window,corner,off in product(range(4),range(4),(False,True)):
            yield fixture(size,0,0,off,control=(window<<6)|(corner<<8),tag=f'ignored_w{window}_corner{corner}')
        for address,off in product((0,0x80000000,0xFFFFFFD0),(False,True)):
            yield fixture(size,0,0,off,address=address,tag=f'address{address:08x}')
        for bank,delay in product((0,1),(0,1,2,3,7,10,20)):
            row=fixture(size,16-size,bank,False,status=(0xF0200810&~63)|size,tag=f'follow_k{delay}')
            yield following(row,delay)
