#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""TRAP PC/ST/vector ordering and counts: SPVU001A12-253/254."""
from itertools import product
from store_cases import insert,transactions as store_transactions
from load_cases import extract
from oracle import load_states
MASK32=(1<<32)-1


def fixture(n,off,offset=0,*,status=0xC0200810,target=0x1800,alignment=0,tag='base',address=None,low=0):
    if n not in range(32):raise ValueError('TRAP number')
    sp=(0x5040+offset if address is None else address)&MASK32;offset=sp&15;vector=0xFFFFFFE0-32*n
    if not n:target=0x1000;low=0
    target&=~15
    touched={((sp-64+bit)&MASK32)&~15 for bit in range(64)}
    memory={a:(0xA55A^((a>>4)&0xFFFF)) for a in touched}
    for a,v in ((0xFFFFFFE0,0x1000),(0xFFFFFFF0,0)):
        if a in memory:memory[a]=v
    memory.update({vector:(target|low)&0xFFFF,(vector+16)&MASK32:(target|low)>>16})
    memory=sorted(memory.items())
    old=[0x11223344,0x55667788,0x99AABBCC,status];b={q:0xB0102030+q*0x1020304 for q in range(4)}
    return dict(name=f'trap_n{n}_{tag}_o{offset}_a{alignment}_{"off" if off else "hit"}',coverage_id='TRAP',opcode=0x0900|n,
        regs=old,expected_regs=list(old),initial_b_regs=b,initial_sp=sp,expected_extra_regs={**{f'b{q}':v for q,v in b.items()},'sp':sp if not n else (sp-64)&MASK32},
        expected_st=0x10,cache_disabled=off,states=(30 if offset else 16)+3*off,initial_memory=memory,expected_memory=memory,
        data_store=dict(address=(sp-64)&MASK32,width=64,value=0,mode='trap',cpu=30 if offset else 16),
        data_trap=dict(n=n,vector=vector,fields=[]),trap_flow=dict(target=target),expected_next_opcode=0x0300,
        instruction_word_offset=alignment,drain_instructions=-1 if off or not n else 1,
        citation='SPVU001A12-253/254',conditions=dict(n=n,stack_alignment=offset,status=status,target=target,opcode_offset=alignment,vector_operand=target|low))


def program(case,movi):
    words=movi(0xC00000B0,14)+movi(0x8018 if case['cache_disabled'] else 0x18,13)+[0x0550,0x81AE]
    loop=0x1000+16*len(words);words+=movi(loop,12)
    for q,v in enumerate(case['regs']):words+=movi(v,q)
    for q,v in case['initial_b_regs'].items():words+=movi(v,16+q)
    words+=movi(case['initial_sp'],15)+[0x01A3]+[0x0300]*12
    while len(words)%4!=case['instruction_word_offset']:words.append(0x0300)
    start=0x1000+16*len(words);words += [case['opcode']]+[0x0300]*4
    trap=case['data_trap'];target=case['trap_flow']['target']
    if trap['n']:
        trap['fields']=[dict(address=(case['initial_sp']-32)&MASK32,width=32,value=start+16,reverse=True),dict(address=(case['initial_sp']-64)&MASK32,width=32,value=case['regs'][3],reverse=True)]
        base=target&~63;code={base+q*16:0x0300 for q in range(8)};code[target+16]=0x016C;code[target]=case.get('target_opcode',0x0300)
        if 0x1000<=base and base+128<=0x10000:
            if base<start+16:raise ValueError('TRAP target overlaps setup')
            words += [0x0300]*((base+128-0x1000)//16-len(words))
            for a,v in code.items():words[(a-0x1000)//16]=v
        else:case['initial_memory']=sorted({**dict(case['initial_memory']),**code}.items())
    else:case['expected_next_opcode']=words[0]
    vector_words={trap['vector'],trap['vector']+16}
    stack_words={((field['address']+bit)&MASK32)&~15 for field in trap['fields'] for bit in range(32)}
    if vector_words&stack_words:raise ValueError('TRAP stack overwrites its vector input')
    if len(case['initial_memory'])>16:raise ValueError('TRAP sparse input limit16')
    memory=case['initial_memory']
    for field in trap['fields']:memory=insert(memory,field['address'],32,field['value'])
    case['expected_memory']=memory
    if 'control_follow' in case:
        case['follow_pc']=target+16
        case['expected_follow_memory']=memory
    return words,start,target


def transactions(case):
    trap=case['data_trap'];plan=[]
    for spec in trap['fields']:
        row=dict(data_store=spec,initial_memory=case['initial_memory'],expected_memory=case['expected_memory'])
        plan+=store_transactions(row)
    image=dict(case['initial_memory']);a=trap['vector']
    plan += [(0,a,image[a],0),(0,a+16,image[a+16],0)]
    return plan


def trap_cases():
    for n,off,offset in product(range(32),(False,True),range(16)):
        yield fixture(n,off,offset)
    for n,off,offset,flags,ie in product((0,1,31),(False,True),(0,15),range(16),(0,1)):
        yield fixture(n,off,offset,status=(flags<<28)|(ie<<21)|0x810,tag=f'flags{flags}_ie{ie}')
    for off,field,width,fe in product((False,True),(0,1),range(1,33),(0,1)):
        status=(0xF2200810&~(63<<(6*field)))|(((width&31)|(fe<<5))<<(6*field))
        yield fixture(8,off,15,status=status,tag=f'ignored_f{field}_w{width}_fe{fe}')
    for n,off,alignment in product((0,1,31),(False,True),range(4)):
        yield fixture(n,off,15,alignment=alignment,tag='phase')
    for n,off,low in product((1,31),(False,True),range(16)):
        yield fixture(n,off,15,low=low,tag=f'low{low}')
    for n,off,target in product((1,31),(False,True),(0,0x80010000,0xFFFF0000)):
        yield fixture(n,off,15,target=target,tag=f'target_{target:08x}')
    for n,off,address in product((0,31),(False,True),(0,8,0x80000000,0xFFFFFFF0,0xFFFFFFFF)):
        yield fixture(n,off,address=address,tag=f'sp_{address:08x}')
    for n,bank,offset,source_offset in product((1,31),(0,1),(0,15),(0,15)):
        row=fixture(n,False,offset,tag=f'follow_b{bank}_s{source_offset}')
        address=0x6000+source_offset
        if bank:row['initial_b_regs'][2]=address;row['expected_extra_regs']['b2']=address
        else:row['regs'][2]=address;row['expected_regs'][2]=address
        for q in (4,5,6):
            value=0xB0102030+q*0x1020304
            row['initial_b_regs'][q]=value;row['expected_extra_regs']['b'+str(q)]=value
        memory=row['initial_memory']+[(0x6000,0x9B6D),(0x6010,0xA596),(0x6020,0x35C6)]
        opcode=0x8441|(bank<<4);value=extract(memory,address,16,False)
        row.update(initial_memory=memory,observe_implicit=True,expected_next_opcode=opcode,target_opcode=opcode,drain_instructions=2,
            control_follow=dict(kind='trap-follow-load',states=load_states(address=address,width=16,signed=False),
                                transfers=((address&15)+31)//16,data_load=dict(address=address,width=16),initial_memory=memory),
            expected_follow_regs=list(row['expected_regs']),expected_follow_extra_regs=dict(row['expected_extra_regs']),
            expected_follow_st=0x10|(0x20000000 if not value else 0))
        if bank:row['expected_follow_extra_regs']['b1']=value
        else:row['expected_follow_regs'][1]=value
        yield row
