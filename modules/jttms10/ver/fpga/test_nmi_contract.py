#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Pin TI's host-written stacked NMI rules, including a failing latency target."""
import copy
import unittest

import check_external_reference as reference
import check_results as checker
import event_contract
import irq_contract
import nmi_cases


class NMIContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.oracle = checker.oracle_module()
        cls.base = dict(fixture=next(c for c in cls.oracle.cases() if c['name'] == 'nop_hit'))
        cls.entries = nmi_cases.entries(cls.base, cls.oracle)
        for identifier, entry in enumerate(cls.entries):
            entry['id'] = identifier

    def sample(self):
        entry = copy.deepcopy(self.entries[0])
        pc = entry['next_pc']+48
        plan = [(1, 0x2ff0, 0, 0), (1, 0x2fe0, pc, 0),
                (1, 0x2fd0, 0, 0), (1, 0x2fc0, 0x810, 0),
                (0, 0xfffffee0, 0x4000, 0), (0, 0xfffffef0, 0, 0),
                (0, 0x4000, 0x09e0, 1), (0, 0x4010, 0x5678, 1),
                (0, 0x4020, 0x1234, 1), (0, 0x4030, 0x0940, 1),
                (0, 0x2fc0, 0x810, 0), (0, 0x2fd0, 0, 0),
                (0, 0x2fe0, pc, 0), (0, 0x2ff0, 0, 0)]
        lines = []
        for q, (we, address, data, iaq) in enumerate(plan):
            for prefix, duration in (('BUS', 16), ('TARGET', 4)):
                when = 1024+16*q
                lines += [f'{prefix}_BEGIN {when} {we} {address:08x} {data:04x} {iaq}',
                          f'{prefix}_END {when+duration} {we} {address:08x} {data:04x}']
        memory = {0x2fc0: 0x810, 0x2fd0: 0, 0x2fe0: pc, 0x2ff0: 0,
                  0xfffffee0: 0x4000, 0xfffffef0: 0}
        lines += [f'MEMORY {a:08x} {v:04x}' for a, v in memory.items()]
        lines += ['STIMULUS 1016 0 0 00000010 0110', 'HOST_ACK 1017',
                  'STIMULUS 1018 1 5 00000001 0000',
                  'IRQ_BOUNDARY count=1 previous=1025 complete=1153 first=1249',
                  'FOLLOW clock=1400 st=00000810 a0=12345678 a1=11223344 a2=00000009 a3=d0000810',
                  'FOLLOW_EXTRA sp=00003000']
        return entry, dict(start=1000, end=1008, clocks=8, protocol_version=5), lines

    def test_masks_waits_cache_and_every_sp_offset_are_explicit(self):
        self.assertEqual(len(self.entries), 192)
        combinations = set()
        for entry in self.entries:
            self.assertEqual(irq_contract.validate(entry)[0], 0)
            contract = entry['external_contract']
            combinations.add((contract['sp_offset'], contract['interrupt_enable'],
                              entry['stimulus']['wait_states'], contract['handler_warm']))
            self.assertEqual(entry['fixture']['setup_io'], [])
            self.assertEqual(event_contract.expected_pause(entry), 0)
            checker.make_batches([entry], protocol_version=5)
        self.assertEqual(combinations, {(offset, enabled, waits, warm) for offset in range(16)
                         for enabled in (False, True) for waits in (0, 1, 3) for warm in (False, True)})

    def test_literal_frame_vector_and_context_pass(self):
        entry, observed, lines = self.sample()
        errors, _ = irq_contract.check(entry, observed, lines)
        self.assertEqual(errors, [])

    def test_recognition_starts_at_host_completion_not_stimulus(self):
        entry, observed, lines = self.sample()
        # Request strobe is unchanged; a later host completion makes the
        # measured recognition too short and must fail the published bound.
        changed = [s.replace('HOST_ACK 1017', 'HOST_ACK 1024') for s in lines]
        errors, _ = irq_contract.check(entry, observed, changed)
        self.assertTrue(any('NMI entry latency' in error for error in errors), errors)
        for changed in ([s for s in lines if not s.startswith('HOST_ACK ')], lines+['HOST_ACK 1017']):
            self.assertTrue(any('host NMI completion' in error
                                for error in irq_contract.check(entry, observed, changed)[0]))

    def test_correct_registers_with_wrong_context_or_first_isr_timing_fail(self):
        entry, observed, lines = self.sample()
        for before, after, diagnostic in [('previous=1025', 'previous=1017', 'aligned context switch'),
                                          ('first=1249', 'first=1257', 'first ISR MOVI')]:
            errors, _ = irq_contract.check(entry, observed, [s.replace(before, after) for s in lines])
            self.assertTrue(any(diagnostic in error for error in errors), errors)

    def test_vector_saved_status_memory_and_bus_remain_checked(self):
        entry, observed, lines = self.sample()
        for before, after in [('MEMORY 00002fc0 0810', 'MEMORY 00002fc0 0811'),
                              ('fffffee0 4000', 'fffffee0 4001'),
                              ('BUS_BEGIN 1024 1 00002ff0', 'BUS_BEGIN 1024 1 00002fe0')]:
            self.assertTrue(irq_contract.check(entry, observed, [s.replace(before, after) for s in lines])[0])

    def test_protocol_stimulus_and_masks_fail_closed(self):
        entry, observed, lines = self.sample()
        with self.assertRaisesRegex(ValueError, 'protocol 5'):
            checker.make_batches([entry], protocol_version=4)
        observed['protocol_version'] = 4
        self.assertTrue(irq_contract.check(entry, observed, lines)[0])
        for change in ('mode', 'irq_mask', 'status', 'offset'):
            row = copy.deepcopy(entry)
            if change == 'mode': row['external_events'][0]['control'] = 0x310
            if change == 'irq_mask': row['fixture']['setup_io'] = [(0xc0000110, 2)]
            if change == 'status': row['fixture']['regs'][3] |= 0x00200000
            if change == 'offset': row['external_contract']['sp_offset'] = False
            with self.assertRaises(ValueError): event_contract.expected_pause(row)

    def test_subset_and_cli_inventory(self):
        self.assertEqual(sum(len(b['cases']) for b in reference.fixture_manifest(
            nmi=True, stack_offsets=[0, 1, 15])['batches']), 36)
        for offsets in ([], [1, 1], [False], [-1], [16]):
            with self.assertRaises(ValueError): nmi_cases.entries(self.base, self.oracle, offsets)

    def test_warm_phase_sweep_preserves_literal_masks_and_host_origin(self):
        rows = nmi_cases.phase_entries(self.base, self.oracle)
        self.assertEqual(len(rows), 48)
        combinations = set()
        for row in rows:
            irq_contract.validate(row)
            contract = row['external_contract']
            combinations.add((contract['interrupt_enable'], row['stimulus']['wait_states'],
                              contract['assert_clock']))
            self.assertEqual(row['external_events'][0]['argument'], contract['assert_clock'])
        self.assertEqual(combinations, {(enabled, waits, clock) for enabled in (False, True)
                         for waits in (0, 1, 3) for clock in range(16, 24)})


if __name__ == '__main__':
    unittest.main()
