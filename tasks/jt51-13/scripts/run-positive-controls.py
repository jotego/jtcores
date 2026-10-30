#!/usr/bin/env python3
"""Complete three positive/quiet pairs per retained native stride."""
import json, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    folder=ROOT/'artifacts/physical-positive-controls-02';folder.mkdir()
    replay=ROOT/'artifacts/replay-01';end=ROOT/'artifacts/controlled-02/end.bin';rows=[]
    baseline=ROOT/'artifacts/physical-controls/positive-02.json'
    rows.append({'stride':1,'repeat':0,'capture_report':str(baseline),'quiet_report':str(ROOT/'artifacts/physical-controls/quiet-01.json'),'state':'complete','scope':'Earlier same-geometry positive/quiet qualification; quiet precedes positive'})
    jobs=[(stride,r) for stride in (1,3,32) for r in range(3) if (stride,r)!=(1,0)]
    report={'state':'started','rows':rows}
    def save():
        p=folder/'results.new';p.write_text(json.dumps(report,indent=2)+'\n');p.replace(folder/'results.json')
    save()
    try:
        for i,(stride,repeat) in enumerate(jobs):
            row={'stride':stride,'repeat':repeat,'state':'started'};rows.append(row);save()
            for quiet in (False,True):
                prefix=folder/f'{"quiet" if quiet else "positive"}-stride{stride}-r{repeat}'
                init=replay/'quiet.bin' if quiet else replay/'positive-mul8.bin';event=end if quiet else replay/'positive-event.bin'
                cmd=[sys.executable,str(ROOT/'scripts/capture-event.py'),str(init),str(event),str(prefix),'--capture-id',str(73600+2*i+int(quiet)),'--stride',str(stride),'--settle','0.001']
                with prefix.with_suffix('.runner.log').open('x') as f:subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,check=True)
                data=json.loads(prefix.with_suffix('.json').read_text());assert data['state']=='complete'
                channels=data['analysis']['latch_channels'];assert all(c['invalid_exponent']==0 for c in channels)
                if quiet:assert all(c['minimum']==0 and c['maximum']==0 for c in channels)
                else:assert all(c['minimum']<0<c['maximum'] and c['rms']>0 for c in channels)
                row['quiet_report' if quiet else 'capture_report']=str(prefix.with_suffix('.json'));save()
            row['state']='complete';save();print(json.dumps({'complete':i+1,'total':len(jobs),'stride':stride,'repeat':repeat}),flush=True)
        report['state']='complete';save()
    except BaseException as e:report.update(state='failed',error=repr(e));save();raise
if __name__=='__main__':main()
