#!/usr/bin/env python3
"""Prepare/replay completed replacement-history cases; never opens hardware."""
import argparse
import concurrent.futures
import csv
import hashlib
import json
import math
import pathlib
import re
import subprocess
import time

TASK = pathlib.Path(__file__).resolve().parents[1]
VALIDATION = TASK / 'artifacts/model-history-validation'
MODELS = {
    'jt51': (VALIDATION / 'jt51-build/Vjt51', '3014dd1250015a8f7b221d662974d1dc1a12ffc9742f57fd5d597307a8162b16'),
    'opm': (VALIDATION / 'opm-build/opm-oracle', 'ef5311f272f048dc6f3d822efad55254c4277b33fda144331c1b750e16391ffe'),
}
ENERGY = TASK / 'artifacts/raw-energy-preparation-v1/raw-energy'
ENERGY_SHA = '26da7220454a9950d9a6ee29613b007d0e2b4dc25c89b2af7222c7c443e06866'
HZ = 3580000
FRAMES = 16384
LIMITS = [
    'Replacement trace, not the missing original CSV; expanded timing, not continuous MAME timing.',
    'Host commit API endpoints and reply endpoints are not physical accepted-write timestamps.',
    '37.5 clocks/count plus public-model write overhead differs from assembled CPU overhead.',
    'Model capture begins at EVENT execution; physical ARM precedes EVENT upload/commit. No alignment or age equivalence.',
    'Host gaps are nominal estimates, not confidence bounds on actual chip idle time. No implicit settle.',
    'Raw validity and descriptive energy do not establish resolved envelope, model agreement, or a causal defect.',
]


def sha(path):
    return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()


def load(path):
    return json.loads(pathlib.Path(path).read_text())


def save(path, obj):
    with pathlib.Path(path).open('x') as f:
        json.dump(obj, f, indent=2, allow_nan=False)
        f.write('\n')


def checked_path(path):
    p = pathlib.Path(path)
    if not p.is_absolute() or not p.is_file():
        raise ValueError('expected existing absolute file: ' + str(path))
    return p


def program(path):
    data = checked_path(path).read_bytes()
    if not 1 <= len(data) <= 8192:
        raise ValueError('program size')
    writes, delays, i = [], 0, 0
    while i < len(data):
        op = data[i]
        i += 1
        if op == 0:
            if i != len(data):
                raise ValueError('trailing bytecode')
            return {'path': str(path), 'sha256': sha(path), 'bytes': len(data),
                    'write_count': len(writes), 'writes': writes, 'delay_counts': delays}
        if op in (1, 2):
            if i + 2 > len(data):
                raise ValueError('truncated instruction')
            a, b = data[i:i+2]
            i += 2
            if op == 1:
                writes.append([a, b])
            else:
                delays += a + 256*b
        elif op != 3:
            raise ValueError('unknown instruction')
    raise ValueError('missing END')


def commit(submission):
    calls = [x for x in submission['api_calls'] if
             x['kind'] == 'ROM_API_write' and x['offset'] == 8192 and x['length'] == 2]
    if len(calls) != 1:
        raise ValueError('generation commit must be unique')
    lo, hi = calls[0]['host_start'], calls[0]['host_end']
    if not (math.isfinite(lo) and math.isfinite(hi) and lo <= hi):
        raise ValueError('invalid commit endpoints')
    return {'host_start': lo, 'host_end': hi, 'midpoint': (lo + hi)/2}


def gap(previous, current):
    c = commit(current)
    if previous is None:
        return {'gap_master_clocks': 0, 'origin': 'first model history row; no physical reset/age equivalence',
                'next_commit': c}
    end = previous.get('reply_host_end', previous.get('host_end'))
    pc = commit(previous)
    low, high = c['host_start'] - end, c['host_end'] - end
    if not (math.isfinite(end) and low >= 0):
        raise ValueError('nonordered host submissions')
    nominal = c['midpoint'] - end
    return {'gap_master_clocks': math.floor(nominal*HZ + .5),
            'previous_reply_host_end': end, 'next_commit': c,
            'nominal_host_seconds': nominal,
            'host_endpoint_interval_seconds': [low, high],
            'previous_completion_to_next_commit_conservative_outer_seconds':
                [max(0, low), c['host_end'] - pc['host_start']],
            'interval_scope': 'Host API/reply bounds only; nominal excludes unknown reply polling and CPU completion lag.'}


def pin(pins, path, expected=None):
    p = checked_path(path)
    actual = sha(p)
    if expected is not None and actual != expected:
        raise ValueError('hash mismatch: ' + str(p))
    pins[str(p)] = actual
    return str(p)


def prepare(results, plan_dir, output):
    plan_dir, output = pathlib.Path(plan_dir).resolve(), pathlib.Path(output).resolve()
    if output.exists():
        raise ValueError('output already exists')
    plan_dir.mkdir(parents=True, exist_ok=False)
    raw = pathlib.Path(results).read_bytes()  # one immutable snapshot of the live aggregate
    (plan_dir/'results-snapshot.json').write_bytes(raw)
    source = json.loads(raw)
    pins = {}
    pin(pins, __file__)
    pin(pins, plan_dir/'results-snapshot.json')
    for name, (exe, digest) in MODELS.items():
        pin(pins, exe, digest)
        for filename in ('test.cpp', 'sim.sh', 'README.md'):
            pin(pins, TASK/'ver'/name/filename)
    pin(pins, VALIDATION/'handoff.json', '9cf3ced69d99b954e772a6b41d20c1bd4160f2593f382822b4e07fef36f94112')
    pin(pins, ENERGY, ENERGY_SHA)
    end = plan_dir/'end.bin'
    end.write_bytes(b'\0')
    pin(pins, end)
    selected, skipped, jobs, seen = [], [], [], set()
    for record in source['cases']:
        case = record['case']
        name = case['name']
        if name.startswith('natural') or record['state'] != 'complete':
            skipped.append({'name': name, 'reason': 'natural partial/retake excluded' if name.startswith('natural') else 'incomplete'})
            continue
        if name in seen or not re.fullmatch(r'[A-Za-z0-9_-]+', name):
            raise ValueError('duplicate/unsafe case name')
        seen.add(name)
        cap = load(pin(pins, record['capture_report']))
        quiet = load(pin(pins, record['quiet_report']))
        if cap['state'] != 'complete' or quiet['state'] != 'complete':
            raise ValueError('closed capture/quiet metadata required')
        if case['stride'] not in (1, 3, 32) or cap['stereo_stride'] != case['stride'] or cap['requested_words'] != 32768:
            raise ValueError('capture geometry')
        if cap['nominal_master_clock_hz'] != HZ:
            raise ValueError('clock provenance')
        init, event = program(case['init']), program(case['event'])
        pin(pins, case['init'], cap['init_sha256'])
        pin(pins, case['event'], cap['event_sha256'])
        rows, previous = [], None
        if case['history']:
            history = load(pin(pins, record['history_report']))
            if history['state'] != 'complete' or history['clock_hz'] != HZ or len(history['chunks']) != 80:
                raise ValueError('expected closed complete80 history')
            for index, chunk in enumerate(history['chunks']):
                if chunk['index'] != index:
                    raise ValueError('history ordering')
                p = program(chunk['program'])
                pin(pins, p['path'], chunk['sha256'])
                rows.append({**p, 'timing': gap(previous, chunk)})
                previous = chunk
            if sum(x['write_count'] for x in rows) != 107813:
                raise ValueError('complete prefix write count')
        rows.append({**init, 'timing': gap(previous, cap['init_submission'])})
        rows.append({**program(str(end)), 'timing': gap(cap['init_submission'], cap['event_submission'])})
        if sum(x['write_count'] for x in rows) + event['write_count'] > 2000000:
            raise ValueError('aggregate write guard')
        tsv = plan_dir/(name+'.tsv')
        with tsv.open('x') as f:
            f.write('program\tgap_before_master_clocks\n')
            for row in rows:
                f.write(row['path']+'\t'+str(row['timing']['gap_master_clocks'])+'\n')
        pin(pins, tsv)
        selected.append({'case': case, 'physical_record': record, 'history_rows': rows,
                         'event': event, 'history_tsv': str(tsv),
                         'physical_arm_host_start': cap['arm_host_start'],
                         'physical_event_commit': commit(cap['event_submission']),
                         'outer_init_reply_host_monotonic': cap['init_reply_host_monotonic']})
        for model, (exe, _) in MODELS.items():
            ident = name+'-'+model
            csvpath = output/ident/'samples.csv'
            argv = [str(exe), '--history', str(tsv), '--delay-clocks', '37.5', '--stride', str(case['stride']),
                    '--event', str(end), case['event'], str(csvpath), str(FRAMES)]
            descriptors = [[str(ENERGY), '-input', str(csvpath), '-column', col, '-frames', str(FRAMES),
                            '-stride', str(case['stride']), '-native-rate', '55937.5', '-kind', 'target',
                            '-case', name, '-output', str(output/ident/(col+'-energy.json'))] for col in ('left', 'right')]
            jobs.append({'id': ident, 'case_index': len(selected)-1, 'model': model, 'argv': argv,
                         'CSV': str(csvpath), 'descriptors': descriptors})
    if not jobs:
        raise ValueError('no completed eligible cases')
    plan = {'state': 'prepared_not_executed', 'source_results': str(pathlib.Path(results).resolve()),
            'results_snapshot': str(plan_dir/'results-snapshot.json'), 'output': str(output),
            'source_sha256': sha(__file__), 'pins': pins, 'cases': selected, 'skipped': skipped,
            'jobs': jobs, 'workers': 3, 'model_wall_seconds': 600, 'descriptor_wall_seconds': 60,
            'frames': FRAMES, 'limits': LIMITS}
    save(plan_dir/'plan.json', plan)
    return {'plan': str(plan_dir/'plan.json'), 'sha256': sha(plan_dir/'plan.json'), 'cases': len(selected), 'jobs': len(jobs)}


def audit_model(job, case):
    p = pathlib.Path(job['CSV'])
    count, first, last, ranges = 0, None, None, {'left': [None, None], 'right': [None, None]}
    with p.open() as f:
        reader = csv.DictReader(f)
        if not {'sample', 'left', 'right', 'clock'} <= set(reader.fieldnames or []):
            raise ValueError('public CSV schema')
        for row in reader:
            clock = int(row['clock'])
            if int(row['sample']) != count or (last is not None and clock-last != 64*case['case']['stride']):
                raise ValueError('public sample order/cadence')
            first = clock if first is None else first
            last = clock
            for col in ranges:
                value = int(row[col])
                if not -32768 <= value <= 32767:
                    raise ValueError('PCM range')
                lo, hi = ranges[col]
                ranges[col] = [value if lo is None else min(lo, value), value if hi is None else max(hi, value)]
            count += 1
    if count != FRAMES:
        raise ValueError('public row count')
    with pathlib.Path(str(p)+'.events.csv').open() as f:
        events = list(csv.DictReader(f))
    if not events or events[0]['kind'] != 'capture_start' or any(x['kind'] != 'write' for x in events[1:]):
        raise ValueError('EVENT schema')
    if [[int(x['reg']), int(x['value'])] for x in events[1:]] != case['event']['writes']:
        raise ValueError('EVENT literal writes')
    start = int(events[0]['clock'])
    clocks = [int(x['clock']) for x in events[1:]]
    if clocks != sorted(clocks) or any(c < start for c in clocks) or not start <= first <= start+64:
        raise ValueError('EVENT clock sequence')
    with pathlib.Path(str(p)+'.history.csv').open() as f:
        journal = list(csv.DictReader(f))
    expected = case['history_rows']
    if len(journal) != len(expected)+2:
        raise ValueError('history journal count')
    for i, (actual, wanted) in enumerate(zip(journal, expected)):
        if actual['kind'] != 'history' or int(actual['index']) != i or actual['path'] != wanted['path'] or actual['sha256'] != wanted['sha256']:
            raise ValueError('history journal identity')
        if int(actual['write_count']) != wanted['write_count'] or int(actual['gap_requested_master_clocks']) != wanted['timing']['gap_master_clocks']:
            raise ValueError('history journal writes/gap')
    if journal[-2]['kind'] != 'init' or journal[-2]['sha256'] != hashlib.sha256(b'\0').hexdigest() or int(journal[-2]['write_count']) != 0:
        raise ValueError('CLI INIT must be END')
    if journal[-1]['kind'] != 'capture_start' or int(journal[-1]['clock_before']) != start or any(int(x['implicit_settle_master_clocks']) != 0 for x in journal):
        raise ValueError('implicit settle/capture marker')
    return {'raw_valid': True, 'rows': count, 'cadence_master_clocks': 64*case['case']['stride'],
            'first_clock': first, 'last_clock': last, 'capture_start_clock': start, 'ranges': ranges,
            'EVENT_write_count': len(clocks), 'EVENT_last_write_clock': clocks[-1] if clocks else None,
            'EVENT_last_write_before_last_sample': not clocks or clocks[-1] <= last,
            'history_rows': len(expected), 'implicit_settle_master_clocks': 0}


def process(argv, prefix, seconds):
    started = time.monotonic()
    with pathlib.Path(str(prefix)+'.stdout').open('x') as out, pathlib.Path(str(prefix)+'.stderr').open('x') as err:
        try:
            result = subprocess.run(argv, stdout=out, stderr=err, timeout=seconds, check=False)
            code, timeout = result.returncode, False
        except subprocess.TimeoutExpired:
            code, timeout = 124, True
    return {'argv': argv, 'exitcode': code, 'timeout': timeout, 'host_start': started,
            'host_end': time.monotonic(), 'wall_guard_seconds': seconds}


def run_one(job, plan):
    directory = pathlib.Path(job['CSV']).parent
    directory.mkdir(exist_ok=False)
    record = {'id': job['id'], 'case': plan['cases'][job['case_index']]['case'], 'model': job['model'], 'state': 'failed'}
    try:
        record['process'] = process(job['argv'], directory/'model', plan['model_wall_seconds'])
        if record['process']['exitcode'] != 0:
            raise ValueError('model process failed')
        record['raw_audit'] = audit_model(job, plan['cases'][job['case_index']])
        record['descriptors'] = []
        for argv in job['descriptors']:
            proc = process(argv, directory/pathlib.Path(argv[-1]).stem, plan['descriptor_wall_seconds'])
            record['descriptors'].append(proc)
            if proc['exitcode'] != 0:
                raise ValueError('raw descriptor process failed')
            report = load(argv[-1])
            if report['input_sha256'] != sha(job['CSV']) or report['column'] != argv[4]:
                raise ValueError('descriptor identity')
        record['state'] = 'complete'
    except Exception as exc:
        record['error'] = str(exc)
    record['output_pins'] = {str(p): sha(p) for p in sorted(directory.iterdir()) if p.is_file()}
    save(directory/'record.json', record)
    return record


def execute(plan_path, binding_path):
    plan, binding = load(plan_path), load(binding_path)
    if not (binding.get('authorized_by') == 'ROOT' and binding.get('authorize_model_once') is True
            and binding.get('plan_sha256') == sha(plan_path) and binding.get('runner_sha256') == sha(__file__)
            and binding.get('job_count') == len(plan['jobs'])):
        raise ValueError('explicit ROOT execution binding required')
    for path, digest in plan['pins'].items():
        if sha(path) != digest:
            raise ValueError('changed input: '+path)
    out = pathlib.Path(plan['output'])
    out.mkdir(parents=True, exist_ok=False)
    save(out/'execution-binding.json', {'path': str(pathlib.Path(binding_path).resolve()), 'sha256': sha(binding_path),
                                      'plan_path': str(pathlib.Path(plan_path).resolve()), 'plan_sha256': sha(plan_path)})
    records, index, stop = [], 0, False
    with concurrent.futures.ThreadPoolExecutor(max_workers=plan['workers']) as pool:
        active = {}
        while active or (index < len(plan['jobs']) and not stop):
            while not stop and len(active) < plan['workers'] and index < len(plan['jobs']):
                job = plan['jobs'][index]
                active[pool.submit(run_one, job, plan)] = job['id']
                index += 1
            done, _ = concurrent.futures.wait(active, return_when=concurrent.futures.FIRST_COMPLETED)
            for future in done:
                ident = active.pop(future)
                try:
                    record = future.result()
                except Exception as exc:
                    record = {'id': ident, 'state': 'failed', 'error': str(exc)}
                records.append(record)
                stop |= record['state'] != 'complete'
                save(out/('progress-%03d.json' % len(records)), {'records': records, 'submitted': index, 'stop_new_submissions': stop})
                print(json.dumps({'completed': len(records), 'total': len(plan['jobs']), 'id': ident, 'state': record['state']}), flush=True)
    changed = [p for p, digest in plan['pins'].items() if sha(p) != digest]
    passed = not stop and not changed and len(records) == len(plan['jobs'])
    save(out/'reference.json', {'state': 'complete' if passed else 'failed_retained_no_retry', 'records': records,
                               'submitted': index, 'planned': len(plan['jobs']), 'changed_inputs': changed, 'limits': LIMITS})
    save(out/'TERMINAL.json', {'exitcode': 0 if passed else 1, 'submitted': index, 'completed_records': len(records),
                              'reference_sha256': sha(out/'reference.json')})
    return 0 if passed else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    prep = sub.add_parser('prepare')
    prep.add_argument('--results', required=True)
    prep.add_argument('--plan-dir', required=True)
    prep.add_argument('--output', required=True)
    run = sub.add_parser('execute')
    run.add_argument('--plan', required=True)
    run.add_argument('--ROOT-binding', required=True)
    args = parser.parse_args()
    if args.action == 'prepare':
        print(json.dumps(prepare(args.results, args.plan_dir, args.output)))
        return 0
    return execute(args.plan, args.ROOT_binding)


if __name__ == '__main__':
    raise SystemExit(main())
