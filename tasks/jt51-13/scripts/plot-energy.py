#!/usr/bin/env python3
"""Plot fixed-block public audio descriptors; never align or fit streams."""
import argparse, hashlib, json, platform
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--index',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();args.output.mkdir()
    index=json.loads(args.index.read_text());rows=index['rows'];pins={str(args.index):digest(args.index)}
    groups=sorted({r['group'] for r in rows if r['kind']=='target'})
    colors={'physical':'#1f77b4','jt51':'#d95f02','opm':'#238b45'}
    for latch in (0,1):
        fig,axes=plt.subplots(len(groups),2,figsize=(12,2.45*len(groups)),squeeze=False)
        for g,group in enumerate(groups):
            for column,condition in enumerate(('conditioned','preserved')):
                ax=axes[g,column]
                for source in ('physical','jt51','opm'):
                    chosen=[r for r in rows if r['kind']=='target' and r['group']==group and r['condition']==condition and r['source']==source and r['latch']==latch]
                    assert len(chosen)==3, (group,condition,source,latch,len(chosen))
                    for n,r in enumerate(chosen):
                        p=Path(r['descriptor']);pins[str(p)]=digest(p);data=json.loads(p.read_text())
                        blocks=data['fixed_1024_sample_blocks']
                        x=[b['start_seconds_relative_first_retained_sample']+b['sample_bin_duration_seconds']/2 for b in blocks]
                        y=[b['statistics']['RMS'] for b in blocks]
                        assert len(x)==16 and all(v is not None for v in y)
                        ax.plot(x,y,color=colors[source],alpha=.65,lw=1.2,label=source if n==0 else None)
                label='isolated' if group=='rastan-event' and condition=='conditioned' else condition
                ax.set_title(f'{group} — {label}',fontsize=10)
                ax.set_xlabel('seconds from each recording start')
                ax.set_ylabel('block RMS (serial PCM units)')
                ax.set_ylim(bottom=0);ax.grid(alpha=.25)
                if g==0 and column==0:ax.legend(fontsize=8)
        fig.suptitle(f'YM2151 replacement history: {"LEFT / latch0" if latch==0 else "RIGHT / latch1"}\nThree repetitions per stream; fixed 1024-sample blocks; independent recording origins',fontsize=12)
        fig.text(.5,.008,'Raw PCM descriptors only. No waveform alignment, phase fit, gain match or agreement tolerance. Whole-peak normalized energies remain separate in the reports.',ha='center',fontsize=8)
        fig.tight_layout(rect=(0,.02,1,.95))
        for extension in ('png','pdf'):fig.savefig(args.output/f'public-energy-latch{latch}.{extension}',dpi=150)
        plt.close(fig)
    report={'state':'PLOTS_RENDERED_FROM_FIXED_PUBLIC_DESCRIPTORS','python':platform.python_version(),'matplotlib':matplotlib.__version__,'script_sha256':digest(Path(__file__)),'inputs':pins,'outputs':{p.name:digest(p) for p in args.output.iterdir() if p.is_file()}}
    (args.output/'provenance.json').write_text(json.dumps(report,indent=2)+'\n')
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
if __name__=='__main__':main()
