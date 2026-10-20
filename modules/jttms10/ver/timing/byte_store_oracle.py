#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Literal CD MOVB counts and a bounded, indivisible posted-write contract.

SPVU001A Table13-2 (13-6): absolute B CD7, F CD13; Table13-4
(13-7): plain MOVB B/B index2 CD7. Sections6.2,11.3,13.1.1 permit
one queued field, indivisible RMW pairs and hidden trailing writes. The
generic field +3-per-word equation does not replace these explicit counts.

The placement of an unrelated opcode before the last complete RMW is a
project observation policy, not a TI pin waveform. The literal duration,
physical transfer lengths, contents, order and bounded drain all remain
mandatory. Dependent code writes use their separate architectural oracle.
"""


def supported(case):
    if not case.get('cache_disabled') or 'dependency_conditions' in case:
        return False
    if case.get('coverage_id')=='MOVB_R_ABS':
        return case['data_store']['width']==8
    if case.get('coverage_id')=='MOVB_IND_IND':
        copy=case['data_copy']
        return (copy['width']==8 and copy.get('mode','indirect')=='indirect'
                and copy['source']%16<=8 and copy['destination']%16<=8)
    return False


def states(case):
    if not supported(case):
        raise ValueError('outside nominal CD byte-store contract')
    return 7 if 'data_copy' in case or case['data_store']['address']%16<=8 else 13


def wait_count(case):
    """Blocking words only; the last whole pair remains queued after decode."""
    return 2 if 'data_copy' in case else 3 if states(case)==7 else 5


def apply(case):
    if supported(case):
        case['states']=states(case)
        case['drain_instructions']=-2
        case['source_values']['policy_cd']=case['states']
        case['timing_source_status']='primary-summary-consistent'
        case['source_notes']=('Literal MOVB CD count from Table13-2/4; the '
            'generic field/hidden-write/+3-per-word equation is inapplicable '
            'to this explicit byte entry. One complete trailing RMW is '
            'posted, never split by an opcode. Section13.1.1 charges residual '
            'writes to subsequent bus-dependent work. Bus phase policy is '
            'documented separately; this is not an official TI waveform.')
    return case


def transfers(case):
    from store_cases import transactions
    if 'data_copy' in case:
        from copy_cases import transactions as copy_transactions
        leading,writes=copy_transactions(case)
    else:
        leading=[(0,case['test_pc']+16*(q+1),value,0)
                 for q,value in enumerate(case['extensions'])]
        writes=transactions(case)
    opcode=(0,case['next_pc'],case.get('expected_next_opcode',0x0300),1)
    return leading+writes[:-2]+[opcode]+writes[-2:]


def check_bus(case,observed,lines,wait,pause=0,*,raw=False):
    prefix='TARGET' if raw else 'BUS'
    begin=[s.split() for s in lines if s.startswith(prefix+'_BEGIN ')]
    end=[s.split() for s in lines if s.startswith(prefix+'_END ')]
    plan=transfers(case)
    if len(begin)!=len(plan) or len(end)!=len(plan):
        return [f'{prefix}: expected {len(plan)} CD byte transfers, '
                f'observed {len(begin)} starts/{len(end)} completions']
    errors=[]
    actual=[]
    for q,(b,e) in enumerate(zip(begin,end)):
        kind,address,iaq=int(b[2]),int(b[3],16),int(b[5])
        value=int(b[4] if kind else e[4],16)
        actual.append((kind,address,value,iaq))
        if b[2:4]!=e[2:4]:errors.append(prefix+' response ownership mismatch')
        if int(e[1])-int(b[1])!=(4 if raw else 16)+8*wait:
            errors.append(prefix+' physical cycle duration mismatch')
        if q and int(b[1])<int(end[q-1][1]):
            errors.append(prefix+' overlapping physical cycles')
        if kind and (not q or actual[q-1][:2]!=(0,address) or actual[q-1][3]):
            errors.append(prefix+' RMW pair split or missing read')
    if actual!=plan:
        errors.append(prefix+' CD operand/source/opcode/RMW order or payload mismatch')
    if raw:
        logical=[s.split() for s in lines if s.startswith('BUS_BEGIN ')]
        if len(logical)!=len(begin):errors.append('missing logical CD byte allocations')
        else:
            for b,t in zip(logical,begin):
                if not int(b[1])<=int(t[1])<=int(b[1])+6:
                    errors.append('CD byte target dispatch outside readiness window')
    else:
        alignment=pause+(-pause)%8
        for b in begin:
            if int(b[1])<observed['start']+alignment or (int(b[1])-observed['start']-alignment)%8:
                errors.append('CD byte allocation outside machine-state grid')
        # One final read/write pair overlaps the last CPU state: H3.
        # Waits on this queued pair extend its drain, not the prior decode.
        if int(end[-1][1])>observed['end']+8*(3+2*wait):
            errors.append('CD byte hidden write drain exceeds H3+2W bound')
        if int(begin[-2][1])<observed['end']-8:
            errors.append('CD byte final pair precedes its overlapping CPU state')
    return errors
