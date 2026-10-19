#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Literal LINE table/example anchors, independent of RTL and microcode."""
import unittest
from line_oracle import UnresolvedLineTiming, line_timing, pixel_states


class LineOracleTest(unittest.TestCase):
    def test_printed_119_state_example(self):
        row = line_timing(drawn=23, window=3, ppop=0)
        self.assertEqual((row['states'], row['setup_states'], row['transfer_states']),
                         (119, 4, 115))

    def test_all_unambiguous_processing_columns(self):
        entries = [(0, 2), *[(q, 4) for q in range(1, 17)], (17, 5), (20, 5), (21, 5)]
        for size in (1, 2, 4, 8, 16):
            for ppop, states in entries:
                if ppop >= 16 and size < 4:
                    with self.assertRaises(ValueError):
                        pixel_states(size, ppop)
                else:
                    self.assertEqual(pixel_states(size, ppop), states)

    def test_sub_labels_remain_unresolved(self):
        with self.assertRaises(UnresolvedLineTiming):
            pixel_states(16, 18)
        with self.assertRaises(UnresolvedLineTiming) as error:
            pixel_states(16, 19)
        self.assertEqual(error.exception.alternatives,
                         dict(first_subs_column=5, last_subs_column=6))

    def test_mask_and_transparency_are_already_included(self):
        for mask in (False, True):
            for transparency in (False, True):
                self.assertEqual(line_timing(drawn=3, pixel_size=4,
                    plane_mask=mask, transparency=transparency)['states'], 19)

    def test_window_columns_and_abort(self):
        self.assertEqual(line_timing(drawn=1, outside=3, window=3)['states'], 24)
        self.assertEqual(line_timing(drawn=0, outside=4, window=3)['states'], 24)
        self.assertEqual(line_timing(drawn=3, outside=1, window=2, violation=True)['states'], 24)
        self.assertEqual(line_timing(drawn=0, outside=1, window=2, violation=True)['states'], 9)
        self.assertEqual(line_timing(drawn=3, window=2)['states'], 19)
        with self.assertRaises(UnresolvedLineTiming):
            line_timing(drawn=0, outside=4, window=1)

    def test_empty_and_count_width_boundaries(self):
        self.assertEqual(line_timing(drawn=0)['states'], 4)
        self.assertEqual(line_timing(drawn=65536)['states'], 327684)
        self.assertEqual(line_timing(drawn=0xFFFFFFFF)['states'], 21474836479)

    def test_cache_fetch_is_separate(self):
        row = line_timing(drawn=23, cache_disabled=True)
        self.assertEqual((row['states'], row['setup_states'], row['transfer_states'], row['fetch_states']),
                         (122, 4, 115, 3))

    def test_invalid_conditions_fail(self):
        for values in (dict(drawn=-1), dict(drawn=True), dict(drawn=0x100000000),
                       dict(drawn=1, outside=0xFFFFFFFF, window=3), dict(drawn=1, outside=1),
                       dict(drawn=1, window=2, violation=True), dict(drawn=1, outside=2, window=2),
                       dict(drawn=1, window=3, violation=True), dict(drawn=1, window=4),
                       dict(drawn=1, pixel_size=3), dict(drawn=1, ppop=22)):
            with self.subTest(values=values), self.assertRaises(ValueError):
                line_timing(**values)


if __name__ == '__main__':
    unittest.main()
