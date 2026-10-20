#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Exercise build evidence/rejection paths without running or faking Quartus."""
import copy
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

import write_programming_receipt as receipts

HERE = Path(__file__).resolve().parent
SCRIPT = HERE/'build-runner-incremental.sh'
REPO = HERE.parents[3]


class RapidBuildHelper(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.parent = Path(self.temp.name)/'parent'
        self.build = Path(self.temp.name)/'candidate'
        for root in (self.parent, self.build):
            (root/'output_files').mkdir(parents=True)
        (self.parent/'db').mkdir()
        (self.parent/'db/retained').write_bytes(b'retained database fixture')
        self.sta = "Type : Slow Model Setup 'clock'\nSlack : 0.500\nTNS : 0.000\n"
        (self.parent/'output_files/test_board.sta.summary').write_text(self.sta)
        (self.parent/'output_files/test_board.rbf').write_bytes(b'parent image fixture')
        self.parent_input = self.parent/'input.v'
        self.parent_input.write_text('parent HDL fixture\n')
        self.manifest(self.parent, [self.parent_input])
        result = dict(format='jttms10-incremental-build-result-v1', full_flow_only=True,
            flow_exit_code=0, inputs_unchanged=True,
            input_manifest_sha256=receipts.sha256(self.parent/'v2-build-inputs.json'),
            compile_inputs_sha256=receipts.sha256(self.parent/'v2-compile-inputs.json'),
            rbf_sha256=receipts.sha256(self.parent/'output_files/test_board.rbf'))
        (self.parent/'v2-build-result.json').write_text(json.dumps(result))

    def manifest(self, root, paths):
        hashes = {str(p): receipts.sha256(p) for p in paths}
        (root/'v2-build-inputs.json').write_text(json.dumps(dict(files=hashes)))
        (root/'v2-compile-inputs.json').write_text(json.dumps(dict(files=hashes,
            map_manifest_sha256=receipts.sha256(root/'v2-build-inputs.json'),
            pre_map_metadata_deltas=[])))

    def shell(self, commands, success=True):
        result = subprocess.run(['bash', '-euc', 'source "$1"\n'
            'source_dir=$2\nbase_dir=$3\nbuild_dir=$4\nrepo_root=$5\n'+commands,
            'test', str(SCRIPT), str(HERE), str(self.parent), str(self.build), str(REPO)],
            capture_output=True, text=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout+result.stderr)
        return result

    def snapshot(self):
        row = json.loads(self.shell('snapshot_rapid_parent\nprintf "%s\\n" "$rapid_parent_json"').stdout)
        (self.build/'v2-rapid-parent.json').write_text(json.dumps(row))
        return row

    def candidate(self):
        self.snapshot()
        self.input = self.build/'input.v'
        self.input.write_text('changed HDL fixture\n')
        self.manifest(self.build, [self.input, self.build/'v2-rapid-parent.json'])
        os.utime(self.build/'v2-compile-inputs.json', ns=(1, 1))
        (self.build/'output_files/test_board.rbf').write_bytes(b'new image fixture')
        (self.build/'output_files/test_board.sta.summary').write_text(self.sta)
        for stage in ('map', 'fit', 'asm', 'sta'):
            (self.build/f'output_files/test_board.{stage}.rpt').write_text(stage+' fixture\n')
        (self.build/'logs').mkdir()
        (self.build/'logs/v2-compile.log').write_text(
            'Quartus Prime Rapid Recompile was successful\nElapsed time: 00:02:03\n')
        self.timing = dict(command=['/opt/quartus_free/quartus_sh','--flow','recompile','test_board'],
            cwd=str(self.build), exit_code=0, start_monotonic_ns=100, end_monotonic_ns=123000000100,
            seconds=123)
        self.write_timing()
        (self.build/'v2-rapid-command.json').write_text(json.dumps(
            {k:self.timing[k] for k in ('command', 'cwd', 'start_monotonic_ns')}))

    def write_timing(self):
        (self.build/'v2-rapid-time.json').write_text(json.dumps(self.timing))

    def test_parent_snapshot_binds_image_inputs_result_and_sta(self):
        row = self.snapshot()
        self.assertEqual(row['parent_build_dir'], str(self.parent))
        for key, name in (('parent_build_result_sha256', 'v2-build-result.json'),
                          ('parent_inputs_sha256', 'v2-build-inputs.json'),
                          ('parent_image_sha256', 'output_files/test_board.rbf'),
                          ('parent_sta_summary_sha256', 'output_files/test_board.sta.summary')):
            self.assertEqual(row[key], receipts.sha256(self.parent/name))

    def test_changed_parent_input_rejected_before_clone(self):
        self.parent_input.write_text('changed after parent compile\n')
        result = self.shell('snapshot_rapid_parent', success=False)
        self.assertIn('parent compile input is missing or changed', result.stderr)

    def test_unproven_parent_image_rejected(self):
        (self.parent/'output_files/test_board.rbf').write_bytes(b'wrong image')
        self.assertIn('does not certify', self.shell('snapshot_rapid_parent', success=False).stderr)

    def test_missing_database_and_negative_sta_rejected(self):
        db = self.parent/'db/retained'
        db.unlink()
        self.assertIn('retained Quartus database', self.shell('snapshot_rapid_parent', success=False).stderr)
        db.write_text('restored fixture')
        (self.parent/'output_files/test_board.sta.summary').write_text(self.sta.replace('0.500','-0.100'))
        self.assertIn('positive final STA', self.shell('snapshot_rapid_parent', success=False).stderr)

    def test_candidate_cannot_be_inside_parent(self):
        self.build = self.parent/'nested'
        self.assertIn('outside its immutable parent', self.shell('validate_paths', success=False).stderr)

    def test_successful_certificate_passes_independent_receipt_validator(self):
        self.candidate()
        self.shell('write_rapid_result')
        result = json.loads((self.build/'v2-build-result.json').read_text())
        receipts.validate_rapid_result(self.build, result)
        self.assertEqual(result['flow_kind'], 'recompile')
        self.assertIs(result['full_flow_only'], False)
        self.assertEqual(result['flow_seconds'], 123)
        self.assertEqual(result['flow_log_elapsed_seconds'], 123)

    def test_stale_image_and_reports_rejected_without_certificate(self):
        self.candidate()
        for name in ('test_board.rbf', 'test_board.map.rpt', 'test_board.fit.rpt',
                     'test_board.asm.rpt', 'test_board.sta.rpt', 'test_board.sta.summary'):
            path = self.build/'output_files'/name
            old = path.stat()
            os.utime(path, ns=(1, 1))
            with self.subTest(name=name):
                self.shell('write_rapid_result', success=False)
                self.assertFalse((self.build/'v2-build-result.json').exists())
            os.utime(path, ns=(old.st_atime_ns, old.st_mtime_ns))

    def test_failed_or_wrong_command_rejected_without_certificate(self):
        self.candidate()
        original = copy.deepcopy(self.timing)
        for field, value in (('exit_code', 1), ('command', ['quartus_sh','--flow','compile']),
                             ('cwd', str(self.parent)), ('seconds', 0), ('seconds', 5),
                             ('end_monotonic_ns', 99)):
            with self.subTest(field=field):
                self.timing = dict(original, **{field: value})
                self.write_timing()
                self.shell('write_rapid_result', success=False)
                self.assertFalse((self.build/'v2-build-result.json').exists())

    def test_changed_candidate_and_parent_rejected_without_certificate(self):
        self.candidate()
        self.input.write_text('mutated during compile\n')
        self.assertIn('input changed during Rapid', self.shell('write_rapid_result', success=False).stderr)
        self.input.write_text('changed HDL fixture\n')
        (self.parent/'output_files/test_board.rbf').write_bytes(b'parent changed during compile')
        self.assertIn('parent evidence is missing or changed', self.shell('write_rapid_result', success=False).stderr)
        self.assertFalse((self.build/'v2-build-result.json').exists())

    def test_absent_success_marker_and_negative_sta_rejected(self):
        self.candidate()
        log = self.build/'logs/v2-compile.log'
        log.write_text('Compilation failed\n')
        self.assertIn('successful flow log', self.shell('write_rapid_result', success=False).stderr)
        log.write_text('Quartus Prime Rapid Recompile was successful\n')
        (self.build/'output_files/test_board.sta.summary').write_text(self.sta.replace('0.500','-0.100'))
        self.assertIn('positive final STA', self.shell('write_rapid_result', success=False).stderr)

    def test_clone_preserves_parent_and_rebinds_both_runner_sources(self):
        package = self.parent/'ip/jttms10_fpga_runner'
        package.mkdir(parents=True)
        for path in (REPO/'modules/jttms10/hdl').glob('*.v'):
            (package/path.name).write_text('inherited HDL fixture\n')
        (package/'jttms10_fpga_runner.v').write_text('inherited runner fixture\n')
        (self.parent/'test_board.qsf').write_text(
            f'set_global_assignment -name SEARCH_PATH {self.parent}\n'
            'set_global_assignment -name QSYS_FILE QSYS_test_board.qsys\n')
        before = receipts.file_set(self.parent.rglob('*'))
        # Use a fresh destination, as the public rapid entrypoint requires.
        self.build = Path(self.temp.name)/'clone'
        self.shell('prepare_build')
        self.assertEqual(before, receipts.file_set(self.parent.rglob('*')))
        qsf = (self.build/'test_board.qsf').read_text()
        self.assertNotIn(str(self.parent), qsf)
        self.assertIn('QIP_FILE QSYS_test_board/synthesis/QSYS_test_board.qip', qsf)
        self.assertFalse((self.build/'v2-build-result.json').exists())
        self.assertFalse((self.build/'v2-compile-inputs.json').exists())
        for name in ('jttms10_fpga_runner.v', 'jttms10_fpga_stimulus.v'):
            self.assertEqual((self.build/'ip/jttms10_fpga_runner'/name).read_bytes(), (HERE/name).read_bytes())
            self.assertEqual(qsf.count('VERILOG_FILE '+str(self.build/'ip/jttms10_fpga_runner'/name)), 1)
        self.shell('remove_stale_compile_outputs')
        self.assertFalse((self.build/'output_files/test_board.rbf').exists())
        self.assertTrue((self.parent/'output_files/test_board.rbf').is_file())


if __name__ == '__main__':
    unittest.main()
