#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""FILL probes: SPVU001A12-80..86,13-10..14.

Nonempty rows; PMASK0/T0/W0 only. Partial rows keep word-aligned pitch. B10..14 are
reserved scratch registers marked changed by TI and have no final golden.
"""
from itertools import product
from fill_oracle import fill_timing
from pixel_boolean_cases import boolean, program as prefilled_program


def fixture(size, words, rows, xy, off, *, point=0x10000, offset=0x6000,
            convdp=23, pitch=0x100):
    address, color = 0x6100, 0x5CC3AA55
    if xy:
        # SPVU001A4-12,6-15: signed Y, nonnegative X; OR before OFFSET.
        if point & 0x8000:
            raise ValueError('negative X is outside the defined conversion domain')
        y = point >> 16
        y -= 0x10000 if y & 0x8000 else 0
        address = ((((y * (1 << (31-(convdp & 31)))) & 0xFFFFFFFF)
                    | ((point & 65535) * size)) + offset) & 0xFFFFFFFF
    width = words * 16 // size
    timing = fill_timing(pixel_size=size, width=width, rows=rows,
                         address=address, pitch=pitch, xy=xy, cache_disabled=off)
    seed, status = 0x13579B00, 0xF0000810
    registers = {f'a{q}': seed+q for q in range(15)}
    registers.update({f'b{q}': seed+16+q for q in range(15)})
    registers['sp'] = seed+15
    registers['a3'] = status
    overrides = dict(b2=point if xy else address, b3=pitch,
                     b7=(rows << 16) | width, b9=color)
    if xy:
        overrides['b4'] = offset
    registers.update(overrides)
    expected = dict(registers, b2=address+(rows-1)*pitch+width*size)
    for q in range(10, 15):
        del expected[f'b{q}']
    memory = {}
    for row in range(rows):
        for word in range(-1, words+1):
            addr = address+row*pitch+16*word
            memory[addr] = (0xA596 ^ (row*0x1111) ^ ((word+1)*0x0101)) & 65535
    result = memory.copy()
    for row in range(rows):
        for word in range(words):
            result[address+row*pitch+16*word] = color & 65535
    return dict(name=f'fill_{"xy" if xy else "l"}_ps{size}_n{words}_rows{rows}_{"off" if off else "hit"}',
        coverage_id='FILL_XY' if xy else 'FILL_L', opcode=0x0FE0 if xy else 0x0FC0,
        data_fill=dict(address=address, pitch=pitch, words=words, rows=rows, color=color & 65535),
        regs=[registers[f'a{q}'] for q in range(4)], expected_regs=[expected[f'a{q}'] for q in range(4)],
        expected_extra_regs={k:v for k,v in expected.items() if k not in ('a0','a1','a2','a3')},
        initial_all_regs=registers, register_overrides=overrides, observe_all=True,
        seed=seed, status_holder=3, source_register=7, source_value=registers['a7'], bank=0,
        control=0, setup_io=[(0xC0000150,size),(0xC0000160,0),(0xC0000140,convdp)],
        expected_st=status, states=timing['states'], cache_disabled=off, measure_pass=0,
        initial_memory=sorted(memory.items()), expected_memory=sorted(result.items()), drain_instructions=-1,
        citation='SPVU001A12-80..86;13-10..14 Tables13-5/6/7',
        conditions=dict(size=size,width=width,rows=rows,words_per_row=words,xy=xy,
                        ppop=0,pmask=0,transparency=False,window=0,alignment='A'),
        fill_timing=timing)


def program(case, movi):
    # Reuse cache warming and real register/I/O initialization, not expectations.
    proxy = dict(case, data_store=dict(address=case['data_fill']['address']))
    if case.get('transparent_history'):
        # Exercise the prior graphics instruction through the public ISA and
        # real CONTROL writes. The initializer then restores every GPR/ST.
        control = 0x8018 if case['cache_disabled'] else 0x18
        proxy['setup_words'] = (movi(0xC00000B0,14)+movi(control|0x20,13)+[0x0550,0x81AE]
            +movi(0,0)+movi(0x6500,1)+[0xF801]
            +movi(0xC00000B0,14)+movi(control,13)+[0x0550,0x81AE])
    return prefilled_program(proxy, movi)


def partial_fixture(size, words, alignment, xy, off, *, rows=1):
    """Constant-alignment B/C/D rows using TI's word-oriented RMW contract.

    COLOR1 supplies a 16-bit pattern (12-80), indexed by destination lane.
    Section13.3.2.3 requires one write/RMW for the single-word case;
    13.3.2.4 requires increasing word order. No partial-edge phase is assumed.
    """
    if size not in (1,2,4,8) or words not in (1,2,3) or alignment not in 'BCD':
        raise ValueError('partial FILL requires PS1/2/4/8, N1/2/3 and B/C/D')
    lane = 0 if alignment=='B' else size
    end_lane = 0 if alignment=='C' else size
    width = (words*16-lane-end_lane)//size
    if width<=0:
        raise ValueError('partial FILL requires a nonempty pixel span')
    case=fixture(size,words,rows,xy,off)
    address=case['data_fill']['address']+lane
    row_suffix=f'_rows{rows}' if rows!=1 else ''
    case['name']=f'fill_partial_{"xy" if xy else "l"}_ps{size}_n{words}_{alignment}{row_suffix}_{"off" if off else "hit"}'
    case['data_fill'].update(address=address,partial=True,width=width)
    case['initial_all_regs']['b7']=case['register_overrides']['b7']=(rows<<16)|width
    if xy:
        case['initial_all_regs']['b4']+=lane
        case['register_overrides']['b4']+=lane
        case['expected_extra_regs']['b4']+=lane
    else:
        case['initial_all_regs']['b2']=case['register_overrides']['b2']=address
    pitch=case['data_fill']['pitch']
    case['expected_extra_regs'].update(b2=address+(rows-1)*pitch+width*size,b7=(rows<<16)|width)
    case['conditions'].update(width=width,alignment=alignment,lane=lane)
    timing=fill_timing(pixel_size=size,width=width,rows=rows,address=address,
                       pitch=pitch,xy=xy,cache_disabled=off)
    case.update(states=timing['states'],fill_timing=timing)
    # Preserve every bit outside the rectangle, including both canary words.
    # Enumerate destination bits independently of the timing decomposition.
    memory=dict(case['initial_memory'])
    color=case['data_fill']['color']
    for row in range(rows):
        start=address+row*pitch
        for word in range(start & ~15,(start+width*size+15) & ~15,16):
            memory[word]=color ^ 65535
    case['initial_memory']=sorted(memory.items())
    for row in range(rows):
        start=address+row*pitch
        for bit in range(start,start+width*size):
            word=bit & ~15
            mask=1<<(bit & 15)
            memory[word]=(memory[word] & ~mask) | (color & mask)
    case['expected_memory']=sorted(memory.items())
    return case


def boolean_fixture(size, ppop, xy, off, *, words=1, rows=1):
    """Complete destination words, Table7-1 and Table13-6 A/G4.

    Section13.3.2.3 requires one word RMW, irrespective of pixel size;
    13.3.2.5 assigns G4 to each non-replace Boolean. No measured RTL
    duration or pixel-at-a-time traffic supplies these expectations.
    """
    if ppop not in range(1,16):
        raise ValueError('non-replace Boolean PPOP required')
    case=fixture(size,words,rows,xy,off)
    case['name']=f'fill_boolean_pp{ppop}_{"xy" if xy else "l"}_ps{size}_n{words}_rows{rows}_{"off" if off else "hit"}'
    case['control']=ppop<<10
    case['conditions']['ppop']=ppop
    case['data_fill'].update(processing=True,ppop=ppop)
    timing=fill_timing(pixel_size=size,width=case['conditions']['width'],rows=rows,
        address=case['data_fill']['address'],pitch=case['data_fill']['pitch'],
        xy=xy,ppop=ppop,cache_disabled=off)
    case.update(states=timing['states'],fill_timing=timing)
    before=dict(case['initial_memory'])
    address=case['data_fill']['address']
    for row in range(rows):
        for word in range(words):
            dest=address+row*case['data_fill']['pitch']+16*word
            before[dest]=boolean(ppop,case['data_fill']['color'],before[dest],16)
    case['expected_memory']=sorted(before.items())
    case['citation']='SPVU001A7-15 Table7-1;12-80..86;13-10..14 Tables13-5/6/7'
    return case


def transfers(case):
    spec = case['data_fill']
    if spec.get('processing'):
        # One physical-word read and write, not repeated pixel RMWs.
        before,after=map(dict,(case['initial_memory'],case['expected_memory']))
        plan=[]
        for row in range(spec['rows']):
            for word in range(spec['words']):
                address=spec['address']+row*spec['pitch']+16*word
                plan.extend([(0,address,before[address],0),(1,address,after[address],0)])
        return plan
    if spec.get('partial'):
        before,after=map(dict,(case['initial_memory'],case['expected_memory']))
        plan=[]
        for row in range(spec['rows']):
            start=spec['address']+row*spec['pitch']
            stop=start+spec['width']*case['conditions']['size']
            for word in range(start & ~15,(stop+15) & ~15,16):
                if max(start,word)!=word or min(stop,word+16)!=word+16:
                    plan.append((0,word,before[word],0))
                plan.append((1,word,after[word],0))
        return plan
    return [(1, spec['address']+row*spec['pitch']+16*word, spec['color'], 0)
            for row in range(spec['rows']) for word in range(spec['words'])]


def check_bus(case, observed, lines, wait_states, *, raw=False):
    """Word order, payload, interval and transport; no invented first-slot timing.

    Table13-6 implies word transfers, while §11 defines bus durations.
    The repeated row cadence uses Table13-6's linear row coefficient;
    within-row replacement words use G=2. This is an explicit schedule
    constraint, not a claim about TI's undocumented first-write phase.
    Exact IRQ checkpoint placement still needs a separate source audit.
    """
    prefix = 'TARGET' if raw else 'BUS'
    begin = [x.split() for x in lines if x.startswith(prefix+'_BEGIN ')]
    end = [x.split() for x in lines if x.startswith(prefix+'_END ')]
    plan = transfers(case)
    if case['cache_disabled']:
        plan += [(0, case['next_pc'], 0x0300, 1)]
    if len(begin)!=len(plan) or len(end)!=len(plan):
        return [f'FILL expected {len(plan)} {prefix} transfers, observed {len(begin)} starts/{len(end)} completions']
    logical = [x.split() for x in lines if x.startswith('BUS_BEGIN ')]
    errors = []
    for q, ((kind,addr,data,iaq),b,e) in enumerate(zip(plan,begin,end)):
        start, finish = int(b[1]), int(e[1])
        if not observed['start'] <= start < finish <= observed['end']:
            errors.append(f'{prefix} FILL transfer outside instruction interval')
        if q and start < int(end[q-1][1]):
            errors.append(f'{prefix} FILL transfers overlap or are out of order')
        if raw:
            if len(logical)!=len(plan) or not int(logical[q][1]) <= start <= int(logical[q][1])+6:
                errors.append('FILL target dispatch outside logical readiness window')
        elif start % 8:
            errors.append('FILL logical bus start outside machine-state grid')
        if (int(b[2]),int(b[3],16),int(b[5])) != (kind,addr,iaq):
            errors.append(f'{prefix} FILL request kind/address/IAQ mismatch at transfer {q}')
        if kind and int(b[4],16)!=data:
            errors.append(f'{prefix} FILL write data mismatch at transfer {q}')
        if e[2:4]!=b[2:4] or (not kind and int(e[4],16)!=data):
            errors.append(f'{prefix} FILL response mismatch at transfer {q}')
        if kind and not raw and not case['data_fill'].get('partial') and not case['data_fill'].get('processing'):
            words,rows = case['data_fill']['words'],case['data_fill']['rows']
            if q % words:
                if start-int(begin[q-1][1]) != 16+8*wait_states:
                    errors.append('FILL replacement word cadence differs from G=2 plus external waits')
            elif q:
                row_states = (case['fill_timing']['transfer_states']-2)//rows
                if start-int(begin[q-words][1]) != 8*(row_states+words*wait_states):
                    errors.append('FILL repeated row cadence differs from Table13-6 coefficient plus external waits')
        duration = (4 if raw else 16)+8*wait_states
        if finish-start != duration:
            errors.append(f'{prefix} FILL duration: expected {duration}, observed {finish-start}')
    return errors


def fill_cases():
    for size, words, rows, xy, off in product((1,2,4,8,16),(1,2,3),(1,2),(False,True),(False,True)):
        yield fixture(size, words, rows, xy, off)
    # Longer linear transfers exercise the per-row equations beyond the
    # original one/two/three-word, one/two-row failing baseline. Keep those
    # original120 contracts and their ordering unchanged.
    for size,words,rows,off in product((1,2,4,8,16),(1,2,3,4,8),(1,2,3,4),(False,True)):
        if words<=3 and rows<=2:
            continue
        yield fixture(size,words,rows,False,off)
    # A transparent zero PIXT must not suppress a following opaque FILL.
    # Preserve all earlier fixtures; these histories run before warm-up.
    for size,words,rows,off in product((1,2,4,8,16),(1,2,3),(1,3),(False,True)):
        case = fixture(size,words,rows,False,off)
        case.update(name=case['name']+'_transparent_history',transparent_history=True)
        case['initial_memory'].append((0x6500,0xBEEF))
        case['expected_memory'].append((0x6500,0xBEEF))
        yield case
    for size,words,rows,off in product((1,2,4,8,16),(1,2,3,4,8),(1,2,3,4),(False,True)):
        if words<=3 and rows<=2:
            continue
        yield fixture(size,words,rows,True,off)
    for size,words,rows,off in product((1,2,4,8,16),(1,2,3),(1,3),(False,True)):
        case = fixture(size,words,rows,True,off)
        case.update(name=case['name']+'_transparent_history',transparent_history=True)
        case['initial_memory'].append((0x6500,0xBEEF))
        case['expected_memory'].append((0x6500,0xBEEF))
        yield case
    for size,conv,q,off in product((1,2,4,8,16),range(32),range(5),(False,True)):
        x,y = ((0,0),(1,1),(31,-1),(48,32767),(32767,-32768))[q]
        # Keep the physical array in a safe data island while varying every
        # conversion encoding, signed-Y boundary, X and OFFSET. The expected
        # physical island is fixed independently of the conversion above.
        raw = (((y * (1 << (31-conv))) & 0xFFFFFFFF) | (x*size))
        offset = (0x6100-raw) & 0xFFFFFFFF
        case = fixture(size,1+q%3,1,True,off,point=((y&65535)<<16)|x,
                       offset=offset,convdp=conv|(0xFFE0 if q&1 else 0),pitch=1<<(31-conv))
        case['name'] += f'_convert_c{conv}_p{q}'
        case['conditions'].update(point=((y&65535)<<16)|x,offset=offset,convdp=conv)
        assert case['data_fill']['address']==0x6100
        yield case

    for size,conv,words,rows,off in product((1,2,4,8,16),(16,23,27),(1,3),(2,4),(False,True)):
        x,y = 31,-1
        raw = (((y * (1 << (31-conv))) & 0xFFFFFFFF) | (x*size))
        offset = (0x6100-raw) & 0xFFFFFFFF
        case = fixture(size,words,rows,True,off,point=0xFFFF001F,offset=offset,
                       convdp=conv,pitch=1<<(31-conv))
        case['name'] += f'_pitch_c{conv}'
        case['conditions'].update(point=0xFFFF001F,offset=offset,convdp=conv)
        assert case['data_fill']['address']==0x6100
        yield case

    # Preserve every preceding aligned fixture/program contract. Partial
    # edges add a permanent failing baseline for the unaudited native path.
    for size,words,alignment,xy,off in product((1,2,4,8),(1,2,3),'BCD',(False,True),(False,True)):
        if (size,words,alignment)==(8,1,'D'):
            continue  # No nonempty PS8 span can have both edges inside one word.
        yield partial_fixture(size,words,alignment,xy,off)

    # Append multirow contracts without changing preceding fixture/program order.
    for rows,size,words,alignment,xy,off in product((2,4),(1,2,4,8),(1,2,3),'BCD',(False,True),(False,True)):
        if (size,words,alignment)==(8,1,'D'):
            continue
        yield partial_fixture(size,words,alignment,xy,off,rows=rows)

    # Append independent non-replace Boolean coverage. Keep the preceding
    # 2,660 fixture/program contracts unchanged, including their order.
    for ppop,size,xy,off in product(range(1,16),(1,2,4,8,16),(False,True),(False,True)):
        yield boolean_fixture(size,ppop,xy,off)

    # Preserve the original 2,960 contracts and append the Table13-6 N2,
    # N>=3 and repeated-row boundaries for every Boolean operation/size.
    for (words,rows),ppop,size,xy,off in product(((2,1),(3,1),(1,2),(2,2),(3,3)),
            range(1,16),(1,2,4,8,16),(False,True),(False,True)):
        yield boolean_fixture(size,ppop,xy,off,words=words,rows=rows)
