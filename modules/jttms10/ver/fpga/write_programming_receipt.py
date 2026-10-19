#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Record the exact RTL/image identity after a successful board load."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def file_set(paths):
    return {str(path): sha256(path) for path in sorted(paths) if path.is_file()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image', required=True, type=Path)
    parser.add_argument('--build-dir', required=True, type=Path)
    parser.add_argument('--source-root', required=True, type=Path)
    parser.add_argument('--boot-id', required=True)
    parser.add_argument('--overlay', required=True)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if not re.fullmatch(r'[0-9a-fA-F-]{36}', args.boot_id):
        raise SystemExit('invalid board boot ID')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+', args.overlay):
        raise SystemExit('invalid overlay name')
    image = args.image.resolve(strict=True)
    build = args.build_dir.resolve(strict=True)
    source = args.source_root.resolve(strict=True)
    build_manifest_path = build / 'build-input-manifest.post.json'
    if not build_manifest_path.is_file():
        raise SystemExit('build lacks a post-compile input/image identity manifest')
    build_manifest = json.loads(build_manifest_path.read_text())
    compiled_image = build / 'output_files/test_board.rbf'
    if not compiled_image.is_file() or sha256(image) != sha256(compiled_image):
        raise SystemExit('programmed image does not match the RBF emitted by this Quartus build')
    if build_manifest.get('compile_flow_exit') != 0 or \
       build_manifest.get('rbf_sha256') != sha256(compiled_image):
        raise SystemExit('build manifest does not certify a successful Quartus flow for this RBF')
    sysid_path = build / 'db/ip/QSYS_test_board/submodules/QSYS_test_board_sysid.v'
    text = sysid_path.read_text()
    match = re.search(r'assign\s+readdata\s*=\s*address\s*\?\s*(\d+)\s*:\s*(\d+)\s*;', text)
    if not match:
        raise SystemExit(f'could not parse compiled SYSID from {sysid_path}')
    timestamp, sysid = map(int, match.groups())
    if sysid != 22:
        raise SystemExit(f'compiled SYSID is {sysid}, expected 22')
    rtl_package = build / 'ip/jttms10_fpga_runner'
    generated = build / 'jttms10-generated'
    source_runner = source / 'modules/jttms10/ver/fpga/jttms10_fpga_runner.v'
    if sha256(source_runner) != sha256(rtl_package / source_runner.name):
        raise SystemExit('packaged runner RTL does not match the source used for this receipt')
    source_hdl = source / 'modules/jttms10/hdl'
    source_hdl_files = {path.name: sha256(path) for path in source_hdl.glob('*.v')}
    package_hdl_files = {path.name: sha256(path) for path in rtl_package.glob('*.v')
                         if path.name != source_runner.name}
    if source_hdl_files != package_hdl_files:
        raise SystemExit('packaged CPU RTL does not match the source HDL tree')
    generated_files = {path.name: sha256(path) for path in generated.iterdir() if path.is_file()}
    if not generated_files:
        raise SystemExit('build contains no generated CPU ROM/template inputs')
    live_generated = Path(tempfile.mkdtemp(prefix='jttms10-receipt-generated-'))
    try:
        subprocess.run(['bash', str(source / 'modules/jttms10/ver/build.sh'), str(live_generated)],
                       check=True, stdout=subprocess.DEVNULL)
        current_generated = {path.name: sha256(path) for path in live_generated.iterdir() if path.is_file()}
    except subprocess.CalledProcessError as error:
        raise SystemExit(f'could not regenerate CPU ROM/template inputs from source: {error}') from error
    finally:
        import shutil
        shutil.rmtree(live_generated, ignore_errors=True)
    if current_generated != generated_files:
        raise SystemExit('compiled CPU ROM/template inputs differ from the current source generators')
    for name, digest in generated_files.items():
        if Path(name).suffix not in {'.uc', '.hex', '.vh'}:
            continue
        if sha256(rtl_package / name) != digest:
            raise SystemExit(f'packaged generated input differs from build output: {name}')
        if Path(name).suffix in {'.uc', '.hex'} and sha256(build / name) != digest:
            raise SystemExit(f'build-root ROM input differs from build output: {name}')
    qsf = build / 'test_board.qsf'
    qsf_lines = qsf.read_text().splitlines()
    for path in rtl_package.glob('*.v'):
        assignment = (f'set_global_assignment -library "QSYS_test_board" -name VERILOG_FILE '
                      f'{path.resolve()}')
        if assignment not in qsf_lines:
            raise SystemExit(f'compiled QSF does not bind packaged source: {path.name}')
    try:
        revision = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
        status = subprocess.check_output(['git', '-C', str(source), 'status', '--short'], text=True).splitlines()
    except subprocess.CalledProcessError as error:
        raise SystemExit(f'could not identify source checkout: {error}') from error
    receipt = {
        'format': 'jttms10-fpga-programming-receipt-v1',
        'source_revision': revision,
        'source_status': status,
        'runner_source_sha256': sha256(source_runner),
        'image_path': str(image),
        'image_sha256': sha256(image),
        'build_manifest_sha256': sha256(build_manifest_path),
        'quartus_flow_seconds': build_manifest['compile_flow_seconds'],
        'quartus_flow_exit': build_manifest['compile_flow_exit'],
        'sysid': sysid,
        'sysid_timestamp': timestamp,
        'sysid_source': str(sysid_path),
        'sysid_source_sha256': sha256(sysid_path),
        'qsf_sha256': sha256(qsf),
        'rtl_package_files': file_set(rtl_package.glob('*')),
        'generated_files': file_set(generated.glob('*')),
        'current_source_generated_files': current_generated,
        'board_boot_id': args.boot_id.lower(),
        'overlay': args.overlay,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
    print(args.output)


if __name__ == '__main__':
    main()
