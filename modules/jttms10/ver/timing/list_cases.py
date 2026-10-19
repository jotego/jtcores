#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Independent register-list semantics and bus plans, TI SPVU001A12-109..112."""
from itertools import product
from load_cases import extract
from oracle import load_states
from store_cases import insert, transactions as store_transactions
MASK32=(1<<32)-1


def fixture(load,off,offset,selected,*,bank=0,pointer=3,status=0x70200810,seed=0x13579B00,alignment=0,tag='base',address=None,initial_words=None,initial_values=None):
    selected=sorted(selected)
    if len(set(selected))!=len(selected) or any(q not in range(16) for q in selected) or pointer in selected:
        raise ValueError('undefined register-list pointer alias or invalid list')
    ptr=((0x5400 if not load else 0x5000)+offset if address is None else address)&MASK32
    offset=ptr&15;count=len(selected)
    mask=sum(1<<(q if load else 15-q) for q in selected)
    registers={f'a{q}':(seed+q)&MASK32 for q in range(15)}
    registers.update({f'b{q}':(seed+16+q)&MASK32 for q in range(15)});registers['sp']=(seed+15)&MASK32
    registers.update(initial_values or {})
    name=lambda q:'sp' if q==15 else f'{"b" if bank else "a"}{q}'
    holder=4 if bank==0 and pointer==3 else 3
    registers[f'a{holder}']=status;registers[name(pointer)]=ptr
    expected=dict(registers);memory={};fields=[];order=sorted(selected,reverse=load)
    for i,q in enumerate(order):
        a=(ptr+32*i if load else ptr-32*(i+1))&MASK32
        fields.append(dict(address=a,width=32,value=registers[name(q)]))
        for bit in range(-16,48):
            word=((a+bit)&MASK32)&~15
            memory[word]=0x96A5^((word>>4)&0xFFFF)
    # Preserve boot vector if a wrapped stack spans it; then model data literally.
    for a,v in ((0xFFFFFFE0,0x1000),(0xFFFFFFF0,0)):
        if a in memory:memory[a]=v
    memory.update(initial_words or {})
    memory=sorted(memory.items());final=memory
    for q,field in zip(order,fields):
        if load:expected[name(q)]=extract(memory,field['address'],32,False)
        else:final=insert(final,field['address'],32,field['value'])
    expected[name(pointer)]=(ptr+(32*count if load else -32*count))&MASK32
    cpu=(3+(6 if offset else 4)*count) if load else 2+(10 if offset else 4)*count
    cd=(13+6*count if offset else 11+4*count) if load else 10+(10 if offset else 4)*count
    row=dict(name=f'{"mmfm" if load else "mmtm"}_{tag}_b{bank}_p{pointer}_m{mask:04x}_o{offset}_a{alignment}_{"off" if off else "hit"}',
        coverage_id='MMFM' if load else 'MMTM',opcode=(0x09A0 if load else 0x0980)|(bank<<4)|pointer,extensions=[mask],
        regs=[registers[f'a{q}'] for q in range(4)],expected_regs=[expected[f'a{q}'] for q in range(4)],
        expected_extra_regs={k:v for k,v in expected.items() if k not in ('a0','a1','a2','a3')},
        initial_all_regs=registers,expected_st=status if load else (status&0x7FFFFFFF)|((~(ptr>>31)&1)<<31),cache_disabled=off,
        states=cd if off else cpu,observe_all=True,instruction_word_offset=alignment,initial_memory=memory,expected_memory=final,
        data_list=dict(load=load,selected=selected,pointer=pointer,bank=bank,address=ptr,fields=fields,cpu=cpu,cd=cd),
        seed=seed,register_overrides=initial_values or {},status_holder=holder,hidden_states=0 if load or not count else 8 if offset else 2,drain_instructions=-1 if load or off else -2,
        citation='SPVU001A12-109..112',conditions=dict(registers=selected,count=count,bank=bank,pointer=pointer,alignment=offset,initial_pointer=ptr,status=status,opcode_offset=alignment))

    # Parenthesized hidden states are retained literally. MMFM has no
    # writes under its operation definition; §13.1.1 defines hidden work as
    # writes. The owner's fallback selects read-only behavior, CPU/CD intact.
    printed_hidden=(4 if offset else 2) if load else (8 if offset else 2)
    row['source_values']=dict(entry_cpu=cpu,entry_cd=cd,policy_cpu=cpu,policy_cd=cd,
        entry_hidden=printed_hidden,policy_hidden=row['hidden_states'])
    if printed_hidden!=row['hidden_states']:
        row['timing_source_status']='inferred-conflict-resolution'
        row['source_notes']='Owner fallback: read-only MMFM / no data work for an empty list; literal CPU/CD equations and printed hidden alternative retained. No official TI erratum.'
    return row



def program(case,movi):
    words=movi(0xC00000B0,14)+movi(0x8018 if case['cache_disabled'] else 0x18,13)+[0x0550,0x81AE]
    loop=0x1000+16*len(words);words+=movi(case['seed'],0)
    for q in range(1,16):words += [0x4C00|q,0x1000|(q<<5)|q]
    for q in range(15):words += [0x4E00|q,0x1000|((16+q)<<5)|0x10|q]
    for name,value in case['register_overrides'].items():
        q=15 if name=='sp' else int(name[1:])+(16 if name.startswith('b') else 0)
        words+=movi(value,q)
    spec=case['data_list'];q=spec['pointer'];reg=(16 if spec['bank'] and q!=15 else 0)+q
    words+=movi(spec['address'],reg)+movi(case['initial_all_regs'][f'a{case["status_holder"]}'],case['status_holder'])
    words+=[0x01A0|case['status_holder']]+[0x0300]*12
    while len(words)%4!=case['instruction_word_offset']:words.append(0x0300)
    start=0x1000+16*len(words);words+=[case['opcode'],*case['extensions']];next_pc=0x1000+16*len(words)
    if 'list_follow' in case:
        follow=case['list_follow'];words+=[0x0300]*follow['delay']+[follow['opcode']]
        case['follow_pc']=next_pc+16*(follow['delay']+1)
    words+=[0x0300]*4+[0xC080,loop&0xFFFF,loop>>16]
    if len(words)>128:raise ValueError('register-list fixture exceeds four warm cache segments')
    if len(case['initial_memory'])>64:raise ValueError('register-list sparse input limit64')
    return words,start,next_pc


def transfers(case):
    spec=case['data_list'];plan=[]
    image=dict(case['initial_memory'])
    for field in spec['fields']:
        if spec['load']:
            a=field['address'];plan += [(0,((a&~15)+16*q)&MASK32,image[((a&~15)+16*q)&MASK32],0) for q in range(2+bool(a&15))]
        else:plan+=store_transactions(dict(data_store=field,initial_memory=case['initial_memory'],expected_memory=case['expected_memory']))
    return plan


def wait_count(case):
    spec=case['data_list'];plan=transfers(case)
    if spec['load'] or case['cache_disabled']:return len(plan)
    if not spec['fields']:return 0
    return len(plan)-(5 if spec['address']&15 else 2)


def check_bus(case,observed,lines,wait,pause,*,raw=False):
    spec=case['data_list'];prefix='TARGET' if raw else 'BUS'
    begin=[x.split() for x in lines if x.startswith(prefix+'_BEGIN ')];end=[x.split() for x in lines if x.startswith(prefix+'_END ')]
    plan=transfers(case);offsets=[];off=case['cache_disabled'];unaligned=bool(spec['address']&15);n=len(spec['selected'])
    if spec['load']:first=(5 if off else 2);stride=6 if unaligned else 4;per=3 if unaligned else 2
    else:first=(7 if off else 10 if unaligned else 4);stride=10 if unaligned else 4;per=5 if unaligned else 2
    for q in range(len(plan)):offsets.append(first+(q//per)*stride+(q%per)*2+q*wait+int(off)*wait)
    if 'list_follow' in case:
        follow=case['list_follow'];a=follow['address'];image=dict(case['expected_memory'])
        first=max(spec['cpu']+wait_count(case)*wait+follow['delay'], offsets[-1]+2+wait if offsets else 0)
        for q in range(1+bool(a&15)):
            offsets.append(first+q*(2+wait));word=((a&~15)+16*q)&MASK32
            plan.append((0,word,image[word],0))
    if off:
        plan.insert(0,(0,case['test_pc']+16,case['extensions'][0],0));offsets.insert(0,1)
        offsets.append(case['states']-3+(len(plan))*wait);plan.append((0,case['next_pc'],0x0300,1))
    if len(begin)!=len(plan) or len(end)!=len(plan):return [f'expected {len(plan)} {prefix} list transfers, observed {len(begin)} starts/{len(end)} completions']
    errors=[]
    for i,((kind,a,data,iaq),offset,b,e) in enumerate(zip(plan,offsets,begin,end)):
        start=observed['start']+8*offset+pause+(-pause)%8;clock=int(b[1]);duration=int(e[1])-clock
        if case.get('response_pause_clocks'):
            logical=[x.split() for x in lines if x.startswith('BUS_BEGIN ')]
            if raw and len(logical)!=len(plan):return ['missing logical register-list event allocations']
            actual=int(logical[i][1]) if raw else clock
            # An issued field runs independently through a CPU pause. Later
            # fields may wait for resume; never invent an exact TI CEN count.
            if not start<=actual<=start+case['response_pause_clocks']+8 or (actual-observed['start'])%8:
                errors.append('list event allocation outside grid/bounded interval')
            if i%per and actual!=int((logical if raw else begin)[i-1][1])+16+8*wait:
                errors.append('list field words are not consecutive during CPU pause')
            start=actual

        if not (start<=clock<=start+6 if raw else clock==start):errors.append(f'{prefix} list transfer{i} start: expected {start}'+('..'+str(start+6) if raw else '')+f', observed {clock}')
        if (int(b[2]),int(b[3],16),int(b[5]))!=(kind,a,iaq):errors.append(f'{prefix} list transfer{i} kind/address/IAQ mismatch')
        if kind and int(b[4],16)!=data:errors.append(f'{prefix} list transfer{i} write data mismatch')
        if e[2:4]!=b[2:4] or not kind and int(e[4],16)!=data:errors.append(f'{prefix} list transfer{i} response mismatch')
        if duration!=(4 if raw else 16)+8*wait:errors.append(f'{prefix} list transfer{i} duration mismatch')
        if i and clock<int(end[i-1][1]):errors.append(f'{prefix} list transactions overlap/out of order')
    return errors


def following(case,delay):
    """An actual load through the final Rp, after cached independent work."""
    spec=case['data_list'];bank=spec['bank'];pointer=spec['pointer'];dest=1 if pointer==0 else 0
    key='sp' if pointer==15 else f'{"b" if bank else "a"}{pointer}'
    address=case['expected_extra_regs'].get(key,case['expected_regs'][pointer] if not bank and pointer<4 else 0)
    image=case['expected_memory'];value=extract(image,address,16,False)
    case['list_follow']=dict(delay=delay,address=address,opcode=0x8400|(pointer<<5)|(bank<<4)|dest,states=load_states(address=address,width=16,signed=False),transfers=1+bool(address&15))
    case['expected_follow_regs']=list(case['expected_regs']);case['expected_follow_extra_regs']=dict(case['expected_extra_regs'])
    if bank:case['expected_follow_extra_regs'][f'b{dest}']=value
    else:case['expected_follow_regs'][dest]=value
    case['expected_follow_st']=(case['expected_st']&~0xB0000000)|(0x20000000 if value==0 else 0)
    case['drain_instructions']=delay+2
    return case


def list_cases():
    # All lengths and bit alignments, both banks/cache modes. Rp is excluded
    # as required by the guide's explicit unpredictable-behavior warning.
    for load,off,bank,offset,n in product((False,True),(False,True),(0,1),range(16),range(16)):
        selected=[q for q in range(16) if q!=3][:n]
        yield fixture(load,off,offset,selected,bank=bank,tag=f'length{n}')
    # Every register position, both shared-SP and extreme pointer identities.
    for load,off,bank,pointer,q in product((False,True),(False,True),(0,1),(0,14,15),range(16)):
        if pointer!=q:yield fixture(load,off,(q+pointer)&15,(q,),bank=bank,pointer=pointer,tag=f'single{q}')
    for load,off,offset,flags,ie in product((False,True),(False,True),(0,15),range(16),(0,1)):
        yield fixture(load,off,offset,(0,2,14,15),status=(flags<<28)|(ie<<21)|0x810,tag=f'flags{flags}_ie{ie}')
    for load,off,field,width,fe in product((False,True),(False,True),(0,1),range(1,33),(0,1)):
        status=(0xF2200810&~(63<<(6*field)))|(((width&31)|(fe<<5))<<(6*field))
        yield fixture(load,off,15,(0,2,14,15),status=status,tag=f'ignored_f{field}_w{width}_fe{fe}')
    for load,off,offset,alignment in product((False,True),(False,True),(0,15),range(4)):
        yield fixture(load,off,offset,(0,2,14,15),alignment=alignment,tag='phase')
    for load,off,address in product((False,True),(False,True),(0,1,8,0x80000000,0x8000000F,0xFFFFFFF0,0xFFFFFFFF)):
        yield fixture(load,off,address&15,(0,2,14,15),address=address,tag=f'address_{address:08x}')
    # Sparse/dense masks and value patterns vary independently of length.
    for load,off,bank,seed in product((False,True),(False,True),(0,1),(0,0xFFFFFFFF,0x55555555,0xAAAAAAAA)):
        for mask in (0xAAAA,0x5555,0x8001,0x1E0,0x4010,0xFFF7):
            selected=[q for q in range(16) if mask&(1<<q) and q!=3]
            yield fixture(load,off,(seed+mask)&15,selected,bank=bank,seed=seed,tag=f'pattern{seed:08x}_{mask:04x}')
    for load,bank,offset,n,delay in product((False,True),(0,1),(0,15),(1,4,15),(0,1,3,7,20)):
        selected=[q for q in range(16) if q!=3][:n]
        # Following loads use the normal 16-bit field. Their pointer is the
        # newly updated Rp, so a stale pointer/data port is observable.
        row=fixture(load,False,offset,selected,bank=bank,tag=f'follow_n{n}_k{delay}')
        yield following(row,delay)
    # Empty/one/maximum lists take different completion paths. Keep them
    # in the permanent short-pause union as well as the length matrix.
    for load,off,offset,n in product((False,True),(False,True),(0,15),(0,1,15)):
        selected=[q for q in range(16) if q!=3][:n]
        yield fixture(load,off,offset,selected,tag=f'boundary_phase_n{n}')
