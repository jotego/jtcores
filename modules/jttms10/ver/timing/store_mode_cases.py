#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Extension-address stores; primary conflicts remain explicit in every row."""
from store_cases import fixture,insert
from load_cases import extract


def named(row):
    row['name']=row['name'].replace('store_','storemode_',1)
    return row


def store_mode_cases():
    pairs=((2,0),(0,0),(15,0),(0,15),(15,15),(1,2))
    for off in (False,True):
        for mode in ('offset','absolute'):
            for width in (1,5,8,16,17,31,32):
                for offset in (0,1,7,15):
                    for field in (0,1):
                        for fe in (0,1):
                            index=width*32+offset*2+2*field+fe
                            source,dest=pairs[index%len(pairs)]
                            yield named(fixture(mode,width,offset,field,off,index,fe=fe,bank=(index//6)&1,
                                source=source,dest=dest,displacement=(-32768,-1,0,1,32767)[index%5],
                                base=0x80006000 if index&1 else 0x6000))
            for offset in range(16):
                for q,ignored in enumerate((0x001,0x83F,0x445,0x230)):
                    source,dest=pairs[(offset+q)%5]
                    yield named(fixture(mode,8,offset,0,off,offset*4+q,byte=True,bank=q&1,
                        source=source,dest=dest,ignored=ignored,displacement=(-32768,-1,0,32767)[q],
                        tag=f'byte_o{offset}_ignored{ignored:03x}_r{q&1}'))
        # Extend the old store matrix with orthogonal FE checks, including F0/FE1.
        for mode in ('indirect','post','pre'):
            for width in (1,8,16,32):
                for offset in (0,15):
                    for field in (0,1):
                        yield named(fixture(mode,width,offset,field,off,width+offset,fe=1-field,
                            tag=f'fe_w{width}_o{offset}_f{field}'))
        for mode in ('indirect','post','pre','offset','absolute'):
            for bank in (0,1):
                for source,dest in ((15,0),(0,15),(15,15)):
                    yield named(fixture(mode,32,8,1,off,source+dest,bank=bank,source=source,dest=dest,
                        base=0xFFFFFFF0,displacement=32767,tag=f'wrap_r{bank}_{source}_{dest}'))
    # First-pass cold extension fills: physical RMW reads see initial memory.
    for byte in (False,True):
        for mode in ('offset','absolute'):
            for bank in (0,1):
                for width,offset in (((8,0),(8,15)) if byte else ((16,0),(5,15),(32,15))):
                    for missing in ((1,2) if mode=='absolute' else (1,)):
                        row=fixture(mode,width,offset,1,False,width+offset,byte=byte,bank=bank,
                            source=2,dest=15,displacement=-32768,ignored=0x001 if byte else None,
                            tag=f'cold{missing}_w{width}_o{offset}_r{bank}')
                        row.update(cache_miss='store_extension',miss_word=missing,instruction_word_offset=4-missing,measure_pass=0)
                        row['states']+=9
                        row['drain_instructions']=-2
                        yield named(row)
    # Dependent loads after extension-address stores, before/after write drain.
    for byte in (False,True):
        for mode in ('offset','absolute'):
            for width,offset in (((8,0),(8,15)) if byte else ((1,0),(16,0),(32,15))):
                for delay in (0,1,3,7,20):
                    row=fixture(mode,width,offset,0,False,width+offset,byte=byte,fe=0,
                                source=2,dest=0,displacement=-32768,tag=f'dependency{delay}_w{width}_o{offset}')
                    address=row['data_store']['address'];row['regs'][1]=address;row['expected_regs'][1]=address
                    row['follow_delay']=delay
                    # Byte uses MOVB to force its width regardless of ignored FS.
                    row['following_words']=[0x0300]*delay+[0x8E21 if byte else 0x8421]+[0x0300]*32
                    row['drain_instructions']=24+delay
                    value=extract(row['expected_memory'],address,width,byte)
                    regs=list(row['expected_regs']);regs[1]=value
                    row['expected_follow_regs']=regs
                    row['expected_follow_st']=(row['expected_st']&~0xB0000000)|(value&0x80000000)|(0x20000000 if value==0 else 0)
                    yield named(row)

    # Extra short-pause guards: all four extension forms and both absolute fill words.
    for byte in (False,True):
        for mode in ('offset','absolute'):
            yield named(fixture(mode,8 if byte else 16,15,1,True,1,byte=byte,bank=1,
                source=15,dest=0,displacement=-32768,tag='phase_r1'))
    for missing in (1,2):
        row=fixture('absolute',32,15,0,False,0,source=2,tag=f'phase_cold{missing}')
        row.update(cache_miss='store_extension',miss_word=missing,instruction_word_offset=4-missing,
                   measure_pass=0,drain_instructions=-2,states=row['states']+9)
        yield named(row)

    yield from literal_cases()
    # Resident operands can straddle a four-word subsegment or a complete
    # 32-word cache segment. Table13-2's cached byte count is unchanged.
    for bank in (0,1):
        for source in (0,1,2,15):
            for position in (0,1,2,3,30,31):
                for offset in (0,1,8,9):
                    row=fixture('absolute',8,offset,0,False,position+offset,byte=True,
                        bank=bank,source=source,base=0x80006000 if bank else 0x6000,
                        tag=f'packet_r{bank}_s{source}_pc{position}_o{offset}')
                    row.update(instruction_alignment_words=32,instruction_word_offset=position)
                    yield named(row)


# TI p12-133: width, F, pointer, signed offset, three printed output words.
TI_OFFSET=(
 (1,1,0x15530,0,(0x0001,0,0)),(5,0,0x1552F,1,(0x001F,0,0)),
 (8,0,0x1552D,15,(0xF000,0x000F,0)),(13,1,0x1551C,32,(0xF000,0x01FF,0)),
 (16,0,0x15435,255,(0xFFF0,0x000F,0)),(19,0,0x14531,4095,(0xFFFF,0x0007,0)),
 (22,1,0xD531,32767,(0xFFFF,0x003F,0)),(25,1,0x15540,-14,(0xFFFC,0x07FF,0)),
 (27,0,0x1D530,-32768,(0xFFFF,0x07FF,0)),(31,0,0x15540,-16,(0xFFFF,0x7FFF,0)),
 (31,1,0x15548,-20,(0xFFF0,0xFFFF,0x0007)),(32,0,0x1554D,-20,(0xFE00,0xFFFF,0x01FF)),
 (32,0,0x15520,29,(0xE000,0xFFFF,0x1FFF)),(32,1,0x15520,32,(0,0xFFFF,0xFFFF)))
# TI p12-134: width, F, address, three printed output words.
TI_ABSOLUTE=(
 (5,0,0x15500,(0x001F,0,0)),(8,1,0x15503,(0x07F8,0,0)),
 (13,0,0x15508,(0xFF00,0x001F,0)),(16,1,0x1550B,(0xF800,0x07FF,0)),
 (19,0,0x1550D,(0xE000,0xFFFF,0)),(24,1,0x15510,(0,0xFFFF,0x00FF)),
 (27,0,0x15512,(0,0xFFFC,0x1FFF)),(32,1,0x1550C,(0xF000,0xFFFF,0x0FFF)))
TI_BYTE_WORDS=((0x00EF,0,0),(0x01DE,0,0),(0xDE00,1,0),(0xF000,0x000E,0))


def literal_cases():
    for off in (False,True):
        for mode,vectors in (('offset',TI_OFFSET),('absolute',TI_ABSOLUTE)):
            for q,vector in enumerate(vectors):
                if mode=='offset':width,field,pointer,disp,words=vector;address=(pointer+disp)&0xFFFFFFFF
                else:width,field,address,words=vector;disp=0
                for fe in (0,1):
                    row=fixture(mode,width,address&15,field,off,q,fe=fe,source=0,dest=1,
                        base=address&~15,displacement=disp,tag=f'ti{q}_fe{fe}')
                    memory_base=0x15530 if mode=='offset' else 0x15500
                    row['initial_memory']=[(memory_base+16*i,0) for i in range(3)]
                    row['regs'][0]=row['expected_regs'][0]=0xFFFFFFFF
                    row['data_store']['value']=0xFFFFFFFF
                    row['expected_memory']=[(memory_base+16*i,value) for i,value in enumerate(words)]
                    row['literal_model_memory']=insert(row['initial_memory'],address,width,0xFFFFFFFF)
                    row['literal_citation']='SPVU001A '+('12-133' if mode=='offset' else '12-134')
                    yield named(row)
        for mode in ('offset','absolute'):
            vectors=[(0x10000+o,o) for o in (0,1,9,12)]+[(0x10000,32767),(0x10000,-32768)] if mode=='offset' else [(0x5000+o,0) for o in (0,1,9,12)]
            for q,(address,disp) in enumerate(vectors):
                row=fixture(mode,8,address&15,0,off,q,byte=True,source=0,dest=1,ignored=0x001,
                    base=address&~15,displacement=disp,tag=f'ti_byte{q}')
                memory_base=0x10000 if mode=='offset' else 0x5000
                row['initial_memory']=[(memory_base+16*i,0) for i in range(3)]
                row['regs'][0]=row['expected_regs'][0]=0x89ABCDEF
                row['data_store']['value']=0x89ABCDEF
                words=TI_BYTE_WORDS[q if q<4 else 0]
                row['expected_memory']=[(memory_base+16*i,value) for i,value in enumerate(words)]
                row['literal_model_memory']=insert(row['initial_memory'],address,8,0x89ABCDEF)
                row['literal_citation']='SPVU001A '+('12-116' if mode=='offset' else '12-117')
                yield named(row)
