#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Host process tests: mocked preflight, real local child, no board access."""
import contextlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import check_results as checker
import run_batch


class TransportStream(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.source = Path(__file__).resolve().parents[4]
        self.entry = checker.prepare_cases(['nop_hit'], limit=1, protocol_version=5)[0]
        self.manifest = self.directory / 'manifest.json'
        self.manifest.write_text(json.dumps(dict(format=checker.FORMAT_V5, protocol_version=5,
            batches=checker.make_batches([self.entry], protocol_version=5))))
        self.receipt_path = self.directory / 'receipt.json'
        self.receipt_path.write_text('{}')
        self.binary = self.directory / 'unused-arm-binary'
        self.binary.write_bytes(b'unit-test-never-executes-this-file')
        self.receipt = dict(overlay='unit', runner_source_sha256=run_batch.sha256(
            self.source / 'modules/jttms10/ver/fpga/jttms10_fpga_runner.v'),
            sysid=22, sysid_timestamp=123, board_boot_id='unit', image_sha256='0' * 64)
        self.output = self.directory / 'runs' / 'test'

    def execute(self, child_code, timeout):
        real_popen = subprocess.Popen
        children = []
        def local_process(command, **kwargs):
            self.assertEqual(command[0], 'ssh')
            child = real_popen([sys.executable, '-u', '-c', child_code], **kwargs)
            children.append(child)
            return child
        def stop_children():
            for child in children:
                if child.poll() is None:
                    child.kill()
                child.wait()
        self.addCleanup(stop_children)
        arguments = ['run_batch.py', str(self.manifest), '--source-root', str(self.source),
                     '--receipt', str(self.receipt_path), '--transport-bin', str(self.binary),
                     '--artifacts', str(self.directory / 'runs'), '--run-name', 'test',
                     '--transport-timeout', str(timeout)]
        preflight = subprocess.CompletedProcess([], 0, stdout='unit preflight\n', stderr='')
        with mock.patch.object(sys, 'argv', arguments), \
                mock.patch.object(run_batch, 'KNOWN_HOSTS', self.receipt_path), \
                mock.patch.object(run_batch, 'load_and_validate_receipt', return_value=(self.receipt, {}, {})), \
                mock.patch.object(run_batch, 'ssh_options', return_value=['unit-host']), \
                mock.patch.object(run_batch.subprocess, 'run', return_value=preflight), \
                mock.patch.object(run_batch.subprocess, 'Popen', side_effect=local_process), \
                contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return run_batch.main()

    def test_timeout_keeps_partial_capture_stderr_and_elapsed_record(self):
        child = 'import sys,time; print("partial capture",flush=True); print("synthetic wait",file=sys.stderr,flush=True); time.sleep(30)'
        with self.assertRaisesRegex(RuntimeError, 'partial stdout and timings were retained'):
            self.execute(child, 0.25)
        self.assertEqual((self.output / 'capture.stdout.partial').read_text(), 'partial capture\n')
        self.assertFalse((self.output / 'capture.json').exists())
        self.assertIn('synthetic wait', (self.output / 'remote_stderr.txt').read_text())
        timings = json.loads((self.output / 'timings.json').read_text())
        self.assertTrue(timings['transport_timed_out'])
        self.assertNotEqual(timings['transport_exit_code'], 0)
        self.assertGreaterEqual(timings['execution_seconds'], 0.25)

    def test_nonzero_process_exit_fails_even_with_complete_passing_capture(self):
        case = self.entry['fixture']
        words = [0] * 292
        words[:8] = [self.entry['id'], 2, case['states'] * 8, self.entry['test_pc'],
                     self.entry['next_pc'], 0x0300, case['expected_st'], 64]
        words[8:12] = case['expected_regs']
        words[274] = 0xf
        capture = dict(protocol_version=5, batches=[dict(protocol_version=5, status=2,
                       event_count=0, results=[words], events=[])])
        child = 'import sys; print(' + repr(json.dumps(capture)) + ',flush=True); sys.exit(7)'
        self.assertEqual(self.execute(child, 5), 1)
        self.assertTrue((self.output / 'capture.json').is_file())
        self.assertFalse((self.output / 'capture.stdout.partial').exists())
        report = json.loads((self.output / 'report.json').read_text())
        self.assertEqual((report['passed'], report['failed']), (1, 0))
        timings = json.loads((self.output / 'timings.json').read_text())
        self.assertEqual(timings['transport_exit_code'], 7)
        self.assertFalse(timings['transport_timed_out'])


if __name__ == '__main__':
    unittest.main()
