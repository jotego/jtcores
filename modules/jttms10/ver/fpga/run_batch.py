#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Stage, execute and check one autonomous batch on the DataStorm board."""
import argparse
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time
from stimulus_schema import validate_event as validate_external_event
from write_programming_receipt import (cpu_source_fingerprints, runner_source_fingerprints,
                                       cpu_source_fingerprint_digest,
                                       generate_cpu_artifacts, parse_mif)

HERE = Path(__file__).resolve().parent
TASK = Path('/nobackup/tasks/jtcores-145')
KNOWN_HOSTS = TASK / 'memories/known_hosts'
DEFAULT_IP = '192.168.68.72'
DEFAULT_CC = Path('/opt/gcc-arm-10.2-2020.11-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-gcc')
REMOTE_TRANSPORT = '/tmp/jttms10-fpga-transport'
REMOTE_BATCH = '/tmp/jttms10-fpga-batch.bin'
PROTOCOL_VERSION = 4
DESCRIPTOR_WORDS = 16


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


def load_and_validate_receipt(receipt_path, source_root, hardware_source_root,
                              parent_receipt_path=None):
    receipt_path = Path(receipt_path).resolve(strict=True)
    receipt = json.loads(receipt_path.read_text())
    source_root = Path(source_root).resolve(strict=True)
    hardware_source_root = Path(hardware_source_root).resolve(strict=True)
    if receipt.get('protocol_version') != 4:
        raise SystemExit('V4 transport requires a protocol 4 programming receipt')
    for root in {source_root, hardware_source_root}:
        if runner_source_fingerprints(root) != receipt.get('runner_source_fingerprints'):
            raise SystemExit('runner component checkout differs from the fitted image')
    oracle_sources = cpu_source_fingerprints(source_root)
    hardware_sources = cpu_source_fingerprints(hardware_source_root)
    for root in {source_root, hardware_source_root}:
        if sha256(root / 'modules/jttms10/ver/fpga/jttms10_fpga_runner.v') != receipt.get('runner_source_sha256'):
            raise SystemExit('runner RTL checkout differs from the image recorded in the receipt')
    if receipt.get('format') == 'jttms10-fpga-programming-receipt-v1':
        expected = receipt.get('cpu_source_fingerprints')
        if not isinstance(expected, dict):
            raise SystemExit('programming receipt lacks CPU source fingerprints; refresh it from the compiled image')
        if receipt.get('cpu_source_fingerprint_sha256') != cpu_source_fingerprint_digest(expected):
            raise SystemExit('programming receipt CPU source fingerprint digest is invalid')
        if expected != oracle_sources:
            raise SystemExit('oracle/source checkout differs from the source-bound programming receipt')
        if hardware_sources != expected:
            raise SystemExit('CPU implementation checkout differs from the source-bound programming receipt')
        image_path = Path(receipt.get('image_path', '')).resolve(strict=True)
        if sha256(image_path) != receipt.get('image_sha256'):
            raise SystemExit('baseline image file differs from its programming receipt')
        if parent_receipt_path is not None:
            raise SystemExit('--parent-receipt is valid only for an explicit ROM-update variant receipt')
    elif receipt.get('format') == 'jttms10-fpga-rom-update-receipt-v1':
        if parent_receipt_path is None:
            raise SystemExit('ROM-update receipt requires --parent-receipt for baseline chain validation')
        parent_path = Path(parent_receipt_path).resolve(strict=True)
        parent = json.loads(parent_path.read_text())
        if parent.get('format') != 'jttms10-fpga-programming-receipt-v1':
            raise SystemExit('ROM-update parent is not a full-fit programming receipt')
        if receipt.get('parent_receipt_sha256') != sha256(parent_path):
            raise SystemExit('ROM-update receipt does not match the supplied parent receipt')
        if receipt.get('parent_receipt_path') != str(parent_path):
            raise SystemExit('ROM-update receipt names a different parent receipt path')
        evidence_paths = {
            'parent_build_inputs_path': 'parent_build_manifest_sha256',
            'parent_build_result_path': 'parent_build_result_sha256',
            'parent_sta_summary_path': 'parent_sta_summary_sha256',
            'parent_compile_log_path': 'parent_compile_log_sha256',
        }
        evidence = {}
        for path_key, digest_key in evidence_paths.items():
            path_value, digest_value = receipt.get(path_key), receipt.get(digest_key)
            if not path_value or not re.fullmatch(r'[0-9a-f]{64}', str(digest_value or '')):
                raise SystemExit(f'ROM-update receipt lacks parent evidence: {path_key}')
            evidence[path_key] = Path(path_value).resolve(strict=True)
            if sha256(evidence[path_key]) != digest_value:
                raise SystemExit(f'ROM-update parent evidence changed: {path_key}')
        parent_result = json.loads(evidence['parent_build_result_path'].read_text())
        if (parent_result.get('format') != 'jttms10-incremental-build-result-v1' or
                parent_result.get('flow_exit_code') != 0 or
                parent_result.get('full_flow_only') is not True or
                parent_result.get('input_manifest_sha256') != receipt.get('parent_build_manifest_sha256') or
                parent_result.get('flow_log_sha256') != receipt.get('parent_compile_log_sha256') or
                parent_result.get('rbf_sha256') != receipt.get('parent_image_sha256') or
                not parent_result.get('terminal_marker') or
                parent_result.get('inputs_unchanged') is not True):
            raise SystemExit('ROM-update parent evidence does not certify a successful full fit')
        parent_build_dir = Path(receipt.get('parent_build_dir', '')).resolve(strict=True)
        if (evidence['parent_build_inputs_path'] != parent_build_dir / 'v2-build-inputs.json' or
                evidence['parent_build_result_path'] != parent_build_dir / 'v2-build-result.json' or
                evidence['parent_sta_summary_path'] != parent_build_dir / 'output_files/test_board.sta.summary' or
                evidence['parent_compile_log_path'] != parent_build_dir / 'logs/v2-compile.log'):
            raise SystemExit('ROM-update parent evidence paths are not bound to the declared build directory')
        parent_image = Path(parent.get('image_path', '')).resolve(strict=True)
        if sha256(parent_image) != parent.get('image_sha256'):
            raise SystemExit('full-fit parent image file differs from its receipt')
        parent_sources = parent.get('cpu_source_fingerprints')
        variant_sources = receipt.get('cpu_source_fingerprints')
        if not isinstance(parent_sources, dict) or not isinstance(variant_sources, dict):
            raise SystemExit('ROM-update chain lacks complete baseline/variant source fingerprints')
        if parent.get('cpu_source_fingerprint_sha256') != cpu_source_fingerprint_digest(parent_sources):
            raise SystemExit('parent receipt CPU source fingerprint digest is invalid')
        if receipt.get('cpu_source_fingerprint_sha256') != cpu_source_fingerprint_digest(variant_sources):
            raise SystemExit('ROM-update CPU source fingerprint digest is invalid')
        if oracle_sources != parent_sources:
            raise SystemExit('oracle checkout differs from the full-fit parent receipt source')
        if hardware_sources != variant_sources:
            raise SystemExit('ROM-update CPU checkout differs from its variant certificate')
        delta = receipt.get('source_delta', {})
        changed = sorted(name for name in set(parent_sources) | set(variant_sources)
                         if parent_sources.get(name) != variant_sources.get(name))
        if (changed != ['modules/jttms10/ucode/tms10.yaml'] or
                delta.get('path') != changed[0] or
                delta.get('baseline_sha256') != parent_sources[changed[0]] or
                delta.get('variant_sha256') != variant_sources[changed[0]]):
            raise SystemExit('ROM-update source delta is missing, ambiguous or differs beyond the microcode YAML')
        for key in ('image_sha256', 'runner_source_sha256', 'runner_source_fingerprints', 'protocol_version', 'sysid', 'sysid_timestamp'):
            parent_key = 'image_sha256' if key == 'image_sha256' else key
            if receipt.get('parent_image_sha256' if key == 'image_sha256' else key) != parent.get(parent_key):
                raise SystemExit(f'ROM-update receipt parent {key} identity mismatch')
        if receipt.get('runner_source_sha256') != sha256(
                source_root / 'modules/jttms10/ver/fpga/jttms10_fpga_runner.v'):
            raise SystemExit('ROM-update runner RTL differs from the inherited fitted image')
        if receipt.get('inherited_fit_only') is not True or receipt.get('full_compile_claim') is not False:
            raise SystemExit('ROM-update receipt does not explicitly declare inherited-fit provenance')
        if receipt.get('fit_unchanged_file_count', 0) <= 0 or not re.fullmatch(
                r'[0-9a-f]{64}', receipt.get('fit_unchanged_files_sha256', '')):
            raise SystemExit('ROM-update receipt lacks an unchanged-fit file proof')
        changed_words = receipt.get('changed_mif_words')
        if (not isinstance(changed_words, list) or not changed_words or
                any(type(index) is not int or not 0 <= index < 4096 for index in changed_words) or
                changed_words != sorted(set(changed_words))):
            raise SystemExit('ROM-update receipt has an invalid MIF change footprint')
        generated = receipt.get('source_generated_files', {})
        if not isinstance(generated, dict) or 'tms10.uc' not in generated:
            raise SystemExit('ROM-update certificate lacks generated ROM/template hashes')
        generated_now, temp_generated = generate_cpu_artifacts(hardware_source_root)
        try:
            if generated_now != generated:
                raise SystemExit('current hardware source does not regenerate the certified ROM/template set')
            baseline_generated, baseline_temp = generate_cpu_artifacts(source_root)
            try:
                base_uc = (baseline_temp / 'tms10.uc').read_text().splitlines()
                variant_uc = (temp_generated / 'tms10.uc').read_text().splitlines()
                mif_path = Path(receipt.get('variant_mif_path', '')).resolve(strict=True)
                width, mif_words = parse_mif(mif_path)
                if width != 62 or mif_words != variant_uc:
                    raise SystemExit('variant MIF does not exactly encode the current generated main-control ROM')
                actual_changed = [i for i, (base, variant) in enumerate(zip(base_uc, variant_uc))
                                  if base != variant]
                if len(base_uc) != 4096 or actual_changed != changed_words:
                    raise SystemExit('certified MIF changed-word list differs from source-generated ROM delta')
                if sha256(mif_path) != receipt.get('changed_mif_sha256'):
                    raise SystemExit('variant MIF file differs from its certificate hash')
            finally:
                shutil.rmtree(baseline_temp, ignore_errors=True)
        finally:
            shutil.rmtree(temp_generated, ignore_errors=True)
        image_path = Path(receipt.get('image_path', '')).resolve(strict=True)
        if sha256(image_path) != receipt.get('image_sha256'):
            raise SystemExit('ROM-update image file differs from its certificate hash')
        if receipt.get('firmware_name') != f"jtcores-rom-{receipt.get('variant_name')}-{receipt.get('image_sha256','')[:12]}.rbf":
            raise SystemExit('ROM-update firmware path is not uniquely bound to the image hash')
        for phase_name in ('cdb', 'assembler'):
            phase = receipt.get(phase_name)
            if (not isinstance(phase, dict) or phase.get('exit_code') != 0 or
                    not isinstance(phase.get('seconds'), (int, float)) or phase['seconds'] < 0):
                raise SystemExit(f'ROM-update receipt lacks a successful {phase_name} phase record')
            log_path = Path(phase.get('log_path', '')).resolve(strict=True)
            timing_path = Path(phase.get('timing_path', '')).resolve(strict=True)
            if (sha256(log_path) != phase.get('log_sha256') or
                    sha256(timing_path) != phase.get('timing_sha256')):
                raise SystemExit(f'ROM-update {phase_name} log/timing evidence changed')
        if not re.fullmatch(r'[A-Za-z0-9_.-]+', receipt.get('variant_name', '')):
            raise SystemExit('ROM-update receipt has an invalid variant name')
        if not re.fullmatch(r'[A-Za-z0-9_.-]+', receipt.get('overlay', '')):
            raise SystemExit('ROM-update receipt has an invalid overlay name')
    else:
        raise SystemExit('unsupported or malformed FPGA programming receipt')
    if receipt.get('sysid') != 22 or not isinstance(receipt.get('sysid_timestamp'), int):
        raise SystemExit('receipt lacks the expected compiled SYSID identity')
    if not re.fullmatch(r'[0-9a-fA-F-]{36}', receipt.get('board_boot_id', '')):
        raise SystemExit('receipt lacks a valid board boot ID')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+', receipt.get('overlay', '')):
        raise SystemExit('receipt has an invalid FPGA overlay name')
    if not re.fullmatch(r'[0-9a-f]{64}', receipt.get('image_sha256', '')):
        raise SystemExit('receipt lacks the expected image SHA256')
    return receipt, oracle_sources, hardware_sources


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
    if type(timeout) is not int or not 1 <= timeout <= 0xffffffff:
        raise ValueError('timeout cycles must be an integer in 1..4294967295')
    if not 1 <= len(batches) <= 8192:
        raise ValueError('invalid number of FPGA batches')
    out = bytearray(struct.pack('<4sI', b'JTR5', len(batches)))
    for batch in batches:
        if batch.get('protocol_version') != PROTOCOL_VERSION:
            raise ValueError('batch is missing protocol_version 4')
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
                raise ValueError('descriptor must contain exactly 16 uint32 words')
            if (len(row) != DESCRIPTOR_WORDS or row[2] == 0 or row[1] >= len(words) or
                    row[2] > len(words) - row[1] or row[2] > 3840 or
                    row[6] > len(words) or row[7] > 64 or row[7] > (len(words) - row[6]) // 3 or
                    row[3] & 15 or row[4] & 15 or
                    row[5] > 255 or row[8] > 0x1fffffff or row[9] > timeout or
                    row[10] > timeout or row[11] != 0 or row[14] > 16 or
                    row[15] > len(words) or row[14] > (len(words) - row[15]) // 4 or
                    (row[14] == 0 and row[15] != 0)):
                raise ValueError('invalid descriptor program range')
            drain = row[12] if row[12] < 0x80000000 else row[12] - 0x100000000
            if drain < -2 or row[13] & 15:
                raise ValueError('invalid signed drain mode or follow PC')
            intervals.append((row[1], row[1] + row[2]))
            if row[7]:
                intervals.append((row[6], row[6] + 3 * row[7]))
            if row[14]:
                intervals.append((row[15], row[15] + 4 * row[14]))
            for index in range(row[14]):
                offset = row[15] + 4 * index
                validate_external_event(dict(trigger=words[offset + 3],
                    argument=words[offset] | (words[offset + 1] << 16), control=words[offset + 2]))
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
    ap.add_argument('--hardware-source-root', type=Path,
                    help='CPU implementation checkout; defaults to --source-root')
    ap.add_argument('--batch', type=int, help='run only this batch index')
    ap.add_argument('--ip', default=DEFAULT_IP)
    ap.add_argument('--transport-bin', type=Path)
    ap.add_argument('--cc', type=Path, default=DEFAULT_CC)
    ap.add_argument('--artifacts', type=Path, default=TASK / 'artifacts/fpga-runs')
    ap.add_argument('--receipt', type=Path, default=TASK / 'artifacts/fpga-runs/programming-receipt.json')
    ap.add_argument('--parent-receipt', type=Path,
                    help='required full-fit parent receipt when --receipt is a ROM-update variant')
    ap.add_argument('--timeout-cycles', type=int, default=4_000_000)
    ap.add_argument('--transport-timeout', type=float, default=1200.0,
                    help='maximum wall-clock seconds for the remote FPGA batch stream (default: 1200)')
    ap.add_argument('--run-name')
    ap.add_argument('--compile', action='store_true', help='compile static ARM transport before use')
    args = ap.parse_args()
    if not math.isfinite(args.transport_timeout) or args.transport_timeout <= 0:
        ap.error('--transport-timeout must be a finite positive number of seconds')
    source_root = find_source_root(args.source_root)
    hardware_source_root = find_source_root(args.hardware_source_root or source_root)
    source_fpga = source_root / 'modules/jttms10/ver/fpga'
    if sha256(HERE / 'stimulus_schema.py') != sha256(source_fpga / 'stimulus_schema.py'):
        raise SystemExit('driver and selected checker external event schemas differ')
    if not KNOWN_HOSTS.is_file():
        raise SystemExit(f'pinned SSH host keys are missing: {KNOWN_HOSTS}')
    if not args.receipt.is_file():
        raise SystemExit(f'programming receipt is missing: {args.receipt}')
    receipt, oracle_sources, hardware_sources = load_and_validate_receipt(
        args.receipt, source_root, hardware_source_root, args.parent_receipt)
    overlay = receipt['overlay']
    current_runner_hash = sha256(source_fpga / 'jttms10_fpga_runner.v')
    if receipt.get('runner_source_sha256') != current_runner_hash:
        raise SystemExit('runner RTL differs from the image recorded in the programming receipt')
    manifest = json.loads(args.manifest.read_text())
    if (manifest.get('format') != 'jttms10-fpga-batch-v4' or
            manifest.get('protocol_version') != PROTOCOL_VERSION):
        raise SystemExit('unsupported manifest format; the V4 runner requires protocol version 4')
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
    timings['runner_component_sha256'] = runner_source_fingerprints(source_root)
    timings['source_root'] = str(source_root)
    timings['hardware_source_root'] = str(hardware_source_root)
    timings['oracle_cpu_source_fingerprint_sha256'] = cpu_source_fingerprint_digest(oracle_sources)
    timings['hardware_cpu_source_fingerprint_sha256'] = cpu_source_fingerprint_digest(hardware_sources)
    timings['programming_receipt_sha256'] = sha256(args.receipt)
    timings['image_sha256'] = receipt['image_sha256']
    timings['expected_sysid'] = receipt['sysid']
    timings['expected_sysid_timestamp'] = receipt['sysid_timestamp']
    timings['expected_overlay'] = overlay
    timings['expected_board_boot_id'] = receipt['board_boot_id']
    timings['transport_source_sha256'] = sha256(HERE / 'transport.c')
    timings['checker_source_sha256'] = sha256(source_fpga / 'check_results.py')
    timings['driver_source_sha256'] = sha256(HERE / 'run_batch.py')
    timings['driver_schema_source_sha256'] = sha256(HERE / 'stimulus_schema.py')
    timings['checker_schema_source_sha256'] = sha256(source_fpga / 'stimulus_schema.py')
    timings['event_contract_source_sha256'] = sha256(source_fpga / 'event_contract.py')
    timings['irq_contract_source_sha256'] = sha256(source_fpga / 'irq_contract.py')
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
    partial_capture_path = outdir / 'capture.stdout.partial'
    capture_path = outdir / 'capture.json'
    stderr_path = outdir / 'remote_stderr.txt'
    timed_out = False
    command = ['ssh', *remote,
               f'chmod 755 {REMOTE_TRANSPORT} && {REMOTE_TRANSPORT} {REMOTE_BATCH} {receipt["sysid"]} {receipt["sysid_timestamp"]}']
    with partial_capture_path.open('wb') as stdout_file, stderr_path.open('wb') as stderr_file:
        process = subprocess.Popen(command, stdout=stdout_file, stderr=stderr_file)
        try:
            process.wait(timeout=args.transport_timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            process.kill()
            process.wait()
    timings['execution_seconds'] = time.monotonic() - exec_start
    timings['transport_timeout_seconds'] = args.transport_timeout
    timings['transport_timed_out'] = timed_out
    timings['transport_exit_code'] = process.returncode
    result_stderr = stderr_path.read_text(errors='replace')
    if not result_stderr:
        stderr_path.unlink()
    if timed_out:
        timings['partial_capture_path'] = str(partial_capture_path)
        timings['total_seconds'] = time.monotonic() - overall_start
        (outdir / 'timings.json').write_text(json.dumps(timings, indent=2) + '\n')
        raise RuntimeError(f'FPGA transport exceeded {args.transport_timeout:g}s; partial stdout and timings were retained in {outdir}')
    partial_capture_path.replace(capture_path)
    result_stdout = capture_path.read_text()
    (outdir / 'timings.json').write_text(json.dumps(timings, indent=2) + '\n')
    if process.returncode and not result_stdout.strip():
        raise RuntimeError(f'FPGA transport failed ({process.returncode}): {result_stderr.strip()}')
    capture = json.loads(result_stdout)
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
    # Large full-matrix reports repeat extensive per-case observations. Keep
    # the JSON data unchanged while avoiding whitespace-only NAS I/O.
    (outdir / 'report.json').write_text(json.dumps(aggregate, separators=(',', ':')) + '\n')
    (outdir / 'timings.json').write_text(json.dumps(timings, indent=2) + '\n')
    if process.returncode:
        print(result_stderr, file=sys.stderr, end='')
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
    return int(bool(failures) or bool(process.returncode))


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.SubprocessError, json.JSONDecodeError, RuntimeError) as error:
        print(f'FPGA batch transport error: {error}', file=sys.stderr)
        raise SystemExit(2)
