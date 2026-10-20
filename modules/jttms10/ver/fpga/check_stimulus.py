#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Reject real stimulus RTL regressions with literal clock/pin expectations."""
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
    source = HERE / 'jttms10_fpga_stimulus.v'
    original = source.read_bytes()
    evidence = {}
    variants = (
        ('control', None, None, None),
        ('early_irq', 'relative_clock==argument :',
         "relative_clock+32'd1==argument :", 'event expected index0 clock2'),
        ('wrong_nmi_bit', "host_wdata<=control & 16'h8300;",
         "host_wdata<=(control & 16'h8300) ^ 16'h0100;", 'HSTCTL data wrong'),
    )
    with tempfile.TemporaryDirectory(prefix='jttms10-fpga-stimulus-') as temp:
        work = Path(temp)
        for name, before, after, diagnostic in variants:
            rtl = work / (name + '.v')
            text = original.decode()
            if before:
                if text.count(before) != 1:
                    raise RuntimeError(f'{name}: mutation site is not unique')
                text = text.replace(before, after)
            rtl.write_text(text)
            executable = build_model(work/name, [HERE/'stimulus/test.sv', rtl])
            command = [str(executable), '+MODE=0']
            result = subprocess.run(command, capture_output=True, text=True, timeout=10)
            log = result.stdout + result.stderr
            valid = (result.returncode == 0 and 'PASS stimulus mode0' in log) if diagnostic is None else (
                result.returncode != 0 and diagnostic in log)
            evidence[name] = dict(command=command, returncode=result.returncode,
                                  output=log, expected_diagnostic=diagnostic,
                                  passed=valid, rtl_sha256=hashlib.sha256(rtl.read_bytes()).hexdigest())
            if not valid:
                raise RuntimeError(f'{name}: unexpected result\n{log}')
            print(f'{name}: PASS', flush=True)
    if source.read_bytes() != original:
        raise RuntimeError('source changed during mutation validation')
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(evidence, indent=2)+'\n')


if __name__ == '__main__':
    main()
