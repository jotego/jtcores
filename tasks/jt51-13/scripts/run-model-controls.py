#!/usr/bin/env python3
"""Run finite positive/whole-quiet controls on the qualified public wrappers."""
import concurrent.futures, hashlib, json, subprocess, sys, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    folder=ROOT/'artifacts/model-controls-01';folder.mkdir()
    qualified=json.loads((ROOT/'artifacts/model-history-validation/handoff.json').read_text())
    binaries=qualified['actually_executed_new_executables']
    for path,expected in binaries.items():assert digest(Path(path))==expected
    replay=ROOT/'artifacts/replay-01';end=ROOT/'artifacts/controlled-02/end.bin';jobs=[]
    for model in ('jt51','opm'):
        binary=next(Path(p) for p in binaries if ('/jt51-build/' in p)==(model=='jt51'))
        for stride in (1,3,32):
            for kind in ('positive','quiet'):
                name=f'{model}-{kind}-stride{stride}';init=replay/('positive-mul8.bin' if kind=='positive' else 'quiet.bin');event=replay/'positive-event.bin' if kind=='positive' else end
                schedule=folder/(name+'.tsv');schedule.write_text('program\tgap_before_master_clocks\n'+str(init)+'\t0\n'+str(end)+'\t358000\n')
                output=folder/(name+'.csv');command=[str(binary),'--history',str(schedule),'--delay-clocks','37.5','--stride',str(stride),'--event',str(end),str(event),str(output),'16384']
                jobs.append({'name':name,'model':model,'kind':kind,'stride':stride,'command':command,'output':str(output),'inputs':{str(p):digest(p) for p in (binary,init,end,event,schedule)}})
    (folder/'binding.json').write_text(json.dumps({'authorized_by':'/root','runner_sha256':digest(Path(__file__)),'jobs':jobs},indent=2)+'\n')
    def run(job):
        for p,h in job['inputs'].items():assert digest(Path(p))==h
        start=time.monotonic()
        with (folder/(job['name']+'.log')).open('x') as log:r=subprocess.run(job['command'],stdout=log,stderr=subprocess.STDOUT,timeout=300)
        result=dict(job,exit_status=r.returncode,seconds=time.monotonic()-start)
        result['files']={str(p):digest(p) for p in folder.glob(job['name']+'.csv*')}
        with (folder/(job['name']+'.json')).open('x') as f:json.dump(result,f,indent=2)
        assert r.returncode==0,job['name']
        print(json.dumps({'completed':job['name'],'seconds':result['seconds']}),flush=True);return result
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(run,jobs))
    (folder/'results.json').write_text(json.dumps({'state':'ALL_CONTROL_PROCESSES_TERMINAL_ZERO','results':results},indent=2)+'\n')
if __name__=='__main__':main()
