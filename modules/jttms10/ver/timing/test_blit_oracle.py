#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Literal substitutions into TI's PIXBLT tables, without an RTL model."""
import unittest
from blit_oracle import blit_timing, UnresolvedBlitTiming


class BlitOracleTest(unittest.TestCase):
    def test_regular_table_coefficients(self):
        # Table13-8 LL setup7; Table13-9 A/D>=S/G2 row6/10/4N, tail5.
        for words, rows, states in ((1,1,18),(1,2,24),(2,1,22),
                                    (2,2,32),(3,1,24),(4,2,44)):
            for size in (1,2,4,8,16):
                self.assertEqual(blit_timing('ll',size,words,rows)['states'],states)

    def test_all_regular_setup_columns_and_cd(self):
        for mode, states in (('ll',18),('lxy',20),('xyl',20),('xyxy',23)):
            for off in (False,True):
                row=blit_timing(mode,16,1,1,cache_disabled=off)
                self.assertEqual(row['states'],states+3*off)
                self.assertEqual(row['fetch_states'],3*off)

    def test_binary_short_and_medium_source_word_boundary(self):
        # Table13-11 BL setup4; Table13-12 (3+2R+NG)L+3, G2.
        for mode, extra in (('bl',0),('bxy',2)):
            for size,words,rows,source_words,states in ((16,1,1,1,14),
                    (16,2,1,1,16),(4,3,2,1,29),(1,1,1,1,14),
                    (1,2,1,2,18),(2,4,2,2,37)):
                row=blit_timing(mode,size,words,rows)
                self.assertEqual(row['source_words_per_row'],source_words)
                self.assertEqual(row['states'],states+extra)

    def test_unsupported_binary_domain_is_explicit(self):
        for mode in ('bl','bxy'):
            with self.assertRaises(UnresolvedBlitTiming):
                blit_timing(mode,1,3,1)

    def test_dimension_and_encoding_limits(self):
        for args in (('unknown',16,1,1),('ll',3,1,1),('ll',True,1,1),('ll',16,0,1),
                     ('ll',16,1,0),('ll',16,True,1),('ll',16,1,65536),
                     ('ll',1,4096,1)):
            with self.subTest(args=args),self.assertRaises(ValueError):
                blit_timing(*args)
        self.assertEqual(blit_timing('ll',16,1,65535)['states'],393222)


if __name__=='__main__':
    unittest.main()
