#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""PIXBLT full-word opaque W0/PBH0/PBV0 baseline, all six encodings.

The timing model reads no implementation. Pixels are copied bit by bit;
source reads and destination writes have independent word-level expectations.
NZCV are TI-undefined for PIXBLT; all other ST bits and defined GPRs are checked.
"""
from itertools import product
from blit_oracle import blit_timing
from pixel_boolean_cases import program as prefilled_program

MODES = dict(ll=0x0F00, lxy=0x0F20, xyl=0x0F40, xyxy=0x0F60,
             bl=0x0F80, bxy=0x0FA0)


def fixture(mode, size, words, rows, off, *, offset_geometry=False):
    timing = blit_timing(mode, size, words, rows, cache_disabled=off)
    source, destination = 0x5000, 0x6000
    source_pitch = destination_pitch = 0x100
    source_xy, destination_xy = 0x00500000, 0x00600000
    convsp = convdp = 23
    offset = 0
    if offset_geometry:
        # Nonzero X/Y and OFFSET, different SP/DP conversions and pitches.
        # Choose aligned physical words independently of implementation.
        pixels_per_word = 16 // size
        source_xy, destination_xy = (5 << 16) | (2*pixels_per_word), (9 << 16) | (3*pixels_per_word)
        convsp, convdp, offset = 23, 22, 0x4000
        source = offset + 5*(1 << (31-convsp)) + 2*pixels_per_word*size
        destination = offset + 9*(1 << (31-convdp)) + 3*pixels_per_word*size
        source_pitch, destination_pitch = 0x180, 0x140
    width = timing['width']
    binary = mode in ('bl', 'bxy')
    seed, status = 0x13579B00, 0xF0000810
    registers = {f'a{q}': seed+q for q in range(15)}
    registers.update({f'b{q}': seed+16+q for q in range(15)})
    registers.update(sp=seed+15, a3=status)
    overrides = dict(b0=source_xy if mode in ('xyl', 'xyxy') else source,
                     b1=source_pitch,
                     b2=destination_xy if mode in ('lxy', 'xyxy', 'bxy') else destination,
                     b3=destination_pitch, b4=offset, b7=(rows << 16) | width,
                     b8=0x13572468, b9=0x2468ACE1)
    registers.update(overrides)
    expected = dict(registers, b0=source+rows*source_pitch, b2=destination+rows*destination_pitch)
    for q in range(10, 15):
        del expected[f'b{q}']
    memory = {}
    for row in range(rows):
        for word in range(-1, timing['source_words_per_row']+1):
            memory[source+row*source_pitch+16*word] = (0x96A5 ^ (row*0x3179) ^ ((word+1)*0x1273)) & 65535
        for word in range(-1, words+1):
            memory[destination+row*destination_pitch+16*word] = (0xA596 ^ (row*0x1111) ^ ((word+1)*0x0101)) & 65535
    result = dict(memory)
    for row, pixel in product(range(rows), range(width)):
        at = source+row*source_pitch+pixel*(1 if binary else size)
        if binary:
            bit = (memory[at & ~15] >> (at & 15)) & 1
            # SPVU001A12-175/180: select the COLOR pixel aligned with its
            # destination lane, rather than broadcasting the lowest pixel.
            lane = (destination+row*destination_pitch+pixel*size) & 15
            value = registers['b9' if bit else 'b8'] >> lane
        else:
            value = sum(((memory[(at+bit) & ~15] >> ((at+bit) & 15)) & 1) << bit
                        for bit in range(size))
        for bit in range(size):
            target = destination+row*destination_pitch+pixel*size+bit
            mask = 1 << (target & 15)
            result[target & ~15] = (result[target & ~15] & ~mask) | (((value >> bit) & 1) * mask)
    return dict(name=f'blit_{mode}_ps{size}_n{words}_rows{rows}_{"off" if off else "hit"}'+("_offset_pitches" if offset_geometry else ""),
        coverage_id='PIXBLT_'+mode.upper(), opcode=MODES[mode],
        data_blit=dict(mode=mode, source=source, destination=destination,
                       source_pitch=source_pitch, destination_pitch=destination_pitch, rows=rows,
                       words=words, binary=binary), blit_timing=timing,
        regs=[registers[f'a{q}'] for q in range(4)],
        expected_regs=[expected[f'a{q}'] for q in range(4)],
        expected_extra_regs={k:v for k,v in expected.items() if k not in ('a0','a1','a2','a3')},
        initial_all_regs=registers, register_overrides=overrides, observe_all=True,
        seed=seed, status_holder=3, source_register=7, source_value=registers['a7'], bank=0,
        control=0, setup_io=[(0xC0000150,size),(0xC0000160,0),
                            (0xC0000130,convsp),(0xC0000140,convdp)],
        expected_st=status, expected_st_mask=0x0FFFFFFF,
        states=timing['states'], cache_disabled=off, measure_pass=0,
        initial_memory=sorted(memory.items()), expected_memory=sorted(result.items()),
        drain_instructions=-1, citation='SPVU001A12-174..212;13-18..35',
        conditions=dict(size=size,width=width,rows=rows,words_per_row=words,
                        mode=mode,ppop=0,pmask=0,transparency=False,
                        window=0,pbh=0,pbv=0,alignment='A',source_alignment=0))


def program(case, movi):
    # Reuse real ISA/I/O initialization and prefill, never an expectation.
    proxy = dict(case, data_store=dict(address=case['data_blit']['destination']))
    return prefilled_program(proxy, movi)


def transfers(case):
    spec, timing = case['data_blit'], case['blit_timing']
    before, after = dict(case['initial_memory']), dict(case['expected_memory'])
    plan = []
    for row in range(spec['rows']):
        sources = [(0, spec['source']+row*spec['source_pitch']+16*q,
                    before[spec['source']+row*spec['source_pitch']+16*q], 0)
                   for q in range(timing['source_words_per_row'])]
        writes = [(1, spec['destination']+row*spec['destination_pitch']+16*q,
                   after[spec['destination']+row*spec['destination_pitch']+16*q], 0)
                  for q in range(spec['words'])]
        if spec['binary']:
            plan.extend(sources+writes)
        else:
            for read, write in zip(sources, writes):
                plan.extend((read, write))
    return plan


def check_bus(case, observed, lines, wait_states, *, raw=False):
    """Word order/data, two-state cycles, and repeated-row coefficient.

    The table supplies a row period, not an exact first-word bus phase.
    Target readiness is checked separately; original electrical pins and
    interrupt placement are outside this initial full-word contract.
    """
    prefix = 'TARGET' if raw else 'BUS'
    begin = [line.split() for line in lines if line.startswith(prefix+'_BEGIN ')]
    end = [line.split() for line in lines if line.startswith(prefix+'_END ')]
    logical = [line.split() for line in lines if line.startswith('BUS_BEGIN ')]
    plan = transfers(case)
    if case['cache_disabled']:
        plan.append((0, case['next_pc'], 0x0300, 1))
    if len(begin) != len(plan) or len(end) != len(plan):
        return [f'PIXBLT expected {len(plan)} {prefix} transfers, observed {len(begin)} starts/{len(end)} completions']
    errors = []
    spec, timing = case['data_blit'], case['blit_timing']
    expected = {(kind,address):(data,iaq) for kind,address,data,iaq in plan}
    if len(expected) != len(plan):
        raise ValueError('PIXBLT baseline requires disjoint source/destination rows')
    actual = [(int(b[2]),int(b[3],16)) for b in begin]
    if len(set(actual)) != len(actual) or set(actual) != set(expected):
        return [f'{prefix} PIXBLT request kind/address inventory mismatch']
    # TI specifies forward source/destination traversal. Do not invent an
    # interleaving: a valid implementation may buffer multiple source words.
    for kind in (0,1):
        wanted = [key for key in expected if key[0] == kind and expected[key][1] == 0]
        seen = [key for key,b in zip(actual,begin) if key[0] == kind and int(b[5]) == 0]
        if seen != wanted:
            errors.append(f'{prefix} PIXBLT source or destination order mismatch')
    completed_reads = {}
    row_starts = {}
    for q, (key,b,e) in enumerate(zip(actual,begin,end)):
        kind,address = key
        data,iaq = expected[key]
        start, finish = int(b[1]), int(e[1])
        if not observed['start'] <= start < finish <= observed['end']:
            errors.append(f'{prefix} PIXBLT transfer outside instruction interval')
        if q and start < int(end[q-1][1]):
            errors.append(f'{prefix} PIXBLT transfers overlap or are out of order')
        if raw:
            if len(logical) != len(plan) or not int(logical[q][1]) <= start <= int(logical[q][1])+6:
                errors.append('PIXBLT target dispatch outside logical readiness window')
        elif start % 8:
            errors.append('PIXBLT logical bus start outside machine-state grid')
        if int(b[5]) != iaq:
            errors.append(f'{prefix} PIXBLT IAQ mismatch at transfer {q}')
        if kind and int(b[4],16) != data:
            errors.append(f'{prefix} PIXBLT write data mismatch at transfer {q}')
        if e[2:4] != b[2:4] or (not kind and int(e[4],16) != data):
            errors.append(f'{prefix} PIXBLT response mismatch at transfer {q}')
        duration = (4 if raw else 16)+8*wait_states
        if finish-start != duration:
            errors.append(f'{prefix} PIXBLT duration: expected {duration}, observed {finish-start}')
        if kind == 0 and not iaq:
            completed_reads[address] = finish
            for row in range(spec['rows']):
                if address == spec['source']+row*spec['source_pitch']:
                    row_starts[row] = start
        if kind:
            row = next(r for r in range(spec['rows'])
                       if spec['destination']+r*spec['destination_pitch'] <= address
                       < spec['destination']+r*spec['destination_pitch']+16*spec['words'])
            word = (address-spec['destination']-row*spec['destination_pitch'])//16
            size = case['conditions']['size']
            first = word*(16//size) if spec['binary'] else word*16
            last = first+(16//size)-1 if spec['binary'] else first+15
            required = {spec['source']+row*spec['source_pitch']+(bit//16)*16
                        for bit in range(first,last+1)}
            if any(a not in completed_reads or completed_reads[a] > start for a in required):
                errors.append(f'{prefix} PIXBLT destination written before its source was captured')
    if not raw:
        per_row = timing['source_words_per_row']+spec['words']
        period = 8*(timing['row_states']+per_row*wait_states)
        for row in range(1,spec['rows']):
            if row_starts[row]-row_starts[row-1] != period:
                errors.append('PIXBLT repeated row cadence differs from the TI table coefficient plus waits')
    return errors


def blit_cases():
    for mode,size,words,rows,off in product(MODES,(1,2,4,8,16),(1,2,3,4),(1,2),(False,True)):
        if mode in ('bl','bxy') and words*16//size > 32:
            continue
        yield fixture(mode,size,words,rows,off)

    # Append new address geometry without changing the published 464 cases.
    for mode,size,off in product(('ll','lxy','xyl','xyxy'),(1,2,4,8,16),(False,True)):
        yield fixture(mode,size,3,2,off,offset_geometry=True)

    # Binary rows exercise both source-word counts with the same independent
    # nonzero OFFSET/coordinate and unequal-pitch geometry.
    for mode,size,off in product(('bl','bxy'),(1,2,4,8,16),(False,True)):
        words = 2 if size==1 else 3 if size==2 else 4
        yield fixture(mode,size,words,2,off,offset_geometry=True)
