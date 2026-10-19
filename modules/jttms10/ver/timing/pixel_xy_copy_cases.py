#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""PIXT *Rs.XY,*Rd.XY replace/PMASK0/T0/W0: SPVU001A12-224..226."""
from itertools import product
from pixel_copy_cases import fixture as linear_fixture
from pixel_xy_store_cases import following
from coordinate_cases import linear
from store_cases import insert,transactions
from load_cases import extract


def fixture(size,src_lane,dst_lane,bank,off,*,source_point=None,destination_point=None,offset=0x6000,convsp=20,convdp=22,source=2,pointer=0,source_word=0xA596,destination_word=0x35C6,control=0,**kwargs):
    if control&0xC0:raise ValueError('initial XY-copy timing subset requires W0')
    source_point=(0x10000|src_lane//size) if source_point is None else source_point
    destination_point=(0x20000|dst_lane//size) if destination_point is None else destination_point
    row=linear_fixture(size,src_lane,dst_lane,bank,off,source=source,pointer=pointer,control=control,**kwargs)
    regs=row['initial_all_regs'];key=lambda q:'sp' if q==15 else f'{"b" if bank else "a"}{q}'
    overrides={key(source):source_point,'b1':1<<(31-(convsp&31)),'b3':1<<(31-(convdp&31)),'b4':offset,key(pointer):destination_point}
    regs.update(overrides);sa=linear(regs[key(source)],regs['b4'],size,convsp);da=linear(regs[key(pointer)],regs['b4'],size,convdp)
    if sa%size or da%size:raise ValueError('pixel-aligned converted source/destination required')
    memory={0x6500:0xBEEF,0x6600:0x35C6,da&~15:destination_word,sa&~15:source_word};memory=sorted(memory.items())
    value=extract(memory,sa,size,False)
    row.update(name=row['name'].replace('pixel_copy_','pixel_xy_copy_'),opcode=0xF400|(source<<5)|(bank<<4)|pointer,
        coverage_id='PIXT_XY_XY',pixel_xy_copy=True,register_overrides=overrides,source_value=regs[key(pointer)],
        initial_memory=memory,memory_before_measured=memory,expected_memory=insert(memory,da,size,value),
        citation='SPVU001A12-224..226;4-12')
    row['regs']=[regs[f'a{q}'] for q in range(4)];row['expected_regs']=list(row['regs'])
    row['expected_extra_regs']={k:v for k,v in regs.items() if k not in ('a0','a1','a2','a3')}
    row['data_store'].update(address=da,cpu=7,write_start=6,value=value,mode='pixel_xy_copy')
    row['data_copy'].update(source=sa,destination=da,cpu=7,read_lead=3,write_start=6)
    row['hidden_states']=2*len(transactions(row))-1;row['states']=7+(row['hidden_states']+3 if off else 0)
    row['setup_io'] += [(0xC0000130,convsp),(0xC0000140,convdp)]
    row['conditions'].update(source_point=regs[key(source)],destination_point=regs[key(pointer)],offset=regs['b4'],convsp=convsp,convdp=convdp,source_address=sa,destination_address=da,window=0)
    return row


def pixel_xy_copy_cases():
    for size in (1,2,4,8,16):
        for so,do,bank,off in product(range(0,16,size),range(0,16,size),(0,1),(False,True)):
            yield fixture(size,so,do,bank,off)
        for so,do,bank,off in product(range(0,16,size),range(0,16,size),(0,1),(False,True)):
            yield fixture(size,so,do,bank,off,source_point=0x10000|so//size,destination_point=0x10000|do//size,convdp=20,tag='same_word')
        for conv,q,off in product(range(32),range(5),(False,True)):
            y=(0,16,-16,32752,-32768)[q];x=(0,1,31,48,32767)[q]
            yield fixture(size,0,0,(conv+q)&1,off,source_point=((y&65535)<<16)|x,destination_point=0x200010,
                convsp=conv,convdp=(conv+7)&31,tag=f'source_pitch{conv}_point{q}')
            yield fixture(size,0,0,(conv+q)&1,off,source_point=0x100010,destination_point=((y&65535)<<16)|x,
                convsp=(conv+7)&31,convdp=conv,tag=f'destination_pitch{conv}_point{q}')
        for reg,bank,off in product(range(16),(0,1),(False,True)):
            yield fixture(size,0,0,bank,off,source=reg,pointer=1 if reg!=1 else 0,source_point=0x10010,destination_point=0x20020,tag=f'source{reg}')
            yield fixture(size,0,0,bank,off,source=2,pointer=reg,source_point=0x10010,destination_point=0x20020,tag=f'pointer{reg}')
            yield fixture(size,0,0,bank,off,source=reg,pointer=reg,source_point=0x10010,destination_point=0x20020,tag=f'alias{reg}')
        for field,width,fe,off in product((0,1),range(1,33),(0,1),(False,True)):
            status=(0xF2200810&~(63<<(6*field)))|(((width&31)|(fe<<5))<<(6*field))
            yield fixture(size,0,16-size,0,off,status=status,tag=f'ignored_f{field}_w{width}_fe{fe}')
        for flags,ie,off in product(range(16),(0,1),(False,True)):
            yield fixture(size,0,16-size,0,off,status=(flags<<28)|(ie<<21)|0x810,tag=f'flags{flags}_ie{ie}')
        for bank,off,alignment in product((0,1),(False,True),range(4)):
            yield fixture(size,0,16-size,bank,off,alignment=alignment,tag=f'phase_{alignment}')
        for sw,dw,off in product((0,0xFFFF,0x5555,0xAAAA),(0,0xFFFF,0x5555,0xAAAA),(False,True)):
            yield fixture(size,0,16-size,0,off,source_word=sw,destination_word=dw,tag=f'values_s{sw:04x}_d{dw:04x}')
        for corner,off in product(range(4),(False,True)):
            yield fixture(size,0,0,0,off,control=corner<<8,tag=f'ignored_corner{corner}')
        for offset,off in product((0,0x80000000,0xFFFFFF00),(False,True)):
            yield fixture(size,0,0,0,off,source_point=0x10010,destination_point=0x20020,offset=offset,tag=f'offset{offset:08x}')
        for bank,delay in product((0,1),(0,1,2,3,7,10,20)):
            yield following(fixture(size,0,16-size,bank,False,status=(0xF0200810&~63)|size,tag=f'follow_k{delay}'),delay)
    for size,sx,dx,word,want in ((1,0x500,0x508,0xF,0x10F),(2,0x280,0x284,0xF,0x30F),
            (4,0x140,0x142,0xF,0xF0F),(8,0xA0,0xA1,0xEF,0xEFEF),(16,0x50,0x51,0xCDEF,0xCDEF)):
        for off in (False,True):
            row=fixture(size,0,0,0,off,source_point=0x400000|sx,destination_point=0x400000|dx,
                offset=0,convsp=20,convdp=20,source=0,pointer=1,source_word=word,tag='literal')
            assert row['data_copy']['source']==0x20500
            assert row['data_copy']['destination']==(0x20510 if size==16 else 0x20508)
            assert dict(row['expected_memory'])[0x20510 if size==16 else 0x20500]==want
            yield row
