# SPDX-License-Identifier: GPL-3.0-or-later
"""Independent runtime contract for a small interrupted native LINE.

The full compound interval is intentionally observed-only: the guide does not
publish a total across a scheduled graphics checkpoint, interrupt service,
RETI and LINE restart. Defined interrupt and RETI subintervals, registers,
memory and physical data transactions remain checked independently.
"""
import hashlib

PROGRAM_SHA256 = '2f1aa7abf85b68631b2e8f3b30f80f9affffff3a5502de15078d375a093f5d43'
START_PC = 0x19f0
NEXT_PC = 0x1a00
FOLLOW_PC = 0x1a30
PIXEL_WRITES = ((0x0320, 0x7fff), (0x0330, 0x7fff),
                (0x0340, 0x7fff), (0x0350, 0x7fff))
INITIAL_REGS = (
    ('a0',0x13579b00),('a1',0x13579b01),('a2',0x13579b02),('a3',0xf0200810),
    ('a4',0x13579b04),('a5',0x13579b05),('a6',0x13579b06),('a7',0x13579b07),
    ('a8',0x13579b08),('a9',0x13579b09),('a10',0x13579b0a),('a11',0x13579b0b),
    ('a12',0x13579b0c),('a13',0x13579b0d),('a14',0x13579b0e),('b0',0xfffffffd),
    ('b1',0x13579b11),('b2',0x00020002),('b3',0x00000080),('b4',0x00000200),
    ('b5',0),('b6',0x7fff7fff),('b7',3),('b8',0x13579b18),('b9',0x7fff7fff),
    ('b10',4),('b11',1),('b12',1),('b13',0xffffffff),('b14',0x13579b1e),('sp',0x3000))
EXPECTED_INITIAL_MEMORY = {
    0x0310:0xd9b3,0x0320:0x2bcc,0x0330:0x0519,0x0340:0x1752,
    0x0350:0x616f,0x0360:0x72b8,0x2f80:0xa55a,0x2f90:0xa55a,
    0x2fa0:0xa55a,0x2fb0:0xa55a,0x2fc0:0x0010,0x2fd0:0,
    0x2fe0:0x1070,0x2ff0:0,0xffffffc0:0x4000,0xffffffd0:0}
EXPECTED_FINAL_MEMORY = {
    **EXPECTED_INITIAL_MEMORY,0x0320:0x7fff,0x0330:0x7fff,
    0x0340:0x7fff,0x0350:0x7fff,0x2fc0:0x0810,0x2fd0:0xf020,
    0x2fe0:START_PC,0x2ff0:0}


def _program_hash(words):
    try:
        return hashlib.sha256(b''.join(w.to_bytes(2, 'little') for w in words)).hexdigest()
    except (AttributeError, OverflowError, TypeError):
        return ''


def _memory(entry):
    return dict(entry['fixture'].get('initial_memory', []))

def _freeze(value):
    if isinstance(value, (list, tuple)):
        return tuple(_freeze(item) for item in value)
    if isinstance(value, dict):
        return tuple(sorted((key, _freeze(item)) for key, item in value.items()))
    return value


def _literal_movi(value, register):
    value &= 0xffffffff
    return [0x09e0 + register, value & 0xffff, value >> 16]

def _literal_program():
    # Independent small assembler for this pinned fixture, using the ISA MOVI
    # encoding and literal setup/handler words rather than the line producer.
    warm = _literal_movi(0x2fc0,15) + _literal_movi(0x4000,14) + [0x016e]
    words = []
    setup = ((0xc00000b0,0x18),(0xc0000140,24),(0xc0000150,16),
             (0xc0000160,0),(0xc0000110,2))
    for address,value in setup:
        words += _literal_movi(address,14)+_literal_movi(value,13)+[0x0550,0x81ae]
    for name,value in INITIAL_REGS:
        register = 15 if name == 'sp' else int(name[1:])+(16 if name.startswith('b') else 0)
        words += _literal_movi(value,register)
    words += [0x01a3]+[0x0300]*12
    while len(words)%4:
        words.append(0x0300)
    jump = len(words)
    words += [0xc080,0,0,0x0300]
    start = 0x1000+16*(len(warm)+len(words))
    words[jump+1:jump+3] = [start & 0xffff,start >> 16]
    words = warm+words
    words += [0xdf1a]
    base_start = start - 16*len(warm)
    words += [0x0300]*16+[0x01a3,0xc080,(base_start-16)&0xffff,(base_start-16)>>16]
    while len(words)<768:
        words.append(0x0300)
    words.append(0x0940)
    return words,start,start+16,start+16*4

def validate(entry):
    contract = entry.get('external_contract')
    if (not isinstance(contract, dict) or set(contract) != {'kind', 'interrupt', 'duration', 'program_sha256'} or
            contract.get('kind') != 'graphics_line_irq' or
            contract.get('interrupt') not in ('lint1', 'nmi') or
            contract.get('duration') != 'observed_only' or
            contract.get('program_sha256') != PROGRAM_SHA256):
        raise ValueError('unsupported graphics LINE interrupt contract')
    interrupt = contract['interrupt']
    fixture = entry.get('fixture')
    if not isinstance(fixture, dict) or fixture.get('name') != entry.get('name') or not entry['name'].startswith('graphics_line_'):
        raise ValueError('graphics LINE entry/fixture association differs')
    if (entry.get('test_pc') != START_PC or entry.get('next_pc') != NEXT_PC or
            fixture.get('test_pc') != START_PC or fixture.get('next_pc') != NEXT_PC or
            NEXT_PC != START_PC + 16 or fixture.get('follow_pc') != FOLLOW_PC):
        raise ValueError('graphics LINE measurement PCs differ from literal contract')
    if entry.get('stimulus') != {'wait_states': 0}:
        raise ValueError('graphics LINE contract currently requires zero external waits')
    if entry.get('external_events') != (
            [{'trigger': 1, 'argument': 1, 'control': 1},
             {'trigger': 1, 'argument': 5, 'control': 0}] if interrupt == 'lint1' else
            [{'trigger': 1, 'argument': 1, 'control': 0x110},
             {'trigger': 5, 'argument': 1, 'control': 0}]):
        raise ValueError('graphics LINE interrupt event schedule differs')
    if (fixture.get('initial_sp') != 0x3000 or fixture.get('measure_pass', 1) != 0 or
            fixture.get('opcode') != 0xdf1a or fixture.get('states') != 24 or
            fixture.get('cache_disabled') is not False or fixture.get('control') != 0 or
            fixture.get('status_holder') != 3 or fixture.get('drain_instructions') != 4 or
            fixture.get('observe_all') is not True or fixture.get('observe_implicit') is not True or
            fixture.get('expected_wvp') != 0 or
            _freeze(fixture.get('conditions')) != _freeze(dict(size=16, count=4, z=0, a=3, b=0, d=0xfffffffd,
                point=0x00020002, diagonal=(1, 0), major=(1, 0), window=0,
                wstart=(0, 0), wend=(32767, 32767), convdp=24, offset=0x200,
                color=0x7fff7fff, ppop=0, pmask=0, transparency=False,
                bus_policy='Fig13-1 partial-word RMW/whole-word writes; first-access/pin phase not claimed'))):
        raise ValueError('graphics LINE fixture differs from the independently specified instruction')
    wanted_io = [(0xc0000140, 24), (0xc0000150, 16), (0xc0000160, 0)]
    wanted_io.append((0xc0000110, 2))
    if _freeze(fixture.get('setup_io')) != _freeze(wanted_io):
        raise ValueError('graphics LINE setup I/O differs')
    words = entry.get('program_words')
    literal_words, literal_start, literal_next, literal_follow = _literal_program()
    if (START_PC,NEXT_PC,FOLLOW_PC)!=(literal_start,literal_next,literal_follow):
        raise ValueError('internal graphics LINE literal PC constants differ')
    if not isinstance(words, list) or words != literal_words or len(words) != 769 or _program_hash(words) != PROGRAM_SHA256:
        raise ValueError('graphics LINE program words differ from the pinned literal program')
    if (words[(START_PC - 0x1000) // 16] != 0xdf1a or
            words[(NEXT_PC - 0x1000) // 16] != 0x0300 or words[768] != 0x0940):
        raise ValueError('graphics LINE opcode, continuation or warmed RETI differs')
    memory = _memory(entry)
    if len(memory) != len(fixture.get('initial_memory', [])) or len(memory) != 16:
        raise ValueError('graphics LINE sparse memory inventory differs')
    vector = 0xffffffc0 if interrupt == 'lint1' else 0xfffffee0
    other = 0xfffffee0 if interrupt == 'lint1' else 0xffffffc0
    if memory.get(vector) != 0x4000 or memory.get(vector + 16) != 0 or other in memory or other + 16 in memory:
        raise ValueError('graphics LINE interrupt vector differs')
    if memory.get(0x2fc0) != 0x10 or memory.get(0x2fd0) != 0 or memory.get(0x2fe0) != 0x1070 or memory.get(0x2ff0) != 0:
        raise ValueError('graphics LINE warm RETI frame differs')
    if _freeze(fixture.get('initial_all_regs')) != _freeze(dict(INITIAL_REGS)):
        raise ValueError('graphics LINE initialized register file differs')
    expected_a = [0x13579b00,0x13579b01,0x13579b02,0xf0200810]
    if (_freeze(fixture.get('regs')) != _freeze(expected_a) or
            _freeze(fixture.get('expected_regs')) != _freeze(expected_a) or
            fixture.get('expected_st') != 0xf0200810 or fixture.get('expected_st_mask') != 0x1fffffff or
            _freeze(fixture.get('expected_extra_regs')) != _freeze(dict(
                a4=0x13579b04,a5=0x13579b05,a6=0x13579b06,a7=0x13579b07,a8=0x13579b08,
                a9=0x13579b09,a10=0x13579b0a,a11=0x13579b0b,a12=0x13579b0c,
                a13=0x13579b0d,a14=0x13579b0e,b0=0xfffffffd,b1=0x13579b11,
                b2=0x00020006,b3=0x80,b4=0x200,b5=0,b6=0x7fff7fff,b7=3,
                b8=0x13579b18,b9=0x7fff7fff,b10=0,b11=1,b12=1,sp=0x3000))):
        raise ValueError('graphics LINE expected register/status state differs')
    wanted_initial = dict(EXPECTED_INITIAL_MEMORY)
    if interrupt == 'nmi':
        wanted_initial.pop(0xffffffc0); wanted_initial.pop(0xffffffd0)
        wanted_initial[0xfffffee0]=0x4000; wanted_initial[0xfffffef0]=0
    wanted_final = dict(EXPECTED_FINAL_MEMORY)
    if interrupt == 'nmi':
        wanted_final.pop(0xffffffc0); wanted_final.pop(0xffffffd0)
        wanted_final[0xfffffee0]=0x4000; wanted_final[0xfffffef0]=0
    expected_pixel_plan = dict(pixels=[(0x0320,True),(0x0330,True),(0x0340,True),(0x0350,True)],
                               transfers=[(1,address,value,0) for address,value in PIXEL_WRITES])
    if (_memory(entry) != wanted_initial or dict(fixture.get('expected_memory',[])) != wanted_final or
            len(fixture.get('expected_memory',[])) != len(wanted_final) or
            _freeze(fixture.get('data_line')) != _freeze(expected_pixel_plan)):
        raise ValueError('graphics LINE sparse pixel canary, pixel plan, frame, vector or final memory differs')
    return interrupt


def _parse(line):
    fields = line.split()
    return fields[0], [int(value, 10) if i == 0 else int(value, 16)
                        for i, value in enumerate(fields[1:])]


def check(entry, observed, lines):
    interrupt = validate(entry)
    prefix = 'graphics LINE '+interrupt+': '
    errors = []
    def reject(message):
        errors.append(prefix+message)

    # Never assert a whole-run duration: retain it for the independent
    # original-system/Avalon equality check performed by the caller.
    if observed.get('clocks', 0) <= 0 or observed.get('end', 0) - observed.get('start', 0) != observed.get('clocks'):
        reject('missing or inconsistent observed compound clock interval')

    memory_rows = [line.split() for line in lines if line.startswith('MEMORY ')]
    try:
        actual_memory = {int(row[1], 16): int(row[2], 16) for row in memory_rows}
    except (ValueError, IndexError):
        actual_memory = {}
        reject('malformed final memory snapshot')
    expected_memory = dict(entry['fixture']['expected_memory'])
    if len(actual_memory) != len(memory_rows) or actual_memory != expected_memory:
        reject('final pixel memory, stack frame, vector or canary mismatch')

    boundary_rows = [line for line in lines if line.startswith('IRQ_BOUNDARY ')]
    try:
        if len(boundary_rows) != 1:
            raise ValueError('missing/duplicate')
        boundary = {key: int(value) for key, value in
                    (item.split('=') for item in boundary_rows[0].split()[1:])}
        if set(boundary) != {'count', 'previous', 'complete', 'first'} or boundary['count'] != 1:
            raise ValueError('invalid boundary fields')
        if not (observed['start'] <= boundary['complete'] and
                (boundary['previous'] == 0 or observed['start'] <= boundary['previous'] < boundary['complete']) and
                boundary['complete'] < boundary['first'] <= observed['end']):
            raise ValueError('unordered boundary clocks')
    except (ValueError, KeyError):
        reject('missing, duplicate or unordered context/first-ISR boundaries')
        boundary = None

    stimulus = [line.split() for line in lines if line.startswith('STIMULUS ')]
    if len(stimulus) != 2:
        reject(f'expected two applied interrupt/release events, observed {len(stimulus)}')
    elif (int(stimulus[0][4]) != 1 or int(stimulus[1][4]) != (5 if interrupt == 'lint1' else 1)):
        reject('interrupt event did not follow the literal first-pixel/frame checkpoint')
    if interrupt == 'nmi':
        host_acks = [line.split() for line in lines if line.startswith('HOST_ACK ')]
        if len(host_acks) != 1:
            reject(f'expected one NMI host acknowledgement, observed {len(host_acks)}')
        elif stimulus and int(stimulus[1][1]) <= int(host_acks[0][1]):
            reject('NMI release did not follow its registered host acknowledgement')
        request_clock = int(host_acks[0][1]) if len(host_acks) == 1 else None
    else:
        request_clock = int(stimulus[0][1]) if stimulus else None
    if boundary is not None and request_clock is not None:
        entry_clocks = boundary['complete'] - request_clock
        # UG 8.5.1 Table 8-4: recognition and context sum to 17..22
        # states; this request arrives just after LINE's first pixel checkpoint.
        low, high = 17 * 8 - 1, 22 * 8 + 1
        if not low <= entry_clocks <= high:
            reject(f'interrupt recognition/context: expected {low}..{high} INCLK, observed {entry_clocks}')
        reti_clocks = boundary['first'] - boundary['complete']
        if reti_clocks != 20 * 8:
            reject(f'cold aligned RETI: expected {20*8} INCLK (11 RETI + 9 cache-fill states), observed {reti_clocks}')

    # Full protocol stream: every request is either an instruction fetch from
    # the literal image/handler cache line or one of the exact data operations.
    expected_data = [(1, 0x0320, 0x7fff),
                     *((1, address, dict(entry['fixture']['expected_memory'])[address])
                       for address in (0x2ff0, 0x2fe0, 0x2fd0, 0x2fc0))]
    vector = 0xffffffc0 if interrupt == 'lint1' else 0xfffffee0
    expected_data.extend(((0, vector, 0x4000), (0, vector+16, 0)))
    expected_stack = dict(entry['fixture']['expected_memory'])
    expected_data.extend((0, address, expected_stack[address])
                         for address in (0x2fc0, 0x2fd0, 0x2fe0, 0x2ff0))
    expected_data.extend((1, address, data) for address, data in PIXEL_WRITES[1:])

    requests = []
    accepts = []
    responses = []
    for line in lines:
        if line.startswith('BUS_BEGIN '):
            f = line.split()
            requests.append(dict(clock=int(f[1]), we=int(f[2]), address=int(f[3],16),
                                 wdata=int(f[4],16), iaq=int(f[5])))
        elif line.startswith('BUS_ACCEPT '):
            accepts.append(int(line.split()[1]))
        elif line.startswith('BUS_END '):
            f = line.split()
            responses.append(dict(clock=int(f[1]), we=int(f[2]), address=int(f[3],16),
                                   rdata=int(f[4],16)))

    if not (len(requests) == len(accepts) == len(responses)):
        reject(f'BUS request/accept/response count differs: {len(requests)}/{len(accepts)}/{len(responses)}')
    paired_count = min(len(requests),len(accepts),len(responses))
    data_q = 0
    fetch_errors = 0
    bus_spans = []
    for q in range(paired_count):
        request, accepted, response = requests[q], accepts[q], responses[q]
        if (request['we'] != response['we'] or request['address'] != response['address'] or
                not request['clock'] <= accepted < response['clock']):
            reject(f'BUS transaction {q} has unmatched request/accept/response association')
        bus_spans.append((request['clock'],response['clock'],request['address'],request['we']))
        if request['iaq'] == 0:
            if data_q >= len(expected_data):
                reject(f'unexpected data BUS transaction {q}: {request}')
                continue
            want_we,want_addr,want_data=expected_data[data_q]
            if (request['we'],request['address']) != (want_we,want_addr):
                reject(f'data BUS transaction {data_q} order/kind/address mismatch: {request}')
            if want_we and request['wdata'] != want_data:
                reject(f'data BUS transaction {data_q} write payload mismatch')
            if not want_we and response['rdata'] != want_data:
                reject(f'data BUS transaction {data_q} read response mismatch')
            data_q += 1
        elif request['iaq'] == 1 and request['we'] == 0:
            address=request['address']
            if 0x1000 <= address < 0x1000+16*len(entry['program_words']) and (address-0x1000)%16 == 0:
                want=entry['program_words'][(address-0x1000)//16]
            elif 0x4010 <= address <= 0x4030 and (address-0x4000)%16 == 0:
                want=0
            else:
                reject(f'instruction BUS fetch outside literal program/handler image: {address:08x}')
                fetch_errors += 1
                continue
            if response['rdata'] != want:
                reject(f'instruction BUS fetch data differs at {address:08x}: expected {want:04x}, observed {response["rdata"]:04x}')
        else:
            reject(f'unsupported BUS transaction type at transaction {q}: {request}')
    if data_q != len(expected_data):
        reject(f'expected {len(expected_data)} ordered data BUS transactions, observed {data_q}')

    target_begins=[];target_ends=[]
    for line in lines:
        if line.startswith('TARGET_BEGIN '):
            f=line.split();target_begins.append(dict(clock=int(f[1]),we=int(f[2]),address=int(f[3],16),
                wdata=int(f[4],16),iaq=int(f[5])))
        elif line.startswith('TARGET_END '):
            f=line.split();target_ends.append(dict(clock=int(f[1]),we=int(f[2]),address=int(f[3],16),
                rdata=int(f[4],16)))
    if not (len(requests)==len(target_begins)==len(target_ends)):
        reject(f'TARGET request/response count differs from BUS: {len(requests)}/{len(target_begins)}/{len(target_ends)}')
    for q,(request,accepted,target,end) in enumerate(zip(requests,accepts,target_begins,target_ends)):
        bus_end=responses[q] if q<len(responses) else None
        if (target['we'],target['address'],target['wdata'],target['iaq']) != (
                request['we'],request['address'],request['wdata'],request['iaq']):
            reject(f'TARGET transaction {q} request data/association mismatch')
        if (end['we'],end['address']) != (request['we'],request['address']) or end['clock']-target['clock'] != 4:
            reject(f'TARGET transaction {q} response/4-clock duration mismatch')
        if accepted != target['clock']:
            reject(f'TARGET transaction {q} acceptance ACK clock mismatch')
        if not (request['clock'] <= target['clock'] < end['clock'] <= bus_end['clock']):
            reject(f'TARGET transaction {q} is outside its logical BUS interval')
        if not request['we'] and bus_end['rdata'] != end['rdata']:
            reject(f'TARGET transaction {q} read data differs from BUS response')

    # The event is generated only after the target acknowledges pixel 0; the
    # normal CPU BUS completion follows.  Context completion must follow both
    # architectural vector reads and the first handler retirement is bounded.
    first_pixel = next((q for q,r in enumerate(requests)
                        if r['iaq']==0 and r['we']==1 and r['address']==PIXEL_WRITES[0][0]), None)
    if stimulus and first_pixel is not None and first_pixel < len(target_ends) and first_pixel < len(bus_spans):
        first_pixel_end=target_ends[first_pixel]['clock']
        first_pixel_bus_end=bus_spans[first_pixel][1]
        event_clock=int(stimulus[0][1])
        if not first_pixel_end < event_clock < first_pixel_bus_end:
            reject(f'event clock is outside first acknowledged pixel checkpoint window: expected ({first_pixel_end},{first_pixel_bus_end}), observed {event_clock}')
    vector_end_indexes=[q for q,r in enumerate(requests) if r['iaq']==0 and r['address'] in (vector,vector+16)]
    if boundary is not None and len(vector_end_indexes)==2:
        if boundary['complete'] < responses[vector_end_indexes[-1]]['clock']:
            reject('context completion precedes completion of the second vector read')
    return errors, dict(clocks=observed.get('clocks'), interrupt=interrupt,
                        boundary=boundary, bus_transfers=len(expected_data))
    return errors, dict(clocks=observed.get('clocks'), interrupt=interrupt,
                        boundary=boundary, bus_transfers=len(expected_data))
