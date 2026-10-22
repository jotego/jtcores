#!/usr/bin/env python3
"""Host-only tests for separate FPGA implementation and oracle identities."""
import json
import importlib.util
import os
from pathlib import Path
import shutil
import sys
import subprocess
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import run_batch
import write_programming_receipt as receipts
import partition_build

ORACLE_ENV = 'JT_TMS10_ORACLE_ROOT'
HARDWARE_ENV = 'JTROOT'


def find_hardware_root():
    candidates = []
    if os.environ.get(HARDWARE_ENV):
        candidates.append(Path(os.environ[HARDWARE_ENV]).expanduser())
    candidates.extend(HERE.parents)
    for candidate in candidates:
        root = candidate.resolve()
        if ((root / 'modules/jttms10/hdl').is_dir() and
                (root / 'modules/jttms10/ver/restart/README.md').is_file()):
            return root
    raise RuntimeError(f'could not locate hardware checkout; set {HARDWARE_ENV}')


def find_oracle_root():
    value = os.environ.get(ORACLE_ENV)
    if not value:
        raise unittest.SkipTest(
            f'{ORACLE_ENV} must point to the pinned frozen #144 checkout '
            'at commit 9a17778b941dce89328316ee3e8f7f0a4bd14923')
    root = Path(value).expanduser().resolve()
    if not ((root / 'modules/jttms10/ver/fpga/check_results.py').is_file() and
            (root / 'modules/jttms10/ver/timing').is_dir()):
        raise unittest.SkipTest(f'{ORACLE_ENV} is missing the frozen #144 checker/timing tree: {root}')
    return root


class SourceRootResolution(unittest.TestCase):
    def test_production_resolvers_accept_current_hardware_and_pinned_oracle(self):
        hardware = find_hardware_root()
        oracle = find_oracle_root()
        self.assertEqual(run_batch.find_hardware_source_root(hardware), hardware)
        self.assertEqual(run_batch.find_source_root(oracle), oracle)
        self.assertNotEqual(hardware, oracle)

    def test_environment_defaults_keep_hardware_and_oracle_roots_separate(self):
        hardware = find_hardware_root()
        oracle = find_oracle_root()
        with patch.dict(os.environ, {HARDWARE_ENV: str(hardware), ORACLE_ENV: str(oracle)}):
            self.assertEqual(run_batch.find_source_root(), oracle)
            self.assertEqual(run_batch.find_hardware_source_root(source_root=oracle), hardware)

    def test_hardware_resolver_rejects_checkout_without_cpu_sources(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'modules/jttms10/ver/restart').mkdir(parents=True)
            (root / 'modules/jttms10/ver/restart/README.md').write_text('not a CPU checkout')
            (root / 'modules/jttms10/ver/fpga').mkdir(parents=True)
            (root / 'modules/jttms10/ver/fpga/jttms10_fpga_runner.v').write_text('module runner; endmodule')
            (root / 'modules/jttms10/ver/fpga/jttms10_fpga_stimulus.v').write_text('module stimulus; endmodule')
            with self.assertRaisesRegex(SystemExit, 'cannot locate #149 CPU hardware checkout'):
                run_batch.find_hardware_source_root(root)

    def test_expectation_resolver_rejects_checkout_without_frozen_checker(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'modules/jttms10/ver/timing').mkdir(parents=True)
            (root / 'modules/jttms10/ver/timing/run.py').write_text('# not pinned')
            with self.assertRaisesRegex(SystemExit, 'cannot locate independent TMS34010 expectation checkout'):
                run_batch.find_source_root(root)


class HardwareOracleIdentity(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.oracle = find_oracle_root()
        hardware_root = find_hardware_root()
        self.hardware = Path(self.temp.name) / 'hardware'
        self.hardware.mkdir()
        source_fingerprints = receipts.cpu_source_fingerprints(hardware_root)
        for rel in source_fingerprints:
            source = hardware_root / rel
            target = self.hardware / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
        marker = self.hardware / 'modules/jttms10/ver/restart/README.md'
        marker.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(hardware_root / 'modules/jttms10/ver/restart/README.md', marker)
        for name in ('jttms10_fpga_runner.v', 'jttms10_fpga_stimulus.v'):
            rel = Path('modules/jttms10/ver/fpga') / name
            target = self.hardware / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(HERE / name, target)
        self.image = Path(self.temp.name) / 'candidate.rbf'
        self.image.write_bytes(b'candidate-image-for-identity-test')
        sources = receipts.cpu_source_fingerprints(self.hardware)
        self.receipt = {
            'format': 'jttms10-fpga-programming-receipt-v1',
            'protocol_version': 5,
            'runner_source_fingerprints': receipts.runner_source_fingerprints(self.hardware),
            'cpu_source_fingerprints': sources,
            'cpu_source_fingerprint_sha256': receipts.cpu_source_fingerprint_digest(sources),
            'runner_source_sha256': receipts.sha256(
                self.hardware / 'modules/jttms10/ver/fpga/jttms10_fpga_runner.v'),
            'image_path': str(self.image),
            'image_sha256': receipts.sha256(self.image),
            'sysid': 22,
            'sysid_timestamp': 123,
            'board_boot_id': '9f611c5b-2284-4ae0-91f0-8af7510b7a44',
            'overlay': 'test-candidate',
        }
        self.receipt_path = Path(self.temp.name) / 'receipt.json'
        self.write_receipt()

    def write_receipt(self):
        self.receipt_path.write_text(json.dumps(self.receipt))

    def validate(self):
        return run_batch.load_and_validate_receipt(
            self.receipt_path, self.oracle, self.hardware)

    def test_different_frozen_oracle_is_accepted_with_hardware_receipt(self):
        _, oracle, hardware = self.validate()
        self.assertNotEqual(oracle, hardware)
        self.assertEqual(hardware, self.receipt['cpu_source_fingerprints'])

    def test_stale_hardware_cpu_is_rejected(self):
        rel = next(iter(self.receipt['cpu_source_fingerprints']))
        path = self.hardware / rel
        path.write_bytes(path.read_bytes() + b'\nchanged after receipt\n')
        with self.assertRaisesRegex(SystemExit, 'CPU implementation checkout differs'):
            self.validate()

    def test_stale_hardware_runner_is_rejected(self):
        path = self.hardware / 'modules/jttms10/ver/fpga/jttms10_fpga_stimulus.v'
        path.write_bytes(path.read_bytes() + b'\nchanged after receipt\n')
        with self.assertRaisesRegex(SystemExit, 'hardware runner component checkout differs'):
            self.validate()

    def test_frozen_expectation_manifest_is_enforced(self):
        digest = run_batch.validate_expectation_sources(self.oracle)
        self.assertEqual(digest, run_batch.EXPECTATION_MANIFEST_SHA256)
        with tempfile.TemporaryDirectory() as other:
            copy_root = Path(other)
            manifest = json.loads((HERE / 'expectation_sources.json').read_text())
            for entry in manifest['files']:
                source = self.oracle / entry['path']
                target = copy_root / entry['path']
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
            source = copy_root / manifest['files'][0]['path']
            source.write_bytes(source.read_bytes() + b'\nmutation\n')
            with self.assertRaisesRegex(SystemExit, 'independent expectation source changed'):
                run_batch.validate_expectation_sources(copy_root)


class GeneratedArtifactIdentity(unittest.TestCase):
    def test_fresh_generation_ignores_dispatch_log_and_rom_mutation(self):
        source = find_hardware_root()
        with tempfile.TemporaryDirectory() as temp:
            outputs = [Path(temp) / 'first', Path(temp) / 'second']
            for index, output in enumerate(outputs):
                subprocess.run(['bash', str(source / 'modules/jttms10/ver/build.sh'), str(output)],
                               check=True, stdout=subprocess.DEVNULL)
                log = output / 'dispatch-build.log'
                if log.is_file():
                    log.write_text(f'output={output} seconds={index}.01\n')
            first = receipts.generated_file_set(outputs[0])
            second = receipts.generated_file_set(outputs[1])
            self.assertEqual(first, second)
            rom = outputs[1] / 'tms10.uc'
            self.assertTrue(rom.is_file(), 'generated main-control ROM is a consumed input')
            rom.write_bytes(rom.read_bytes() + b'\n% mutation\n')
            self.assertNotEqual(first, receipts.generated_file_set(outputs[1]))


class LegacySeedCompileSnapshotRecovery(unittest.TestCase):
    """Only the fully bound saved seed may use the manifest-shadow recovery."""

    BUILD = Path('/tmp/jtcores-149-seed-002')

    def setUp(self):
        if not (self.BUILD / 'v2-build-result.json').is_file():
            self.skipTest('saved #149 seed build is unavailable')
        self.inputs_path = self.BUILD / 'v2-build-inputs.json'
        self.compile_path = self.BUILD / 'v2-compile-inputs.json'
        self.inputs = json.loads(self.inputs_path.read_text())
        self.compile_inputs = json.loads(self.compile_path.read_text())
        self.result = json.loads((self.BUILD / 'v2-build-result.json').read_text())

    def validate(self, inputs=None, compile_inputs=None, build_result=None, build=None):
        return receipts.validate_compile_input_snapshot(
            build or self.BUILD, self.inputs_path, self.inputs if inputs is None else inputs,
            self.compile_path, self.compile_inputs if compile_inputs is None else compile_inputs,
            self.result if build_result is None else build_result)

    def test_real_saved_partition_seed_recovers_with_full_rehash_evidence(self):
        recovery = self.validate()
        self.assertEqual(recovery['format'], 'jttms10-known-compile-input-path-shadow-recovery-v1')
        self.assertEqual(recovery['misattributed_diagnostic'],
                         'jttms10-generated/dispatch-model/Vtest.mk')
        self.assertEqual(recovery['source_count_rehashed'], 39)
        self.assertEqual(recovery['compile_file_count_rehashed'], 146)
        self.assertEqual(recovery['diagnostic_count_rehashed'], 28)

    def test_exact_public_partition_result_delegates_only_with_bound_original_helper(self):
        self.assertEqual(partition_build.validate_partition_result(
            self.BUILD, self.result)['mode'], 'seed')

        altered = dict(self.result)
        altered['flow_seconds'] += 0.01
        with self.assertRaisesRegex(ValueError, 'differs from its on-disk certificate'):
            partition_build.validate_partition_result(self.BUILD, altered)

        inputs = self.inputs
        source_root = Path(inputs['source_root']).resolve()
        helper = source_root / 'modules/jttms10/ver/fpga/partition_build.py'
        original_sha = partition_build.sha256

        def changed_helper(path):
            if Path(path).resolve() == helper.resolve():
                return '0' * 64
            return original_sha(path)

        with patch.object(partition_build, 'sha256', side_effect=changed_helper):
            with self.assertRaisesRegex(ValueError, 'validator source hash'):
                partition_build.validate_partition_result(self.BUILD, self.result)

    def test_changed_legacy_result_and_stage_certificate_reject(self):
        with tempfile.TemporaryDirectory(prefix='jttms10-legacy-result-') as temporary:
            build = Path(temporary)
            result_path = build / 'v2-build-result.json'
            result_path.write_text(json.dumps({**self.result, 'test_mutation': True}))
            shutil.copy2(self.BUILD / 'v2-partition-stage-result.json', build)
            with self.assertRaises((ValueError, OSError)):
                partition_build.validate_partition_result(
                    build, json.loads(result_path.read_text()))

        with tempfile.TemporaryDirectory(prefix='jttms10-legacy-cert-') as temporary:
            build = Path(temporary)
            shutil.copy2(self.BUILD / 'v2-build-result.json', build)
            shutil.copy2(self.inputs_path, build)
            cert = build / 'v2-partition-stage-result.json'
            shutil.copy2(self.BUILD / cert.name, cert)
            cert.write_bytes(cert.read_bytes() + b'\nmutation\n')
            with self.assertRaisesRegex(ValueError, 'certificate'):
                partition_build.validate_partition_result(build, self.result)

    def test_changed_legacy_payload_copy_is_rejected_without_mutating_saved_seed(self):
        source_root = Path(self.inputs['source_root']).resolve()
        helper_path = source_root / 'modules/jttms10/ver/fpga/partition_build.py'
        self.assertEqual(receipts.sha256(helper_path),
                         partition_build.LEGACY_SAVED_SEED_HELPER_SHA256)
        spec = importlib.util.spec_from_file_location('_test_pinned_seed_partition_build',
                                                       helper_path)
        self.assertIsNotNone(spec)
        legacy = importlib.util.module_from_spec(spec)
        assert spec.loader is not None
        spec.loader.exec_module(legacy)
        original = json.loads((self.BUILD / 'v2-generated-payloads.json').read_text())
        with tempfile.TemporaryDirectory(prefix='jttms10-legacy-payload-') as temporary:
            build = Path(temporary)
            shutil.copy2(self.BUILD / 'v2-generated-payloads.json', build)
            for name in original['payloads']:
                for relative in (name, f'jttms10-generated/{name}',
                                 f'ip/jttms10_fpga_runner/{name}'):
                    target = build / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(self.BUILD / relative, target)
            target = build / 'jttms10-generated/tms10.uc'
            target.write_bytes(target.read_bytes() + b'\nmutation\n')
            with self.assertRaisesRegex(ValueError, 'payload copy mismatch'):
                legacy.validate_generated_payload_manifest(build, verify_generation=False)

    def test_writer_creates_receipt_from_saved_image_without_mutating_build(self):
        with tempfile.TemporaryDirectory(prefix='jttms10-seed-receipt-') as temporary:
            output = Path(temporary) / 'receipt.json'
            command = [
                sys.executable, str(HERE / 'write_programming_receipt.py'),
                '--image', str(self.BUILD / 'output_files/test_board.rbf'),
                '--build-dir', str(self.BUILD),
                '--source-root', self.inputs['source_root'],
                '--boot-id', '9f611c5b-2284-4ae0-91f0-8af7510b7a44',
                '--overlay', 'saved-seed-recovery-test', '--output', str(output),
            ]
            result = subprocess.run(command, text=True, capture_output=True, check=False)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            receipt = json.loads(output.read_text())
            self.assertEqual(receipt['image_sha256'], self.result['rbf_sha256'])
            self.assertEqual(receipt['compile_input_snapshot_recovery']['format'],
                             'jttms10-known-compile-input-path-shadow-recovery-v1')

    def test_rejects_any_mutated_loaded_snapshot_or_partial_inventory(self):
        altered = dict(self.compile_inputs)
        altered['map_manifest_sha256'] = '0' * 64
        with self.assertRaisesRegex(SystemExit, 'differs from its on-disk certificate'):
            self.validate(compile_inputs=altered)

        altered = dict(self.compile_inputs)
        altered['files'] = dict(altered['files'])
        altered['files'].pop(next(iter(altered['files'])))
        with self.assertRaisesRegex(SystemExit, 'differs from its on-disk certificate'):
            self.validate(compile_inputs=altered)

        altered = dict(self.inputs)
        altered['non_compile_generated_outputs'] = dict(altered['non_compile_generated_outputs'])
        altered['non_compile_generated_outputs']['jttms10-generated/dispatch-model/Vtest.mk'] = '0' * 64
        with self.assertRaisesRegex(SystemExit, 'differs from its on-disk certificate'):
            self.validate(inputs=altered)

        altered = dict(self.inputs)
        altered['source_hashes'] = dict(altered['source_hashes'])
        key = next(iter(altered['source_hashes']))
        altered['source_hashes'][key] = '0' * 64
        with self.assertRaisesRegex(SystemExit, 'differs from its on-disk certificate'):
            self.validate(inputs=altered)

    def test_rehash_rejects_changed_frozen_source_and_diagnostic(self):
        original_sha256 = receipts.sha256
        source_path = Path(next(iter(self.inputs['source_hashes'])))

        def source_mutation(path):
            return '0' * 64 if Path(path) == source_path else original_sha256(path)

        with patch.object(receipts, 'sha256', side_effect=source_mutation):
            with self.assertRaisesRegex(SystemExit, 'legacy seed frozen source changed'):
                self.validate()

        diagnostic_rel = next(iter(self.inputs['non_compile_generated_outputs']))
        diagnostic_path = self.BUILD / diagnostic_rel

        def diagnostic_mutation(path):
            return '0' * 64 if Path(path) == diagnostic_path else original_sha256(path)

        with patch.object(receipts, 'sha256', side_effect=diagnostic_mutation):
            with self.assertRaisesRegex(SystemExit, 'legacy seed generated diagnostic changed'):
                self.validate()

    def test_invalid_or_missing_partition_validation_cannot_use_recovery(self):
        with patch('partition_build.validate_partition_result',
                   side_effect=ValueError('mutated stage certificate')):
            with self.assertRaisesRegex(SystemExit, 'explicit CPU partition certificate is invalid'):
                self.validate()

        with tempfile.TemporaryDirectory(prefix='jttms10-missing-partition-cert-') as temporary:
            empty_build = Path(temporary)
            (empty_build / 'v2-build-result.json').write_text(
                json.dumps(self.result))
            with self.assertRaisesRegex(SystemExit, 'explicit CPU partition certificate is invalid'):
                self.validate(build=empty_build)


if __name__ == '__main__':
    unittest.main()
