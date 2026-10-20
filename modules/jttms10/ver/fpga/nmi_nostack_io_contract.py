# SPDX-License-Identifier: GPL-3.0-or-later
"""Strict CPU-visible I/O preservation contract for NMIM=1 runtime cases."""
from nmi_nostack_io_cases import IO_READS

KEYS={'kind','handler_warm','sp_offset','interrupt_enable','assert_clock'}
STATIC_SETUP=[[a,v] for a,v,_ in IO_READS[:6]]

def _movi(value,register):
    return [0x09e0|register,value&0xffff,(value>>16)&0xffff]

def _literal_program(spec,status,sp):
    """Build the bounded literal program independently of the fixture producer."""
    words=_movi(0x4000,4)+_movi(0x4050,5)+[0x0300]*10
    # Disable display/refresh, then initialize each selected implemented I/O
    # register with an ordinary CPU word store before the host event.
    words+=_movi(0xc00000b0,14)+_movi(0x18,13)+[0x0550,0x81ae]
    for address,value in STATIC_SETUP:
        words+=_movi(address,14)+_movi(value,13)+[0x0550,0x81ae]
    loop_index=len(words)
    for reg,value in enumerate((0x80000003,0x11223344,2,status)):
        words+=_movi(value,reg)
    words+=_movi(sp,15)+_movi(0x18,13)+_movi(0xc00000b0,14)+[0x01a3]+[0x0300]*12
    test_pc=0x1000+16*len(words)
    words += [0x0300]+[0x0300]*12+[0xc0d6]
    if spec['handler_warm']:
        # Warm 4000 through A4, then return through the initialized A5 target.
        words[loop_index:loop_index]=_movi(0x14f0,5)+_movi(0x4000,4)+[0x0164]+_movi(0x4050,5)
        test_pc+=16*10
    if len(words)>768: raise ValueError('NMI I/O pre-handler program exceeds vector boundary')
    words += [0x0300]*(768-len(words))
    words += _movi(0x12345678,0)+[0x0165,0x0300]
    for address,_,destination in IO_READS:
        words += _movi(address,14)+[0x0550,0x8400|(14<<5)|destination]
    words += [0x0300,0x0300,0x0300,0xc0ff]
    return words,test_pc,test_pc+16

def validate(entry):
    s=entry.get('external_contract',{})
    if (set(s)!=KEYS or s.get('kind')!='scalar_nmi_nostack_io' or
        type(s.get('handler_warm')) is not bool or type(s.get('interrupt_enable')) is not bool or
        type(s.get('sp_offset')) is not int or not 0<=s['sp_offset']<=15 or
        type(s.get('assert_clock')) is not int or not 16<=s['assert_clock']<=23):
        raise ValueError('unsupported no-stack NMI I/O contract')
    c=entry.get('fixture',{}); sp=0x3000+s['sp_offset']
    status=0xd0000810|(0x00200000 if s['interrupt_enable'] else 0)
    base_name=f"nmi_nostack_io_ie{int(s['interrupt_enable'])}_w{entry.get('stimulus',{}).get('wait_states')}_{'warm' if s['handler_warm'] else 'cold'}_sp{s['sp_offset']}"
    if entry.get('name') not in (base_name,base_name+f"_assert{s['assert_clock']}") or c.get('name')!=entry.get('name'):
        raise ValueError('NMI I/O fixture/result name association differs')
    expected=dict(opcode=0x0300,states=1,cache_disabled=False,initial_sp=sp,
        regs=[0x80000003,0x11223344,2,status],expected_regs=[0x80000003,0x11223344,2,status],
        expected_st=status,expected_extra_regs=dict(sp=sp,a4=0x4000,a5=0x4050,a13=0x18,a14=0xc00000b0),
        observe_all=True,observe_implicit=True,setup_io=STATIC_SETUP,drain_instructions=48,
        follow_pc=0x4290)
    if any(c.get(k)!=v for k,v in expected.items()) or c.get('conditions',{}).get('intenb')!=0 or c.get('conditions',{}).get('nmim')!=1:
        raise ValueError('NMI I/O initialization or expected state differs from contract')
    if c.get('measure_pass',1)!=1 or entry.get('test_pc')!=c.get('test_pc') or entry.get('next_pc')!=c.get('next_pc'):
        raise ValueError('NMI I/O measurement pass/program association differs')
    memory={a:0xa5a5 for a in range((sp-64)&~15,((sp+31)&~15)+16,16)}
    memory.update({0xfffffee0:0x4000,0xfffffef0:0})
    if len(c.get('initial_memory',[]))!=len(memory) or dict(c['initial_memory'])!=memory:
        raise ValueError('NMI I/O stack guards or vector initialization differs')
    if c.get('next_pc')!=c.get('test_pc',-16)+16: raise ValueError('NMI I/O measured NOP differs')
    words,test_pc,next_pc=_literal_program(s,status,sp)
    if (entry.get('program_words')!=words or len(words)!=812 or c.get('test_pc')!=test_pc or
        c.get('next_pc')!=next_pc or entry.get('test_pc')!=test_pc or entry.get('next_pc')!=next_pc):
        raise ValueError('NMI I/O complete literal program/setup/warmup/NOP/handler image differs')
    wanted_events=[dict(trigger=0,argument=s['assert_clock'],control=0x310),dict(trigger=5,argument=1,control=0)]
    stim=entry.get('stimulus',{})
    if (entry.get('external_events')!=wanted_events or type(stim.get('wait_states')) is not int or
        stim.get('wait_states') not in (0,1,3) or stim.get('pause_clocks',0) or stim.get('pause_after_clocks',0)):
        raise ValueError('NMI I/O event/wait schedule differs')
    return s,sp,status

def check(entry,observed,lines):
    spec,sp,status=validate(entry); errors=[]
    def reject(msg): errors.append('no-stack NMI I/O: '+msg)
    follow={}
    for label in ('FOLLOW','FOLLOW_EXTRA','FOLLOW_ALL'):
        rows=[x.split() for x in lines if x.startswith(label+' ')]
        if len(rows)!=1: reject('expected exactly one '+label+' observation'); continue
        try: follow.update({k:int(v,10 if k=='clock' else 16) for k,v in (x.split('=') for x in rows[0][1:])})
        except ValueError: reject('malformed '+label+' observation')
    expected=[0x12345678,0x11223344,2,status,0x4000,0x4050,0x18,1,0x1b,0x14,0x10,0x2a5a,0x200]
    for q,value in enumerate(expected):
        got=follow.get(f'a{q}')
        matches=(got is not None and got&0x0300==0x0200) if q==12 else got==value
        if not matches: reject(f'ISR A{q} expected {value:08x}, got {got}')
    if (follow.get('st')!=0x10 or follow.get('sp')!=sp or follow.get('a13')!=0x18 or
        follow.get('a14')!=0xc0000100): reject('ISR status, stack or preserved pointer differs')
    memrows=[x.split() for x in lines if x.startswith('MEMORY ')]
    try: memory={int(x[1],16):int(x[2],16) for x in memrows}
    except (ValueError,IndexError): memory={}; reject('malformed memory observation')
    if len(memory)!=len(memrows) or memory!=dict(entry['fixture']['initial_memory']): reject('stack guards/vector changed')
    waits=entry['stimulus']['wait_states']; duration=16+8*waits; tduration=4+8*waits
    plan=[(0xfffffee0,0x4000,0),(0xfffffef0,0,0)]
    if not spec['handler_warm']: plan += [(0x4000+16*q,x,1) for q,x in enumerate((0x09e0,0x5678,0x1234,0x0165))]
    # 4040 is the aligned instruction-cache line containing the ISR entry at
    # 4050. Every bus word fetch is listed once, in its actual execution order.
    for a in range(0x4040,0x42c0,0x10):
        i=(a-0x1000)//16
        plan.append((a,entry['program_words'][i],1))
    bb=[x.split() for x in lines if x.startswith('BUS_BEGIN ')]; be=[x.split() for x in lines if x.startswith('BUS_END ')]
    tb=[x.split() for x in lines if x.startswith('TARGET_BEGIN ')]; te=[x.split() for x in lines if x.startswith('TARGET_END ')]
    acks=[int(x.split()[1]) for x in lines if x.startswith('BUS_ACCEPT ')]
    eb=[x for x in bb if int(x[2])==0]; ee=[x for x in be if int(x[2])==0]
    if not (len(eb)==len(ee)==len(tb)==len(te)==len(plan)): reject('external vector/ISR fetch count differs from complete declared plan')
    for q,((a,d,iaq),b,e,b2,e2) in enumerate(zip(plan,eb,ee,tb,te)):
        try:
            t=int(b[1]); end=int(e[1])
            if (int(b[3],16),int(b[5]),int(e[3],16),int(e[4],16))!=(a,iaq,a,d): reject(f'external fetch {q} raw address/data/order differs')
            observed_duration=end-t; ack_count=sum(t<=x<end for x in acks)
            if observed_duration!=duration or ack_count!=1:
                reject(f'external fetch {q} BUS duration expected {duration} INCLK, observed {observed_duration} INCLK; ACK count expected 1, observed {ack_count}')
            actual_target=(int(b2[2]),int(b2[3],16),int(b2[5]),int(e2[2]),int(e2[3],16),int(e2[4],16))
            observed_target_duration=int(e2[1])-int(b2[1])
            if actual_target!=(0,a,iaq,0,a,d): reject(f'target fetch {q} data differs')
            if observed_target_duration!=tduration:
                reject(f'target fetch {q} duration expected {tduration} INCLK, observed {observed_target_duration} INCLK')
            if not t<=int(b2[1])<int(e2[1])<=end: reject(f'target fetch {q} is outside its BUS transfer')
        except (ValueError,IndexError): reject('malformed external fetch transaction')
    ib=[x for x in bb if int(x[2])==5]; ie=[x for x in be if int(x[2])==5]
    if len(ib)!=7 or len(ie)!=7: reject(f'expected seven CPU I/O reads, observed {len(ib)}/{len(ie)}')
    for q,((a,value,dest),b,e) in enumerate(zip(IO_READS,ib,ie)):
        try:
            t=int(b[1]); end=int(e[1]); data=int(e[4],16); opcode=0x8400|(14<<5)|dest
            if (int(b[3],16),int(b[5]),int(e[3],16))!=(a,0,a): reject(f'I/O read {q} raw address/order differs')
            if value is not None and data!=value: reject(f'I/O read {q} data expected {value:04x}, got {data:04x}')
            if value is None and data&0x0300!=0x0200: reject(f'HSTCTLH NMI/NMIM bits differ: {data:04x}')
            observed_duration=end-t; ack_count=sum(t<=x<end for x in acks)
            if observed_duration!=16 or ack_count!=1:
                reject(f'I/O read {q} duration expected 16 INCLK, observed {observed_duration} INCLK; ACK count expected 1, observed {ack_count}')
        except (ValueError,IndexError): reject('malformed CPU I/O read')
    if len(bb)!=len(plan)+7 or len(be)!=len(plan)+7: reject('unexpected bus activity beyond vectors, complete handler, and seven reads')
    if len(acks)!=len(plan)+7: reject('unexpected or missing bus acceptance outside complete declared plan')
    # Do not assign a golden position to speculative instruction prefetches.
    # Require each explicit MOVE opcode fetch to precede its read, preserve
    # ordered reads, and exclude overlap or unclassified bus traffic.
    move_fetches=[0x4090,0x40e0,0x4130,0x4180,0x41d0,0x4220,0x4270]
    try:
        ordered=[(int(b[1]),int(e[1])) for b,e in zip(bb,be)]
        if any(begin>finish for begin,finish in ordered) or any(next_begin<previous_end for (previous_begin,previous_end),(next_begin,next_end) in zip(ordered,ordered[1:])):
            reject('combined bus transactions overlap or are out of order')
        for q,(begin,end) in enumerate(zip(ib,ie)):
            opcode_end=next(int(row[1]) for row in ee if int(row[3],16)==move_fetches[q])
            if int(begin[1])<opcode_end: reject(f'I/O read {q} precedes its MOVE instruction fetch')
    except (ValueError,StopIteration,IndexError): reject('cannot associate I/O read with its MOVE instruction fetch')
    br=[x for x in lines if x.startswith('IRQ_BOUNDARY ')]
    try:
        if observed.get('protocol_version')!=5 or len(br)!=1: raise ValueError()
        boundary={k:int(v) for k,v in (x.split('=') for x in br[0].split()[1:])}
        if set(boundary)!={'count','previous','complete','first'} or boundary['count']!=1 or not observed['end']<=boundary['previous']<boundary['complete']<boundary['first']: raise ValueError()
        vector_end=next(int(e[1]) for e in ee if int(e[3],16)==0xfffffef0)
        if vector_end>boundary['complete']: reject('context completes before second vector read completes')
        if not spec['handler_warm']:
            cold_fill_end=max(int(e[1]) for e in ee if int(e[3],16) in (0x4000,0x4010,0x4020,0x4030))
            if cold_fill_end>boundary['first']: reject('first ISR MOVI retires before cold handler fill completes')
        host=[int(x.split()[1]) for x in lines if x.startswith('HOST_ACK ')]
        if len(host)!=1:
            reject(f'HOST_ACK count expected 1, observed {len(host)}; recognition latency expected 7..17 INCLK, observed unavailable')
        else:
            recognition=boundary['previous']-host[0]
            if not 7<=recognition<=17:
                reject(f'recognition latency expected 7..17 INCLK, observed {recognition} INCLK')
        first=8*(3+(0 if spec['handler_warm'] else 9+4*waits))
        observed_first=boundary['first']-boundary['complete']
        if observed_first!=first:
            reject(f'first ISR MOVI duration expected {first} INCLK, observed {observed_first} INCLK')
        if follow.get('clock',0)<boundary['first']: reject('follow-up observation precedes first ISR MOVI')
        if any(int(b[1])<boundary['first'] or int(e[1])>follow.get('clock',0) for b,e in zip(ib,ie)):
            reject('CPU I/O reads are outside first-ISR/follow-up bounds')
    except (ValueError,KeyError,StopIteration,IndexError): boundary=None; reject('missing/malformed/out-of-order NMI boundaries')
    traces={}
    for label in ('BUS_BEGIN','BUS_ACCEPT','BUS_END','TARGET_BEGIN','TARGET_END'):
        rows=[]
        for x in lines:
            if x.startswith(label+' '):
                p=x.split(); p[1]=str(int(p[1])-observed['start']); rows.append(' '.join(p))
        traces[label]=rows
    normalized_boundary=None if boundary is None else {k:(v if k=='count' else v-observed['start']) for k,v in boundary.items()}
    if 'clock' in follow: follow['clock']-=observed['start']
    semantic_follow={k:v for k,v in follow.items() if k=='clock' or k in ('st','sp') or
                     any(k==f'a{q}' for q in range(15))}
    return errors,dict(follow=semantic_follow,memory=[list(x) for x in sorted(memory.items())],traces=traces,
        boundary=normalized_boundary,
        io_reads=[dict(address=f'0x{a:08x}',value=f'0x{int(e[4],16):04x}') for (a,_,_),e in zip(IO_READS,ie)],
        host_readback_contract='CPU-visible HSTCTLH; physical host polling unsupported',
        context_duration_contract='not separately specified for NMIM=1; observed only')
