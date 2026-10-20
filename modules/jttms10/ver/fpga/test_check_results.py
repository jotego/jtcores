#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Protocol negatives: corrupted captures must not become passing fixtures."""
import copy
import json
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
        batch = checker.make_batches([entry], protocol_version=1)[0]
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

    def packet_v2(self):
        old, capture = self.packet()
        batch = checker.make_batches(old['cases'])[0]
        capture['protocol_version'] = 2
        capture['results'][0].extend([0] * (202 - 72))
        return batch, capture

    def test_v2_controls_and_actual_pause_count(self):
        batch, capture = self.packet_v2()
        self.assertEqual(checker.check_batch(batch, capture)['failed'], 0)
        batch['cases'][0]['stimulus'] = dict(pause_clocks=7)
        capture['results'][0][2] += 7
        capture['results'][0][72] = 7
        self.assertEqual(checker.check_batch(batch, capture)['failed'], 0)
        capture['results'][0][72] = 6
        self.assertEqual(checker.check_batch(batch, capture)['failed'], 1)

    def test_v2_version_memory_count_and_stale_padding(self):
        batch, capture = self.packet_v2()
        capture['protocol_version'] = 1
        with self.assertRaisesRegex(ValueError, 'protocol version'):
            checker.check_batch(batch, capture)
        for word in (73, 75, 201):
            batch, capture = self.packet_v2()
            capture['results'][0][word] = 1
            self.assertEqual(checker.check_batch(batch, capture)['failed'], 1)

    def test_v2_sparse_staging_bounds_and_record_layout(self):
        batch, _ = self.packet_v2()
        entry = batch['cases'][0]
        entry['fixture']['initial_memory'] = [(0xff001230, 0x1234)]
        prepared = checker.make_batches([entry])[0]
        desc = prepared['descriptors'][0]
        self.assertEqual(desc[6:8], [len(entry['program_words']), 1])
        self.assertEqual(prepared['program_words'][desc[6]:], [0x1230, 0xff00, 0x1234])
        for memory in ([(1, 0)], [(0x1000, 1), (0x1000, 2)],
                       [(q << 10, 0) for q in range(17)], [(0x1000, 0x10000)]):
            entry['fixture']['initial_memory'] = memory
            with self.assertRaises(ValueError):
                checker.make_batches([entry])

    def test_v2_unsupported_drain_store_and_stimulus(self):
        batch, _ = self.packet_v2()
        entry = batch['cases'][0]
        for drain in (1, -2):
            entry['fixture']['drain_instructions'] = drain
            with self.assertRaisesRegex(ValueError, 'drain/follow'):
                checker.make_batches([entry])
        del entry['fixture']['drain_instructions']
        for settings in (dict(wait_states=0x20000000), dict(pause_clocks=-1), dict(hold=1)):
            entry['stimulus'] = settings
            with self.assertRaises(ValueError):
                checker.make_batches([entry])

    def test_manifest_protocol_envelope_is_checked(self):
        batch, _ = self.packet_v2()
        manifest = dict(format=checker.FORMAT, protocol_version=2, batches=[batch])
        self.assertEqual(checker.validate_manifest(manifest), 2)
        for mutation in ('format', 'version', 'batch', 'empty'):
            other = copy.deepcopy(manifest)
            if mutation == 'format':
                other['format'] = checker.FORMAT_V1
            elif mutation == 'version':
                del other['protocol_version']
            elif mutation == 'batch':
                del other['batches'][0]['protocol_version']
            else:
                other['batches'] = []
            with self.assertRaises(ValueError):
                checker.validate_manifest(other)

    def test_unhandled_memory_expectation_is_rejected(self):
        batch, _ = self.packet_v2()
        entry = batch['cases'][0]
        entry['fixture']['expected_memory'] = []
        with self.assertRaisesRegex(ValueError, 'memory expectation'):
            checker.make_batches([entry])

    def packet_v3(self, follow=False):
        old, capture = self.packet_v2()
        entry = old['cases'][0]
        if follow:
            case = entry['fixture']
            case.update(control_follow=dict(states=1, transfers=0),
                        expected_follow_regs=list(case['expected_regs']),
                        expected_follow_st=case['expected_st'],
                        expected_follow_memory=[],
                        follow_pc=case['next_pc'] + 16, drain_instructions=1)
        batch = checker.make_batches([entry], protocol_version=3)[0]
        capture['protocol_version'] = 3
        result = capture['results'][0]
        result.extend([0] * (288 - len(result)))
        result[274] = 0xf
        if follow:
            result[203:208] = [1, 80, case['expected_follow_st'], case['follow_pc'], 0x0300]
            result[208:212] = case['expected_follow_regs']
            result[272] = 80
            result[276] = 0xf
        return batch, capture

    def test_v3_descriptor_drain_and_follow_layout(self):
        batch, capture = self.packet_v3(follow=True)
        desc = batch['descriptors'][0]
        self.assertEqual(len(desc), 16)
        self.assertEqual(desc[12:], [1, batch['cases'][0]['fixture']['follow_pc'], 0, 0])
        self.assertEqual(checker.check_batch(batch, capture)['failed'], 0)
        entry = batch['cases'][0]
        entry['fixture']['drain_instructions'] = -2
        self.assertEqual(checker.make_batches([entry], protocol_version=3)[0]['descriptors'][0][12],
                         0xfffffffe)
        for drain in (-3, 0x80000000, True):
            entry['fixture']['drain_instructions'] = drain
            with self.assertRaisesRegex(ValueError, 'drain mode'):
                checker.make_batches([entry], protocol_version=3)

    def test_v3_valid_sentinel_register_and_missing_validity(self):
        batch, capture = self.packet_v3()
        batch['cases'][0]['fixture']['expected_regs'][0] = 0xdead0000
        capture['results'][0][8] = 0xdead0000
        self.assertEqual(checker.check_batch(batch, capture)['failed'], 0)
        capture['results'][0][274] &= ~1
        self.assertEqual(checker.check_batch(batch, capture)['failed'], 1)

    def test_v3_following_state_clocks_association_and_validity(self):
        for slot in (203, 204, 205, 206, 207, 208, 272, 276):
            batch, capture = self.packet_v3(follow=True)
            if slot == 207:
                capture['results'][0][slot] = 0x10000
            elif slot == 272:
                capture['results'][0][slot] = 72
            else:
                capture['results'][0][slot] ^= 1
            self.assertEqual(checker.check_batch(batch, capture)['failed'], 1, slot)
        batch, capture = self.packet_v3(follow=True)
        capture['results'][0][203] = 2
        self.assertIn('following capture count', '\n'.join(checker.check_batch(batch, capture)['cases'][0]['errors']))

    def test_v3_following_memory_and_extra_registers(self):
        batch, capture = self.packet_v3(follow=True)
        case, result = batch['cases'][0]['fixture'], capture['results'][0]
        case.update(observe_implicit=True, expected_follow_extra_regs={'b4': 0x1234},
                    initial_memory=[(0x4000, 0x1111)], expected_follow_memory=[(0x4000, 0x2222)])
        result[73:76] = [1, 0x4000, 0x2222]
        result[228] = 0x1234
        result[276] |= 1 << 20
        self.assertEqual(checker.check_batch(batch, capture)['failed'], 0)
        # Fixture pairs become arrays across the manifest JSON boundary.
        reloaded = json.loads(json.dumps(batch))
        self.assertEqual(checker.check_batch(reloaded, capture)['failed'], 0)
        result[228] ^= 1
        self.assertEqual(checker.check_batch(batch, capture)['failed'], 1)
        result[228] ^= 1
        result[75] ^= 1
        self.assertEqual(checker.check_batch(batch, capture)['failed'], 1)

    def test_v3_padding_and_unrequested_follow_are_checked(self):
        for slot in (202, 203, 204, 208, 272, 273, 276, 278, 287):
            batch, capture = self.packet_v3()
            capture['results'][0][slot] = 0x10000 if slot == 202 else 1
            self.assertEqual(checker.check_batch(batch, capture)['failed'], 1, slot)
        batch, _ = self.packet_v3()
        entry = batch['cases'][0]
        for field in ('expected_memory', 'expected_follow_regs'):
            entry['fixture'][field] = []
            with self.assertRaisesRegex(ValueError, 'unhandled'):
                checker.make_batches([entry], protocol_version=3)
            del entry['fixture'][field]

    def test_v3_following_cross_backend_comparison(self):
        batch, capture = self.packet_v3(follow=True)
        rows = checker.check_batch(batch, capture)['cases']
        self.assertEqual(checker.compare_reference(rows, copy.deepcopy(rows)), [])
        for field in ('clock', 'a0', 'st'):
            reference = copy.deepcopy(rows)
            reference[0]['observed_follow'][field] += 1
            self.assertTrue(checker.compare_reference(rows, reference), field)

    def packet_v4(self):
        old, capture = self.packet_v3()
        entry = old['cases'][0]
        entry['external_events'] = [
            dict(trigger=0, argument=0, control=1),
            dict(trigger=0, argument=1, control=0),
            dict(trigger=0, argument=2, control=16),
            dict(trigger=5, argument=1, control=0),
        ]
        batch = checker.make_batches([entry], protocol_version=4)[0]
        capture['protocol_version'] = 4
        result = capture['results'][0]
        result[278:287] = [4, 4, 0, 0, 1, 1, 0, 4, 0]
        capture['events'] = [[68, 0, 0, 1 << 20]]
        for index, (clock, event) in enumerate(zip((65, 66, 67, 69), entry['external_events'])):
            capture['events'].append([clock, event['trigger'] << 16 | event['control'],
                                      event['argument'], 1 << 14 | index << 15])
        capture['event_count'] = len(capture['events'])
        return batch, capture

    def test_v4_control_and_event_table_staging(self):
        batch, capture = self.packet_v4()
        self.assertEqual(checker.check_batch(batch, capture)['failed'], 0)
        entry, desc = batch['cases'][0], batch['descriptors'][0]
        self.assertEqual(desc[14:], [4, len(entry['program_words'])])
        # Each entry is argument low/high, control, trigger, all little endian.
        self.assertEqual(batch['program_words'][desc[15]:],
                         [0, 0, 1, 0, 1, 0, 0, 0, 2, 0, 16, 0, 1, 0, 0, 5])
        for version in (1, 2, 3):
            with self.assertRaisesRegex(ValueError, 'external events'):
                checker.make_batches([entry], protocol_version=version)

    def test_v4_missing_wrong_or_reordered_stimuli_fail(self):
        for mutation in ('clock', 'trigger', 'argument', 'control', 'drop', 'duplicate', 'order'):
            with self.subTest(mutation=mutation):
                batch, capture = self.packet_v4()
                if mutation in ('clock', 'argument'):
                    capture['events'][1][0 if mutation == 'clock' else 2] += 1
                elif mutation == 'trigger':
                    capture['events'][1][1] |= 3 << 16
                elif mutation == 'control':
                    capture['events'][1][1] ^= 2
                elif mutation == 'drop':
                    capture['events'].pop()
                elif mutation == 'duplicate':
                    capture['events'].append(copy.deepcopy(capture['events'][-1]))
                else:
                    capture['events'][1:3] = reversed(capture['events'][1:3])
                capture['event_count'] = len(capture['events'])
                try:
                    report = checker.check_batch(batch, capture)
                except ValueError:
                    continue
                self.assertEqual(report['failed'], 1)

    def test_v4_counters_sticky_error_and_reserved_tail_fail(self):
        for word in range(278, 288):
            batch, capture = self.packet_v4()
            capture['results'][0][word] ^= 1
            self.assertEqual(checker.check_batch(batch, capture)['failed'], 1, word)

    def test_v4_host_ack_and_appendix_association_fail(self):
        for mutation in ('missing_ack', 'duplicate_ack', 'runtime_after_appendix',
                         'wrong_case', 'reserved', 'bad_encoding'):
            with self.subTest(mutation=mutation):
                batch, capture = self.packet_v4()
                if mutation == 'missing_ack':
                    capture['events'].pop(0)
                elif mutation == 'duplicate_ack':
                    capture['events'].insert(0, copy.deepcopy(capture['events'][0]))
                elif mutation == 'runtime_after_appendix':
                    capture['events'].append(capture['events'].pop(0))
                elif mutation == 'wrong_case':
                    capture['events'][1][3] |= 1 << 9
                elif mutation == 'reserved':
                    capture['events'][1][3] |= 1 << 20
                else:
                    capture['events'][1][1] = 6 << 16
                capture['event_count'] = len(capture['events'])
                try:
                    report = checker.check_batch(batch, capture)
                except ValueError:
                    continue
                self.assertEqual(report['failed'], 1)

    def test_v4_stimuli_do_not_waive_architecture_or_instruction_timing(self):
        for word in (2, 6, 8):
            batch, capture = self.packet_v4()
            capture['results'][0][word] ^= 1
            self.assertEqual(checker.check_batch(batch, capture)['failed'], 1, word)
        batch, capture = self.packet_v4()
        # A self-consistent event/pause record is not an independent ISA oracle.
        batch['cases'][0]['external_events'][0]['control'] |= 32
        capture['events'][1][1] |= 32
        capture['results'][0][286] = 1
        capture['results'][0][72] = 1
        capture['results'][0][2] += 1
        self.assertEqual(checker.check_batch(batch, capture)['failed'], 1)

    def test_v4_independent_early_cen_contract_and_corruption(self):
        for clocks in (1, 7, 8):
            old, capture = self.packet_v3()
            entry = old['cases'][0]
            entry['external_contract'] = dict(kind='early_cen', clocks=clocks)
            entry['external_events'] = [dict(trigger=0, argument=0, control=32),
                                        dict(trigger=0, argument=clocks, control=0)]
            batch = checker.make_batches([entry], protocol_version=4)[0]
            capture['protocol_version'] = 4
            result = capture['results'][0]
            result[2] += clocks
            result[72] = clocks
            result[278:287] = [2, 2, 0, 0, 0, 0, 0, clocks, clocks]
            capture['events'] = [[65, 32, 0, 1 << 14],
                                 [65+clocks, 0, clocks, 1 << 14 | 1 << 15]]
            capture['event_count'] = 2
            rows = checker.check_batch(batch, capture)
            self.assertEqual(rows['failed'], 0, rows)
            self.assertEqual(rows['cases'][0]['external_observation']['paused'], clocks)
            for word in (2, 6, 8, 72, 286):
                wrong = copy.deepcopy(capture)
                wrong['results'][0][word] ^= 1
                self.assertEqual(checker.check_batch(batch, wrong)['failed'], 1, word)
            # Both the fixed declaration and event observations participate in
            # cross-backend checks; neither can be dropped from one backend.
            other = copy.deepcopy(rows['cases'])
            other[0]['external_observation']['events'][0][0] += 1
            self.assertTrue(checker.compare_reference(rows['cases'], other))


if __name__ == '__main__':
    unittest.main()
