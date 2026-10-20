#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Compare short Avalon event batches with an independent full-system bench."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

import check_results as checker
from event_cases import specifications
from event_contract import expected_pause
import event_contract
import irq_cases

HERE = Path(__file__).resolve().parent
MODULE = HERE.parents[1]
sys.path.insert(0, str(MODULE/'ver'))
from verilator_build import build_model


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fixture_manifest():
    specs = specifications()
    bases = {entry['name']: entry for entry in checker.prepare_cases(
        sorted({row['base'] for row in specs}), protocol_version=4)}
    entries = []
    for identifier, spec in enumerate(specs):
        if spec['base'] not in bases:
            raise ValueError('missing original independent fixture: '+spec['base'])
        entry = copy.deepcopy(bases[spec['base']])
        entry['id'] = identifier
        entry['base_fixture_name'] = spec['base']
        entry['name'] += '__'+spec['label']
        entry['fixture']['name'] = entry['name']
        entry['external_events'] = [dict(event, argument=entry['fixture']['follow_pc'])
                                   if event['argument'] == 'follow_pc' else dict(event)
                                   for event in spec['events']]
        if 'contract' in spec:
            entry['external_contract'] = spec['contract']
        entry['stimulus'] = dict(wait_states=spec.get('wait_states', 0))
        entries.append(entry)
    for entry in irq_cases.entries(bases['nop_hit'], checker.oracle_module()):
        entry['id'] = len(entries)
        entries.append(entry)
    return dict(format=checker.FORMAT_V4, protocol_version=4,
                oracle_sha256=sha(checker.TIMING/'run.py'),
                batches=checker.make_batches(entries, protocol_version=4))


def watch_flags(case):
    return (int(bool(case.get('expected_extra_regs'))) |
            (2 if any(key in case for key in ('control_flow', 'stack_control_flow', 'call_flow', 'trap_flow')) else 0) |
            (4 if case.get('observe_implicit') or case.get('observe_all') else 0) |
            (8 if case.get('observe_all') else 0) | (16 if 'data_line' in case else 0))


def reference_case(entry, executable, work, output, oracle):
    case = copy.deepcopy(entry['fixture'])
    for key in ('initial_memory', 'expected_memory', 'expected_follow_memory'):
        if key in case:
            case[key] = [tuple(pair) for pair in case[key]]
    image = [0]*4096
    image[256:256+len(entry['program_words'])] = entry['program_words']
    (work/'program.mem').write_text(''.join(f'{word:04x}\n' for word in image))
    memory = case.get('initial_memory', [])
    (work/'data.mem').write_text(''.join(f'{address:08x} {value:04x}\n' for address, value in memory))
    events = entry.get('external_events', [])
    (work/'events.txt').write_text(str(len(events))+'\n'+''.join(
        f"{event['trigger']:x} {event['argument']:08x} {event['control']:04x}\n" for event in events))
    settings = checker.stimulus_for(entry)
    command = [str(executable), '+PROGRAM=program.mem', '+DATA=data.mem', '+EXTERNAL_EVENTS=events.txt',
        f"+CASE_ID={entry['id']}", f"+TEST_PC={entry['test_pc']:x}", f"+NEXT_PC={entry['next_pc']:x}",
        f"+MEASURE_PASS={case.get('measure_pass', 1)}", f'+DATA_COUNT={len(memory)}',
        f'+WATCH_EXTRA={watch_flags(case)}', f"+DRAIN_INSTRUCTIONS={case.get('drain_instructions', 0)}",
        f"+FOLLOW_PC={case.get('follow_pc', 0):x}", f"+WAIT={8*settings['wait_states']}",
        f"+PAUSE={settings['pause_clocks']}", f"+PAUSE_AFTER={settings['pause_after_clocks']}"]
    result = subprocess.run(command, cwd=work, capture_output=True, text=True, timeout=30)
    log = result.stdout+result.stderr
    (output/f"{entry['id']:03d}.log").write_text(log)
    if result.returncode:
        raise RuntimeError(f"{entry['name']}: original-system simulation exit {result.returncode}; see {output}")
    observed = oracle.parse_result(log)
    if observed['case'] != entry['id']:
        raise ValueError('reference case association mismatch')
    pause = settings['pause_clocks'] + expected_pause(entry)
    errors = oracle.check(case, observed, settings['wait_states'], pause)
    # Construct observation metadata from the independent bench's counters,
    # never from an Avalon result or expected instruction duration.
    summaries = [line for line in log.splitlines() if line.startswith('EXTERNAL_RESULT ')]
    if len(summaries) != 1:
        raise ValueError(f"{entry['name']}: missing/duplicate independent event summary")
    counters = dict(part.split('=') for part in summaries[0].split()[1:])
    keys = ('configured', 'applied', 'writes', 'holds', 'hosts', 'issued', 'error', 'last', 'paused')
    if set(counters) != set(keys):
        raise ValueError('malformed independent event summary')
    words = [0]*288
    words[2], words[7] = observed['clocks'], observed['start']
    words[278:287] = [int(counters[key]) for key in keys]
    for line in log.splitlines():
        if line.startswith('DRAIN '):
            words[272] = int(line.split()[1])
        elif line.startswith('FOLLOW '):
            words[203], words[204], words[206] = 1, int(line.split()[1].split('=')[1]), case['follow_pc']
    lines = [line for line in log.splitlines() if line.startswith(
        ('BUS_', 'TARGET_', 'STIMULUS ', 'HOLD_ACK ', 'HOST_ACK '))]
    errors.extend(checker.check_external_events(entry, words, lines))
    row = oracle.check_observation(case, observed, errors, log, settings['wait_states'], pause)
    follow_errors, irq_observation = event_contract.check_followup(entry, observed, log.splitlines())
    errors.extend(follow_errors)
    if irq_observation is not None:
        row['irq_observation'] = irq_observation
    if events or entry.get('external_contract') is not None:
        row['external_observation'] = checker.external_observation(words, lines)
        row['external_contract'] = copy.deepcopy(entry.get('external_contract'))
    return row


def run(manifest, output, reference_only=False):
    if checker.validate_manifest(manifest) != 4:
        raise ValueError('external reference requires protocol 4')
    entries = [entry for batch in manifest['batches'] for entry in batch['cases']]
    if not 1 <= len(entries) <= 64:
        raise ValueError('reference accepts 1..64 short cases; run long supported matrices on FPGA')
    output.mkdir(parents=True, exist_ok=False)
    (output/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    sources = [checker.TIMING/'test.sv', HERE/'reference_stimulus.sv', *sorted((MODULE/'hdl').glob('*.v'))]
    inputs = [*sources, *sorted(checker.TIMING.glob('*.py')), *sorted(HERE.glob('*.py')),
              MODULE/'ver/build.sh', MODULE/'ver/verilator_build.py',
              *sorted((MODULE/'ucode').glob('*.yaml'))]
    provenance = {str(p.relative_to(MODULE)): sha(p) for p in inputs}
    oracle = checker.oracle_module()
    rows = []
    with tempfile.TemporaryDirectory(prefix='jttms10-external-reference-') as temp:
        work = Path(temp)
        # The CPU's ROM filenames are relative to its simulation cwd.
        generated = work
        subprocess.run(['bash', str(MODULE/'ver/build.sh'), str(generated)],
                       check=True, stdout=subprocess.DEVNULL)
        try:
            executable = build_model(work/'obj', sources, includes=[generated],
                                     defines=['JTTMS10_EXTERNAL_REFERENCE'])
        finally:
            if (work/'obj/build.log').is_file():
                shutil.copyfile(work/'obj/build.log', output/'compile-reference.log')
        (output/'generated').mkdir()
        generated_hashes = {}
        for path in sorted(generated.iterdir()):
            if path.suffix in ('.uc', '.hex', '.vh'):
                generated_hashes[path.name] = sha(path)
                shutil.copyfile(path, output/'generated'/path.name)
        (output/'reference-logs').mkdir()
        for entry in entries:
            rows.append(reference_case(entry, executable, work, output/'reference-logs', oracle))
    reference = dict(cases=rows, source_sha256=provenance, generated_sha256=generated_hashes,
                     backend='original full-system Verilator with independent behavioral events')
    (output/'reference.json').write_text(json.dumps(reference, indent=2)+'\n')
    failures = [row['name'] for row in rows if row['errors']]
    for row in rows:
        print(row['name']+(': FAIL '+repr(row['errors']) if row['errors'] else ': PASS'), flush=True)
    if failures:
        raise RuntimeError('independent reference failed its unchanged ISA/event contract')
    verification = dict(cases=len(rows), original_oracle_pass=True, source_sha256=provenance,
                        generated_sha256=generated_hashes, reference_only=reference_only)
    if not reference_only:
        command = [sys.executable, str(HERE/'check_runner.py'), '--manifest', str(output/'manifest.json'),
                   '--reference', str(output/'reference.json'), '--output', str(output/'avalon')]
        result = subprocess.run(command, capture_output=True, text=True)
        (output/'avalon-command.log').write_text(result.stdout+result.stderr)
        if result.returncode:
            raise RuntimeError(f'Avalon/reference comparison failed: exit {result.returncode}; see {output}')
        report = json.loads((output/'avalon/report.json').read_text())
        if report['reference_comparison_errors']:
            raise ValueError('cross-backend observation mismatch')
        verification.update(avalon_command=command, avalon_exit=0, cross_backend_differences=0)
    if any(sha(MODULE/path) != digest for path, digest in provenance.items()):
        raise RuntimeError('reference source changed during validation')
    (output/'verification.json').write_text(json.dumps(verification, indent=2)+'\n')
    return verification


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=Path)
    parser.add_argument('--output', type=Path, help='new directory retaining raw reference and Avalon evidence')
    parser.add_argument('--report', type=Path)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument('--reference-only', action='store_true', help='prepare references for later physical comparison')
    modes.add_argument('--prepare-only', action='store_true', help='write runtime fixtures without building a local model')
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text()) if args.manifest else fixture_manifest()
    if args.prepare_only:
        if args.output is None or args.report is not None:
            parser.error('--prepare-only requires --output and does not produce a validation --report')
        if checker.validate_manifest(manifest) != 4:
            parser.error('external fixtures require protocol 4')
        args.output.mkdir(parents=True, exist_ok=False)
        (args.output/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
        return 0
    if args.output:
        result = run(manifest, args.output.resolve(), args.reference_only)
    else:
        with tempfile.TemporaryDirectory(prefix='jttms10-event-check-') as temp:
            result = run(manifest, Path(temp)/'evidence', args.reference_only)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2)+'\n')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
