#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""PIXT *Rs,Rd: independent bit model, SPVU001A12-218/219 and §7.3.

Only aligned 1/2/4/8/16-bit linear pixels are defined (§4.2.1,p4-6).
NCZ are undefined: preserving them is an explicit implementation choice.
"""
from itertools import product
from load_cases import extract
from oracle import load_states
MASK32=(1<<32)-1
SIZES=(1,2,4,8,16)


def pixel_value(word,size,offset,pmask):
    if size not in SIZES or offset not in range(0,16,size):
        raise ValueError('pixel size/alignment outside TI defined domain')
    return sum(((word>>(offset+q)&1) and not (pmask>>(offset+q)&1))<<q for q in range(size))


def fixture(size,offset,bank,off,*,pmask=0,status=0xF0200810,address=None,tag='base',source=2,destination=0,
            source_word=0xA596,control=0,alignment=None,code_source=False,cold=False):
    if size not in SIZES or offset not in range(0,16,size):raise ValueError('pixel size/alignment')
    if source not in range(16) or destination not in range(16):raise ValueError('register number')
    address=(0x6000+offset if address is None else address)&MASK32
    if address%size:raise ValueError('linear pixel address must be pixel aligned (TI7.3)')
    if cold and off:raise ValueError('CD cannot have a cache miss')
    holder=4 if bank==0 and source==3 else 3
    seed=0x13579B00
    registers={f'a{q}':seed+q for q in range(15)}
    registers.update({f'b{q}':seed+16+q for q in range(15)});registers['sp']=seed+15
    name=lambda q:'sp' if q==15 else f'{"b" if bank else "a"}{q}'
    registers[f'a{holder}']=status;registers[name(source)]=address
    value=pixel_value(source_word,size,address&15,pmask)
    expected=dict(registers);expected[name(destination)]=value
    memory=[(address&~15,source_word),(0x6500,0x35C6)]
    # Wrapped words that are reset vectors must preserve the boot address.
    if (address&~15) in (0xFFFFFFE0,0xFFFFFFF0):raise ValueError('pixel input overlaps reset vector')
    row=dict(name=f'pixel_read_ps{size}_o{offset}_r{bank}_{tag}_{"off" if off else "hit"}',coverage_id='PIXT_LIN_R',opcode=0xFA00|(source<<5)|(bank<<4)|destination,
        regs=[registers[f'a{q}'] for q in range(4)],expected_regs=[expected[f'a{q}'] for q in range(4)],
        expected_extra_regs={k:v for k,v in expected.items() if k not in ('a0','a1','a2','a3')},observe_all=True,
        initial_all_regs=registers,seed=seed,status_holder=holder,source_register=source,bank=bank,
        expected_st=(status&~0x10000000)|(0x10000000 if value else 0),states=13 if cold else 7 if off else 4,cache_disabled=off,
        initial_memory=memory,expected_memory=memory,drain_instructions=-1,pixel_load=True,control=control,
        setup_io=[(0xC0000150,size),(0xC0000160,pmask)],data_load=dict(address=address,width=size,signed=False,mode='pixel'),
        citation='SPVU001A12-218/219;4.2.1p4-6;7.3',conditions=dict(size=size,offset=offset,bank=bank,pmask=pmask,status=status,source=source,destination=destination,control=control))
    if alignment is not None:row['instruction_word_offset']=alignment
    if cold:row.update(cache_miss='pixel_next',measure_pass=0,instruction_word_offset=3)
    if code_source:
        # Program length is independent of the literal source address.
        _,pc,_=program(row,lambda v,r:[0x09E0|r,v&65535,v>>16])
        return fixture(size,0,bank,off,pmask=pmask,status=status,address=pc,tag=tag,source=source,destination=destination,
            source_word=row['opcode'],control=control,alignment=alignment)
    return row


def program(case,movi):
    words=movi(0xC00000B0,14)+movi((0x8018 if case['cache_disabled'] else 0x18)|case['control'],13)+[0x0550,0x81AE]
    for a,v in case['setup_io']:words+=movi(a,14)+movi(v,13)+[0x0550,0x81AE]
    words += case.get('setup_words', [])
    while len(words)%32:words.append(0x0300)
    loop_index=len(words);loop=0x1000+16*loop_index
    words+=movi(case['seed'],0)
    for q in range(1,16):words += [0x4C00|q,0x1000|(q<<5)|q]
    for q in range(15):words += [0x4E00|q,0x1000|((16+q)<<5)|0x10|q]
    for name,value in case.get('register_overrides',{}).items():
        words+=movi(value,15 if name=='sp' else int(name[1:])+(16 if name.startswith('b') else 0))
    reg=case['source_register']+(16 if case['bank'] and case['source_register']!=15 else 0)
    words+=movi(case.get('source_value',case['data_load']['address']),reg)+movi(case['initial_all_regs'][f'a{case["status_holder"]}'],case['status_holder'])
    words+=[0x01A0|case['status_holder']]+[0x0300]*12
    if 'instruction_word_offset' in case:
        while len(words)%4!=case['instruction_word_offset']:words.append(0x0300)
    start=0x1000+16*len(words);words+=[case['opcode']];next_pc=0x1000+16*len(words)
    words+=case.get('following_words',[0x0300]*4)
    if 'control_follow' in case:case['follow_pc']=next_pc+16
    words += [0x0300]*4+[0xC080,loop&65535,loop>>16]
    if (len(words)-1)//32-loop_index//32>=4:raise ValueError('pixel fixture exceeds four warm cache segments')
    if len(case['initial_memory'])>64:raise ValueError('sparse input limit')
    return words,start,next_pc


def following(case,bank,unaligned):
    """A real field load follows immediately, retaining all register checks."""
    address=0x700F if unaligned else 0x7000
    memory=case['initial_memory']+[(0x7000,0xA55A),(0x7010,0x3CC3),(0x7020,0x5678)]
    case['initial_memory']=case['expected_memory']=memory
    pointer=f'{"b" if bank else "a"}2'
    # The pixel read uses source7/destination6, so A/B2 remains available.
    case['initial_all_regs'][pointer]=address
    case['expected_extra_regs'][pointer]=address if bank else case['expected_extra_regs'].get(pointer,0)
    if not bank:
        del case['expected_extra_regs'][pointer]
        case['regs'][2]=case['expected_regs'][2]=address
    case['register_overrides']={pointer:address}
    value=extract(memory,address,16,False)
    case['following_words']=[0x8440|(bank<<4)]
    case['control_follow']=dict(states=load_states(address=address,width=16,signed=False),transfers=1+unaligned,
        data_load=dict(address=address,width=16,signed=False),initial_memory=memory)
    case['expected_follow_regs']=list(case['expected_regs']);extra=dict(case['expected_extra_regs'])
    if bank:extra['b0']=value
    else:case['expected_follow_regs'][0]=value
    case['expected_follow_extra_regs']=extra
    case['expected_follow_st']=(case['expected_st']&~0xB0000000)|(0x20000000 if value==0 else 0)
    case['expected_follow_memory']=memory;case['drain_instructions']=2
    return case


def pixel_read_cases():
    for size in SIZES:
        for offset,bank,off in product(range(0,16,size),(0,1),(False,True)):
            yield fixture(size,offset,bank,off)
        for offset,off,pmask in product(range(0,16,size),(False,True),[1<<q for q in range(16)]+[0xFFFF,0x5555,0xAAAA]):
            yield fixture(size,offset,0,off,pmask=pmask,tag=f'mask{pmask:04x}')
        for field,width,fe,off in product((0,1),range(1,33),(0,1),(False,True)):
            status=(0xF2200810&~(63<<(6*field)))|(((width&31)|(fe<<5))<<(6*field))
            yield fixture(size,16-size,0,off,status=status,tag=f'ignored_f{field}_w{width}_fe{fe}')
        for source,dest in ((0,14),(14,0),(15,0),(0,15),(3,3),(7,7),(15,15)):
            for bank,off in product((0,1),(False,True)):
                yield fixture(size,0,bank,off,source=source,destination=dest,tag=f'identity_s{source}_d{dest}')
        for flags,ie,off in product(range(16),(0,1),(False,True)):
            yield fixture(size,0,0,off,status=(flags<<28)|(ie<<21)|0x810,pmask=0xFFFF if flags&1 else 0,tag=f'flags{flags}_ie{ie}')
        for ppop,off in product(range(22),(False,True)):
            for window in range(4):
                yield fixture(size,0,0,off,control=(ppop<<10)|(window<<6)|0x20,tag=f'ignored_pp{ppop}_w{window}_t1')
        for bank,off,alignment in product((0,1),(False,True),range(4)):
            yield fixture(size,0,bank,off,alignment=alignment,tag=f'phase_{alignment}')
        for address,off in product((0,0x80000000,0xFFFFFFD0),(False,True)):
            yield fixture(size,0,0,off,address=address,tag=f'address{address:08x}')
        for word,off in product((0,0xFFFF,0x5555,0xAAAA,1,0x8000),(False,True)):
            yield fixture(size,0,0,off,source_word=word,tag=f'value{word:04x}')
        for bank,off in product((0,1),(False,True)):
            yield fixture(size,0,bank,off,code_source=True,tag='cached_source')
        for bank,unaligned in product((0,1),(False,True)):
            yield following(fixture(size,0,bank,False,source=7,destination=6,tag=f'follow_b{bank}_u{int(unaligned)}'),bank,unaligned)
        yield fixture(size,0,0,False,cold=True,tag='cold_next')
    # Numeric source/destination vectors printed literally on p12-219.
    examples=((0x20500,1,0,1),(0x20500,1,0xFFFF,0),(0x20500,2,0,3),(0x20500,2,0x5555,2),
        (0x20500,4,0,15),(0x20510,4,0x9999,2),(0x20500,8,0,255),(0x20510,8,0x5454,0x23),
        (0x20500,16,0,65535),(0x20500,16,0xBA98,0x4567),(0x20510,16,0xBA98,0x123))
    for i,(address,size,pmask,expected) in enumerate(examples):
        word=0xFFFF if address==0x20500 else 0x3333
        assert pixel_value(word,size,0,pmask)==expected
        for off in (False,True):yield fixture(size,0,0,off,address=address,source=0,destination=1,source_word=word,pmask=pmask,tag=f'literal{i}')
