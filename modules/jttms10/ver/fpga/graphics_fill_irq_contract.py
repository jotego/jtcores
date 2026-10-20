# SPDX-License-Identifier: GPL-3.0-or-later
"""Independent CPU-visible contract for interrupted aligned FILL L/XY."""
import hashlib

STARTS = {
    ('l','lint1'): 0x1af0, ('l','nmi'): 0x18f0,
    ('xy','lint1'): 0x1af0, ('xy','nmi'): 0x18f0,
}
HASHES = {
    ('l','lint1'): '6b65f5d3ca62fbbb2934dca80f11043995564dc8213be5ac5bb0f2ee671d3b57',
    ('l','nmi'): '3640b0dac854f27c8e8475c48fda58ce2ac9abd4751b1348ad65ff19e947fb19',
    ('xy','lint1'): '5361ff10e88f49811f132a65b5f3529f384680077d787bdd66521a74fa223725',
    ('xy','nmi'): 'f7da82beb0a3417c20b66e2ddedde8fa1858438700d57ef37a2ac59b9231e94f',
}
MEMORY_INITIAL_FILL = {
    0x60f0:0xa596, 0x6100:0xa497, 0x6110:0xa794, 0x6120:0xa695,
    0x61f0:0xb487, 0x6200:0xb586, 0x6210:0xb685, 0x6220:0xb784,
    0x62f0:0x87b4, 0x6300:0x86b5, 0x6310:0x85b6, 0x6320:0x84b7,
    0x63f0:0x96a5, 0x6400:0x97a4, 0x6410:0x94a7, 0x6420:0x95a6,
    0x64f0:0xe1d2, 0x6500:0xe0d3, 0x6510:0xe3d0, 0x6520:0xe2d1,
    0x65f0:0xf0c3, 0x6600:0xf1c2, 0x6610:0xf2c1, 0x6620:0xf3c0,
    0x66f0:0xc3f0, 0x6700:0xc2f1, 0x6710:0xc1f2, 0x6720:0xc0f3,
    0x67f0:0xd2e1, 0x6800:0xd3e0, 0x6810:0xd0e3, 0x6820:0xd1e2,
}
STACK_INITIAL = {address:0xa55a for address in range(0x2f80,0x3000,16)}
FILL_WRITES = tuple((address,0xaa55) for address in (
    0x6100,0x6110,0x6200,0x6210,0x6300,0x6310,0x6400,0x6410,
    0x6500,0x6510,0x6600,0x6610,0x6700,0x6710,0x6800,0x6810))
INIT_REGS = tuple((f'a{q}',0x13579b00+q) for q in range(15)) + tuple(
    (f'b{q}',0x13579b10+q) for q in range(15)) + (('sp',0x3000),)


def _freeze(value):
    if isinstance(value,(list,tuple)):
        return tuple(_freeze(item) for item in value)
    if isinstance(value,dict):
        return tuple(sorted((key,_freeze(item)) for key,item in value.items()))
    return value


def _movi(value, register):
    value &= 0xffffffff
    return [0x09e0+register,value&0xffff,value>>16]


def _literal_program(engine, interrupt):
    """Rebuild this small image from literal TI/ISA inputs, not the producer."""
    warm = _movi(0x2fc0,15)+_movi(0x4000,14)+[0x016e]
    words=[]
    setup=[(0xc00000b0,0x18),(0xc0000150,16),(0xc0000160,0),(0xc0000140,23)]
    if interrupt == 'lint1':
        setup.append((0xc0000110,2))
    for address,value in setup:
        words += _movi(address,14)+_movi(value,13)+[0x0550,0x81ae]
    while len(words)%32:
        words.append(0x0300)
    words += _movi(0x13579b00,0)
    for q in range(1,16):
        words += [0x4c00|q,0x1000|(q<<5)|q]
    for q in range(15):
        words += [0x4e00|q,0x1000|((16+q)<<5)|0x10|q]
    overrides=[('b2',0x00010000 if engine=='xy' else 0x6100),
               ('b3',0x100),('b7',0x00080002),('b9',0x5cc3aa55)]
    if engine == 'xy':
        overrides.append(('b4',0x6000))
    overrides.append(('sp',0x3000))
    for name,value in overrides:
        register=15 if name=='sp' else 16+int(name[1:])
        words += _movi(value,register)
    words += _movi(0x13579b07,7)+_movi(0xf0200810,3)+[0x01a3]+[0x0300]*12
    while (len(words)+4)%4:
        words.append(0x0300)
    loop=0x1000+16*len(words)
    jump=len(words)
    words += [0xc080,0,0,0x0300]
    start=0x1000+16*(len(warm)+len(words))
    end=start+16
    words[jump+1:jump+3]=[end&0xffff,end>>16]
    words += [0x0fe0 if engine=='xy' else 0x0fc0]
    words += [0x0300]*16+[0x01a3,0xc080,0,0]
    words=warm+words
    tail_jump=(start-0x1000)//16+18
    words[tail_jump+1:tail_jump+3]=[(start-16)&0xffff,(start-16)>>16]
    while len(words)<768:
        words.append(0x0300)
    words.append(0x0940)
    return words,start,end


def _digest(words):
    return hashlib.sha256(b''.join(w.to_bytes(2,'little') for w in words)).hexdigest()


def validate(entry):
    contract=entry.get('external_contract')
    if not isinstance(contract,dict) or set(contract)!={'kind','interrupt','engine','duration','program_sha256'}:
        raise ValueError('unsupported native FILL interrupt contract')
    engine,interrupt=contract.get('engine'),contract.get('interrupt')
    key=(engine,interrupt)
    if (contract.get('kind')!='graphics_fill_irq' or key not in STARTS or
            contract.get('duration')!='observed_only' or contract.get('program_sha256')!=HASHES[key]):
        raise ValueError('unsupported native FILL contract kind, scope or image digest')
    entry_name=f'graphics_fill_{engine}_{interrupt}_resume'
    fixture=entry.get('fixture')
    if (not isinstance(fixture,dict) or entry.get('name')!=entry_name or
            fixture.get('name')!=entry_name):
        raise ValueError('native FILL entry/fixture association differs')
    literal,start,end=_literal_program(engine,interrupt)
    if (start,end)!=(STARTS[key],STARTS[key]+16):
        raise ValueError('internal native FILL literal PCs differ')
    if (entry.get('test_pc'),entry.get('next_pc'),fixture.get('test_pc'),fixture.get('next_pc'))!=(start,end,start,end):
        raise ValueError('native FILL measurement PCs differ')
    if entry.get('stimulus')!={'wait_states':0} or fixture.get('measure_pass',1)!=0:
        raise ValueError('native FILL requires the measured initialized pass and zero waits')
    if entry.get('program_words')!=literal or len(literal)!=769 or _digest(literal)!=HASHES[key]:
        raise ValueError('native FILL program differs from independently rebuilt literal image')
    if (literal[(start-0x1000)//16]!=(0x0fe0 if engine=='xy' else 0x0fc0) or
            literal[(end-0x1000)//16]!=0x0300 or literal[768]!=0x0940):
        raise ValueError('native FILL opcode, continuation or RETI handler differs')
    event_after_writes=2 if engine=='xy' else 1
    expected_events=([dict(trigger=1,argument=event_after_writes,control=1),
                      dict(trigger=1,argument=5,control=0)] if interrupt=='lint1' else
                     [dict(trigger=1,argument=event_after_writes,control=0x110),
                      dict(trigger=5,argument=1,control=0)])
    if entry.get('external_events')!=expected_events:
        raise ValueError('native FILL interrupt checkpoint/event schedule differs')
    if (fixture.get('initial_sp')!=0x3000 or fixture.get('opcode')!=(0x0fe0 if engine=='xy' else 0x0fc0) or
            fixture.get('states')!=(56 if engine=='xy' else 54) or fixture.get('cache_disabled') is not False or
            fixture.get('control')!=0 or fixture.get('expected_st')!=0xf0200810 or
            fixture.get('follow_pc')!=end+16*8):
        raise ValueError('native FILL state, mode, continuation or checkpoint metadata differs')
    wanted_setup=[(0xc0000150,16),(0xc0000160,0),(0xc0000140,23)]
    if interrupt=='lint1': wanted_setup.append((0xc0000110,2))
    if _freeze(fixture.get('setup_io'))!=_freeze(wanted_setup):
        raise ValueError('native FILL CPU-visible setup registers differ')
    expected_overrides={'b2':0x00010000 if engine=='xy' else 0x6100,
                        'b3':0x100,'b7':0x00080002,'b9':0x5cc3aa55,'sp':0x3000}
    if engine=='xy': expected_overrides['b4']=0x6000
    if fixture.get('register_overrides')!=expected_overrides:
        raise ValueError('native FILL literal CPU register-write setup differs')

    initial_regs={name:value for name,value in INIT_REGS}
    initial_regs.update(a3=0xf0200810,b2=0x00010000 if engine=='xy' else 0x6100,
                        b3=0x100,b7=0x00080002,b9=0x5cc3aa55,sp=0x3000)
    if engine=='xy': initial_regs['b4']=0x6000
    expected_regs=dict(initial_regs)
    expected_regs.update(a3=0xf0200810,b2=0x6820,b3=0x100,b7=0x00080002,b9=0x5cc3aa55)
    if engine=='xy': expected_regs['b4']=0x6000
    expected_regs['sp']=0x3000
    expected_extra={name:value for name,value in expected_regs.items() if name not in ('a0','a1','a2','a3')}
    for q in range(10,15): expected_extra.pop(f'b{q}',None)
    if (_freeze(fixture.get('initial_all_regs'))!=_freeze(initial_regs) or
            _freeze(fixture.get('expected_extra_regs'))!=_freeze(expected_extra) or
            _freeze(fixture.get('regs'))!=_freeze([expected_regs[f'a{q}'] for q in range(4)]) or
            _freeze(fixture.get('expected_regs'))!=_freeze([expected_regs[f'a{q}'] for q in range(4)])):
        raise ValueError('native FILL initialized or final register contract differs')
    if (fixture.get('expected_st')!=0xf0200810 or
            fixture.get('observe_all') is not True or fixture.get('observe_implicit') is not True):
        raise ValueError('native FILL final status/observation contract differs')
    conditions=dict(size=16,width=2,rows=8,words_per_row=2,xy=engine=='xy',
                    ppop=0,pmask=0,transparency=False,window=0,alignment='A')
    if _freeze(fixture.get('conditions'))!=_freeze(conditions):
        raise ValueError('native FILL condition domain differs')
    fill=dict(address=0x6100,pitch=0x100,words=2,rows=8,color=0xaa55)
    if _freeze(fixture.get('data_fill'))!=_freeze(fill):
        raise ValueError('native FILL pixel transaction parameters differ')
    init=dict(MEMORY_INITIAL_FILL); init.update(STACK_INITIAL)
    init.update({0x2fc0:0x0010,0x2fd0:0,0x2fe0:0x1070,0x2ff0:0})
    vector=0xffffffc0 if interrupt=='lint1' else 0xfffffee0
    other=0xfffffee0 if interrupt=='lint1' else 0xffffffc0
    init.update({vector:0x4000,vector+16:0})
    final=dict(init)
    for address,value in FILL_WRITES: final[address]=value
    saved_status=0xf220
    final.update({0x2fc0:0x0810,0x2fd0:saved_status,0x2fe0:end&0xffff,
                  0x2ff0:end>>16,vector:0x4000,vector+16:0})
    if (other in init or other+16 in init or _freeze(fixture.get('initial_memory'))!=_freeze(sorted(init.items())) or
            _freeze(fixture.get('expected_memory'))!=_freeze(sorted(final.items()))):
        raise ValueError('native FILL initial/final memory, PBX frame, vector or canary differs')
    if (fixture.get('data_fill',{}).get('color')!=0xaa55 or fixture.get('drain_instructions')!=12 or
            fixture.get('follow_pc')!=end+128):
        raise ValueError('native FILL observed continuation settings differ')
    return engine,interrupt


def _parse_bus(lines):
    requests=[]; accepts=[]; responses=[]; targets=[]; target_ends=[]
    for line in lines:
        f=line.split()
        if line.startswith('BUS_BEGIN '):
            requests.append(dict(clock=int(f[1]),we=int(f[2]),address=int(f[3],16),wdata=int(f[4],16),iaq=int(f[5])))
        elif line.startswith('BUS_ACCEPT '): accepts.append(int(f[1]))
        elif line.startswith('BUS_END '):
            responses.append(dict(clock=int(f[1]),we=int(f[2]),address=int(f[3],16),rdata=int(f[4],16)))
        elif line.startswith('TARGET_BEGIN '):
            targets.append(dict(clock=int(f[1]),we=int(f[2]),address=int(f[3],16),wdata=int(f[4],16),iaq=int(f[5])))
        elif line.startswith('TARGET_END '):
            target_ends.append(dict(clock=int(f[1]),we=int(f[2]),address=int(f[3],16),rdata=int(f[4],16)))
    return requests,accepts,responses,targets,target_ends


def check(entry,observed,lines):
    engine,interrupt=validate(entry)
    prefix=f'graphics FILL {engine}/{interrupt}: '
    errors=[]
    def reject(message): errors.append(prefix+message)
    if observed.get('clocks',0)<=0 or observed.get('end',0)-observed.get('start',0)!=observed.get('clocks'):
        reject('missing or inconsistent observed compound clock interval')
    memory_rows=[line.split() for line in lines if line.startswith('MEMORY ')]
    try: actual_memory={int(row[1],16):int(row[2],16) for row in memory_rows}
    except (ValueError,IndexError): actual_memory={};reject('malformed final memory snapshot')
    expected_memory=dict(entry['fixture']['expected_memory'])
    if len(actual_memory)!=len(memory_rows) or actual_memory!=expected_memory:
        reject('final fill memory, PBX stack frame, vector or canary mismatch')
    boundaries=[line for line in lines if line.startswith('IRQ_BOUNDARY ')]
    try:
        if len(boundaries)!=1: raise ValueError('count')
        boundary={k:int(v) for k,v in (item.split('=') for item in boundaries[0].split()[1:])}
        if set(boundary)!={'count','previous','complete','first'} or boundary['count']!=1:
            raise ValueError('fields')
        if not (observed['start']<=boundary['complete'] and boundary['previous']==0 and
                boundary['complete']<boundary['first']<=observed['end']): raise ValueError('order')
    except (ValueError,KeyError): reject('missing, duplicate or unordered in-flight context/first-ISR boundaries');boundary=None
    stimulus=[line.split() for line in lines if line.startswith('STIMULUS ')]
    event_after_writes=2 if engine=='xy' else 1
    if len(stimulus)!=2:
        reject(f'expected two applied interrupt/release events, observed {len(stimulus)}')
    else:
        wanted_first=(0,1,event_after_writes,1 if interrupt=='lint1' else 0x110)
        wanted_second=(1,1 if interrupt=='lint1' else 5,5 if interrupt=='lint1' else 1,0)
        if (tuple((int(stimulus[0][2]),int(stimulus[0][3]),int(stimulus[0][4],16),int(stimulus[0][5],16)))!=wanted_first or
                tuple((int(stimulus[1][2]),int(stimulus[1][3]),int(stimulus[1][4],16),int(stimulus[1][5],16)))!=wanted_second):
            reject('event did not follow the declared FILL word/row checkpoint and release schedule')
    if interrupt=='nmi':
        host_acks=[line.split() for line in lines if line.startswith('HOST_ACK ')]
        if len(host_acks)!=1: reject(f'expected one NMI host acknowledgement, observed {len(host_acks)}')
        elif stimulus and not (int(stimulus[0][1])<int(host_acks[0][1])<int(stimulus[1][1])):
            reject('NMI acknowledgement is not ordered between assertion and release')
        request_clock=int(host_acks[0][1]) if len(host_acks)==1 else None
    else: request_clock=int(stimulus[0][1]) if stimulus else None
    requests,accepts,responses,targets,target_ends=_parse_bus(lines)
    vector=0xffffffc0 if interrupt=='lint1' else 0xfffffee0
    fill_plan=list(FILL_WRITES)
    # TI permits destination-word boundaries and row ends. Accept any word
    # boundary after the trigger through the final unfinished word, subject to
    # the independent recognition bound below.
    data_requests=[r for r in requests if r['iaq']==0]
    first_frame=next((q for q,r in enumerate(data_requests)
                      if r['we']==1 and r['address']==0x2ff0),None)
    before=first_frame if first_frame is not None else -1
    minimum_before=event_after_writes
    if not minimum_before<=before<len(fill_plan):
        reject(f'FILL interruption must leave resumed pixel work; observed pre-context word count {before}')
        if before==len(fill_plan):
            reject(f'FILL request missed the 20-state word/row checkpoint bound: no eligible checkpoint before all {len(fill_plan)} destination words completed')
    expected_data=[(1,a,d) for a,d in fill_plan[:before]]
    stack=dict(entry['fixture']['expected_memory'])
    expected_data += [(1,a,stack[a]) for a in (0x2ff0,0x2fe0,0x2fd0,0x2fc0)]
    expected_data += [(0,vector,0x4000),(0,vector+16,0)]
    expected_data += [(0,a,stack[a]) for a in (0x2fc0,0x2fd0,0x2fe0,0x2ff0)]
    expected_data += [(1,a,d) for a,d in fill_plan[before:]]
    if not (len(requests)==len(accepts)==len(responses)==len(targets)==len(target_ends)):
        reject(f'BUS/TARGET request-ACK-response count differs: {len(requests)}/{len(accepts)}/{len(responses)}/{len(targets)}/{len(target_ends)}')
    matched=min(len(requests),len(accepts),len(responses),len(targets),len(target_ends))
    data_index=0
    for q in range(matched):
        r,ack,bus_end,t,tend=requests[q],accepts[q],responses[q],targets[q],target_ends[q]
        if q and r['clock']<responses[q-1]['clock']:
            reject(f'BUS transaction {q} overlaps or precedes the previous transfer response')
        if (r['we']!=bus_end['we'] or r['address']!=bus_end['address'] or not r['clock']<=ack<bus_end['clock']):
            reject(f'BUS transaction {q} request/ACK/response association differs')
        if (t['we'],t['address'],t['wdata'],t['iaq'])!=(r['we'],r['address'],r['wdata'],r['iaq']):
            reject(f'TARGET transaction {q} request association/data differs')
        if (tend['we'],tend['address'])!=(r['we'],r['address']) or tend['clock']-t['clock']!=4:
            reject(f'TARGET transaction {q} response/4-clock duration differs')
        if ack!=t['clock'] or not r['clock']<=t['clock']<tend['clock']<=bus_end['clock']:
            reject(f'TARGET transaction {q} ACK/containment differs')
        if r['iaq']==0:
            if data_index>=len(expected_data): reject(f'unexpected data BUS transaction {q}: {r}');continue
            we,address,value=expected_data[data_index]
            if (r['we'],r['address'])!=(we,address): reject(f'data transaction {data_index} order/kind/address differs: {r}')
            if we and r['wdata']!=value: reject(f'data transaction {data_index} write payload differs')
            if not we and (bus_end['rdata']!=value or tend['rdata']!=value): reject(f'data transaction {data_index} read response differs')
            data_index+=1
        elif r['iaq']==1 and r['we']==0:
            address=r['address']
            if 0x1000<=address<0x1000+16*len(entry['program_words']) and (address-0x1000)%16==0:
                want=entry['program_words'][(address-0x1000)//16]
            elif 0x4010<=address<=0x4030 and (address-0x4000)%16==0: want=0
            else: reject(f'instruction fetch outside literal image: {address:08x}');continue
            if bus_end['rdata']!=want or tend['rdata']!=want: reject(f'instruction fetch data differs at {address:08x}')
        else: reject(f'unsupported BUS transaction type at transaction {q}: {r}')
    if data_index!=len(expected_data): reject(f'expected {len(expected_data)} ordered data transactions, observed {data_index}')
    trigger_index=event_after_writes-1
    fill_indexes=[q for q,r in enumerate(requests) if r['iaq']==0 and r['we']==1 and
                  (r['address'],r['wdata']) in fill_plan]
    checkpoint_clock=None
    if len(fill_indexes)==len(fill_plan) and len(stimulus)==2 and minimum_before<=before<len(fill_plan):
        trigger_transfer=fill_indexes[trigger_index]
        checkpoint_transfer=fill_indexes[before-1]
        event_clock=int(stimulus[0][1])
        if not target_ends[trigger_transfer]['clock']<event_clock<responses[trigger_transfer]['clock']:
            reject('event is not applied after its declared FILL write count and before bus completion')
        fill_recognition=responses[checkpoint_transfer]['clock']-event_clock
        if not 0<=fill_recognition<=20*8+1:
            reject(f'FILL request to selected word/row checkpoint: expected 0..161 INCLK, observed {fill_recognition}')
        checkpoint_clock=responses[checkpoint_transfer]['clock']
    vector_indexes=[q for q,r in enumerate(requests) if r['iaq']==0 and r['address'] in (vector,vector+16)]
    if boundary is not None and len(vector_indexes)==2 and boundary['complete']<responses[vector_indexes[-1]]['clock']:
        reject('context completion precedes second vector read completion')
    if boundary is not None and request_clock is not None:
        entry_clocks=boundary['complete']-request_clock
        low,high=17*8-1,(20+22)*8+1
        if not low<=entry_clocks<=high:
            reject(f'FILL recognition plus context (TI §§13.3.4 and 8.5.1): expected {low}..{high} INCLK, observed {entry_clocks}')
        reti_clocks=boundary['first']-boundary['complete']
        if reti_clocks!=20*8:
            reject(f'cold aligned RETI: expected 160 INCLK (11 RETI + 9 cache-fill states), observed {reti_clocks}')
    return errors,dict(clocks=observed.get('clocks'),engine=engine,interrupt=interrupt,
                       boundary=boundary,bus_transfers=len(expected_data),
                       row_checkpoint=None if checkpoint_clock is None else checkpoint_clock-observed.get('start',0),
                       pre_context_fill_words=before,
                       fill_recognition=None if checkpoint_clock is None or request_clock is None else checkpoint_clock-request_clock)
