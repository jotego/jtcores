#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Primary-table FILL model checks; these are not CPU timing probes."""
import unittest

from fill_oracle import UnresolvedFillTiming, fill_timing, graphics_states


class FillOracleTests(unittest.TestCase):
    def test_three_printed_examples(self):
        # SPVU001A13-14..17: the clipped array starts at(235,73),53x15.
        base = dict(pixel_size=4, width=53, rows=15, address=73*0x800+235*4,
                    pitch=0x800, xy=True, window_operation='start')
        for options, expected in ((dict(ppop=0), 483), (dict(ppop=20), 1113),
                                  (dict(ppop=5, plane_mask=True, transparency=True), 1293)):
            with self.subTest(options=options):
                result = fill_timing(**base, **options)
                self.assertEqual(result['states'], expected)
                self.assertEqual((result['words_per_row'], result['alignment']), (14, 'C'))

    def test_all_alignment_columns_and_row_length_boundaries(self):
        # Table13-6 evaluated at G=2,L=2, with FILL L setup4.
        expected = ((12, 14, 13, 13), (18, 20, 20, 21),
                    (20, 25, 24, 25), (24, 29, 28, 29))
        for words, totals in enumerate(expected, 1):
            for alignment, total in zip('ABCD', totals):
                lane = int(alignment in 'CD')
                width = words*16 - lane - int(alignment in 'BD')
                with self.subTest(words=words, alignment=alignment):
                    result = fill_timing(pixel_size=1, width=width, rows=2, address=0x2000+lane)
                    self.assertEqual(result['states'], total)
                    self.assertEqual((result['words_per_row'], result['alignment']), (words, alignment))

    def test_xy_setup_columns_and_single_cd_surcharge(self):
        # Table13-5 plus the aligned one-word five-state transfer.
        for name, states in zip(('disabled', 'fits', 'start', 'dimensions', 'both'),
                                (11, 14, 21, 17, 25)):
            for off in (False, True):
                with self.subTest(window=name, cd=off):
                    self.assertEqual(fill_timing(pixel_size=16, width=1, rows=1,
                        xy=True, window_operation=name, cache_disabled=off)['states'], states+3*off)

    def test_every_processing_operation_and_mask_transparency_combination(self):
        # Table13-7: replace;15 other Booleans;ADD;ADDS;SUB;SUBS;MAX;MIN.
        expected = [2] + [4]*16 + [5, 5, 6, 5, 5]
        for ppop, states in enumerate(expected):
            for mask, trans in ((False, False), (True, False), (False, True), (True, True)):
                with self.subTest(ppop=ppop, mask=mask, trans=trans):
                    self.assertEqual(graphics_states(16, ppop, plane_mask=mask,
                        transparency=trans), states + (2 if mask or trans else 0))

    def test_edge_reads_are_reused_for_masking(self):
        # Two full center words remain chargeable in the four-word D case.
        base = dict(pixel_size=4, width=14, rows=2, address=4, ppop=19)
        self.assertEqual(fill_timing(**base)['states'], 61)
        self.assertEqual(fill_timing(**base, plane_mask=True)['states'], 69)
        # A short C row already has its single required read.
        base = dict(pixel_size=4, width=3, rows=2, address=4, ppop=20)
        self.assertEqual(fill_timing(**base)['states'], 19)
        self.assertEqual(fill_timing(**base, transparency=True)['states'], 19)

    def test_maximum_dimensions_and_single_instruction_cd_cost(self):
        # Table13-6,A,long with N=L=65535,G=2, plus setup4.
        base = dict(pixel_size=16, width=65535, rows=65535)
        self.assertEqual(fill_timing(**base)['states'], 8589737991)
        self.assertEqual(fill_timing(**base, cache_disabled=True)['states'], 8589737994)

    def test_single_word_two_edge_adjustment_keeps_both_alternatives(self):
        for rows, printed, single in ((1, 7, 9), (2, 9, 13)):
            with self.subTest(rows=rows):
                with self.assertRaises(UnresolvedFillTiming) as error:
                    fill_timing(pixel_size=4, width=1, rows=rows, address=4, plane_mask=True)
                self.assertEqual(error.exception.alternatives,
                                 dict(printed_two_edges=printed, single_word_edge=single))

    def test_undefined_and_unresolved_domains_cannot_supply_goldens(self):
        for size in (1, 2):
            for ppop in range(16, 22):
                with self.assertRaises(ValueError):graphics_states(size, ppop)
        for options in (dict(width=0), dict(rows=0), dict(pitch=1),
                        dict(xy=True, window_operation='hit'), dict(xy=True, window_operation='miss')):
            args = dict(pixel_size=4, width=4, rows=2);args.update(options)
            with self.subTest(options=options):
                with self.assertRaises(UnresolvedFillTiming):fill_timing(**args)
        for options in (dict(pixel_size=3), dict(ppop=22), dict(address=1),
                        dict(width=65536), dict(window_operation='fits')):
            args = dict(pixel_size=4, width=4, rows=2);args.update(options)
            with self.subTest(options=options):
                with self.assertRaises(ValueError):fill_timing(**args)
        self.assertEqual(fill_timing(pixel_size=4, width=4, rows=1, pitch=1)['states'], 9)


if __name__ == '__main__':unittest.main()
