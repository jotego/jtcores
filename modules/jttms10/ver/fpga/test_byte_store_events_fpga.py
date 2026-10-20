#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Host-side protocol-v5 adapter tests for CD byte-store event fixtures."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import types
import unittest

import check_results as checker


class ByteStoreEventsFPGA(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.oracle = checker.oracle_module()
        cls.cases_module, cls.event_oracle = checker.byte_store_event_modules()

    def entries(self, kind, wait=0, pause=0, phase=0):
        return checker.prepare_byte_store_event_cases(kind, 5, dict(
            wait_states=wait, pause_clocks=pause, pause_after_clocks=0), phase)

    def capture(self, entry, *, wait=None, pause=None, add_hold_restart=True):
        """Build a complete synthetic v5 raw capture, not a normalized row."""
        case = entry['fixture']
        stimulus = checker.stimulus_for(entry)
        wait = stimulus['wait_states'] if wait is None else wait
        pause = stimulus['pause_clocks'] if pause is None else pause
        kind = case['byte_store_event']['kind']
        start = 104 if pause == 0 else (8 - (pause + (-pause) % 8) % 8) % 8 + 104
        event_model = self.event_oracle
        leading, stores, reads, opcodes = event_model.transfer_plan(case)
        hold_restart_position = None
        hold_read_position = None
        if kind == 'following':
            delay = case['byte_store_event']['delay']
            # The first accepted opcode can overlap the final RMW work. Later
            # NOPs, the dependent reads, and the post-load opcode must follow
            # in causal order.
            transactions = (leading + stores[:-2] + opcodes[:1] + stores[-2:] +
                            opcodes[1:delay + 1] + reads + opcodes[delay + 1:])
        else:
            transactions = leading + stores + reads + opcodes
        if kind == 'hold' and add_hold_restart:
            write = next(transaction for transaction in stores if transaction[0])
            read_index = max(index for index, transaction in enumerate(transactions)
                             if transaction == (0, write[1], next(t[2] for t in stores
                                 if t[0] == 0 and t[1] == write[1]), 0))
            transactions.insert(read_index + 1, transactions[read_index])
            hold_read_position = read_index
            hold_restart_position = read_index + 1

        raw_events = []
        transaction_clock_ranges = []
        base_gap = 16 + 8 * wait
        hold_phase = entry.get('byte_store_event_profile', {}).get('hold_phase', 0)
        hold_request = start + hold_phase + 1
        if kind == 'hold' and hold_read_position is not None:
            prior_offset = (pause + (-pause) % 8) + hold_read_position * base_gap
            hold_read_end = start + prior_offset + base_gap
            grant_clock = max(hold_request, hold_read_end)
            hold_release_request = grant_clock + 3
            release_clock = hold_release_request + 1
        else:
            grant_clock = hold_request
            hold_release_request = grant_clock + 3
            release_clock = hold_release_request + 1
        next_hold_clock = start + (pause + (-pause) % 8)
        for index, (transfer_kind, address, value, iaq) in enumerate(transactions):
            if kind == 'hold':
                if index == hold_restart_position:
                    next_hold_clock = max(next_hold_clock,
                        ((release_clock + 7) // 8) * 8)
                when = next_hold_clock
                next_hold_clock += base_gap
            else:
                when = start + (pause + (-pause) % 8) + index * base_gap
            common = (transfer_kind << 1) | iaq
            records = [
                (when, common | (1 << 6), (value & 0xffff) << 16),
                (when + 2, common | (1 << 8), (value & 0xffff) << 16),
                (when + 6 + 8 * wait, common | (1 << 7), value & 0xffff),
                (when + 16 + 8 * wait, common | (1 << 5), value & 0xffff),
            ]
            first = len(raw_events)
            for clock, flags, data in records:
                raw_events.append([clock, data, address, flags])
            transaction_clock_ranges.append((first, len(raw_events), when, transfer_kind, address))

        hold_edges = []
        stimulus_records = []
        if kind == 'hold':
            hold_edges = [(grant_clock, 1), (release_clock, 0)]
            case_id = entry['id']
            for clock, level in hold_edges:
                raw_events.append([clock, 0, 0, (1 << 19) | (level << 18)])

        result = [0] * checker.RESULT_SIZES[5]
        bytestore = event_model.byte_store_oracle
        if bytestore.supported(case):
            transfer_count = bytestore.wait_count(case)
        elif 'data_copy' in case:
            copy_reads, copy_writes = event_model.copy_transactions(case)
            transfer_count = len(copy_reads) + (len(copy_writes) + 1 + len(case.get('extensions', [])))
        else:
            transfer_count = len(event_model.store_transactions(case)) + 1 + len(case.get('extensions', []))
        primary = case['states'] * 8 + transfer_count * wait * 8
        alignment = pause + (-pause) % 8 if transfer_count else 0
        primary += alignment
        result[:8] = [entry['id'], 2, primary, entry['test_pc'], entry['next_pc'],
                      case['expected_next_opcode'], case['expected_st'], start]
        result[72] = pause
        for index, value in enumerate(case['expected_regs']):
            result[8 + index] = value
        for name, value in case.get('expected_extra_regs', {}).items():
            result[8 + checker.register_slot(name)] = value
        result[73] = len(case['initial_memory'])
        final_memory = dict(case['expected_memory'])
        for index, (address, _) in enumerate(case['initial_memory']):
            result[74 + 2*index:76 + 2*index] = [address, final_memory[address]]
        result[274:276] = [0xffffffff, 0xffffffff]
        result[280] = sum(transfer[0] for transfer in transactions)

        follow_clock = 0
        if kind == 'following':
            follow_clock = start + event_model.following_clocks(case, wait, pause)
            result[203:208] = [1, follow_clock, case['expected_follow_st'],
                               case['follow_pc'], 0x0300]
            for index, value in enumerate(case['expected_follow_regs']):
                result[208 + index] = value
            for name, value in case['expected_follow_extra_regs'].items():
                result[208 + checker.register_slot(name)] = value
            result[276:278] = [0xffffffff, 0xffffffff]

        finish = max(start + primary + 8, follow_clock + 1,
                     max((end for _, end, _, _, _ in transaction_clock_ranges), default=start) + 1,
                     hold_edges[-1][0] + 1 if hold_edges else 0)
        if kind == 'hold':
            # HOLD has no primary-duration contract, but the returned primary
            # interval must still contain the opcode response it reports.
            opcode_ends = [event[0] for event in raw_events
                           if event[3] & 1 and event[3] & (1 << 5)]
            if opcode_ends:
                result[2] = max(result[2], max(opcode_ends) - start)
                finish = max(finish, start + result[2] + 1)
        result[272] = finish
        if kind == 'hold':
            writes = sum(transfer[0] for transfer in transactions)
            result[278:288] = [2, 2, writes, release_clock - grant_clock, 0, 0, 0,
                               hold_release_request - start - 1, 0, 0]

        # Scheduler records are the protocol-v5 appendix and follow all live
        # bus records in the returned event buffer.
        for index, event in enumerate(entry.get('external_events', [])):
            trigger, argument, control = (event[key] for key in ('trigger', 'argument', 'control'))
            clock = start + argument + 1 if trigger == 0 else hold_release_request
            flags = (1 << 14) | (index << 15)
            stimulus_records.append([clock, (trigger << 16) | control, argument, flags])
        raw_events.sort(key=lambda record: record[0])
        raw_events.extend(stimulus_records)
        capture = dict(protocol_version=5, status=2, event_count=len(raw_events),
                       results=[result], events=raw_events)
        return capture, transaction_clock_ranges

    def test_cli_selection_profiles_and_canonical_inventory(self):
        following = self.entries('following')
        self.assertEqual(len(following), 16)
        self.assertEqual(len(checker.make_batches(following, 5)), 1)
        hold = self.entries('hold', wait=1, phase=24)
        self.assertEqual(len(hold), 4)
        self.assertEqual(hold[0]['external_events'], [
            dict(trigger=0, argument=24, control=4), dict(trigger=4, argument=3, control=0)])
        with self.assertRaisesRegex(ValueError, 'protocol-version 5'):
            checker.prepare_byte_store_event_cases('hold', 4)
        with self.assertRaisesRegex(ValueError, 'unsupported following'):
            self.entries('following', wait=2)
        with self.assertRaisesRegex(ValueError, 'no CEN pause'):
            self.entries('hold', wait=1, pause=1)
        with self.assertRaisesRegex(ValueError, 'malformed byte_store_event'):
            malformed = copy.deepcopy(following[0]['fixture'])
            del malformed['byte_store_event']
            checker.require_supported(malformed, 5)
        with self.assertRaisesRegex(ValueError, 'byte store operation|selected byte-store'):
            malformed = copy.deepcopy(following[0]['fixture'])
            malformed['data_store']['width'] = 16
            checker.require_supported(malformed, 5)
        self.assertTrue(checker.instruction_duration_required(following[0]['fixture'], following[0]))
        hold_fixture = hold[0]['fixture']
        self.assertFalse(checker.instruction_duration_required(hold_fixture, hold[0]))
        changed_hold = copy.deepcopy(hold_fixture)
        changed_hold['data_store']['address'] ^= 16
        with self.assertRaisesRegex(ValueError, 'fixture differs'):
            checker.instruction_duration_required(changed_hold, hold[0])
        ordinary = checker.prepare_cases(['nop_hit'], protocol_version=5)[0]
        published = checker.prepare_cases([], protocol_version=5, published_targets=True)[0]
        self.assertTrue(checker.instruction_duration_required(ordinary['fixture'], ordinary))
        self.assertTrue(checker.instruction_duration_required(published['fixture'], published))

        cli = Path(checker.__file__)
        with tempfile.TemporaryDirectory() as temp:
            for kind, extra in (('following', []), ('hold', ['--hold-phase', '52'])):
                output = Path(temp) / f'{kind}.json'
                subprocess.run([sys.executable, str(cli), 'prepare', '--byte-store-events', kind,
                    '--protocol-version', '5', *extra, '--output', str(output)],
                    check=True, capture_output=True, text=True)
                manifest = json.loads(output.read_text())
                self.assertEqual(checker.validate_manifest(manifest), 5)
                damaged = copy.deepcopy(manifest)
                damaged['batches'][0]['cases'].pop()
                with self.assertRaisesRegex(ValueError, 'inventory differs'):
                    checker.validate_manifest(damaged)
                damaged = copy.deepcopy(manifest)
                damaged['byte_store_event_sources_sha256']['timing/run.py'] = '0' * 64
                with self.assertRaisesRegex(ValueError, 'source hashes differ'):
                    checker.validate_manifest(damaged)

    def test_check_batch_following_full_observation_and_mutations(self):
        entries = self.entries('following', wait=1, pause=1)
        rows = []
        for wait, pause in ((0, 0), (1, 0), (3, 0), (1, 1), (1, 7)):
            profile_entries = self.entries('following', wait=wait, pause=pause)
            profile_rows = []
            for entry in profile_entries:
                batch, = checker.make_batches([entry], 5)
                capture, _ = self.capture(entry)
                report = checker.check_batch(batch, capture)
                self.assertEqual(report['failed'], 0, (entry['name'], wait, pause, report))
                profile_rows.extend(report['cases'])
            references = [self.reference_row(row, entry)
                          for row, entry in zip(profile_rows, profile_entries)]
            self.assertEqual(checker.compare_reference(profile_rows, references), [])
            rows.extend(profile_rows)
        entry = entries[0]
        batch, = checker.make_batches([entry], 5)
        original, ranges = self.capture(entry)
        mutations = {
            'A register': lambda raw: raw['results'][0].__setitem__(8, raw['results'][0][8] ^ 1),
            'ST': lambda raw: raw['results'][0].__setitem__(6, raw['results'][0][6] ^ 1),
            'pause': lambda raw: raw['results'][0].__setitem__(72, 0),
            'memory': lambda raw: raw['results'][0].__setitem__(75, raw['results'][0][75] ^ 1),
            'next opcode': lambda raw: raw['results'][0].__setitem__(5, raw['results'][0][5] ^ 1),
            'BUS address': lambda raw: next(event for event in raw['events']
                if event[3] & (1 << 6)).__setitem__(2, 0xDEAD),
            'TARGET address': lambda raw: next(event for event in raw['events']
                if event[3] & (1 << 8)).__setitem__(2, 0xDEAD),
            'following load clock': lambda raw: raw['results'][0].__setitem__(204,
                raw['results'][0][204] + 8),
        }
        for label, mutate in mutations.items():
            with self.subTest(mutation=label):
                changed = copy.deepcopy(original)
                mutate(changed)
                self.assertGreater(checker.check_batch(batch, changed)['failed'], 0)
        altered_reference = copy.deepcopy(references[0])
        altered_reference['observed_follow']['clock'] += 8
        self.assertTrue(checker.compare_reference([rows[0]], [altered_reference]))
        changed_profile = copy.deepcopy(references[0])
        changed_profile['kind'] = 'hold'
        self.assertTrue(checker.compare_reference([rows[0]], [changed_profile]))
        self.assertEqual(checker.compare_reference([rows[0]], [rows[0]]), [])
        changed_actual_profile = copy.deepcopy(rows[0])
        changed_actual_profile['byte_store_event_profile'] = {'kind': 'hold'}
        self.assertTrue(checker.compare_reference([changed_actual_profile], [rows[0]]))
        explicit_reference = copy.deepcopy(rows[0])
        explicit_reference['kind'] = 'hold'
        self.assertTrue(checker.compare_reference([rows[0]], [explicit_reference]))

        damaged_program = copy.deepcopy(entry)
        damaged_program['program_words'][0] ^= 1
        with self.assertRaisesRegex(ValueError, 'program or measurement interval'):
            checker.make_batches([damaged_program], 5)

    def test_check_batch_hold_restart_and_duration_scope(self):
        entries = self.entries('hold', wait=0, phase=40)
        entry = next(item for item in entries if item['name'].startswith('copy_'))
        batch, = checker.make_batches([entry], 5)
        capture, ranges = self.capture(entry)
        report = checker.check_batch(batch, capture)
        self.assertEqual(report['failed'], 0, report)
        row = report['cases'][0]
        self.assertEqual(row['hold_edges'], [(capture['results'][0][7] + 41, 1),
                                              (capture['results'][0][7] + 45, 0)])
        reference = self.reference_row(row, entry)
        self.assertEqual(checker.compare_reference([row], [reference]), [])
        changed_external = copy.deepcopy(reference)
        changed_external['external_observation']['hold_edges'][0][0] += 1
        self.assertTrue(checker.compare_reference([row], [changed_external]))
        slower = copy.deepcopy(capture)
        slower['results'][0][2] += 800
        slower['results'][0][272] += 800
        self.assertEqual(checker.check_batch(batch, slower)['failed'], 0)

        # Remove the post-grant repeated destination read. Architecture and
        # memory remain unchanged; the physical RMW freshness contract rejects it.
        restart_index, (_, _, restart_clock, _, _) = next(
            (index, item) for index, item in enumerate(ranges)
            if item[2] >= capture['results'][0][7] + 48 and item[3] == 0 and
            item[4] == entry['fixture']['data_store']['address'])
        broken = copy.deepcopy(capture)
        lo, hi, _, _, _ = ranges[restart_index]
        restart_times = {restart_clock, restart_clock + 2, restart_clock + 6,
                         restart_clock + 16}
        broken['events'] = [event for event in broken['events'] if event[0] not in restart_times]
        broken['event_count'] = len(broken['events'])
        failed = checker.check_batch(batch, broken)
        self.assertGreater(failed['failed'], 0)
        self.assertTrue(any('RMW' in error or 'inventory' in error
                            for error in failed['cases'][0]['errors']), failed)

        bad_schedule = copy.deepcopy(batch)
        bad_schedule['cases'][0]['external_events'][0]['argument'] += 1
        with self.assertRaisesRegex(ValueError, 'scheduler events'):
            checker.check_batch(bad_schedule, capture)
        malformed = copy.deepcopy(entry['fixture'])
        malformed['byte_store_event']['kind'] = 'unknown'
        with self.assertRaisesRegex(ValueError, 'unknown byte_store_event'):
            checker.instruction_duration_required(malformed, entry)

    def test_source_loader_restores_ambient_module_aliases(self):
        names = ('run', 'copy_cases', 'store_cases', 'byte_store_oracle', 'oracle')
        prior_modules = {name: sys.modules.get(name) for name in names}
        prior_path = list(sys.path)
        prior_cache = checker._byte_store_event_modules
        sentinels = {name: types.ModuleType('ambient_'+name) for name in names}
        try:
            for name, module in sentinels.items():
                sys.modules[name] = module
            sys.path.insert(0, '/tmp/ambient-byte-event-import-sentinel')
            checker._byte_store_event_modules = None
            cases_module, event_module = checker.byte_store_event_modules()
            self.assertEqual(len(list(cases_module.following_cases())), 16)
            self.assertTrue(callable(event_module.check_observation))
            for name, module in sentinels.items():
                self.assertIs(sys.modules.get(name), module, name)
            self.assertEqual(sys.path, prior_path[:0] +
                             ['/tmp/ambient-byte-event-import-sentinel'] + prior_path)
        finally:
            checker._byte_store_event_modules = prior_cache
            sys.path[:] = prior_path
            for name, module in prior_modules.items():
                if module is None:
                    sys.modules.pop(name, None)
                else:
                    sys.modules[name] = module

    def test_check_batch_all_hold_fixture_shapes(self):
        # Phase 52 places grant after the two absolute-address operand reads
        # and the first RMW read; copies need fewer leading reads.
        for wait in (0, 1):
            for phase in (40, 52):
                entries = self.entries('hold', wait=wait, phase=phase)
                self.assertEqual(len(entries), 4)
                for entry in entries:
                    with self.subTest(wait=wait, phase=phase, name=entry['name']):
                        batch, = checker.make_batches([entry], 5)
                        capture, _ = self.capture(entry)
                        report = checker.check_batch(batch, capture)
                        self.assertEqual(report['failed'], 0, report)

    @staticmethod
    def reference_row(row, entry):
        """Shape an independent-runner style reference around fixture expectations."""
        fixture = entry['fixture']
        reference = dict(name=entry['name'], kind=fixture['byte_store_event']['kind'],
                         profile='base', wait_states=0, pause_clocks=0,
                         hold_phase=entry.get('byte_store_event_profile', {}).get('hold_phase'),
                         fixture=copy.deepcopy(fixture), observed=copy.deepcopy(row['observed']),
                         errors=[], external_observation=copy.deepcopy(row['external_observation']),
                         bus_trace=copy.deepcopy(row['bus_trace']),
                         target_trace=copy.deepcopy(row['target_trace']))
        for key in ('observed_follow', 'observed_memory', 'observed_next_opcodes', 'hold_edges'):
            if key in row:
                reference[key] = copy.deepcopy(row[key])
        return reference


if __name__ == '__main__':
    unittest.main()
