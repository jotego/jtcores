#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Independent CD MOVB following-load and HOLD observation contracts.

SPVU001A Table13-1: indirect CD byte load B6/F8; Tables13-2/4: absolute
store B7/F13 and plain copy B/B7, B/F13. Section13.1.1 charges an outstanding
write to the next bus-dependent work. The existing native observation policy
posts one whole final RMW, with H3+2W remaining at primary decode. A CD NOP
costs4+W, and requests its opcode at state1, overlapping one hidden state.
These placement/overlap choices are explicit project policies, not TI pin
waveforms. Literal durations and physical cycles remain independent checks.

Sections6.2,11.3 require indivisible RMW and fresh read after HOLD intervenes
between read and write. HOLD-adjusted total instruction duration is outside
this contract; bus durations, grant ownership and restart are mandatory.
"""
from collections import Counter
import byte_store_oracle
from copy_cases import transactions as copy_transactions
from store_cases import transactions as store_transactions


def primary_transfers(case):
    if 'data_copy' in case:
        return copy_transactions(case)
    return ([(0,case['test_pc']+16*(q+1),value,0)
             for q,value in enumerate(case['extensions'])],store_transactions(case))


def following_clocks(case,wait=0,pause=0):
    """End of dependent load, relative to the original store's start (INCLK)."""
    delay=case['byte_store_event']['delay']
    words=((case['data_store']['address']&15)+8+15)//16
    native=byte_store_oracle.supported(case)
    primary=byte_store_oracle.states(case) if native else 13  # plain B/F copy
    blocking=byte_store_oracle.wait_count(case) if native else 6
    hidden=3+2*wait if native else 0
    residual=hidden if delay==0 else max(0,hidden-1)
    load=6 if words==1 else 8
    return 8*(primary+blocking*wait+delay*(4+wait)+load+(words+1)*wait+residual)+pause+(-pause)%8


def transfer_plan(case):
    leading,writes=primary_transfers(case)
    spec=case['byte_store_event']
    if spec['kind']=='hold':
        return leading,writes,[],[(0,case['next_pc'],case['expected_next_opcode'],1)]
    image=dict(case['expected_memory']);address=case['data_store']['address']
    count=((address&15)+8+15)//16
    reads=[(0,(address&~15)+16*q,image[(address&~15)+16*q],0) for q in range(count)]
    opcodes=[(0,case['next_pc']+16*q,case['following_words'][q],1)
             for q in range(spec['delay']+2)]
    return leading,writes,reads,opcodes


def check_bus(case,observed,lines,wait,pause=0,*,raw=False,hold_edges=()):
    prefix='TARGET' if raw else 'BUS'
    begin=[s.split() for s in lines if s.startswith(prefix+'_BEGIN ')]
    end=[s.split() for s in lines if s.startswith(prefix+'_END ')]
    if len(begin)!=len(end):return [prefix+': unmatched physical transfers']
    leading,writes,reads,opcodes=transfer_plan(case)
    expected=Counter(leading+writes+reads+opcodes)
    actual=[];errors=[]
    hold=case['byte_store_event']['kind']=='hold'
    valid_hold=len(hold_edges)==2 and [v for clock,v in hold_edges]==[1,0]
    for q,(b,e) in enumerate(zip(begin,end)):
        kind,address,iaq=int(b[2]),int(b[3],16),int(b[5])
        value=int(b[4] if kind else e[4],16)
        actual.append((kind,address,value,iaq))
        if b[2:4]!=e[2:4]:errors.append(prefix+': physical response ownership mismatch')
        if iaq and address==case['next_pc'] and int(e[1])>observed.get('end',int(e[1])):
            errors.append(prefix+': primary decode preceded its opcode response')
        if int(e[1])-int(b[1])!=(4 if raw else 16)+8*wait:
            errors.append(prefix+': physical cycle duration mismatch')
        if q and int(b[1])<int(end[q-1][1]):errors.append(prefix+': overlapping physical cycles')
        if kind:
            if not q or actual[q-1][:2]!=(0,address) or actual[q-1][3]:
                errors.append(prefix+': split or missing RMW read')
            elif valid_hold:
                grant,release=(edge[0] for edge in hold_edges)
                if int(end[q-1][1])<=grant and release<=int(b[1]):
                    errors.append(prefix+': RMW write used a stale read across HOLD grant')
        if valid_hold and hold_edges[0][0]<=int(b[1])<hold_edges[1][0]:
            errors.append(prefix+': physical cycle launched during HOLD grant')
        if valid_hold and int(b[1])<hold_edges[0][0]<int(e[1]):
            errors.append(prefix+': HOLD granted before active physical cycle completed')
    inventory=Counter(actual);extra=inventory-expected
    restart_reads={t for t in writes if not t[0]}
    if expected-inventory or extra and (not hold or any(t not in restart_reads for t in extra)):
        errors.append(prefix+': complete transaction address/data/kind/IAQ inventory mismatch')
    if actual[:len(leading)]!=leading:errors.append(prefix+': operand/source ordering mismatch')
    if [t for t in actual if t[0]]!=[t for t in writes if t[0]]:
        errors.append(prefix+': field write order or payload mismatch')
    if [t for t in actual if t[3]]!=opcodes:errors.append(prefix+': instruction fetch order or payload mismatch')
    if hold and extra:
        # A repeated read requires an earlier read of the same word before
        # the grant and a replacement after release. Arbitrary duplicates fail.
        for transaction,count in extra.items():
            indices=[q for q,t in enumerate(actual) if t==transaction]
            if not valid_hold or count!=1 or len(indices)!=2 or not (
                    int(end[indices[0]][1])<=hold_edges[0][0]
                    and int(begin[indices[1]][1])>=hold_edges[1][0]):
                errors.append(prefix+': repeated RMW read without one intervening HOLD grant')
    if reads:
        write_indices=[q for q,t in enumerate(actual) if t[0]]
        read_indices=[q for q,t in enumerate(actual) if not t[0] and not t[3]
                      and q>(write_indices[-1] if write_indices else len(actual))]
        following=[actual[q] for q in read_indices]
        if following!=reads:errors.append(prefix+': dependent data read before completed field write')
        opcode_indices=[q for q,t in enumerate(actual) if t[3]]
        delay=case['byte_store_event']['delay']
        if (len(opcode_indices)==delay+2 and read_indices and not
                (opcode_indices[delay]<read_indices[0]<=read_indices[-1]<opcode_indices[delay+1])):
            errors.append(prefix+': dependent read lies outside load opcode/next opcode ordering')
    if raw:
        logical=[s.split() for s in lines if s.startswith('BUS_BEGIN ')]
        if len(logical)!=len(begin):errors.append(prefix+': missing logical allocations')
        else:
            for b,t in zip(logical,begin):
                if not int(b[1])<=int(t[1])<=int(b[1])+6:
                    errors.append(prefix+': target dispatch outside physical readiness window')
    elif not hold:
        alignment=pause+(-pause)%8
        for b in begin:
            if int(b[1])<observed['start']+alignment or (int(b[1])-observed['start']-alignment)%8:
                errors.append(prefix+': physical allocation outside machine-state grid')
    return errors


def check_observation(case,observed,log,wait,pause=0):
    """Transport-independent observations use existing timing bench labels."""
    errors=[];row=dict(errors=errors)
    traces={prefix:[s for s in log.splitlines() if s.startswith(prefix+'_')
                   and int(s.split()[1])>=observed['start']
                   and not (s.startswith(prefix+'_END ') and int(s.split()[1])==observed['start'])]
            for prefix in ('BUS','TARGET')}
    row.update(bus_trace=traces['BUS'],target_trace=traces['TARGET'])
    memory=[(int(s.split()[1],16),int(s.split()[2],16)) for s in log.splitlines() if s.startswith('MEMORY ')]
    row['observed_memory']=memory
    if sorted(memory)!=sorted(map(tuple,case['expected_memory'])):errors.append('drained byte-store memory mismatch')
    hold_edges=[(int(s.split()[1]),int(s.split()[2])) for s in log.splitlines() if s.startswith('HOLD_ACK ')]
    row['hold_edges']=hold_edges
    summaries=[s for s in log.splitlines() if s.startswith('EXTERNAL_RESULT ')]
    if len(summaries)==1:
        # Behavioral-reference counters are actual observations. The FPGA
        # adapter supplies the same fields from its returned result words.
        external={k:int(v) for k,v in (item.split('=') for item in summaries[0].split()[1:])}
        external.update(events=[],hold_edges=[],host_clocks=[])
        for line in log.splitlines():
            fields=line.split()
            if not fields:continue
            if fields[0]=='STIMULUS':
                external['events'].append([int(fields[1])-observed['start'],int(fields[2]),
                    int(fields[3]),int(fields[4],16),int(fields[5],16)])
            elif fields[0]=='HOLD_ACK':
                external['hold_edges'].append([int(fields[1])-observed['start'],int(fields[2])])
            elif fields[0]=='HOST_ACK':
                external['host_clocks'].append(int(fields[1])-observed['start'])
        row['external_observation']=external
    hold=case['byte_store_event']['kind']=='hold'
    if hold:
        if len(hold_edges)!=2 or [v for clock,v in hold_edges]!=[1,0] or hold_edges[1][0]-hold_edges[0][0]<3:
            errors.append('missing or invalid HOLD grant/release')
        opcodes=[int(s.split()[1],16) for s in log.splitlines() if s.startswith('NEXT_OPCODE ')]
        row['observed_next_opcodes']=opcodes
        if opcodes!=[case['expected_next_opcode']]:errors.append('byte-store next opcode mismatch')
    else:
        if hold_edges:errors.append('unexpected HOLD grant in following-load case')
        follow=[s for s in log.splitlines() if s.startswith('FOLLOW ')]
        extra=[s for s in log.splitlines() if s.startswith('FOLLOW_EXTRA ')]
        if len(follow)!=1 or len(extra)!=1:errors.append('missing or duplicate following-load snapshot')
        else:
            actual={k:int(v,10 if k=='clock' else 16) for line in follow+extra
                    for k,v in (item.split('=') for item in line.split()[1:])}
            row['observed_follow']=actual
            if any(s.startswith(prefix+'_END ') and int(s.split()[1])>actual.get('clock',0)
                   for prefix in ('BUS','TARGET') for s in traces[prefix]):
                errors.append('following snapshot preceded completed physical work')
            clocks=following_clocks(case,wait,pause)
            if actual.get('clock',0)-observed['start']!=clocks:
                errors.append(f'following dependent load: expected {clocks} INCLK, observed {actual.get("clock",0)-observed["start"]} INCLK')
            for q,value in enumerate(case['expected_follow_regs']):
                if actual.get(f'a{q}')!=value:errors.append(f'following load A{q} result mismatch')
            if actual.get('st')!=case['expected_follow_st']:errors.append('following load ST result mismatch')
            for name,value in case['expected_follow_extra_regs'].items():
                if actual.get(name)!=value:errors.append('following load '+name.upper()+' result mismatch')
    errors+=check_bus(case,observed,traces['BUS'],wait,pause,hold_edges=hold_edges)
    errors+=check_bus(case,observed,traces['TARGET']+traces['BUS'],wait,pause,raw=True,hold_edges=hold_edges)
    return row
