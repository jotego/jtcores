#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Reject actual NMI priority/HALT regressions through the host/peripheral path."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
MODULE = HERE.parents[1]
sys.path.insert(0, str(MODULE/'ver'))
from verilator_build import build_model


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(output):
    output.mkdir(parents=True, exist_ok=False)
    inputs = [*sorted((MODULE/'hdl').glob('*.v')), MODULE/'ver/nmi/test.sv',
              MODULE/'ver/build.sh', MODULE/'ver/verilator_build.py',
              *sorted((MODULE/'ucode').glob('*.yaml')), Path(__file__).resolve()]
    frozen = {str(p.relative_to(MODULE)): sha(p) for p in inputs}
    variants = (
        ('lower_irq_priority', 'assign irq_ready = irq_pending && (!nmi_pending || nmi_ready);',
         'assign irq_ready = irq_pending;', 3, 'maskable IRQ beat pending NMI'),
        ('halt_before_nmi', 'assign halt_ready = halt && (cpu_halted || !nmi_pending || nmi_ready);',
         'assign halt_ready = halt;', 1, 'NMI entry wrong'),
        ('wake_halted_cpu', 'assign halt_ready = halt && (cpu_halted || !nmi_pending || nmi_ready);',
         'assign halt_ready = halt && (!nmi_pending || nmi_ready);', 2,
         'halt/pause changed NMI context mode=2'),
    )
    records = []
    with tempfile.TemporaryDirectory(prefix='jttms10-nmi-priority-') as temporary:
        work = Path(temporary)
        subprocess.run(['bash', str(MODULE/'ver/build.sh'), str(work)], check=True,
                       stdout=subprocess.DEVNULL)
        for name, before, after, mode, diagnostic in [('control', None, None, None, None), *variants]:
            copied = work/name/'hdl'
            shutil.copytree(MODULE/'hdl', copied)
            if before is not None:
                target = copied/'jttms10_system.v'
                original = target.read_text()
                if original.count(before) != 1:
                    raise ValueError(name+': mutation anchor is not unique')
                target.write_text(original.replace(before, after))
                shutil.copyfile(target, output/(name+'-jttms10_system.v'))
            try:
                executable = build_model(work/name/'obj', [MODULE/'ver/nmi/test.sv',
                    *sorted(copied.glob('*.v'))], includes=[work])
            finally:
                log = work/name/'obj/build.log'
                if log.is_file():
                    shutil.copyfile(log, output/(name+'-compile.log'))
            modes = ([(1, 0), (1, 1), (2, 0), (3, 0), (4, 0), (5, 0)] if name == 'control'
                     else [(mode, int(name == 'halt_before_nmi'))])
            for selected, paused in modes:
                result = subprocess.run([str(executable), f'+MODE={selected}', f'+SHORT_PAUSE={paused}'], cwd=work,
                                        capture_output=True, text=True, timeout=30)
                log = result.stdout+result.stderr
                (output/f'{name}-{selected}-pause{paused}.log').write_text(log)
                if name == 'control':
                    if result.returncode or f'PASS: host NMI mode{selected} ' not in log:
                        raise RuntimeError(f'control mode{selected} failed')
                elif result.returncode == 0 or diagnostic not in log:
                    raise RuntimeError(name+': actual regression was not identified')
                records.append(dict(name=name, mode=selected, short_pause=paused, exit_code=result.returncode,
                                    required_diagnostic=diagnostic))
                print(f'{name} mode{selected}: PASS', flush=True)
    if any(sha(MODULE/p) != digest for p, digest in frozen.items()):
        raise RuntimeError('NMI priority source changed during validation')
    proof = dict(control_cases=6, actual_RTL_mutations_rejected=3, records=records, source_sha256=frozen)
    (output/'verification.json').write_text(json.dumps(proof, indent=2)+'\n')
    return proof


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    if args.output:
        proof = run(args.output.resolve())
    else:
        with tempfile.TemporaryDirectory(prefix='jttms10-nmi-priority-evidence-') as temporary:
            proof = run(Path(temporary)/'evidence')
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(proof, indent=2)+'\n')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
