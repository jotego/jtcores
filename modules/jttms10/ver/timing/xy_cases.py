#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""TI packed XY arithmetic, independent of the DUT carry chain.

The two signed 16-bit coordinates have independent modulo-65536 results.
SUBXY's C/V report signed operand ordering, unlike CMPXY's result signs.
SPVU001A entry12-56 gives CMPXY1/4; summary12-12 and SPVS002C June1991
p11 give3/6 andminimum3. This conflict remains an acceptance blocker.
"""
from itertools import product
from scalar_cases import MASK32,N,C,Z,V
from alu_cases import initial_status

BASES=dict(ADDXY=0xE000,SUBXY=0xE200,CMPXY=0xE400)
PAGES=dict(ADDXY='12-41',SUBXY='12-252',CMPXY='12-56; summary12-12; SPVS002C June1991 p11')


def signed16(value):
    return value-65536 if value&32768 else value


def pack(x,y):
    return ((y&65535)<<16)|(x&65535)


def arithmetic(name,source,dest,status):
    if name not in BASES:raise ValueError('unknown XY arithmetic operation')
    sx,sy=source&65535,source>>16
    dx,dy=dest&65535,dest>>16
    x=(dx+sx if name=='ADDXY' else dx-sx)%65536
    y=(dy+sy if name=='ADDXY' else dy-sy)%65536
    vs= signed16(sx)>signed16(dx) if name=='SUBXY' else x>=32768
    cs= signed16(sy)>signed16(dy) if name=='SUBXY' else y>=32768
    flags=(N if x==0 else 0)|(Z if y==0 else 0)|(V if vs else 0)|(C if cs else 0)
    return dest if name=='CMPXY' else pack(x,y),(status&~(N|C|Z|V))|flags


def fixture(name,source,dest,*,off=False,bank=0,rd=0,rs=2,flags=0,alignment=0,tag='',initial_st=None):
    if name not in BASES or bank not in (0,1) or rd not in (0,1,2,15) or rs not in (0,1,2,15):
        raise ValueError('invalid XY fixture')
    if rs==rd and source!=dest:raise ValueError('aliased operands must agree')
    st=initial_status(flags) if initial_st is None else initial_st
    a=[0x11223344,0x55667788,0x99AABBCC,st]
    b={q:0xB0102030+q*0x1020304 for q in range(4)};sp=0x12345000
    def put(reg,value):
        nonlocal sp
        if reg==15:sp=value
        elif bank:b[reg]=value
        else:a[reg]=value
    put(rd,dest);put(rs,source)
    expected=list(a);extra={f'b{q}':v for q,v in b.items()};extra['sp']=sp
    value,status=arithmetic(name,source,dest,st)
    if rd==15:extra['sp']=value
    elif bank:extra[f'b{rd}']=value
    else:expected[rd]=value
    hit=3 if name=='CMPXY' else 1
    row=dict(name=f'xy_{name.lower()}_{tag}_r{bank}_{rs}_{rd}_a{alignment}_{"off" if off else "hit"}',
        coverage_id=name+'_RR',opcode=BASES[name]|(rs<<5)|(bank<<4)|rd,
        regs=a,initial_b_regs=b,initial_sp=sp,expected_regs=expected,expected_extra_regs=extra,
        expected_st=status,states=hit+3*off,cache_disabled=off,instruction_word_offset=alignment,
        citation='SPVU001A '+PAGES[name],conditions=dict(form=name,source=source,destination=dest,
        bank=bank,source_register=rs,destination_register=rd,initial_nczv=st>>28))
    if name=='CMPXY':
        row.update(source_values=dict(entry_cpu=1,entry_cd=4,summary_cpu=3,summary_cd=6,
            datasheet_cpu=3,policy_cpu=3,policy_cd=6),timing_source_status='inferred-conflict-resolution',
            source_notes='SPVU001A entry12-56 prints1/4; summary12-12 prints3/6, matching SPVS002C June1991 p11 minimum3. Selected3/6 follows summary/data sheet; no official erratum is claimed.')
    return row


# Literal output words/flags, transcribed from the named TI instruction pages.
LITERALS={
 'ADDXY':[(0,0,0,10),(0,1,1,2),(0,0x10000,0x10000,8),(0,0x10001,0x10001,0),
 (0xffff,1,0,10),(0xffff,0x10001,0x10000,8),(0xffff,2,1,2),(0xffff,0x10002,0x10001,0),
 (0xffff0000,0x10000,0,10),(0xffff0000,0x10001,1,2),(0xffff0000,0x20000,0x10000,8),(0xffff0000,0x20001,0x10001,0),
 (0xffffffff,0x10001,0,10),(0xffffffff,0x10002,1,2),(0xffffffff,0x20001,0x10000,8),(0xffffffff,0x20002,0x10001,0)],
 'SUBXY':[(s,0x90009,r,f) for s,r,f in [(0x10001,0x80008,0),(0x90001,8,2),(0x10009,0x80000,8),(0x90009,0,10),
 (0x10,0x9fff9,1),(0x90010,0xfff9,3),(0x100000,0xfff90009,4),(0x100009,0xfff90000,12),(0x100010,0xfff9fff9,5)]],
 'CMPXY':[(0x90009,d,d,f) for d,f in [(0x10001,5),(0x90001,3),(0x10009,12),(0x90009,10),
 (0x10,4),(0x90010,2),(0x100000,1),(0x100009,8),(0x100010,0)]]}


def xy_cases():
    halves=(0,1,0x7fff,0x8000,0xffff)
    pairs=[(pack(s,d),pack(d,s)) for d,s in product(halves,repeat=2)]
    for d,s in product(halves,repeat=2):
        pairs.extend([(pack(s,0xffff),pack(d,0)),(pack(0xffff,s),pack(0,d)),
                      (pack(s,0x8000),pack(d,0x7fff)),(pack(s,0x7fff),pack(d,0x8000))])
    for name,bank,off in product(BASES,(0,1),(False,True)):
        for q,(source,dest) in enumerate(pairs):
            yield fixture(name,source,dest,bank=bank,off=off,flags=q,tag=f'boundary{q}')
        for rd,rs in [(1,1),(1,0),(2,15),(15,2),(15,15)]:
            for q,value in enumerate((0,1,0xffffffff,0x80007fff,0x7fff8000,0x12345678)):
                yield fixture(name,value,value if rs==rd else value^0x8000ffff,bank=bank,off=off,
                    rd=rd,rs=rs,flags=q,tag=f'identity{q}')
        for flags in range(16):
            yield fixture(name,0x7fff0000,0x8000ffff,bank=bank,off=off,flags=flags,tag=f'flags{flags}')
        for bit,axis in product(range(16),range(2)):
            source=1<<(bit+16*axis);dest=((1<<bit)-1)<<(16*axis)
            yield fixture(name,source,dest,bank=bank,off=off,flags=bit,tag=f'carry{axis}_{bit}')
        for q,(source,dest,_,_) in enumerate(LITERALS[name]):
            yield fixture(name,source,dest,bank=bank,off=off,flags=q,tag=f'guide{q}')
        for alignment in (1,2,3):
            yield fixture(name,0x8000ffff,0x7fff0001,bank=bank,off=off,flags=15,
                alignment=alignment,tag='alignment')
        for field,width,fe in product(range(2),range(1,33),range(2)):
            st=0xF0200000|((width&31)<<(field*6))|(fe<<(field*6+5))
            row=fixture(name,0x8000ffff,0x7fff0001,bank=bank,off=off,
                initial_st=st,tag=f'ignored_f{field}_w{width}_fe{fe}')
            row['conditions'].update(ignored_field=field,ignored_width=width,ignored_fe=fe)
            yield row
        yield fixture(name,0x8000ffff,0x7fff0001,bank=bank,off=off,flags=15,tag='phase')
