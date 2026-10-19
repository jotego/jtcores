#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""PIXT *Rs,*Rd replace PMASK0/T0: SPVU001A7-10,12-220/221.

Aligned pixels only. The p12-221 PS16/destination20508 example conflicts
with the explicit alignment rule; retain as an excluded source ambiguity.
"""
from itertools import product
from pixel_store_cases import fixture as replace_fixture,following
from pixel_boolean_cases import program
from store_cases import insert,transactions
from load_cases import extract


def fixture(size,src_lane,dst_lane,bank,off,*,source_address=None,destination_address=None,source_word=0xA596,destination_word=0x35C6,source=2,pointer=0,**kwargs):
    if src_lane not in range(0,16,size):raise ValueError('aligned source pixel required')
    sa=(0x5000+src_lane if source_address is None else source_address)&0xFFFFFFFF
    da=(0x6000+dst_lane if destination_address is None else destination_address)&0xFFFFFFFF
    if sa%size:raise ValueError('pixel-aligned source required')
    if source==pointer:sa=da
    row=replace_fixture(size,dst_lane,bank,off,source=source,pointer=pointer,address=da,value=sa,**kwargs)
    row.pop('pixel_store')
    # Same-word source/destination observes one original image.
    memory=dict(row['initial_memory']);memory[da&~15]=destination_word;memory[sa&~15]=source_word
    memory=sorted(memory.items());value=extract(memory,sa,size,False)
    row.update(name=row['name'].replace(f'pixel_store_ps{size}_o{dst_lane}_',f'pixel_copy_ps{size}_s{src_lane}_d{dst_lane}_'),
        coverage_id='PIXT_LIN_LIN',opcode=0xFC00|(source<<5)|(bank<<4)|pointer,pixel_processing=True,pixel_copy=True,
        measure_pass=0,initial_memory=memory,memory_before_measured=memory,expected_memory=insert(memory,da,size,value),
        citation='SPVU001A7-10;12-220/221')
    row['data_store'].update(cpu=4,value=value,mode='pixel_copy')
    row['data_copy']=dict(source=sa,destination=da,width=size,cpu=4,read_lead=1,write_start=3)
    row['hidden_states']=2*len(transactions(row))-1;row['states']=4+(row['hidden_states']+3 if off else 0)
    row['conditions'].update(source_address=sa,destination_address=da,source_lane=sa&15,destination_lane=da&15)
    return row


def pixel_copy_cases():
    for size in (1,2,4,8,16):
        for so,do,bank,off in product(range(0,16,size),range(0,16,size),(0,1),(False,True)):
            yield fixture(size,so,do,bank,off)
        for so,do,bank,off in product(range(0,16,size),range(0,16,size),(0,1),(False,True)):
            yield fixture(size,so,do,bank,off,destination_address=0x5000+do,tag='same_word')
        for reg,bank,off in product(range(16),(0,1),(False,True)):
            yield fixture(size,0,16-size,bank,off,source=reg,pointer=1 if reg!=1 else 0,tag=f'source{reg}')
            yield fixture(size,0,16-size,bank,off,source=2,pointer=reg,tag=f'pointer{reg}')
            yield fixture(size,0,16-size,bank,off,source=reg,pointer=reg,tag=f'alias{reg}')
        for field,width,fe,off in product((0,1),range(1,33),(0,1),(False,True)):
            status=(0xF2200810&~(63<<(6*field)))|(((width&31)|(fe<<5))<<(6*field))
            yield fixture(size,0,16-size,0,off,status=status,tag=f'ignored_f{field}_w{width}_fe{fe}')
        for flags,ie,off in product(range(16),(0,1),(False,True)):
            yield fixture(size,0,16-size,0,off,status=(flags<<28)|(ie<<21)|0x810,tag=f'flags{flags}_ie{ie}')
        for bank,off,alignment in product((0,1),(False,True),range(4)):
            yield fixture(size,0,16-size,bank,off,alignment=alignment,tag=f'phase_{alignment}')
        for source_word,dest_word,off in product((0,0xFFFF,0x5555,0xAAAA),(0,0xFFFF,0x5555,0xAAAA),(False,True)):
            yield fixture(size,0,16-size,0,off,source_word=source_word,destination_word=dest_word,tag=f'values_s{source_word:04x}_d{dest_word:04x}')
        for window,corner,off in product(range(4),range(4),(False,True)):
            yield fixture(size,0,16-size,0,off,control=(window<<6)|(corner<<8),tag=f'ignored_w{window}_corner{corner}')
        for sa,da,off in product((0,0x80000000,0xFFFFFFD0),(0,0x80000000,0xFFFFFFD0),(False,True)):
            yield fixture(size,0,0,0,off,source_address=sa,destination_address=da,tag=f'addresses_s{sa:08x}_d{da:08x}')
        for bank,delay in product((0,1),(0,1,2,3,7,10,20)):
            yield following(fixture(size,0,16-size,bank,False,status=(0xF0200810&~63)|size,tag=f'follow_k{delay}'),delay)
    # Literal aligned examples on12-221; PS16/dst20508 is explicitly excluded.
    for size,word,want in ((1,0xF,0x10F),(2,0xF,0x30F),(4,0xF,0xF0F),(8,0xEF,0xEFEF)):
        for off in (False,True):
            row=fixture(size,0,8,0,off,source_address=0x20500,destination_address=0x20508,source=0,pointer=1,source_word=word,tag='literal')
            assert dict(row['expected_memory'])[0x20500]==want
            yield row
