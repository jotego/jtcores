#!/usr/bin/env python3
"""Offline orchestration contracts; no public chip execution or endpoints."""
import csv
import importlib.util
import pathlib
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('runner', pathlib.Path(__file__).with_name('run-models.py'))
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)


def submission(start, end, reply):
    return {'api_calls': [{'kind': 'ROM_API_write', 'offset': 8192, 'length': 2,
                           'host_start': start, 'host_end': end}], 'host_end': reply}


class Contracts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def write(self, name, data):
        p = self.root/name
        p.write_bytes(data)
        return str(p)

    def test_bytecode_literal(self):
        p = self.write('p.bin', bytes([1, 8, 64, 2, 0, 32, 3, 0]))
        result = r.program(p)
        self.assertEqual(result['writes'], [[8, 64]])
        self.assertEqual(result['delay_counts'], 8192)

    def test_bytecode_invalid(self):
        for i, data in enumerate((b'', b'\1', b'\4\0', b'\0\0', b'\2\0', b'\3', b'\0'*8193)):
            with self.subTest(i=i), self.assertRaises(ValueError):
                r.program(self.write(str(i), data))

    def test_host_midpoint_not_reply_interval(self):
        result = r.gap(submission(1, 1.01, 2), submission(3, 3.2, 4))
        self.assertEqual(result['gap_master_clocks'], round(1.1*r.HZ))
        self.assertEqual(result['host_endpoint_interval_seconds'], [1, 1.2000000000000002])
        self.assertEqual(r.gap(None, submission(3, 3.2, 4))['gap_master_clocks'], 0)

    def test_commit_rejects_duplicates_and_overlap(self):
        s = submission(3, 3.2, 4)
        s['api_calls'] *= 2
        with self.assertRaises(ValueError):
            r.commit(s)
        with self.assertRaises(ValueError):
            r.gap(submission(1, 2, 4), submission(3, 3.2, 5))

    def test_exclusive_json(self):
        p = self.root/'file.json'
        r.save(p, {'n': 1})
        with self.assertRaises(FileExistsError):
            r.save(p, {'n': 2})

    def test_mock_process_exit_retained(self):
        result = r.process([sys.executable, '-c', 'print("fixture");raise SystemExit(7)'], self.root/'process', 5)
        self.assertEqual(result['exitcode'], 7)
        self.assertFalse(result['timeout'])
        self.assertEqual((self.root/'process.stdout').read_text(), 'fixture\n')

    def test_mock_process_timeout(self):
        result = r.process([sys.executable, '-c', 'import time;time.sleep(2)'], self.root/'timeout', .02)
        self.assertTrue(result['timeout'])
        self.assertEqual(result['exitcode'], 124)

    def test_execution_requires_ROOT_binding_before_output(self):
        p, b = self.root/'plan.json', self.root/'binding.json'
        r.save(p, {'jobs': [], 'output': str(self.root/'output')})
        r.save(b, {})
        with self.assertRaises(ValueError):
            r.execute(p, b)
        self.assertFalse((self.root/'output').exists())

    def test_public_csv_cadence_rejects_missing_rows(self):
        p = self.root/'samples.csv'
        p.write_text('sample,left,right,clock\n0,0,0,64\n1,0,0,129\n')
        with self.assertRaisesRegex(ValueError, 'cadence'):
            r.audit_model({'CSV': str(p)}, {'case': {'stride': 1}})

    def test_quiet_and_postcapture_EVENT_are_retained(self):
        p = self.root/'samples.csv'
        end = self.write('end.bin', b'\0')
        expected = {**r.program(end), 'timing': {'gap_master_clocks': 0}}
        with p.open('w') as f:
            f.write('sample,left,right,clock\n')
            for i in range(r.FRAMES):
                f.write(f'{i},0,0,{64*(i+1)}\n')
        pathlib.Path(str(p)+'.events.csv').write_text('kind,clock,reg,value\ncapture_start,0,,\nwrite,2000000,8,64\n')
        fields = ['kind','index','path','sha256','write_count','gap_requested_master_clocks',
                  'clock_before','implicit_settle_master_clocks']
        with pathlib.Path(str(p)+'.history.csv').open('w') as f:
            writer = csv.DictWriter(f, fieldnames=fields)
            writer.writeheader()
            for kind in ('history','init','capture_start'):
                writer.writerow(dict(kind=kind,index=0,path=end,sha256=r.sha(end),write_count=0,
                                     gap_requested_master_clocks=0,clock_before=0,implicit_settle_master_clocks=0))
        result = r.audit_model({'CSV':str(p)}, {'case':{'stride':1},'event':{'writes':[[8,64]]},'history_rows':[expected]})
        self.assertTrue(result['raw_valid'])
        self.assertFalse(result['EVENT_last_write_before_last_sample'])
        self.assertEqual(result['ranges']['left'], [0,0])


if __name__ == '__main__':
    unittest.main()
