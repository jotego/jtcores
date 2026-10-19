#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Pin agreeing TI targets and keep stimulus/architectural checks independent."""
from collections import Counter
import copy
from pathlib import Path
import sys
import unittest

from run import cases, check, program, published_duration_case
from store_cases import fixture


class PublishedTargets(unittest.TestCase):
    def test_absolute_literal_counts_and_wrong_duration(self):
        for off, states in ((False, 1), (True, 7)):
            original = fixture('absolute', 8, 0, 0, off, 0, byte=True)
            row = published_duration_case(original)
            self.assertEqual(row['states'], states)  # SPVU001A12-117/13-6.
            observed = dict(clocks=original['states']*8, paused=0,
                            st=original['expected_st'], **original['expected_extra_regs'])
            observed.update({f'a{q}': value for q,value in enumerate(original['expected_regs'])})
            self.assertEqual(len(check(row, observed)), 1)
            observed['clocks'] = states*8
            self.assertEqual(check(row, observed), [])
            observed['a0'] ^= 1
            self.assertTrue(any('result mismatch' in error for error in check(row, observed)))

    def test_inventory_and_program_contracts(self):
        counts = Counter()
        for original in cases():
            frozen = copy.deepcopy(original)
            row = published_duration_case(original)
            self.assertEqual(original, frozen)
            if row is None:
                continue
            counts[original['coverage_id'], original['cache_disabled']] += 1
            self.assertEqual(program(copy.deepcopy(original)), program(copy.deepcopy(row)))
            for key in ('expected_regs','expected_st','expected_extra_regs','initial_memory',
                        'expected_memory','data_store','data_copy','expected_follow_regs'):
                self.assertEqual(row.get(key), original.get(key))
        self.assertEqual(counts, {('MOVB_R_ABS',False):18, ('MOVB_R_ABS',True):9,
                                  ('MOVB_IND_IND',True):18})

    def test_conflicting_or_inapplicable_entries_stay_unselected(self):
        row = fixture('absolute', 8, 9, 0, False, 0, byte=True)
        self.assertIsNone(published_duration_case(row))
        row = fixture('offset', 8, 0, 0, True, 0, byte=True)
        self.assertIsNone(published_duration_case(row))
        row = fixture('absolute', 8, 0, 0, False, 0, byte=True)
        row['states'] += 1
        with self.assertRaisesRegex(ValueError, 'unhandled'):
            published_duration_case(row)

    def test_fpga_preparation_reuses_same_target(self):
        sys.path.insert(0, str(Path(__file__).resolve().parent.parent/'fpga'))
        import check_results
        entries = check_results.prepare_cases(['storemode_movb_absolute_byte_o0_ignored001_r0_hit'],
                                              protocol_version=3, published_targets=True)
        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0]['fixture']['states'], 1)
        self.assertTrue(entries[0]['name'].endswith('_published_duration'))


if __name__ == '__main__':
    unittest.main()
