#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""TI load address modes and physical register identities, independent of RTL."""
from alu_cases import initial_status
from load_cases import extract
from oracle import load_states
from scalar_cases import MASK32,N,Z,V

PAGES={'indirect':'12-135/136','post':'12-139/140','pre':'12-143/144',
       'offset':'12-147/148','absolute':'12-153/154'}
BYTE_PAGES={'indirect':'12-118','offset':'12-120','absolute':'12-123'}
BASES={'indirect':0x8400,'post':0x9400,'pre':0xA400,'offset':0xB400,'absolute':0x05A0}
BYTE_BASES={'indirect':0x8E00,'offset':0xAE00,'absolute':0x07E0}
COVERAGE={'indirect':'MOVE_IND_R','post':'MOVE_POST_R','pre':'MOVE_PRE_R',
          'offset':'MOVE_OFF_R','absolute':'MOVE_ABS_R'}
BYTE_COVERAGE={'indirect':'MOVB_IND_R','offset':'MOVB_OFF_R','absolute':'MOVB_ABS_R'}


def fixture(mode,width,offset,field,sign,off,bank,source,dest,index,*,byte=False,
            displacement=None,base=None,ignored=None,tag=None):
    status=initial_status(index)
    shift=6*field
    status=(status & ~(63<<shift)) | (((width&31)|(int(sign)<<5))<<shift)
    if ignored is not None:
        status=(status & ~0xFFF) | ignored
    address=((base if base is not None else (0x80006000 if index&1 else 0x6000))+offset)&MASK32
    pattern=(0,0xFFFFFFFFFFFF,0xE1709B6DA5C3,0xAAAAAAAAAAAA,0x555555555555)[index%5]
    memory=[(((address&~15)+16*i)&MASK32,(pattern>>(16*i))&0xFFFF) for i in range(3)]
    # A wrapped field shares the reset vector's upper word; keep that word
    # zero so the real reset vector still selects the program at 00001000.
    if base==0xFFFFFFF0:memory=[(0xFFFFFFF0,0),(0,0x5A5A),(0x10,0xA5A5)]
    a=[0x11223344,0x55667788,0x99AABBCC,status]
    b={0:0xB0102030,1:0xB1425364,2:0xB2758697,3:0xB3A8B9CA}
    sp=0x12345000
    if mode=='offset':
        displacement=(-32768,-1,0,1,32767)[index%5] if displacement is None else displacement
    extensions=([displacement&0xFFFF] if mode=='offset' else
                [address&0xFFFF,address>>16] if mode=='absolute' else [])
    pointer=(address+width if mode=='pre' else address-displacement if mode=='offset' else address)&MASK32
    if mode!='absolute':
        if source==15:sp=pointer
        elif bank:b[source]=pointer
        else:a[source]=pointer
    expected_a=list(a);expected_b={f'b{r}':v for r,v in b.items()};expected_b['sp']=sp
    def write_expected(register,value):
        if register==15:expected_b['sp']=value
        elif bank:expected_b[f'b{register}']=value
        else:expected_a[register]=value
    if mode in ('pre','post'):
        write_expected(source,(pointer+width if mode=='post' else pointer-width)&MASK32)
    value=extract(memory,address,width,sign or byte)
    write_expected(dest,value)
    flags=(status & ~(N|Z|V)) | (value&N) | (Z if value==0 else 0)
    opcode=(BYTE_BASES[mode] if byte else BASES[mode] | (field<<9)) | (bank<<4) | dest
    if mode!='absolute':opcode|=source<<5
    name=tag or f'w{width}_o{offset}_f{field}_s{int(sign)}_r{bank}_{source}_{dest}_q{index}'
    row=dict(name=f'loadmode_{"movb" if byte else "move"}_{mode}_{name}_{"off" if off else "hit"}',
        coverage_id=(BYTE_COVERAGE if byte else COVERAGE)[mode],opcode=opcode,extensions=extensions,
        regs=a,initial_b_regs=b,initial_sp=sp,expected_regs=expected_a,expected_extra_regs=expected_b,
        expected_st=flags,cache_disabled=off,initial_memory=memory,
        states=load_states(address=address,width=width,signed=sign,byte=byte,cache_disabled=off,mode=mode),
        data_load=dict(address=address,width=width,signed=sign,byte=byte,mode=mode),
        citation='SPVU001A 13-5 Table13-1; '+(BYTE_PAGES if byte else PAGES)[mode],
        conditions=dict(mode=mode,width=width,offset=offset,field=field,signed=sign,bank=bank,
            source=source if mode!='absolute' else None,destination=dest,displacement=displacement,
            alias=source==dest and mode!='absolute',ignored_field_definition=ignored))
    if mode=='absolute' and not byte:
        row['source_notes']='Table13-1 and §5.4.7 supply CD counts; p12-153 prints conflicting 5/15 and 7/13. Postulated entry typo, not an official erratum.'
    if mode=='post' and source==dest:
        row['source_notes']='Loaded data wins pointer alias writeback; interpretation of p12-139 corroborated by MAME MOVE_NI_R (p12-143 states the predecrement rule explicitly).'
    return row


def load_mode_cases():
    pairs=((2,0),(0,0),(15,0),(0,15),(15,15),(3,1))
    for off in (False,True):
        for mode in ('indirect','post','pre','offset','absolute'):
            widths=range(1,33) if mode in ('post','pre') else (1,5,8,16,17,31,32)
            index=0
            for width in widths:
                for offset in (0,1,7,15):
                    for field in (0,1):
                        for sign in (False,True):
                            source,dest=pairs[index%len(pairs)];bank=(index//len(pairs))&1
                            if not bank and source==3:source=2
                            yield fixture(mode,width,offset,field,sign,off,bank,source,dest,index)
                            index+=1
        for mode in ('indirect','offset','absolute'):
            for offset in range(16):
                for q,ignored in enumerate((0x001,0x83F,0x445,0x230)):
                    index=4*offset+q;source,dest=pairs[index%5]
                    yield fixture(mode,8,offset,0,True,off,index&1,source,dest,index,byte=True,
                                  ignored=ignored,tag=f'o{offset}_ignored{ignored:03x}_r{index&1}')
        for mode in ('indirect','post','pre','offset','absolute'):
            for bank in (0,1):
                for q,(source,dest) in enumerate(((15,0),(0,15),(15,15))):
                    yield fixture(mode,32,8,1,False,off,bank,source,dest,q,base=0xFFFFFFF0,
                                  displacement=32767,tag=f'wrap_r{bank}_{source}_{dest}')
    # Cold extension subsegments: current opcode (and, for miss2, low word)
    # is resident; the next required instruction word forces a four-word fill.
    for byte in (False,True):
        vectors=((8,0,False),(8,15,True)) if byte else ((16,0,False),(5,15,True),(32,15,True))
        for mode in ('offset','absolute'):
            for bank in (0,1):
                for q,(width,offset,sign) in enumerate(vectors):
                    for missing in ((1,2) if mode=='absolute' else (1,)):
                        row=fixture(mode,width,offset,1,sign,False,bank,15,0,2+q,
                            byte=byte,ignored=0x001 if byte else None,
                            tag=f'{"phase_cold" if (not byte and mode=="absolute" and bank==0 and q==0 and missing==2) else "cold"}{missing}_w{width}_o{offset}_r{bank}')
                        row['name']=row['name'].removesuffix('_hit')
                        row.update(cache_miss='load_extension',miss_word=missing,
                                   instruction_word_offset=4-missing,measure_pass=0,
                                   states=row['states']+9)
                        row['conditions']['missing_extension']=missing
                        yield row

    # One fixed bus-order probe for each new form, batched by --case _phase_
    # under all six remaining early CEN phases in the normal runner.
    for byte,mode in ((False,'post'),(False,'pre'),(False,'offset'),(False,'absolute'),
                      (True,'offset'),(True,'absolute')):
        yield fixture(mode,8 if byte else 5,15,1,True,True,1,15,0,2,
            byte=byte,ignored=0x001 if byte else None,base=0x80006000,
            displacement=-32768,tag='phase_r1')
