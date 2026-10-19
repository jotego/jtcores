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
from stack_cases import popst_fixture
from return_cases import rets_fixture
from interrupt_return_cases import reti_fixture
from trap_cases import fixture as trap_fixture,transactions as trap_transactions
from list_cases import fixture as list_fixture,transfers as list_transfers,wait_count as list_wait_count
from pixel_read_cases import fixture as pixel_fixture
from pixel_xy_read_cases import fixture as xy_pixel_fixture
from pixel_store_cases import fixture as pixel_store_fixture
from pixel_boolean_cases import fixture as boolean_fixture
from pixel_copy_cases import fixture as copy_pixel_fixture
from pixel_xy_store_cases import fixture as xy_store_fixture
from draw_cases import fixture as draw_fixture
from pixel_xy_copy_cases import fixture as xy_copy_fixture
from copy_cases import transactions as copy_transactions
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
    pause=case.get('response_pause_clocks',32)
    if observed['paused']!=pause:errors.append(f'expected exactly {pause} CPU-disabled clocks')
    # An overlapping CEN pause may hide CPU wait time. Keep a conservative
    # completion bound; exact TI duration is checked in the normal suite.
    if 'data_list' in case:count=list_wait_count(case)
    elif 'data_trap' in case:count=len(trap_transactions(case))
    elif 'data_copy' in case:count=len(copy_transactions(case)[0])
    elif (case.get('pixel_store') or (case.get('pixel_xy_store') or case.get('pixel_draw'))):count=0  # Cached posted CPU work does not charge data waits.
    else:
        data=case['data_load'];fields=case.get('stack_fields',[data])
        count=sum(((f['address']&15)+f['width']+15)//16 for f in fields)
    minimum=case['states']*8+count*8  # one wait on every physical transfer
    if not minimum<=observed['clocks']<=minimum+pause+8:
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
    # The field was accepted before pausing; every word retains its TI
    # two-state+wait timing. No opcode read occurs in these cached probes.
    bus_case=case
    if 'data_copy' in case and all(len(v)==1 for v in records.values()):
        # This CPU-only pause overlaps the destination read. Its response
        # is retained while disabled; processing/posting waits for resume.
        # The first available bus boundary after resume owns the write.
        # Base intrinsic/read/post timing remains asserted by timing/run.py.
        resume=records['PAUSE_END'][0]-observed['start']
        read_waits=len(copy_transactions(case)[0])  # one external wait each
        first_write=max(case['data_copy']['write_start']+read_waits,(resume+7)//8)
        bus_case=dict(case,data_copy=dict(case['data_copy'],write_start=first_write-read_waits))
    errors+=check_bus(bus_case,observed,bus,1,0)
    errors+=check_target(bus_case,observed,target+(bus if case.get('stack_load') or 'data_trap' in case or 'data_list' in case else []),1,0)
    if case.get('stack_control_flow') or case.get('trap_flow'):
        opcodes=[int(s.split()[1],16) for s in log.splitlines() if s.startswith('NEXT_OPCODE ')]
        if opcodes!=[case['expected_next_opcode']]:errors.append('response-resume target opcode mismatch')
    if 'expected_memory' in case:
        memory=[(int(s.split()[1],16),int(s.split()[2],16)) for s in log.splitlines() if s.startswith('MEMORY ')]
        if sorted(memory)!=sorted(case['expected_memory']):errors.append('memory after response resume mismatch')
    return dict(name=case['name'],event_kind='posted-memory-response' if (case.get('pixel_store') or (case.get('pixel_xy_store') or case.get('pixel_draw'))) else 'logical-field-response',observed=observed,events=records,bus_trace=bus,
                target_trace=target,functional_errors=functional,errors=errors)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report',type=Path)
    parser.add_argument('--case',help='run matching controls plus the duplicate-response positive control')
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
            posted=bool((case.get('pixel_store') or (case.get('pixel_xy_store') or case.get('pixel_draw'))))
            top='posted_response' if posted else 'test'
            observers=[str(HERE/'posted.sv')] if posted else []
            compiled=subprocess.run(['iverilog','-g2012','-s',top,'-I',str(work),'-o',str(binary),
                str(HERE.parent/'timing/test.sv'),*observers,*map(str,sorted(hdl.glob('*.v')))],capture_output=True,text=True)
            if compiled.returncode:raise RuntimeError(compiled.stdout+compiled.stderr)
            result=subprocess.run(['vvp',str(binary),'+PROGRAM=program.mem','+DATA=data.mem',f'+DATA_COUNT={len(case["initial_memory"])}',
                f'+WATCH_EXTRA={13 if case.get("observe_all") else 3 if case.get("stack_control_flow") or case.get("trap_flow") else 1}','+CASE_ID=0',f'+MEASURE_PASS={case.get("measure_pass",1)}',f'+TEST_PC={start:x}',f'+NEXT_PC={following:x}',
                '+WAIT=8',f'+PAUSE={case.get("response_pause_clocks",32)}',f'+PAUSE_AFTER={case.get("response_pause_after",2)}',f'+DRAIN_INSTRUCTIONS={case.get("drain_instructions",0)}','+RESPONSE_PAUSE'],cwd=work,capture_output=True,text=True,timeout=15)
            return evaluate(case,result.stdout+result.stderr,result.returncode)
        probes=[fixture('post',16,0,0,False,False,bank,source,dest,1,
                       tag=f'response_pause_r{bank}_{source}_{dest}')
                for bank,source,dest in ((0,15,0),(1,15,0),(1,15,15))]
        for offset in (0,15):
            case=popst_fixture(f'response_pause_o{offset}',False,offset,15)
            case['response_pause_clocks']=96
            probes.append(case)
        for offset in (0,15):
            case=rets_fixture(f'response_pause_o{offset}',False,offset,n=31)
            case['response_pause_clocks']=96
            probes.append(case)
        for offset in (0,15):
            case=reti_fixture(f'response_pause_o{offset}',False,offset,15)
            case['response_pause_clocks']=160
            probes.append(case)
        for n in (0,31):
            for offset in (0,15):
                case=trap_fixture(n,False,offset,tag='response_pause')
                case['response_pause_clocks']=96 if not n else 160
                case['response_pause_after']=2 if not n else 12
                probes.append(case)
        for load in (False,True):
            for offset in (0,15):
                case=list_fixture(load,False,offset,(0,2,14,15),bank=int(bool(offset)),tag='response_pause')
                case['response_pause_clocks']=256
                case['response_pause_after']=20 if load else 92 if offset else 44
                probes.append(case)
        for size in (1,16):
            for bank in (0,1):
                case=pixel_fixture(size,16-size,bank,False,pmask=0x5555,tag='response_pause')
                case['response_pause_clocks']=96
                case['response_pause_after']=12
                probes.append(case)
        for size in (1,16):
            for bank in (0,1):
                case=xy_pixel_fixture(size,16-size,bank,False,pmask=0x5555,
                    source=4 if bank else 2,tag='response_pause')
                case['response_pause_clocks']=96
                case['response_pause_after']=28
                probes.append(case)
        for size in (1,16):
            for bank in (0,1):
                case=pixel_store_fixture(size,16-size,bank,False,tag='response_pause')
                case['response_pause_clocks']=96
                case['response_pause_after']=9
                probes.append(case)
        for size in (1,16):
            for bank in (0,1):
                case=boolean_fixture(size,16-size,bank,False,ppop=10,tag='response_pause')
                case['response_pause_clocks']=96
                case['response_pause_after']=12
                probes.append(case)
        for size in (1,16):
            for bank in (0,1):
                case=copy_pixel_fixture(size,0,16-size,bank,False,tag='response_pause')
                case['response_pause_clocks']=96
                case['response_pause_after']=12
                probes.append(case)
        for size in (1,16):
            for bank in (0,1):
                case=xy_store_fixture(size,16-size,bank,False,tag='response_pause')
                case['response_pause_clocks']=96
                case['response_pause_after']=25
                probes.append(case)
        for size in (1,16):
            for bank in (0,1):
                case=draw_fixture(size,16-size,bank,False,tag='response_pause')
                case['response_pause_clocks']=96
                case['response_pause_after']=25
                probes.append(case)
        for size in (1,16):
            for bank in (0,1):
                case=xy_copy_fixture(size,0,16-size,bank,False,tag='response_pause')
                case['response_pause_clocks']=96
                case['response_pause_after']=28
                probes.append(case)
        if args.case:
            selected=[case for case in probes if args.case in case['name']]
            if not selected:parser.error('no matching response-pause controls')
            probes=selected if probes[0] in selected else [probes[0],*selected]
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
               HERE.parent/'timing/test.sv',HERE/'posted.sv',Path(__file__).resolve(),
               *[HERE.parent/'timing'/name for name in ('oracle.py','run.py','load_mode_cases.py','load_cases.py','alu_cases.py','scalar_cases.py','stack_cases.py','return_cases.py','interrupt_return_cases.py','store_cases.py','trap_cases.py','list_cases.py','pixel_read_cases.py','pixel_xy_read_cases.py','pixel_store_cases.py','pixel_boolean_cases.py','pixel_copy_cases.py','pixel_xy_store_cases.py','draw_cases.py','pixel_xy_copy_cases.py','copy_cases.py')]]
        args.report.write_text(json.dumps(dict(contract='CPU-only CEN: logical field response or posted memory response; exact TI base counts checked separately',
            generated_sha256=generated,source_sha256={str(p.relative_to(MODULE)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},cases=rows),indent=2)+'\n')
    return 0


if __name__=='__main__':raise SystemExit(main())
