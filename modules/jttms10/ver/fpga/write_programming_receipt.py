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
    inputs_path = build / 'v2-build-inputs.json'
    result_path = build / 'v2-build-result.json'
    if inputs_path.exists():
        if not result_path.is_file():
            raise SystemExit('incremental build lacks its successful-flow certificate')
        inputs_manifest = json.loads(inputs_path.read_text())
        build_result = json.loads(result_path.read_text())
        compile_inputs_path = build / 'v2-compile-inputs.json'
        map_result_path = build / 'v2-map-result.json'
        if not compile_inputs_path.is_file():
            raise SystemExit('incremental build lacks its compile-input certificate')
        compile_inputs = json.loads(compile_inputs_path.read_text())
        compile_log = build / 'logs/v2-compile.log'
        if compile_inputs.get('map_manifest_sha256') != sha256(inputs_path):
            raise SystemExit('compile-time input snapshot does not name the frozen map manifest')
        if build_result.get('full_flow_only') is not True:
            if not map_result_path.is_file():
                raise SystemExit('incremental build lacks its successful map certificate')
            map_result = json.loads(map_result_path.read_text())
            map_log = build / 'logs/v2-map.log'
            if map_result.get('input_manifest_sha256') != sha256(inputs_path) or \
               map_result.get('flow_exit_code') != 0 or not map_result.get('terminal_marker') or \
               not map_log.is_file() or map_result.get('flow_log_sha256') != sha256(map_log):
                raise SystemExit('incremental map certificate does not certify frozen inputs')
        if build_result.get('compile_inputs_sha256') != sha256(compile_inputs_path):
            raise SystemExit('successful flow certificate does not match compile-time inputs')
        for path, expected in compile_inputs.get('files', {}).items():
            p = Path(path)
            if not p.is_file() or sha256(p) != expected:
                raise SystemExit(f'compile-time input changed since full compilation: {p}')
        certificate_path = inputs_path
        flow_seconds = build_result.get('flow_seconds')
        flow_exit = build_result.get('flow_exit_code')
    else:
        # Compatibility for the canonical full build helper. Never use this path
        # to certify an incremental build that has v2 inputs but a missing result.
        legacy_path = build / 'build-input-manifest.post.json'
        if not legacy_path.is_file():
            raise SystemExit('build lacks a post-compile input/image identity manifest')
        legacy = json.loads(legacy_path.read_text())
        compiled_image = build / 'output_files/test_board.rbf'
        if legacy.get('compile_flow_exit') != 0 or \
           legacy.get('rbf_sha256') != sha256(compiled_image):
            raise SystemExit('full-build manifest does not certify this successful flow/RBF')
        certificate_path = legacy_path
        flow_seconds = legacy.get('compile_flow_seconds')
        flow_exit = legacy.get('compile_flow_exit')
    compiled_image = build / 'output_files/test_board.rbf'
    if not compiled_image.is_file() or sha256(image) != sha256(compiled_image):
        raise SystemExit('programmed image does not match the RBF emitted by this Quartus build')
    if inputs_path.exists():
        if build_result.get('format') != 'jttms10-incremental-build-result-v1' or \
           build_result.get('input_manifest_sha256') != sha256(inputs_path) or \
           build_result.get('flow_exit_code') != 0 or \
           build_result.get('inputs_unchanged') is not True or \
           build_result.get('rbf_sha256') != sha256(compiled_image) or \
           not compile_log.is_file() or build_result.get('flow_log_sha256') != sha256(compile_log) or \
           not build_result.get('terminal_marker'):
            raise SystemExit('v2 build result does not certify successful flow for this RBF/input manifest')
        for path, expected in inputs_manifest.get('files', {}).items():
            p = Path(path)
            if p.name.endswith('.sopcinfo'):
                continue # Quartus may rewrite this generated metadata after map.
            if not p.is_file() or sha256(p) != expected:
                raise SystemExit(f'compiled build input changed after frozen map: {p}')
    # Identify the compiled SYSID from the project binding. Incremental builds
    # bind the preserved generated QIP directly; canonical full builds bind the
    # Qsys source and Quartus compiles its generated db/ip copy.
    qsf = build / 'test_board.qsf'
    qsf_text = qsf.read_text()
    qip_match = re.search(r'^set_global_assignment\s+-name\s+QIP_FILE\s+(.+?)\s*$',
                          qsf_text, re.MULTILINE)
    qsys_match = re.search(r'^set_global_assignment\s+-name\s+QSYS_FILE\s+(.+?)\s*$',
                           qsf_text, re.MULTILINE)
    if bool(qip_match) == bool(qsys_match):
        raise SystemExit('QSF must bind exactly one QIP_FILE or QSYS_FILE')
    if qip_match:
        qip_path = (build / qip_match.group(1).strip('"{}')).resolve()
        if not qip_path.is_file() or 'submodules/QSYS_test_board_sysid.v' not in qip_path.read_text():
            raise SystemExit('generated QIP does not bind the expected compiled SYSID source')
        sysid_path = qip_path.parent / 'submodules/QSYS_test_board_sysid.v'
        sysid_binding = 'QIP_FILE'
    else:
        qsys_path = (build / qsys_match.group(1).strip('"{}')).resolve()
        if not qsys_path.is_file():
            raise SystemExit('QSF-bound QSYS_FILE is missing')
        system_name = qsys_path.stem
        sysid_path = build / 'db/ip' / system_name / 'submodules' / f'{system_name}_sysid.v'
        qip_path = build / 'db/ip' / system_name / f'{system_name}.qip'
        if (not sysid_path.is_file() or not qip_path.is_file() or
                f'submodules/{system_name}_sysid.v' not in qip_path.read_text()):
            raise SystemExit('Qsys-generated db/ip subtree lacks the compiled SYSID binding')
        if inputs_path.exists():
            raise SystemExit('incremental build cannot use an ambiguous QSYS_FILE binding')
        certified = legacy.get('compiled_qsys_hdl_sha256', {})
        relative = str(sysid_path.relative_to(build))
        if certified.get(relative) != sha256(sysid_path):
            raise SystemExit('QSYS_FILE compiled SYSID differs from the successful full-build certificate')
        sysid_binding = 'QSYS_FILE'
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
    def relative_file_set(root):
        result = {}
        for path in sorted(root.rglob('*')):
            relative = path.relative_to(root)
            # build.sh emits this temporary Verilator model while checking the
            # decoder. Its dependency file and build log contain host-specific
            # paths/timing, and none of its contents are Quartus inputs.
            if 'dispatch-model' in relative.parts or '__pycache__' in relative.parts:
                continue
            if not path.is_file() or path.suffix == '.pyc':
                continue
            result[str(relative)] = sha256(path)
        return result

    generated_files = relative_file_set(generated)
    if not generated_files:
        raise SystemExit('build contains no generated CPU ROM/template inputs')
    live_generated = Path(tempfile.mkdtemp(prefix='jttms10-receipt-generated-'))
    try:
        subprocess.run(['bash', str(source / 'modules/jttms10/ver/build.sh'), str(live_generated)],
                       check=True, stdout=subprocess.DEVNULL)
        current_generated = relative_file_set(live_generated)
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
        'build_manifest_sha256': sha256(certificate_path),
        'build_result_sha256': sha256(result_path) if result_path.is_file() else None,
        'map_result_sha256': sha256(build/'v2-map-result.json') if (build/'v2-map-result.json').is_file() else None,
        'quartus_flow_seconds': flow_seconds,
        'quartus_flow_exit': flow_exit,
        'sysid': sysid,
        'sysid_timestamp': timestamp,
        'sysid_source': str(sysid_path),
        'sysid_source_sha256': sha256(sysid_path),
        'sysid_binding': sysid_binding,
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
