#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Prepare FPGA batches and check observations using the independent timing suite.

This module performs no SSH, device access or FPGA programming. Protocol v1
initially supports read-only scalar programs with zero waits and no CEN pause.
Unsupported fixture requirements fail explicitly rather than losing checks.
"""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
TIMING = HERE.parent / 'timing'
MAX_CASES = 32
MAX_WORDS = 4096
RESULT_WORDS = 72
FORMAT = 'jttms10-fpga-batch-v1'
MASK32 = (1 << 32) - 1
# Explicit fixture-family selection, not a verdict allowlist. Every selected
# fixture still passes require_supported and every existing oracle assertion.
READ_ONLY_TERMS = ['mpys_', 'mpyu_', 'nop_hit', 'nop_off', 'nop_next_subsegment_miss_',
                   'add_hit', 'add_off', 'movk_hit', 'movk_off', 'sla_', 'sll_', 'sra_',
                   'srl_', 'rl_', 'lmo_', 'scalar_', 'divs_', 'divu_', 'mods_', 'modu_',
                   'immediate_', 'xy_addxy_', 'xy_subxy_', 'xy_cmpxy_',
                   'coordinate_cpw_', 'coordinate_cvxyl_', 'emu_run_']


def oracle_module():
    # The fixture generator and all expectations remain owned by timing/run.py.
    if str(TIMING) not in sys.path:
        sys.path.insert(0, str(TIMING))
    spec = importlib.util.spec_from_file_location('jttms10_timing_oracle', TIMING / 'run.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def require_supported(case):
    # Fail closed when fixtures gain a new observation or stimulus requirement.
    # A blacklist would silently discard checks added to the software backend.
    supported = {'name', 'opcode', 'regs', 'expected_regs', 'expected_st', 'states',
                 'cache_disabled', 'cache_miss', 'extensions', 'expected_extra_regs',
                 'expected_masks', 'initial_b_regs', 'initial_sp', 'observe_implicit',
                 'instruction_word_offset', 'measure_pass', 'miss_word', 'setup_io',
                 'pc_result_register', 'test_pc', 'next_pc', 'citation', 'conditions',
                 'coverage_id', 'source_conflict_kind', 'source_notes',
                 'source_result_register', 'source_values', 'timing_source_status'}
    found = sorted(set(case) - supported)
    if found:
        raise ValueError(f"{case['name']}: unsupported FPGA fixture requirements: {', '.join(found)}")


def prepare_cases(terms, limit=None):
    if not terms:
        raise ValueError('select cases explicitly with at least one --case')
    oracle = oracle_module()
    entries = []
    for original in oracle.cases():
        if not any(term in original['name'] for term in terms):
            continue
        require_supported(original)
        case = copy.deepcopy(original)
        words, test_pc, next_pc = oracle.program(case)
        if not 0 < len(words) <= 3840:
            raise ValueError(f"{case['name']}: program does not fit the FPGA target")
        if not 0x1000 <= test_pc < next_pc < 0x10000:
            raise ValueError(f"{case['name']}: unsupported program measurement interval")
        case.update(test_pc=test_pc, next_pc=next_pc)
        entries.append(dict(id=len(entries), name=case['name'], fixture=case,
                            program_words=words, test_pc=test_pc, next_pc=next_pc))
        if limit is not None and len(entries) >= limit:
            break
    if not entries:
        raise ValueError('no matching timing fixtures')
    return entries


def make_batches(entries):
    batches = []
    batch = dict(cases=[], program_words=[], descriptors=[])
    identifiers = set()
    for entry in entries:
        words = entry['program_words']
        identifier = u32(entry['id'])
        if identifier in identifiers:
            raise ValueError('duplicate external case identifier')
        identifiers.add(identifier)
        if not words or len(words) > 3840 or any(type(v) is not int or not 0 <= v <= 0xffff for v in words):
            raise ValueError(f"{entry['name']}: invalid program length")
        if len(batch['cases']) == MAX_CASES or len(batch['program_words']) + len(words) > MAX_WORDS:
            batches.append(batch)
            batch = dict(cases=[], program_words=[], descriptors=[])
        batch['descriptors'].append([entry['id'], len(batch['program_words']), len(words),
                                     entry['test_pc'], entry['next_pc'],
                                     entry['fixture'].get('measure_pass', 1), 0, 0])
        batch['cases'].append(entry)
        batch['program_words'].extend(words)
    if batch['cases']:
        batches.append(batch)
    return batches


def u32(value):
    if type(value) is not int or not 0 <= value <= MASK32:
        raise ValueError(f'invalid protocol word: {value!r}')
    return value


def decode_events(raw, case_count):
    if not isinstance(raw, list) or len(raw) > 4096:
        raise ValueError('invalid event buffer length')
    lines = [[] for _ in range(case_count)]
    previous_case = -1
    previous_clock = -1
    counts = [0] * case_count
    for words in raw:
        if not isinstance(words, list) or len(words) != 4:
            raise ValueError('each event must contain four words')
        clock, data, address, flags = map(u32, words)
        index = (flags >> 9) & 31
        if flags >> 14 or index >= case_count or not flags & 0x1e0:
            raise ValueError('invalid event flags or case association')
        if index < previous_case or (index == previous_case and clock < previous_clock):
            raise ValueError('event order is not chronological within the case sequence')
        previous_case, previous_clock = index, clock
        counts[index] += 1
        if counts[index] > 128:
            raise ValueError('event buffer exceeds its per-case bound')
        kind, iaq = (flags >> 1) & 15, flags & 1
        for bit, prefix, complete in ((6, 'BUS', False), (5, 'BUS', True),
                                      (8, 'TARGET', False), (7, 'TARGET', True)):
            if flags & (1 << bit):
                # Preserve the simulation contract: logical allocations use the
                # enclosing TI state boundary; raw target dispatch is unrounded.
                when = clock - clock % 8 if prefix == 'BUS' and not complete else clock
                value = data & 0xffff if complete else data >> 16
                line = f'{prefix}_{"END" if complete else "BEGIN"} {when} {kind} {address:08x} {value:04x}'
                if not complete:
                    line += f' {iaq}'
                lines[index].append(line)
                if prefix == 'BUS' and not complete:
                    lines[index].append(f'BUS_ACCEPT {clock}')
    return lines


def check_batch(batch, capture):
    entries = batch['cases']
    if not 0 < len(entries) <= MAX_CASES:
        raise ValueError('invalid batch case count')
    if len({entry['id'] for entry in entries}) != len(entries):
        raise ValueError('duplicate external case identifier')
    count = u32(capture['event_count'])
    if count & 0x80000000:
        raise ValueError('FPGA diagnostic trace overflow')
    if u32(capture['status']) != 2:
        failures = []
        for result in capture.get('results', []):
            if isinstance(result, list) and len(result) >= 2 and type(result[1]) is int and result[1] != 2:
                failures.append(f'case id={result[0]} status=0x{result[1]:08x}')
        detail = '; '.join(failures) or 'no failing case result was returned'
        raise ValueError(f"FPGA batch did not succeed: status=0x{capture['status']:08x}; {detail}")
    if count != len(capture['events']):
        raise ValueError('event count differs from the drained buffer length')
    results = capture['results']
    if not isinstance(results, list) or len(results) != len(entries):
        raise ValueError('result count differs from the requested case count')
    traces = decode_events(capture['events'], len(entries))
    oracle = oracle_module()
    rows = []
    for index, (entry, result) in enumerate(zip(entries, results)):
        case = entry['fixture']
        require_supported(case)
        if not isinstance(result, list) or len(result) != RESULT_WORDS:
            raise ValueError(f"{entry['name']}: malformed result length")
        result = list(map(u32, result))
        errors = []
        if result[0] != entry['id']:
            errors.append(f"case identifier mismatch: expected {entry['id']}, observed {result[0]}")
        if result[1] != 2:
            errors.append(f'case execution failed: status=0x{result[1]:08x}')
        if result[3:5] != [entry['test_pc'], entry['next_pc']]:
            errors.append('measurement PC association mismatch')
        if result[7] + result[2] > MASK32 or result[2] == 0:
            errors.append('invalid or wrapped measurement clocks')
        observed = dict(case=result[0], clocks=result[2], start=result[7],
                        end=result[7] + result[2], paused=0, st=result[6])
        required = {f'a{q}': q for q in range(len(case['expected_regs']))}
        for name in case.get('expected_extra_regs', {}):
            if name == 'sp':
                required[name] = 15
            elif len(name) > 1 and name[0] in 'ab' and name[1:].isdigit() and int(name[1:]) < 16:
                logical = int(name[1:])
                required[name] = 15 if logical == 15 else logical + (16 if name[0] == 'b' else 0)
            else:
                raise ValueError(f'unsupported architectural observation {name!r}')
        for name, slot in required.items():
            value = result[8 + slot]
            if value == 0xdead0000 + slot:
                errors.append(f'{name.upper()}: RF shadow slot was not initialized')
            observed[name] = value
        word = (entry['next_pc'] - 0x1000) // 16
        if word >= len(entry['program_words']) or result[5] != entry['program_words'][word]:
            errors.append('next accepted opcode differs from the fixture program')
        errors.extend(oracle.check(case, observed, 0, 0))
        log = '\n'.join(traces[index])
        rows.append(oracle.check_observation(case, observed, errors, log, 0, 0))
    failures = sum(bool(row['errors']) for row in rows)
    return dict(cases=rows, passed=len(rows) - failures, failed=failures)


def compare_reference(rows, reference_rows):
    """Compare validated captures with the original bench, relative to decode."""
    actual = {row['name']: row for row in rows}
    reference = {row['name']: row for row in reference_rows}
    if len(actual) != len(rows) or len(reference) != len(reference_rows):
        return ['duplicate case names in cross-backend comparison']
    if actual.keys() != reference.keys():
        return ['case inventory differs between FPGA and reference captures']
    errors = []
    for name, row in actual.items():
        other = reference[name]
        if row['errors'] or other['errors']:
            errors.append(name+': failing input capture cannot establish equivalence')
            continue
        for key in ('opcode', 'regs', 'expected_regs', 'expected_st', 'states',
                    'cache_disabled', 'extensions', 'expected_extra_regs', 'test_pc', 'next_pc'):
            if row.get(key) != other.get(key):
                errors.append(name+': fixture '+key+' differs')
        observed, golden = row['observed'], other['observed']
        fields = ['clocks', 'st', 'paused', *[f'a{q}' for q in range(len(row['expected_regs']))],
                  *row.get('expected_extra_regs', {})]
        for key in fields:
            if observed.get(key) != golden.get(key):
                errors.append(name+': observed '+key+' differs')
        for key in ('bus_trace', 'target_trace'):
            normalized = []
            for item in (row, other):
                lines = []
                for line in item[key]:
                    parts = line.split()
                    parts[1] = str(int(parts[1]) - item['observed']['start'])
                    lines.append(' '.join(parts))
                normalized.append(lines)
            if normalized[0] != normalized[1]:
                errors.append(name+': '+key+' differs relative to accepted decode')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    prepare = sub.add_parser('prepare')
    prepare.add_argument('--case', action='append', default=[])
    prepare.add_argument('--read-only-matrix', action='store_true',
                         help='select the documented scalar/XY/coordinate/EMU RUN-high families')
    prepare.add_argument('--limit', type=int)
    prepare.add_argument('--output', type=Path, required=True)
    check = sub.add_parser('check')
    check.add_argument('manifest', type=Path)
    check.add_argument('capture', type=Path)
    check.add_argument('--batch', type=int, default=0)
    check.add_argument('--report', type=Path)
    compare = sub.add_parser('compare', help='compare a checked multi-batch capture with Verilator')
    compare.add_argument('manifest', type=Path)
    compare.add_argument('capture', type=Path)
    compare.add_argument('reference', type=Path)
    compare.add_argument('--report', type=Path)
    args = parser.parse_args()
    try:
        if args.command == 'prepare':
            if args.limit is not None and args.limit < 1:
                raise ValueError('--limit must be positive')
            terms = args.case + (READ_ONLY_TERMS if args.read_only_matrix else [])
            entries = prepare_cases(terms, args.limit)
            data = dict(format=FORMAT, batches=make_batches(entries),
                        oracle_sha256=hashlib.sha256((TIMING / 'run.py').read_bytes()).hexdigest())
            args.output.write_text(json.dumps(data, indent=2) + '\n')
            print(f"Prepared {len(entries)} cases in {len(data['batches'])} batches")
            return 0
        manifest = json.loads(args.manifest.read_text())
        if manifest['format'] != FORMAT:
            raise ValueError('unsupported manifest format')
        if args.command == 'compare':
            captures = json.loads(args.capture.read_text())['batches']
            if not isinstance(captures, list) or not captures or len(captures) != len(manifest['batches']):
                raise ValueError('capture batch count differs from the manifest')
            reports = [check_batch(batch, captured)
                       for batch, captured in zip(manifest['batches'], captures)]
            rows = [row for report in reports for row in report['cases']]
            differences = compare_reference(rows, json.loads(args.reference.read_text())['cases'])
            report = dict(batches=reports, passed=sum(x['passed'] for x in reports),
                          failed=sum(x['failed'] for x in reports),
                          reference_comparison_errors=differences)
            if args.report:
                args.report.write_text(json.dumps(report, indent=2) + '\n')
            for row in rows:
                for error in row['errors']:
                    print(f"{row['name']}: {error}", file=sys.stderr)
            for error in differences:
                print(error, file=sys.stderr)
            print(f"Checked {len(rows)} cases: {report['failed']} failed, "
                  f"{len(differences)} reference differences")
            return int(bool(report['failed']) or bool(differences))
        if not 0 <= args.batch < len(manifest['batches']):
            raise ValueError('invalid batch index')
        report = check_batch(manifest['batches'][args.batch], json.loads(args.capture.read_text()))
        if args.report:
            args.report.write_text(json.dumps(report, indent=2) + '\n')
        for row in report['cases']:
            print(f"{row['name']}: {'FAIL' if row['errors'] else 'PASS'}")
            for error in row['errors']:
                print('  ' + error)
        return int(bool(report['failed']))
    except (ValueError, KeyError, TypeError, IndexError) as error:
        print(f'FPGA result error: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
