#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""PIXT Rs,*Rd Boolean PPOP1..15, PMASK0/T0: SPVU001A7-15,12-213/214.

A cache-prefill route skips the write. Measure the first execution so XOR,
complement and other non-idempotent operations see the specified old pixel.
"""
from itertools import product
from pixel_store_cases import fixture as replace_fixture, following
from pixel_read_cases import program as read_program
from store_cases import insert, transactions
from load_cases import extract


def boolean(ppop,source,destination,size):
    if ppop not in range(16) or size not in (1,2,4,8,16):raise ValueError('Boolean pixel domain')
    s,d=source,destination
    # Explicit TI Table7-1 expressions, independent of RTL truth-table encoding.
    values=(s,s&d,s&~d,0,s|~d,~(s^d),~d,~(s|d),s|d,d,s^d,~s&d,-1,~s|d,~(s&d),~s)
    return values[ppop]&((1<<size)-1)


def fixture(size,lane,bank,off,*,ppop=10,destination_word=0xA596,**kwargs):
    if ppop not in range(1,16):raise ValueError('non-replace Boolean PPOP required')
    row=replace_fixture(size,lane,bank,off,**kwargs)
    address=row['data_store']['address'];row.pop('pixel_store')
    memory=[(a,destination_word if a==address&~15 else v) for a,v in row['initial_memory']]
    source=row['data_store']['value'];dest=extract(memory,address,size,False)
    value=boolean(ppop,source,dest,size)
    row.update(name=row['name'].replace('pixel_store_',f'pixel_boolean_pp{ppop}_'),pixel_processing=True,measure_pass=0,
        control=row['control']|(ppop<<10),initial_memory=memory,memory_before_measured=memory,
        expected_memory=insert(memory,address,size,value),citation='SPVU001A7-15 Table7-1;12-213/214')
    row['conditions'].update(ppop=ppop,destination_word=destination_word,source_value=source)
    row['data_store'].update(cpu=4,value=value,mode='pixel_boolean')
    row['data_copy']=dict(source=address,destination=address,width=size,cpu=4,read_lead=1,write_start=3)
    row['hidden_states']=2*len(transactions(row))-1
    row['states']=4+(row['hidden_states']+3 if off else 0)
    return row


def program(case,movi):
    # Reuse only the initialization, stopping before the original measured op.
    proxy=dict(case,data_load=dict(address=case['data_store']['address']))
    words,old_pc,_=read_program(proxy,movi);words=words[:(old_pc-0x1000)//16]
    # JA operands or the skipped-to tail warm the opcode's four-word segment.
    # The final NOP before PIXT gives the usual previous-opcode boundary.
    offset=case.get('instruction_word_offset',0)
    while (len(words)+4)%4!=offset:words.append(0x0300)
    jump=len(words);words += [0xC080,0,0,0x0300]
    start=0x1000+16*len(words);words.append(case['opcode']);next_pc=start+16
    words[jump+1:jump+3]=[next_pc&65535,next_pc>>16]
    if 'follow_delay' in case:
        words += [0x0300]*case['follow_delay']+[case['follow_opcode']]+[0x0300]*16
        dest=case['follow_opcode']&15;bank=(case['follow_opcode']>>4)&1
        key='sp' if dest==15 else f'{"b" if bank else "a"}{dest}'
        words += movi(case['initial_all_regs'][key],dest+(16 if bank and dest!=15 else 0))
    else:words += [0x0300]*16
    words += [0x01A0|case['status_holder'],0xC080,(start-16)&65535,(start-16)>>16]
    # Only route-to-PIXT/tail tags matter after initialization.
    if (len(words)-1)//32-jump//32>=4:raise ValueError('Boolean prefill exceeds warm cache tags')
    return words,start,next_pc


def pixel_boolean_cases():
    for ppop,size in product(range(1,16),(1,2,4,8,16)):
        for lane,bank,off in product(range(0,16,size),(0,1),(False,True)):
            yield fixture(size,lane,bank,off,ppop=ppop)
        for source_word,dest_word,off in product((0,0xFFFF,0x5555,0xAAAA),(0,0xFFFF),(False,True)):
            yield fixture(size,16-size,0,off,ppop=ppop,value=source_word,destination_word=dest_word,
                tag=f'values_s{source_word:04x}_d{dest_word:04x}')
    for size in (1,2,4,8,16):
        for reg,bank,off in product(range(16),(0,1),(False,True)):
            pp=1+reg%15
            yield fixture(size,0,bank,off,ppop=pp,source=reg,pointer=1 if reg!=1 else 0,tag=f'source{reg}')
            yield fixture(size,0,bank,off,ppop=pp,source=2,pointer=reg,tag=f'pointer{reg}')
            yield fixture(size,16-size,bank,off,ppop=pp,source=reg,pointer=reg,tag=f'alias{reg}')
        for field,width,fe,off in product((0,1),range(1,33),(0,1),(False,True)):
            status=(0xF2200810&~(63<<(6*field)))|(((width&31)|(fe<<5))<<(6*field))
            yield fixture(size,16-size,0,off,ppop=1+(width+fe+field)%15,status=status,tag=f'ignored_f{field}_w{width}_fe{fe}')
        for flags,ie,off in product(range(16),(0,1),(False,True)):
            yield fixture(size,0,0,off,ppop=1+flags%15,status=(flags<<28)|(ie<<21)|0x810,tag=f'flags{flags}_ie{ie}')
        for ppop,bank,off,alignment in product((1,10,15),(0,1),(False,True),range(4)):
            yield fixture(size,0,bank,off,ppop=ppop,alignment=alignment,tag=f'phase_{alignment}')
        for window,corner,off in product(range(4),range(4),(False,True)):
            yield fixture(size,0,0,off,ppop=1+(window+corner*4)%15,control=(window<<6)|(corner<<8),tag=f'ignored_w{window}_corner{corner}')
        for address,off in product((0,0x80000000,0xFFFFFFD0),(False,True)):
            yield fixture(size,0,0,off,ppop=15,address=address,tag=f'address{address:08x}')
        for ppop,bank,delay in product((1,10,15),(0,1),(0,1,2,3,7,10,20)):
            yield following(fixture(size,16-size,bank,False,ppop=ppop,status=(0xF0200810&~63)|size,tag=f'follow_k{delay}'),delay)
    for ppop,dest,want in ((10,0x0300,0x0500),(1,0x0100,0)):
        for off in (False,True):
            row=fixture(4,8,0,off,ppop=ppop,source=0,pointer=1,value=6,address=0x20508,destination_word=dest,tag='literal')
            assert dict(row['expected_memory'])[0x20500]==want
            yield row
