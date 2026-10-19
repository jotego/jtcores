#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate representative Avalon runner batches in Verilator before FPGA use."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

import check_results as checker

HERE = Path(__file__).resolve().parent
MODULE = HERE.parents[1]


def parse_captures(log):
    captures = []
    active = None
    for line in log.splitlines():
        if not line.startswith('CAPTURE_'):
            continue
        fields = line.split()
        if fields[0] == 'CAPTURE_BEGIN':
            if active is not None or int(fields[1]) != len(captures):
                raise ValueError('invalid capture batch association')
            active = dict(status=int(fields[2], 16), protocol_version=int(fields[3]) if len(fields) == 4 else 1,
                          results=[], events=[])
        elif active is None:
            raise ValueError('capture data outside a batch')
        elif fields[0] == 'CAPTURE_RESULT':
            if int(fields[1]) != len(active['results']):
                raise ValueError('duplicate or reordered capture result')
            active['results'].append([int(x, 16) for x in fields[2:]])
        elif fields[0] == 'CAPTURE_COUNT':
            if 'event_count' in active:
                raise ValueError('duplicate event count')
            active['event_count'] = int(fields[1], 16)
        elif fields[0] == 'CAPTURE_EVENT':
            active['events'].append([int(x, 16) for x in fields[1:]])
        elif fields[0] == 'CAPTURE_END':
            if int(fields[1]) != len(captures):
                raise ValueError('incorrect closing batch identifier')
            captures.append(active)
            active = None
        else:
            raise ValueError('unknown capture record')
    if active is not None:
        raise ValueError('unterminated capture')
    return captures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument('--case', action='append')
    selection.add_argument('--manifest', type=Path, help='prepared batches, including deliberate descriptor negatives')
    parser.add_argument('--limit', type=int)
    parser.add_argument('--batch-size', type=int, default=32)
    parser.add_argument('--timeout-cycles', type=int, default=4_000_000)
    parser.add_argument('--wait-states', type=int, default=0)
    parser.add_argument('--pause-clocks', type=int, default=0)
    parser.add_argument('--pause-after-clocks', type=int, default=0)
    parser.add_argument('--reference', type=Path, help='original timing/run.py JSON for these exact cases')
    parser.add_argument('--output', type=Path, required=True, help='new evidence directory')
    args = parser.parse_args()
    if not 1 <= args.batch_size <= 32:
        parser.error('batch size must be 1..32')
    if not 1000 <= args.timeout_cycles <= 0xffffffff:
        parser.error('timeout must be 1000..4294967295 input clocks')
    output = args.output.resolve()
    if output.exists():
        parser.error('output directory must be new')
    output.mkdir(parents=True)
    if args.manifest:
        manifest = json.loads(args.manifest.read_text())
        if manifest.get('format') != checker.FORMAT or not manifest.get('batches'):
            parser.error('unsupported or empty manifest')
        batches = manifest['batches']
    else:
        entries = checker.prepare_cases(args.case, args.limit, 2,
                                       dict(wait_states=args.wait_states, pause_clocks=args.pause_clocks,
                                            pause_after_clocks=args.pause_after_clocks))
        batches = []
        for q in range(0, len(entries), args.batch_size):
            batches.extend(checker.make_batches(entries[q:q+args.batch_size]))
        manifest = dict(format=checker.FORMAT, protocol_version=2, batches=batches)
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    started = time.monotonic()
    with tempfile.TemporaryDirectory(prefix='jttms10-fpga-verify-') as temp:
        work = Path(temp)
        subprocess.run(['bash', str(MODULE/'ver/build.sh'), str(work)], check=True,
                       stdout=subprocess.DEVNULL)
        batch_lines = []
        for q, batch in enumerate(batches):
            desc = [word for entry in batch['descriptors'] for word in entry]
            program = batch['program_words']
            desc_file, program_file = work/f'desc-{q}.hex', work/f'program-{q}.hex'
            desc_file.write_text(''.join(f'{v:08x}\n' for v in desc+[0]*(384-len(desc))))
            program_file.write_text(''.join(f'{v:08x}\n' for v in program+[0]*(4096-len(program))))
            batch_lines.append(f"{len(batch['cases'])} {len(program)} {desc_file} {program_file}\n")
        (work/'batches.txt').write_text(''.join(batch_lines))
        sources = [HERE/'test_runner.sv', HERE/'jttms10_fpga_runner.v', *sorted((MODULE/'hdl').glob('*.v'))]
        command = ['verilator', '--binary', '--timing', '--top-module', 'test',
                   '--timescale-override', '1ns/1ps', '-Wno-EOFNEWLINE',
                   '-DJTTMS10_REGRESSION', '-j', '4', '--Mdir', str(work/'obj'),
                   '-I'+str(work), *map(str, sources)]
        inputs = [*sources, *sorted((MODULE/'ucode').glob('*.yaml')),
                  *sorted(checker.TIMING.glob('*.py')), MODULE/'ver/build.sh',
                  MODULE/'ver/decoder/generate.py', HERE/'check_results.py', HERE/'check_runner.py',
                  MODULE/'ver/gfx/check_targets.py', MODULE/'ver/gfx/check_flow.py']
        provenance = {str(p.relative_to(MODULE)):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
        generated = {}
        (output/'generated').mkdir()
        for suffix in ('*.uc', '*.hex', '*.vh'):
            for path in sorted(work.glob(suffix)):
                generated[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
                shutil.copyfile(path, output/'generated'/path.name)
        toolchain = dict(verilator=subprocess.check_output(['verilator', '--version'], text=True).strip(),
                         python=sys.version,
                         jtframe_sha256=hashlib.sha256((MODULE.parent/'jtframe/bin/jtframe').read_bytes()).hexdigest())
        (output/'provenance.json').write_text(json.dumps(dict(source_sha256=provenance,
            generated_sha256=generated, toolchain=toolchain), indent=2)+'\n')
        compiled = subprocess.run(command, capture_output=True, text=True)
        (output/'compile.log').write_text(compiled.stdout+compiled.stderr)
        compiled.check_returncode()
        result = subprocess.run([str(work/'obj/Vtest'), '+BATCHES='+str(work/'batches.txt'),
                                 '+TIMEOUT='+str(args.timeout_cycles)],
                                cwd=work, capture_output=True, text=True, timeout=60)
        log = result.stdout+result.stderr
        (output/'run.log').write_text(log)
        result.check_returncode()
    captures = parse_captures(log)
    if len(captures) != len(batches):
        raise ValueError('wrong number of completed batches')
    reports = []
    for index, (batch, capture) in enumerate(zip(batches, captures)):
        (output/f'capture-{index}.json').write_text(json.dumps(capture, indent=2)+'\n')
        try:
            reports.append(checker.check_batch(batch, capture))
        except ValueError as error:
            reports.append(dict(cases=[], passed=0, failed=len(batch['cases']),
                                protocol_errors=[str(error)]))
    report = dict(batches=reports, elapsed_seconds=time.monotonic()-started,
                  source_sha256=provenance, generated_sha256=generated,
                  toolchain=toolchain, backend='Verilator Avalon runner')
    reference_errors = []
    if args.reference:
        reference = json.loads(args.reference.read_text())
        reference_errors = checker.compare_reference(
            [row for batch in reports for row in batch['cases']], reference['cases'])
        report['reference_comparison_errors'] = reference_errors
    (output/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    for batch in reports:
        for error in batch.get('protocol_errors', []):
            print('Protocol failure: '+error)
        for row in batch['cases']:
            print(f"{row['name']}: {'FAIL' if row['errors'] else 'PASS'}")
            for error in row['errors']:
                print('  '+error)
    for error in reference_errors:
        print('Reference mismatch: '+error)
    return int(bool(reference_errors) or any(batch['failed'] for batch in reports))


if __name__ == '__main__':
    raise SystemExit(main())
