#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check CD store/fetch dependencies through the timed system in Verilator."""
import argparse
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
from store_dependency_oracle import check_trace, check_bus


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
                    errors+=check_bus(case,observed,bus,wait,pause)
                    errors+=check_bus(case,observed,target+bus,wait,pause,raw=True)
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
