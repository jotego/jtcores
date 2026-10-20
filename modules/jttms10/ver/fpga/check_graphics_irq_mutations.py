#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Prove independent LINE continuation and checkpoint contracts reject RTL mutations."""
import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
TMS = HERE.parents[1]
DEFAULT_HDL = TMS/'hdl'
REFERENCE = HERE/'check_external_reference.py'
MUTATIONS = (
    ('wrong_line_restart_pc', 'jttms10.v',
     "md<=line_hw_push ? pc-32'd16 : pc;", "md<=line_hw_push ? pc : pc;",
     ('expected 00020006', 'final pixel memory', 'data BUS transaction')),
    ('overlong_line_checkpoint', 'jttms10.v',
     'LINE_PIXEL_I=5*CLKS_PER_STATE-1;', 'LINE_PIXEL_I=30*CLKS_PER_STATE-1;',
     ('interrupt recognition/context: expected 135..177 INCLK',)),
)


def replace_once(path, old, new):
    source = path.read_text()
    if source.count(old) != 1:
        raise RuntimeError(f'mutation site changed: {path.name}: {old!r}')
    path.write_text(source.replace(old, new))


def run_mutation(name, filename, old, new, needles, root):
    hdl = root/(name+'-hdl')
    shutil.copytree(DEFAULT_HDL, hdl)
    replace_once(hdl/filename, old, new)
    output = root/name
    command = [sys.executable, str(REFERENCE), '--graphics-irq', '--cpu-rtl-dir', str(hdl),
               '--output', str(output)]
    process = subprocess.run(command, text=True, capture_output=True)
    report_path = output/'avalon'/'report.json'
    if not report_path.is_file():
        raise RuntimeError(f'{name}: runner failed before emitting a contract report\n{process.stdout}{process.stderr}')
    reference = json.loads((output/'reference.json').read_text())
    report = json.loads(report_path.read_text())
    if any(case['errors'] for case in reference['cases']):
        raise RuntimeError(f'{name}: original full-system positive control failed')
    errors = [message for batch in report['batches'] for case in batch['cases'] for message in case['errors']]
    missing = [needle for needle in needles if not any(needle in error for error in errors)]
    if process.returncode == 0 or missing:
        raise RuntimeError(f'{name}: mutation was not rejected by its independent contract; '
                           f'missing={missing}, errors={errors}, output={output}')
    control_output=root/(name+'-nop-control')
    control=[sys.executable,str(HERE/'check_runner.py'),'--case','nop_hit',
             '--cpu-rtl-dir',str(hdl),'--output',str(control_output)]
    control_run=subprocess.run(control,text=True,capture_output=True)
    control_report=control_output/'report.json'
    if control_run.returncode or not control_report.is_file():
        raise RuntimeError(f'{name}: NOP control failed to run\n{control_run.stdout}{control_run.stderr}')
    control_data=json.loads(control_report.read_text())
    if not control_data.get('batches') or any(batch.get('failed',0) for batch in control_data.get('batches',[])):
        raise RuntimeError(f'{name}: ordinary NOP control failed: {control_data}')
    print(f'{name}: PASS; independent contract rejected mutation ({len(errors)} diagnostics), NOP control passed; evidence={output}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, help='new directory retaining copied mutant RTL and two short runs')
    args = parser.parse_args()
    if args.output:
        root = args.output.resolve()
        root.mkdir(parents=True, exist_ok=False)
        for mutation in MUTATIONS:
            run_mutation(*mutation, root)
    else:
        with tempfile.TemporaryDirectory(prefix='jttms10-graphics-irq-mutations-') as temp:
            root = Path(temp)
            for mutation in MUTATIONS:
                run_mutation(*mutation, root)


if __name__ == '__main__':
    main()
