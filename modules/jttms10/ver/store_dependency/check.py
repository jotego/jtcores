#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check CD store/fetch dependencies through the timed system in Verilator."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
MODULE=HERE.parents[1]
sys.path.insert(0, str(HERE.parent))
from verilator_build import build_model
sys.path.insert(0, str(HERE.parent/'timing'))
import run
from cases import cases, transfers


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


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rtl-dir', type=Path, default=MODULE/'hdl')
    parser.add_argument('--report', type=Path)
    parser.add_argument('--traces', type=Path)
    args=parser.parse_args()
    hdl=args.rtl_dir.resolve()
    if not (hdl/'jttms10.v').is_file():parser.error('missing CPU HDL')
    prepared=list(cases())
    if len(prepared)!=16:raise RuntimeError('dependency fixture inventory changed')
    rows=[]
    if args.traces:args.traces.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='jttms10-cd-dependency-') as temp:
        work=Path(temp)
        subprocess.run(['bash', str(MODULE/'ver/build.sh'), str(work)],
                       check=True, stdout=subprocess.DEVNULL)
        generated={p.name:hashlib.sha256(p.read_bytes()).hexdigest()
                   for p in work.iterdir() if p.suffix in ('.uc','.vh','.hex')}
        bench=HERE.parent/'timing/test.sv'
        model=build_model(work/'obj', [bench,*sorted(hdl.glob('*.v'))], includes=[work])
        if args.traces:(args.traces/'compile.log').write_bytes((work/'obj/build.log').read_bytes())
        (work/'cases.txt').write_text(''.join(
            f"{i} {c['test_pc']:x} {c['next_pc']:x} 0 {len(words)} {len(c['initial_memory'])} 3 -2 0 "+
            ' '.join(f'{w:04x}' for w in words)+' '+
            ' '.join(f'{a:08x} {v:04x}' for a,v in c['initial_memory'])+'\n'
            for i,(c,words) in enumerate(prepared)))
        for profile,wait,pause in [('base',0,0),('w1',1,0),('w3',3,0),('w1p1',1,1),('w1p7',1,7)]:
            argv=[str(model), '+BATCH=cases.txt', f'+WAIT={wait*8}',
                  f'+PAUSE={pause}', '+RESPONSE_PAUSE']
            result=run.simulate(argv,work,30)
            log=result.stdout+result.stderr
            if args.traces:(args.traces/(profile+'.log')).write_text(log)
            try:chunks=run.split_transcripts(log,list(range(16)),batch=True)
            except ValueError as error:
                rows.append(dict(profile=profile,name='batch',errors=[str(error),f'simulator exit {result.returncode}']))
                continue
            for identifier,(case,words) in enumerate(prepared):
                text=chunks[identifier]
                errors=[]
                try:
                    observed=run.parse_result(text)
                    errors+=run.check(case,observed,wait,pause,check_duration=False)
                    if observed['case']!=identifier:errors.append('case identifier mismatch')
                    memory=sorted((int(s.split()[1],16),int(s.split()[2],16))
                                  for s in text.splitlines() if s.startswith('MEMORY '))
                    if memory!=sorted(case['expected_memory']):errors.append('drained memory mismatch')
                    opcodes=[int(s.split()[1],16) for s in text.splitlines() if s.startswith('NEXT_OPCODE ')]
                    if opcodes!=[case['expected_next_opcode']]:errors.append('modified opcode observation mismatch')
                    bus=run.measured_trace(text,'BUS',observed,trailing=True)
                    target=run.measured_trace(text,'TARGET',observed,trailing=True)
                    errors+=check_trace(case,bus,wait)+check_trace(case,target,wait,raw=True)
                    logical=[s.split() for s in bus if s.startswith('BUS_BEGIN ')]
                    physical=[s.split() for s in target if s.startswith('TARGET_BEGIN ')]
                    if len(logical)==len(physical):
                        for b,t in zip(logical,physical):
                            if not int(b[1])<=int(t[1])<=int(b[1])+6:
                                errors.append('target dispatch outside physical cycle readiness window')
                    if result.returncode:errors.append(f'simulator exit {result.returncode}')
                    rows.append(dict(name=case['name'],profile=profile,wait_states=wait,
                        pause_clocks=pause,fixture=case,observed=observed,
                        observed_memory=memory,observed_next_opcodes=opcodes,
                        bus_trace=bus,target_trace=target,errors=errors))
                except (KeyError,ValueError) as error:
                    rows.append(dict(name=case['name'],profile=profile,errors=[str(error)]))
    sources=[*sorted(hdl.glob('*.v')),*sorted((MODULE/'ucode').glob('*.yaml')),
             *sorted((HERE.parent/'timing').glob('*.py')),bench,HERE/'cases.py',HERE/'check.py',HERE.parent/'verilator_build.py']
    report=dict(simulator='verilator',scope='CD architectural/fetch dependency and physical bus checks only; no instruction-duration or cached self-modification signoff',
        source_sha256={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},
        generated_sha256=generated,cases=rows,passed=sum(not r['errors'] for r in rows),failed=sum(bool(r['errors']) for r in rows))
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps(report,indent=2)+'\n')
    for row in rows:
        if row['errors']:
            print(row['profile'],row['name']+': FAIL', '; '.join(row['errors']))
            print('\n'.join(row.get('bus_trace',[])[-12:]))
    print(f"CD store/fetch dependencies: {report['passed']} passed, {report['failed']} failed")
    return int(bool(report['failed']))


if __name__=='__main__':
    sys.exit(main())
