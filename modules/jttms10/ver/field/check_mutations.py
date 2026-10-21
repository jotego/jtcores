#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check detection of physical write-mask, read and HOLD regressions."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from verilator_build import build_model


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    source = HERE.parents[1] / 'hdl/jttms10_field.v'
    original = source.read_bytes()
    bench = HERE / 'test.sv'
    bench_hash = hashlib.sha256(bench.read_bytes()).hexdigest()
    variants = (
        ('control', None, None, None),
        ('ignored_write_mask', "write_mask <= we ? wmask : 16'hffff;",
         "write_mask <= 16'hffff;", 'memory changed outside field'),
        ('masked_read', "write_mask <= we ? wmask : 16'hffff;",
         'write_mask <= wmask;', 'read addr='),
        ('unlatched_mask', 'assign word_mask = field_mask & write_mask;',
         "assign word_mask = field_mask & (we ? wmask : 16'hffff);",
         'memory changed outside field'),
        ('lost_masked_hold_restart',
         "wire restart_rmw = word_restart && state == WRITE && word_mask != 16'hffff;",
         "wire restart_rmw = word_restart && state == WRITE && field_mask != 16'hffff;",
         'masked stale write survived HOLD'),
    )
    evidence = {}
    with tempfile.TemporaryDirectory(prefix='jttms10-field-mutations-') as temp:
        work = Path(temp)
        for name, before, after, diagnostic in variants:
            text = original.decode()
            if before:
                if text.count(before) != 1:
                    raise RuntimeError(f'{name}: mutation site is not unique')
                text = text.replace(before, after)
            rtl = work / (name + '.v')
            rtl.write_text(text)
            executable = build_model(work/name, [bench, rtl])
            command = [str(executable)]
            result = subprocess.run(command, capture_output=True, text=True, timeout=10)
            log = result.stdout + result.stderr
            passed = (result.returncode == 0 and 'PASS: 5120 write/read vectors' in log
                      if diagnostic is None else result.returncode != 0 and diagnostic in log)
            evidence[name] = dict(command=command, returncode=result.returncode,
                                  output=log, expected_diagnostic=diagnostic, passed=passed,
                                  rtl_sha256=hashlib.sha256(rtl.read_bytes()).hexdigest(),
                                  bench_sha256=bench_hash)
            if args.report:
                args.report.parent.mkdir(parents=True, exist_ok=True)
                args.report.write_text(json.dumps(evidence, indent=2)+'\n')
            if not passed:
                raise RuntimeError(f'{name}: unexpected result\n{log}')
            print(f'{name}: PASS', flush=True)
    if source.read_bytes() != original or hashlib.sha256(bench.read_bytes()).hexdigest() != bench_hash:
        raise RuntimeError('source or bench changed during mutation validation')


if __name__ == '__main__':
    main()
