#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Reject real NMIM=1 stack, recognition and first-ISR timing mutations."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

import check_external_reference as reference
import check_results as checker

HERE = Path(__file__).resolve().parent
HDL = HERE.parents[1]/'hdl'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(output):
    output.mkdir(parents=True, exist_ok=False)
    frozen = {p.name: sha(p) for p in HDL.glob('*.v')}
    ordinary = [e for b in reference.fixture_manifest()['batches'] for e in b['cases']]
    extra = [e for b in reference.fixture_manifest(nmi_nostack=True, stack_offsets=[0])['batches']
             for e in b['cases']]
    entries = [next(e for e in ordinary if e['name'] == name)
               for name in ('nop_hit__empty', 'nop_off__empty')]
    entries += [next(e for e in extra if e['name'] == name)
                for name in ('nmi_nostack_ie0_w0_cold_sp0', 'nmi_nostack_ie0_w0_warm_sp0')]
    for q, entry in enumerate(entries):
        entry['id'] = q
    manifest = dict(format=checker.FORMAT_V5, protocol_version=5,
                    batches=checker.make_batches(entries, 5))
    reference.run(manifest, output/'control')
    controls = json.loads((output/'control/reference.json').read_text())['cases']
    variants = [
        ('unwanted_stack', 'jttms10_system.v', '.nmi_nostack(nmi_nmim)',
         ".nmi_nostack(1'b0)", 'stack guards or vector changed'),
        ('early_recognition', 'jttms10_system.v',
         'assign nmi_ready = nmi_pending && nmi_age==NMI_LAST;',
         'assign nmi_ready = nmi_pending;', 'recognition:'),
        ('slow_first_isr', 'jttms10.v',
         "wire [15:0] decode_clocks={10'd0,decode_states} * CLKS_PER_STATE[15:0];",
         "wire [15:0] decode_clocks={10'd0,decode_states} * CLKS_PER_STATE[15:0]+(decode_opcode==16'h09e0 ? 16'd8 : 16'd0);",
         'first ISR MOVI'),
    ]
    records = []
    with tempfile.TemporaryDirectory(prefix='jttms10-nostack-mutants-') as temp:
        for name, filename, before, after, diagnostic in variants:
            copied = Path(temp)/name/'hdl'
            shutil.copytree(HDL, copied)
            target = copied/filename
            original = target.read_text()
            if original.count(before) != 1:
                raise ValueError(name+': mutation anchor is not unique')
            target.write_text(original.replace(before, after))
            shutil.copyfile(target, output/(name+'-'+filename))
            command = [sys.executable, str(HERE/'check_runner.py'),
                '--manifest', str(output/'control/manifest.json'),
                '--reference', str(output/'control/reference.json'),
                '--cpu-rtl-dir', str(copied), '--output', str(output/name)]
            result = subprocess.run(command, capture_output=True, text=True)
            (output/(name+'-command.log')).write_text(result.stdout+result.stderr)
            path = output/name/'report.json'
            if result.returncode != 1 or not path.is_file():
                raise RuntimeError(f'{name}: expected identified failing executions, exit={result.returncode}')
            report = json.loads(path.read_text())
            rows = [r for b in report['batches'] for r in b['cases']]
            captures = [json.loads((output/name/f'capture-{q}.json').read_text())
                        for q in range(len(manifest['batches']))]
            if any(c['status'] != 2 or any(r[1] != 2 for r in c['results']) for c in captures):
                raise ValueError(name+': timeout/protocol abort is not the intended mutation evidence')
            if len(rows) != 4 or any(r['errors'] for r in rows[:2]):
                raise ValueError(name+': NOP controls failed or cases were lost')
            for row, control in zip(rows, controls):
                keys = ['clocks', 'st', *[f'a{q}' for q in range(len(row['expected_regs']))],
                        *row.get('expected_extra_regs', {})]
                if any(row['observed'].get(k) != control['observed'].get(k) for k in keys):
                    raise ValueError(name+': initialized preceding NOP state changed')
            for row, control in zip(rows[2:], controls[2:]):
                if not any(diagnostic in error for error in row['errors']):
                    raise ValueError(name+': intended NMIM=1 regression was not rejected')
                if name != 'unwanted_stack':
                    if len(row['errors']) != 1:
                        raise ValueError(name+': expected only the intended timing error')
                    actual, golden = [dict(r['irq_observation']['follow']) for r in (row, control)]
                    actual.pop('clock'); golden.pop('clock')
                    if actual != golden or row['irq_observation']['memory'] != control['irq_observation']['memory']:
                        raise ValueError(name+': timing-only mutant changed final architecture')
            if not report['reference_comparison_errors']:
                raise ValueError(name+': failing capture falsely established reference equivalence')
            records.append(dict(name=name, command=command, exit_code=result.returncode,
                file=filename, before=before, after=after, mutant_sha256=sha(target),
                unchanged_NOP_controls=2, required_diagnostic=diagnostic,
                failures=[dict(name=r['name'], errors=r['errors']) for r in rows if r['errors']]))
            print(name+': PASS (actual RTL regression rejected)', flush=True)
    if frozen != {p.name: sha(p) for p in HDL.glob('*.v')}:
        raise RuntimeError('canonical CPU changed during mutation checks')
    proof = dict(control_cases=4, actual_RTL_mutations_rejected=len(variants),
                 cpu_sha256=frozen, records=records,
                 context_duration_contract='not separately specified for NMIM=1; no total-duration signoff')
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
        with tempfile.TemporaryDirectory(prefix='jttms10-nostack-mutation-check-') as temp:
            proof = run(Path(temp)/'evidence')
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(proof, indent=2)+'\n')


if __name__ == '__main__':
    main()
