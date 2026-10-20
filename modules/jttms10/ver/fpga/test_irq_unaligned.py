#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Pin TI's unaligned context rule and partial-word frame invariants."""
import copy
import unittest

import check_results as checker
import check_external_reference as reference
import event_contract
import irq_cases
import irq_contract


class UnalignedInterrupt(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.oracle = checker.oracle_module()
        cls.base = dict(fixture=next(c for c in cls.oracle.cases() if c['name'] == 'nop_hit'))
        cls.entries = irq_cases.unaligned_entries(cls.base, cls.oracle)
        for identifier, entry in enumerate(cls.entries):
            entry['id'] = identifier

    def sample(self):
        entry = copy.deepcopy(self.entries[0])  # SP3001, LINT1, W0, cold.
        c = entry['fixture']
        pc = c['next_pc']+3*16
        # Literal RMW plan: PC then ST, descending physical words for each.
        # Bit0 of the first word and bits1..15 of the last word are outside
        # the frame. The middle shared word carries PC plus ST's final bit.
        plan = [(0, 0x3000, 0xa5a5), (1, 0x3000, 0xa5a4),
                (1, 0x2ff0, 0), (0, 0x2fe0, 0xa5a5),
                (1, 0x2fe0, (pc << 1) | 1),
                (0, 0x2fe0, (pc << 1) | 1), (1, 0x2fe0, pc << 1),
                (1, 0x2fd0, 0x40), (0, 0x2fc0, 0xa5a5), (1, 0x2fc0, 0x1021),
                (0, 0xffffffc0, 0x4000), (0, 0xffffffd0, 0),
                (0, 0x4000, 0x09e0), (0, 0x4010, 0x5678),
                (0, 0x4020, 0x1234), (0, 0x4030, 0x0940),
                (0, 0x2fc0, 0x1021), (0, 0x2fd0, 0x40), (0, 0x2fe0, pc << 1),
                (0, 0x2fe0, pc << 1), (0, 0x2ff0, 0), (0, 0x3000, 0xa5a4)]
        lines = []
        for q, (we, address, data) in enumerate(plan):
            when = 1024+16*q+(44 if q >= 12 else 0)+(30 if q >= 16 else 0)
            for prefix, duration in (('BUS', 16), ('TARGET', 4)):
                lines += [f'{prefix}_BEGIN {when} {we} {address:08x} {data:04x} {int(12 <= q < 16)}',
                          f'{prefix}_END {when+duration} {we} {address:08x} {data:04x}']
        memory = {0x2fc0: 0x1021, 0x2fd0: 0x40, 0x2fe0: pc << 1,
                  0x2ff0: 0, 0x3000: 0xa5a4, 0xffffffc0: 0x4000, 0xffffffd0: 0}
        lines += [f'MEMORY {a:08x} {d:04x}' for a, d in memory.items()]
        lines += ['STIMULUS 1017 0 0 00000010 0001', 'STIMULUS 1201 1 1 00000006 0000',
                  'IRQ_BOUNDARY count=1 previous=1028 complete=1252 first=1348',
                  'FOLLOW clock=1500 st=00200810 a0=12345678 a1=11223344 a2=00000009 a3=d0200810',
                  'FOLLOW_EXTRA sp=00003001']
        return entry, dict(start=1000, end=1008, clocks=8, protocol_version=5), lines

    def test_all_nonzero_offsets_pins_waits_and_handlers_are_explicit(self):
        self.assertEqual(len(self.entries), 180)
        combinations = set()
        for row in self.entries:
            lint, warm, _ = irq_contract.validate(row)
            offset = row['external_contract']['sp_offset']
            combinations.add((offset, lint, row['stimulus']['wait_states'], warm))
            self.assertEqual(event_contract.expected_pause(row), 0)
            self.assertEqual(len(row['fixture']['initial_memory']), 7)
            self.assertEqual(row['fixture']['initial_sp'], 0x3000+offset)
            checker.make_batches([row], protocol_version=5)
        self.assertEqual(combinations, {(offset, lint, waits, warm) for offset in range(1, 16)
                         for lint in (1, 2) for waits in (0, 1, 3) for warm in (False, True)})

    def test_scalar_literal_frame_bus_order_and_28_state_timing(self):
        entry, observed, lines = self.sample()
        errors, normalized = irq_contract.check(entry, observed, lines)
        self.assertEqual(errors, [])
        self.assertEqual(normalized['boundary'], dict(count=1, previous=28, complete=252, first=348))

    def test_every_offset_preserves_bits_outside_the_64_bit_frame(self):
        for offset in range(1, 16):
            memory = irq_contract.initial_stack(0x3000+offset, False)
            plan = irq_contract.push_field(memory, 0x2fe0+offset, 0x12345678)
            plan += irq_contract.push_field(memory, 0x2fc0+offset, 0x00200810)
            # Independent packed-bit equation, not the model's per-bit loops.
            original = int('a5a5'*5, 16)
            mask = ((1 << 64)-1) << offset
            expected = (original & ~mask) | (0x1234567800200810 << offset)
            actual = sum(memory[0x2fc0+16*q] << (16*q) for q in range(5))
            self.assertEqual(actual, expected)
            self.assertEqual(len(plan), 10)
            self.assertEqual(sum(we for we, *_ in plan), 6)
            self.assertEqual(irq_contract.read_field(memory, 0x2fc0+offset), 0x00200810)
            self.assertEqual(irq_contract.read_field(memory, 0x2fe0+offset), 0x12345678)

    def test_surrounding_bits_frame_memory_and_word_order_remain_checked(self):
        entry, observed, lines = self.sample()
        for before, after in [('MEMORY 00002fc0 1021', 'MEMORY 00002fc0 1020'),
                              ('MEMORY 00003000 a5a4', 'MEMORY 00003000 0000'),
                              ('BUS_BEGIN 1024 0 00003000', 'BUS_BEGIN 1024 0 00002fe0'),
                              ('TARGET_BEGIN 1040 1 00003000 a5a4',
                               'TARGET_BEGIN 1040 1 00003000 a5a5')]:
            self.assertTrue(irq_contract.check(entry, observed, [s.replace(before, after) for s in lines])[0])

    def test_wrong_context_recognition_first_isr_and_waits_fail(self):
        entry, observed, lines = self.sample()
        for before, after, diagnostic in [('previous=1028', 'previous=1020', 'unaligned context switch'),
                                          ('complete=1252', 'complete=1260', 'entry latency'),
                                          ('first=1348', 'first=1356', 'first ISR MOVI')]:
            errors = irq_contract.check(entry, observed, [s.replace(before, after) for s in lines])[0]
            self.assertTrue(any(diagnostic in error for error in errors), errors)
        entry['stimulus']['wait_states'] = 1
        self.assertTrue(irq_contract.check(entry, observed, lines)[0])

    def test_protocol_and_contract_fail_closed(self):
        entry, observed, lines = self.sample()
        with self.assertRaisesRegex(ValueError, 'protocol 5'):
            checker.make_batches([entry], protocol_version=4)
        observed['protocol_version'] = 4
        self.assertTrue(any('protocol5' in error for error in irq_contract.check(entry, observed, lines)[0]))
        for offset in (False, 0, 16, -1):
            changed = copy.deepcopy(entry)
            changed['external_contract']['sp_offset'] = offset
            with self.assertRaises(ValueError):
                event_contract.expected_pause(changed)
        for field, value in [('initial_sp', 0x3000), ('initial_memory', [])]:
            changed = copy.deepcopy(entry)
            changed['fixture'][field] = value
            with self.assertRaises(ValueError):
                event_contract.expected_pause(changed)

    def test_subset_selection_is_deterministic_and_rejects_ambiguous_offsets(self):
        self.assertEqual(irq_cases.unaligned_entries(self.base, self.oracle, [15, 1]),
                         irq_cases.unaligned_entries(self.base, self.oracle, [1, 15]))
        self.assertEqual(sum(len(b['cases']) for b in reference.fixture_manifest(
            irq_unaligned=True, stack_offsets=[1, 8, 15])['batches']), 36)
        for offsets in ([], [1, 1], [False], [0], [16]):
            with self.assertRaises(ValueError):
                irq_cases.unaligned_entries(self.base, self.oracle, offsets)


if __name__ == '__main__':
    unittest.main()
