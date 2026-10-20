#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Corrupt architectural/entry timing observations without changing expectations."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

import check_results as checker
import event_contract
import irq_cases
import irq_contract


class InterruptContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        oracle = checker.oracle_module()
        cls.base = dict(fixture=next(c for c in oracle.cases() if c['name'] == 'nop_hit'))
        cls.entries = irq_cases.entries(cls.base, oracle)

    def sample(self, warm=False):
        entry = copy.deepcopy(self.entries[6 if warm else 0])
        c = entry['fixture']
        pc = c['next_pc']+3*16
        frame = [0, pc, 0x20, 0x0810]
        vector = 0xffffffc0
        plan = [(1, a, d, 0) for a, d in zip((0x2ff0, 0x2fe0, 0x2fd0, 0x2fc0), frame)]
        plan += [(0, vector, 0x4000, 0), (0, vector+16, 0, 0)]
        if not warm:
            plan += [(0, 0x4000+16*q, d, 1) for q, d in enumerate((0x09e0, 0x5678, 0x1234, 0x0940))]
        plan += [(0, a, d, 0) for a, d in zip(range(0x2fc0, 0x3000, 16), reversed(frame))]
        lines = []
        for q, (we, address, value, iaq) in enumerate(plan):
            when = 1024+16*q+(64 if warm and q >= 6 else 0)
            for prefix, duration in (('BUS', 16), ('TARGET', 4)):
                lines += [f'{prefix}_BEGIN {when} {we} {address:08x} {value:04x} {iaq}',
                          f'{prefix}_END {when+duration} {we} {address:08x} {value:04x}']
        lines += ['STIMULUS 1017 0 0 00000010 0001', 'STIMULUS 1089 1 1 00000004 0000']
        lines += [f'MEMORY {a:08x} {d:04x}' for a, d in zip(range(0x2fc0, 0x3000, 16), reversed(frame))]
        lines += [f'MEMORY {vector:08x} 4000', f'MEMORY {vector+16:08x} 0000']
        if warm:
            lines += ['FOLLOW clock=1160 st=00000010 a0=80000003 a1=11223344 a2=00000005 a3=d0200810',
                      'FOLLOW_EXTRA sp=00002fc0']
        else:
            lines += ['FOLLOW clock=1300 st=00200810 a0=12345678 a1=11223344 a2=00000009 a3=d0200810',
                      'FOLLOW_EXTRA sp=00003000']
        return entry, dict(start=1000, end=1008, clocks=8), lines

    def test_fixtures_preserve_original_nop_and_have_explicit_conditions(self):
        self.assertEqual(len(self.entries), 12)
        self.assertEqual(self.base['fixture']['regs'][3], 0xd0000810)
        for entry in self.entries:
            self.assertEqual(event_contract.expected_pause(entry), 0)
            self.assertEqual(entry['fixture']['states'], 1)
            checker.require_supported(entry['fixture'], 4)

    def test_cold_continuation_and_warm_handler_controls(self):
        for warm in (False, True):
            with self.subTest(warm=warm):
                entry, observed, lines = self.sample(warm)
                errors, normalized = irq_contract.check(entry, observed, lines)
                self.assertEqual(errors, [])
                self.assertEqual(normalized['follow']['clock'], (1160 if warm else 1300)-1000)
                self.assertEqual(normalized['follow']['a2'], 5 if warm else 9)

    def test_checked_observation_survives_json_reference_roundtrip(self):
        entry, observed, lines = self.sample()
        errors, normalized = irq_contract.check(entry, observed, lines)
        row = dict(entry['fixture'], observed=dict(observed, st=0xd0200810,
            paused=0, a0=0x80000003, a1=0x11223344, a2=2, a3=0xd0200810, sp=0x3000),
            errors=errors, irq_observation=normalized)
        self.assertEqual(checker.compare_reference([row], [json.loads(json.dumps(row))]), [])

    def test_wrong_register_status_sp_and_missing_snapshot_fail(self):
        for a, b, expected in (('a0=12345678', 'a0=12345679', 'A0'),
                               ('a2=00000009', 'a2=00000008', 'A2'),
                               ('st=00200810', 'st=00200811', 'ST'),
                               ('sp=00003000', 'sp=00002fc0', 'SP')):
            entry, observed, lines = self.sample()
            errors, _ = irq_contract.check(entry, observed, [s.replace(a, b) for s in lines])
            self.assertTrue(any(expected in error for error in errors), errors)
        entry, observed, lines = self.sample()
        self.assertTrue(irq_contract.check(entry, observed, [s for s in lines if not s.startswith('FOLLOW ')])[0])

    def test_wrong_frame_pc_status_vector_or_memory_association_fail(self):
        for address, value in ((0x2fe0, 0), (0x2fc0, 0), (0xffffffc0, 0x4100), (0x2ff0, 0xffff)):
            entry, observed, lines = self.sample()
            rows = [f'MEMORY {address:08x} {value:04x}' if s.startswith(f'MEMORY {address:08x} ') else s for s in lines]
            with self.subTest(address=address):
                self.assertTrue(irq_contract.check(entry, observed, rows)[0])
        self.assertTrue(irq_contract.check(entry, observed, lines+['MEMORY 00002fc0 0810'])[0])

    def test_stack_vector_fetch_and_pop_order_data_are_checked(self):
        for prefix in ('BUS', 'TARGET'):
            for q in (0, 1, 4, 6, 10, 13):
                entry, observed, lines = self.sample()
                starts = [i for i, s in enumerate(lines) if s.startswith(prefix+'_BEGIN ')]
                a = lines[starts[q]].split()
                a[3] = f'{int(a[3], 16)^16:08x}'
                lines[starts[q]] = ' '.join(a)
                with self.subTest(prefix=prefix, transfer=q):
                    self.assertTrue(any('request/order/data' in s for s in irq_contract.check(entry, observed, lines)[0]))

    def test_wrong_bus_wait_length_fails_even_with_correct_architecture(self):
        for prefix in ('BUS', 'TARGET'):
            entry, observed, lines = self.sample()
            rows = []
            changed = False
            for s in lines:
                if s.startswith(prefix+'_END ') and not changed:
                    a = s.split();a[1] = str(int(a[1])+8);s = ' '.join(a);changed = True
                rows.append(s)
            self.assertTrue(any('INCLK' in s for s in irq_contract.check(entry, observed, rows)[0]))
        entry['stimulus']['wait_states'] = 1
        self.assertTrue(any('INCLK' in s for s in irq_contract.check(entry, observed, lines)[0]))

    def test_missing_or_duplicate_bus_transfer_fails(self):
        entry, observed, lines = self.sample()
        for rows in ([s for s in lines if not s.startswith('BUS_BEGIN 1024 ')], lines+[lines[0]]):
            self.assertTrue(any('expected 14' in s for s in irq_contract.check(entry, observed, rows)[0]))

    def test_late_warm_handler_fails_with_correct_architecture(self):
        entry, observed, lines = self.sample(True)
        lines = [s.replace('clock=1160', 'clock=1200') for s in lines]
        errors, _ = irq_contract.check(entry, observed, lines)
        self.assertTrue(any('entry latency' in s and 'observed 183' in s for s in errors), errors)
        self.assertFalse(any('expected 0x' in s for s in errors), errors)

    def explicit_sample(self, warm=True):
        entry, observed, lines = self.sample(warm)
        observed['protocol_version'] = 5
        first = 1180 if warm else 1252
        lines.append(f'IRQ_BOUNDARY count=1 previous=1028 complete=1156 first={first}')
        return entry, observed, lines

    def test_v5_checks_actual_context_and_first_isr_retirement(self):
        for warm in (False, True):
            entry, observed, lines = self.explicit_sample(warm)
            errors, normalized = irq_contract.check(entry, observed, lines)
            self.assertEqual(errors, [])
            self.assertEqual(normalized['boundary']['complete'], 156)
            # Decoding is a separate recorded observation, not the context
            # completion edge. The explicit boundary owns absolute latency.
            lines = [s.replace('clock=1160', 'clock=1164') for s in lines]
            self.assertEqual(irq_contract.check(entry, observed, lines)[0], [])

    def test_v5_does_not_fall_back_to_decode_when_boundaries_are_missing(self):
        entry, observed, lines = self.explicit_sample()
        for rows in (lines[:-1], lines+[lines[-1]],
                     lines[:-1]+[lines[-1].replace('count=1', 'count=0')],
                     lines[:-1]+[lines[-1].replace('count=1', 'count=2')],
                     lines[:-1]+['IRQ_BOUNDARY count=1'],
                     lines[:-1]+[lines[-1]+' first=1180']):
            self.assertTrue(any('explicit IRQ boundaries' in e
                                for e in irq_contract.check(entry, observed, rows)[0]))

    def test_v5_rejects_wrong_context_latency_and_first_isr_even_with_correct_state(self):
        entry, observed, lines = self.explicit_sample()
        for a, b, match in [('previous=1028', 'previous=1020', 'context switch'),
                            ('complete=1156', 'complete=1164', 'entry latency'),
                            ('first=1180', 'first=1188', 'first ISR MOVI')]:
            rows = [s.replace(a, b) for s in lines]
            self.assertTrue(any(match in e for e in irq_contract.check(entry, observed, rows)[0]))

    def test_exact_context_count_is_checked_inside_recognition_envelope(self):
        entry, observed, lines = self.sample(True)
        errors, _ = irq_contract.check(entry, observed, [s.replace('clock=1160', 'clock=1159') for s in lines])
        self.assertTrue(any('context switch' in s and 'observed 127' in s for s in errors), errors)
        self.assertFalse(any('entry latency' in s for s in errors), errors)

    def test_warm_context_counter_matches_saved_resume_pc(self):
        entry, observed, lines = self.sample(True)
        errors, _ = irq_contract.check(entry, observed, [s.replace('a2=00000005', 'a2=00000004') for s in lines])
        self.assertTrue(any('handler entry A2' in s for s in errors), errors)

    def test_changed_contract_events_initialization_or_program_fail_closed(self):
        for change in ('field', 'kind', 'lint', 'warm', 'event', 'pause', 'regs', 'memory', 'handler'):
            entry, _, _ = self.sample()
            if change == 'field': entry['external_contract']['waive_timing'] = True
            elif change == 'kind': entry['external_contract']['kind'] = 'other_irq'
            elif change == 'lint': entry['external_contract']['lint'] = True
            elif change == 'warm': entry['external_contract']['handler_warm'] = 1
            elif change == 'event': entry['external_events'][0]['argument'] = 15
            elif change == 'pause': entry['stimulus']['pause_clocks'] = 7
            elif change == 'regs': entry['fixture']['regs'][2] = 3
            elif change == 'memory': entry['fixture']['initial_memory'][0] = (0x2fc0, 1)
            else: entry['program_words'][(0x4000-0x1000)//16] ^= 1
            with self.subTest(change=change), self.assertRaises(ValueError):
                event_contract.expected_pause(entry)

    def test_selected_source_owns_irq_expectations(self):
        with tempfile.TemporaryDirectory(prefix='jttms10-selected-irq-') as temp:
            root = Path(temp)
            (root/'event_contract.py').write_bytes(Path(event_contract.__file__).read_bytes())
            (root/'irq_contract.py').write_text(
                'def validate(entry):\n    assert entry["selected"] == 123\n'
                'def check(entry, observed, lines):\n    return [], {"selected": entry["selected"]}\n')
            (root/'nmi_nostack_contract.py').write_text(
                'def validate(entry):\n    assert entry["selected"] == 456\n'
                'def check(entry, observed, lines):\n    return [], {"selected_nostack": entry["selected"]}\n')
            (root/'nmi_nostack_io_contract.py').write_text(
                'def validate(entry):\n    assert entry["selected"] == 789\n'
                'def check(entry, observed, lines):\n    return [], {"selected_io": entry["selected"]}\n')
            spec = importlib.util.spec_from_file_location('selected_event_contract', root/'event_contract.py')
            module = importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
            entry = dict(external_contract=dict(kind='scalar_irq'), selected=123)
            self.assertEqual(module.expected_pause(entry), 0)
            self.assertEqual(module.check_followup(entry, {}, []), ([], dict(selected=123)))
            entry = dict(external_contract=dict(kind='scalar_nmi_nostack'), selected=456)
            self.assertEqual(module.expected_pause(entry), 0)
            self.assertEqual(module.check_followup(entry, {}, []), ([], dict(selected_nostack=456)))
            entry = dict(external_contract=dict(kind='scalar_nmi_nostack_io'), selected=789)
            self.assertEqual(module.expected_pause(entry), 0)
            self.assertEqual(module.check_followup(entry, {}, []), ([], dict(selected_io=789)))
        entry, observed, lines = self.sample()
        self.assertEqual(irq_contract.check(entry, observed, lines)[0], [])

    def test_all_eight_phase_conditions_preserve_original_cases(self):
        before = copy.deepcopy(self.entries)
        phases = irq_cases.phase_entries(self.base, checker.oracle_module())
        self.assertEqual(self.entries, before)
        self.assertEqual(len(phases), 48)
        self.assertEqual(len({row['name'] for row in phases}), 48)
        combinations = set()
        for row in phases:
            self.assertEqual(event_contract.expected_pause(row), 0)
            lint, warm, _ = irq_contract.validate(row)
            self.assertTrue(warm)
            combinations.add((lint, row['stimulus']['wait_states'],
                              row['external_contract']['assert_clock']))
            original = next(e for e in self.entries if row['name'].startswith(e['name']+'_assert'))
            self.assertEqual(row['program_words'], original['program_words'])
            self.assertEqual(row['fixture']['regs'], original['fixture']['regs'])
        self.assertEqual(combinations, {(lint, waits, clock) for lint in (1, 2)
                                       for waits in (0, 1, 3) for clock in range(16, 24)})

    def test_phase_changes_recognition_clock_but_not_exact_context_count(self):
        for clock in range(16, 24):
            entry, observed, lines = self.sample(True)
            entry['external_contract'].update(kind='scalar_irq_phase', assert_clock=clock)
            entry['external_events'][0]['argument'] = clock
            lines = [s.replace('STIMULUS 1017 0 0 00000010',
                               f'STIMULUS {1001+clock} 0 0 {clock:08x}') for s in lines]
            self.assertEqual(irq_contract.check(entry, observed, lines)[0], [])
            late = [s.replace('clock=1160', 'clock=1168') for s in lines]
            self.assertTrue(any('context switch' in error
                                for error in irq_contract.check(entry, observed, late)[0]))

    def test_phase_contract_rejects_unsupported_conditions_and_table_mismatch(self):
        for field, value in [('assert_clock', False), ('assert_clock', 15),
                             ('assert_clock', 24), ('handler_warm', False)]:
            entry, _, _ = self.sample(True)
            entry['external_contract'].update(kind='scalar_irq_phase', assert_clock=16)
            entry['external_contract'][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                event_contract.expected_pause(entry)
        entry['external_contract'].update(handler_warm=True, assert_clock=17)
        with self.assertRaisesRegex(ValueError, 'stimulus differs'):
            event_contract.expected_pause(entry)


if __name__ == '__main__':
    unittest.main()
