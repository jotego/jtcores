#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""EMU RUN-high pulse contract, separate from original EMUA pin-phase timing.

The unchanged standard timing bench ties RUN high. Observe one one-clock
acknowledgement in the measured instruction, retain the exact TI selected
counts and all architectural/bus checks. RUN-low hold/resume stays open.
"""
import argparse,hashlib,json,shutil,subprocess,sys,tempfile
from pathlib import Path

HERE=Path(__file__).resolve().parent
MODULE=HERE.parents[1]
sys.dont_write_bytecode=True
sys.path.insert(0,str(HERE.parent))
from verilator_build import build_model
sys.path.insert(0,str(HERE.parent/'timing'))
from emu_cases import fixture
from run import program,parse_result,measured_trace,check,check_bus,check_target


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--report',type=Path)
    args=parser.parse_args();rows=[];models={}
    with tempfile.TemporaryDirectory(prefix='jttms10-emu-events-') as temp:
        work=Path(temp)
        subprocess.run(['bash',str(MODULE/'ver/build.sh'),str(work)],check=True,stdout=subprocess.DEVNULL)
        bench=HERE.parent/'timing/test.sv'
        def capture(name,off,pause,hdl):
            case=fixture(name,0xF0200FFF,off);words,start,end=program(case);case.update(test_pc=start,next_pc=end)
            image=[0]*4096;image[0x100:0x100+len(words)]=words
            (work/'program.mem').write_text(''.join(f'{w:04x}\n' for w in image))
            key=hdl.resolve()
            if key not in models:
                models[key]=build_model(work/('model'+str(len(models))),
                    [bench,HERE/'monitor.sv',*sorted(hdl.glob('*.v'))],
                    top='emu_events',includes=[work])
            result=subprocess.run([str(models[key]),'+PROGRAM=program.mem',f'+TEST_PC={start:x}',f'+NEXT_PC={end:x}','+MEASURE_PASS=1','+WATCH_EXTRA=1','+WAIT=8',f'+PAUSE={pause}'],cwd=work,capture_output=True,text=True,timeout=20)
            log=result.stdout+result.stderr;observed=parse_result(log)
            functional=[]
            for q,v in enumerate(case['expected_regs']):
                if observed['a'+str(q)]!=v:functional.append('A'+str(q)+' result mismatch')
            for n,v in case['expected_extra_regs'].items():
                if observed.get(n)!=v:functional.append(n+' result mismatch')
            if observed['st']!=case['expected_st']:functional.append('ST result mismatch')
            errors=check(case,observed,1,pause);traces={}
            for raw,checker in [(False,check_bus),(True,check_target)]:
                trace=measured_trace(log,'TARGET' if raw else 'BUS',observed)
                traces['target_trace' if raw else 'bus_trace']=trace
                errors+=checker(case,observed,trace,1,pause)
            if result.returncode:errors.append('simulator exit '+str(result.returncode))
            events=[int(s.split()[1]) for s in log.splitlines() if s.startswith('EMU_ACK ')]
            event_errors=[]
            if len(events)!=1:event_errors.append('expected one one-clock EMU acknowledgement')
            elif not observed['start']<events[0]<observed['end']:event_errors.append('EMU acknowledgement outside measured instruction')
            return dict(name=name,case=case,pause_clocks=pause,observed=observed,acknowledgements=events,functional_errors=functional,timing_bus_errors=errors,event_errors=event_errors,**traces)
        for off in (False,True):
            for pause in (0,1,6,7):
                name=f'control_{"off" if off else "hit"}_p{pause}'
                row=capture(name,off,pause,MODULE/'hdl');rows.append(row)
                if row['functional_errors'] or row['timing_bus_errors'] or row['event_errors']:raise RuntimeError(json.dumps(row,indent=2))
                print(name+': PASS (exact selected count, full state, ordered bus and one EMU pulse)')
        mutant=work/'missing-ack';shutil.copytree(MODULE/'hdl',mutant)
        p=mutant/'jttms10.v';text=p.read_text();old='if(emu_step) emu_ack<=1;';assert text.count(old)==1
        p.write_text(text.replace(old,'if(emu_step) emu_ack<=0;'))
        row=capture('missing_emu_ack',False,1,mutant);rows.append(row)
        if row['functional_errors'] or row['timing_bus_errors'] or row['event_errors']!=['expected one one-clock EMU acknowledgement']:raise RuntimeError(json.dumps(row,indent=2))
        print('missing_emu_ack: PASS (missing event rejected with correct timing and architectural state)')
        sources=[*sorted((MODULE/'hdl').glob('*.v')),*sorted((MODULE/'ucode').glob('*.yaml')),bench,HERE/'monitor.sv',HERE/'check.py',HERE.parent/'verilator_build.py',HERE.parent/'timing/emu_cases.py',HERE.parent/'timing/run.py',HERE.parent/'timing/oracle.py',HERE.parent/'timing/alu_cases.py',HERE.parent/'timing/scalar_cases.py']
        report=dict(simulator='verilator',compiled_models=len(models),contract='EMU RUN-high pulse; original EMUA pin phase and RUN-low hold/resume excluded',source_sha256={str(p.relative_to(MODULE)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},generated_sha256={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in work.iterdir() if p.suffix in ('.uc','.vh','.hex')},cases=rows)
        if args.report:args.report.write_text(json.dumps(report,indent=2)+'\n')
    return 0

if __name__=='__main__':raise SystemExit(main())
