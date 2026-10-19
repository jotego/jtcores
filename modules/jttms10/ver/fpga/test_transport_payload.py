#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Validate the wire boundary without SSH, MMIO or executing RTL."""
import copy
import struct
import unittest

import check_results as checker
import run_batch


class TransportPayload(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.entry = checker.prepare_cases(['nop_hit'], limit=1, protocol_version=3)[0]

    def batch(self):
        return checker.make_batches([copy.deepcopy(self.entry)], protocol_version=3)[0]

    def test_v3_stream_has_distinct_magic_and_complete_descriptor(self):
        batch = self.batch()
        batch['descriptors'][0][12] = 0xfffffffe
        payload = run_batch.input_payload([batch], 1234)
        self.assertEqual(struct.unpack_from('<4sI', payload), (b'JTR4', 1))
        self.assertEqual(struct.unpack_from('<4I', payload, 8),
                         (1, len(batch['program_words']), 1234, 0))
        self.assertEqual(list(struct.unpack_from('<16I', payload, 24)), batch['descriptors'][0])
        self.assertEqual(list(struct.unpack_from(f'<{len(batch["program_words"])}H', payload, 88)),
                         batch['program_words'])

    def test_full_fixture_batch_count_fits_transport(self):
        payload = run_batch.input_payload([self.batch()] * 5151, 1234)
        self.assertEqual(struct.unpack_from('<4sI', payload), (b'JTR4', 5151))
        with self.assertRaisesRegex(ValueError, 'number of FPGA batches'):
            run_batch.input_payload([self.batch()] * 8193, 1234)

    def test_old_layout_cannot_be_misread_as_new_layout(self):
        old = checker.make_batches([copy.deepcopy(self.entry)], protocol_version=2)[0]
        with self.assertRaisesRegex(ValueError, 'protocol_version 3'):
            run_batch.input_payload([old], 1234)

    def test_unsupported_drain_follow_and_reserved_fields_fail(self):
        for index, value in ((12, 0xfffffffd), (12, 0x80000000), (13, 1), (14, 1), (15, 1)):
            with self.subTest(index=index, value=value):
                batch = self.batch()
                batch['descriptors'][0][index] = value
                with self.assertRaises(ValueError):
                    run_batch.input_payload([batch], 1234)

    def test_invalid_timeout_fails_before_serialization(self):
        for timeout in (0, -1, 0x100000000, True):
            with self.subTest(timeout=timeout), self.assertRaises(ValueError):
                run_batch.input_payload([self.batch()], timeout)


if __name__ == '__main__':
    unittest.main()
