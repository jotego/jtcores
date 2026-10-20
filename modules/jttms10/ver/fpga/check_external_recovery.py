#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Exercise external event failures through Avalon and verify isolation/rearm."""
import argparse
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile

import check_results as checker

HERE = Path(__file__).resolve().parent
KINDS = ('count', 'encoding', 'zero_base', 'unapplied', 'late',
         'host_protocol', 'cen_timeout', 'hold_timeout', 'overflow')


def manifests():
    # Deliberate malformed descriptors/tables bypass the ordinary Python/C
    # preflight only in the Avalon simulation. No physical transport is used.
    original = checker.prepare_cases(['nop_hit', 'nop_off', 'add_off',
                                     'blit_ll_ps4_n4_rows2_hit'], protocol_version=5)
    by_name = {entry['name']: entry for entry in original}
    batches, expected = [], []
    for kind in KINDS:
        # HOLD grants the external bus; a cached instruction can still finish.
        # The disabled-cache NOP needs its next fetch and must time out while
        # HOLD remains asserted. Do not demand that HOLD freeze cached work.
        failed = copy.deepcopy(by_name['nop_off' if kind in ('overflow', 'hold_timeout') else 'nop_hit'])
        clean = copy.deepcopy(by_name['nop_hit'])
        failed['id'], clean['id'] = 101, 202
        failed['external_events'] = [dict(trigger=0, argument=0, control=1),
                                     dict(trigger=0, argument=1, control=0)]
        status = 0x80000004
        if kind in ('count', 'encoding', 'zero_base'):
            status = 0x80000003
        elif kind == 'unapplied':
            failed['external_events'] = [dict(trigger=0, argument=1000, control=0)]
        elif kind == 'late':
            failed['external_events'][1]['argument'] = 0
        elif kind == 'host_protocol':
            for event in failed['external_events']:
                event['control'] = 16
        elif kind in ('cen_timeout', 'hold_timeout'):
            failed['external_events'] = [dict(trigger=0, argument=0,
                                             control=32 if kind == 'cen_timeout' else 4)]
            status = 0x80000002
        elif kind == 'overflow':
            status = 0x80000002
        batch = checker.make_batches([failed, clean], protocol_version=5)[0]
        desc = batch['descriptors'][0]
        if kind == 'count':
            desc[14] = 17
        elif kind == 'encoding':
            batch['program_words'][desc[15] + 3] = 6
        elif kind == 'zero_base':
            desc[14] = 0
        elif kind == 'overflow':
            desc[4] = 0xff00
        batches.extend([batch, checker.make_batches([clean], protocol_version=5)[0]])
        expected.append(dict(kind=kind, status=status, batch=len(batches)-2))
    controls = [copy.deepcopy(by_name[name]) for name in
                ('nop_hit', 'add_off', 'blit_ll_ps4_n4_rows2_hit')]
    for identifier, entry in enumerate(controls, 801):
        entry['id'] = identifier
    harmless = copy.deepcopy(by_name['nop_hit'])
    harmless['id'] = 804
    harmless['external_events'] = [dict(trigger=0, argument=0, control=1),
                                   dict(trigger=0, argument=1, control=0),
                                   dict(trigger=0, argument=2, control=16),
                                   dict(trigger=5, argument=1, control=0)]
    batches.extend(checker.make_batches(controls, protocol_version=5))
    batches.extend(checker.make_batches([harmless], protocol_version=5))
    return dict(format=checker.FORMAT_V5, protocol_version=5, batches=batches), expected


def verify(manifest, captures, report, expected):
    records = []
    for item in expected:
        index, kind = item['batch'], item['kind']
        failed, rearm = captures[index:index+2]
        batch, clean = manifest['batches'][index:index+2]
        if not failed['status'] & 0x80000000:
            raise ValueError(f'{kind}: failed case did not make its batch fail')
        if [r[0] for r in failed['results']] != [101, 202]:
            raise ValueError(f'{kind}: case identification lost')
        if [r[1] for r in failed['results']] != [item['status'], 2]:
            raise ValueError(f'{kind}: incorrect error or subsequent-case status')
        overflow = bool(failed['event_count'] & 0x80000000)
        count = failed['event_count'] & 0x7fffffff
        if overflow != (kind == 'overflow') or count != len(failed['events']):
            raise ValueError(f'{kind}: incorrect explicit overflow/count')
        checker.decode_events(failed['events'], 2, 5)
        if kind == 'overflow' and count != 512:
            raise ValueError('overflow: case trace exceeded or missed its bound')
        trace = []
        for event in failed['events']:
            if (event[3] >> 9) & 31 == 1:
                event = event.copy()
                event[3] &= ~(31 << 9)
                trace.append(event)
        isolated = dict(protocol_version=5, status=2, results=[failed['results'][1]],
                        events=trace, event_count=len(trace))
        independent = checker.check_batch(clean, isolated)
        rearmed = checker.check_batch(clean, rearm)
        if independent['failed'] or rearmed['failed']:
            raise ValueError(f'{kind}: independent next case or clean rearm failed')
        if not report['batches'][index].get('protocol_errors'):
            raise ValueError(f'{kind}: host did not reject the original batch')
        records.append(dict(kind=kind, first_case_status=item['status'],
                            next_case_pass=True, clean_rearm_pass=True,
                            overflow=overflow, trace_records=count,
                            independent_next_case=independent, rearmed=rearmed))
    return records


def run(output):
    output.mkdir(parents=True, exist_ok=False)
    manifest, expected = manifests()
    path = output/'manifest.json'
    path.write_text(json.dumps(manifest, indent=2)+'\n')
    command = [sys.executable, str(HERE/'check_runner.py'), '--manifest', str(path),
               '--timeout-cycles', '10000', '--output', str(output/'avalon')]
    result = subprocess.run(command, capture_output=True, text=True)
    (output/'command.json').write_text(json.dumps(dict(command=command, exit_code=result.returncode),
                                                     indent=2)+'\n')
    (output/'command.log').write_text(result.stdout+result.stderr)
    evidence = output/'avalon'
    if result.returncode != 1 or not (evidence/'report.json').is_file():
        raise RuntimeError(f'no valid negative execution: exit {result.returncode}; see {output}')
    captures = [json.loads((evidence/f'capture-{q}.json').read_text())
                for q in range(len(manifest['batches']))]
    report = json.loads((evidence/'report.json').read_text())
    records = verify(manifest, captures, report, expected)
    positive = []
    for batch, raw in zip(manifest['batches'][2*len(expected):], captures[2*len(expected):]):
        verdict = checker.check_batch(batch, raw)
        if verdict['failed']:
            raise ValueError('ordinary or harmless-event control failed its unchanged ISA oracle')
        positive.append(verdict)
    if sum(row['passed'] for row in positive) != 4:
        raise ValueError('positive control inventory differs')
    verification = dict(negative_command_exit=1, records=records,
                        positive_controls=positive, source_sha256=report['source_sha256'])
    (output/'verification.json').write_text(json.dumps(verification, indent=2)+'\n')
    for item in records:
        print(f"{item['kind']}: PASS (identified failure, independent next case and clean rearm)")
    print('ordinary/harmless controls: 4 PASS (unchanged ISA oracle)')
    return verification


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, help='new directory to retain raw evidence')
    parser.add_argument('--report', type=Path, help='verification report for the standard runner')
    args = parser.parse_args()
    if args.output:
        verification = run(args.output.resolve())
    else:
        with tempfile.TemporaryDirectory(prefix='jttms10-external-recovery-') as temp:
            verification = run(Path(temp)/'evidence')
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(verification, indent=2)+'\n')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
