#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Host checks for the narrowly scoped protocol-v5 CD dependency adapter."""
import copy
import json
import unittest

import check_results as checker


class StoreDependencyFPGA(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.oracle = checker.oracle_module()
        cls.entries = checker.prepare_store_dependency_cases(5, dict(
            wait_states=0, pause_clocks=0, pause_after_clocks=0))
        cls.dependency = checker.store_dependency_checker()

    def test_explicit_family_inventory_and_v5_batch_roundtrip(self):
        self.assertEqual(len(self.entries), 16)
        batch, = checker.make_batches(self.entries, protocol_version=5)
        self.assertEqual(len(batch['cases']), 16)
        roundtrip = json.loads(json.dumps(batch))
        self.assertEqual([entry['fixture']['dependency_conditions'] for entry in roundtrip['cases']],
                         [entry['fixture']['dependency_conditions'] for entry in batch['cases']])
        for entry in roundtrip['cases']:
            checker.require_supported(entry['fixture'], 5)

    def test_dependency_metadata_is_strict_and_fail_closed(self):
        valid = self.entries[0]['fixture']
        checker.validate_store_dependency(valid, 5)
        bad_cases = []
        for key in ('destination', 'offset', 'preceding_word', 'next_opcode_modified'):
            case = copy.deepcopy(valid)
            del case['dependency_conditions'][key]
            bad_cases.append((case, 'keys'))
        case = copy.deepcopy(valid); case['dependency_conditions']['unexpected'] = 1
        bad_cases.append((case, 'keys'))
        case = copy.deepcopy(valid); case['dependency_conditions']['offset'] = True
        bad_cases.append((case, 'offset'))
        case = copy.deepcopy(valid); case['dependency_conditions']['preceding_word'] = 1
        bad_cases.append((case, 'booleans'))
        case = copy.deepcopy(valid); case['dependency_conditions']['destination'] ^= 16
        bad_cases.append((case, 'destination'))
        case = copy.deepcopy(valid); case['dependency_conditions']['offset'] = (case['dependency_conditions']['offset'] + 1) & 15
        bad_cases.append((case, 'offset'))
        case = copy.deepcopy(valid); case['dependency_conditions']['next_opcode_modified'] = not case['dependency_conditions']['next_opcode_modified']
        bad_cases.append((case, 'flag'))
        case = copy.deepcopy(valid); case['data_store']['width'] = 16
        bad_cases.append((case, 'byte'))
        case = copy.deepcopy(valid); case['cache_disabled'] = False
        bad_cases.append((case, 'cache-disabled'))
        case = copy.deepcopy(valid); case['measure_pass'] = 1
        bad_cases.append((case, 'first pass'))
        case = copy.deepcopy(valid); case['drain_instructions'] = -1
        bad_cases.append((case, 'drain'))
        for case, message in bad_cases:
            with self.subTest(message=message, conditions=case['dependency_conditions']):
                with self.assertRaisesRegex(ValueError, message):
                    checker.require_supported(case, 5)
        with self.assertRaisesRegex(ValueError, 'protocol 5'):
            checker.require_supported(valid, 4)

    def trace(self, case, wait_states=0):
        leading, stores, opcode = self.dependency.transfers(case)
        expected = leading + stores + [opcode]
        bus, target = [], []
        for index, (kind, address, value, iaq) in enumerate(expected):
            start = 100 + index * (40 + 8 * wait_states)
            bus.extend((f'BUS_BEGIN {start} {kind} {address:08x} {value:04x} {iaq}',
                        f'BUS_END {start + 16 + 8*wait_states} {kind} {address:08x} {value:04x}'))
            target_start = start + 2
            target.extend((f'TARGET_BEGIN {target_start} {kind} {address:08x} {value:04x} {iaq}',
                           f'TARGET_END {target_start + 4 + 8*wait_states} {kind} {address:08x} {value:04x}'))
        return bus, target

    def test_exact_trace_checks_and_mutations(self):
        for entry in self.entries:
            case = entry['fixture']
            bus, target = self.trace(case, 1)
            self.assertEqual(self.dependency.check_trace(case, bus, 1), [], case['name'])
            self.assertEqual(self.dependency.check_trace(case, target, 1, raw=True), [], case['name'])
            bad_bus = bus.copy()
            bad_bus[0] = bad_bus[0].replace(f'{int(bad_bus[0].split()[3],16):08x}', '00009990')
            self.assertTrue(self.dependency.check_trace(case, bad_bus, 1))
            bad_target = target.copy()
            fields = bad_target[1].split(); fields[1] = str(int(fields[1]) + 1); bad_target[1] = ' '.join(fields)
            self.assertTrue(self.dependency.check_trace(case, bad_target, 1, raw=True))
            if case['dependency_conditions']['next_opcode_modified']:
                # The opcode fetch may not be moved ahead of the write that changes it.
                entries = [line.split() for line in bus if line.startswith('BUS_BEGIN ')]
                fetch_index = next(i for i, words in enumerate(entries) if int(words[5]) == 1)
                write_index = next(i for i, words in enumerate(entries)
                                   if int(words[2]) == 1 and int(words[3], 16) == case['next_pc'])
                if fetch_index > write_index:
                    starts = [line for line in bus if line.startswith('BUS_BEGIN ')]
                    ends = [line for line in bus if line.startswith('BUS_END ')]
                    starts[fetch_index], starts[write_index] = starts[write_index], starts[fetch_index]
                    ends[fetch_index], ends[write_index] = ends[write_index], ends[fetch_index]
                    reordered = []
                    for begin, end in zip(starts, ends): reordered.extend((begin, end))
                    errors = self.dependency.check_trace(case, reordered, 1)
                    self.assertTrue(any('opcode fetch preceded' in error for error in errors), errors)

    def test_duration_exemption_is_validated_and_family_scoped(self):
        dependency = self.entries[0]['fixture']
        entry = self.entries[0]
        self.assertFalse(checker.instruction_duration_required(dependency, entry))
        malformed = copy.deepcopy(dependency)
        malformed['dependency_conditions']['offset'] ^= 1
        with self.assertRaisesRegex(ValueError, 'offset'):
            checker.instruction_duration_required(malformed, entry)
        ordinary = next(case for case in self.oracle.cases() if case['name'] == 'nop_hit')
        self.assertTrue(checker.instruction_duration_required(ordinary, {'fixture': ordinary}))
        published_base = next(case for case in self.oracle.cases()
                               if case.get('coverage_id') in ('MOVB_R_ABS', 'MOVB_IND_IND')
                               and self.oracle.published_duration_case(case) is not None)
        published = self.oracle.published_duration_case(published_base)
        self.assertIsNotNone(published)
        self.assertTrue(checker.instruction_duration_required(published, {'fixture': published}))
        observed = dict(clocks=dependency['states']*8 + 8, paused=0,
                        st=dependency['expected_st'])
        for index, value in enumerate(dependency['expected_regs']): observed[f'a{index}'] = value
        self.assertFalse(any('expected' in error and 'INCLK' in error for error in
                             self.oracle.check(dependency, observed, check_duration=False)))
        self.assertTrue(any('INCLK' in error for error in self.oracle.check(dependency, observed,
                            check_duration=True)))
        for case in (ordinary, published):
            observed = dict(clocks=(case['states'] + 1) * 8, paused=0,
                            st=case['expected_st'])
            for index, value in enumerate(case['expected_regs']): observed[f'a{index}'] = value
            self.assertTrue(checker.instruction_duration_required(case, {'fixture': case}))
            self.assertTrue(any('INCLK' in error for error in self.oracle.check(
                case, observed, check_duration=checker.instruction_duration_required(
                    case, {'fixture': case}))))
            words, test_pc, next_pc = self.oracle.program(copy.deepcopy(case))
            fixture = copy.deepcopy(case)
            fixture.update(test_pc=test_pc, next_pc=next_pc)
            entry = dict(id=3, name=fixture['name'], fixture=fixture,
                         program_words=words, test_pc=test_pc, next_pc=next_pc)
            batch, = checker.make_batches([entry], protocol_version=5)
            result = [0] * checker.RESULT_SIZES[5]
            next_opcode = fixture.get('expected_next_opcode', words[(next_pc-0x1000)//16])
            result[:8] = [3, 2, (fixture['states'] + 1) * 8, test_pc, next_pc,
                          next_opcode, fixture['expected_st'], 100]
            result[8:8+len(fixture['expected_regs'])] = fixture['expected_regs']
            initial = fixture.get('initial_memory', [])
            result[73] = len(initial)
            for index, (address, value) in enumerate(fixture.get('expected_memory', initial)):
                result[74+2*index:76+2*index] = [address, value]
            result[274] = 0xffff
            raw = dict(protocol_version=5, status=2, event_count=0,
                       results=[result], events=[])
            batch_errors = checker.check_batch(batch, raw)['cases'][0]['errors']
            self.assertTrue(any('INCLK' in error for error in batch_errors), batch_errors)

    def make_raw_capture(self, entry, *, clocks=1000, events=True):
        case = entry['fixture']
        result = [0] * checker.RESULT_SIZES[5]
        result[:8] = [entry['id'], 2, clocks, entry['test_pc'], entry['next_pc'],
                      case['expected_next_opcode'], case['expected_st'], 104]
        for index, value in enumerate(case['expected_regs']):
            result[8+index] = value
        for name, value in case.get('expected_extra_regs', {}).items():
            result[8+checker.register_slot(name)] = value
        result[72] = 0
        memory = case.get('expected_memory', [])
        result[73] = len(memory)
        for index, (address, value) in enumerate(memory):
            result[74+2*index:76+2*index] = [address, value]
        result[272] = result[7] + clocks + 1
        result[274] = 0xffffffff
        result[275] = 0xffffffff
        transactions = []
        raw_events = []
        if events:
            leading, stores, opcode = self.dependency.transfers(case)
            data_store = case.get('data_store', {})
            extension_count = len(case.get('extensions', []))
            lead = data_store.get('write_start', data_store.get('cpu', 1) - 1)
            first = lead + (3 + 0) * extension_count
            starts = [1 + q * 4 for q in range(extension_count)]
            starts.extend(first + q * 2 for q in range(len(stores)))
            starts.append(first + len(stores) * 2)
            transactions = leading + stores + [opcode]
            for index, ((kind, address, value, iaq), offset) in enumerate(zip(transactions, starts)):
                start = result[7] + offset * 8
                common = (kind << 1) | iaq
                for clock, flags, data in (
                    (start, common | (1 << 6), value << 16),
                    (start + 2, common | (1 << 8), value << 16),
                    (start + 6, common | (1 << 7), value),
                    (start + 16, common | (1 << 5), value),
                ):
                    raw_events.append([clock, data, address, flags])
        result[278:288] = [0, 0, sum(bool(item[0]) for item in transactions), 0, 0,
                           0, 0, 0, 0, 0]
        return dict(protocol_version=5, status=2, event_count=len(raw_events),
                    results=[result], events=raw_events)

    def test_check_batch_dependency_capture_and_full_check_mutations(self):
        entry = self.entries[0]
        batch, = checker.make_batches([entry], protocol_version=5)
        capture = self.make_raw_capture(entry)
        rows = checker.check_batch(batch, capture)
        self.assertEqual(rows['failed'], 0, rows)
        # Total clocks are deliberately outside the dependency fixture's
        # instruction-duration contract; all other observations stay checked.
        slower = copy.deepcopy(capture)
        slower['results'][0][2] += 800
        slower['results'][0][272] += 800
        self.assertEqual(checker.check_batch(batch, slower)['failed'], 0)

        mutations = {
            'register': lambda c: c['results'][0].__setitem__(8, c['results'][0][8] ^ 1),
            'ST': lambda c: c['results'][0].__setitem__(6, c['results'][0][6] ^ 1),
            'pause': lambda c: c['results'][0].__setitem__(72, 1),
            'memory': lambda c: c['results'][0].__setitem__(75, c['results'][0][75] ^ 1),
            'opcode': lambda c: c['results'][0].__setitem__(5, c['results'][0][5] ^ 1),
            'BUS': lambda c: c['events'][0].__setitem__(2, c['events'][0][2] ^ 16),
            'TARGET': lambda c: c['events'][1].__setitem__(2, c['events'][1][2] ^ 16),
        }
        for label, mutate in mutations.items():
            with self.subTest(mutation=label):
                changed = copy.deepcopy(capture)
                mutate(changed)
                self.assertGreater(checker.check_batch(batch, changed)['failed'], 0)

        # Corrupt the address on both raw records for the RMW read.
        rmw = copy.deepcopy(capture)
        destination = entry['fixture']['dependency_conditions']['destination']
        for event in rmw['events']:
            if (event[2] == destination and not (event[3] & (1 | 2)) and
                    (event[3] & ((1 << 6) | (1 << 5)))):
                event[2] ^= 16
        rmw_report = checker.check_batch(batch, rmw)
        self.assertGreater(rmw_report['failed'], 0)
        self.assertTrue(any('RMW read' in error for error in
                            rmw_report['cases'][0]['dependency_observation']['bus_errors']))

    def test_dependency_named_fixture_without_metadata_fails_closed(self):
        case = copy.deepcopy(self.entries[0]['fixture'])
        del case['dependency_conditions']
        with self.assertRaisesRegex(ValueError, 'malformed dependency_conditions'):
            checker.require_supported(case, 5)
        entry = copy.deepcopy(self.entries[0])
        del entry['fixture']['dependency_conditions']
        batch, = checker.make_batches([self.entries[0]], protocol_version=5)
        batch['cases'][0] = entry
        with self.assertRaisesRegex(ValueError, 'malformed dependency_conditions'):
            checker.check_batch(batch, self.make_raw_capture(self.entries[0]))

    def test_dependency_reference_wrapper_normalizes_fixture_schema(self):
        case = self.entries[0]['fixture']
        row = dict(name=case['name'], fixture=copy.deepcopy(case),
                   observed=dict(start=10, end=20, clocks=10, paused=0, st=case['expected_st'],
                                 **{f'a{q}': value for q, value in enumerate(case['expected_regs'])}),
                   observed_memory=copy.deepcopy(case['expected_memory']),
                   observed_next_opcodes=[case['expected_next_opcode']],
                   bus_trace=['BUS_BEGIN 10 0 00001300 0000 0'],
                   target_trace=['TARGET_BEGIN 10 0 00001300 0000 0'], errors=[])
        actual = {**copy.deepcopy(case), **{key: value for key, value in row.items() if key != 'fixture'}}
        self.assertEqual(checker.compare_reference([actual], [row]), [])
        changed = copy.deepcopy(row)
        changed['fixture']['dependency_conditions']['offset'] ^= 1
        self.assertIn('fixture dependency_conditions differs',
                      checker.compare_reference([actual], [changed])[0])


if __name__ == '__main__':
    unittest.main()
