#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Reject actual lost-HOLD-restart and late-dependent-load RTL mutations."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
MODULE=HERE.parents[1]


def execute(work,name,kind,hdl):
    report=work/(name+'.json')
    argv=[sys.executable,'-B',str(HERE/'check_byte_events.py'),'--kind',kind,
          '--rtl-dir',str(hdl),'--report',str(report),'--traces',str(work/(name+'-traces'))]
    result=subprocess.run(argv,capture_output=True,text=True,timeout=120)
    (work/(name+'.log')).write_text(result.stdout+result.stderr)
    if not report.is_file():raise RuntimeError(name+': missing mutation report\n'+result.stdout+result.stderr)
    data=json.loads(report.read_text())
    if len(data['cases'])!=dict(all=120,hold=40,following=80)[kind]:
        raise RuntimeError(name+': incomplete case inventory')
    for row in data['cases']:
        case=row['fixture'];obs=row['observed']
        if obs['st']!=case['expected_st'] or any(obs.get(f'a{q}')!=v for q,v in enumerate(case['expected_regs'])):
            raise RuntimeError(name+': functional failure is not successful timing/protocol detection')
        if any(obs.get(key)!=value for key,value in case['expected_extra_regs'].items()):
            raise RuntimeError(name+': implicit architectural state changed')
        if sorted(map(tuple,row['observed_memory']))!=sorted(map(tuple,case['expected_memory'])):
            raise RuntimeError(name+': memory changed')
        if kind=='following':
            follow=row['observed_follow']
            if follow['st']!=case['expected_follow_st'] or any(follow.get(f'a{q}')!=v for q,v in enumerate(case['expected_follow_regs'])):
                raise RuntimeError(name+': following load result changed')
            if any(follow.get(key)!=value for key,value in case['expected_follow_extra_regs'].items()):
                raise RuntimeError(name+': following implicit state changed')
    data['command']=argv;data['exit_code']=result.returncode
    return data


def run(work):
    hdl=MODULE/'hdl'
    hashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(hdl.glob('*.v'))}
    records={}
    control=execute(work,'control','all',hdl)
    if control['exit_code'] or control['failed']:raise RuntimeError('byte-event positive control failed')
    records['control']=control
    for name,kind,file,before,after,diagnostic in (
        ('lost_hold_restart','hold','jttms10_word.v',
         '.word_restart(word_restart && data_owner)',".word_restart(1'b0)",
         'RMW write used a stale read across HOLD grant'),
        ('late_dependent_byte_load','following','jttms10.v',
         '(pixel_xy_copy ? CLKS_PER_STATE[15:0] : 16\'d0);',
         '((pixel_xy_copy || (byte_op && !copy_ir && control[15])) ? CLKS_PER_STATE[15:0] : 16\'d0);',
         'following dependent load: expected')):
        mutant=work/name;shutil.copytree(hdl,mutant)
        path=mutant/file;text=path.read_text()
        if text.count(before)!=1:raise RuntimeError(name+': mutation anchor changed')
        path.write_text(text.replace(before,after))
        data=execute(work,name,kind,mutant)
        if data['exit_code']!=1 or not data['failed'] or not any(diagnostic in error for row in data['cases'] for error in row['errors']):
            raise RuntimeError(name+': expected timing/protocol violation not detected')
        if any(diagnostic not in error for row in data['cases'] for error in row['errors']):
            raise RuntimeError(name+': unrelated failures cannot count as successful mutation detection')
        data['mutation']=dict(file=file,before=before,after=after,
            sha256=hashlib.sha256(path.read_bytes()).hexdigest(),diagnostic=diagnostic)
        records[name]=data
        print(name+': PASS (actual mutation rejected; architecture and memory correct)',flush=True)
    if any(hashlib.sha256(Path(p).read_bytes()).hexdigest()!=digest for p,digest in hashes.items()):
        raise RuntimeError('canonical HDL changed during mutation validation')
    return dict(controls_passed=120,mutations_rejected=2,source_sha256=hashes,records=records)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path)
    parser.add_argument('--report',type=Path)
    args=parser.parse_args()
    if args.output:
        args.output.mkdir(parents=True,exist_ok=False)
        result=run(args.output.resolve())
    else:
        with tempfile.TemporaryDirectory(prefix='jttms10-byte-event-mutants-') as temp:result=run(Path(temp))
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps(result,indent=2)+'\n')
    print('CD byte-store event mutations: 120 controls passed, 2 mutations rejected')
    return 0


if __name__=='__main__':
    sys.exit(main())
