#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Guard against making the checker accept correct results at wrong times."""
import unittest

from oracle import multiply_states
from run import cases, check, check_bus, split_transcripts
from scalar_cases import shift_result, TI_SLA_EXAMPLES


class TimingCheckerTest(unittest.TestCase):
    def setUp(self):
        self.case = next(c for c in cases() if c['name'] == 'mpys_fs2_positive_even_hit')
        self.observed = dict(clocks=48, start=100, end=148, paused=0, st=self.case['expected_st'],
                             **{f'a{n}': v for n, v in enumerate(self.case['expected_regs'])})

    def test_correct_math_wrong_time_fails(self):
        self.assertEqual(check(self.case, self.observed), [])
        self.observed['clocks'] = 168  # Incorrect full-width latency at FS1=2.
        self.assertTrue(any('expected 48 INCLK' in e for e in check(self.case, self.observed)))

    def test_source_field_sign_not_register_sign(self):
        # p.12-167: 5+8/2 versus 6+8/2, plus three states with CD.
        self.assertEqual(multiply_states(signed=False, fs1=8, source=0xFFFFFF01), 9)
        self.assertEqual(multiply_states(signed=False, fs1=8, source=0x00000081), 10)
        self.assertEqual(multiply_states(signed=False, fs1=8, source=0x81,
                                         cache_disabled=True), 13)

    def test_undefined_fields_rejected(self):
        for fs in (-2, 1, 3, 31, 34):
            with self.subTest(fs=fs), self.assertRaises(ValueError):
                multiply_states(signed=True, fs1=fs, source=1)
        self.assertEqual(multiply_states(signed=True, fs1=0, source=1), 21)

    def test_external_wait_cannot_be_ignored(self):
        case = dict(self.case, cache_disabled=True, states=9, next_pc=0x1230)
        self.observed['clocks'] = 72
        self.assertEqual(check(case, self.observed), [])
        self.assertTrue(check(case, self.observed, wait_states=1))
        self.observed['clocks'] = 80
        self.assertEqual(check(case, self.observed, wait_states=1), [])

    def test_bus_contract_is_independent_of_total(self):
        case = dict(self.case, cache_disabled=True, states=9, next_pc=0x1230)
        lines = ['BUS_BEGIN 148 0 00001230 0000 1', 'BUS_END 172 0 00001230 0300']
        self.assertEqual(check_bus(case, self.observed, lines, 1), [])
        # An ACK a state early must fail even if someone pads retirement.
        lines[1] = 'BUS_END 164 0 00001230 0300'
        self.assertTrue(check_bus(case, self.observed, lines, 1))
        # Likewise a cold-cache fill cannot be classified as a warm hit.
        self.assertTrue(check_bus(self.case, self.observed, lines, 0))

    def test_bus_start_cannot_be_hidden_by_total_padding(self):
        case = dict(self.case, cache_disabled=True, states=9, next_pc=0x1230)
        lines = ['BUS_BEGIN 100 0 00001230 0000 1', 'BUS_END 124 0 00001230 0300']
        self.assertTrue(any('read start' in e for e in check_bus(case, self.observed, lines, 1)))

    def test_functional_assertions_remain_active(self):
        self.observed['a0'] ^= 1
        self.assertTrue(any('A0:' in e for e in check(self.case, self.observed)))

    def test_paused_clocks_cannot_be_absorbed_by_instruction_padding(self):
        self.observed.update(paused=7, clocks=55)
        self.assertEqual(check(self.case, self.observed, pause_clocks=7), [])
        self.observed['clocks'] = 48
        self.assertTrue(check(self.case, self.observed, pause_clocks=7))

    def test_batch_case_association(self):
        log='CASE 0\nRESULT case=0\nCASE 1\nRESULT case=1\nBATCH_DONE cases=2\n'
        chunks=split_transcripts(log,[0,1],batch=True)
        self.assertIn('RESULT case=0',chunks[0])
        self.assertNotIn('RESULT case=1',chunks[0])
        for bad in (log.replace('CASE 1','CASE 0'), log.replace('CASE 1','CASE 2')):
            with self.subTest(log=bad), self.assertRaises(ValueError):
                split_transcripts(bad,[0,1],batch=True)

    def test_batch_must_finish_every_case(self):
        for log in ('CASE 0\n', 'CASE 0\nBATCH_DONE cases=0\n',
                    'CASE 0\nBATCH_DONE cases=1\nBATCH_DONE cases=1\n'):
            with self.subTest(log=log), self.assertRaises(ValueError):
                split_transcripts(log,[0],batch=True)

    def test_ti_sla_example_vectors(self):
        # SPVU001A p.12-239: complete result and NCZV examples.
        for value,count,result,flags in TI_SLA_EXAMPLES:
            with self.subTest(value=value,count=count):
                actual,status=shift_result('SLA',value,count,0xF0000810)
                self.assertEqual((actual,status),(result,(flags<<28)|0x810))


if __name__ == '__main__':
    unittest.main()
