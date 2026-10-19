#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Stage, execute and check one autonomous batch on the DataStorm board."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
TASK = Path('/nobackup/tasks/jtcores-145')
KNOWN_HOSTS = TASK / 'memories/known_hosts'
DEFAULT_IP = '192.168.68.72'
DEFAULT_CC = Path('/opt/gcc-arm-10.2-2020.11-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-gcc')
REMOTE_TRANSPORT = '/tmp/jttms10-fpga-transport'
REMOTE_BATCH = '/tmp/jttms10-fpga-batch.bin'
PROTOCOL_VERSION = 2
DESCRIPTOR_WORDS = 12


def find_source_root(explicit=None):
    candidates = [explicit] if explicit else []
    if not explicit:
        candidates.extend([os.environ.get('JTROOT'), HERE.parents[3]])
    for candidate in candidates:
        if not candidate:
            continue
        root = Path(candidate).expanduser().resolve()
        if ((root / 'modules/jttms10/hdl').is_dir() and
                (root / 'modules/jttms10/ver/timing/run.py').is_file() and
                (root / 'modules/jttms10/ver/fpga/jttms10_fpga_runner.v').is_file()):
            return root
    raise SystemExit('cannot locate JTCORES source; pass --source-root or set JTROOT')


def sha256(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def ssh_options(ip):
    key = Path.home() / '.ssh/id_ed25519'
    return ['-o', 'BatchMode=yes', '-o', 'IdentitiesOnly=yes', '-o', 'ConnectTimeout=8',
            '-i', str(key), '-o', 'StrictHostKeyChecking=yes', '-o', f'UserKnownHostsFile={KNOWN_HOSTS}',
            f'root@{ip}']


def compile_transport(cc, out):
    if not cc.is_file():
        raise RuntimeError(f'ARM cross compiler not found: {cc}')
    out.parent.mkdir(parents=True, exist_ok=True)
    start = time.monotonic()
    subprocess.run([str(cc), '-static', '-Os', '-march=armv7-a', '-mfpu=vfpv3-d16',
                    '-mfloat-abi=hard', '-Wall', '-Wextra', '-Werror',
                    str(HERE / 'transport.c'), '-o', str(out)], check=True)
    return time.monotonic() - start


def input_payload(batches, timeout):
    if not 1 <= len(batches) <= 4096:
        raise ValueError('invalid number of FPGA batches')
    out = bytearray(struct.pack('<4sI', b'JTR3', len(batches)))
    for batch in batches:
        if batch.get('protocol_version') != PROTOCOL_VERSION:
            raise ValueError('batch is missing protocol_version 2')
        cases, words, desc = batch['cases'], batch['program_words'], batch['descriptors']
        batch_flags = batch.get('batch_flags', 0)
        if not 1 <= len(cases) <= 32 or len(desc) != len(cases) or not 1 <= len(words) <= 4096:
            raise ValueError('batch exceeds the FPGA protocol capacity')
        if batch_flags != 0:
            raise ValueError('unsupported batch flags')
        if any(type(word) is not int or not 0 <= word <= 0xffff for word in words):
            raise ValueError('program/init pool word is outside uint16 range')
        intervals = []
        for row in desc:
            if (not isinstance(row, (list, tuple)) or len(row) != DESCRIPTOR_WORDS or
                    any(type(word) is not int or not 0 <= word <= 0xffffffff for word in row)):
                raise ValueError('descriptor must contain exactly 12 uint32 words')
            if (len(row) != DESCRIPTOR_WORDS or row[2] == 0 or row[1] >= len(words) or
                    row[2] > len(words) - row[1] or row[2] > 3840 or
                    row[6] > len(words) or row[7] > 64 or row[7] > (len(words) - row[6]) // 3 or
                    row[3] & 15 or row[4] & 15 or
                    row[5] > 255 or row[8] > 0x1fffffff or row[9] > timeout or
                    row[10] > timeout or row[11] != 0):
                raise ValueError('invalid descriptor program range')
            intervals.append((row[1], row[1] + row[2]))
            if row[7]:
                intervals.append((row[6], row[6] + 3 * row[7]))
            initialized = []
            regions = set()
            for i in range(row[7]):
                p = row[6] + 3 * i
                address = words[p] | (words[p + 1] << 16)
                if address & 15 or address in initialized:
                    raise ValueError('sparse initializers must be unique, word-aligned addresses')
                initialized.append(address)
                regions.add(address >> 10)
            if len(regions) > 16:
                raise ValueError('sparse initializer set exceeds 16 tagged regions')
        intervals.sort()
        for left, right in zip(intervals, intervals[1:]):
            if left[1] > right[0]:
                raise ValueError('program/initializer pool ranges overlap')
        out += struct.pack('<IIII', len(cases), len(words), timeout, batch_flags)
        for row in desc:
            out += struct.pack(f'<{DESCRIPTOR_WORDS}I', *row)
        out += struct.pack(f'<{len(words)}H', *words)
    return bytes(out)


def main():
    overall_start = time.monotonic()
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('manifest', type=Path)
    ap.add_argument('--source-root', type=Path,
                    help='JTCORES checkout containing modules/jttms10 (defaults to JTROOT or inferred checkout)')
    ap.add_argument('--batch', type=int, help='run only this batch index')
    ap.add_argument('--ip', default=DEFAULT_IP)
    ap.add_argument('--transport-bin', type=Path)
    ap.add_argument('--cc', type=Path, default=DEFAULT_CC)
    ap.add_argument('--artifacts', type=Path, default=TASK / 'artifacts/fpga-runs')
    ap.add_argument('--receipt', type=Path, default=TASK / 'artifacts/fpga-runs/programming-receipt.json')
    ap.add_argument('--timeout-cycles', type=int, default=4_000_000)
    ap.add_argument('--run-name')
    ap.add_argument('--compile', action='store_true', help='compile static ARM transport before use')
    args = ap.parse_args()
    source_root = find_source_root(args.source_root)
    source_fpga = source_root / 'modules/jttms10/ver/fpga'
    if not KNOWN_HOSTS.is_file():
        raise SystemExit(f'pinned SSH host keys are missing: {KNOWN_HOSTS}')
    if not args.receipt.is_file():
        raise SystemExit(f'programming receipt is missing: {args.receipt}')
    receipt = json.loads(args.receipt.read_text())
    if receipt.get('format') != 'jttms10-fpga-programming-receipt-v1':
        raise SystemExit('unsupported or malformed FPGA programming receipt')
    if receipt.get('sysid') != 22 or not isinstance(receipt.get('sysid_timestamp'), int):
        raise SystemExit('receipt lacks the expected compiled SYSID identity')
    if not re.fullmatch(r'[0-9a-fA-F-]{36}', receipt.get('board_boot_id', '')):
        raise SystemExit('receipt lacks a valid board boot ID')
    overlay = receipt.get('overlay', '')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+', overlay):
        raise SystemExit('receipt has an invalid FPGA overlay name')
    current_runner_hash = sha256(source_fpga / 'jttms10_fpga_runner.v')
    if receipt.get('runner_source_sha256') != current_runner_hash:
        raise SystemExit('runner RTL differs from the image recorded in the programming receipt')
    manifest = json.loads(args.manifest.read_text())
    if (manifest.get('format') != 'jttms10-fpga-batch-v2' or
            manifest.get('protocol_version') != PROTOCOL_VERSION):
        raise SystemExit('unsupported manifest format')
    batches = manifest['batches']
    if any(batch.get('protocol_version') != PROTOCOL_VERSION for batch in batches):
        raise SystemExit('one or more manifest batches use an unsupported protocol version')
    if args.batch is not None:
        batches = [batches[args.batch]]
    if not batches:
        raise SystemExit('manifest has no batches')
    args.artifacts.mkdir(parents=True, exist_ok=True)
    run_name = args.run_name or time.strftime('run-%Y%m%dT%H%M%SZ', time.gmtime())
    outdir = args.artifacts / run_name
    outdir.mkdir(parents=True, exist_ok=False)
    binary = args.transport_bin or outdir / 'transport'
    timings = {'batch_count': len(batches)}
    if args.compile or not binary.is_file():
        timings['compile_seconds'] = compile_transport(args.cc, binary)
    payload = input_payload(batches, args.timeout_cycles)
    input_file = outdir / 'input.bin'
    input_file.write_bytes(payload)
    timings['input_sha256'] = sha256(input_file)
    timings['transport_sha256'] = sha256(binary)
    timings['manifest_sha256'] = sha256(args.manifest)
    timings['runner_rtl_sha256'] = current_runner_hash
    timings['source_root'] = str(source_root)
    timings['programming_receipt_sha256'] = sha256(args.receipt)
    timings['image_sha256'] = receipt['image_sha256']
    timings['expected_sysid'] = receipt['sysid']
    timings['expected_sysid_timestamp'] = receipt['sysid_timestamp']
    timings['expected_overlay'] = overlay
    timings['expected_board_boot_id'] = receipt['board_boot_id']
    timings['transport_source_sha256'] = sha256(HERE / 'transport.c')
    timings['checker_source_sha256'] = sha256(source_fpga / 'check_results.py')
    timings['oracle_source_sha256'] = sha256(source_root / 'modules/jttms10/ver/timing/run.py')
    timings['start_unix'] = time.time()
    remote = ssh_options(args.ip)
    preflight_command = (
        'set -e; '
        f'test "$(cat /proc/sys/kernel/random/boot_id)" = {receipt["board_boot_id"]}; '
        'test "$(cat /sys/class/fpga_manager/fpga0/state)" = operating; '
        'test "$(cat /sys/class/fpga_bridge/br0/state)" = enabled; '
        'test "$(cat /sys/class/fpga_bridge/br1/state)" = enabled; '
        'test "$(cat /proc/sys/kernel/tainted)" = 0; '
        f'test "$(cat /sys/kernel/config/device-tree/overlays/{overlay}/status)" = applied; '
        'printf "boot_id="; cat /proc/sys/kernel/random/boot_id; '
        'printf "manager="; cat /sys/class/fpga_manager/fpga0/state; '
        'printf "br0="; cat /sys/class/fpga_bridge/br0/state; '
        'printf "br1="; cat /sys/class/fpga_bridge/br1/state; '
        'printf "tainted="; cat /proc/sys/kernel/tainted; '
    )
    preflight_start = time.monotonic()
    preflight = subprocess.run(['ssh', *remote, preflight_command], text=True,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
    timings['preflight_seconds'] = time.monotonic() - preflight_start
    (outdir / 'preflight.txt').write_text(preflight.stdout + preflight.stderr)
    if preflight.returncode:
        timings['total_seconds'] = time.monotonic() - overall_start
        (outdir / 'timings.json').write_text(json.dumps(timings, indent=2) + '\n')
        raise RuntimeError(f'FPGA programming receipt preflight failed ({preflight.returncode}); runner MMIO was not accessed')
    transfer_start = time.monotonic()
    subprocess.run(['scp', '-O', *remote[:-1], str(binary), f'{remote[-1]}:{REMOTE_TRANSPORT}'], check=True)
    subprocess.run(['scp', '-O', *remote[:-1], str(input_file), f'{remote[-1]}:{REMOTE_BATCH}'], check=True)
    timings['transfer_seconds'] = time.monotonic() - transfer_start
    exec_start = time.monotonic()
    result = subprocess.run(['ssh', *remote,
                             f'chmod 755 {REMOTE_TRANSPORT} && {REMOTE_TRANSPORT} {REMOTE_BATCH} {receipt["sysid"]} {receipt["sysid_timestamp"]}'],
                            text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=240)
    timings['execution_seconds'] = time.monotonic() - exec_start
    if result.stderr:
        (outdir / 'remote_stderr.txt').write_text(result.stderr)
    (outdir / 'timings.json').write_text(json.dumps(timings, indent=2) + '\n')
    capture_path = outdir / 'capture.json'
    if result.stdout.strip():
        capture_path.write_text(result.stdout)
    if result.returncode and not result.stdout.strip():
        raise RuntimeError(f'FPGA transport failed ({result.returncode}): {result.stderr.strip()}')
    capture = json.loads(result.stdout)
    if capture.get('protocol_version') != PROTOCOL_VERSION:
        raise RuntimeError('transport returned an unsupported protocol version')
    captures = capture.get('batches')
    if not isinstance(captures, list) or len(captures) != len(batches):
        raise RuntimeError(f"transport returned {0 if not isinstance(captures, list) else len(captures)} of {len(batches)} batch captures")
    checker_path = source_fpga / 'check_results.py'
    spec = importlib.util.spec_from_file_location('jttms10_fpga_check_results', checker_path)
    checker = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = checker
    spec.loader.exec_module(checker)
    check_start = time.monotonic()
    reports = []
    for batch, captured in zip(batches, captures):
        try:
            reports.append(checker.check_batch(batch, captured))
        except ValueError as error:
            reports.append({'cases': [], 'passed': 0, 'failed': len(batch['cases']),
                            'protocol_errors': [str(error)]})
    timings['check_seconds'] = time.monotonic() - check_start
    timings['fpga_stage_seconds'] = sum(x.get('stage_ms', 0) for x in captures) / 1000
    timings['fpga_run_seconds'] = sum(x.get('run_ms', 0) for x in captures) / 1000
    timings['fpga_drain_seconds'] = sum(x.get('drain_ms', 0) for x in captures) / 1000
    timings['fpga_batch_phases'] = [
        {'stage_seconds': x.get('stage_ms', 0) / 1000,
         'run_seconds': x.get('run_ms', 0) / 1000,
         'drain_seconds': x.get('drain_ms', 0) / 1000}
        for x in captures]
    timings['total_seconds'] = time.monotonic() - overall_start
    (outdir / 'timings.json').write_text(json.dumps(timings, indent=2) + '\n')
    failures = sum(report['failed'] for report in reports)
    aggregate = {'batches': reports, 'passed': sum(x['passed'] for x in reports), 'failed': failures}
    (outdir / 'report.json').write_text(json.dumps(aggregate, indent=2) + '\n')
    (outdir / 'timings.json').write_text(json.dumps(timings, indent=2) + '\n')
    if result.returncode:
        print(result.stderr, file=sys.stderr, end='')
    for batch, report in zip(batches, reports):
        for row in report['cases']:
            print(f"{row['name']}: {'FAIL' if row['errors'] else 'PASS'} ({row['observed']['clocks']} clocks)")
            for error in row['errors']:
                print(f'  {error}')
        for error in report.get('protocol_errors', []):
            print(f"batch protocol failure: {error}", file=sys.stderr)
        if not report['cases'] and report.get('protocol_errors'):
            print('failed cases: ' + ', '.join(x['name'] for x in batch['cases']), file=sys.stderr)
    print(f"capture: {capture_path}")
    return int(bool(failures) or bool(result.returncode))


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.SubprocessError, json.JSONDecodeError, RuntimeError) as error:
        print(f'FPGA batch transport error: {error}', file=sys.stderr)
        raise SystemExit(2)
