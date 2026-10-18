#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Independent memory-to-memory fields: SPVU001A pp.13-4,13-6/7.

The initial expansion covers plain indirect field/byte copies. Printed
alternatives remain explicit. Source bits are captured before any write;
overlapping warm-up and measured copies are modeled separately.
"""
from itertools import product
from alu_cases import initial_status
from scalar_cases import MASK32
from load_cases import extract
from store_cases import insert, transactions as store_transactions


def alignment(address,width):
    if width not in range(1,33):raise ValueError('undefined field width')
    offset=address&15;span=offset+width
    if width==16 and offset==0:return 'A'
    if span<=16:return 'B'
    if width==32 and offset==0:return 'C'
    if span>32:return 'G'
    if offset==0:return 'E'
    if span==32:return 'D'
    return 'F'


# Table13-3, printed p.13-6; impossible same-width pairs remain absent.
INDICES={
    'A':dict(A=1,F=3), 'B':dict(B=2,F=3),
    'C':dict(C=6,G=9), 'D':dict(D=7,E=7,F=8,G=9),
    'E':dict(D=7,E=7,F=8,G=9),
    'F':dict(A=4,B=5,D=7,E=7,F=8,G=9),
    'G':dict(C=10,D=11,E=11,F=12,G=13),
}
# Table13-4 plain MOVE: (visible CPU, hidden writes, cache-disabled).
PRINTED=((3,1,7),(3,3,9),(3,7,13),(5,1,9),(5,3,11),
         (5,3,11),(5,5,13),(5,7,15),(5,9,17),(7,3,13),
         (7,5,15),(5,7,17),(9,9,21))
POST_PRINTED=((4,0,7),(4,2,9),(4,6,13),(6,0,9),(6,2,11),
              (6,2,11),(6,4,13),(6,6,15),(6,8,17),(8,2,13),
              (8,4,15),(6,6,17),(10,8,21))
PRE_PRINTED=((4,1,8),(4,3,10),(4,7,14),(6,1,10),(6,3,12),
             (6,3,12),(6,5,14),(6,7,15),(6,9,18),(8,3,14),
             (8,5,16),(6,7,18),(10,9,22))


def counts(source,destination,width,*,byte=False,mode='indirect'):
    if mode not in ('indirect','post','pre') or (byte and mode!='indirect'):
        raise ValueError('undefined copy addressing mode')
    if mode!='indirect':
        cpu,hidden,_,index,_=counts(source,destination,width)
        cpu+=1
        hidden-=int(mode=='post')
        cd=cpu+hidden+3
        printed=(POST_PRINTED if mode=='post' else PRE_PRINTED)[index-1]
        values={} if (cpu,hidden,cd)==printed else dict(
            summary_cpu=printed[0],summary_cd=printed[2],policy_cpu=cpu,policy_cd=cd)
        return cpu,hidden,cd,index,values
    if byte and width!=8:raise ValueError('MOVB forces eight bits')
    sa,da=alignment(source,width),alignment(destination,width)
    index=INDICES[sa][da];cpu,hidden,cd=PRINTED[index-1]
    values={}
    if index==12:
        # The source spans three physical words; the same printed column's
        # CD17 and H7 imply CPU7. CPU5 contradicts the repeated read rule.
        cpu=7
        values=dict(summary_cpu=5,summary_cd=17,policy_cpu=7,policy_cd=17)
    if byte and index==2:
        # MOVB entry/summary both print CD7; the field/bus equation gives9.
        # Retain this as an agreed published-target gap, never a silent fix.
        values=dict(summary_cpu=3,summary_cd=7,policy_cpu=3,policy_cd=9,
                    entry_typical_cpu=3 if not(source&7 or destination&7) else None,
                    entry_typical_cd=7 if not(source&7 or destination&7) else None)
    return cpu,hidden,cd,index,values


def fixture(width,source_offset,destination_offset,field,off,index,*,
            byte=False,bank=0,source=2,dest=0,fe=0,ignored=None,
            source_address=None,destination_address=None,alignment_offset=0,tag=None,
            mode='indirect'):
    if bank not in (0,1) or source not in (0,1,2,15) or dest not in (0,1,2,15):
        raise ValueError('unobserved register identity')
    if field not in (0,1) or fe not in (0,1) or (byte and width!=8):
        raise ValueError('undefined copy field')
    src=(0x5000+source_offset if source_address is None else source_address)&MASK32
    dst=(0x6000+destination_offset if destination_address is None else destination_address)&MASK32
    st=initial_status(index)
    st=(st&~(63<<(6*field)))|(((width&31)|(fe<<5))<<(6*field))
    if byte:st=(st&~0xFFF)|(0x001 if ignored is None else ignored)
    a=[0x11223344,0x55667788,0x99AABBCC,st]
    b={q:0xB0102030+q*0x1020304 for q in range(4)};sp=0x12345000
    def put(reg,value):
        nonlocal sp
        if reg==15:sp=value
        elif bank:b[reg]=value
        else:a[reg]=value
    def get(reg):return sp if reg==15 else b[reg] if bank else a[reg]
    # Input addresses describe the first data field. Predecrement pointers
    # start one width above it; aliases then obey sequential double updates.
    put(source,(src+(width if mode=='pre' else 0))&MASK32)
    put(dest,(dst+(width if mode=='pre' else 0))&MASK32)
    initial_a=list(a);initial_b=dict(b);initial_sp=sp
    if mode=='pre':put(source,(get(source)-width)&MASK32)
    src=get(source)
    if mode=='post':put(source,(get(source)+width)&MASK32)
    if mode=='pre':put(dest,(get(dest)-width)&MASK32)
    dst=get(dest)
    if mode=='post':put(dest,(get(dest)+width)&MASK32)
    touched={((address+bit)&MASK32)&~15 for address in (src,dst) for bit in range(width)}
    # Sparse memory also supplies the reset-vector high word. Wrapped
    # source fields may read it, but must keep the initial reset PC at0x1000.
    memory=sorted((word,0 if word==0xFFFFFFF0 else
        ((word>>4)*0x9E37+0x35C6+index*0x123)&65535) for word in touched)
    before=insert(memory,dst,width,extract(memory,src,width,False))
    expected=insert(before,dst,width,extract(before,src,width,False))
    cpu,hidden,cd,table_index,values=counts(src,dst,width,byte=byte,mode=mode)
    selected_cd=values.get('policy_cd',cd)
    label=tag or f'w{width}_s{source_offset}_d{destination_offset}_f{field}_fe{fe}'
    mode_label='' if mode=='indirect' else mode+'_'
    row=dict(name=f'copy_{"movb" if byte else "move"}_{mode_label}{label}_r{bank}_{source}_{dest}_{"off" if off else "hit"}',
        coverage_id='MOVB_IND_IND' if byte else {'indirect':'MOVE_IND_IND','post':'MOVE_POST_POST','pre':'MOVE_PRE_PRE'}[mode],
        opcode=(0x9C00 if byte else {'indirect':0x8800,'post':0x9800,'pre':0xA800}[mode])|(0 if byte else field<<9)|(source<<5)|(bank<<4)|dest,
        regs=initial_a,expected_regs=list(a),initial_b_regs=initial_b,initial_sp=initial_sp,
        expected_extra_regs={**{f'b{q}':v for q,v in b.items()},'sp':sp},
        expected_st=st,cache_disabled=off,states=selected_cd if off else cpu,
        initial_memory=memory,memory_before_measured=before,expected_memory=expected,
        data_copy=dict(source=src,destination=dst,width=width,byte=byte,cpu=cpu,hidden=hidden),
        data_store=dict(address=dst,width=width,cpu=cpu),
        instruction_word_offset=alignment_offset,tail_instructions=32,drain_instructions=-1 if off else 24,
        citation='SPVU001A 13-4,13-6/7; '+('12-119' if byte else {'indirect':'12-137/138','post':'12-141/142','pre':'12-145/146'}[mode]),
        conditions=dict(width=width,field=field,field_extension=fe,source=src,destination=dst,
            source_alignment=alignment(src,width),destination_alignment=alignment(dst,width),
            table_index=table_index,bank=bank,source_register=source,destination_register=dest))
    if mode!='indirect':
        row['conditions']['mode']=mode
        row['data_copy'].update(mode=mode,read_lead=int(mode=='pre'),
                                write_start=cpu-(2 if mode=='post' else 1))
    if values:
        differs=values['policy_cd' if off else 'policy_cpu']!=values['summary_cd' if off else 'summary_cpu']
        row.update(source_values=values,timing_source_status='inferred-conflict-resolution' if differs else 'primary-summary-consistent',
            source_notes=('MOVE index12 prints CPU5/CD17/H7 despite its three source reads. The common read/hidden-write equation selects CPU7/CD17. MOVB index2 prints CPU3/CD7, while the same field equation selects CPU3/CD9; that agreed entry/summary target remains a known gap. Printed alternatives are retained; no official erratum is claimed.' if mode=='indirect' else
                          'Table13-4 pointer copies add one CPU state to the plain copy. Postincrement overlaps one further hidden state; predecrement retains its hidden states. The project selects this common equation for index12 CPU and predecrement index8 CD, retaining the printed alternatives under the owner direction. This is not an official TI correction.'))
    return row


def transactions(case):
    spec=case['data_copy'];address=spec['source'];width=spec['width']
    memory=dict(case['memory_before_measured'])
    count=((address&15)+width+15)//16
    reads=[(0,((address&~15)+16*q)&MASK32,memory[((address&~15)+16*q)&MASK32],0)
           for q in range(count)]
    # The copy may overlap; use the actual pre-measurement image for RMW.
    writes=store_transactions(dict(case,initial_memory=case['memory_before_measured'],measure_pass=0))
    return reads,writes


def copy_cases():
    for off,width,so,do,field,fe in product((False,True),range(1,33),(0,1,7,15),(0,1,7,15),(0,1),(0,1)):
        index=width*32+so*2+do+field
        yield fixture(width,so,do,field,off,index,fe=fe,bank=(index//7)&1)
    for off,so,do,ignored in product((False,True),range(16),range(16),(0x001,0x83F,0x445,0x230)):
        index=so*16+do
        yield fixture(8,so,do,0,off,index,byte=True,bank=ignored&1,ignored=ignored,
            tag=f'byte_s{so}_d{do}_ignored{ignored:03x}')
    for off,bank,width,source,dest in product((False,True),(0,1),(1,8,16,32),(0,2,15),(0,2,15)):
        yield fixture(width,15,1,1,off,width+source+dest,bank=bank,source=source,dest=dest,
            tag=f'identity_w{width}')
    for off,width,displacement in product((False,True),(5,16,32),(-17,-1,0,1,17)):
        yield fixture(width,0,0,0,off,width,source_address=0x5007,
            destination_address=0x5007+displacement,tag=f'overlap_w{width}_d{displacement}')
    for off,width in product((False,True),(1,16,32)):
        yield fixture(width,0,0,1,off,width,source_address=0xFFFFFFF8,
            destination_address=0x8000600F,tag=f'wrap_w{width}')
    for off,flags in product((False,True),range(16)):
        yield fixture(32,15,1,0,off,flags,tag=f'flags{flags}')
    for off,field,width,fe in product((False,True),(0,1),range(1,33),(0,1)):
        ignored=(0x810&~(63<<(6*field)))|(((width&31)|(fe<<5))<<(6*field))
        row=fixture(8,9,15,field,off,width,byte=True,bank=field,ignored=ignored,
            tag=f'ignored_f{field}_w{width}_fe{fe}')
        row['conditions'].update(ignored_field=field,ignored_width=width,ignored_fe=fe)
        yield row
    for off,bank,(width,so,do,byte) in product((False,True),(0,1),
            ((16,0,0,False),(32,15,1,False),(8,9,0,True))):
        yield fixture(width,so,do,1,off,15,bank=bank,source=15,dest=0,byte=byte,
            tag='phase' if width==16 and bank==1 else f'phase_w{width}_s{so}_d{do}')
    # Real consumers distinguish cached retirement from completion of the
    # trailing writes. Source-read waits precede the overlap interval.
    for byte in (False,True):
        for width,so,do,delay in product((8,) if byte else (1,8,16,17,32),
                                       (0,15),(0,15),(0,1,3,7,20)):
            row=fixture(width,so,do,0,False,width+so+do,byte=byte,source=2,dest=0,fe=0,
                tag=f'dependency{delay}_w{width}_s{so}_d{do}')
            row['follow_delay']=delay
            row['following_words']=[0x0300]*delay+[0x8E01 if byte else 0x8401]+[0x0300]*32
            row['drain_instructions']=24+delay
            value=extract(row['expected_memory'],row['data_copy']['destination'],width,byte)
            expected=list(row['expected_regs']);expected[1]=value
            row['expected_follow_regs']=expected
            row['expected_follow_st']=(row['expected_st']&~0xB0000000)|(value&0x80000000)|(0x20000000 if value==0 else 0)
            yield row
    yield from literal_cases()


# TI p.12-138: width,F,source address,destination address,three output words.
TI_FIELDS=(
    (1,1,0x15500,0x15530,(0x0001,0,0)),
    (5,0,0x15500,0x15534,(0x01F0,0,0)),
    (10,1,0x15500,0x1553A,(0xFC00,0x000F,0)),
    (19,0,0x15500,0x1553F,(0x8000,0xFFFF,0x0003)),
    (7,1,0x15504,0x15530,(0x007F,0,0)),
    (13,0,0x1550A,0x15530,(0x1FFF,0,0)),
    (8,1,0x1550D,0x15534,(0x0FF0,0,0)),
    (28,0,0x1550D,0x15530,(0xFFFF,0x0FFF,0)),
    (23,1,0x15505,0x15535,(0xFFE0,0x0FFF,0)),
    (31,0,0x15508,0x15536,(0xFFC0,0xFFFF,0x001F)),
    (31,1,0x15508,0x15531,(0xFFFE,0xFFFF,0)),
    (32,0,0x1550A,0x15530,(0xFFFF,0xFFFF,0)),
    (32,1,0x15500,0x1553A,(0xFC00,0xFFFF,0x03FF)),
)
TI_BYTES=(
    (0,0,0x00EF,0),(0,1,0x01DE,0),(0,9,0xDE00,1),(0,12,0xF000,0x000E),
    (1,0,0x00F7,0),(1,1,0x01EE,0),(1,9,0xEE00,1),(1,12,0x7000,0x000F),
    (9,0,0x00E6,0),(9,1,0x01CC,0),(9,9,0xCC00,1),(9,12,0x6000,0x000E),
    (12,0,0x00BC,0),(12,1,0x0178,0),(12,9,0x7800,1),(12,12,0xC000,0x000B),
)


def literal_cases():
    for off,bank in product((False,True),(0,1)):
        for q,(width,field,src,dst,words) in enumerate(TI_FIELDS):
            row=fixture(width,src&15,dst&15,field,off,q,bank=bank,source=0,dest=1,
                source_address=src,destination_address=dst,tag=f'guide_field{q}')
            memory=[(0x15500+16*k,0xFFFF) for k in range(3)]+[(0x15530+16*k,0) for k in range(3)]
            final=memory[:3]+[(0x15530+16*k,value) for k,value in enumerate(words)]
            row.update(initial_memory=memory,memory_before_measured=final,expected_memory=final,
                literal_model_memory=insert(memory,dst,width,extract(memory,src,width,False)),
                literal_citation='SPVU001A 12-138')
            if q==12:
                row['literal_source_notes']='The final printed mnemonic selects F0 while its field column shows FS1=32. This semantic vector programs and selects FS1=32; both field selections are also covered by the full width matrix.'
            yield row
        for q,(so,do,low,high) in enumerate(TI_BYTES):
            src=0x5000+so;dst=0x6000+do
            row=fixture(8,so,do,0,off,q,byte=True,bank=bank,source=0,dest=1,
                source_address=src,destination_address=dst,tag=f'guide_byte{q}')
            memory=[(0x5000,0xCDEF),(0x5010,0x89AB),(0x6000,0),(0x6010,0)]
            final=memory[:2]+[(0x6000,low),(0x6010,high)]
            row.update(initial_memory=memory,memory_before_measured=final,expected_memory=final,
                literal_model_memory=insert(memory,dst,8,extract(memory,src,8,False)),literal_citation='SPVU001A 12-119')
            yield row
