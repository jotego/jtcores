#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Two-address copies: SPVU001A pp.12-121..125,12-151/152,12-157/158."""
from itertools import product
from copy_cases import fixture, TI_FIELDS, TI_BYTES
from load_cases import extract
from store_cases import insert

MODES=('offset_offset','absolute_absolute')
DISPLACEMENTS=(-32768,-1,0,1,32767)


def copy_pair_cases():
    for mode,off,width,so,do,field,fe in product(MODES,(False,True),range(1,33),(0,1,7,15),(0,1,7,15),(0,1),(0,1)):
        index=width*32+so*2+do+field
        yield fixture(width,so,do,field,off,index,fe=fe,bank=(index//7)&1,mode=mode,
                      displacement=DISPLACEMENTS[index%5],destination_displacement=DISPLACEMENTS[(index+2)%5])
    for mode,off,so,do,ignored in product(MODES,(False,True),range(16),range(16),(0x001,0x83F,0x445,0x230)):
        index=so*16+do
        yield fixture(8,so,do,0,off,index,byte=True,bank=ignored&1,ignored=ignored,mode=mode,
                      displacement=DISPLACEMENTS[index%5],destination_displacement=DISPLACEMENTS[(index+2)%5],
                      tag=f'byte_s{so}_d{do}_ignored{ignored:03x}')
    for off,bank,width,source,dest in product((False,True),(0,1),(1,8,16,32),(0,2,15),(0,2,15)):
        yield fixture(width,15,1,1,off,width+source+dest,bank=bank,source=source,dest=dest,
                      tag=f'identity_w{width}',mode='offset_offset',displacement=-17,destination_displacement=17)
    for mode,off,byte,width,delta in product(MODES,(False,True),(False,True),(5,8,16,32),(-17,-1,0,1,17)):
        if byte and width!=8:continue
        yield fixture(width,0,0,0,off,width,source_address=0x5007,destination_address=0x5007+delta,
                      mode=mode,byte=byte,displacement=32767,destination_displacement=-32768,
                      tag=f'overlap_w{width}_d{delta}')
    for mode,off,byte,width in product(MODES,(False,True),(False,True),(1,8,16,32)):
        if byte and width!=8:continue
        yield fixture(width,0,0,1,off,width,source_address=0xFFFFFFF8,destination_address=0x8000600F,
                      mode=mode,byte=byte,displacement=-32768,destination_displacement=32767,tag=f'wrap_w{width}')
    for mode,off,byte,flags in product(MODES,(False,True),(False,True),range(16)):
        yield fixture(8 if byte else 32,15,1,0,off,flags,mode=mode,byte=byte,tag=f'flags{flags}')
    for mode,off,field,width,fe in product(MODES,(False,True),(0,1),range(1,33),(0,1)):
        ignored=(0x810&~(63<<(6*field)))|(((width&31)|(fe<<5))<<(6*field))
        row=fixture(8,9,15,field,off,width,byte=True,bank=field,ignored=ignored,
                    mode=mode,tag=f'ignored_f{field}_w{width}_fe{fe}')
        row['conditions'].update(ignored_field=field,ignored_width=width,ignored_fe=fe)
        yield row
    for mode,off,bank,byte,width in product(MODES,(False,True),(0,1),(False,True),(8,16,32)):
        if byte and width!=8:continue
        yield fixture(width,15 if width==32 else 0,1 if width==32 else 0,1,off,15,
                      bank=bank,source=15,dest=0,mode=mode,byte=byte,
                      displacement=-32768,destination_displacement=32767,tag=f'phase_w{width}')
    for mode,byte,width,so,do,delay in product(MODES,(False,True),(1,8,16,17,32),(0,15),(0,15),(0,1,3,7,20)):
        if byte and width!=8:continue
        row=fixture(width,so,do,0,False,width+so+do,mode=mode,byte=byte,source=2,dest=0,
                    displacement=-32768,destination_displacement=32767,
                    tag=f'dependency{delay}_w{width}_s{so}_d{do}')
        address=row['data_copy']['destination']
        row['regs'][1]=address;row['expected_regs'][1]=address
        row['follow_delay']=delay;row['following_words']=[0x0300]*delay+[0x8E21 if byte else 0x8421]+[0x0300]*32
        row['drain_instructions']=24+delay
        value=extract(row['expected_memory'],address,width,byte)
        row['expected_follow_regs']=list(row['expected_regs']);row['expected_follow_regs'][1]=value
        row['expected_follow_st']=(row['expected_st']&~0xB0000000)|(value&0x80000000)|(0x20000000 if value==0 else 0)
        yield row
    for mode,missing,byte,field,width,offset in product(MODES,(1,2,3,4),(False,True),(0,1),(8,16,32),(0,15)):
        if mode=='offset_offset' and missing>2 or byte and width!=8:continue
        row=fixture(width,offset,offset,field,False,width,mode=mode,byte=byte,
                    tag=f'phase_cold{missing}_w{width}_o{offset}_f{field}')
        row.update(cache_miss='copy_extension',miss_word=missing,measure_pass=0,
                   instruction_word_offset=4-missing,states=row['states']+9,drain_instructions=-2,
                   memory_before_measured=row['initial_memory'],expected_memory=row['memory_before_measured'])
        if mode=='absolute_absolute' and missing==1:
            # Four address words fill the entire next subsegment. The next
            # opcode is in another cold subsegment and waits for the writes.
            row['next_opcode_miss']=True
            row['states']+=9+row['data_copy']['hidden']
        yield row
    yield from literal_cases()


def literal_cases():
    # The absolute entries print these exact operands and numeric results.
    for off in (False,True):
        for q,(width,field,src,dst,words) in enumerate(TI_FIELDS):
            row=fixture(width,src&15,dst&15,field,off,q,mode='absolute_absolute',
                        source_address=src,destination_address=dst,tag=f'guide_field{q}')
            memory=[(0x15500+16*k,0xFFFF) for k in range(3)]+[(0x15530+16*k,0) for k in range(3)]
            final=memory[:3]+[(0x15530+16*k,value) for k,value in enumerate(words)]
            row.update(initial_memory=memory,memory_before_measured=final,expected_memory=final,
                       literal_model_memory=insert(memory,dst,width,extract(memory,src,width,False)),
                       literal_citation='SPVU001A 12-158')
            if q==12:
                row['literal_source_notes']='The printed F0 mnemonic conflicts with its FS1=32 column. This vector selects the defined FS1; the full width matrix covers both fields.'
            yield row
        for q,(so,do,low,high) in enumerate(TI_BYTES):
            src=0x10000+so;dst=0x11000+do
            row=fixture(8,so,do,0,off,q,byte=True,mode='absolute_absolute',
                        source_address=src,destination_address=dst,tag=f'guide_byte{q}')
            memory=[(0x10000,0xCDEF),(0x10010,0x89AB),(0x11000,0),(0x11010,0)]
            final=memory[:2]+[(0x11000,low),(0x11010,high)]
            row.update(initial_memory=memory,memory_before_measured=final,expected_memory=final,
                       literal_model_memory=insert(memory,dst,8,extract(memory,src,8,False)),
                       literal_citation='SPVU001A 12-125')
            yield row
    # p.12-122: signed endpoint operands keep the effective address fixed.
    for off,bank,so,do in product((False,True),(0,1),(0,12,32767,-32768),(0,1,9,12,32767,-32768)):
        source=0x10000+(12 if so==12 else 0)
        dest=0x11000+(do if do in (1,9,12) else 0)
        literal=next((low,high) for a,b,low,high in TI_BYTES if a==source-0x10000 and b==dest-0x11000)
        row=fixture(8,source&15,dest&15,0,off,0,mode='offset_offset',byte=True,bank=bank,source=0,dest=1,
                    source_address=source,destination_address=dest,displacement=so,destination_displacement=do,
                    tag=f'guide_byte_so{so}_do{do}')
        memory=[(0x10000,0xCDEF),(0x10010,0x89AB),(0x11000,0),(0x11010,0)]
        final=memory[:2]+[(0x11000,literal[0]),(0x11010,literal[1])]
        row.update(initial_memory=memory,memory_before_measured=final,expected_memory=final,
                   literal_model_memory=insert(memory,dest,8,extract(memory,source,8,False)),literal_citation='SPVU001A 12-122')
        yield row
