#!/usr/bin/env python3
"""Reacquire the natural replacement event with its full finite recording horizon."""
import argparse, contextlib, fcntl, hashlib, json, subprocess, sys, time
from pathlib import Path
import history_frontend as history
import monitor
from pico_link import Pico
ROOT=Path(__file__).resolve().parents[1]
BOOT='649a7930d90807890c8e60bdc7c26b59b6be1833223ff61bd7a93a9d49b51775'
def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--execute',action='store_true',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    folder=a.output.resolve();folder.mkdir();replay=ROOT/'artifacts/replay-01';controlled=ROOT/'artifacts/controlled-02'
    manifest=history.load_history(replay/'history.tsv');cases=[]
    for i in range(3):
        cases.append({'name':f'rastan-event-preserved-r{i}','init':str(controlled/'end.bin'),'event':str(replay/'natural-event.bin'),'stride':3,'history':True,'purpose':'Complete natural EVENT and post-tail after every replacement prefix write; longer-window reacquisition'})
        cases.append({'name':f'rastan-event-isolated-r{i}','init':str(replay/'natural-fresh-init.bin'),'event':str(replay/'natural-fresh-event.bin'),'stride':3,'history':False,'purpose':'Isolated selected natural ALG0 program; matched longer-window control'})
    with (folder/'cases.json').open('x') as f:json.dump(cases,f,indent=2)
    report={'state':'started','started_host_monotonic':time.monotonic(),'cases':[],'runner_sha256':history.file_hash(__file__)}
    history.save(folder/'results.json',report)
    try:
        for i,c in enumerate(cases):
            row={'case':c,'state':'started','capture_id':73500+i*2};report['cases'].append(row);history.save(folder/'results.json',report)
            needed=3*len(manifest['chunks'])+12 if c['history'] else 12
            with (ROOT/'artifacts/monitor.lock').open('w') as lock:
                fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB);pico=Pico(monitor.NAME)
                try:
                    events=pico.events(monitor.BASE)
                    if events['count']+needed+12>=4096:
                        rearm=folder/(c['name']+'-rearm.json');monitor.rearm(pico,rearm);row['rearm']=str(rearm);events=pico.events(monitor.BASE)
                    if c['history']:
                        state_path=ROOT/'artifacts/monitor-state.json';state=monitor.load_state()
                        binding={'authorized_by':'/root','authorize_history_once':True,'frontend_sha256':history.file_hash(history.__file__),'history_sha256':manifest['sha256'],'initial_state_sha256':history.file_hash(state_path),'initial_generation':state['generation'],'initial_markers':events['count'],'expected_boot_bank_sha256':BOOT,'reserve_markers':18}
                        bp=folder/(c['name']+'-binding.json')
                        with bp.open('x') as f:json.dump(binding,f,indent=2)
                        hp=folder/(c['name']+'-history.json');history.execute(manifest,ROOT,hp,binding,monitor,pico);row['history_report']=str(hp)
                finally:pico.close()
            for quiet in (False,True):
                name=c['name']+('-quiet' if quiet else '-capture');prefix=folder/name
                init=replay/'quiet.bin' if quiet else Path(c['init']);event=controlled/'end.bin' if quiet else Path(c['event'])
                command=[sys.executable,str(ROOT/'scripts/capture-event.py'),str(init),str(event),str(prefix),'--capture-id',str(row['capture_id']+int(quiet)),'--stride',str(c['stride']),'--settle','0.001']
                with prefix.with_suffix('.runner.log').open('x') as log:subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,check=True)
                result=json.loads(prefix.with_suffix('.json').read_text());assert result['state']=='complete'
                channels=result['analysis']['latch_channels'];assert all(x['invalid_exponent']==0 for x in channels)
                if quiet:assert all(x['minimum']==0 and x['maximum']==0 for x in channels),'whole quiet failed'
                else:assert any(x['rms']>0 for x in channels),'silent target'
                row['quiet_report' if quiet else 'capture_report']=str(prefix.with_suffix('.json'))
            row['state']='complete';history.save(folder/'results.json',report);print(json.dumps({'completed':i+1,'total':len(cases),'case':c['name']}),flush=True)
        report.update(state='complete',finished_host_monotonic=time.monotonic());history.save(folder/'results.json',report)
    except BaseException as error:
        report.update(state='failed',error=repr(error),finished_host_monotonic=time.monotonic());history.save(folder/'results.json',report);raise
if __name__=='__main__':main()
