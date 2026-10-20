#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Short Verilator checks of CD MOVB following loads and HOLD/restart."""
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
sys.path[:0]=[str(HERE.parent/'timing'),str(HERE.parent)]
import run
from byte_store_event_oracle import check_observation
from byte_events_cases import following_cases,hold_cases
from verilator_build import build_model


def check_reference_events(log,observed,phase):
    """Check the behavioral scheduler against its requested event table."""
    errors=[]
    applied=[s.split() for s in log.splitlines() if s.startswith('STIMULUS ')]
    wanted=[] if phase is None else [(0,phase,4),(4,3,0)]
    actual=[(int(s[3]),int(s[4],16),int(s[5],16)) for s in applied]
    if actual!=wanted or [int(s[2]) for s in applied]!=list(range(len(wanted))):
        errors.append('reference applied event table differs from requested stimulus')
    holds=[(int(s.split()[1]),int(s.split()[2])) for s in log.splitlines() if s.startswith('HOLD_ACK ')]
    if phase is not None and len(applied)==2:
        if int(applied[0][1])!=observed['start']+phase+1:
            errors.append('reference HOLD request clock differs from configured phase')
        if len(holds)!=2 or int(applied[1][1])!=holds[0][0]+3:
            errors.append('reference HOLD release differs from acknowledged-clock checkpoint')
    external=[s for s in log.splitlines() if s.startswith('EXTERNAL_RESULT ')]
    if len(external)!=1:return errors+['missing or duplicate external scheduler result']
    fields={k:int(v) for k,v in (item.split('=') for item in external[0].split()[1:])}
    hold_clocks=holds[1][0]-holds[0][0] if len(holds)==2 else 0
    writes=sum(s.startswith('TARGET_END ') and s.split()[2]=='1' and int(s.split()[1])>observed['start'] for s in log.splitlines())
    wanted_fields=dict(configured=len(wanted),applied=len(wanted),writes=writes,
                       holds=hold_clocks,hosts=0,issued=0,error=0,paused=0)
    if any(fields.get(k)!=v for k,v in wanted_fields.items()):
        errors.append('reference scheduler completion counters differ from physical trace')
    return errors


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rtl-dir',type=Path,default=MODULE/'hdl')
    parser.add_argument('--report',type=Path)
    parser.add_argument('--traces',type=Path)
    parser.add_argument('--kind',choices=('following','hold','all'),default='all')
    args=parser.parse_args()
    hdl=args.rtl_dir.resolve()
    if not (hdl/'jttms10.v').is_file():parser.error('missing CPU HDL')
    if args.traces:args.traces.mkdir(parents=True,exist_ok=True)
    rows=[]
    with tempfile.TemporaryDirectory(prefix='jttms10-byte-events-') as temp:
        work=Path(temp)
        subprocess.run(['bash',str(MODULE/'ver/build.sh'),str(work)],check=True,stdout=subprocess.DEVNULL)
        sources=[HERE.parent/'timing/test.sv',HERE.parent/'fpga/reference_irq.sv',
                 HERE.parent/'fpga/reference_stimulus.sv',*sorted(hdl.glob('*.v'))]
        provenance=[*sources,*sorted((MODULE/'ucode').glob('*.yaml')),
                    *sorted((HERE.parent/'timing').glob('*.py')),
                    HERE/'byte_events_cases.py',Path(__file__),HERE.parent/'verilator_build.py',HERE.parent/'build.sh']
        source_sha256={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in provenance}
        model=build_model(work/'obj',sources,includes=[work],defines=['JTTMS10_EXTERNAL_REFERENCE'])
        if args.traces:(args.traces/'compile.log').write_bytes((work/'obj/build.log').read_bytes())
        generated={p.name:hashlib.sha256(p.read_bytes()).hexdigest()
                   for p in work.iterdir() if p.suffix in ('.uc','.vh','.hex')}
        groups=[]
        if args.kind!='hold':groups.append(('following',list(following_cases()),
            [(name,wait,pause,None) for name,wait,pause in
             [('base',0,0),('w1',1,0),('w3',3,0),('w1p1',1,1),('w1p7',1,7)]]))
        if args.kind!='following':groups.append(('hold',list(hold_cases()),
            [(f'w{wait}h{phase}',wait,0,phase) for wait in (0,1) for phase in (0,8,24,40,52)]))
        for kind,prepared,profiles in groups:
            if len(prepared)!=(16 if kind=='following' else 4):raise RuntimeError('byte-event fixture inventory changed')
            (work/'cases.txt').write_text(''.join(
                f"{i} {c['test_pc']:x} {c['next_pc']:x} 0 {len(words)} {len(c['initial_memory'])} 7 {c['drain_instructions']} {c.get('follow_pc',0):x} "+
                ' '.join(f'{w:04x}' for w in words)+' '+
                ' '.join(f'{a:08x} {v:04x}' for a,v in c['initial_memory'])+'\n'
                for i,(c,words) in enumerate(prepared)))
            for profile,wait,pause,phase in profiles:
                (work/'events.txt').write_text('0\n' if phase is None else f'2\n0 {phase:x} 4\n4 3 0\n')
                argv=[str(model),'+BATCH=cases.txt',f'+WAIT={wait*8}',f'+PAUSE={pause}',
                      '+RESPONSE_PAUSE','+EXTERNAL_EVENTS=events.txt']
                result=run.simulate(argv,work,30);log=result.stdout+result.stderr
                if args.traces:(args.traces/(kind+'-'+profile+'.log')).write_text(log)
                try:chunks=run.split_transcripts(log,list(range(len(prepared))),batch=True)
                except ValueError as error:
                    rows.append(dict(kind=kind,profile=profile,name='batch',errors=[str(error),f'simulator exit {result.returncode}']))
                    continue
                for identifier,(case,words) in enumerate(prepared):
                    text=chunks[identifier]
                    try:
                        observed=run.parse_result(text)
                        row=check_observation(case,observed,text,wait,pause)
                        row['errors']+=run.check(case,observed,wait,pause,check_duration=kind=='following')
                        if observed['case']!=identifier:row['errors'].append('case identifier mismatch')
                        if result.returncode:row['errors'].append(f'simulator exit {result.returncode}')
                        row['errors']+=check_reference_events(text,observed,phase)
                        row.update(name=case['name'],kind=kind,profile=profile,
                            wait_states=wait,pause_clocks=pause,hold_phase=phase,
                            fixture=case,observed=observed)
                        row['byte_store_event_profile']=(dict(kind=kind,hold_phase=phase)
                            if kind=='hold' else dict(kind=kind))
                    except (KeyError,ValueError) as error:
                        row=dict(name=case['name'],kind=kind,profile=profile,errors=[str(error)])
                    rows.append(row)
        if any(hashlib.sha256(Path(p).read_bytes()).hexdigest()!=digest for p,digest in source_sha256.items()):
            raise RuntimeError('source changed during byte-event validation')
        report=dict(simulator='verilator',
            scope='CD byte-store nominal/following-load duration and complete bus/HOLD restart; HOLD-adjusted instruction duration and IRQ acceptance remain unqualified',
            source_sha256=source_sha256,
            generated_sha256=generated,cases=rows,
            passed=sum(not r['errors'] for r in rows),failed=sum(bool(r['errors']) for r in rows))
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps(report,indent=2)+'\n')
    for row in rows:
        if row['errors']:
            print(row['kind'],row['profile'],row['name']+': FAIL','; '.join(row['errors']))
            print('\n'.join(row.get('bus_trace',[])[-12:]))
    print(f"CD byte-store events: {report['passed']} passed, {report['failed']} failed")
    return int(bool(report['failed']))


if __name__=='__main__':
    sys.exit(main())
