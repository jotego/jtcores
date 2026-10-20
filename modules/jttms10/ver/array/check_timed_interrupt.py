#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Prove that timed PIXBLT IRQ benches reject actual RTL regressions.

Only temporary HDL copies are changed. Every mutant must build successfully
and fail a specific architectural/checkpoint assertion; compiler failures do
not count as detection. The same physical-word bench first passes unchanged.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

VER = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(VER))
from verilator_build import build_model


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path)
    parser.add_argument('--kind', choices=('binary', 'regular'), default='binary')
    args = parser.parse_args()
    kind = args.kind
    hdl = VER.parent / 'hdl'
    frozen = {p.name: digest(p) for p in hdl.glob('*.v')}
    variants = [
        ('control', None, None, None, None),
        ('missed_word_checkpoint', 'jttms10_gfx.v',
         'assign bus_abort=active && irq_pending && !bus_accepted &&',
         "assign bus_abort=active && irq_pending && !bus_accepted && 1'b0 &&",
         f'{kind} IRQ missed destination checkpoint'),
        ('cancel_accepted_write', 'jttms10_gfx.v',
         'assign bus_abort=active && irq_pending && !bus_accepted &&',
         'assign bus_abort=active && irq_pending &&',
         f'{kind} context'),
        ('lost_resume_timing', 'jttms10.v',
         'binary_last_row<=rs_data==0;\n                timing_active<=1;',
         'binary_last_row<=rs_data==0;\n                timing_active<=0;',
         f'{kind} IRQ timeout'),
    ]
    if kind == 'regular':
        variants[2] = ('wrong_checkpoint_frame', 'jttms10_gfx.v',
                       'else uaddr<=GCTXBLT_SEQA;',
                       'else uaddr<=GCTXBINROW_SEQA;',
                       'regular context')
    evidence = {}
    with tempfile.TemporaryDirectory(prefix=f'jttms10-{kind}-irq-mutations-') as temp:
        work = Path(temp)
        for name, filename, before, after, diagnostic in variants:
            copied = work / name / 'hdl'
            shutil.copytree(hdl, copied)
            if filename:
                target = copied / filename
                source = target.read_text()
                if source.count(before) != 1:
                    raise RuntimeError(f'{name}: mutation anchor is not unique')
                target.write_text(source.replace(before, after))
            bench = 'timed_interrupt.sv' if kind == 'binary' else 'timed_copy_interrupt.sv'
            executable = build_model(work/name/'obj',
                [VER/'array'/bench, *sorted(copied.glob('*.v'))],
                includes=[VER/'build'])
            format_arg = '+XY=1' if kind == 'binary' else '+COPY_MODE=3'
            command = [str(executable), '+PSIZE=4', '+WIDTH=32', format_arg,
                       '+WAIT_STATES=1', '+IRQ_AFTER=2', '+PAUSE_CLOCKS=31']
            if kind == 'regular':
                command = [str(executable), '+PSIZE=4', '+WIDTH=16', format_arg,
                           '+WAIT_STATES=0', '+IRQ_AFTER=1', '+PAUSE_CLOCKS=0']
            result = subprocess.run(command, cwd=VER/'build', capture_output=True,
                                    text=True, timeout=30)
            log = result.stdout + result.stderr
            if diagnostic is None:
                valid = result.returncode == 0 and log.count(f'PASS {kind} IRQ') == 5
            else:
                valid = result.returncode != 0 and diagnostic in log
            evidence[name] = dict(command=command, returncode=result.returncode, output=log,
                                  expected_diagnostic=diagnostic, passed=valid,
                                  hdl_sha256={p.name:digest(p) for p in copied.glob('*.v')})
            if not valid:
                raise RuntimeError(f'{name}: incorrect regression outcome\n{log}')
            print(f'{name}: PASS', flush=True)
    if frozen != {p.name: digest(p) for p in hdl.glob('*.v')}:
        raise RuntimeError('source HDL changed during mutation checks')
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(evidence, indent=2)+'\n')


if __name__ == '__main__':
    main()
