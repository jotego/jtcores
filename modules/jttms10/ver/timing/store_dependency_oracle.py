#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""CD instruction-word dependencies, independent of CPU arbitration phases.

SPVU001A 5.4.6,6.2,11.3 (5-24,6-4,11-4): requested instruction words
come from memory with CD; byte insertion preserves surrounding bits and
physical RMW pairs are indivisible. A modifying write precedes a dependent
opcode fetch. This family has no total instruction-duration contract.
Exact physical cycle lengths, transaction inventory/order and target
readiness remain checked for both old and native byte-store implementations.
No instruction-specific point phase is inferred from an RTL observation.
"""
from collections import Counter
from store_cases import transactions


def transfers(case):
    prefix=[(0, case['test_pc']+16*(q+1), value, 0)
            for q,value in enumerate(case.get('extensions', []))]
    if 'data_copy' in case:
        address=case['data_copy']['source']
        prefix.append((0, address, dict(case['initial_memory'])[address], 0))
    return prefix, transactions(case), (0, case['next_pc'], case['expected_next_opcode'], 1)


def check_trace(case, lines, wait, *, raw=False):
    prefix='TARGET' if raw else 'BUS'
    begin=[s.split() for s in lines if s.startswith(prefix+'_BEGIN ')]
    end=[s.split() for s in lines if s.startswith(prefix+'_END ')]
    leading, stores, opcode=transfers(case)
    expected=leading+stores+[opcode]
    if len(begin)!=len(expected) or len(end)!=len(expected):
        return [f'{prefix}: expected {len(expected)} transfers, got {len(begin)} starts/{len(end)} ends']
    actual=[]
    errors=[]
    for q,(b,e) in enumerate(zip(begin,end)):
        kind,address,iaq=int(b[2]),int(b[3],16),int(b[5])
        value=int(b[4] if kind else e[4],16)
        actual.append((kind,address,value,iaq))
        if e[2:4]!=b[2:4]:errors.append(prefix+': response ownership mismatch')
        if int(e[1])-int(b[1])!=(4 if raw else 16)+8*wait:
            errors.append(prefix+': incorrect physical cycle duration')
        if q and int(b[1])<int(end[q-1][1]):errors.append(prefix+': overlapping transfers')
    if actual[:len(leading)]!=leading:errors.append(prefix+': operand/source read order or data mismatch')
    if Counter(actual)!=Counter(expected):errors.append(prefix+': transaction address/data/kind/IAQ inventory mismatch')
    writes=[]
    for q,item in enumerate(actual):
        kind,address,value,iaq=item
        if kind:
            writes.append(item)
            if not q or actual[q-1][:2]!=(0,address) or actual[q-1][3]!=0:
                errors.append(prefix+': interrupted or missing RMW read')
    if writes!=[item for item in stores if item[0]]:
        errors.append(prefix+': field write order or payload mismatch')
    fetches=[q for q,item in enumerate(actual) if item[3]]
    if len(fetches)!=1:errors.append(prefix+': expected one opcode fetch')
    elif case['dependency_conditions']['next_opcode_modified']:
        modified=[q for q,item in enumerate(actual) if item[0] and item[1]==case['next_pc']]
        if len(modified)!=1 or modified[0]>=fetches[0]:
            errors.append(prefix+': opcode fetch preceded its modifying write')
    return errors


def check_bus(case, observed, lines, wait, pause=0, *, raw=False):
    errors=check_trace(case,lines,wait,raw=raw)
    prefix='TARGET' if raw else 'BUS'
    begin=[s.split() for s in lines if s.startswith(prefix+'_BEGIN ')]
    if raw:
        logical=[s.split() for s in lines if s.startswith('BUS_BEGIN ')]
        if len(logical)!=len(begin):
            errors.append('dependency: missing logical allocations for target readiness')
        else:
            for b,t in zip(logical,begin):
                if not int(b[1])<=int(t[1])<=int(b[1])+6:
                    errors.append('dependency: target dispatch outside physical readiness window')
    else:
        for b in begin:
            clock=int(b[1])
            if clock<observed['start'] or (clock-observed['start'])%8:
                errors.append('dependency: physical allocation outside machine-state grid')
    return errors
