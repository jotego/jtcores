#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Reject actual CPU entry regressions with the unchanged independent oracle."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

import check_results as checker
import check_external_reference as reference

HERE = Path(__file__).resolve().parent
HDL = HERE.parents[1]/'hdl'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(output, irq_unaligned=False):
    output.mkdir(parents=True, exist_ok=False)
    frozen = {p.name: sha(p) for p in HDL.glob('*.v')}
    entries = [entry for batch in reference.fixture_manifest()['batches'] for entry in batch['cases']]
    wanted = ('nop_hit__empty', 'nop_off__empty', 'irq_scalar_lint1_w0_cold', 'irq_scalar_lint1_w0_warm')
    entries = [next(entry for entry in entries if entry['name'] == name) for name in wanted]
    if irq_unaligned:
        extra = [entry for batch in reference.fixture_manifest(
            irq_unaligned=True, stack_offsets=[1])['batches'] for entry in batch['cases']]
        entries[2:] = [next(entry for entry in extra if entry['name'] == name+'_sp1')
                       for name in wanted[2:]]
        for identifier, entry in enumerate(entries):
            entry['id'] = identifier
    manifest = dict(format=checker.FORMAT_V5, protocol_version=5,
                    batches=checker.make_batches(entries, protocol_version=5))
    reference.run(manifest, output/'control')
    controls = json.loads((output/'control/reference.json').read_text())['cases']
    variants = (
        ('slow_halfword_entry', 'jttms10_ctrl.v',
         'TIMED_PROGRAM!=0 ? HWSAVE_TIMED_SEQA : HWSAVE_SEQA;', 'HWSAVE_SEQA;'),
        ('low_word_first', 'jttms10.v',
         '(TIMED_PROGRAM!=0 && hw_entry && stack_sel==WRITE_STACK)', "(1'b0 && hw_entry && stack_sel==WRITE_STACK)"),
        ('skip_resume_instruction', 'jttms10.v',
         "md<=line_hw_push ? pc-32'd16 : pc;", "md<=line_hw_push ? pc-32'd16 : pc+(hw_entry ? 32'd16 : 32'd0);"),
        ('slow_first_isr', 'jttms10.v',
         "wire [15:0] decode_clocks={10'd0,decode_states} * CLKS_PER_STATE[15:0];",
         "wire [15:0] decode_clocks={10'd0,decode_states} * CLKS_PER_STATE[15:0]+(decode_opcode==16'h09e0 ? 16'd8 : 16'd0);"),
        ('missing_context_observer', 'jttms10.v',
         'assign obs_hw_complete = step && ni && hw_entry;',
         "assign obs_hw_complete = step && ni && hw_entry && 1'b0;"),
    )
    if irq_unaligned:
        variants += (('lost_surrounding_bits', 'jttms10_field.v',
            '(old_word & ~word_mask)',
            "(old_word & ~word_mask & (base_addr==32'h3000 ? 16'd0 : 16'hffff))"),)
    records = []
    with tempfile.TemporaryDirectory(prefix='jttms10-entry-mutations-') as temp:
        for name, filename, before, after in variants:
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
            report_path = output/name/'report.json'
            if result.returncode != 1 or not report_path.is_file():
                raise RuntimeError(f'{name}: compiler failure or no identified failing execution (exit {result.returncode})')
            report = json.loads(report_path.read_text())
            rows = [row for batch in report['batches'] for row in batch['cases']]
            captures = [json.loads((output/name/f'capture-{q}.json').read_text())
                        for q in range(len(manifest['batches']))]
            if any(cap['status'] != 2 or any(r[1] != 2 for r in cap['results']) for cap in captures):
                raise ValueError(name+': expected ordinary observations, not a timeout/protocol abort')
            if len(rows) != 4 or any(row['errors'] for row in rows[:2]):
                raise ValueError(name+': independent NOP controls failed or cases were lost')
            for row, control in zip(rows, controls):
                for key in ('clocks', 'st', 'a0', 'a1', 'a2', 'a3'):
                    if row['observed'][key] != control['observed'][key]:
                        raise ValueError(name+': mutant corrupted the preceding measured NOP')
            if name != 'skip_resume_instruction':
                for row, control in zip(rows[2:], controls[2:]):
                    actual = dict(row['irq_observation']['follow'])
                    golden = dict(control['irq_observation']['follow'])
                    actual.pop('clock');golden.pop('clock')
                    if actual != golden or (name != 'lost_surrounding_bits' and
                            row['irq_observation']['memory'] != control['irq_observation']['memory']):
                        raise ValueError(name+': order/timing mutation changed final architecture')
                    if name == 'lost_surrounding_bits':
                        memory, initial = (dict(x['irq_observation']['memory']) for x in (row, control))
                        if ([a for a in memory if memory[a] != initial[a]] != [0x3000] or
                                memory[0x3000] != 0 or initial[0x3000] != 0xa5a4):
                            raise ValueError(name+': mutation did not isolate surrounding bits')
                diagnostic = dict(slow_halfword_entry=('unaligned' if irq_unaligned else 'aligned')+' context switch',
                    low_word_first='request/order/data mismatch', slow_first_isr='first ISR MOVI',
                    missing_context_observer='explicit IRQ boundaries',
                    lost_surrounding_bits='surrounding preserved bits')[name]
            else:
                diagnostic = 'A2:'
            if not any(diagnostic in error for row in rows[2:] for error in row['errors']):
                raise ValueError(name+': independent IRQ check missed the intended regression')
            if not report['reference_comparison_errors']:
                raise ValueError(name+': mutant falsely established reference equivalence')
            records.append(dict(name=name, command=command, exit_code=result.returncode,
                file=filename, before=before, after=after, mutant_sha256=sha(target),
                unchanged_nop_controls=2, required_diagnostic=diagnostic,
                failures=[dict(name=row['name'], errors=row['errors']) for row in rows if row['errors']]))
            print(name+': PASS (actual RTL regression rejected)', flush=True)
    if frozen != {p.name: sha(p) for p in HDL.glob('*.v')}:
        raise RuntimeError('canonical CPU changed during mutation validation')
    result = dict(control_cases=4, mutations_rejected=len(variants), cpu_sha256=frozen, records=records)
    (output/'verification.json').write_text(json.dumps(result, indent=2)+'\n')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--report', type=Path)
    parser.add_argument('--irq-unaligned', action='store_true',
                        help='use unaligned IRQ controls and also corrupt surrounding stack bits')
    args = parser.parse_args()
    if args.output:
        result = run(args.output.resolve(), args.irq_unaligned)
    else:
        with tempfile.TemporaryDirectory(prefix='jttms10-entry-mutation-check-') as temp:
            result = run(Path(temp)/'evidence', args.irq_unaligned)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2)+'\n')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
