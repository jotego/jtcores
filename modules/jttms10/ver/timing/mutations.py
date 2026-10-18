#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Demonstrate rejection of timing bugs while arithmetic/state remain correct.

Mutations operate only on fresh temporary copies. Positive controls must
pass first. Syntax errors, missing results and functional failures do not
count as successful detection of a timing regression.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
MODULE = HERE.parents[1]


def run_case(work, name, case, extra=(), mutated=False, event_error=None):
    report = work / (name+'.json')
    command = [sys.executable,str(HERE / 'run.py'),'--case',case,'--report',str(report),*extra]
    result = subprocess.run(command,capture_output=True,text=True,timeout=60)
    if not report.exists():
        raise RuntimeError(f'{name}: no report\n{result.stdout}{result.stderr}')
    data = json.loads(report.read_text())
    if len(data['cases']) != 1:
        raise RuntimeError(f'{name}: expected exactly one probe')
    row = data['cases'][0]
    observed = row['observed']
    if event_error is not None:
        if result.returncode!=1 or not row['errors'] or event_error not in result.stdout+result.stderr:
            raise RuntimeError(f'{name}: expected event contract was not rejected\n{result.stdout}{result.stderr}')
        print(f'{name}: PASS (sequencer pause event violation rejected)')
        return data
    if observed is None or observed['st'] != row['expected_st'] or any(
            observed[f'a{q}'] != value for q,value in enumerate(row['expected_regs'])):
        raise RuntimeError(f'{name}: functional failure is not a timing-only mutation\n{result.stdout}{result.stderr}')
    expected_exit = int(mutated)
    if result.returncode != expected_exit or bool(row['errors']) != mutated:
        raise RuntimeError(f'{name}: unexpected detection result (exit={result.returncode})\n{result.stdout}{result.stderr}')
    print(f'{name}: PASS (' + ('timing regression rejected; architectural state correct)' if mutated else 'positive control)'))
    return data


def replace_once(path, old, new):
    source = path.read_text()
    if source.count(old) != 1:
        raise RuntimeError(f'mutation site changed: {path.name}: {old!r}')
    path.write_text(source.replace(old,new))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report',type=Path)
    args = parser.parse_args()
    evidence = {}
    with tempfile.TemporaryDirectory(prefix='jttms10-timing-mutations-') as temp:
        work = Path(temp)
        case = 'mpys_fs2_positive_even_hit'
        evidence['fs_control'] = run_case(work,'fs_control',case)
        evidence['cen_control'] = run_case(work,'cen_control',case,['--pause-clocks','7'])
        evidence['wait_control'] = run_case(work,'wait_control','nop_off',['--wait-states','1'])

        flat = work / 'flat-width-hdl'
        shutil.copytree(MODULE / 'hdl',flat)
        replace_once(flat / 'jttms10.v',"6'd5+multiply_half","6'd21")
        evidence['wrong_fs1_latency'] = run_case(work,'wrong_fs1_latency',case,
                                                ['--rtl-dir',str(flat)],mutated=True)

        cen = work / 'ignores-cen-hdl'
        shutil.copytree(MODULE / 'hdl',cen)
        replace_once(cen / 'jttms10.v','if(cen) begin',"if(1'b1) begin")
        evidence['absorbed_cen_pause'] = run_case(work,'absorbed_cen_pause',case,
            ['--rtl-dir',str(cen),'--pause-clocks','7'],mutated=True)

        bench = work / 'ignores-wait.sv'
        shutil.copyfile(HERE / 'test.sv',bench)
        replace_once(bench,'delay_clocks=16+extra_wait;','delay_clocks=16;')
        evidence['omitted_target_wait'] = run_case(work,'omitted_target_wait','nop_off',
            ['--bench',str(bench),'--wait-states','1'],mutated=True)

        prime = work / 'primes-while-paused-hdl'
        shutil.copytree(MODULE / 'hdl',prime)
        replace_once(prime / 'jttms10_ctrl.v','else if(!cen && enable) begin','else if(!cen) begin')
        evidence['sequencer_advances_during_pause'] = run_case(work,'sequencer_advances_during_pause',case,
            ['--rtl-dir',str(prime),'--pause-clocks','7'],mutated=True,
            event_error='instruction sequencer advanced while CEN paused')
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps(evidence,indent=2)+'\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
