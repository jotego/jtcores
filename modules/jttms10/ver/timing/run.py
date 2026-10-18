#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Run specification timing checks through the complete jttms10 system.

Every mismatch fails (including when --report is requested). No baseline
allowlist, microcode cycle annotation, or functional result can waive timing.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
from oracle import INPUT_CLOCKS_PER_STATE, FIXED, fixed_states, multiply_states
from scalar_cases import shift_cases, lmo_cases
from alu_cases import alu_cases
from xy_cases import xy_cases
from coordinate_cases import coordinate_cases
from copy_cases import copy_cases, transactions as copy_transactions
from divide_cases import divide_cases
from immediate_cases import immediate_cases
from load_cases import load_cases
from load_mode_cases import load_mode_cases
from store_cases import store_cases, transactions as store_transactions
from store_mode_cases import store_mode_cases
from control_cases import control_cases, program as control_program, fetch_extensions

HERE = Path(__file__).resolve().parent
MODULE = HERE.parents[1]
MASK32 = (1 << 32) - 1


def movi(value, register):
    return [0x09E0 | register, value & 0xFFFF, (value >> 16) & 0xFFFF]


def cases():
    for cache_disabled in (False, True):
        for signed in (True, False):
            for fs in range(2, 33, 2):
                for negative in (False, True):
                    for odd in (False, True):
                        name = (f"{'mpys' if signed else 'mpyu'}_fs{fs}"
                                f"_{'negative' if negative else 'positive'}"
                                f"_{'odd' if odd else 'even'}"
                                f"_{'off' if cache_disabled else 'hit'}")
                        source = 1 | ((1 << (fs - 1)) if negative else 0)
                        # Ignored high bits distinguish field sign from bit31.
                        if fs < 32:
                            source |= (~((1 << fs) - 1)) & MASK32
                        regs = [0x80000003, 0x80000003 if odd else 0x11223344,
                                source, 0xD0000810 | ((fs & 31) << 6)]
                        expected = list(regs)
                        multiplier = source & ((1 << fs) - 1)
                        multiplicand = regs[int(odd)]
                        if signed:
                            if multiplier & (1 << (fs - 1)):
                                multiplier -= 1 << fs
                            if multiplicand & (1 << 31):
                                multiplicand -= 1 << 32
                        product = (multiplier * multiplicand) & ((1 << 64) - 1)
                        width = 32 if odd else 64
                        stored = product & ((1 << width) - 1)
                        expected[int(odd)] = (product if odd else product >> 32) & MASK32
                        if not odd:
                            expected[1] = product & MASK32
                        expected_st = regs[3] & ~(1 << 29)
                        expected_st |= int(stored == 0) << 29
                        if signed:
                            expected_st = (expected_st & ~(1 << 31)) | ((stored >> (width - 1)) << 31)
                        states = multiply_states(signed=signed, fs1=fs, source=source,
                                                 cache_disabled=cache_disabled)
                        yield dict(name=name, opcode=(0x5C00 if signed else 0x5E00) | 0x40 | int(odd),
                                   coverage_id='MPYS_RR' if signed else 'MPYU_RR',
                                   regs=regs, expected_regs=expected, expected_st=expected_st,
                                   states=states, cache_disabled=cache_disabled,
                                   citation="SPVU001A " + ("12-165" if signed else "12-167"),
                                   conditions=dict(fs1=fs, signed=signed, source=source,
                                                   destination=int(odd)))
        for name, opcode in (("NOP", 0x0300), ("ADD", 0x4040), ("MOVK", 0x18A0)):
            regs = [0x80000003, 0x11223344, 2, 0xD0000810]
            expected = list(regs)
            expected_st = regs[3]
            if name == "ADD":
                expected[0] += 2
                expected_st = (regs[3] & 0x0FFFFFFF) | 0x80000000
            elif name == "MOVK":
                expected[0] = 5
            yield dict(name=f"{name.lower()}_{'off' if cache_disabled else 'hit'}",
                       coverage_id={'NOP':'NOP', 'ADD':'ADD_RR', 'MOVK':'MOVK_K'}[name],
                       opcode=opcode, regs=regs, expected_regs=expected,
                       expected_st=expected_st, states=fixed_states(name, cache_disabled=cache_disabled),
                       cache_disabled=cache_disabled, citation="SPVU001A " + FIXED[name][2],
                       conditions={})
    yield from shift_cases()
    yield from lmo_cases()
    yield from alu_cases()
    yield from divide_cases()
    yield from immediate_cases()
    yield from load_cases()
    yield from load_mode_cases()
    yield from store_cases()
    yield from store_mode_cases()
    yield from control_cases()
    yield from xy_cases()
    yield from coordinate_cases()
    yield from copy_cases()
    for flags in (0x00000810,0xF0000810):
        regs=[0x11223344,0xAABBCCDD,0x55667788,flags]
        yield dict(name=f'nop_next_subsegment_miss_{flags:08x}',coverage_id='NOP',opcode=0x0300,
                   regs=regs,expected_regs=list(regs),expected_st=flags,states=10,
                   cache_disabled=False,cache_miss=True,measure_pass=0,
                   citation='SPVU001A 5.4.7 p.5-24; 12-170',conditions=dict(next_opcode_miss=True))


def program(case):
    if 'control_flow' in case:
        return control_program(case,movi)
    # Disable DRAM refresh and video; only the CPU uses the physical bus.
    words = movi(0xC00000B0, 14) + movi(0x8018 if case['cache_disabled'] else 0x18, 13)
    words += [0x0550, 0x81AE]  # SETF 16,0,0; MOVE A13,*A14,0
    for address,value in case.get('setup_io',[]):
        words += movi(address,14)+movi(value,13)+[0x0550,0x81AE]
    loop = 0x1000 + 16 * len(words)
    for reg, value in enumerate(case['regs']):
        words += movi(value, reg)
    for reg,value in case.get('initial_b_regs',{}).items():
        words += movi(value,16+reg)
    if 'initial_sp' in case:words += movi(case['initial_sp'],15)
    words += [0x01A3] + [0x0300] * 12  # PUTST A3, then drain previous writes
    offset=case.get('instruction_word_offset',3 if case.get('cache_miss') else None)
    if offset is not None:
        while len(words)%4!=offset:words.append(0x0300)
    test_pc = 0x1000 + 16 * len(words)
    words += [case['opcode'],*case.get('extensions',[])]
    next_pc = 0x1000 + 16 * len(words)
    if 'pc_result_register' in case:
        case['expected_regs'][case['pc_result_register']] = next_pc
    words += case.get('following_words',[0x0300] * case.get('tail_instructions',12))
    branch_pc = 0x1000 + 16 * len(words)
    displacement = (loop - (branch_pc + 16)) // 16
    assert -127 <= displacement < 0
    words += [0xC000 | (displacement & 255)]
    return words, test_pc, next_pc


def parse_result(stdout):
    results = [line for line in stdout.splitlines() if line.startswith('RESULT ')]
    if len(results) != 1:
        raise ValueError(f"expected exactly one RESULT, found {len(results)}")
    fields = dict(item.split('=') for item in results[0].split()[1:])
    implicit=[line for line in stdout.splitlines() if line.startswith('IMPLICIT ')]
    if len(implicit)>1:raise ValueError('duplicate implicit-register observation')
    if implicit:fields.update(item.split('=') for item in implicit[0].split()[1:])
    return {key: int(value, 10 if key in ('case', 'clocks', 'start', 'end', 'paused') else 16)
            for key, value in fields.items()}


def split_transcripts(log, identifiers, *, batch):
    """Validate case association; one case must never inherit another's result."""
    chunks = {}
    order = []
    active = None
    for line in log.splitlines():
        if line.startswith('CASE '):
            active = int(line.split()[1])
            if active in chunks:
                raise ValueError(f'duplicate CASE marker {active}')
            order.append(active)
            chunks[active] = []
        elif active is not None:
            chunks[active].append(line)
    if order != identifiers:
        position = next((q for q,(a,b) in enumerate(zip(identifiers,order)) if a!=b),
                        min(len(identifiers),len(order)))
        expected = identifiers[position] if position<len(identifiers) else 'end'
        actual = order[position] if position<len(order) else 'end'
        raise ValueError(f'CASE order/count mismatch: expected {len(identifiers)} cases, observed {len(order)}; '
                         f'at position {position}, expected {expected}, observed {actual}')
    if batch and log.splitlines().count(f'BATCH_DONE cases={len(identifiers)}') != 1:
        raise ValueError('missing or duplicate BATCH_DONE marker')
    return {key: '\n'.join(lines) for key, lines in chunks.items()}


def simulate(command, work, timeout):
    try:
        return subprocess.run(command, cwd=work, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        output = error.stdout or ''
        if isinstance(output, bytes):
            output = output.decode(errors='replace')
        return subprocess.CompletedProcess(command, 124, output, 'simulation timed out\n')


def measured_trace(log, prefix, observed, *, trailing=False):
    """A previous opcode may complete exactly as direct dispatch starts.

    Include new allocations at the opening boundary, and completions after
    it through the closing boundary. A prior completion at start belongs
    to the preceding instruction, not the measured transfer sequence.
    """
    result=[]
    for line in log.splitlines():
        if not line.startswith(prefix+'_'):continue
        if observed is not None:
            clock=int(line.split()[1])
            if clock<observed['start'] or line.startswith(prefix+'_END ') and clock==observed['start']:continue
            if not trailing and clock>observed['end']:continue
            if not trailing and clock==observed['end'] and not line.startswith(prefix+'_END '):continue
        result.append(line)
    return result


def check(case, observed, wait_states=0, pause_clocks=0):
    errors = []
    if 'data_store' in case:
        if 'data_copy' in case:
            reads,writes=copy_transactions(case)
            count=len(reads)+(len(writes)+1)*int(case['cache_disabled'])
        else:
            count=(len(store_transactions(case))+1+len(case.get('extensions',[]))) if case['cache_disabled'] else 4 if case.get('cache_miss')=='store_extension' else 0
        alignment=(-pause_clocks)%8 if count else 0
        clocks=case['states']*8+count*wait_states*8+pause_clocks+alignment
        if observed['clocks']!=clocks:errors.append(f"{case['name']}: expected {clocks} INCLK, observed {observed['clocks']} INCLK")
        if observed['paused']!=pause_clocks:errors.append('CPU pause count mismatch')
        for reg,value in enumerate(case['expected_regs']):
            if observed[f'a{reg}']!=value:errors.append(f'A{reg} result mismatch')
        for name,value in case['expected_extra_regs'].items():
            if observed.get(name)!=value:errors.append(name.upper()+' result mismatch')
        if observed['st']!=case['expected_st']:errors.append('ST result mismatch')
        return errors
    load=case.get('data_load')
    data_words=(((load['address']&15)+load['width']+15)//16) if load else 0
    words=data_words+(4 if case.get('cache_miss') else (1+len(case.get('extensions',[])))*int(case['cache_disabled']))
    if 'control_flow' in case:
        words=(1+len(fetch_extensions(case)))*int(case['cache_disabled'])
    added_clocks = words * wait_states * INPUT_CLOCKS_PER_STATE
    alignment=(-pause_clocks)%INPUT_CLOCKS_PER_STATE if words else 0
    expected_clocks = case['states'] * INPUT_CLOCKS_PER_STATE + added_clocks + pause_clocks + alignment
    if observed['paused'] != pause_clocks:
        errors.append(f"expected {pause_clocks} paused clocks, observed {observed['paused']}")
    if observed['clocks'] != expected_clocks:
        errors.append(f"expected {expected_clocks} INCLK ({case['states']} intrinsic machine states, "
                      f"{added_clocks} external wait clocks, {pause_clocks} CEN pause clocks, {alignment} bus alignment clocks), "
                      f"observed {observed['clocks']} INCLK")
    for reg, value in enumerate(case['expected_regs']):
        mask = case.get('expected_masks', [MASK32]*len(case['expected_regs']))[reg]
        if (observed[f'a{reg}'] ^ value) & mask:
            errors.append(f"A{reg}: expected {value:08x} (mask {mask:08x}), observed {observed[f'a{reg}']:08x}")
    if observed['st'] != case['expected_st']:
        errors.append(f"ST: expected {case['expected_st']:08x}, observed {observed['st']:08x}")
    for name,value in case.get('expected_extra_regs',{}).items():
        if observed.get(name)!=value:
            errors.append(f'{name.upper()}: expected {value:08x}, observed {observed.get(name)!r}')
    return errors


def reads(case, wait_states=0):
    """Independent external instruction-word plan for these general forms.

    TI §5.4.7: CD adds three states per word; §11.5 p.11-24 makes
    extension IAQ low with CD, but all four cache-fill reads IAQ high.
    Each immediate word consumes an intrinsic state and its external-fetch
    penalty. No data writes or hidden states occur in these fixtures.
    """
    if 'control_flow' in case:
        if not case['cache_disabled']:return []
        extensions=fetch_extensions(case)
        # The instruction entries specify total counts, not an internal
        # word-by-word CPU schedule for extended branches. Assert every
        # transfer/address/IAQ and the TI state grid without inventing such
        # microinstruction edges. Single-word forms retain the fixed slot.
        return [(None,case['test_pc']+16*(q+1),word,0) for q,word in enumerate(extensions)]+[
            (None if extensions else case['states']-3,case['next_pc'],case['expected_next_opcode'],1)]
    if 'data_load' in case:
        load=case['data_load'];address=load['address']
        count=((address&15)+load['width']+15)//16
        image=dict(case['initial_memory'])
        mode=load.get('mode','indirect');extensions=case.get('extensions',[])
        plan=[]
        if case['cache_disabled']:
            plan=[(1+i*(4+wait_states),case['test_pc']+16*(i+1),word,0) for i,word in enumerate(extensions)]
        lead=1 if mode=='pre' else 2 if mode in ('offset','absolute') else 0
        first=lead+(3+wait_states)*len(extensions)*int(case['cache_disabled'])
        if case.get('cache_miss')=='load_extension':
            missing=case['miss_word'];fill_words=extensions[missing-1:]+[0x0300]*4
            plan=[(missing+i*(2+wait_states),case['test_pc']+16*(missing+i),fill_words[i],1) for i in range(4)]
            first=lead+9+4*wait_states
        plan += [(first+i*(2+wait_states),((address&~15)+16*i)&MASK32,
                  image[((address&~15)+16*i)&MASK32],0) for i in range(count)]
        if case['cache_disabled']:
            plan.append((case['states']-3+(count+len(extensions))*wait_states,case['next_pc'],0x0300,1))
        return plan
    if case.get('cache_miss')=='extension':
        first=case.get('miss_word',1)
        words=case['extensions'][first-1:]+[0x0300]*4
        return [(first+i*(2+wait_states),case['test_pc']+16*(i+first),words[i],1) for i in range(4)]
    if case.get('cache_miss'):
        return [(case['states']-9+i*(2+wait_states),case['next_pc']+16*i,0x0300,1)
                for i in range(4)]
    if not case['cache_disabled']:
        return []
    extensions=case.get('extensions',[])
    if extensions:
        words=[(case['test_pc']+16*(i+1),word,0) for i,word in enumerate(extensions)]
        words.append((case['next_pc'],0x0300,1))
        return [(1+i*(4+wait_states),addr,data,iaq) for i,(addr,data,iaq) in enumerate(words)]
    return [(case['states']-3,case['next_pc'],0x0300,1)]


def check_bus(case, observed, lines, wait_states, pause_clocks=0):
    errors = []
    begin = [line.split() for line in lines if line.startswith('BUS_BEGIN ')]
    end = [line.split() for line in lines if line.startswith('BUS_END ')]
    if 'data_store' in case:return check_store_bus(case,observed,lines,wait_states,pause_clocks)
    plan=reads(case,wait_states)
    if len(begin) != len(plan) or len(end) != len(plan):
        errors.append(f"expected {len(plan)} physical instruction reads, observed {len(begin)} starts/{len(end)} ACKs")
    elif plan:
        if 'control_flow' in case and any(int(b[1])<int(e[1]) for b,e in zip(begin[1:],end[:-1])):
            errors.append('control-flow instruction reads overlap or are out of order')
        if observed['start']%INPUT_CLOCKS_PER_STATE:
            errors.append('external fetch begins from an instruction off the machine-state grid')
        alignment=(-pause_clocks)%INPUT_CLOCKS_PER_STATE
        for (offset,addr,data,iaq),b,e in zip(plan,begin,end):
            if offset is None:
                start=int(b[1])
                if start%8 or not observed['start']<=start<int(e[1])<=observed['end']:
                    errors.append('extended control-flow read outside the TI grid/instruction interval')
            else:
                start=observed['start']+offset*INPUT_CLOCKS_PER_STATE+pause_clocks+alignment
                if int(b[1]) != start:
                    errors.append(f"TI instruction read start: expected clock {start}, observed {b[1]}")
            if (int(b[2]), int(b[3], 16), int(b[5])) != (0,addr,iaq):
                errors.append(f"unexpected physical cycle: {' '.join(b)}; expected address {addr:08x}, IAQ {iaq}")
            if e[2:4] != b[2:4] or int(e[4], 16) != data:
                errors.append(f"unexpected target response: {' '.join(e)}; expected data {data:04x}")
            clocks = int(e[1]) - int(b[1])
            if clocks != 16 + 8 * wait_states:
                errors.append(f"TI read duration: expected {16+8*wait_states} INCLK, observed {clocks}")
    return errors


def check_target(case,observed,lines,wait_states,pause_clocks=0):
    """Check actual transport requests/ACKs separately from logical states."""
    if 'data_store' in case:return check_store_bus(case,observed,lines,wait_states,pause_clocks,raw=True)
    plan=reads(case,wait_states)
    begin=[line.split() for line in lines if line.startswith('TARGET_BEGIN ')]
    end=[line.split() for line in lines if line.startswith('TARGET_END ')]
    errors=[]
    if len(begin)!=len(plan) or len(end)!=len(plan):
        return [f'expected {len(plan)} target reads, observed {len(begin)} starts/{len(end)} ACKs']
    logical_begin=[line.split() for line in lines if line.startswith('BUS_BEGIN ')]
    for q,((offset,addr,data,iaq),b,e) in enumerate(zip(plan,begin,end)):
        if offset is None:
            if len(logical_begin)!=len(plan):
                errors.append('missing logical bus allocations for extended control-flow target checks')
                continue
            logical=int(logical_begin[q][1])
        else:logical=observed['start']+offset*8+pause_clocks+(-pause_clocks)%8
        if not logical<=int(b[1])<=logical+6:
            errors.append(f'target dispatch outside TI readiness window: {b[1]} versus {logical}..{logical+6}')
        if (int(b[2]),int(b[3],16),int(b[5]))!=(0,addr,iaq):
            errors.append(f'unexpected target request: {b}; expected address {addr:08x}, IAQ {iaq}')
        if e[2:4]!=b[2:4] or int(e[4],16)!=data:
            errors.append(f'unexpected target data: {e}; expected {data:04x}')
        duration=int(e[1])-int(b[1])
        if duration!=4+8*wait_states:
            errors.append(f'target ACK: expected {4+8*wait_states} INCLK, observed {duration}')
    return errors


def check_store_bus(case,observed,lines,wait_states,pause_clocks=0,*,raw=False):
    prefix='TARGET' if raw else 'BUS'
    begin=[x.split() for x in lines if x.startswith(prefix+'_BEGIN ')]
    end=[x.split() for x in lines if x.startswith(prefix+'_END ')]
    if 'data_copy' in case:
        reads,writes=copy_transactions(case);plan=reads+writes
        starts=[q*(2+wait_states) for q in range(len(reads))]
        first=case['data_copy']['cpu']-1+len(reads)*wait_states
        starts += [first+q*(2+wait_states) for q in range(len(writes))]
        if case['cache_disabled']:
            starts.append(first+len(writes)*(2+wait_states))
            plan.append((0,case['next_pc'],0x0300,1))
        if 'follow_delay' in case:
            start=max(case['data_copy']['cpu']+len(reads)*wait_states+case['follow_delay'],
                      first+len(writes)*(2+wait_states))
            address=case['data_copy']['destination'];width=case['data_copy']['width']
            image=dict(case['expected_memory'])
            for q in range(((address&15)+width+15)//16):
                word=((address&~15)+16*q)&MASK32
                starts.append(start+q*(2+wait_states));plan.append((0,word,image[word],0))
    else:
        spec=case['data_store'];data_plan=store_transactions(case);plan=[];starts=[]
        extensions=case.get('extensions',[])
        lead=spec['cpu']-1
        first=lead
        if case['cache_disabled']:
            plan=[(0,case['test_pc']+16*(q+1),word,0) for q,word in enumerate(extensions)]
            starts=[1+q*(4+wait_states) for q in range(len(extensions))]
            first+=(3+wait_states)*len(extensions)
        if case.get('cache_miss')=='store_extension':
            missing=case['miss_word'];fill=extensions[missing-1:]+[0x0300]*4
            plan=[(0,case['test_pc']+16*(missing+q),fill[q],1) for q in range(4)]
            starts=[missing+q*(2+wait_states) for q in range(4)]
            first+=9+4*wait_states
        starts.extend(first+q*(2+wait_states) for q in range(len(data_plan)))
        plan.extend(data_plan)
        if case['cache_disabled']:
            starts.append(first+len(data_plan)*(2+wait_states))
            plan.append((0,case['next_pc'],0x0300,1))
        if 'follow_delay' in case:
            start=max(spec['cpu']+case['follow_delay'],lead+len(plan)*(2+wait_states))
            image=dict(case['expected_memory']);address=spec['address']
            count=((address&15)+spec['width']+15)//16
            for q in range(count):
                word=((address&~15)+16*q)&MASK32
                starts.append(start+q*(2+wait_states));plan.append((0,word,image[word],0))
    errors=[]
    if len(begin)!=len(plan) or len(end)!=len(plan):
        return [f'expected {len(plan)} {prefix} store/fetch transfers, observed {len(begin)} starts/{len(end)} completions']
    for offset,(kind,addr,data,iaq),b,e in zip(starts,plan,begin,end):
        start=observed['start']+8*offset+pause_clocks+(-pause_clocks)%8
        clock=int(b[1]);duration=int(e[1])-clock
        if (not raw and clock!=start) or (raw and not start<=clock<=start+6):
            errors.append(f'{prefix} transfer start: expected {start}'+('..'+str(start+6) if raw else '')+f', observed {clock}')
        if (int(b[2]),int(b[3],16),int(b[5]))!=(kind,addr,iaq):errors.append(f'{prefix} request kind/address/IAQ mismatch: {b}')
        if kind and int(b[4],16)!=data:errors.append(f'{prefix} write data mismatch')
        if e[2:4]!=b[2:4] or (not kind and int(e[4],16)!=data):errors.append(f'{prefix} read response mismatch')
        expected=(4 if raw else 16)+8*wait_states
        if duration!=expected:errors.append(f'{prefix} transfer duration: expected {expected}, observed {duration}')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', action='append', help='case name or substring; repeat for a union of probes')
    parser.add_argument('--report', type=Path, help='write all observations and verdicts as JSON')
    parser.add_argument('--traces', type=Path, help='retain full logs in this directory')
    parser.add_argument('--trace-core', action='store_true',
                        help='include controller/cache handshakes in retained logs')
    parser.add_argument('--rtl-dir', type=Path, default=MODULE / 'hdl',
                        help='complete alternative HDL directory for regression mutation checks')
    parser.add_argument('--bench', type=Path, default=HERE / 'test.sv',
                        help='alternative testbench for stimulus mutation checks')
    parser.add_argument('--separate-processes', action='store_true',
                        help='start a fresh simulator for each case (slower isolation cross-check)')
    parser.add_argument('--simulator', choices=('iverilog', 'verilator'), default='iverilog',
                        help='simulation engine (Verilator also requires a C++ compiler)')
    parser.add_argument('--wait-states', type=int, default=0,
                        help='add this many TI machine states to every physical cycle')
    parser.add_argument('--pause-clocks', type=int, default=0,
                        help='pause CEN during measured CPU execution for this many input clocks')
    parser.add_argument('--pause-after-clocks', type=int, default=0,
                        help='delay the CPU-work pause by this many INCLK (select an instruction still executing)')
    args = parser.parse_args()
    started = time.monotonic()
    if args.wait_states < 0 or args.pause_clocks < 0 or args.pause_after_clocks < 0:
        parser.error('wait states and pause clocks must be nonnegative')
    selected = [case for case in cases() if args.case is None or any(term in case['name'] for term in args.case)]
    if not selected:
        parser.error('no matching cases')
    hdl = args.rtl_dir.resolve()
    if not (hdl / 'jttms10.v').is_file() or not args.bench.is_file():
        parser.error('missing CPU HDL or testbench')
    if args.traces:
        args.traces.mkdir(parents=True, exist_ok=True)
    rows = []
    sources = [(f'hdl/{path.name}',path) for path in sorted(hdl.glob('*.v'))]
    sources += [(f'ucode/{path.name}',path) for path in sorted((MODULE / 'ucode').glob('*.yaml'))]
    sources += [(f'ver/timing/{name}',HERE / name) for name in ('oracle.py', 'run.py', 'scalar_cases.py', 'alu_cases.py', 'divide_cases.py', 'immediate_cases.py', 'load_cases.py', 'load_mode_cases.py', 'store_cases.py', 'store_mode_cases.py', 'control_cases.py', 'xy_cases.py', 'coordinate_cases.py', 'copy_cases.py')]
    sources += [('ver/timing/test.sv',args.bench)]
    provenance = dict(source_sha256={name: hashlib.sha256(path.read_bytes()).hexdigest()
                                     for name,path in sources})
    version_command = ['verilator','--version'] if args.simulator=='verilator' else ['iverilog','-V']
    version = subprocess.run(version_command,capture_output=True,text=True,check=True)
    provenance['simulator_version'] = version.stdout.splitlines()[0]
    with tempfile.TemporaryDirectory(prefix='jttms10-timing-') as temp:
        work = Path(temp)
        subprocess.run(['bash', str(MODULE / 'ver/build.sh'), str(work)], check=True,
                       stdout=subprocess.DEVNULL)
        rtl_sources = [str(args.bench.resolve()), *map(str, sorted(hdl.glob('*.v')))]
        if args.simulator == 'iverilog':
            binary = work / 'timing.vvp'
            compile_command = ['iverilog', '-g2012', '-s', 'test', '-I', str(work),
                               '-o', str(binary), *rtl_sources]
            executable = ['vvp', str(binary)]
        else:
            obj = work / 'obj'
            compile_command = ['verilator', '--binary', '--timing', '--top-module', 'test',
                '--timescale-override', '1ns/1ps', '-Wno-EOFNEWLINE', '-j', '4',
                '--Mdir', str(obj), '-I'+str(work), *rtl_sources]
            executable = [str(obj / 'Vtest')]
        compiled = subprocess.run(compile_command, cwd=work, capture_output=True, text=True)
        if args.traces:
            (args.traces / 'compile.log').write_text(compiled.stdout+compiled.stderr)
        if compiled.returncode:
            print(compiled.stdout+compiled.stderr)
            raise SystemExit(compiled.returncode)
        provenance['generated_sha256'] = {
            path.name: hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(work.iterdir()) if path.suffix in ('.vh', '.uc', '.hex')}
        prepared = []
        for identifier, case in enumerate(selected):
            words, test_pc, next_pc = program(case)
            case = dict(case, test_pc=test_pc, next_pc=next_pc)
            if 'follow_delay' in case:case['follow_pc']=next_pc+16*(case['follow_delay']+1)
            prepared.append((identifier, case, words))
        base_command = [*executable, f'+WAIT={8 * args.wait_states}', f'+PAUSE_AFTER={args.pause_after_clocks}',
                        f'+PAUSE={args.pause_clocks}', *(['+TRACE'] if args.trace_core else [])]
        executions = []
        if args.separate_processes:
            for identifier, case, words in prepared:
                image = [0] * 4096
                image[0x100:0x100 + len(words)] = words
                memory=case.get('initial_memory',[])
                (work / 'data.mem').write_text(''.join(f'{addr:08x} {value:04x}\n' for addr,value in memory))
                (work / 'program.mem').write_text(''.join(f'{word:04x}\n' for word in image))
                command = base_command + ['+PROGRAM=program.mem', f'+CASE_ID={identifier}',
                    f'+MEASURE_PASS={case.get("measure_pass",1)}',f'+DATA_COUNT={len(memory)}','+DATA=data.mem',f'+WATCH_EXTRA={int(bool(case.get("expected_extra_regs"))) | (2 if "control_flow" in case else 0) | (4 if case.get("observe_implicit") else 0)}',
                    f"+DRAIN_INSTRUCTIONS={case.get('drain_instructions',0)}", f"+FOLLOW_PC={case.get('follow_pc',0):x}", f"+TEST_PC={case['test_pc']:x}", f"+NEXT_PC={case['next_pc']:x}"]
                executions.append(([identifier], simulate(command, work, 30)))
        else:
            (work / 'cases.txt').write_text(''.join(
                f"{identifier} {case['test_pc']:x} {case['next_pc']:x} {case.get('measure_pass',1)} {len(words)} {len(case.get('initial_memory',[]))} {int(bool(case.get('expected_extra_regs'))) | (2 if 'control_flow' in case else 0) | (4 if case.get('observe_implicit') else 0)} {case.get('drain_instructions',0)} {case.get('follow_pc',0):x} " +
                ' '.join(f'{word:04x}' for word in words) + ' ' +
                ' '.join(f'{addr:08x} {value:04x}' for addr,value in case.get('initial_memory',[]))+'\n'
                for identifier, case, words in prepared))
            executions.append((list(range(len(prepared))), simulate(
                base_command+['+BATCH=cases.txt'], work, max(30, 2*len(prepared)))))
        logs = {}
        protocol_errors = {}
        for identifiers, result in executions:
            output = result.stdout + result.stderr
            try:
                chunks = split_transcripts(output, identifiers, batch=not args.separate_processes)
                logs.update(chunks)
            except ValueError as error:
                for identifier in identifiers:
                    logs[identifier] = output
                    protocol_errors[identifier] = str(error)
            if result.returncode:
                for identifier in identifiers:
                    protocol_errors[identifier] = f'simulator exit {result.returncode}'
        for identifier, case, words in prepared:
            log = logs[identifier]
            if args.traces:
                (args.traces / (case['name'] + '.log')).write_text(log)
            try:
                observed = parse_result(log)
                errors = check(case, observed, args.wait_states, args.pause_clocks)
                if observed['case'] != identifier:
                    errors.append(f"expected case identifier {identifier}, observed {observed['case']}")
            except ValueError as error:
                observed, errors = None, [str(error)]
            if identifier in protocol_errors:
                errors.insert(0, protocol_errors[identifier])
            row = dict(case, observed=observed, errors=errors)
            # Keep measured bus traffic with the verdict, including expected
            # zero-traffic warm hits. Full launch trace is available separately.
            row['bus_trace'] = measured_trace(log,'BUS',observed,trailing='data_store' in case)
            row['target_trace'] = measured_trace(log,'TARGET',observed,trailing='data_store' in case)
            if observed is not None:
                errors.extend(check_bus(case, observed, row['bus_trace'], args.wait_states, args.pause_clocks))
                errors.extend(check_target(case,observed,row['target_trace']+(row['bus_trace'] if 'control_flow' in case else []),args.wait_states,args.pause_clocks))
            if 'control_flow' in case:
                next_opcodes=[int(line.split()[1],16) for line in log.splitlines() if line.startswith('NEXT_OPCODE ')]
                row['observed_next_opcodes']=next_opcodes
                if next_opcodes != [case['expected_next_opcode']]:errors.append('control-flow target opcode mismatch')
            if 'control_follow' in case:
                follow=[line for line in log.splitlines() if line.startswith('FOLLOW ')]
                if len(follow)!=1:errors.append('expected exactly one post-branch instruction observation')
                else:
                    fields=dict(item.split('=') for item in follow[0].split()[1:])
                    actual={key:int(value,10 if key=='clock' else 16) for key,value in fields.items()}
                    if 'expected_follow_extra_regs' in case:
                        extra=[line for line in log.splitlines() if line.startswith('FOLLOW_EXTRA ')]
                        if len(extra)!=1:errors.append('expected exactly one following implicit-register observation')
                        else:actual.update({key:int(value,16) for key,value in (item.split('=') for item in extra[0].split()[1:])})
                        for key,value in case['expected_follow_extra_regs'].items():
                            if actual.get(key)!=value:errors.append(f'first instruction after branch {key.upper()} mismatch')
                    row['observed_follow']=actual
                    spec=case['control_follow']
                    clocks=8*(spec['states']+spec['transfers']*args.wait_states)
                    if observed is not None and actual['clock']-observed['end']!=clocks:
                        errors.append(f'first instruction after branch: expected {clocks} INCLK, observed {actual["clock"]-observed["end"]}')
                    for q,value in enumerate(case['expected_follow_regs']):
                        if actual[f'a{q}']!=value:errors.append(f'first instruction after branch A{q} mismatch')
                    if actual['st']!=case['expected_follow_st']:errors.append('first instruction after branch ST mismatch')
                    if spec.get('scalar') and observed is not None:
                        following=dict(name=case['name']+'_following',cache_disabled=case['cache_disabled'],
                            states=spec['states'],test_pc=case['next_pc'],next_pc=case['follow_pc'])
                        interval=dict(start=observed['end'],end=actual['clock'],clocks=actual['clock']-observed['end'])
                        row['follow_bus_trace']=measured_trace(log,'BUS',interval)
                        row['follow_target_trace']=measured_trace(log,'TARGET',interval)
                        errors.extend('following coordinate: '+error for error in check_bus(following,interval,row['follow_bus_trace'],args.wait_states))
                        errors.extend('following coordinate: '+error for error in check_target(following,interval,row['follow_target_trace'],args.wait_states))
                memory=[(int(x.split()[1],16),int(x.split()[2],16)) for x in log.splitlines() if x.startswith('MEMORY ')]
                row['observed_memory']=memory
                if sorted(memory)!=sorted(case['expected_follow_memory']):errors.append('memory after first post-branch instruction mismatch')
            if 'data_store' in case:
                memory=[(int(x.split()[1],16),int(x.split()[2],16)) for x in log.splitlines() if x.startswith('MEMORY ')]
                row['observed_memory']=memory
                if 'follow_delay' in case:
                    follow=[x for x in log.splitlines() if x.startswith('FOLLOW ')]
                    if len(follow)!=1:errors.append('expected exactly one following-load observation')
                    else:
                        values=dict(x.split('=') for x in follow[0].split()[1:])
                        actual={n:int(v,10 if n=='clock' else 16) for n,v in values.items()};row['observed_follow']=actual
                        spec=case['data_store'];count=len(store_transactions(case));reads_count=((spec['address']&15)+spec['width']+15)//16
                        source_wait=len(copy_transactions(case)[0])*args.wait_states if 'data_copy' in case else 0
                        begin=(source_wait+max(spec['cpu']+case['follow_delay'],spec['cpu']-1+count*(2+args.wait_states)))*8+args.pause_clocks+(-args.pause_clocks)%8
                        expected=begin+reads_count*(16+8*args.wait_states)+8
                        if actual['clock']-observed['start']!=expected:errors.append(f'following dependent load: expected {expected} INCLK, observed {actual["clock"]-observed["start"]}')
                        for q,value in enumerate(case['expected_follow_regs']):
                            if actual[f'a{q}']!=value:errors.append(f'following load A{q} mismatch')
                        if actual['st']!=case['expected_follow_st']:errors.append('following load ST mismatch')
                if sorted(memory)!=sorted(case['expected_memory']):errors.append('memory after write drain differs from expected preserved field')
            rows.append(row)
            print(f"{case['name']}: {'FAIL' if errors else 'PASS'} ({case['citation']})")
            if errors:
                print('  ' + '; '.join(errors))
                print(f"  opcode={case['opcode']:04x} conditions={case['conditions']}")
                for line in row['bus_trace'][-12:]:
                    print('  ' + line)
                for line in row['target_trace'][-8:]:
                    print('  ' + line)
                if observed is None:
                    print('\n'.join(log.splitlines()[-12:]))
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(dict(clock_unit='INCLK', clocks_per_machine_state=8,
                                              target_ready_clocks=4+8*args.wait_states,
                                              bus_contract='TI two-state minimum; Q1 ready sampling; raw ready+data target transport',
                                              external_wait_states=args.wait_states,
                                              cpu_pause_clocks=args.pause_clocks,
                                              cpu_pause_after_clocks=args.pause_after_clocks,
                                              full_isa_coverage=False,
                                              simulation_mode='separate' if args.separate_processes else 'batch',
                                              simulator=args.simulator,
                                              elapsed_seconds=round(time.monotonic()-started, 3),
                                              provenance=provenance,
                                              cases=rows), indent=2) + '\n')
    failures = sum(bool(row['errors']) for row in rows)
    print(f'Timing: {len(rows)-failures} passed, {failures} failed, {len(rows)} total')
    print('Full ISA timing signoff remains open (#144); instruction/condition coverage is checked separately.')
    return int(failures != 0)


if __name__ == '__main__':
    sys.exit(main())
