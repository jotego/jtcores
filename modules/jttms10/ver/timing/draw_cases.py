#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""DRAV replace/PMASK0/T0/W0: SPVU001A12-67..69."""
from itertools import product
from pixel_xy_store_cases import fixture as xy_fixture, following
from store_cases import insert


def advance(point,delta):
    return (((point&65535)+(delta&65535))&65535)|((((point>>16)+(delta>>16))&65535)<<16)


def fixture(size,lane,bank,off,*,delta=0x00100010,color=0x9876A596,source=2,pointer=0,**kwargs):
    row=xy_fixture(size,lane,bank,off,value=delta,source=source,pointer=pointer,**kwargs)
    row.pop('pixel_xy_store');regs=row['initial_all_regs'];key=lambda q:'sp' if q==15 else f'{"b" if bank else "a"}{q}'
    point=row['conditions']['point'];overrides=dict(row['register_overrides']);overrides.update(b9=color);overrides[key(pointer)]=point
    regs.update(overrides);new_point=advance(regs[key(pointer)],regs[key(source)])
    address=row['data_store']['address'];pixel=(regs['b9']>>(address&15))&((1<<size)-1)
    expected=dict(regs);expected[key(pointer)]=new_point
    row.update(name=row['name'].replace('pixel_xy_store_','draw_'),opcode=0xF600|(source<<5)|(bank<<4)|pointer,
        coverage_id='DRAV_RR',pixel_draw=True,register_overrides=overrides,
        expected_memory=insert(row['initial_memory'],address,size,pixel),
        citation='SPVU001A12-67..69;4-12')
    row['regs']=[regs[f'a{q}'] for q in range(4)];row['expected_regs']=[expected[f'a{q}'] for q in range(4)]
    row['expected_extra_regs']={k:v for k,v in expected.items() if k not in ('a0','a1','a2','a3')}
    row['data_store'].update(value=pixel,mode='draw_replace')
    row['conditions'].update(delta=regs[key(source)],color=regs['b9'],new_point=new_point)
    return row


def draw_cases():
    for size in (1,2,4,8,16):
        for lane,bank,off in product(range(0,16,size),(0,1),(False,True)):
            yield fixture(size,lane,bank,off)
        for conv,q,off in product(range(32),range(5),(False,True)):
            y=(0,16,-16,32752,-32768)[q];x=(0,1,31,48,32767)[q]
            yield fixture(size,0,(conv+q)&1,off,point=((y&65535)<<16)|x,conv=conv,tag=f'pitch{conv}_point{q}')
        for reg,bank,off in product(range(16),(0,1),(False,True)):
            yield fixture(size,0,bank,off,source=reg,pointer=1 if reg!=1 else 0,point=0x10010,tag=f'source{reg}')
            yield fixture(size,0,bank,off,source=2,pointer=reg,point=0x10010,tag=f'pointer{reg}')
            yield fixture(size,0,bank,off,source=reg,pointer=reg,point=0x10010,tag=f'alias{reg}')
        for field,width,fe,off in product((0,1),range(1,33),(0,1),(False,True)):
            status=(0xF2200810&~(63<<(6*field)))|(((width&31)|(fe<<5))<<(6*field))
            yield fixture(size,0,0,off,status=status,tag=f'ignored_f{field}_w{width}_fe{fe}')
        for flags,ie,off in product(range(16),(0,1),(False,True)):
            yield fixture(size,0,0,off,status=(flags<<28)|(ie<<21)|0x810,tag=f'flags{flags}_ie{ie}')
        for bank,off,alignment in product((0,1),(False,True),range(4)):
            yield fixture(size,0,bank,off,alignment=alignment,tag=f'phase_{alignment}')
        for color,bank,off in product((0,0xFFFFFFFF,0x55555555,0xAAAAAAAA,0x80000000,0x00010000),(0,1),(False,True)):
            yield fixture(size,16-size,bank,off,color=color,tag=f'color{color:08x}')
        for bit,lane,off in product(range(16),range(0,16,size),(False,True)):
            yield fixture(size,lane,bit&1,off,color=1<<bit,tag=f'color_bit{bit}')
        points=(0,0x7FFF7FFF,0x80007FFF,0xFFFF0000,0x00010010)
        deltas=(0,1,0xFFFF,0x10000,0xFFFF0000,0xFFFFFFFF,0x7FFF7FFF,0x80008000,0x00018001,0xFFFF7FFF)
        for q,(point,delta,off) in enumerate(product(points,deltas,(False,True))):
            yield fixture(size,0,(q//2)&1,off,point=point,delta=delta,tag=f'point{point:08x}_delta{delta:08x}')
        for corner,off in product(range(4),(False,True)):
            yield fixture(size,0,0,off,control=corner<<8,tag=f'ignored_corner{corner}')
        for offset,off in product((0,0x80000000,0xFFFFFF00),(False,True)):
            yield fixture(size,0,0,off,point=0x10010,offset=offset,tag=f'offset{offset:08x}')
        for bank,delay in product((0,1),(0,1,2,3,7,10,20)):
            yield following(fixture(size,16-size,bank,False,status=(0xF0200810&~63)|size,tag=f'follow_k{delay}'),delay)
    for size,x,new_point,want in ((1,0x40,0x500050,0x8889),(2,0x20,0x500030,0x888B),(4,0x10,0x500020,0x888F),(8,8,0x500018,0x88FF),(16,4,0x500014,0xFFFF)):
        for off in (False,True):
            row=fixture(size,0,0,off,point=0x400000|x,offset=0x10000,conv=22,source=1,pointer=0,color=0xFFFFFFFF,tag=f'literal_x{x:x}')
            row['initial_memory']=[(a,0x8888 if a==0x18040 else v) for a,v in row['initial_memory']]
            row['expected_memory']=insert(row['initial_memory'],row['data_store']['address'],size,row['data_store']['value'])
            assert row['data_store']['address']==0x18040 and row['expected_regs'][0]==new_point
            assert dict(row['expected_memory'])[0x18040]==want
            for key,value in dict(b5=0x100000,b6=0x3C0040).items():
                row['initial_all_regs'][key]=value;row['register_overrides'][key]=value;row['expected_extra_regs'][key]=value
            yield row
