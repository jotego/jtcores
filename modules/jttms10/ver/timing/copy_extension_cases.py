#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Extended source / postincrement destination copies, TI pp.12-149..156."""
from itertools import product
from copy_cases import fixture, TI_FIELDS
from load_cases import extract
from store_cases import insert


def copy_extension_cases():
    for mode,off,width,so,do,field,fe in product(
            ('offset_post','absolute_post'),(False,True),range(1,33),(0,1,7,15),(0,1,7,15),(0,1),(0,1)):
        index=width*32+so*2+do+field
        yield fixture(width,so,do,field,off,index,fe=fe,bank=(index//7)&1,mode=mode,
                      displacement=(-32768,-1,0,1,32767)[index%5] if mode=='offset_post' else 0)
    for off,bank,width,source,dest in product((False,True),(0,1),(1,8,16,32),(0,2,15),(0,2,15)):
        yield fixture(width,15,1,1,off,width+source+dest,bank=bank,source=source,dest=dest,
                      tag=f'identity_w{width}',mode='offset_post',displacement=-17)
    for off,bank,width,dest in product((False,True),(0,1),(1,8,16,32),(0,2,15)):
        yield fixture(width,15,1,1,off,width+dest,bank=bank,dest=dest,
                      tag=f'identity_w{width}',mode='absolute_post')
    for mode,off,width,delta in product(('offset_post','absolute_post'),(False,True),(5,16,32),(-17,-1,0,1,17)):
        yield fixture(width,0,0,0,off,width,source_address=0x5007,destination_address=0x5007+delta,
                      mode=mode,displacement=32767 if mode=='offset_post' else 0,
                      tag=f'overlap_w{width}_d{delta}')
    for mode,off,width in product(('offset_post','absolute_post'),(False,True),(1,16,32)):
        yield fixture(width,0,0,1,off,width,source_address=0xFFFFFFF8,destination_address=0x8000600F,
                      mode=mode,displacement=-32768 if mode=='offset_post' else 0,tag=f'wrap_w{width}')
    for mode,off,flags in product(('offset_post','absolute_post'),(False,True),range(16)):
        yield fixture(32,15,1,0,off,flags,mode=mode,tag=f'flags{flags}')
    for mode,off,bank,width in product(('offset_post','absolute_post'),(False,True),(0,1),(16,32)):
        yield fixture(width,0 if width==16 else 15,0 if width==16 else 1,1,off,15,
                      bank=bank,source=15,dest=0,mode=mode,displacement=-32768 if mode=='offset_post' else 0,
                      tag=f'phase_w{width}')
    for mode,width,so,do,delay in product(('offset_post','absolute_post'),(1,8,16,17,32),(0,15),(0,15),(0,1,3,7,20)):
        row=fixture(width,so,do,0,False,width+so+do,mode=mode,source=2,dest=0,
                    displacement=-32768 if mode=='offset_post' else 0,
                    tag=f'dependency{delay}_w{width}_s{so}_d{do}')
        address=row['data_copy']['destination']
        row['regs'][1]=address;row['expected_regs'][1]=address
        row['follow_delay']=delay;row['following_words']=[0x0300]*delay+[0x8421]+[0x0300]*32
        row['drain_instructions']=24+delay
        value=extract(row['expected_memory'],address,width,False)
        row['expected_follow_regs']=list(row['expected_regs']);row['expected_follow_regs'][1]=value
        row['expected_follow_st']=(row['expected_st']&~0xB0000000)|(value&0x80000000)|(0x20000000 if value==0 else 0)
        yield row
    for mode,missing,bank,width,offset in product(('offset_post','absolute_post'),(1,2),(0,1),(16,32),(0,15)):
        if mode=='offset_post' and missing==2:continue
        row=fixture(width,offset,offset,0,False,width,mode=mode,bank=bank,
                    tag=f'phase_cold{missing}_w{width}_o{offset}')
        row.update(cache_miss='copy_extension',miss_word=missing,measure_pass=0,
                   instruction_word_offset=4-missing,states=row['states']+9,drain_instructions=-2,
                   memory_before_measured=row['initial_memory'],expected_memory=row['memory_before_measured'])
        yield row
    yield from literal_cases()


def literal_cases():
    # p.12-156 reprints these data results. Its Before/After headings and
    # several pointers conflict with the mnemonic; use the explicit syntax
    # and the memory results, keeping that source limitation visible.
    for off,bank in product((False,True),(0,1)):
        for q,(width,field,src,dst,words) in enumerate(TI_FIELDS):
            row=fixture(width,src&15,dst&15,field,off,q,mode='absolute_post',bank=bank,dest=1,
                        source_address=src,destination_address=dst,tag=f'guide_field{q}')
            memory=[(0x15500+16*k,0xFFFF) for k in range(3)]+[(0x15530+16*k,0) for k in range(3)]
            final=memory[:3]+[(0x15530+16*k,value) for k,value in enumerate(words)]
            row.update(initial_memory=memory,memory_before_measured=final,expected_memory=final,
                       literal_model_memory=insert(memory,dst,width,extract(memory,src,width,False)),
                       literal_citation='SPVU001A 12-156',
                       literal_source_notes='The example has inconsistent Before/After pointer columns; this fixture follows the explicit @source,*Rd+ syntax and retains the printed memory results.')
            yield row
