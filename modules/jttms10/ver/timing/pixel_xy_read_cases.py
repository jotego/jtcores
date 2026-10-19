#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""PIXT *Rs.XY,Rd: SPVU001A12-222/223 and conversion4-12/7.3."""
from itertools import product
from coordinate_cases import linear
from pixel_read_cases import fixture as linear_fixture, pixel_value, following


def fixture(size,lane,bank,off,*,point=None,offset=0x6000,conv=20,pmask=0,status=0xF0200810,
            source=2,destination=0,word=0xA596,control=0,alignment=None,tag='base',cold=False):
    point=(0x10000|lane//size) if point is None else point
    if bank and source==4:offset=point  # Rs and implied OFFSET are one register.
    address=linear(point,offset,size,conv)
    if address%size:raise ValueError('converted address must be pixel aligned')
    row=linear_fixture(size,address&15,bank,off,pmask=pmask,status=status,address=address,source=source,
        destination=destination,source_word=word,control=control,alignment=alignment,tag=tag,cold=cold)
    row.update(name=f'pixel_xy_read_ps{size}_o{lane}_r{bank}_{tag}_{"off" if off else "hit"}',coverage_id='PIXT_XY_R',opcode=0xF200|(source<<5)|(bank<<4)|destination,
        states=15 if cold else 9 if off else 6,source_value=point,register_overrides=dict(b4=offset,b1=1<<(31-(conv&31))),citation='SPVU001A12-222/223;4-12;7.3')
    row['data_load']['mode']='pixel_xy'
    row['setup_io'] += [(0xC0000130,conv),(0xC0000140,(conv+7)&31)]
    row['conditions'].update(point=point,offset=offset,convsp=conv,convdp=(conv+7)&31)
    registers=row['initial_all_regs'];registers.update(row['register_overrides'])
    key=lambda q:'sp' if q==15 else f'{"b" if bank else "a"}{q}'
    registers[key(source)]=point
    expected=dict(registers);expected[key(destination)]=pixel_value(word,size,address&15,pmask)
    row['regs']=[registers[f'a{q}'] for q in range(4)];row['expected_regs']=[expected[f'a{q}'] for q in range(4)]
    row['expected_extra_regs']={k:v for k,v in expected.items() if k not in ('a0','a1','a2','a3')}
    return row


def pixel_xy_read_cases():
    sizes=(1,2,4,8,16)
    for size in sizes:
        for lane,bank,off in product(range(0,16,size),(0,1),(False,True)):
            yield fixture(size,lane,bank,off)
        for lane,off,mask in product(range(0,16,size),(False,True),[1<<q for q in range(16)]+[0xFFFF,0x5555,0xAAAA]):
            yield fixture(size,lane,0,off,pmask=mask,tag=f'mask{mask:04x}')
        for conv,q,off in product(range(32),range(5),(False,True)):
            y=(0,16,-16,32752,-32768)[q];x=(0,1,31,48,32767)[q]
            yield fixture(size,0,(conv+q)&1,off,point=((y&65535)<<16)|x,conv=conv,tag=f'pitch{conv}_point{q}')
        for field,width,fe,off in product((0,1),(1,8,16,31,32),(0,1),(False,True)):
            status=(0xF2200810&~(63<<(6*field)))|(((width&31)|(fe<<5))<<(6*field))
            yield fixture(size,0,0,off,status=status,tag=f'ignored_f{field}_w{width}_fe{fe}')
        for source,dest in ((0,14),(14,0),(15,0),(0,15),(3,3),(7,7),(15,15),(4,0),(0,4)):
            for bank,off in product((0,1),(False,True)):
                yield fixture(size,0,bank,off,point=0x10010,source=source,destination=dest,tag=f'identity_s{source}_d{dest}')
        for flags,ie,off in product(range(16),(0,1),(False,True)):
            yield fixture(size,0,0,off,status=(flags<<28)|(ie<<21)|0x810,pmask=65535 if flags&1 else 0,tag=f'flags{flags}_ie{ie}')
        for ppop,window,off in product((0,1,16,21),range(4),(False,True)):
            yield fixture(size,0,0,off,control=(ppop<<10)|(window<<6)|0x20,tag=f'ignored_pp{ppop}_w{window}_t1')
        for bank,off,alignment in product((0,1),(False,True),range(4)):
            yield fixture(size,0,bank,off,alignment=alignment,tag=f'phase_{alignment}')
        for offset,off in product((0,0x80000000,0xFFFFFF00),(False,True)):
            yield fixture(size,0,0,off,point=0x10010,offset=offset,tag=f'offset{offset:08x}')
        for bank,unaligned in product((0,1),(False,True)):
            row=fixture(size,0,bank,False,source=7,destination=6,tag=f'follow_b{bank}_u{int(unaligned)}')
            overrides=dict(row['register_overrides']);row=following(row,bank,unaligned);row['register_overrides']={**overrides,**row['register_overrides']}
            yield row
        yield fixture(size,0,0,False,cold=True,tag='cold_next')
    # p12-223 labels B3/DPTCH and A1 in prose, but says source CONVSP and
    # encodes *A0.XY,A1. Numeric source, memory and outputs agree with §4.2.
    examples=((1,0x500,0,1),(1,0x500,65535,0),(2,0x280,0,3),(2,0x280,0xAAAA,1),
        (4,0x140,0,15),(4,0x140,0x9999,6),(8,0xA0,0,0x3F),(8,0xA0,0x8989,0x36),
        (16,0x50,0,0xCF3F),(16,0x50,0x7310,0x8C2F))
    for i,(size,x,mask,value) in enumerate(examples):
        assert pixel_value(0xCF3F,size,0,mask)==value
        for off in (False,True):yield fixture(size,0,0,off,point=0x400000|x,offset=0,source=0,destination=1,word=0xCF3F,pmask=mask,tag=f'literal{i}')
