#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Reject real event timing/host-data mutations with unchanged independent checks."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

import check_results as checker
import check_external_reference as reference

HERE = Path(__file__).resolve().parent


def run(output):
    output.mkdir(parents=True, exist_ok=False)
    entries = [entry for batch in reference.fixture_manifest()['batches'] for entry in batch['cases']]
    wanted = ('nop_hit__empty', 'nop_hit__early_cen7_w0', 'nop_hit__lint_host')
    entries = [next(entry for entry in entries if entry['name'] == name) for name in wanted]
    # Separate batches retain the individual ordinary oracle verdict even if
    # another mutant case times out or encounters an execution protocol error.
    manifest = dict(format=checker.FORMAT_V4, protocol_version=4,
                    batches=[checker.make_batches([entry], protocol_version=4)[0] for entry in entries])
    reference.run(manifest, output/'control')
    source = HERE/'jttms10_fpga_stimulus.v'
    original = source.read_text()
    variants = (
        ('early_cen', 'relative_clock==argument :',
         "relative_clock==(argument==0 ? 32'd0 : argument-32'd1) :"),
        ('wrong_host_nmi', "host_wdata<=control & 16'h8300;",
         "host_wdata<=(control & 16'h8300) ^ 16'h0100;"),
    )
    records = []
    for name, before, after in variants:
        if original.count(before) != 1:
            raise ValueError(name+': mutation anchor is not unique')
        rtl = output/(name+'.v')
        rtl.write_text(original.replace(before, after))
        target = output/name
        command = [sys.executable, str(HERE/'check_runner.py'),
            '--manifest', str(output/'control/manifest.json'),
            '--reference', str(output/'control/reference.json'),
            '--stimulus-rtl', str(rtl), '--output', str(target), '--timeout-cycles', '10000']
        result = subprocess.run(command, capture_output=True, text=True)
        (output/(name+'-command.log')).write_text(result.stdout+result.stderr)
        if result.returncode != 1 or not (target/'report.json').is_file():
            raise RuntimeError(f'{name}: no valid failing execution, exit {result.returncode}')
        report = json.loads((target/'report.json').read_text())
        captures = [json.loads((target/f'capture-{q}.json').read_text()) for q in range(3)]
        control = checker.check_batch(manifest['batches'][0], captures[0])
        if control['passed'] != 1 or control['failed']:
            raise ValueError(name+': unaffected NOP control failed')
        if name == 'early_cen':
            verdict = checker.check_batch(manifest['batches'][1], captures[1])
            row = verdict['cases'][0]
            if captures[1]['status'] != 2 or verdict['failed'] != 1:
                raise ValueError('early CEN mutation did not return an identified ordinary timing failure')
            if row['observed']['clocks'] != 14 or row['observed']['paused'] != 6:
                raise ValueError('early CEN mutation did not shorten the declared seven-clock pause')
            if any(row['observed'][f'a{q}'] != value for q, value in enumerate(row['expected_regs'])):
                raise ValueError('early CEN timing mutant changed the architectural result')
            if row['observed']['st'] != row['expected_st']:
                raise ValueError('early CEN timing mutant changed architectural status')
            if not any('expected 15 INCLK' in error for error in row['errors']):
                raise ValueError('independent instruction duration oracle missed early CEN release')
            if not any('external event clock' in error for error in row['errors']):
                raise ValueError('independent event clock check missed early CEN release')
        else:
            raw = captures[2]
            if raw['status'] == 2 and raw['results'][0][1] == 2 and not report['batches'][2]['failed']:
                raise ValueError('unexpected host NMI passed')
            unaffected = checker.check_batch(manifest['batches'][1], captures[1])
            if unaffected['failed']:
                raise ValueError('host mutation corrupted the unrelated CEN control')
        if not report['reference_comparison_errors']:
            raise ValueError(name+': failing mutant was accepted as reference-equivalent')
        records.append(dict(name=name, command=command, exit_code=result.returncode,
            mutant_rtl_sha256=hashlib.sha256(rtl.read_bytes()).hexdigest(),
            unchanged_nop_control_pass=True, reference_mismatch_detected=bool(report['reference_comparison_errors']),
            identified_results=[dict(id=raw['results'][0][0], status=raw['results'][0][1]) for raw in captures]))
        print(name+': PASS (actual mutant rejected, unchanged NOP control passes)', flush=True)
    if source.read_text() != original:
        raise RuntimeError('canonical synthesizable source changed during mutation validation')
    verification = dict(control_cases=3, mutations_rejected=2, records=records,
                        original_stimulus_sha256=hashlib.sha256(original.encode()).hexdigest())
    (output/'verification.json').write_text(json.dumps(verification, indent=2)+'\n')
    return verification


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, help='new directory retaining baseline/mutant captures')
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    if args.output:
        result = run(args.output.resolve())
    else:
        with tempfile.TemporaryDirectory(prefix='jttms10-event-mutations-') as temp:
            result = run(Path(temp)/'evidence')
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2)+'\n')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
