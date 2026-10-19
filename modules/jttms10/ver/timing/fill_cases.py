#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Full-word replace FILL probes: SPVU001A12-80..86,13-10..14.

Nonempty, word-aligned rows; PPOP0/PMASK0/T0/W0 only. B10..14 are
reserved scratch registers marked changed by TI and have no final golden.
"""
from itertools import product
from fill_oracle import fill_timing
from pixel_boolean_cases import program as prefilled_program


def fixture(size, words, rows, xy, off):
    address, pitch, color = 0x6100, 0x100, 0x5CC3AA55
    width = words * 16 // size
    timing = fill_timing(pixel_size=size, width=width, rows=rows,
                         address=address, pitch=pitch, xy=xy, cache_disabled=off)
    seed, status = 0x13579B00, 0xF0000810
    registers = {f'a{q}': seed+q for q in range(15)}
    registers.update({f'b{q}': seed+16+q for q in range(15)})
    registers['sp'] = seed+15
    registers['a3'] = status
    overrides = dict(b2=0x10000 if xy else address, b3=pitch,
                     b7=(rows << 16) | width, b9=color)
    if xy:
        overrides['b4'] = 0x6000
    registers.update(overrides)
    expected = dict(registers, b2=address+(rows-1)*pitch+width*size)
    for q in range(10, 15):
        del expected[f'b{q}']
    memory = {}
    result = {}
    for row in range(rows):
        for word in range(-1, words+1):
            addr = address+row*pitch+16*word
            memory[addr] = (0xA596 ^ (row*0x1111) ^ ((word+1)*0x0101)) & 65535
            result[addr] = color & 65535 if word in range(words) else memory[addr]
    return dict(name=f'fill_{"xy" if xy else "l"}_ps{size}_n{words}_rows{rows}_{"off" if off else "hit"}',
        coverage_id='FILL_XY' if xy else 'FILL_L', opcode=0x0FE0 if xy else 0x0FC0,
        data_fill=dict(address=address, pitch=pitch, words=words, rows=rows, color=color & 65535),
        regs=[registers[f'a{q}'] for q in range(4)], expected_regs=[expected[f'a{q}'] for q in range(4)],
        expected_extra_regs={k:v for k,v in expected.items() if k not in ('a0','a1','a2','a3')},
        initial_all_regs=registers, register_overrides=overrides, observe_all=True,
        seed=seed, status_holder=3, source_register=7, source_value=registers['a7'], bank=0,
        control=0, setup_io=[(0xC0000150,size),(0xC0000160,0),(0xC0000140,23)],
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


def transfers(case):
    spec = case['data_fill']
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
        if kind and not raw:
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
