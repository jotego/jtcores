#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""TI 11.4.2/8/10 bus state/ready-phase oracle, independent of the RTL.

Eight INCLK/state, four two-clock quarters: first LRDY sample is ten
clocks after the cycle's state boundary; data capture is in Q4 and the
cycle completes after sixteen clocks plus whole-state waits. The target
ACK is abstract readiness AND data, not a pre-timed two-state response.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

HERE=Path(__file__).resolve().parent
RTL=HERE.parents[1]/'hdl'/'jttms10_bus_timer.v'


def completion(start, ready, *, io=False):
    sample=start+10  # Q1 ends in the second state: TI Fig11-4, p11-8.
    waits=0 if io else max(0,(ready-sample+7)//8)
    return start+16+8*waits


def probes():
    for queued in (False,True):
        for phase in range(8):
            for latency in range(41):
                yield dict(queued=queued,phase=phase,latency=latency,io=False,block=0,held=0,second=False)
            for latency in (0,1000):
                yield dict(queued=queued,phase=phase,latency=latency,io=True,block=0,held=0,second=False)
    for phase in range(8):
        yield dict(queued=True,phase=phase,latency=4,io=False,block=20,held=0,second=False)
    for held in (1,8,32):
        yield dict(queued=False,phase=0,latency=2,io=False,block=0,held=held,second=True)


def verify(case,lines):
    rows=[]
    for line in lines.splitlines():
        if line.startswith('RESULT '):
            fields=dict(x.split('=') for x in line.split()[1:])
            rows.append({k:int(v,16 if k=='data' else 10) for k,v in fields.items()})
    if len(rows)!=1+int(case['second']):
        return [f'expected {1+int(case["second"])} results, observed {len(rows)}'],rows
    launch=8+case['phase']
    allowed=max(launch,case['block'])
    # Queued work can occupy the first state's bridge clocks, but may not
    # backdate before a HOLD release. New arrivals wait for a state boundary.
    boundary=(allowed//8)*8
    if not case['queued'] or boundary<case['block']:
        boundary=((allowed+7)//8)*8
    accept=allowed if case['queued'] and boundary<=allowed else boundary
    if not case['queued']:accept=boundary
    expected=completion(boundary,accept+case['latency'],io=case['io'])
    errors=[]
    first=rows[0]
    if (first['accept'],first['end'])!=(accept,expected):
        errors.append(f'expected accept/completion {accept}/{expected} INCLK, observed {first["accept"]}/{first["end"]}')
    for i,row in enumerate(rows):
        want=0x2222 if case['io'] else 0xA000+i
        if row['data']!=want:errors.append(f'data expected {want:04x}, observed {row["data"]:04x}')
        if row['targets']!=(0 if case['io'] else i+1):errors.append('external transaction count mismatch')
        if i:
            release=rows[0]['accept']+case['latency']+case['held']
            if row['accept']<release or row['accept']%8:
                errors.append('next request accepted before old ACK drained/state boundary')
            end=completion(row['accept'],row['accept']+case['latency'])
            if row['end']!=end:errors.append(f'second completion expected {end}, observed {row["end"]}')
    return errors,rows


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rtl',type=Path,default=RTL)
    parser.add_argument('--report',type=Path)
    parser.add_argument('--simulator',choices=('iverilog','verilator'),default='verilator')
    args=parser.parse_args()
    rows=[]
    with tempfile.TemporaryDirectory(prefix='jttms10-bus-timing-') as temp:
        def compile_bench(name,sources):
            if args.simulator=='iverilog':
                binary=Path(temp)/(name+'.vvp')
                command=['iverilog','-g2012','-s','test','-o',str(binary),*map(str,sources)]
                executable=['vvp',str(binary)]
            else:
                obj=Path(temp)/name
                command=['verilator','--binary','--timing','--top-module','test',
                         '--timescale-override','1ns/1ps','-j','4','--Mdir',str(obj),*map(str,sources)]
                executable=[str(obj/'Vtest')]
            result=subprocess.run(command,capture_output=True,text=True)
            if result.returncode:raise RuntimeError(result.stdout+result.stderr)
            return executable
        executable=compile_bench('timer',[HERE/'test.sv',args.rtl])
        for case in probes():
            command=[*executable,f'+LATENCY={case["latency"]}',f'+PHASE={case["phase"]}',
                     f'+BLOCK={case["block"]}',f'+HOLD_ACK={case["held"]}']
            command += ['+QUEUED'] if case['queued'] else []
            command += ['+IO'] if case['io'] else []
            command += ['+SECOND'] if case['second'] else []
            result=subprocess.run(command,capture_output=True,text=True,timeout=5)
            errors,observed=verify(case,result.stdout)
            if result.returncode:errors.append(f'simulator exit {result.returncode}: {result.stdout}{result.stderr}')
            rows.append(dict(conditions=case,observed=observed,errors=errors))
        executable=compile_bench('interference',[HERE/'interference.sv',RTL.with_name('jttms10_bus.v'),args.rtl])
        result=subprocess.run(executable,capture_output=True,text=True,timeout=5)
        if result.returncode or 'queued host I/O PASS' not in result.stdout:
            raise RuntimeError('timed arbiter integration failed:\n'+result.stdout+result.stderr)
        print(result.stdout.splitlines()[0])
    failed=[r for r in rows if r['errors']]
    for row in failed[:10]:print(row)
    print(f'TI bus timing: {len(rows)-len(failed)} passed, {len(failed)} failed, {len(rows)} scenarios')
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps(dict(source='SPVU001A pp.11-8,11-14,11-16',
            simulator=args.simulator,
            note='Abstract ready+data transport; original LAD/control pins are not generated.',
            io_latch_policy='Q4 model choice; TI specifies two states and ignored LRDY, not the internal I/O register latch edge.',
            source_sha256={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in
                           (args.rtl,RTL.with_name('jttms10_bus.v'),HERE/'test.sv',HERE/'interference.sv',Path(__file__))},
            interference_log=result.stdout,
            cases=rows),indent=2)+'\n')
    return int(bool(failed))


if __name__=='__main__':raise SystemExit(main())
