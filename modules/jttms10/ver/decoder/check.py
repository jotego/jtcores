#!/usr/bin/env python3
"""Exhaustively compare opcode recognition against the pinned read-only core."""
import subprocess
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
MODULE = HERE.parents[1]
REFERENCE = MODULE.parent / 'tms34010'
PINNED = '29bcb384ec3dba892ea54db2ee92b38ae395d575'


def main():
    revision = subprocess.check_output(
        ['git', '-C', str(REFERENCE), 'rev-parse', 'HEAD'], text=True).strip()
    dirty = subprocess.check_output(
        ['git', '-C', str(REFERENCE), 'status', '--porcelain'], text=True).strip()
    if revision != PINNED or dirty:
        raise SystemExit('decode audit requires the clean pinned reference ' + PINNED)
    with tempfile.TemporaryDirectory(prefix='jttms10-decode-') as temp:
        work = Path(temp)
        subprocess.run(['bash', str(MODULE / 'ver/build.sh'), str(work)], check=True)
        subprocess.run([
            'verilator', '--binary', '--timing', '--quiet-build', '-Wno-fatal',
            '-Wno-PINMISSING', '-Wno-TIMESCALEMOD', '--top-module', 'test',
            '-I' + str(work), '--Mdir', str(work / 'obj'),
            str(REFERENCE / 'rtl/tms34010_pkg.sv'),
            str(REFERENCE / 'rtl/core/tms34010_decode.sv'),
            str(MODULE / 'hdl/jttms10_ctrl.v'), str(HERE / 'test.sv'),
        ], check=True, cwd=work)
        subprocess.run([str(work / 'obj/Vtest')], check=True, cwd=work)


if __name__ == '__main__':
    main()
