# SPDX-License-Identifier: GPL-3.0-or-later
"""Independent scalar interrupt expectations (SPVU001A 8-2..8, 12-230/231).

Entry saves PC then ST, MSW first. RETI restores both and SP. A warm handler
isolates the printed aligned context-switch latency from cache-fill cost.
No expected value comes from the RTL, microcode, or another backend's trace.
"""

PREFIXES = ('BUS_BEGIN', 'BUS_ACCEPT', 'BUS_END', 'TARGET_BEGIN', 'TARGET_END')


def validate(entry):
    contract = entry['external_contract']
    if not isinstance(contract, dict):
        raise ValueError('unsupported independent scalar IRQ contract')
    phase = contract.get('kind') == 'scalar_irq_phase'
    keys = {'kind', 'lint', 'handler_warm'} | ({'assert_clock'} if phase else set())
    if (set(contract) != keys or contract['kind'] not in ('scalar_irq', 'scalar_irq_phase') or
            type(contract['lint']) is not int or
            contract['lint'] not in (1, 2) or type(contract['handler_warm']) is not bool):
        raise ValueError('unsupported independent scalar IRQ contract')
    lint, warm = contract['lint'], contract['handler_warm']
    assertion = contract.get('assert_clock', 16)
    if phase and (not warm or type(assertion) is not int or not 16 <= assertion <= 23):
        raise ValueError('scalar IRQ phase contract requires a warm handler and assertion clock16..23')
    wanted = [dict(trigger=0, argument=assertion, control=1 << (lint-1)),
              dict(trigger=1, argument=4, control=0)]
    if entry.get('external_events') != wanted:
        raise ValueError('scalar IRQ stimulus differs from its independent contract')
    stimulus = entry.get('stimulus', {})
    if stimulus.get('pause_clocks', 0) or stimulus.get('pause_after_clocks', 0):
        raise ValueError('scalar IRQ contract does not support CEN pauses')
    c = entry['fixture']
    expected = dict(opcode=0x0300, states=1, cache_disabled=False, initial_sp=0x3000,
        regs=[0x80000003, 0x11223344, 2, 0xd0200810],
        expected_regs=[0x80000003, 0x11223344, 2, 0xd0200810], expected_st=0xd0200810,
        expected_extra_regs=dict(sp=0x3000), observe_implicit=True, drain_instructions=12,
        following_words=[0x1022]*12)
    if any(c.get(k) != v for k, v in expected.items()):
        raise ValueError('scalar IRQ fixture differs from its independent initialization')
    if c.get('measure_pass', 1) != 1 or c.get('setup_io') not in (
            [(0xc0000110, 1 << lint)], [[0xc0000110, 1 << lint]]):
        raise ValueError('scalar IRQ requires a warmed measured NOP and only INTENB setup')
    if (c['test_pc'] != entry['test_pc'] or c['next_pc'] != entry['next_pc'] or
            c['next_pc'] != c['test_pc']+16 or
            c['follow_pc'] != (0x4000 if warm else c['next_pc']+16*7)):
        raise ValueError('scalar IRQ measurement/following PC association differs')
    vector = 0xffffffc0 if lint == 1 else 0xffffffa0
    memory = {a: 0 for a in range(0x2fc0, 0x3000, 16)}
    memory.update({vector: 0x4000, vector+16: 0})
    if warm:
        memory.update({0x2fc0: 0x10, 0x2fe0: 0x1070})
    if len(c.get('initial_memory', [])) != 6 or dict(c['initial_memory']) != memory:
        raise ValueError('scalar IRQ initial stack/vector differs')
    words = entry['program_words']
    offset = (c['next_pc']-0x1000)//16
    if (words[offset:offset+12] != [0x1022]*12 or
            words[(0x4000-0x1000)//16:][:4] != [0x09e0, 0x5678, 0x1234, 0x0940]):
        raise ValueError('scalar IRQ continuation/handler differs from its independent program')
    return lint, warm, vector


def check(entry, observed, lines):
    lint, warm, vector = validate(entry)
    errors = []
    def reject(message):
        errors.append('scalar IRQ: '+message)
    def fields(label):
        rows = [s for s in lines if s.startswith(label+' ')]
        if len(rows) != 1:
            reject('expected exactly one '+label+' observation')
            return {}
        try:
            return {k: int(v, 10 if k == 'clock' else 16)
                    for k, v in (word.split('=') for word in rows[0].split()[1:])}
        except ValueError:
            reject('malformed '+label+' observation')
            return {}
    c = entry['fixture']
    follow = fields('FOLLOW')
    follow.update(fields('FOLLOW_EXTRA'))
    memory_rows = [s.split() for s in lines if s.startswith('MEMORY ')]
    try:
        memory = {int(s[1], 16): int(s[2], 16) for s in memory_rows}
    except (ValueError, IndexError):
        reject('malformed final memory observation')
        memory = {}
    if len(memory_rows) != 6 or set(memory) != {a for a, _ in c['initial_memory']}:
        reject('final stack/vector snapshot is missing, duplicate or misassociated')
    return_pc = memory.get(0x2fe0, 0) | (memory.get(0x2ff0, 0) << 16)
    if (return_pc & 15 or not c['next_pc']+16 <= return_pc <= c['next_pc']+16*7):
        reject('saved return PC is outside the initialized continuation')
    if memory.get(0x2fc0, 0) | (memory.get(0x2fd0, 0) << 16) != 0x00200810:
        reject('saved ST differs from the completed ADDK context')
    if memory.get(vector) != 0x4000 or memory.get(vector+16) != 0:
        reject('interrupt vector was corrupted')
    wanted = dict(a0=0x80000003 if warm else 0x12345678, a1=0x11223344,
        a2=2+(return_pc-c['next_pc'])//16 if warm else 2+7, a3=0xd0200810,
        st=0x10 if warm else 0x00200810, sp=0x2fc0 if warm else 0x3000)
    for k, value in wanted.items():
        if follow.get(k) != value:
            reject(f'{"handler entry" if warm else "RETI continuation"} {k.upper()}: '
                   f'expected 0x{value:08x}, observed '+
                   (f'0x{follow[k]:08x}' if k in follow else 'missing'))
    waits = entry.get('stimulus', {}).get('wait_states', 0)
    frame = [0, return_pc & 0xffff, 0x20, 0x0810]
    plan = [(1, address, data, 0) for address, data in zip((0x2ff0, 0x2fe0, 0x2fd0, 0x2fc0), frame)]
    plan += [(0, vector, 0x4000, 0), (0, vector+16, 0, 0)]
    if not warm:
        plan += [(0, 0x4000+16*q, data, 1) for q, data in enumerate((0x09e0, 0x5678, 0x1234, 0x0940))]
    plan += [(0, address, data, 0) for address, data in zip(range(0x2fc0, 0x3000, 16), reversed(frame))]
    for prefix, duration in (('BUS', 16+8*waits), ('TARGET', 4+8*waits)):
        begins = [s.split() for s in lines if s.startswith(prefix+'_BEGIN ')]
        ends = [s.split() for s in lines if s.startswith(prefix+'_END ')]
        if len(begins) != len(plan) or len(ends) != len(plan):
            reject(f'{prefix} expected {len(plan)} frame/vector/handler/RETI transfers, '
                   f'observed {len(begins)} requests/{len(ends)} responses')
            continue
        previous_end = -1
        try:
            for q, ((we, address, data, iaq), a, b) in enumerate(zip(plan, begins, ends)):
                when, until = int(a[1]), int(b[1])
                if ((int(a[2]), int(a[3], 16), int(a[5])) != (we, address, iaq) or
                        (we and int(a[4], 16) != data) or b[2:4] != a[2:4] or
                        (not we and int(b[4], 16) != data)):
                    reject(f'{prefix} transfer {q} request/order/data mismatch')
                if until-when != duration:
                    reject(f'{prefix} transfer {q}: expected {duration} INCLK, observed {until-when}')
                if when < previous_end or when < observed['end']:
                    reject(f'{prefix} transfer {q} is out of order or overlaps the measured NOP')
                previous_end = until
        except (ValueError, IndexError):
            reject('malformed '+prefix+' transaction')
    boundary = None
    if observed.get('protocol_version', 4) >= 5:
        rows = [s for s in lines if s.startswith('IRQ_BOUNDARY ')]
        try:
            if len(rows) != 1 or len(rows[0].split()) != 5:
                raise ValueError('missing or duplicate observation')
            boundary = {k: int(v) for k, v in
                        (word.split('=') for word in rows[0].split()[1:])}
            if (set(boundary) != {'count', 'previous', 'complete', 'first'} or
                    boundary['count'] != 1 or not
                    observed['start'] <= boundary['previous'] < boundary['complete'] < boundary['first']):
                raise ValueError('invalid count or unordered boundaries')
        except (ValueError, KeyError):
            reject('missing, duplicate or invalid explicit IRQ boundaries')
            boundary = None
        if boundary is not None:
            # UG8-6 steps1..4 complete when initialized ST and the vector PC
            # are installed; step5 begins the ISR. Do not use its later decode
            # as the context endpoint. UG8-7/8, Table8-4: recognition1..2,
            # aligned context16 states plus six external word waits.
            stimulus = [s.split() for s in lines if s.startswith('STIMULUS ')]
            if len(stimulus) != 2:
                reject('missing interrupt assertion clock')
            else:
                clocks = boundary['complete']-int(stimulus[0][1])
                lower, upper = 8*(17+6*waits)-1, 8*(18+6*waits)+1
                if not lower <= clocks <= upper:
                    reject(f'LINT{lint} entry latency: expected {lower}..{upper} INCLK '
                           f'(17..18 states + six word waits), observed {clocks}')
            clocks = boundary['complete']-boundary['previous']
            expected = 8*(16+6*waits)
            if clocks != expected:
                reject(f'aligned context switch: expected {expected} INCLK '
                       f'(16 states + six word waits), observed {clocks}')
            # MOVI long is3 cached states (UG12-160). A cold four-word line
            # adds9 states and four configured word waits (cache contract).
            # This separate check prevents an arbitrary gap after context
            # completion from hiding behind the corrected entry endpoint.
            clocks = boundary['first']-boundary['complete']
            expected = 8*(3+(0 if warm else 9+4*waits))
            if clocks != expected:
                reject(f'first ISR MOVI: expected {expected} INCLK, observed {clocks}')
    if warm and observed.get('protocol_version', 4) < 5:
        stimulus = [s.split() for s in lines if s.startswith('STIMULUS ')]
        if len(stimulus) != 2 or 'clock' not in follow:
            reject('missing interrupt assertion or handler-entry clock')
        else:
            # UG 8.5.1/Table8-4: recognition1..2 + aligned context16 states.
            # ADDK is one state, so its remaining interrupt time is zero
            # (Table8-5 note1). Refresh/host traffic are disabled and the
            # handler is warm. Six external words add exactly six waits.
            # One INCLK accommodates the recorded falling-vs-rising edge.
            clocks = follow['clock']-int(stimulus[0][1])
            lower, upper = 8*(17+6*waits)-1, 8*(18+6*waits)+1
            if not lower <= clocks <= upper:
                reject(f'warm LINT{lint} entry latency: expected {lower}..{upper} INCLK '
                       f'(17..18 states + six word waits), observed {clocks}')
            # Saved PC and A2 identify how many one-state ADDKs completed.
            # They fix the acceptance boundary from the measured NOP end,
            # without depending on a private IRQ-take signal or RTL schedule.
            # Table8-4 then requires exactly16 aligned context states.
            completed_addks = (return_pc-c['next_pc'])//16
            context_clocks = follow['clock']-observed['end']-8*completed_addks
            expected_context = 8*(16+6*waits)
            if context_clocks != expected_context:
                reject(f'aligned context switch: expected {expected_context} INCLK '
                       f'(16 states + six word waits), observed {context_clocks}')
    # Uninitialized B registers have no architectural expectation in this
    # fixture. Compare only explicitly initialized/observed state.
    follow = {k: v for k, v in follow.items() if k in wanted or k == 'clock'}
    normalized = {}
    for prefix in PREFIXES:
        rows = []
        for line in lines:
            if line.startswith(prefix+' '):
                a = line.split()
                a[1] = str(int(a[1])-observed['start'])
                rows.append(' '.join(a))
        normalized[prefix] = rows
    if 'clock' in follow:
        follow['clock'] -= observed['start']
    result = dict(follow=follow, memory=[list(pair) for pair in sorted(memory.items())], traces=normalized)
    if observed.get('protocol_version', 4) >= 5:
        result['boundary'] = (None if boundary is None else
            {k: value if k == 'count' else value-observed['start'] for k, value in boundary.items()})
    return errors, result
