#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Run specification timing checks through the complete jttms10 system.

Every mismatch fails (including when --report is requested). No baseline
allowlist, microcode cycle annotation, or functional result can waive timing.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
from oracle import INPUT_CLOCKS_PER_STATE, FIXED, fixed_states, multiply_states

HERE = Path(__file__).resolve().parent
MODULE = HERE.parents[1]
MASK32 = (1 << 32) - 1


def movi(value, register):
    return [0x09E0 | register, value & 0xFFFF, (value >> 16) & 0xFFFF]


def cases():
    for cache_disabled in (False, True):
        for signed in (True, False):
            for fs in range(2, 33, 2):
                for negative in (False, True):
                    for odd in (False, True):
                        name = (f"{'mpys' if signed else 'mpyu'}_fs{fs}"
                                f"_{'negative' if negative else 'positive'}"
                                f"_{'odd' if odd else 'even'}"
                                f"_{'off' if cache_disabled else 'hit'}")
                        source = 1 | ((1 << (fs - 1)) if negative else 0)
                        # Ignored high bits distinguish field sign from bit31.
                        if fs < 32:
                            source |= (~((1 << fs) - 1)) & MASK32
                        regs = [0x80000003, 0x80000003 if odd else 0x11223344,
                                source, 0xD0000810 | ((fs & 31) << 6)]
                        expected = list(regs)
                        multiplier = source & ((1 << fs) - 1)
                        multiplicand = regs[int(odd)]
                        if signed:
                            if multiplier & (1 << (fs - 1)):
                                multiplier -= 1 << fs
                            if multiplicand & (1 << 31):
                                multiplicand -= 1 << 32
                        product = (multiplier * multiplicand) & ((1 << 64) - 1)
                        width = 32 if odd else 64
                        stored = product & ((1 << width) - 1)
                        expected[int(odd)] = (product if odd else product >> 32) & MASK32
                        if not odd:
                            expected[1] = product & MASK32
                        expected_st = regs[3] & ~(1 << 29)
                        expected_st |= int(stored == 0) << 29
                        if signed:
                            expected_st = (expected_st & ~(1 << 31)) | ((stored >> (width - 1)) << 31)
                        states = multiply_states(signed=signed, fs1=fs, source=source,
                                                 cache_disabled=cache_disabled)
                        yield dict(name=name, opcode=(0x5C00 if signed else 0x5E00) | 0x40 | int(odd),
                                   regs=regs, expected_regs=expected, expected_st=expected_st,
                                   states=states, cache_disabled=cache_disabled,
                                   citation="SPVU001A " + ("12-165" if signed else "12-167"),
                                   conditions=dict(fs1=fs, signed=signed, source=source,
                                                   destination=int(odd)))
        for name, opcode in (("NOP", 0x0300), ("ADD", 0x4040), ("MOVK", 0x18A0)):
            regs = [0x80000003, 0x11223344, 2, 0xD0000810]
            expected = list(regs)
            expected_st = regs[3]
            if name == "ADD":
                expected[0] += 2
                expected_st = (regs[3] & 0x0FFFFFFF) | 0x80000000
            elif name == "MOVK":
                expected[0] = 5
            yield dict(name=f"{name.lower()}_{'off' if cache_disabled else 'hit'}",
                       opcode=opcode, regs=regs, expected_regs=expected,
                       expected_st=expected_st, states=fixed_states(name, cache_disabled=cache_disabled),
                       cache_disabled=cache_disabled, citation="SPVU001A " + FIXED[name][2],
                       conditions={})


def program(case):
    # Disable DRAM refresh and video; only the CPU uses the physical bus.
    words = movi(0xC00000B0, 14) + movi(0x8018 if case['cache_disabled'] else 0x18, 13)
    words += [0x0550, 0x81AE]  # SETF 16,0,0; MOVE A13,*A14,0
    loop = 0x1000 + 16 * len(words)
    for reg, value in enumerate(case['regs']):
        words += movi(value, reg)
    words += [0x01A3] + [0x0300] * 12  # PUTST A3, then drain previous writes
    test_pc = 0x1000 + 16 * len(words)
    words += [case['opcode']]
    next_pc = 0x1000 + 16 * len(words)
    words += [0x0300] * 12
    branch_pc = 0x1000 + 16 * len(words)
    displacement = (loop - (branch_pc + 16)) // 16
    assert -127 <= displacement < 0
    words += [0xC000 | (displacement & 255)]
    return words, test_pc, next_pc


def parse_result(stdout):
    results = [line for line in stdout.splitlines() if line.startswith('RESULT ')]
    if len(results) != 1:
        raise ValueError(f"expected exactly one RESULT, found {len(results)}")
    fields = dict(item.split('=') for item in results[0].split()[1:])
    return {key: int(value, 10 if key in ('clocks', 'start', 'end') else 16)
            for key, value in fields.items()}


def check(case, observed, wait_states=0):
    errors = []
    added_clocks = wait_states * INPUT_CLOCKS_PER_STATE if case['cache_disabled'] else 0
    expected_clocks = case['states'] * INPUT_CLOCKS_PER_STATE + added_clocks
    if observed['clocks'] != expected_clocks:
        errors.append(f"expected {expected_clocks} INCLK ({case['states']} intrinsic machine states, "
                      f"{added_clocks} external wait clocks), "
                      f"observed {observed['clocks']} INCLK")
    for reg, value in enumerate(case['expected_regs']):
        if observed[f'a{reg}'] != value:
            errors.append(f"A{reg}: expected {value:08x}, observed {observed[f'a{reg}']:08x}")
    if observed['st'] != case['expected_st']:
        errors.append(f"ST: expected {case['expected_st']:08x}, observed {observed['st']:08x}")
    return errors


def check_bus(case, observed, lines, wait_states):
    """These register-only probes have no data cycles or hidden writes.

    A warm hit issues no external cycles; CD issues exactly the following
    opcode read. The second pass must not be accidentally measured cold.
    """
    errors = []
    begin = [line.split() for line in lines if line.startswith('BUS_BEGIN ')]
    end = [line.split() for line in lines if line.startswith('BUS_END ')]
    count = int(case['cache_disabled'])
    if len(begin) != count or len(end) != count:
        errors.append(f"expected {count} physical opcode reads, observed {len(begin)} starts/{len(end)} ACKs")
    elif count:
        b, e = begin[0], end[0]
        if (int(b[2]), int(b[3], 16), int(b[5])) != (0, case['next_pc'], 1):
            errors.append(f"unexpected physical cycle: {' '.join(b)}")
        if e[2:4] != b[2:4] or int(e[4], 16) != 0x0300:
            errors.append(f"unexpected target response: {' '.join(e)}")
        clocks = int(e[1]) - int(b[1])
        if clocks != 16 + 8 * wait_states:
            errors.append(f"physical read: expected {16+8*wait_states} INCLK, observed {clocks}")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', help='exact case name, or substring')
    parser.add_argument('--report', type=Path, help='write all observations and verdicts as JSON')
    parser.add_argument('--traces', type=Path, help='retain full logs in this directory')
    parser.add_argument('--wait-states', type=int, default=0,
                        help='add this many TI machine states to every physical cycle')
    args = parser.parse_args()
    if args.wait_states < 0:
        parser.error('wait states must be nonnegative')
    selected = [case for case in cases() if args.case is None or args.case in case['name']]
    if not selected:
        parser.error('no matching cases')
    if args.traces:
        args.traces.mkdir(parents=True, exist_ok=True)
    rows = []
    sources = sorted((MODULE / 'hdl').glob('*.v')) + sorted((MODULE / 'ucode').glob('*.yaml'))
    sources += [HERE / name for name in ('test.sv', 'oracle.py', 'run.py')]
    provenance = dict(source_sha256={str(path.relative_to(MODULE)): hashlib.sha256(path.read_bytes()).hexdigest()
                                     for path in sources})
    with tempfile.TemporaryDirectory(prefix='jttms10-timing-') as temp:
        work = Path(temp)
        subprocess.run(['bash', str(MODULE / 'ver/build.sh'), str(work)], check=True,
                       stdout=subprocess.DEVNULL)
        hdl = MODULE / 'hdl'
        binary = work / 'timing.vvp'
        subprocess.run(['iverilog', '-g2012', '-s', 'test', '-I', str(work),
                        '-o', str(binary), str(HERE / 'test.sv'),
                        *map(str, sorted(hdl.glob('*.v')))], check=True, cwd=work)
        provenance['generated_sha256'] = {
            path.name: hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(work.iterdir()) if path.suffix in ('.vh', '.uc', '.hex')}
        for case in selected:
            words, test_pc, next_pc = program(case)
            case = dict(case, test_pc=test_pc, next_pc=next_pc)
            image = [0] * 4096
            image[0x100:0x100 + len(words)] = words
            (work / 'program.mem').write_text(''.join(f'{word:04x}\n' for word in image))
            result = subprocess.run(['vvp', str(binary), '+PROGRAM=program.mem',
                                     f'+TEST_PC={test_pc:x}', f'+NEXT_PC={next_pc:x}',
                                     f'+WAIT={8 * args.wait_states}'],
                                    cwd=work, capture_output=True, text=True, timeout=30)
            log = result.stdout + result.stderr
            if args.traces:
                (args.traces / (case['name'] + '.log')).write_text(log)
            try:
                if result.returncode:
                    raise ValueError(f'simulator exit {result.returncode}')
                observed = parse_result(result.stdout)
                errors = check(case, observed, args.wait_states)
            except ValueError as error:
                observed, errors = None, [str(error)]
            row = dict(case, observed=observed, errors=errors)
            # Keep measured bus traffic with the verdict, including expected
            # zero-traffic warm hits. Full launch trace is available separately.
            row['bus_trace'] = [line for line in log.splitlines() if line.startswith('BUS_') and
                                (observed is None or observed['start'] <= int(line.split()[1]) <= observed['end'])]
            if observed is not None:
                errors.extend(check_bus(case, observed, row['bus_trace'], args.wait_states))
            rows.append(row)
            print(f"{case['name']}: {'FAIL' if errors else 'PASS'} ({case['citation']})")
            if errors:
                print('  ' + '; '.join(errors))
                print(f"  opcode={case['opcode']:04x} conditions={case['conditions']}")
                for line in row['bus_trace'][-12:]:
                    print('  ' + line)
                if observed is None:
                    print('\n'.join(log.splitlines()[-12:]))
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(dict(clock_unit='INCLK', clocks_per_machine_state=8,
                                              external_wait_states=args.wait_states,
                                              provenance=provenance,
                                              cases=rows), indent=2) + '\n')
    failures = sum(bool(row['errors']) for row in rows)
    print(f'Timing: {len(rows)-failures} passed, {failures} failed, {len(rows)} total')
    return int(failures != 0)


if __name__ == '__main__':
    sys.exit(main())
