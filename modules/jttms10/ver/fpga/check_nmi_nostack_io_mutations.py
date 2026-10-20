#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Reject a functional CPU-visible I/O read mutation with NOP controls."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

import check_external_reference as reference
import check_results as checker

HERE=Path(__file__).resolve().parent
HDL=HERE.parents[1]/'hdl'

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def run(output):
    output.mkdir(parents=True,exist_ok=False)
    frozen={p.name:sha(p) for p in HDL.glob('*.v')}
    ordinary=[e for b in reference.fixture_manifest()['batches'] for e in b['cases']]
    io=[e for b in reference.fixture_manifest(nmi_nostack_io=True,stack_offsets=[0])['batches'] for e in b['cases']]
    names=('nop_hit__empty','nop_off__empty',
           'nmi_nostack_io_ie0_w0_cold_sp0','nmi_nostack_io_ie0_w0_warm_sp0')
    entries=[next(e for e in ordinary if e['name']==names[0]),
             next(e for e in ordinary if e['name']==names[1]),
             next(e for e in io if e['name']==names[2]),
             next(e for e in io if e['name']==names[3])]
    for i,e in enumerate(entries): e['id']=i
    manifest=dict(format=checker.FORMAT_V5,protocol_version=5,batches=checker.make_batches(entries,5))
    reference.run(manifest,output/'control')
    controls=json.loads((output/'control/reference.json').read_text())['cases']
    with tempfile.TemporaryDirectory(prefix='jttms10-nmi-io-mutant-') as temp:
        copied=Path(temp)/'hdl'; shutil.copytree(HDL,copied)
        target=copied/'jttms10_io.v'; original=target.read_text()
        before='default: io_rdata=regs[idx];'
        after="default: io_rdata=(idx==5'h16) ? 16'h0000 : regs[idx];"
        if original.count(before)!=1: raise ValueError('CPU I/O read mutation anchor is not unique')
        target.write_text(original.replace(before,after))
        shutil.copyfile(target,output/'mutant-jttms10_io.v')
        command=[sys.executable,str(HERE/'check_runner.py'),'--manifest',str(output/'control/manifest.json'),
                 '--reference',str(output/'control/reference.json'),'--cpu-rtl-dir',str(copied),
                 '--output',str(output/'mutant')]
        result=subprocess.run(command,capture_output=True,text=True)
        (output/'mutant-command.log').write_text(result.stdout+result.stderr)
        report_path=output/'mutant/report.json'
        if result.returncode!=1 or not report_path.is_file():
            raise RuntimeError(f'functional I/O mutation was not identified, exit={result.returncode}')
        report=json.loads(report_path.read_text()); rows=[r for b in report['batches'] for r in b['cases']]
        captures=[json.loads((output/'mutant'/f'capture-{q}.json').read_text()) for q in range(len(manifest['batches']))]
        if len(rows)!=4 or any(r['errors'] for r in rows[:2]): raise ValueError('NOP controls failed or cases lost')
        if any(c['status']!=2 or any(r[1]!=2 for r in c['results']) for c in captures):
            raise ValueError('timeout/protocol abort is not mutation evidence')
        for row,control in zip(rows[2:],controls[2:]):
            if not any('I/O read 5 data' in e for e in row['errors']):
                raise ValueError('PMASK CPU-visible data mutation was not rejected')
            if (len(row['errors'])!=2 or not any('ISR A11 expected 00002a5a, got 0' in e for e in row['errors']) or
                not any('I/O read 5 data expected 2a5a, got 0000' in e for e in row['errors'])):
                raise ValueError('mutant did not produce exactly the two PMASK architectural/readback errors: '+repr(row['errors']))
            if row['irq_observation']['follow'].get('a11')!=0:
                raise ValueError('mutant capture did not observe corrupted A11 value zero')
            for key,value in control['irq_observation']['follow'].items():
                if key not in ('clock','a11') and row['irq_observation']['follow'].get(key)!=value:
                    raise ValueError('PMASK-only mutation changed another initialized register')
            if row['irq_observation']['memory']!=control['irq_observation']['memory']:
                raise ValueError('PMASK-only mutation changed memory/guards')
            if (row['observed'].get('clocks')!=control['observed'].get('clocks') or
                row['irq_observation'].get('boundary')!=control['irq_observation'].get('boundary') or
                row['irq_observation'].get('follow',{}).get('clock')!=control['irq_observation'].get('follow',{}).get('clock')):
                raise ValueError('functional mutation changed independent timing counts')
        if frozen!={p.name:sha(p) for p in HDL.glob('*.v')}:
            raise RuntimeError('canonical CPU source changed during mutation check')
    proof=dict(control_cases=4,nop_controls_passed=2,actual_functional_mutations_rejected=1,
        mutation='CPU read of PMASK (I/O index 0x16) returns zero',unchanged_timing=True,
        cpu_sha256=frozen,required_diagnostic='no-stack NMI I/O: I/O read 5 data')
    (output/'verification.json').write_text(json.dumps(proof,indent=2)+'\n')
    print('PMASK I/O read mutation: PASS (NOP controls pass; functional regression rejected)',flush=True)
    return proof

def main():
    import argparse
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path);a=p.parse_args()
    if a.output: run(a.output.resolve())
    else:
        with tempfile.TemporaryDirectory(prefix='jttms10-nmi-io-mutation-') as t: run(Path(t)/'evidence')
if __name__=='__main__': main()
