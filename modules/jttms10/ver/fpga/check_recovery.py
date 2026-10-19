#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check short controller timeout/overflow negatives and independent recovery."""
import argparse
import concurrent.futures
import copy
import json
from pathlib import Path
import subprocess
import sys

import check_results as checker

HERE = Path(__file__).resolve().parent


def recovery_manifest(kind):
    terms = ['nop_off', 'nop_hit'] if kind == 'overflow' else ['mpys_fs2_positive_even_hit', 'nop_hit']
    entries = checker.prepare_cases(terms)
    entries.sort(key=lambda entry: entry['name'] == 'nop_hit')
    if len(entries) != 2 or entries[1]['name'] != 'nop_hit':
        raise ValueError('recovery test requires exactly one negative and one clean fixture')
    for identifier, entry in enumerate(entries):
        entry['id'] = identifier
    batch = checker.make_batches(entries)[0]
    if kind == 'overflow':
        field, old, new = 'next_pc', batch['descriptors'][0][4], 0xff00
        batch['descriptors'][0][4] = new
    else:
        field, old, new = 'test_pc', batch['descriptors'][0][3], 0x1000
        batch['descriptors'][0][3] = new
        batch['descriptors'][0][5] = 1
    return dict(format=checker.FORMAT, protocol_version=2,
                batches=[batch, checker.make_batches([copy.deepcopy(entries[1])])[0]],
                deliberate_injection=dict(case_id=0, field='descriptor.'+field,
                                          original=old, mutated=new, timeout_cycles=10000))


def verify_recovery(kind, manifest, capture, report):
    batch, clean = manifest['batches']
    if not capture['status'] & 0x80000000 or len(capture['results']) != 2:
        raise ValueError('negative batch did not return two identified failing-batch results')
    if [row[0] for row in capture['results']] != [entry['id'] for entry in batch['cases']]:
        raise ValueError('negative batch lost case identification')
    if capture['results'][0][1] != 0x80000002 or capture['results'][1][1] != 2:
        raise ValueError('timeout or subsequent-case status is incorrect')
    overflow = bool(capture['event_count'] & 0x80000000)
    count = capture['event_count'] & 0x7fffffff
    if count != len(capture['events']) or overflow != (kind == 'overflow'):
        raise ValueError('incorrect trace overflow/count reporting')
    version = batch.get('protocol_version', 1)
    if count != (checker.EVENT_LIMITS[version][0] if overflow else 0):
        raise ValueError('diagnostic trace did not respect the expected bound')
    checker.decode_events(capture['events'], 2, version)
    trace = []
    for row in capture['events']:
        if ((row[3] >> 9) & 31) == 1:
            row = row.copy()
            row[3] &= ~(31 << 9)
            trace.append(row)
    # The original failed batch remains failed. Isolate only the later result
    # for an additional oracle check; never relabel the whole capture success.
    isolated = dict(status=2, protocol_version=version, event_count=len(trace), events=trace,
                    results=[capture['results'][1]])
    independent = checker.check_batch(clean, isolated)
    rearmed = report['batches'][1]
    if independent['failed'] or independent['passed'] != 1 or rearmed['failed'] or rearmed['passed'] != 1:
        raise ValueError('subsequent case or rearmed batch failed its independent oracle')
    if not report['batches'][0].get('protocol_errors'):
        raise ValueError('negative batch was not rejected by the host checker')
    return dict(first_case_status=capture['results'][0][1], second_case_status=capture['results'][1][1],
                second_case_oracle=independent, clean_rearm_batch=rearmed,
                trace_records=count, overflow=overflow)


def run_negative(kind, output):
    manifest = recovery_manifest(kind)
    path = output / (kind+'-manifest.json')
    path.write_text(json.dumps(manifest, indent=2)+'\n')
    artifacts = output / kind
    command = [sys.executable, str(HERE/'check_runner.py'), '--manifest', str(path),
               '--timeout-cycles', '10000', '--output', str(artifacts)]
    result = subprocess.run(command, text=True, capture_output=True)
    if not artifacts.is_dir():
        raise RuntimeError(result.stdout+result.stderr)
    (artifacts/'command.log').write_text(result.stdout+result.stderr)
    if result.returncode != 1 or not (artifacts/'report.json').is_file():
        raise RuntimeError(f'{kind}: no valid negative execution (exit {result.returncode}); see {artifacts}')
    report = json.loads((artifacts/'report.json').read_text())
    capture = json.loads((artifacts/'capture-0.json').read_text())
    evidence = verify_recovery(kind, manifest, capture, report)
    evidence.update(negative_command_exit=result.returncode, source_sha256=report['source_sha256'])
    (artifacts/'recovery-verification.json').write_text(json.dumps(evidence, indent=2)+'\n')
    return dict(kind=kind, verified=True, negative_exit=result.returncode,
                trace_records=evidence['trace_records'], output=str(artifacts))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', required=True, type=Path, help='new evidence directory')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda kind: run_negative(kind, args.output), ['timeout', 'overflow']))
    (args.output/'summary.json').write_text(json.dumps(results, indent=2)+'\n')
    for result in results:
        print(f"{result['kind']}: PASS (negative exit 1, next case and clean rearm pass)")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
