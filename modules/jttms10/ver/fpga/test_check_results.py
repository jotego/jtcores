#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Protocol negatives: corrupted captures must not become passing fixtures."""
import copy
import unittest

import check_results as checker


class ResultChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.oracle = checker.oracle_module()

    def packet(self, cache_disabled=False):
        name = 'nop_off' if cache_disabled else 'nop_hit'
        case = copy.deepcopy(next(x for x in self.oracle.cases() if x['name'] == name))
        words, test_pc, next_pc = self.oracle.program(case)
        case.update(test_pc=test_pc, next_pc=next_pc)
        entry = dict(id=81, name=name, fixture=case, program_words=words,
                     test_pc=test_pc, next_pc=next_pc)
        batch = checker.make_batches([entry])[0]
        result = [81, 2, case['states'] * 8, test_pc, next_pc, 0x0300, case['expected_st'], 64]
        result.extend(0xdead0000 + q for q in range(64))
        result[8:12] = case['expected_regs']
        events = []
        if cache_disabled:
            events = [[72, 0x0300, next_pc, 1 | (1 << 6) | (1 << 8)],
                      [76, 0x0300, next_pc, 1 | (1 << 7)],
                      [88, 0x0300, next_pc, 1 | (1 << 5)]]
        capture = dict(status=2, event_count=len(events), results=[result], events=events)
        return batch, capture

    def test_warm_and_cache_disabled_controls(self):
        for cd in (False, True):
            batch, capture = self.packet(cd)
            self.assertEqual(checker.check_batch(batch, capture)['failed'], 0)

    def test_wrong_register_status_and_instruction_time(self):
        for word in (2, 6, 8):
            batch, capture = self.packet()
            capture['results'][0][word] ^= 1
            self.assertEqual(checker.check_batch(batch, capture)['failed'], 1)

    def test_case_id_order_and_count(self):
        batch, capture = self.packet()
        capture['results'][0][0] += 1
        self.assertEqual(checker.check_batch(batch, capture)['failed'], 1)
        capture['results'] = []
        with self.assertRaisesRegex(ValueError, 'result count'):
            checker.check_batch(batch, capture)

    def test_case_failure_does_not_pass_on_batch_success(self):
        batch, capture = self.packet()
        capture['results'][0][1] = 0x80000002
        self.assertEqual(checker.check_batch(batch, capture)['failed'], 1)

    def test_timeout_batch_error_and_overflow(self):
        batch, capture = self.packet()
        capture['status'] = 0x80000002
        with self.assertRaisesRegex(ValueError, 'did not succeed'):
            checker.check_batch(batch, capture)
        capture['status'] = 2
        capture['event_count'] = 0x80000000
        with self.assertRaisesRegex(ValueError, 'overflow'):
            checker.check_batch(batch, capture)

    def test_uninitialized_register_and_wrong_next_opcode(self):
        for word, value in ((8, 0xdead0000), (5, 0x1800)):
            batch, capture = self.packet()
            capture['results'][0][word] = value
            self.assertEqual(checker.check_batch(batch, capture)['failed'], 1)

    def test_wrong_bus_address_response_and_duration(self):
        for record, word in ((0, 2), (1, 1), (2, 0)):
            batch, capture = self.packet(True)
            capture['events'][record][word] += 1
            self.assertEqual(checker.check_batch(batch, capture)['failed'], 1)

    def test_missing_bus_event_is_rejected(self):
        batch, capture = self.packet(True)
        capture['events'].pop()
        capture['event_count'] -= 1
        self.assertEqual(checker.check_batch(batch, capture)['failed'], 1)

    def test_malformed_event_case_reserved_bits_and_order(self):
        for mutation in ('case', 'reserved', 'order'):
            batch, capture = self.packet(True)
            if mutation == 'case':
                capture['events'][0][3] |= 1 << 9
            elif mutation == 'reserved':
                capture['events'][0][3] |= 1 << 14
            else:
                capture['events'].reverse()
            with self.assertRaises(ValueError):
                checker.check_batch(batch, capture)

    def test_unsupported_memory_contract_is_not_silently_dropped(self):
        batch, capture = self.packet()
        batch['cases'][0]['fixture']['initial_memory'] = [[0x4000, 0]]
        with self.assertRaisesRegex(ValueError, 'unsupported FPGA'):
            checker.check_batch(batch, capture)

    def test_new_fixture_requirements_are_not_silently_dropped(self):
        for requirement in ('expected_follow_regs', 'interrupt_schedule',
                            'future_observation'):
            batch, capture = self.packet()
            batch['cases'][0]['fixture'][requirement] = []
            with self.assertRaisesRegex(ValueError, requirement):
                checker.check_batch(batch, capture)

    def test_program_and_count_bounds_split_batches(self):
        batch, _ = self.packet()
        entry = batch['cases'][0]
        entries = []
        for identifier in range(33):
            item = copy.deepcopy(entry)
            item['id'] = identifier
            entries.append(item)
        self.assertEqual([len(x['cases']) for x in checker.make_batches(entries)], [32, 1])
        for item in entries:
            item['program_words'] = [0x0300] * 3000
        self.assertEqual(len(checker.make_batches(entries)), 33)

    def test_duplicate_ids_and_invalid_program_words(self):
        batch, _ = self.packet()
        entry = batch['cases'][0]
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            checker.make_batches([entry, copy.deepcopy(entry)])
        entry['program_words'][0] = 0x10000
        with self.assertRaises(ValueError):
            checker.make_batches([entry])

    def test_reference_comparison_checks_state_clocks_and_events(self):
        batch, capture = self.packet(True)
        rows = checker.check_batch(batch, capture)['cases']
        self.assertEqual(checker.compare_reference(rows, copy.deepcopy(rows)), [])
        for field in ('clocks', 'a0'):
            other = copy.deepcopy(rows)
            other[0]['observed'][field] += 1
            self.assertTrue(checker.compare_reference(rows, other))
        other = copy.deepcopy(rows)
        other[0]['bus_trace'].pop()
        self.assertTrue(checker.compare_reference(rows, other))


if __name__ == '__main__':
    unittest.main()
