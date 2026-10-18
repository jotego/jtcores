#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Register-to-memory fields and hidden writes: TI SPVU001A 13-2/3,13-6.

Plain/post/pre field and plain byte counts agree between entries and summary.
Offset/absolute counts conflict and remain outside this initial store oracle.
"""
from alu_cases import initial_status
from scalar_cases import MASK32


def insert(memory,address,width,value):
    """Walk architectural bits, preserving every bit outside the field."""
    image=dict(memory)
    for bit in range(width):
        pos=(address+bit)&MASK32;word=pos&~15;mask=1<<(pos&15)
        image[word]=(image[word]&~mask) | (((value>>bit)&1)<<(pos&15))
    return sorted(image.items())


def transactions(case):
    """TI §13.2 Fig13-1: partial words read/modify/write; whole words write."""
    spec=case['data_store'];address=spec['address'];width=spec['width']
    # Warm-up executes the same idempotent store once before measurement.
    image=dict(case['expected_memory']);final=dict(case['expected_memory'])
    touched={((address+b)&MASK32)&~15 for b in range(width)}
    result=[]
    for word in sorted(touched,key=lambda w:(w-(address&~15))&MASK32):
        bits=sum(1 for b in range(width) if (((address+b)&MASK32)&~15)==word)
        if bits!=16:result.append((0,word,image[word],0))
        result.append((1,word,final[word],0))
    return result


def fixture(mode,width,offset,field,off,index,*,byte=False,bank=0,source=2,dest=0):
    address=0x6000+offset
    st=initial_status(index)
    st=(st&~(63<<(6*field))) | (((width&31)|((index&1)<<5))<<(6*field))
    if byte:st=(st&~0xFFF)|(0x001,0x83F,0x445,0x230)[index%4]
    memory=[(0x6000+16*q,(0x35C6A5969B6D>>(16*q))&0xFFFF) for q in range(3)]
    a=[0x11223344,0x55667788,0x99AABBCC,st]
    b={q:0xB0102030+q*0x1020304 for q in range(4)};sp=0x12345000
    def put(reg,value):
        nonlocal sp
        if reg==15:sp=value
        elif bank:b[reg]=value
        else:a[reg]=value
    def get(reg):return sp if reg==15 else b[reg] if bank else a[reg]
    put(source,(0,0xFFFFFFFF,0xE1709B6D,0xAAAAAAAA,0x55555555)[index%5])
    put(dest,address+width if mode=='pre' else address)
    value=address if mode=='pre' and source==dest else get(source)
    ea=list(a);eb={f'b{r}':v for r,v in b.items()};eb['sp']=sp
    if mode in ('pre','post'):
        pointer=address if mode=='pre' else address+width
        if dest==15:eb['sp']=pointer
        elif bank:eb[f'b{dest}']=pointer
        else:ea[dest]=pointer
    cpu=2 if mode=='pre' else 1
    row=dict(name=f'store_{"movb" if byte else "move"}_{mode}_w{width}_o{offset}_f{field}_r{bank}_{source}_{dest}_q{index}_{"off" if off else "hit"}',
        opcode=((0x8C00 if byte else {'indirect':0x8000,'post':0x9000,'pre':0xA000}[mode] | field<<9) | source<<5 | bank<<4 | dest),
        coverage_id='MOVB_R_IND' if byte else {'indirect':'MOVE_R_IND','post':'MOVE_R_POST','pre':'MOVE_R_PRE'}[mode],
        regs=a,initial_b_regs=b,initial_sp=sp,expected_regs=ea,expected_extra_regs=eb,expected_st=st,
        initial_memory=memory,expected_memory=insert(memory,address,width,value),
        data_store=dict(address=address,width=width,value=value,mode=mode,cpu=cpu),
        cache_disabled=off,tail_instructions=32,drain_instructions=-1 if off else 24,
        citation='SPVU001A 13-2/3,13-6; '+('12-115' if byte else {'indirect':'12-127','post':'12-128/129','pre':'12-130/131'}[mode]),
        conditions=dict(mode=mode,width=width,offset=offset,field=field,bank=bank,source=source,destination=dest,alias=source==dest))
    count=len(transactions(row));row['hidden_states']=2*count-1
    row['states']=cpu+(row['hidden_states']+3 if off else 0)
    return row


def store_cases():
    for off in (False,True):
        for mode in ('indirect','post','pre'):
            for width in range(1,33):
                for offset in (range(16) if mode=='indirect' else (0,1,7,15)):
                    for field in (0,1):
                        index=width*32+offset*2+field
                        bank=(index//7)&1
                        yield fixture(mode,width,offset,field,off,index,bank=bank)
        for offset in range(16):
            for q in range(4):
                yield fixture('indirect',8,offset,0,off,offset*4+q,byte=True,bank=q&1)
        for mode in ('indirect','post','pre'):
            for bank in (0,1):
                for width in (1,16,32):
                    for source,dest in ((0,0),(15,0),(0,15),(15,15)):
                        yield fixture(mode,width,15,1,off,source+dest+width,bank=bank,source=source,dest=dest)

    # A bus-dependent load after K cached NOPs consumes only hidden states
    # which have not already overlapped CPU execution (§13.1.1 pp13-2/3).
    from load_cases import extract
    for width in (1,8,16,17,32):
        for offset in (0,15):
            for delay in (0,1,2,3,7,10,20):
                row=fixture('indirect',width,offset,0,False,width*32+offset*2)
                row['name']=row['name'].removesuffix('_hit')+f'_dependency{delay}_hit'
                row['follow_delay']=delay
                row['following_words']=[0x0300]*delay+[0x8401]+[0x0300]*32
                row['drain_instructions']=24+delay
                value=extract(row['expected_memory'],row['data_store']['address'],width,False)
                regs=list(row['expected_regs']);regs[1]=value
                row['expected_follow_regs']=regs
                row['expected_follow_st']=(row['expected_st']&~0xB0000000)|(value&0x80000000)|(0x20000000 if value==0 else 0)
                yield row
