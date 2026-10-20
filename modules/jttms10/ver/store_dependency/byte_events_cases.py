#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""First-pass CD byte stores followed by dependent loads or external HOLD.

SPVU001A §§6.2,11.3,13.1.1 and Tables13-1/2/4. Expectations use the
existing bit insertion/extraction functions; no RTL or captured data is read.
"""
from copy_cases import fixture as copy_fixture
from load_cases import extract
from store_cases import fixture as store_fixture
from run import program


def store(copy, offset, tag):
    case=(copy_fixture(8,0,offset,0,True,offset,byte=True,source=0,dest=1,tag=tag)
          if copy else store_fixture('absolute',8,offset,0,True,offset,
                                     byte=True,source=2,tag=tag))
    case.update(measure_pass=0,drain_instructions=-2,expected_next_opcode=0x0300)
    if copy:
        # A first-pass copy reads the original source and destination, rather
        # than the image after an unmeasured warm-up copy.
        case['memory_before_measured']=case['initial_memory']
    return case


def locate(case):
    words,start,end=program(case)
    case.update(test_pc=start,next_pc=end)
    return case,words


def following_cases():
    for copy in (False,True):
        for offset in (0,8,9,15):
            for delay in (0,3):
                case=store(copy,offset,f'cd_follow_o{offset}_k{delay}')
                destination=2 if copy else 1
                if not copy:
                    case['regs'][1]=case['expected_regs'][1]=case['data_store']['address']
                opcode=0x8e00 | (1<<5) | destination  # MOVB *A1,Ad
                case.update(byte_store_event=dict(kind='following',delay=delay),
                    drain_instructions=delay+1,
                    following_words=[0x0300]*delay+[opcode]+[0x0300]*4,
                    expected_next_opcode=0x0300 if delay else opcode)
                value=extract(case['expected_memory'],case['data_store']['address'],8,True)
                regs=list(case['expected_regs']);regs[destination]=value
                case['expected_follow_regs']=regs
                case['expected_follow_extra_regs']=dict(case['expected_extra_regs'])
                case['expected_follow_st']=((case['expected_st']&~0xb0000000)
                    | (value&0x80000000) | (0x20000000 if value==0 else 0))
                case,words=locate(case)
                case['follow_pc']=case['next_pc']+16*(delay+1)
                yield case,words


def hold_cases():
    for copy,offset in ((False,0),(False,15),(True,0),(True,8)):
        case=store(copy,offset,f'cd_hold_o{offset}')
        case['byte_store_event']=dict(kind='hold')
        yield locate(case)
