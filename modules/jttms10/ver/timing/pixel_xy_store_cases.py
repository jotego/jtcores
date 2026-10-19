#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""PIXT Rs,*Rd.XY replace/PMASK0/T0/W0: SPVU001A12-215..217,4-12."""
from itertools import product
from coordinate_cases import linear
from pixel_store_cases import fixture as replace_fixture
from pixel_boolean_cases import program
from store_cases import insert,transactions
from load_cases import extract


def fixture(size,lane,bank,off,*,point=None,offset=0x6000,conv=20,value=0xE1709B6D,source=2,pointer=0,control=0,**kwargs):
    if control&0xC0:raise ValueError('initial XY subset requires W0')
    point=(0x10000|lane//size) if point is None else point
    if bank and pointer==4:offset=point
    address=linear(point,offset,size,conv)
    if address%size:raise ValueError('pixel-aligned converted address required')
    row=replace_fixture(size,address&15,bank,off,source=source,pointer=pointer,value=value,address=address,control=control,**kwargs)
    row.pop('pixel_store');regs=row['initial_all_regs'];key=lambda q:'sp' if q==15 else f'{"b" if bank else "a"}{q}'
    overrides={key(source):value,'b3':1<<(31-(conv&31)),'b4':offset,key(pointer):point}
    regs.update(overrides);actual=regs[key(source)]
    row.update(name=row['name'].replace(f'pixel_store_ps{size}_o{address&15}_',f'pixel_xy_store_ps{size}_o{lane}_'),coverage_id='PIXT_R_XY',
        opcode=0xF000|(source<<5)|(bank<<4)|pointer,pixel_processing=True,pixel_xy_store=True,measure_pass=0,
        register_overrides=overrides,source_value=point,expected_memory=insert(row['initial_memory'],address,size,actual),
        citation='SPVU001A12-215..217;4-12')
    row['regs']=[regs[f'a{q}'] for q in range(4)];row['expected_regs']=list(row['regs'])
    row['expected_extra_regs']={k:v for k,v in regs.items() if k not in ('a0','a1','a2','a3')}
    row['data_store'].update(cpu=4,write_start=3,value=actual,mode='pixel_xy_replace')
    row['hidden_states']=2*len(transactions(row))-1;row['states']=4+(row['hidden_states']+3 if off else 0)
    row['setup_io'] += [(0xC0000140,conv),(0xC0000130,(conv+7)&31)]
    row['conditions'].update(point=point,offset=offset,convdp=conv,convsp=(conv+7)&31,window=0)
    return row


def following(case,delay):
    bank=case['bank'];source=case['conditions']['source'];pointer=case['conditions']['pointer']
    fptr=next(q for q in range(8,15) if q not in (source,pointer));dest=1 if pointer==0 else 0
    key=f'{"b" if bank else "a"}{fptr}';address=case['data_store']['address']
    case['initial_all_regs'][key]=address;case['expected_extra_regs'][key]=address
    case['register_overrides'][key]=address
    value=extract(case['expected_memory'],address,case['data_store']['width'],False)
    case.update(follow_delay=delay,follow_opcode=0x8400|(fptr<<5)|(bank<<4)|dest,drain_instructions=delay+2)
    case['expected_follow_regs']=list(case['expected_regs']);extra=dict(case['expected_extra_regs'])
    if bank:extra[f'b{dest}']=value
    else:case['expected_follow_regs'][dest]=value
    case['expected_follow_extra_regs']=extra
    case['expected_follow_st']=(case['expected_st']&~0xB0000000)|(0x20000000 if not value else 0)
    return case


def pixel_xy_store_cases():
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
        for value,bank,off in product((0,0xFFFFFFFF,0x55555555,0xAAAAAAAA,1,0x80000000),(0,1),(False,True)):
            yield fixture(size,16-size,bank,off,value=value,tag=f'value{value:08x}')
        for corner,off in product(range(4),(False,True)):
            yield fixture(size,0,0,off,control=corner<<8,tag=f'ignored_corner{corner}')
        for offset,off in product((0,0x80000000,0xFFFFFF00),(False,True)):
            yield fixture(size,0,0,off,point=0x10010,offset=offset,tag=f'offset{offset:08x}')
        for bank,delay in product((0,1),(0,1,2,3,7,10,20)):
            yield following(fixture(size,16-size,bank,False,status=(0xF0200810&~63)|size,tag=f'follow_k{delay}'),delay)
    for size,x,value,want in ((1,0x500,65535,1),(2,0x280,65535,3),(4,0x140,65535,15),(8,0xA0,65535,255),(16,0x50,65535,65535),(4,0x142,6,0x600)):
        for off in (False,True):
            row=fixture(size,0,0,off,point=0x400000|x,offset=0,source=0,pointer=1,value=value,tag=f'literal_x{x:x}')
            row['initial_memory']=[(a,0 if a==0x20500 else v) for a,v in row['initial_memory']]
            row['expected_memory']=insert(row['initial_memory'],row['data_store']['address'],size,value)
            assert row['data_store']['address'] in (0x20500,0x20508)
            assert dict(row['expected_memory'])[0x20500]==want
            yield row
