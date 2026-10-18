#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Pointer-copy semantics and literal vectors, SPVU001A pp.12-141..146."""
from itertools import product
from copy_cases import fixture, TI_FIELDS
from load_cases import extract
from store_cases import insert


def pointer_copy_cases():
    for mode,off,width,so,do,field,fe in product(
            ('post','pre'),(False,True),range(1,33),(0,1,7,15),(0,1,7,15),(0,1),(0,1)):
        index=width*32+so*2+do+field
        yield fixture(width,so,do,field,off,index,fe=fe,bank=(index//7)&1,mode=mode)
    for mode,off,bank,width,source,dest in product(
            ('post','pre'),(False,True),(0,1),(1,8,16,32),(0,2,15),(0,2,15)):
        yield fixture(width,15,1,1,off,width+source+dest,bank=bank,source=source,dest=dest,
                      tag=f'identity_w{width}',mode=mode)
    for mode,off,width,displacement in product(('post','pre'),(False,True),(5,16,32),(-17,-1,0,1,17)):
        yield fixture(width,0,0,0,off,width,source_address=0x5007,
                      destination_address=0x5007+displacement,tag=f'overlap_w{width}_d{displacement}',mode=mode)
    for mode,off,width in product(('post','pre'),(False,True),(1,16,32)):
        yield fixture(width,0,0,1,off,width,source_address=0xFFFFFFF8,
                      destination_address=0x8000600F,tag=f'wrap_w{width}',mode=mode)
    for mode,off,flags in product(('post','pre'),(False,True),range(16)):
        yield fixture(32,15,1,0,off,flags,tag=f'flags{flags}',mode=mode)
    for mode,off,bank,width in product(('post','pre'),(False,True),(0,1),(16,32)):
        yield fixture(width,0 if width==16 else 15,0 if width==16 else 1,1,off,15,
                      bank=bank,source=15,dest=0,tag=f'phase_w{width}',mode=mode)
    for mode,width,so,do,delay in product(('post','pre'),(1,8,16,17,32),(0,15),(0,15),(0,1,3,7,20)):
        row=fixture(width,so,do,0,False,width+so+do,source=2,dest=0,fe=0,mode=mode,
                    tag=f'dependency{delay}_w{width}_s{so}_d{do}')
        # A1 retains the written field's address after A0's pointer update.
        address=row['data_copy']['destination']
        row['regs'][1]=address;row['expected_regs'][1]=address
        row['follow_delay']=delay
        row['following_words']=[0x0300]*delay+[0x8421]+[0x0300]*32
        row['drain_instructions']=24+delay
        value=extract(row['expected_memory'],address,width,False)
        row['expected_follow_regs']=list(row['expected_regs']);row['expected_follow_regs'][1]=value
        row['expected_follow_st']=(row['expected_st']&~0xB0000000)|(value&0x80000000)|(0x20000000 if value==0 else 0)
        yield row
    yield from literal_cases()


# p.12-142: width,F,initial source/destination,three output words.
POST_FIELDS=(
    (1,1,0x15500,0x1553D,(0x2000,0,0)),
    (5,0,0x15505,0x15538,(0x1F00,0,0)),
    (10,1,0x1550A,0x1553F,(0x8000,0x01FF,0)),
    (19,0,0x1550D,0x15530,(0xFFFF,0x0007,0)),
    (7,1,0x15510,0x15532,(0x01FC,0,0)),
    (13,0,0x15511,0x1553A,(0xFC00,0x007F,0)),
    (8,1,0x15513,0x1553F,(0x8000,0x007F,0)),
    (28,0,0x15510,0x1553A,(0xFC00,0xFFFF,0x003F)),
    (23,1,0x15518,0x15534,(0xFFF0,0x07FF,0)),
    (31,0,0x15510,0x15530,(0xFFFF,0x7FFF,0)),
    (31,1,0x15511,0x1553D,(0xE000,0xFFFF,0x0FFF)),
    (32,0,0x15510,0x1553F,(0x8000,0xFFFF,0x7FFF)),
    (32,1,0x15500,0x15530,(0xFFFF,0xFFFF,0)),
)


def literal_cases():
    for mode,off,bank in product(('post','pre'),(False,True),(0,1)):
        for q,(width,field,src,dst,words) in enumerate(POST_FIELDS if mode=='post' else TI_FIELDS):
            row=fixture(width,src&15,dst&15,field,off,q,bank=bank,source=0,dest=1,
                        source_address=src,destination_address=dst,tag=f'guide_field{q}',mode=mode)
            memory=[(0x15500+16*k,0xFFFF) for k in range(3)]+[(0x15530+16*k,0) for k in range(3)]
            final=memory[:3]+[(0x15530+16*k,value) for k,value in enumerate(words)]
            row.update(initial_memory=memory,memory_before_measured=final,expected_memory=final,
                       literal_model_memory=insert(memory,dst,width,extract(memory,src,width,False)),
                       literal_citation='SPVU001A '+('12-142' if mode=='post' else '12-146'))
            yield row
