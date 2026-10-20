# SPDX-License-Identifier: GPL-3.0-or-later
"""TI NMIM=1 state/bus rules; no invented total context-switch duration.

SPVU001A6-32/33 and8-5 require discarding the interrupted context without
stack traffic. Section8.5.1/Table8-4 specifies1..2 recognition states from
host-write completion. Its16/28-state context rule describes stack pushes;
NMIM=1 has no separately printed context count and is explicitly not signed off.
"""


def validate(entry):
    contract = entry.get('external_contract')
    keys = {'kind', 'handler_warm', 'sp_offset', 'interrupt_enable', 'assert_clock'}
    if (not isinstance(contract, dict) or set(contract) != keys or
            contract['kind'] != 'scalar_nmi_nostack' or
            type(contract['handler_warm']) is not bool or
            type(contract['interrupt_enable']) is not bool or
            type(contract['sp_offset']) is not int or not 0 <= contract['sp_offset'] <= 15 or
            type(contract['assert_clock']) is not int or not 16 <= contract['assert_clock'] <= 23):
        raise ValueError('unsupported no-stack NMI contract')
    c = entry['fixture']
    sp = 0x3000+contract['sp_offset']
    status = 0xd0000810 | (0x00200000 if contract['interrupt_enable'] else 0)
    expected = dict(opcode=0x0300, states=1, cache_disabled=False, initial_sp=sp,
        regs=[0x80000003, 0x11223344, 2, status],
        expected_regs=[0x80000003, 0x11223344, 2, status], expected_st=status,
        expected_extra_regs=dict(sp=sp, a4=0x4000, a5=0x4050, a13=0x18, a14=0xc00000b0),
        observe_all=True, observe_implicit=True, setup_io=[], drain_instructions=12,
        following_words=[0x0300]*12, follow_pc=0x4030)
    if any(c.get(k) != v for k, v in expected.items()) or c.get('measure_pass', 1) != 1:
        raise ValueError('no-stack NMI initialization differs from its contract')
    memory = {a: 0xa5a5 for a in range((sp-64) & ~15, ((sp+31) & ~15)+16, 16)}
    memory.update({0xfffffee0: 0x4000, 0xfffffef0: 0})
    if (len(c.get('initial_memory', [])) != len(memory) or dict(c['initial_memory']) != memory or
            c['test_pc'] != entry['test_pc'] or c['next_pc'] != entry['next_pc'] or
            c['next_pc'] != c['test_pc']+16):
        raise ValueError('no-stack NMI memory/measurement association differs')
    words = entry['program_words']
    q = (c['next_pc']-0x1000)//16
    if (words[q:q+12] != [0x0300]*12 or
            words[(0x4000-0x1000)//16:] != [0x09e0, 0x5678, 0x1234, 0x0165, 0x0300, 0xc0ff, 0x0300, 0x0300]):
        raise ValueError('no-stack NMI handler/continuation differs')
    wanted = [dict(trigger=0, argument=contract['assert_clock'], control=0x310),
              dict(trigger=5, argument=1, control=0)]
    stimulus = entry.get('stimulus', {})
    if (entry.get('external_events') != wanted or type(stimulus.get('wait_states')) is not int or
            stimulus['wait_states'] not in (0, 1, 3) or
            stimulus.get('pause_clocks', 0) or stimulus.get('pause_after_clocks', 0)):
        raise ValueError('no-stack NMI stimulus differs from its contract')
    return contract, sp, status


def check(entry, observed, lines):
    contract, sp, status = validate(entry)
    errors = []
    def reject(message):
        errors.append('no-stack NMI: '+message)
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
    follow = fields('FOLLOW')
    follow.update(fields('FOLLOW_EXTRA'))
    follow.update(fields('FOLLOW_ALL'))
    wanted = dict(a0=0x12345678, a1=0x11223344, a2=2, a3=status,
                  a4=0x4000, a5=0x4050, a13=0x18, a14=0xc00000b0, sp=sp, st=0x10)
    for key, expected in wanted.items():
        if follow.get(key) != expected:
            reject(f'ISR {key.upper()}: expected 0x{expected:08x}, observed '+
                   (f'0x{follow[key]:08x}' if key in follow else 'missing'))
    memory_rows = [s.split() for s in lines if s.startswith('MEMORY ')]
    try:
        memory = {int(s[1], 16): int(s[2], 16) for s in memory_rows}
    except (ValueError, IndexError):
        reject('malformed memory observation')
        memory = {}
    if len(memory_rows) != len(memory) or memory != dict(entry['fixture']['initial_memory']):
        reject('stack guards or vector changed')
    # Exactly two vector reads; cold entry also fills the four-word ISR line.
    # No stack transaction, hidden push or RETI read is allowed anywhere.
    plan = [(0xfffffee0, 0x4000, 0), (0xfffffef0, 0, 0)]
    if not contract['handler_warm']:
        plan += [(0x4000+16*q, word, 1)
                 for q, word in enumerate((0x09e0, 0x5678, 0x1234, 0x0165))]
    # The handler's register JUMP reaches a second line at0x4050.
    plan += [(0x4040+16*q, word, 1)
             for q, word in enumerate((0x0300, 0xc0ff, 0x0300, 0x0300))]
    normalized = {}
    waits = entry['stimulus']['wait_states']
    for prefix, duration in (('BUS', 16+8*waits), ('TARGET', 4+8*waits)):
        begins = [s.split() for s in lines if s.startswith(prefix+'_BEGIN ')]
        ends = [s.split() for s in lines if s.startswith(prefix+'_END ')]
        if len(begins) != len(plan) or len(ends) != len(plan):
            reject(f'{prefix} expected {len(plan)} vector/handler reads, observed {len(begins)}/{len(ends)}')
        previous = observed['end']
        try:
            for q, ((address, data, iaq), begin, end) in enumerate(zip(plan, begins, ends)):
                when, until = int(begin[1]), int(end[1])
                if (int(begin[2]), int(begin[3], 16), int(begin[5]), int(end[2]), int(end[3], 16), int(end[4], 16)) != (0, address, iaq, 0, address, data):
                    reject(f'{prefix} transfer {q} kind/address/order/data mismatch')
                if when < previous or until-when != duration:
                    reject(f'{prefix} transfer {q} timing: expected {duration} INCLK, observed {until-when}')
                previous = until
            if prefix == 'BUS':
                accepts = [int(s.split()[1]) for s in lines if s.startswith('BUS_ACCEPT ')]
                if len(accepts) != len(plan) or any(not int(a[1]) <= clock < int(b[1])
                        for a, b, clock in zip(begins, ends, accepts)):
                    reject('BUS acknowledgement count/order differs')
        except (ValueError, IndexError):
            reject('malformed '+prefix+' transaction')
        for label in (prefix+'_BEGIN', prefix+'_ACCEPT', prefix+'_END'):
            values = []
            for line in lines:
                if line.startswith(label+' '):
                    parts = line.split()
                    parts[1] = str(int(parts[1])-observed['start'])
                    values.append(' '.join(parts))
            normalized[label] = values
    boundary = None
    try:
        rows = [s for s in lines if s.startswith('IRQ_BOUNDARY ')]
        if observed.get('protocol_version') != 5 or len(rows) != 1:
            raise ValueError('missing explicit boundary')
        boundary = {k: int(v) for k, v in (word.split('=') for word in rows[0].split()[1:])}
        if (set(boundary) != {'count', 'previous', 'complete', 'first'} or boundary['count'] != 1 or not
                observed['end'] <= boundary['previous'] < boundary['complete'] < boundary['first']):
            raise ValueError('invalid context boundary')
        acknowledgements = [int(s.split()[1]) for s in lines if s.startswith('HOST_ACK ')]
        if len(acknowledgements) != 1:
            reject('expected exactly one host NMI completion clock')
        else:
            recognition = boundary['previous']-acknowledgements[0]
            if not 7 <= recognition <= 17:
                reject(f'recognition: expected 7..17 INCLK (1..2 states), observed {recognition}')
        first = boundary['first']-boundary['complete']
        expected = 8*(3+(0 if contract['handler_warm'] else 9+4*waits))
        if first != expected:
            reject(f'first ISR MOVI: expected {expected} INCLK, observed {first}')
        bus_ends = [int(s.split()[1]) for s in lines if s.startswith('BUS_END ')]
        if (len(bus_ends) < 2 or bus_ends[1] > boundary['complete'] or
                follow.get('clock', 0) < boundary['first']):
            reject('vector completion, context and ISR observations are out of order')
    except (ValueError, KeyError):
        reject('missing, malformed or unordered explicit NMI boundaries')
    follow = {k: v for k, v in follow.items() if k in wanted or k == 'clock'}
    if 'clock' in follow:
        follow['clock'] -= observed['start']
    return errors, dict(follow=follow, memory=[list(pair) for pair in sorted(memory.items())],
        traces=normalized, boundary=None if boundary is None else
        {k: v if k == 'count' else v-observed['start'] for k, v in boundary.items()},
        context_duration_contract='not separately specified for NMIM=1; observed only')
