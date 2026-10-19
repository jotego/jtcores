#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Keep stale CPU images out of runs without binding fixture expectations."""
import json
from pathlib import Path
import shutil
import tempfile
import unittest

import run_batch
import write_programming_receipt as receipts


class SourceBoundReceipts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'source'
        self.inputs = (
            'modules/jttms10/hdl/cpu.v',
            'modules/jttms10/hdl/dispatch.hex',
            'modules/jttms10/ucode/tms10.yaml',
            'modules/jttms10/ver/decoder/generate.py',
            'modules/jttms10/ver/decoder/dump.sv',
            'modules/jttms10/ver/gfx/generate.py',
            'modules/jttms10/ver/build.sh',
            'modules/jttms10/ver/verilator_build.py',
            'modules/jtframe/src/jtframe/ucode/ucode.go',
            'modules/jtframe/src/jtframe/ucode/template.vh',
            'modules/jtframe/bin/jtframe',
        )
        for name in self.inputs:
            self.write(name, name + '\n')
        self.write('modules/jttms10/ver/fpga/jttms10_fpga_runner.v', 'runner\n')
        self.image = Path(self.temp.name) / 'baseline.rbf'
        self.image.write_bytes(b'compiled-image')
        sources = receipts.cpu_source_fingerprints(self.root)
        self.receipt = {
            'format': 'jttms10-fpga-programming-receipt-v1',
            'cpu_source_fingerprints': sources,
            'cpu_source_fingerprint_sha256': receipts.cpu_source_fingerprint_digest(sources),
            'runner_source_sha256': receipts.sha256(
                self.root / 'modules/jttms10/ver/fpga/jttms10_fpga_runner.v'),
            'image_path': str(self.image),
            'image_sha256': receipts.sha256(self.image),
            'sysid': 22,
            'sysid_timestamp': 123,
            'board_boot_id': '9f611c5b-2284-4ae0-91f0-8af7510b7a44',
            'overlay': 'test-baseline',
        }
        self.receipt_path = Path(self.temp.name) / 'receipt.json'

    def write(self, name, content):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def validate(self, hardware=None, parent=None):
        self.receipt_path.write_text(json.dumps(self.receipt))
        return run_batch.load_and_validate_receipt(
            self.receipt_path, self.root, hardware or self.root, parent)

    def test_cpu_and_generation_inputs_are_bound(self):
        before = receipts.cpu_source_fingerprints(self.root)
        self.assertEqual(set(before), set(self.inputs))
        for name in self.inputs:
            with self.subTest(input=name):
                path = self.root / name
                original = path.read_bytes()
                path.write_bytes(original + b'changed\n')
                with self.assertRaisesRegex(SystemExit, 'oracle/source checkout differs'):
                    self.validate()
                path.write_bytes(original)

    def test_fixture_and_expected_result_changes_need_no_new_image(self):
        self.write('modules/jttms10/ver/timing/run.py', 'new oracle\n')
        self.write('modules/jttms10/ver/timing/fixtures.yaml', 'new program\n')
        self.write('modules/jttms10/ver/gfx/__pycache__/generate.pyc', 'cache\n')
        self.validate()

    def test_checkout_relocation_and_fingerprint_order(self):
        other = Path(self.temp.name) / 'relocated'
        shutil.copytree(self.root, other)
        _, expected, actual = self.validate(hardware=other)
        self.assertEqual(actual, expected)
        self.assertEqual(receipts.cpu_source_fingerprint_digest(expected),
                         receipts.cpu_source_fingerprint_digest(dict(reversed(list(actual.items())))))

    def test_different_hardware_source_is_rejected(self):
        other = Path(self.temp.name) / 'variant'
        shutil.copytree(self.root, other)
        (other / 'modules/jttms10/ucode/tms10.yaml').write_text('mutant\n')
        with self.assertRaisesRegex(SystemExit, 'CPU implementation checkout differs'):
            self.validate(hardware=other)

    def test_image_and_runner_drift_are_rejected(self):
        self.image.write_bytes(b'other-image')
        with self.assertRaisesRegex(SystemExit, 'baseline image file differs'):
            self.validate()
        self.image.write_bytes(b'compiled-image')
        self.write('modules/jttms10/ver/fpga/jttms10_fpga_runner.v', 'changed runner\n')
        with self.assertRaisesRegex(SystemExit, 'runner RTL checkout differs'):
            self.validate()

    def test_old_receipt_and_variant_without_parent_fail_closed(self):
        saved = self.receipt.pop('cpu_source_fingerprints')
        with self.assertRaisesRegex(SystemExit, 'lacks CPU source fingerprints'):
            self.validate()
        self.receipt['cpu_source_fingerprints'] = saved
        self.receipt['format'] = 'jttms10-fpga-rom-update-receipt-v1'
        with self.assertRaisesRegex(SystemExit, 'requires --parent-receipt'):
            self.validate()

    def test_digest_corruption_is_rejected(self):
        self.receipt['cpu_source_fingerprint_sha256'] = '0' * 64
        with self.assertRaisesRegex(SystemExit, 'fingerprint digest is invalid'):
            self.validate()

    def test_mif_requires_complete_unique_fixed_width_words(self):
        mif = Path(self.temp.name) / 'rom.mif'
        header = 'WIDTH=3;\nDEPTH=2;\nADDRESS_RADIX=UNS;\nDATA_RADIX=BIN;\nCONTENT BEGIN\n'
        mif.write_text(header + '0 : 001;\n1 : 110;\nEND;\n')
        self.assertEqual(receipts.parse_mif(mif), (3, ['001', '110']))
        for rows in ('0 : 001;', '0 : 001;\n0 : 110;',
                     '0 : 001;\n1 : 11;', '0 : 001;\n2 : 110;'):
            with self.subTest(rows=rows):
                mif.write_text(header + rows + '\nEND;\n')
                with self.assertRaises(SystemExit):
                    receipts.parse_mif(mif)


if __name__ == '__main__':
    unittest.main()
