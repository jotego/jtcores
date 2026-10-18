#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Independent bit-addressed load fixtures: SPVU001A 13-5,12-118,12-135/136."""
from alu_cases import initial_status
from oracle import load_states
from scalar_cases import MASK32,N,Z,V


def extract(memory, address, size, signed):
    # Read individual bits; no alignment shifter or DUT masking algorithm.
    image=dict(memory)
    value=sum(((image.get((address+bit)&~15,0) >> ((address+bit)&15))&1)<<bit
              for bit in range(size))
    if signed and value&(1<<(size-1)):value-=1<<size
    return value&MASK32


def fixture(*, byte, width, offset, signed, field, off, pattern, tag, carry, base_address=0x6000):
    status=(initial_status(width+offset) & ~(1<<30)) | (carry<<30)
    shift=6*field
    status=(status & ~(63<<shift)) | (((width&31)|(int(signed)<<5))<<shift)
    address=base_address+offset
    memory=[(base_address+16*i,(pattern>>(16*i))&0xFFFF) for i in range(3)]
    alias=(width+offset)%8==0
    source=0 if alias else 2
    regs=[0xDEADBEEF,0x11223344,address,status];regs[source]=address
    expected=list(regs);value=extract(memory,address,width,signed or byte)
    expected[0]=value
    flags=(status & ~(N|Z|V)) | (value & N) | (Z if value==0 else 0)
    return dict(name=f'load_{"movb" if byte else "move"}_{tag}_{"off" if off else "hit"}',
        coverage_id='MOVB_IND_R' if byte else 'MOVE_IND_R',
        opcode=(0x8E00 if byte else 0x8400 | (field<<9))|(source<<5),
        regs=regs,expected_regs=expected,expected_st=flags,
        states=load_states(address=address,width=width,signed=signed,byte=byte,cache_disabled=off),
        cache_disabled=off,initial_memory=memory,
        data_load=dict(address=address,width=width,signed=signed,byte=byte),
        citation='SPVU001A 13-5 Table13-1; '+('12-118' if byte else '12-135/136'),
        conditions=dict(width=width,offset=offset,signed=signed,field=field,source=source,
                        destination=0,alias=alias,pattern=pattern))


def load_cases():
    patterns=(0,0xFFFFFFFFFFFF,0xE1709B6DA5C3,0xAAAAAAAAAAAA,0x555555555555)
    for off in (False,True):
        for width in range(1,33):
            for offset in range(16):
                for field in (0,1):
                    for signed in (False,True):
                        yield fixture(byte=False,width=width,offset=offset,signed=signed,field=field,off=off,
                            pattern=patterns[(width+offset)%len(patterns)],
                            tag=f'f{field}_w{width}_o{offset}_s{int(signed)}',carry=(width+offset+field)&1)
        for offset in range(16):
            for q,pattern in enumerate(patterns[:4]):
                for carry in (0,1):
                    yield fixture(byte=True,width=8,offset=offset,signed=True,field=0,off=off,
                        pattern=pattern,tag=f'o{offset}_p{q}_c{carry}',carry=carry)

    # Literal primary examples, preserving the printed source addresses/data.
    move_examples=((1,1,1,0),(0,5,0,0x10),(1,5,1,0xFFFFFFF0),
        (0,12,1,0x770),(1,12,0,0x770),(0,18,0,0x37770),
        (1,18,1,0xFFFF7770),(0,27,1,0xFF777770),(1,27,0,0x07777770),
        (0,31,0,0x77777770),(1,31,1,0xF7777770),(0,32,0,0x77777770),
        (0,32,1,0x77777770))
    byte_examples=((0,0xFFFFFFEF),(1,0x77),(8,0),(12,0xFFFFFFB0))
    for off in (False,True):
        for carry in (0,1):
            for q,(field,width,sign,value) in enumerate(move_examples):
                row=fixture(byte=False,width=width,offset=0,signed=bool(sign),field=field,off=off,
                    pattern=0x77777770,tag=f'ti{q}_c{carry}',carry=carry,base_address=0x15500)
                assert row['expected_regs'][0]==value
                row['citation']='SPVU001A 12-136 literal; 13-5 Table13-1'
                yield row
            for q,(offset,value) in enumerate(byte_examples):
                row=fixture(byte=True,width=8,offset=offset,signed=True,field=0,off=off,
                    pattern=0x89AB00EF,tag=f'ti{q}_c{carry}',carry=carry,base_address=0x5000)
                assert row['expected_regs'][0]==value
                row['citation']='SPVU001A 12-118 literal; 13-5 Table13-1'
                yield row
        for sign in (False,True):
            yield fixture(byte=False,width=32,offset=15,signed=sign,field=1,off=off,
                pattern=0xE1709B6DA5C3,tag=f'high_address_s{int(sign)}',carry=1,base_address=0x80006000)
