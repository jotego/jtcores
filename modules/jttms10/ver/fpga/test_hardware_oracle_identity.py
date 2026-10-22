#!/usr/bin/env python3
"""Host-only tests for separate FPGA implementation and oracle identities."""
import json
import os
from pathlib import Path
import shutil
import sys
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import run_batch
import write_programming_receipt as receipts

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


if __name__ == '__main__':
    unittest.main()
