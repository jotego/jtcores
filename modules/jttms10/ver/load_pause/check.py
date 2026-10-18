#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""CEN response-retention events, separate from exact TI instruction counts.

CEN is a CPU-only wrapper extension. Its pause overlaps an already-issued
external transfer here; the bus continues while CPU state must hold. The
normal timing runner separately requires the unpaused TI counts. This test
checks bus timing/order, exact paused-clock count, capture/resumption, all
initialized architectural registers and bounded completion, never claims
an overlapping CPU-only pause is a TI instruction timing figure.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

HERE=Path(__file__).resolve().parent
MODULE=HERE.parents[1]
sys.dont_write_bytecode=True
sys.path.insert(0,str(HERE.parent/'timing'))
from load_mode_cases import fixture
from run import program,parse_result,check_bus,check_target


def evaluate(case,log,returncode):
    observed=parse_result(log)
    functional=[]
    for q,value in enumerate(case['expected_regs']):
        if observed[f'a{q}']!=value:functional.append(f'A{q} result mismatch')
    for name,value in case['expected_extra_regs'].items():
        if observed.get(name)!=value:functional.append(name.upper()+' result mismatch')
    if observed['st']!=case['expected_st']:functional.append('ST result mismatch')
    errors=list(functional)
    if returncode:errors.append('simulator exit '+str(returncode))
    if observed['paused']!=32:errors.append('expected exactly 32 CPU-disabled clocks')
    # An overlapping CEN pause may hide CPU wait time. Keep a conservative
    # completion bound; exact TI duration is checked in the normal suite.
    minimum=case['states']*8+8  # one requested external wait on the sole read
    if not minimum<=observed['clocks']<=minimum+32+8:
        errors.append('completion outside base..base+pause+one-state alignment bound')
    records={name:[] for name in ('PAUSE_BEGIN','PAUSE_END','PAUSE_DATA_REQ','PAUSE_DATA_ACK')}
    for line in log.splitlines():
        tag=line.split()[0] if line.split() else ''
        if tag in records:records[tag].append(int(line.split()[1]))
    if any(len(v)!=1 for v in records.values()):errors.append('expected one request/pause/captured response/resume')
    elif not records['PAUSE_DATA_REQ'][0]<records['PAUSE_BEGIN'][0]<=records['PAUSE_DATA_ACK'][0]<records['PAUSE_END'][0]:
        errors.append('request must precede pause and response must be captured during it')
    bus=[s for s in log.splitlines() if s.startswith('BUS_')]
    target=[s for s in log.splitlines() if s.startswith('TARGET_')]
    # The one data cycle was allocated before pausing and retains its TI
    # two-state+wait timing. No opcode read occurs in this cached probe.
    errors+=check_bus(case,observed,bus,1,0)
    errors+=check_target(case,observed,target,1,0)
    return dict(name=case['name'],observed=observed,events=records,bus_trace=bus,
                target_trace=target,functional_errors=functional,errors=errors)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report',type=Path)
    args=parser.parse_args()
    rows=[]
    with tempfile.TemporaryDirectory(prefix='jttms10-response-pause-') as temp:
        work=Path(temp)
        subprocess.run(['bash',str(MODULE/'ver/build.sh'),str(work)],check=True,stdout=subprocess.DEVNULL)
        generated={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in work.iterdir() if p.suffix in ('.uc','.vh','.hex')}
        def run_case(case,name,hdl):
            words,start,following=program(case);case=dict(case,test_pc=start,next_pc=following)
            image=[0]*4096;image[0x100:0x100+len(words)]=words
            (work/'program.mem').write_text(''.join(f'{x:04x}\n' for x in image))
            (work/'data.mem').write_text(''.join(f'{a:08x} {v:04x}\n' for a,v in case['initial_memory']))
            binary=work/(name+'.vvp')
            compiled=subprocess.run(['iverilog','-g2012','-s','test','-I',str(work),'-o',str(binary),
                str(HERE.parent/'timing/test.sv'),*map(str,sorted(hdl.glob('*.v')))],capture_output=True,text=True)
            if compiled.returncode:raise RuntimeError(compiled.stdout+compiled.stderr)
            result=subprocess.run(['vvp',str(binary),'+PROGRAM=program.mem','+DATA=data.mem','+DATA_COUNT=3',
                '+WATCH_EXTRA=1','+CASE_ID=0','+MEASURE_PASS=1',f'+TEST_PC={start:x}',f'+NEXT_PC={following:x}',
                '+WAIT=8','+PAUSE=32','+PAUSE_AFTER=2','+RESPONSE_PAUSE'],cwd=work,capture_output=True,text=True,timeout=15)
            return evaluate(case,result.stdout+result.stderr,result.returncode)
        probes=[fixture('post',16,0,0,False,False,bank,source,dest,1,
                       tag=f'response_pause_r{bank}_{source}_{dest}')
                for bank,source,dest in ((0,15,0),(1,15,0),(1,15,15))]
        for q,case in enumerate(probes):
            row=run_case(case,'control'+str(q),MODULE/'hdl');row['kind']='positive-control';rows.append(row)
            if row['errors']:raise RuntimeError(json.dumps(row,indent=2))
            print(row['name']+': PASS (held CPU, captured response, ordered bus and correct resume)')
        mutant=work/'lost-response-hdl';shutil.copytree(MODULE/'hdl',mutant)
        path=mutant/'jttms10.v';source=path.read_text()
        site='if(!(load_pending || store_pending) || bus_op) completed<=0;'
        if source.count(site)!=1:raise RuntimeError('response-retention mutation site changed')
        path.write_text(source.replace(site,'completed<=0;'))
        row=run_case(probes[0],'lost_response',mutant);row.update(kind='mutation',mutation='lost_early_response',expected_rejection=True);rows.append(row)
        if row['functional_errors'] or not any('expected 1 physical instruction reads' in e for e in row['errors']):
            raise RuntimeError('lost-response mutation was not rejected by bus count with correct architecture:\n'+json.dumps(row,indent=2))
        print('lost_early_response: PASS (duplicate data read rejected; architectural state correct)')
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True)
        paths=[*sorted((MODULE/'hdl').glob('*.v')),*sorted((MODULE/'ucode').glob('*.yaml')),
               HERE.parent/'timing/test.sv',Path(__file__).resolve(),
               *[HERE.parent/'timing'/name for name in ('oracle.py','run.py','load_mode_cases.py','load_cases.py','alu_cases.py','scalar_cases.py')]]
        args.report.write_text(json.dumps(dict(contract='CPU-only CEN response retention; exact TI base counts are checked separately',
            generated_sha256=generated,source_sha256={str(p.relative_to(MODULE)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},cases=rows),indent=2)+'\n')
    return 0


if __name__=='__main__':raise SystemExit(main())
