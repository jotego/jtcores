#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Literal no-stack NMI architectural, recognition and bus expectations."""
import copy
import unittest

import check_external_reference as reference
import check_results as checker
import event_contract
import nmi_nostack_cases
import nmi_nostack_contract as contract


class NoStackNMIContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.oracle = checker.oracle_module()
        cls.base = dict(fixture=next(c for c in cls.oracle.cases() if c['name'] == 'nop_hit'))
        cls.entries = nmi_nostack_cases.entries(cls.base, cls.oracle)
        for identifier, entry in enumerate(cls.entries):
            entry['id'] = identifier

    def sample(self):
        entry = copy.deepcopy(self.entries[0])
        plan = [(1032, 0xfffffee0, 0x4000, 0), (1056, 0xfffffef0, 0, 0)]
        plan += [(1080+16*q, 0x4000+16*q, value, 1)
                 for q, value in enumerate((0x09e0, 0x5678, 0x1234, 0x0165))]
        plan += [(1184+16*q, 0x4040+16*q, value, 1)
                 for q, value in enumerate((0x0300, 0xc0ff, 0x0300, 0x0300))]
        lines = []
        for when, address, value, iaq in plan:
            for prefix, duration in (('BUS', 16), ('TARGET', 4)):
                lines += [f'{prefix}_BEGIN {when} 0 {address:08x} 0000 {iaq}',
                          f'{prefix}_END {when+duration} 0 {address:08x} {value:04x}']
            lines.append(f'BUS_ACCEPT {when}')
        lines += [f'MEMORY {address:08x} {value:04x}' for address, value in entry['fixture']['initial_memory']]
        lines += ['STIMULUS 1017 0 0 00000010 0310', 'HOST_ACK 1018',
                  'STIMULUS 1019 1 5 00000001 0000',
                  'IRQ_BOUNDARY count=1 previous=1028 complete=1076 first=1172',
                  'FOLLOW clock=1176 st=00000010 a0=12345678 a1=11223344 a2=00000002 a3=d0000810',
                  'FOLLOW_ALL a4=00004000 a5=00004050 a13=00000018 a14=c00000b0',
                  'FOLLOW_EXTRA sp=00003000']
        return entry, dict(start=1000, end=1008, clocks=8, protocol_version=5), lines

    def test_literal_no_stack_architecture_bus_and_recognition_pass(self):
        entry, observed, lines = self.sample()
        errors, result = contract.check(entry, observed, lines)
        self.assertEqual(errors, [])
        self.assertEqual(result['context_duration_contract'], 'not separately specified for NMIM=1; observed only')

    def test_every_mask_wait_cache_and_stack_alignment_is_explicit(self):
        self.assertEqual(len(self.entries), 192)
        combinations = set()
        for entry in self.entries:
            spec, _, _ = contract.validate(entry)
            combinations.add((spec['sp_offset'], spec['interrupt_enable'],
                              entry['stimulus']['wait_states'], spec['handler_warm']))
            self.assertEqual(event_contract.expected_pause(entry), 0)
            checker.make_batches([entry], 5)
        self.assertEqual(combinations, {(q, enabled, wait, warm) for q in range(16)
                         for enabled in (False, True) for wait in (0, 1, 3) for warm in (False, True)})

    def test_no_stack_write_can_hide_behind_correct_final_memory(self):
        entry, observed, lines = self.sample()
        lines += ['BUS_BEGIN 1300 1 00002ff0 a5a5 0', 'BUS_END 1316 1 00002ff0 a5a5']
        self.assertTrue(any('vector/handler reads' in e for e in contract.check(entry, observed, lines)[0]))

    def test_registers_status_and_guard_words_stay_checked(self):
        entry, observed, lines = self.sample()
        for old, new in [('sp=00003000', 'sp=00002fc0'), ('a4=00004000', 'a4=00004001'),
                         ('st=00000010', 'st=00000011'), ('MEMORY 00002fc0 a5a5', 'MEMORY 00002fc0 a5a4')]:
            self.assertTrue(contract.check(entry, observed, [s.replace(old, new) for s in lines])[0])

    def test_correct_architecture_with_wrong_recognition_or_isr_time_fails(self):
        entry, observed, lines = self.sample()
        for old, new, diagnostic in [('HOST_ACK 1018', 'HOST_ACK 1027', 'recognition:'),
                                      ('first=1172', 'first=1180', 'first ISR MOVI')]:
            errors = contract.check(entry, observed, [s.replace(old, new) for s in lines])[0]
            self.assertTrue(any(diagnostic in error for error in errors), errors)

    def test_vector_bus_data_order_and_wait_duration_remain_checked(self):
        entry, observed, lines = self.sample()
        for old, new in [('BUS_END 1048 0 fffffee0 4000', 'BUS_END 1048 0 fffffee0 4001'),
                         ('BUS_BEGIN 1032 0 fffffee0', 'BUS_BEGIN 1032 0 fffffef0'),
                         ('TARGET_END 1036', 'TARGET_END 1044')]:
            self.assertTrue(contract.check(entry, observed, [s.replace(old, new) for s in lines])[0])

    def test_protocol_mask_schedule_and_program_fail_closed(self):
        entry, observed, lines = self.sample()
        with self.assertRaisesRegex(ValueError, 'protocol 5'):
            checker.make_batches([entry], 4)
        for change in ('mask', 'offset', 'program', 'schedule'):
            row = copy.deepcopy(entry)
            if change == 'mask': row['external_events'][0]['control'] = 0x110
            if change == 'offset': row['external_contract']['sp_offset'] = False
            if change == 'program': row['program_words'][-5] = 0x0940
            if change == 'schedule': row['external_events'][0]['argument'] += 1
            with self.assertRaises(ValueError): event_contract.expected_pause(row)
        observed['protocol_version'] = 4
        self.assertTrue(contract.check(entry, observed, lines)[0])

    def test_bus_acknowledgement_count_and_order_are_required(self):
        entry, observed, lines = self.sample()
        for changed in ([s for s in lines if s != 'BUS_ACCEPT 1032'],
                        [s.replace('BUS_ACCEPT 1032', 'BUS_ACCEPT 1048') for s in lines]):
            self.assertTrue(any('BUS acknowledgement' in e for e in contract.check(entry, observed, changed)[0]))

    def test_vector_and_isr_cannot_precede_context_installation(self):
        entry, observed, lines = self.sample()
        changed = [s.replace('complete=1076 first=1172', 'complete=1068 first=1164') for s in lines]
        self.assertTrue(any('out of order' in e for e in contract.check(entry, observed, changed)[0]))

    def test_warm_phase_and_subset_inventory(self):
        rows = nmi_nostack_cases.entries(self.base, self.oracle, phase_sweep=True)
        self.assertEqual(len(rows), 48)
        for row in rows: contract.validate(row)
        self.assertEqual({(r['external_contract']['interrupt_enable'], r['stimulus']['wait_states'],
                          r['external_contract']['assert_clock']) for r in rows},
                         {(e, w, c) for e in (False, True) for w in (0, 1, 3) for c in range(16, 24)})
        self.assertEqual(sum(len(b['cases']) for b in reference.fixture_manifest(
            nmi_nostack=True, stack_offsets=[0, 1, 15])['batches']), 36)
        for offsets in ([], [1, 1], [False], [-1], [16]):
            with self.assertRaises(ValueError): nmi_nostack_cases.entries(self.base, self.oracle, offsets)


if __name__ == '__main__':
    unittest.main()
