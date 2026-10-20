#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Keep stale CPU images out of runs without binding fixture expectations."""
import copy
import json
import os
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
        self.write('modules/jttms10/ver/fpga/jttms10_fpga_stimulus.v', 'stimulus\n')
        self.image = Path(self.temp.name) / 'baseline.rbf'
        self.image.write_bytes(b'compiled-image')
        sources = receipts.cpu_source_fingerprints(self.root)
        self.receipt = {
            'format': 'jttms10-fpga-programming-receipt-v1',
            'protocol_version': 5,
            'runner_source_fingerprints': receipts.runner_source_fingerprints(self.root),
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
        with self.assertRaisesRegex(SystemExit, 'runner component checkout differs'):
            self.validate()

    def test_sequencer_and_protocol_are_bound_before_device_access(self):
        self.write('modules/jttms10/ver/fpga/jttms10_fpga_stimulus.v', 'changed stimulus\n')
        with self.assertRaisesRegex(SystemExit, 'runner component checkout differs'):
            self.validate()
        self.write('modules/jttms10/ver/fpga/jttms10_fpga_stimulus.v', 'stimulus\n')
        for old in (1, 2, 3, 4):
            self.receipt['protocol_version'] = old
            with self.assertRaisesRegex(SystemExit, 'protocol 5 programming receipt'):
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


class RapidBuildReceipts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.build = Path(self.temp.name) / 'rapid'
        self.parent = Path(self.temp.name) / 'parent'
        for root in (self.build, self.parent):
            (root / 'output_files').mkdir(parents=True)
        (self.build / 'logs').mkdir()
        self.freeze = self.build / 'v2-compile-inputs.json'
        self.freeze.write_text('{}\n')
        os.utime(self.freeze, ns=(1, 1))
        marker = 'Quartus Prime Rapid Recompile was successful'
        (self.build / 'logs/v2-compile.log').write_text(marker+'\n')
        self.sta_text = "Type : Slow Model Setup 'clock'\nSlack : 0.500\nTNS : 0.000\n"
        for root in (self.build, self.parent):
            (root / 'output_files/test_board.sta.summary').write_text(self.sta_text)
        for stage in ('map', 'fit', 'asm', 'sta'):
            (self.build / f'output_files/test_board.{stage}.rpt').write_text(stage+' report\n')
        (self.parent / 'v2-build-inputs.json').write_text('{"source":"frozen"}\n')
        (self.parent / 'output_files/test_board.rbf').write_bytes(b'parent-image')
        parent_result = dict(format='jttms10-incremental-build-result-v1',
                             full_flow_only=True, flow_exit_code=0, inputs_unchanged=True,
                             input_manifest_sha256=receipts.sha256(self.parent/'v2-build-inputs.json'),
                             rbf_sha256=receipts.sha256(self.parent/'output_files/test_board.rbf'))
        (self.parent / 'v2-build-result.json').write_text(json.dumps(parent_result))
        self.result = dict(format=receipts.RAPID_RESULT_FORMAT, flow_kind='recompile',
            command=['/opt/quartus_free/quartus_sh','--flow','recompile','test_board'],
            working_directory=str(self.build), full_flow_only=False,
            flow_exit_code=0, inputs_unchanged=True, terminal_marker=marker,
            flow_log_sha256=receipts.sha256(self.build/'logs/v2-compile.log'),
            stage_reports={s:receipts.sha256(self.build/f'output_files/test_board.{s}.rpt')
                           for s in ('map','fit','asm','sta')},
            sta_summary_sha256=receipts.sha256(self.build/'output_files/test_board.sta.summary'),
            parent_build_dir=str(self.parent),
            parent_build_result_sha256=receipts.sha256(self.parent/'v2-build-result.json'),
            parent_inputs_sha256=receipts.sha256(self.parent/'v2-build-inputs.json'),
            parent_image_sha256=receipts.sha256(self.parent/'output_files/test_board.rbf'),
            parent_sta_summary_sha256=receipts.sha256(self.parent/'output_files/test_board.sta.summary'))

    def test_successful_actual_recompile(self):
        receipts.validate_rapid_result(self.build, self.result)

    def test_recompile_command_and_kind_are_explicit(self):
        for field, value in (('flow_kind','compile'), ('full_flow_only',True),
                             ('command',['quartus_sh','--flow','recompile','test_board']),
                             ('working_directory',str(self.parent)), ('flow_exit_code',1),
                             ('inputs_unchanged',False)):
            with self.subTest(field=field):
                row = dict(self.result, **{field:value})
                with self.assertRaisesRegex(SystemExit, 'command/flow'):
                    receipts.validate_rapid_result(self.build,row)

    def test_actual_flow_log_and_terminal_are_required(self):
        for changes in ({'flow_log_sha256':'0'*64}, {'terminal_marker':'successful but absent'},
                        {'terminal_marker':''}):
            with self.subTest(changes=changes), self.assertRaisesRegex(SystemExit,'flow log'):
                receipts.validate_rapid_result(self.build,dict(self.result,**changes))

    def test_all_stage_reports_are_required(self):
        for stage in ('map','fit','asm','sta'):
            row=copy.deepcopy(self.result)
            del row['stage_reports'][stage]
            with self.subTest(stage=stage), self.assertRaisesRegex(SystemExit,'must bind'):
                receipts.validate_rapid_result(self.build,row)

    def test_stale_report_and_changed_report_are_rejected(self):
        report=self.build/'output_files/test_board.fit.rpt'
        os.utime(report,ns=(1,1))
        with self.assertRaisesRegex(SystemExit,'stale or changed: fit'):
            receipts.validate_rapid_result(self.build,self.result)
        report.write_text('different fit report\n')
        with self.assertRaisesRegex(SystemExit,'stale or changed: fit'):
            receipts.validate_rapid_result(self.build,self.result)

    def test_negative_final_sta_is_rejected_even_with_correct_hash(self):
        sta=self.build/'output_files/test_board.sta.summary'
        sta.write_text(self.sta_text.replace('0.500','-0.106').replace('0.000','-0.106'))
        self.result['sta_summary_sha256']=receipts.sha256(sta)
        with self.assertRaisesRegex(SystemExit,'positive final STA'):
            receipts.validate_rapid_result(self.build,self.result)

    def test_parent_image_and_result_bindings_are_required(self):
        for field in ('parent_build_result_sha256','parent_inputs_sha256','parent_image_sha256',
                      'parent_sta_summary_sha256'):
            with self.subTest(field=field), self.assertRaisesRegex(SystemExit,'parent evidence'):
                receipts.validate_rapid_result(self.build,dict(self.result,**{field:'0'*64}))
        path=self.parent/'v2-build-result.json'
        row=json.loads(path.read_text());row['rbf_sha256']='0'*64
        path.write_text(json.dumps(row))
        self.result['parent_build_result_sha256']=receipts.sha256(path)
        with self.assertRaisesRegex(SystemExit,'parent result'):
            receipts.validate_rapid_result(self.build,self.result)

    def test_parent_must_exist_and_cannot_be_the_candidate(self):
        for parent, message in ((self.build, 'cannot certify itself'),
                                (self.build/'missing', 'parent is unavailable')):
            with self.subTest(parent=parent), self.assertRaisesRegex(SystemExit,message):
                receipts.validate_rapid_result(self.build,dict(self.result,parent_build_dir=str(parent)))

    def test_empty_or_negative_parent_sta_is_rejected(self):
        sta=self.parent/'output_files/test_board.sta.summary'
        for text in ('', self.sta_text.replace('0.500','-0.100')):
            sta.write_text(text)
            self.result['parent_sta_summary_sha256']=receipts.sha256(sta)
            with self.subTest(text=text), self.assertRaisesRegex(SystemExit,'positive final STA'):
                receipts.validate_rapid_result(self.build,self.result)


if __name__ == '__main__':
    unittest.main()
