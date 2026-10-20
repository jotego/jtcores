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


RAPID_RESULT_FORMAT = 'jttms10-rapid-build-result-v1'


def validate_positive_sta(path):
    rows = re.findall(r'Type\s*:\s*[^\n]+\nSlack\s*:\s*([-\d.]+)\nTNS\s*:\s*([-\d.]+)',
                      path.read_text())
    if not rows or any(float(slack) <= 0 or float(tns) != 0 for slack, tns in rows):
        raise SystemExit(f'Rapid build requires positive final STA and zero TNS: {path}')


def validate_rapid_result(build, result):
    """Validate a real source-changing Rapid flow, without relabeling it full.

    Common frozen source/input/RBF checks are also applied by the caller.
    Fresh reports and the immutable parent bind the recompile's reused fit.
    """
    build = build.resolve(strict=True)
    command = ['/opt/quartus_free/quartus_sh', '--flow', 'recompile', 'test_board']
    if (result.get('format') != RAPID_RESULT_FORMAT or
            result.get('flow_kind') != 'recompile' or result.get('command') != command or
            result.get('working_directory') != str(build) or
            result.get('full_flow_only') is True or result.get('flow_exit_code') != 0 or
            result.get('inputs_unchanged') is not True):
        raise SystemExit('invalid Rapid command/flow certificate')
    log = build / 'logs/v2-compile.log'
    marker = result.get('terminal_marker')
    if (not log.is_file() or result.get('flow_log_sha256') != sha256(log) or
            not isinstance(marker, str) or not marker or
            'successful' not in marker.lower() or marker not in log.read_text(errors='replace')):
        raise SystemExit('Rapid certificate lacks its actual successful flow log')
    reports = result.get('stage_reports')
    if not isinstance(reports, dict) or set(reports) != {'map', 'fit', 'asm', 'sta'}:
        raise SystemExit('Rapid certificate must bind map, fit, assembly and STA reports')
    freeze = build / 'v2-compile-inputs.json'
    if not freeze.is_file():
        raise SystemExit('Rapid build lacks its pre-flow compile-input snapshot')
    for stage, digest in reports.items():
        report = build / f'output_files/test_board.{stage}.rpt'
        if (not report.is_file() or sha256(report) != digest or
                report.stat().st_mtime_ns <= freeze.stat().st_mtime_ns):
            raise SystemExit(f'Rapid stage report is missing, stale or changed: {stage}')
    sta = build / 'output_files/test_board.sta.summary'
    if (not sta.is_file() or result.get('sta_summary_sha256') != sha256(sta) or
            sta.stat().st_mtime_ns <= freeze.stat().st_mtime_ns):
        raise SystemExit('Rapid final STA summary is missing, stale or changed')
    validate_positive_sta(sta)
    parent_name = result.get('parent_build_dir')
    if not isinstance(parent_name, str) or not parent_name:
        raise SystemExit('Rapid certificate lacks its fitted parent')
    try:
        parent = Path(parent_name).resolve(strict=True)
    except OSError as error:
        raise SystemExit(f'Rapid fitted parent is unavailable: {parent_name}') from error
    if parent == build:
        raise SystemExit('Rapid build cannot certify itself as its parent')
    bindings = {'parent_build_result_sha256': parent / 'v2-build-result.json',
                'parent_inputs_sha256': parent / 'v2-build-inputs.json',
                'parent_image_sha256': parent / 'output_files/test_board.rbf',
                'parent_sta_summary_sha256': parent / 'output_files/test_board.sta.summary'}
    for key, path in bindings.items():
        if not path.is_file() or result.get(key) != sha256(path):
            raise SystemExit(f'Rapid parent evidence is missing or changed: {key}')
    parent_result = json.loads(bindings['parent_build_result_sha256'].read_text())
    if (parent_result.get('format') not in ('jttms10-incremental-build-result-v1', RAPID_RESULT_FORMAT) or
            parent_result.get('flow_exit_code') != 0 or parent_result.get('inputs_unchanged') is not True or
            parent_result.get('input_manifest_sha256') != result['parent_inputs_sha256'] or
            parent_result.get('rbf_sha256') != result['parent_image_sha256']):
        raise SystemExit('Rapid parent result does not certify its frozen inputs/image')
    validate_positive_sta(bindings['parent_sta_summary_sha256'])


def runner_source_fingerprints(source_root):
    """Bind all synthesizable runner components, independently of the oracle."""
    root = Path(source_root).resolve()
    names = ('jttms10_fpga_runner.v', 'jttms10_fpga_stimulus.v')
    paths = [root / 'modules/jttms10/ver/fpga' / name for name in names]
    if any(not path.is_file() for path in paths):
        raise SystemExit('runner source fingerprint input is missing')
    return {str(path.relative_to(root)): sha256(path) for path in paths}


def cpu_source_fingerprints(source_root):
    """Hash the CPU implementation and every source/tool input that builds it.

    Timing fixtures and the Python oracle are deliberately excluded: changing
    expected observations must not require recompiling or re-certifying the
    FPGA image.
    """
    root = Path(source_root).resolve()
    cpu_hdl = root / 'modules/jttms10/hdl'
    cpu_ucode = root / 'modules/jttms10/ucode'
    decoder = root / 'modules/jttms10/ver/decoder'
    gfx = root / 'modules/jttms10/ver/gfx'
    shared_ucode = root / 'modules/jtframe/src/jtframe/ucode'
    groups = (cpu_hdl, cpu_ucode, decoder, gfx, shared_ucode)
    paths = set()
    paths.update((root / 'modules/jttms10/ver/build.sh',))
    paths.update((root / 'modules/jttms10/ver/verilator_build.py',))
    paths.update((root / 'modules/jtframe/bin/jtframe',))
    for directory in groups:
        if not directory.is_dir():
            raise SystemExit(f'CPU source fingerprint directory is missing: {directory}')
        for path in directory.rglob('*'):
            if not path.is_file() or '__pycache__' in path.parts or path.suffix == '.pyc':
                continue
            if directory == cpu_hdl and path.suffix not in {'.v', '.vh', '.hex'}:
                continue
            if directory == cpu_ucode and path.suffix not in {'.yaml', '.yml'}:
                continue
            if directory == decoder and path.suffix not in {'.py', '.sv', '.v', '.vh'}:
                continue
            if directory == gfx and path.suffix != '.py':
                continue
            if directory == shared_ucode and path.suffix not in {'.go', '.vh'}:
                continue
            paths.add(path)
    missing = [path for path in paths if not path.is_file()]
    if missing:
        raise SystemExit(f'CPU source fingerprint input is missing: {missing[0]}')
    return {path.relative_to(root).as_posix(): sha256(path)
            for path in sorted(paths)}


def cpu_source_fingerprint_digest(fingerprints):
    encoded = json.dumps(fingerprints, sort_keys=True, separators=(',', ':')).encode()
    return hashlib.sha256(encoded).hexdigest()


def tree_hashes(root):
    root = Path(root).resolve(strict=True)
    return {path.relative_to(root).as_posix(): sha256(path)
            for path in sorted(root.rglob('*')) if path.is_file()}


def artifact_hashes(root):
    root = Path(root).resolve(strict=True)
    return {path.name: sha256(path) for path in sorted(root.iterdir())
            if path.is_file() and path.suffix in {'.uc', '.vh', '.hex'}}


def parse_mif(path):
    text = Path(path).read_text()
    header = re.search(r'WIDTH=(\d+);\s*DEPTH=(\d+);', text)
    if not header:
        raise SystemExit(f'could not parse MIF dimensions: {path}')
    width, depth = map(int, header.groups())
    values = [None] * depth
    for address, value in re.findall(r'\s*(\d+)\s*:\s*([01]+)\s*;', text):
        address = int(address)
        if address >= depth or values[address] is not None or len(value) != width:
            raise SystemExit(f'invalid or duplicate MIF word at {address}: {path}')
        values[address] = value
    if any(value is None for value in values):
        raise SystemExit(f'MIF is incomplete: {path}')
    return width, values


def phase_record(path, phase):
    path = Path(path).resolve(strict=True)
    text = path.read_text(errors='replace')
    seconds = re.search(r'seconds=([0-9]+(?:\.[0-9]+)?)', text)
    exit_code = re.search(r'exit=(\d+)', text)
    if not seconds or not exit_code or int(exit_code.group(1)) != 0:
        raise SystemExit(f'{phase} timing record does not certify exit 0: {path}')
    return {'seconds': float(seconds.group(1)), 'exit_code': 0,
            'timing_path': str(path), 'timing_sha256': sha256(path)}


def file_deltas(base, variant):
    before = tree_hashes(base)
    after = tree_hashes(variant)
    return {
        name: {'base_sha256': before.get(name), 'variant_sha256': after.get(name)}
        for name in sorted(before.keys() | after.keys()) if before.get(name) != after.get(name)
    }, before, after


ROM_UPDATE_DELTA_ALLOWLIST = {
    'tms10.uc',
    'ip/jttms10_fpga_runner/tms10.uc',
    'jttms10-generated/tms10.uc',
    'db/test_board.ram0_jttms10_ctrl_cc30e43c.hdl.mif',
    'db/test_board.asm.qmsg', 'db/test_board.asm.rdb',
    'db/test_board.cmp.cdb', 'db/test_board.cmp.hdb', 'db/test_board.cmp.rdb',
    'db/test_board.map.cdb', 'db/test_board.mif_update.qmsg',
    'output_files/test_board.asm.rpt', 'output_files/test_board.flow.rpt',
    'output_files/test_board.mif_update.rpt', 'output_files/test_board.rbf',
    'output_files/test_board.sof',
}


def generate_cpu_artifacts(source):
    generated = Path(tempfile.mkdtemp(prefix='jttms10-rom-variant-source-'))
    try:
        subprocess.run(['bash', str(Path(source) / 'modules/jttms10/ver/build.sh'), str(generated)],
                       check=True, stdout=subprocess.DEVNULL)
        return {path.name: sha256(path) for path in sorted(generated.iterdir())
                if path.is_file() and path.suffix in {'.uc', '.vh', '.hex'}}, generated
    except BaseException:
        import shutil
        shutil.rmtree(generated, ignore_errors=True)
        raise


def write_rom_update_receipt(*, image, build, base_build, baseline_source,
                             hardware_source, parent_receipt_path, boot_id,
                             overlay, variant_name, cdb_log, asm_log,
                             cdb_time, asm_time, source_generation_time, output):
    """Certify a CDB/ASM ROM update as an inherited-fit variant, never as a compile."""
    if not re.fullmatch(r'[0-9a-fA-F-]{36}', boot_id):
        raise SystemExit('invalid board boot ID')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+', overlay):
        raise SystemExit('invalid overlay name')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+', variant_name):
        raise SystemExit('invalid ROM-update variant name')
    source_phase = phase_record(source_generation_time, 'source generation')
    cdb_phase = phase_record(cdb_time, 'quartus_cdb')
    asm_phase = phase_record(asm_time, 'quartus_asm')
    image = Path(image).resolve(strict=True)
    build = Path(build).resolve(strict=True)
    base_build = Path(base_build).resolve(strict=True)
    baseline_source = Path(baseline_source).resolve(strict=True)
    hardware_source = Path(hardware_source).resolve(strict=True)
    parent_receipt_path = Path(parent_receipt_path).resolve(strict=True)
    parent = json.loads(parent_receipt_path.read_text())
    if parent.get('format') != 'jttms10-fpga-programming-receipt-v1':
        raise SystemExit('parent must be the canonical full-fit programming receipt')
    if parent.get('protocol_version') != 4:
        raise SystemExit('V4 ROM update requires a protocol 4 parent receipt')
    for root in {baseline_source, hardware_source}:
        if runner_source_fingerprints(root) != parent.get('runner_source_fingerprints'):
            raise SystemExit('ROM update runner components differ from the fitted parent')
    baseline_fingerprints = cpu_source_fingerprints(baseline_source)
    if parent.get('cpu_source_fingerprints') != baseline_fingerprints:
        raise SystemExit('parent receipt is not source-bound to the baseline checkout')
    variant_fingerprints = cpu_source_fingerprints(hardware_source)
    changed_source = sorted(set(baseline_fingerprints) | set(variant_fingerprints))
    changed_source = [name for name in changed_source
                      if baseline_fingerprints.get(name) != variant_fingerprints.get(name)]
    source_delta = 'modules/jttms10/ucode/tms10.yaml'
    if changed_source != [source_delta]:
        raise SystemExit(f'ROM variant must change only {source_delta}; found {changed_source}')
    parent_build_result = base_build / 'v2-build-result.json'
    parent_inputs = base_build / 'v2-build-inputs.json'
    parent_sta = base_build / 'output_files/test_board.sta.summary'
    if not parent_build_result.is_file() or not parent_inputs.is_file() or not parent_sta.is_file():
        raise SystemExit('parent fitted build is missing result/input/STA evidence')
    result = json.loads(parent_build_result.read_text())
    if (result.get('format') != 'jttms10-incremental-build-result-v1' or
            result.get('flow_exit_code') != 0 or result.get('full_flow_only') is not True or
            result.get('rbf_sha256') != parent.get('image_sha256') or
            result.get('input_manifest_sha256') != sha256(parent_inputs) or
            parent.get('build_result_sha256') != sha256(parent_build_result)):
        raise SystemExit('parent receipt/build result do not certify the inherited full fit')
    if not (build / 'v2-build-result.json').is_file() or \
       sha256(build / 'v2-build-result.json') != sha256(parent_build_result):
        raise SystemExit('variant build clone changed the inherited successful-fit certificate')
    compiled_base = base_build / 'output_files/test_board.rbf'
    compiled_variant = build / 'output_files/test_board.rbf'
    if sha256(compiled_base) != parent.get('image_sha256'):
        raise SystemExit('base fit image does not match the parent programming receipt')
    if sha256(image) != sha256(compiled_variant):
        raise SystemExit('variant image does not match the assembler-produced RBF')
    deltas, before_files, after_files = file_deltas(base_build, build)
    unexpected = sorted(set(deltas) - ROM_UPDATE_DELTA_ALLOWLIST)
    if unexpected:
        raise SystemExit(f'ROM update changed files outside ROM/ASM allowlist: {unexpected}')
    required_changes = {
        'db/test_board.ram0_jttms10_ctrl_cc30e43c.hdl.mif',
        'output_files/test_board.rbf',
        'output_files/test_board.sof',
    }
    if not required_changes <= set(deltas):
        raise SystemExit('ROM update did not produce the required MIF/SOF/RBF changes')
    unchanged_before = {key: value for key, value in before_files.items()
                        if key not in ROM_UPDATE_DELTA_ALLOWLIST}
    unchanged_after = {key: value for key, value in after_files.items()
                       if key not in ROM_UPDATE_DELTA_ALLOWLIST}
    if unchanged_before != unchanged_after:
        raise SystemExit('fitted netlist, constraints, generated IP, or fit database changed')
    if parent_sta.is_file() and sha256(parent_sta) != sha256(build / 'output_files/test_board.sta.summary'):
        raise SystemExit('post-fit STA report changed in the ROM-only variant')
    cdb_log, asm_log = Path(cdb_log).resolve(strict=True), Path(asm_log).resolve(strict=True)
    cdb_text, asm_text = cdb_log.read_text(errors='replace'), asm_log.read_text(errors='replace')
    if 'MIF/HEX Update was successful' not in cdb_text or '0 errors' not in cdb_text:
        raise SystemExit('CDB log does not record a successful MIF update')
    if 'Assembler was successful' not in asm_text or '0 errors' not in asm_text:
        raise SystemExit('Assembler log does not record a successful image build')
    generated, temp_generated = generate_cpu_artifacts(hardware_source)
    try:
        package = build / 'ip/jttms10_fpga_runner'
        package_hashes = artifact_hashes(package)
        root_hashes = artifact_hashes(build)
        generated_hashes = artifact_hashes(build / 'jttms10-generated')
        if generated != package_hashes or generated != root_hashes or generated != generated_hashes:
            raise SystemExit('variant generated ROM/template inputs do not match packaged build inputs')
        baseline_generated = {
            name: digest for name, digest in parent.get('current_source_generated_files', {}).items()
            if Path(name).suffix in {'.uc', '.vh', '.hex'}
        }
        changed_generated = sorted(name for name in set(generated) | set(baseline_generated)
                                   if generated.get(name) != baseline_generated.get(name))
        if changed_generated != ['tms10.uc']:
            raise SystemExit(f'generated ROM update changed unexpected files: {changed_generated}')
        uc_path = temp_generated / 'tms10.uc'
        uc_rows = uc_path.read_text().splitlines()
        mif_path = build / 'db/test_board.ram0_jttms10_ctrl_cc30e43c.hdl.mif'
        width, mif_words = parse_mif(mif_path)
        if width != 62 or len(uc_rows) != 4096 or mif_words != uc_rows:
            raise SystemExit('updated main-control MIF is not an exact encoding of the generated tms10.uc')
    finally:
        import shutil
        shutil.rmtree(temp_generated, ignore_errors=True)
    qsf = build / 'test_board.qsf'
    qsf_text = qsf.read_text()
    qip_match = re.search(r'^set_global_assignment\s+-name\s+QIP_FILE\s+(.+?)\s*$',
                          qsf_text, re.MULTILINE)
    if not qip_match:
        raise SystemExit('inherited-fit variant requires the preserved QIP-bound project')
    qip = (build / qip_match.group(1).strip('"{}')).resolve()
    sysid_path = qip.parent / 'submodules/QSYS_test_board_sysid.v'
    text = sysid_path.read_text()
    match = re.search(r'assign\s+readdata\s*=\s*address\s*\?\s*(\d+)\s*:\s*(\d+)\s*;', text)
    if not match:
        raise SystemExit('could not parse the inherited SYSID source')
    timestamp, sysid = map(int, match.groups())
    if sysid != parent.get('sysid') or timestamp != parent.get('sysid_timestamp'):
        raise SystemExit('variant SYSID differs from its fitted parent')
    source_path = hardware_source / source_delta
    baseline_mif_words = parse_mif(base_build / 'db/test_board.ram0_jttms10_ctrl_cc30e43c.hdl.mif')[1]
    receipt = {
        'format': 'jttms10-fpga-rom-update-receipt-v1',
        'variant_name': variant_name,
        'parent_receipt_path': str(parent_receipt_path),
        'parent_receipt_sha256': sha256(parent_receipt_path),
        'parent_image_sha256': parent['image_sha256'],
        'parent_build_result_sha256': parent['build_result_sha256'],
        'parent_build_manifest_sha256': parent['build_manifest_sha256'],
        'parent_sta_summary_sha256': sha256(parent_sta),
        'parent_build_dir': str(base_build),
        'parent_build_inputs_path': str(parent_inputs),
        'parent_build_result_path': str(parent_build_result),
        'parent_sta_summary_path': str(parent_sta),
        'parent_compile_log_path': str(base_build / 'logs/v2-compile.log'),
        'parent_compile_log_sha256': result.get('flow_log_sha256'),
        'inherited_fit_only': True,
        'full_compile_claim': False,
        'fit_unchanged_file_count': len(unchanged_before),
        'fit_unchanged_files_sha256': cpu_source_fingerprint_digest(unchanged_before),
        'changed_build_files': deltas,
        'cpu_source_fingerprints': variant_fingerprints,
        'cpu_source_fingerprint_sha256': cpu_source_fingerprint_digest(variant_fingerprints),
        'baseline_cpu_source_fingerprint_sha256': cpu_source_fingerprint_digest(baseline_fingerprints),
        'source_delta': {
            'path': source_delta,
            'baseline_sha256': baseline_fingerprints[source_delta],
            'variant_sha256': variant_fingerprints[source_delta],
        },
        'source_generated_files': generated,
        'changed_mif_path': 'db/test_board.ram0_jttms10_ctrl_cc30e43c.hdl.mif',
        'variant_mif_path': str(build / 'db/test_board.ram0_jttms10_ctrl_cc30e43c.hdl.mif'),
        'changed_mif_sha256': sha256(build / 'db/test_board.ram0_jttms10_ctrl_cc30e43c.hdl.mif'),
        'changed_mif_words': [index for index, value in enumerate(mif_words)
                              if value != baseline_mif_words[index]],
        'source_generation': source_phase,
        'cdb': {**cdb_phase, 'log_path': str(cdb_log), 'log_sha256': sha256(cdb_log)},
        'assembler': {**asm_phase, 'log_path': str(asm_log), 'log_sha256': sha256(asm_log)},
        'image_path': str(image),
        'image_sha256': sha256(image),
        'runner_source_sha256': parent['runner_source_sha256'],
        'protocol_version': parent['protocol_version'],
        'runner_source_fingerprints': parent['runner_source_fingerprints'],
        'sysid': sysid,
        'sysid_timestamp': timestamp,
        'sysid_source_sha256': sha256(sysid_path),
        'board_boot_id': boot_id.lower(),
        'overlay': overlay,
        'firmware_name': f'jtcores-rom-{variant_name}-{sha256(image)[:12]}.rbf',
    }
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
    print(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--image', required=True, type=Path)
    parser.add_argument('--build-dir', required=True, type=Path)
    parser.add_argument('--source-root', required=True, type=Path)
    parser.add_argument('--hardware-source-root', type=Path,
                        help='CPU implementation checkout for ROM-update variants')
    parser.add_argument('--rom-update-parent-receipt', type=Path,
                        help='write an inherited-fit ROM-update certificate instead of a full-build receipt')
    parser.add_argument('--base-build-dir', type=Path,
                        help='successful fitted build that the ROM-only variant inherits')
    parser.add_argument('--variant-name', help='short unique ROM variant name')
    parser.add_argument('--cdb-log', type=Path, help='successful quartus_cdb --update_mif log')
    parser.add_argument('--asm-log', type=Path, help='successful quartus_asm log')
    parser.add_argument('--cdb-time', type=Path, help='monotonic quartus_cdb timing record')
    parser.add_argument('--asm-time', type=Path, help='monotonic quartus_asm timing record')
    parser.add_argument('--source-generation-time', type=Path,
                        help='monotonic CPU ROM generation timing record')
    parser.add_argument('--boot-id', required=True)
    parser.add_argument('--overlay', required=True)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    if not re.fullmatch(r'[0-9a-fA-F-]{36}', args.boot_id):
        raise SystemExit('invalid board boot ID')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+', args.overlay):
        raise SystemExit('invalid overlay name')
    if args.rom_update_parent_receipt:
        required = {
            '--base-build-dir': args.base_build_dir,
            '--hardware-source-root': args.hardware_source_root,
            '--variant-name': args.variant_name,
            '--cdb-log': args.cdb_log,
            '--asm-log': args.asm_log,
            '--cdb-time': args.cdb_time,
            '--asm-time': args.asm_time,
            '--source-generation-time': args.source_generation_time,
        }
        missing = [name for name, value in required.items() if value is None]
        if missing:
            raise SystemExit(f'ROM-update receipt is missing required options: {", ".join(missing)}')
        write_rom_update_receipt(
            image=args.image, build=args.build_dir, base_build=args.base_build_dir,
            baseline_source=args.source_root,
            hardware_source=args.hardware_source_root,
            parent_receipt_path=args.rom_update_parent_receipt,
            boot_id=args.boot_id, overlay=args.overlay, variant_name=args.variant_name,
            cdb_log=args.cdb_log, asm_log=args.asm_log,
            cdb_time=args.cdb_time, asm_time=args.asm_time,
            source_generation_time=args.source_generation_time, output=args.output)
        return
    image = args.image.resolve(strict=True)
    build = args.build_dir.resolve(strict=True)
    source = args.source_root.resolve(strict=True)
    source_fingerprints = cpu_source_fingerprints(source)
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
        if build_result.get('format') == RAPID_RESULT_FORMAT:
            validate_rapid_result(build, build_result)
        elif build_result.get('full_flow_only') is not True:
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
        if build_result.get('format') not in ('jttms10-incremental-build-result-v1', RAPID_RESULT_FORMAT) or \
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
    runner_fingerprints = runner_source_fingerprints(source)
    for relative, digest in runner_fingerprints.items():
        if sha256(rtl_package / Path(relative).name) != digest:
            raise SystemExit('packaged runner component differs from source: '+relative)
    source_hdl = source / 'modules/jttms10/hdl'
    source_hdl_files = {path.name: sha256(path) for path in source_hdl.glob('*.v')}
    package_hdl_files = {path.name: sha256(path) for path in rtl_package.glob('*.v')
                         if path.name not in {Path(relative).name for relative in runner_fingerprints}}
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
        'protocol_version': 4,
        'runner_source_fingerprints': runner_fingerprints,
        'cpu_source_fingerprints': source_fingerprints,
        'cpu_source_fingerprint_sha256': cpu_source_fingerprint_digest(source_fingerprints),
        'image_path': str(image),
        'image_sha256': sha256(image),
        'build_manifest_sha256': sha256(certificate_path),
        'build_result_sha256': sha256(result_path) if result_path.is_file() else None,
        'map_result_sha256': sha256(build/'v2-map-result.json') if (build/'v2-map-result.json').is_file() else None,
        'quartus_flow_seconds': flow_seconds,
        'quartus_flow_exit': flow_exit,
        'quartus_flow_kind': build_result.get('flow_kind', 'compile') if inputs_path.exists() else 'compile',
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
