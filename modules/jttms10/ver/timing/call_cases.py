#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""CALL/CALLA/CALLR timing and stack oracle, TI SPVU001A12-48..50."""
from itertools import product
from alu_cases import initial_status
from store_cases import insert

MASK32=(1<<32)-1
LENGTHS={'CALL_R':1,'CALLA':3,'CALLR':2}


def call_fixture(form,off,offset=0,*,bank=0,reg=0,status=0xC0000810,target=0x3000,low=0,alignment=0,tag='base',address=None,displacement=None):
    if form not in LENGTHS or bank not in (0,1) or reg not in (0,1,2,15):raise ValueError('CALL fixture identity')
    sp=(0x6020+offset if address is None else address)&MASK32
    offset=sp&15
    a=[0x11223344,0x55667788,0x99AABBCC,status]
    b={q:0xB0102030+q*0x1020304 for q in range(4)}
    if form=='CALL_R':
        if reg==15:
            if offset:raise ValueError('SP-target case must avoid self-modifying target word')
            target=sp&~15
        elif bank:b[reg]=target|low
        else:a[reg]=target|low
    address=(sp-32)&MASK32
    memory=[(((address&~15)+16*q)&MASK32,0xA55A^q*0x1357) for q in range(3 if offset else 2)]
    cpu=4 if form=='CALLA' else 3
    hidden=(9 if form=='CALL_R' else 8) if offset else (3 if form=='CALL_R' else 2)
    return dict(name=f'call_{form.lower()}_{tag}_o{offset}_r{bank}_{reg}_a{alignment}_{"off" if off else "hit"}',
        coverage_id=form,opcode={'CALL_R':0x0920|bank<<4|reg,'CALLA':0x0D5F,'CALLR':0x0D3F}[form],
        extensions=[0]*(LENGTHS[form]-1),regs=a,initial_b_regs=b,initial_sp=sp,
        expected_regs=list(a),expected_extra_regs={**{f'b{q}':v for q,v in b.items()},'sp':address},
        expected_st=status,cache_disabled=off,states=cpu+(hidden+3*LENGTHS[form] if off else 0),hidden_states=hidden,
        initial_memory=memory,expected_memory=memory,drain_instructions=24 if not off else -1,
        data_store=dict(address=address,width=32,value=0,mode='call',cpu=cpu,write_start=2 if form!='CALLR' else 1,reverse=True),
        call_flow=dict(form=form,target=target&~15,low=low,displacement=displacement),expected_next_opcode=0x0300,instruction_word_offset=alignment,
        citation='SPVU001A12-'+{'CALL_R':'48','CALLA':'49','CALLR':'50'}[form]+'; stack order12-253',
        conditions=dict(form=form,stack_alignment=offset,bank=bank,register=reg,status=status,target=target,low=low,opcode_offset=alignment))


def program(case,movi):
    flow=case['call_flow'];form=flow['form'];length=LENGTHS[form]
    words=movi(0xC00000B0,14)+movi(0x8018 if case['cache_disabled'] else 0x18,13)+[0x0550,0x81AE]
    loop=0x1000+16*len(words);words+=movi(loop,12)
    for q,v in enumerate(case['regs']):words+=movi(v,q)
    for q,v in case['initial_b_regs'].items():words+=movi(v,16+q)
    words+=movi(case['initial_sp'],15)+[0x01A3]+[0x0300]*12
    while len(words)%4!=case['instruction_word_offset']:words.append(0x0300)
    start=0x1000+16*len(words);pc=(start+16*length)&MASK32;target=flow['target']
    if form=='CALLR' and flow['displacement'] is not None:target=(pc+16*flow['displacement'])&MASK32
    case['conditions'].update(return_pc=pc,target=target)
    if form=='CALLA':case['extensions']=[(target|flow['low'])&0xFFFF,(target|flow['low'])>>16]
    if form=='CALLR':
        delta=(target-pc)&MASK32
        if delta>=1<<31:delta-=1<<32
        if delta%16 or not -32768<=delta//16<=32767:raise ValueError('CALLR displacement range')
        case['extensions']=[(delta//16)&0xFFFF]
    case['data_store']['value']=pc
    case['expected_memory']=insert(case['initial_memory'],case['data_store']['address'],32,pc)
    words+=[case['opcode']]+case['extensions']+[0x0300]*4
    base=target&~63;local=0x1000<=base and base+60*16<=0x10000
    tail=(48 if 'follow_delay' in case else 24) if local else 1
    count=tail+4 if local else 8
    code={((base+16*q)&MASK32):0x0300 for q in range(count)}
    code[(target+tail*16)&MASK32]=0x016C
    code[(target+16*case.get('follow_delay',0))&MASK32]=case.get('target_opcode',0x0300)
    live={((target+16*q)&MASK32) for q in range(tail+1)}
    if live&set(dict(case['initial_memory'])):raise ValueError('CALL stack overlaps target program')
    for a,v in case['initial_memory']:
        if a in code:code[a]=v
    if local:
        if target<start+16*length:raise ValueError('CALL local target overlaps setup')
        for a in code:
            if a<target and a<0x1000+16*len(words):code[a]=words[(a-0x1000)//16]
        words += [0x0300]*((base+count*16-0x1000)//16-len(words))
        for a,v in code.items():words[(a-0x1000)//16]=v
    else:
        case['initial_memory']=sorted({**dict(case['initial_memory']),**code}.items())
        case['expected_memory']=insert(case['initial_memory'],case['data_store']['address'],32,pc)
        if not case['cache_disabled']:case['drain_instructions']=-2
    warm_tags={a>>9 for a in range(0x1000,start+length*16,16)}|{a>>9 for a in code}
    if len(warm_tags)>4:raise ValueError('CALL warm fixture exceeds four cache segments')
    if len(case['initial_memory'])>16:raise ValueError('CALL sparse memory exceeds bench input limit16')
    if 'follow_delay' in case:
        values=list(case['expected_regs']);extra=dict(case['expected_extra_regs'])
        if case['following_bank']:extra['b1']=pc
        else:values[1]=pc
        case.update(expected_follow_regs=values,expected_follow_extra_regs=extra,
                    expected_follow_st=(case['expected_st']&~0xB0000000)|(pc&0x80000000)|(0x20000000 if pc==0 else 0))
    return words,start,target


def call_cases():
    for form,off,offset,flags in product(LENGTHS,(False,True),range(16),(0,15)):
        yield call_fixture(form,off,offset,status=initial_status(flags),tag=f'flags{flags}')
    for off,bank,reg,low in product((False,True),(0,1),(0,1,2,15),range(16)):
        if reg==15 and low:continue
        yield call_fixture('CALL_R',off,0 if reg==15 else 15,bank=bank,reg=reg,low=0 if reg==15 else low,tag=f'low{low}')
    for form,off,field,width,fe in product(LENGTHS,(False,True),(0,1),range(1,33),(0,1)):
        status=(0x60200810&~(63<<(6*field)))|(((width&31)|(fe<<5))<<(6*field))
        yield call_fixture(form,off,15,status=status,tag=f'ignored_f{field}_w{width}_fe{fe}')
    for form,off,alignment in product(LENGTHS,(False,True),range(4)):
        yield call_fixture(form,off,15,alignment=alignment,tag='phase')
    for form,off,target in product(('CALL_R','CALLA'),(False,True),(0,0x80010000,0xFFFF0000)):
        yield call_fixture(form,off,15,target=target,tag=f'high_{target:08x}')
    for off,displacement in product((False,True),(-32768,-32767,-1024,0,1,2,1024,32766,32767)):
        yield call_fixture('CALLR',off,15,displacement=displacement,tag=f'disp_{displacement}')
    for form,off,address in product(LENGTHS,(False,True),(0x80006000,0xFFFF600F)):
        yield call_fixture(form,off,address=address,tag=f'stack_{address:08x}')
    for form,bank,offset,delay in product(LENGTHS,(0,1),(0,15),(0,1,2,3,7,10,20)):
        row=call_fixture(form,False,offset,bank=bank,reg=2,status=0xC0000800,tag=f'follow_b{bank}_k{delay}')
        address=row['data_store']['address']
        if bank:row['initial_b_regs'][0]=address;row['expected_extra_regs']['b0']=address
        else:row['regs'][0]=address;row['expected_regs'][0]=address
        for q in (4,5,6):
            value=0xB0102030+q*0x1020304
            row['initial_b_regs'][q]=value;row['expected_extra_regs']['b'+str(q)]=value
        opcode=0x8401|(bank<<4)
        row.update(follow_delay=delay,following_bank=bank,target_opcode=opcode,
                   expected_next_opcode=0x0300 if delay else opcode,observe_implicit=True,drain_instructions=24+delay)
        yield row
