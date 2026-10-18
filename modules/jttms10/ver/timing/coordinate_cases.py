#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""TI CPW/CVXYL expectations and real implicit-register/MMR setup.

CPW limits must be nonnegative; negative limits have unpredictable results.
CVXYL uses nonnegative X. Its mathematical OR precedes the offset addition.
Four printed example outputs conflict with that formula; retain the values
and keep those probe instances excluded by the source-acceptance gate.
"""
from itertools import product
from scalar_cases import MASK32,N,C,Z,V
from alu_cases import initial_status
from xy_cases import pack,signed16

CPW_EXAMPLES=[(pack(x,y),code) for y,codes in [
 (4,[0xA0,0x80,0x80,0xC0]),(5,[0x20,0,0,0x40]),
 (10,[0x20,0,0,0x40]),(11,[0x120,0x100,0x100,0x140])]
 for x,code in zip([4,5,10,11],codes)]
CV_EXAMPLES=[(0x00400030,offset,size,conv,result) for offset,size,conv,result in [
 (0,16,20,0x20300),(0,8,20,0x20180),(0,4,20,0x20000),
 (0x8000,4,20,0x28000),(0x0F000000,4,20,0x0F020000),
 (0,2,20,0x20060),(0,1,20,0x20030),(0,1,19,0x40030),
 (0,1,21,0x10000)]]


def point_code(point,start,end):
    sx,sy=signed16(start&65535),signed16(start>>16)
    ex,ey=signed16(end&65535),signed16(end>>16)
    if min(sx,sy,ex,ey)<0 or sx>ex or sy>ey:raise ValueError('undefined window limits')
    x,y=signed16(point&65535),signed16(point>>16)
    return (int(x<sx)<<5)|(int(x>ex)<<6)|(int(y<sy)<<7)|(int(y>ey)<<8)


def linear(point,offset,size,convdp):
    if point&0x8000 or size not in (1,2,4,8,16):
        raise ValueError('undefined XY conversion parameters')
    # TI4-12 and6-15: invert the five LSBs, not32-CONVDP.
    y=signed16(point>>16);x=point&65535;pitch=2**(31-(convdp&31))
    return (((y*pitch)&MASK32)|(x*size))+offset & MASK32


def fixture(name,point,*,bank=0,rs=2,rd=0,off=False,flags=0,initial_st=None,
            start=0x00050005,end=0x000A000A,offset=0,size=1,convdp=20,
            alignment=0,tag=''):
    if name not in ('CPW','CVXYL') or bank not in (0,1) or rs not in (0,1,2,3,4,5,6,15) or rd not in (0,1,2,3,4,5,6,15):
        raise ValueError('invalid coordinate fixture')
    if bank==0 and (rs in (3,4,5,6) or rd in (3,4,5,6)):
        raise ValueError('unobserved A register / A3 holds ST')
    st=initial_status(flags) if initial_st is None else initial_st
    a=[0x11223344,0x55667788,0x99AABBCC,st]
    b={q:0xB0102030+q*0x1020304 for q in range(4)}
    b.update({4:offset,5:start,6:end});sp=0x12345000
    if name=='CVXYL':b[3]=2**(31-(convdp&31))
    if bank and rs in (3,4,5,6) and b[rs]!=point:raise ValueError('implicit source must contain the specified input')
    if rs==15:sp=point
    elif bank:b[rs]=point
    else:a[rs]=point
    expected=list(a);extra={f'b{q}':v for q,v in b.items()};extra['sp']=sp
    value=point_code(point,start,end) if name=='CPW' else linear(point,offset,size,convdp)
    status=(st&~V)|(V if value else 0) if name=='CPW' else st
    if rd==15:extra['sp']=value
    elif bank:extra[f'b{rd}']=value
    else:expected[rd]=value
    row=dict(name=f'coordinate_{name.lower()}_{tag}_r{bank}_{rs}_{rd}_a{alignment}_{"off" if off else "hit"}',
        coverage_id=name+'_RR',opcode=(0xE600 if name=='CPW' else 0xE800)|(rs<<5)|(bank<<4)|rd,
        regs=a,initial_b_regs=b,initial_sp=sp,expected_regs=expected,expected_extra_regs=extra,
        expected_st=status,states=(1 if name=='CPW' else 3)+3*off,
        cache_disabled=off,instruction_word_offset=alignment,observe_implicit=True,
        citation='SPVU001A '+('12-57/58' if name=='CPW' else '4-12;6-15;12-59/60'),
        conditions=dict(form=name,point=point,window_start=start,window_end=end,
            offset=offset,pixel_size=size,convdp=convdp,bank=bank,source_register=rs,destination_register=rd))
    if name=='CVXYL':
        row['setup_io']=[(0xC0000140,convdp),(0xC0000150,size)]
        for pt,ofs,sz,cv,printed in CV_EXAMPLES:
            if (point,offset,size,convdp)==(pt,ofs,sz,cv) and value!=printed:
                row.update(timing_source_status='inferred-conflict-resolution',source_conflict_kind='behavior',
                    source_values=dict(entry_cpu=3,entry_cd=6,policy_cpu=3,policy_cd=6,
                        entry_example_result=printed,formula_result=value,policy_result=value),
                    source_result_register='sp' if rd==15 else f'b{rd}' if bank else f'a{rd}',
                    source_notes='Timing3/6 agrees. The scanned example on12-60 conflicts with the OR/shift/add formula on4-12 and12-59. Expected result follows the repeated formula; the printed alternative remains explicit and this source policy blocks acceptance. No official erratum is claimed.')
    return row


def coordinate_cases():
    for bank,off in product((0,1),(False,True)):
        for q,(ws,we) in enumerate([(pack(0,0),pack(0,0)),(pack(5,5),pack(10,10)),
            (pack(0,0),pack(32767,32767)),(pack(32766,32765),pack(32767,32767))]):
            xs=sorted(set([-32768,-1,0,(ws&65535)-1,ws&65535,we&65535,(we&65535)+1,32767]))
            ys=sorted(set([-32768,-1,0,(ws>>16)-1,ws>>16,we>>16,(we>>16)+1,32767]))
            for k,(x,y) in enumerate(product([x for x in xs if x<=32767],[y for y in ys if y<=32767])):
                yield fixture('CPW',pack(x,y),bank=bank,off=off,flags=k,start=ws,end=we,tag=f'window{q}_point{k}')
        for q,(pt,_) in enumerate(CPW_EXAMPLES):
            yield fixture('CPW',pt,bank=bank,off=off,flags=q,tag=f'guide{q}')
        for conv,size,q in product(range(32),(1,2,4,8,16),range(5)):
            y=(0,1,-1,32767,-32768)[q];x=(0,1,31,48,32767)[(conv+size+q)%5]
            offset=(0,0xFFFFFFF0,0x80000000,0x12345678)[(conv+q)%4]
            yield fixture('CVXYL',pack(x,y),bank=bank,off=off,flags=conv+q,
                offset=offset,size=size,convdp=conv,tag=f'pitch{conv}_size{size}_point{q}')
        for q,(pt,ofs,size,conv,_) in enumerate(CV_EXAMPLES):
            yield fixture('CVXYL',pt,bank=bank,off=off,flags=q,offset=ofs,
                size=size,convdp=conv,tag=f'guide{q}')
        for name in ('CPW','CVXYL'):
            for rd,rs in [(1,1),(1,0),(2,15),(15,2),(15,15)]+([(5,2),(6,2),(4,2),(0,5),(0,6)] if bank else []):
                pt=0x00050005 if bank and rs==5 else 0x000A000A if bank and rs==6 else 0x00010002
                yield fixture(name,pt,bank=bank,off=off,flags=15,rd=rd,rs=rs,tag='identity')
            for flags in range(16):
                yield fixture(name,0x80007FFF,bank=bank,off=off,flags=flags,tag=f'flags{flags}')
            for field,width,fe in product(range(2),range(1,33),range(2)):
                st=0xF0200000|((width&31)<<(field*6))|(fe<<(field*6+5))
                row=fixture(name,0xFFFF7FFF,bank=bank,off=off,initial_st=st,tag=f'ignored_f{field}_w{width}_fe{fe}')
                row['conditions'].update(ignored_field=field,ignored_width=width,ignored_fe=fe)
                yield row
            for alignment in (1,2,3):
                yield fixture(name,0x80007FFF,bank=bank,off=off,flags=15,alignment=alignment,tag='alignment')
            yield fixture(name,0x80007FFF,bank=bank,off=off,flags=15,tag='phase')
    # Direct branch fetches may accept their following opcode at timed ACK.
    # Exercise the real coordinate instructions at that immediate boundary.
    from control_cases import fixture as branch_fixture
    for branch,target,bank in product(('JR_LONG','JACC'),('CPW','CVXYL'),(0,1)):
        row=branch_fixture(branch,off=True,flags=3,code=10,displacement=8)
        point=(0x00050005 if bank else 0x80007FFF) if target=='CPW' else 0x80000031
        offset=0x12345678;start=0x00050005;end=0x000A000A
        if bank:
            row['initial_b_regs'][2]=point;row['expected_extra_regs']['b2']=point
        else:
            row['regs'][2]=point;row['expected_regs'][2]=point
        for q,value in [(4,offset),(5,start),(6,end)]+([(3,0x800)] if target=='CVXYL' else []):
            row['initial_b_regs'][q]=value;row['expected_extra_regs'][f'b{q}']=value
        value=point_code(point,start,end) if target=='CPW' else linear(point,offset,16,20)
        expected=list(row['expected_regs']);extra=dict(row['expected_extra_regs'])
        if bank:extra['b0']=value
        else:expected[0]=value
        status=(row['expected_st']&~V)|(V if value else 0) if target=='CPW' else row['expected_st']
        row.update(name=f'coordinate_after_{branch.lower()}_{target.lower()}_r{bank}',
            target_opcode=(0xE600 if target=='CPW' else 0xE800)|(bank<<4)|0x40,
            observe_implicit=True,setup_io=[(0xC0000140,20),(0xC0000150,16)] if target=='CVXYL' else [],
            control_follow=dict(kind='coordinate',form=target,scalar=True,states=4 if target=='CPW' else 6,transfers=1),
            expected_follow_regs=expected,expected_follow_extra_regs=extra,expected_follow_st=status,
            expected_follow_memory=[],drain_instructions=2)
        row['conditions'].update(follow_form=target,follow_bank=bank)
        yield row
