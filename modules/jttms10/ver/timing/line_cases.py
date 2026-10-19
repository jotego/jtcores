#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Independent LINE geometry/data and timing probes, TI SPVU001A12-99..104.

Initial CPU probes use replace/PMASK0/T0 with W0/W2/W3. W1 and ambiguous
SUB/SUBS processing retain their unresolved source status in line_oracle.
The physical word target uses partial-word RMW and whole-word writes
(the existing Fig13-1 field contract). Its exact first-access phase and original LAD-pin schedule are not specified by these fixtures.
"""
from itertools import product
from line_oracle import line_timing

MASK32 = 0xFFFFFFFF


def signed(value, bits):
    value &= (1 << bits)-1
    return value-(1 << bits) if value & (1 << (bits-1)) else value


def xy(x, y):
    return ((y & 65535) << 16) | (x & 65535)


def fixture(size, count, z, off, *, a=None, b=0, d=None, point=(16,16),
            diagonal=(1,1), major=(1,0), convdp=20, offset=0x6000,
            window=0, wstart=(0,0), wend=(32767,32767),
            color=None, status=0xF0000810, tag='base'):
    if size not in (1,2,4,8,16) or z not in (0,1) or window not in (0,2,3):
        raise ValueError('supported LINE fixture domain')
    if type(count) is not int or not 0 <= count <= 32:
        raise ValueError('bounded fixture count must be in0..32')
    if window and not count:
        raise ValueError('empty window-mode flag effects are not audited')
    a = max(0,count-1) if a is None else a
    d = 2*b-a if d is None else d
    if not 0 <= b <= a <= 65535:
        raise ValueError('LINE dimensions require a>=b>=0')
    color = ((1 << size)-1) if color is None else color
    if not 0 <= color < 1 << size:
        raise ValueError('pixel color does not fit size')
    color_word = sum(color << q for q in range(0,32,size))
    initial_point, initial_d = xy(*point), d & MASK32
    current, decision, left = initial_point, initial_d, count
    pixels, outside, violation, v = [], 0, False, bool(status & 0x10000000)
    for _ in range(count):
        x,y = signed(current,16), signed(current >> 16,16)
        if x < 0:
            raise ValueError('negative X conversion is outside the defined domain')
        inside = wstart[0] <= x <= wend[0] and wstart[1] <= y <= wend[1]
        draw = window == 0 or inside
        address = (((y*(1 << (31-(convdp & 31)))) & MASK32) | (x*size)) + offset
        pixels.append((address & MASK32, draw))
        outside += not draw
        if window:
            v = not inside
        violation = window == 2 and not inside
        left -= 1
        take_diagonal = signed(decision,32) >= 0 if z else signed(decision,32) > 0
        decision = (decision+2*b-(2*a if take_diagonal else 0)) & MASK32
        dx,dy = diagonal if take_diagonal else major
        current = xy(x+dx,y+dy)
        if violation:
            break
    timing = line_timing(drawn=len(pixels)-outside, outside=outside, window=window,
                         violation=violation, pixel_size=size, cache_disabled=off)
    seed = 0x13579B00
    registers = {f'a{q}':seed+q for q in range(15)}
    registers.update({f'b{q}':seed+16+q for q in range(15)})
    registers.update(sp=seed+15, a3=status)
    overrides = dict(b0=initial_d,b2=initial_point,b3=1 << (31-(convdp & 31)),
                     b4=offset,b5=xy(*wstart),b6=xy(*wend),b7=xy(a,b),
                     b9=color_word,b10=count,b11=xy(*diagonal),b12=xy(*major),b13=MASK32)
    registers.update(overrides)
    expected = dict(registers,b0=decision,b2=current,b10=left)
    del expected['b13'],expected['b14']  # PATTRN/TEMP have no defined final golden.
    memory = {}
    for address,_ in pixels or [(offset,False)]:
        for word in ((address & ~15)-16,address & ~15,(address & ~15)+16):
            word &= MASK32
            memory.setdefault(word,(0xA596 ^ (word >> 4)*0x1235) & 65535)
    if len(memory) > 64:
        raise ValueError('fixture exceeds bounded target memory')
    result,plan = memory.copy(),[]
    for address,draw in pixels:
        if not draw:
            continue
        word,lane = address & ~15,address & 15
        old = result[word]
        # Existing word-target contract: read only to preserve untouched bits.
        # Fig13-1 applies the same distinction in store_cases.transactions.
        if size != 16:
            plan.append((0,word,old,0))
        value = old
        for bit in range(size):
            mask = 1 << (lane+bit)
            value = (value & ~mask) | (((color >> bit) & 1) << (lane+bit))
        result[word] = value
        plan.append((1,word,value,0))
    return dict(name=f'line_ps{size}_z{z}_n{count}_w{window}_{tag}_{"off" if off else "hit"}',
        coverage_id='LINE',opcode=0xDF1A | (z << 7),states=timing['states'],line_timing=timing,
        regs=[registers[f'a{q}'] for q in range(4)],expected_regs=[expected[f'a{q}'] for q in range(4)],
        expected_extra_regs={k:v for k,v in expected.items() if k not in ('a0','a1','a2','a3')},
        expected_st=(status & ~0x10000000) | (int(v) << 28),expected_st_mask=0x1FFFFFFF,
        expected_wvp=int(violation),observe_all=True,initial_all_regs=registers,
        seed=seed,status_holder=3,source_register=7,source_value=registers['a7'],bank=0,
        register_overrides=overrides,cache_disabled=off,measure_pass=0,
        control=window << 6,setup_io=[(0xC0000140,convdp),(0xC0000150,size),(0xC0000160,0)],
        initial_memory=sorted(memory.items()),expected_memory=sorted(result.items()),drain_instructions=-1,
        data_line=dict(pixels=pixels,transfers=plan),
        citation='SPVU001A12-99..104 Tables12-10/11;5-24;13-2',
        conditions=dict(size=size,count=count,z=z,a=a,b=b,d=initial_d,point=initial_point,
                        diagonal=diagonal,major=major,window=window,wstart=wstart,wend=wend,
                        convdp=convdp,offset=offset,color=color_word,ppop=0,pmask=0,transparency=False,
                        bus_policy='Fig13-1 partial-word RMW/whole-word writes; first-access/pin phase not claimed'))


def program(case, movi):
    # Public ISA initialization and a skipped-to tail prefill the measured
    # opcode. The initial B-file context is never consumed by a warm-up LINE.
    words = movi(0xC00000B0,14)+movi((0x8018 if case['cache_disabled'] else 0x18)|case['control'],13)+[0x0550,0x81AE]
    for address,value in case['setup_io']:
        words += movi(address,14)+movi(value,13)+[0x0550,0x81AE]
    for name,value in case['initial_all_regs'].items():
        reg = 15 if name == 'sp' else int(name[1:])+(16 if name.startswith('b') else 0)
        words += movi(value,reg)
    words += [0x01A0 | case['status_holder']]+[0x0300]*12
    while len(words)%4:
        words.append(0x0300)
    jump = len(words)
    words += [0xC080,0,0,0x0300]
    start = 0x1000+16*len(words)
    words += [case['opcode']]
    following = start+16
    words[jump+1:jump+3] = [following & 65535,following >> 16]
    words += [0x0300]*16+[0x01A0 | case['status_holder'],0xC080,(start-16) & 65535,(start-16) >> 16]
    return words,start,following


def transfers(case):
    return list(case['data_line']['transfers'])


def check_bus(case, observed, lines, wait_states, *, raw=False):
    prefix = 'TARGET' if raw else 'BUS'
    begins = [x.split() for x in lines if x.startswith(prefix+'_BEGIN ')]
    ends = [x.split() for x in lines if x.startswith(prefix+'_END ')]
    plan = transfers(case)
    if case['cache_disabled']:
        plan += [(0,case['next_pc'],0x0300,1)]
    if len(begins) != len(plan) or len(ends) != len(plan):
        return [f'LINE word-target contract expected {len(plan)} {prefix} transfers, observed {len(begins)} starts/{len(ends)} completions']
    logical = [x.split() for x in lines if x.startswith('BUS_BEGIN ')]
    errors = []
    for i,((we,addr,data,iaq),begin,end) in enumerate(zip(plan,begins,ends)):
        start,finish = int(begin[1]),int(end[1])
        if not observed['start'] <= start < finish <= observed['end']:
            errors.append('LINE transfer outside measured interval')
        if i and start < int(ends[i-1][1]):
            errors.append('LINE transfers overlap or reorder')
        if (int(begin[2]),int(begin[3],16),int(begin[5])) != (we,addr,iaq):
            errors.append(f'LINE request kind/address/IAQ mismatch at transfer{i}')
        if end[2:4] != begin[2:4] or int((begin if we else end)[4],16) != data:
            errors.append(f'LINE word payload/response mismatch at transfer{i}')
        if finish-start != (4 if raw else 16)+8*wait_states:
            errors.append('LINE transport duration mismatch')
        if not raw and start % 8:
            errors.append('LINE request outside machine-state grid')
        if raw and (len(logical) != len(plan) or not int(logical[i][1]) <= start <= int(logical[i][1])+6):
            errors.append('LINE target dispatch outside logical readiness window')
    return errors


def line_cases():
    for size,count,z,off in product((1,2,4,8,16),(0,1,2,3,7,16,23,32),(0,1),(False,True)):
        yield fixture(size,count,z,off)
    for size,z,off,vertical,sx,sy in product((1,2,4,8,16),(0,1),(False,True),(False,True),(-1,1),(-1,1)):
        yield fixture(size,8,z,off,a=7,b=3,diagonal=(sx,sy),major=(0,sy) if vertical else (sx,0),
                      tag=f'octant_v{int(vertical)}_x{sx}_y{sy}')
    for size,z,off,d in product((1,2,4,8,16),(0,1),(False,True),(-1,0,1)):
        yield fixture(size,1,z,off,a=2,b=1,d=d,tag=f'tie_d{d}')
    for size,z,off,q in product((1,2,4,8,16),(0,1),(False,True),range(3)):
        color=(0,(1 << size)-1,5 & ((1 << size)-1))[q]
        yield fixture(size,3,z,off,color=color,tag=f'color{q}')
    for flags,z,off in product(range(16),(0,1),(False,True)):
        yield fixture(4,3,z,off,status=(flags << 28)|0x810,tag=f'flags{flags}')
    for size,z,off in product((1,2,4,8,16),(0,1),(False,True)):
        for window,lo,hi,tag in (
            (2,(16,16),(31,17),'fits'),(2,(16,16),(17,16),'abort'),
            (2,(20,20),(21,21),'first_outside'),(3,(17,16),(19,16),'mixed'),
            (3,(20,20),(21,21),'miss'),(3,(16,16),(31,17),'fits')):
            yield fixture(size,5,z,off,a=4,b=1,window=window,wstart=lo,wend=hi,tag=tag)
    for off in (False,True):
        # Figure12-11 literal setup: hex coordinates/CONVDP, decimal23 pixels.
        yield fixture(4,23,0,off,a=22,b=3,d=-16,point=(3,0x52),offset=0x100,
                      window=3,wstart=(3,0x30),wend=(0x25,0x55),color=4,tag='guide_119')
