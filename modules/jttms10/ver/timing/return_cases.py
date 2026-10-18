#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""RETS source/stack model: SPVU001A pp3-6,12-232.

All five-bit encodings0..31, including literal0/1/2/16/31, use the stated
SP+32+16*N rule. The prose upper bound32 is not a distinct five-bit encoding;
retain the documented default0 behavior rather than inventing a mapping.
"""
from itertools import product
from alu_cases import initial_status
from load_cases import extract
from store_cases import insert
from oracle import load_states

MASK32=(1<<32)-1


def rets_fixture(tag,off,offset=0,n=0,flags=0,*,address=None,target=0x1800,low=0,initial=None,alignment=0):
    if n not in range(32) or low not in range(16):raise ValueError('RETS five-bit argument or ignored PC bits')
    sp=(0x5000+offset if address is None else address)&MASK32
    old=initial_status(flags) if initial is None else initial
    addresses=sorted({((sp+bit)&MASK32)&~15 for bit in range(32)})
    memory=insert([(a,0xA55A) for a in addresses],sp,32,(target&~15)|low)
    memory=[(a,0 if a==0xFFFFFFF0 else v) for a,v in memory]
    operand=extract(memory,sp,32,False);destination=operand&~15
    regs=[0x11223344,0x55667788,0x99AABBCC,old]
    b={q:0xB0102030+q*0x1020304 for q in range(4)}
    return dict(name=f'stack_rets_{tag}_{"off" if off else "hit"}',coverage_id='RETS',opcode=0x0960|n,
        regs=regs,expected_regs=list(regs),initial_b_regs=b,initial_sp=sp,
        expected_extra_regs={**{f'b{q}':v for q,v in b.items()},'sp':(sp+32+16*n)&MASK32},
        expected_st=old,cache_disabled=off,states=7+2*bool(sp&15)+3*off,
        initial_memory=memory,expected_memory=memory,drain_instructions=1,
        data_load=dict(address=sp,width=32,mode='stack'),stack_load='RETS',
        stack_control_flow=dict(form='RETS',target=destination),expected_next_opcode=0x0300,
        instruction_word_offset=alignment,citation='SPVU001A3-6/12-232; summary12-17; SPVS002C June1991p14',
        conditions=dict(source=sp,stack_alignment=sp&15,n=n,return_operand=operand,target=destination,
                        initial_status=old,opcode_offset=alignment))


def program(case,movi):
    """Warm a real return target, then jump through A12 to reinitialize SP."""
    words=movi(0xC00000B0,14)+movi(0x8018 if case['cache_disabled'] else 0x18,13)+[0x0550,0x81AE]
    loop=0x1000+16*len(words);words+=movi(loop,12)
    for q,v in enumerate(case['regs']):words+=movi(v,q)
    for q,v in case['initial_b_regs'].items():words+=movi(v,16+q)
    words+=movi(case['initial_sp'],15)+[0x01A3]+[0x0300]*12
    while len(words)%4!=case['instruction_word_offset']:words.append(0x0300)
    start=0x1000+16*len(words);words+=[case['opcode']]+[0x0300]*4
    target=case['stack_control_flow']['target']
    base=target&~63
    code={((base+16*q)&MASK32):0x0300 for q in range(8)}
    code[target]=case.get('target_opcode',0x0300)
    code[(target+(32 if 'control_follow' in case else 16))&MASK32]=0x016C
    if 'control_follow' in case:case['follow_pc']=(target+16)&MASK32
    initial=dict(case['initial_memory'])
    sp=case['initial_sp'];count=((sp&15)+32+15)//16
    stack_words={((sp&~15)+16*q)&MASK32 for q in range(count)}
    if stack_words&set(code):raise ValueError('return target code overlaps its saved PC input')
    # Local code can use the real program image; sparse full-address target
    # words remain input stimulus through the same bench memory interface.
    if 0x1000<=base and base+128<=0x10000:
        assert base>=start+16
        length=(base+128-0x1000)//16
        words += [0x0300]*(length-len(words))
        for a,v in code.items():words[(a-0x1000)//16]=v
    else:
        initial.update(code);case['initial_memory']=sorted(initial.items());case['expected_memory']=case['initial_memory']
    return words,start,target


def return_cases():
    for off,offset,n in product((False,True),range(16),range(32)):
        yield rets_fixture(f'o{offset}_n{n}',off,offset,n,flags=n)
    for off,offset,flags in product((False,True),(0,15),range(16)):
        yield rets_fixture(f'flags{flags}_o{offset}',off,offset,31,flags)
    for off,field,width,fe in product((False,True),(0,1),range(1,33),(0,1)):
        old=(0xF0200810&~(63<<(6*field)))|(((width&31)|(fe<<5))<<(6*field))
        yield rets_fixture(f'ignored_f{field}_w{width}_fe{fe}',off,15,16,initial=old)
    for off,offset,low in product((False,True),(0,15),range(16)):
        yield rets_fixture(f'low{low}_o{offset}',off,offset,2,low=low)
    for off,alignment in product((False,True),range(4)):
        yield rets_fixture(f'phase_a{alignment}',off,15,31,15,alignment=alignment)
    for off,target in product((False,True),(0,0x80010000,0xFFFF0000)):
        yield rets_fixture(f'high_{target:08x}',off,15,1,target=target)
    for off,n,(sp,target) in product((False,True),(0,31),((0xFFFFFFF0,0x10000),(0xFFFFFFF8,0x1800))):
        yield rets_fixture(f'wrap_{sp:08x}_n{n}',off,n=n,address=sp,target=target)
    for off,n in product((False,True),(0,1,2,16,31)):
        yield rets_fixture(f'guide_n{n}',off,n=n,address=0x0FF00000,target=0x1FFF0)
    yield from following_cases()


def following_cases():
    for width,fe,offset,source_offset,bank in product((1,16,32),(0,1),(0,15),(0,15),(0,1)):
        old=0xF0200800|(width&31)|(fe<<5)
        row=rets_fixture(f'following_w{width}_fe{fe}_sp{offset}_o{source_offset}_r{bank}',False,offset,31,initial=old)
        address=0x6000+source_offset
        if bank:
            row['initial_b_regs'][2]=address;row['expected_extra_regs']['b2']=address
        else:row['regs'][2]=address;row['expected_regs'][2]=address
        for q in (4,5,6):
            value=0xB0102030+q*0x1020304
            row['initial_b_regs'][q]=value;row['expected_extra_regs']['b'+str(q)]=value
        memory=row['initial_memory']+[(0x6000,0x9B6D),(0x6010,0xA596),(0x6020,0x35C6)]
        row.update(initial_memory=memory,expected_memory=memory,expected_follow_memory=memory,
                   observe_implicit=True,target_opcode=0x8441|(bank<<4),expected_next_opcode=0x8441|(bank<<4),drain_instructions=2,
                   control_follow=dict(kind='return-follow-load',states=load_states(address=address,width=width,signed=bool(fe)),
                                       transfers=((address&15)+width+15)//16,
                                       data_load=dict(address=address,width=width),initial_memory=memory))
        value=extract(memory,address,width,bool(fe))
        row['expected_follow_regs']=list(row['expected_regs'])
        row['expected_follow_extra_regs']=dict(row['expected_extra_regs'])
        if bank:row['expected_follow_extra_regs']['b1']=value
        else:row['expected_follow_regs'][1]=value
        row['expected_follow_st']=(old&~0xB0000000)|(value&0x80000000)|(0x20000000 if not value else 0)
        yield row
