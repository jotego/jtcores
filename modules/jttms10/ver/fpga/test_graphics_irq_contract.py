#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Host guards for the bounded native LINE interrupt runtime contract."""
import copy
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import check_results
import event_contract
import graphics_irq_cases
import graphics_irq_contract


def sample_trace(entry):
    kind = entry['external_contract']['interrupt']
    vector = 0xffffffc0 if kind == 'lint1' else 0xfffffee0
    initial = dict(entry['fixture']['expected_memory'])
    stack = initial
    transfers = [(1,0x0320,0x7fff)]
    transfers.extend((1,address,stack[address]) for address in (0x2ff0,0x2fe0,0x2fd0,0x2fc0))
    transfers.extend(((0,vector,0x4000),(0,vector+16,0)))
    transfers.extend((0,address,stack[address]) for address in (0x2fc0,0x2fd0,0x2fe0,0x2ff0))
    transfers.extend((1,address,data) for address,data in graphics_irq_contract.PIXEL_WRITES[1:])
    clocks=[100,120,140,160,180,200,220,250,270,290,310,425,445,465]
    lines=[]
    for q,((we,address,data),start) in enumerate(zip(transfers,clocks)):
        accept=start+2
        target_end=accept+4
        bus_end=start+16
        lines.extend((f'BUS_BEGIN {start} {we} {address:08x} {data:04x} 0',
                      f'BUS_ACCEPT {accept}',
                      f'TARGET_BEGIN {accept} {we} {address:08x} {data:04x} 0',
                      f'TARGET_END {target_end} {we} {address:08x} {data:04x}',
                      f'BUS_END {bus_end} {we} {address:08x} {data:04x}'))
    if kind == 'nmi':
        lines.extend(('STIMULUS 107 0 1 00000001 0110','HOST_ACK 108',
                      'STIMULUS 109 1 5 00000001 0000'))
    else:
        lines.extend(('STIMULUS 107 0 1 00000001 0001',
                      'STIMULUS 109 1 1 00000005 0000'))
    lines.append('IRQ_BOUNDARY count=1 previous=0 complete=245 first=405')
    lines.extend(f'MEMORY {address:08x} {value:04x}'
                 for address,value in entry['fixture']['expected_memory'])
    return lines


class GraphicsIRQContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows = graphics_irq_cases.entries(check_results.oracle_module())

    def test_independent_literal_programs_validate(self):
        self.assertEqual([graphics_irq_contract.validate(row) for row in self.rows],
                         ['lint1', 'nmi'])
        self.assertFalse(event_contract.check_duration(self.rows[0]))
        self.assertTrue(event_contract.check_duration({'fixture': {'name': 'ordinary'}}))
        self.assertFalse(event_contract.check_transfer_observation(self.rows[1]))
        self.assertTrue(event_contract.check_transfer_observation({'fixture': {'name': 'ordinary'}}))

    def test_program_event_setup_and_vector_tampering_fail_closed(self):
        mutations = []
        row = copy.deepcopy(self.rows[0]); row['program_words'][5] ^= 1; mutations.append(row)
        row = copy.deepcopy(self.rows[0]); row['fixture']['setup_io'] = list(map(list, row['fixture']['setup_io'])); row['fixture']['setup_io'][0][1] ^= 1; mutations.append(row)
        row = copy.deepcopy(self.rows[0]); row['fixture']['next_pc'] += 16; mutations.append(row)
        row = copy.deepcopy(self.rows[0]); row['external_events'][0]['argument'] = 2; mutations.append(row)
        row = copy.deepcopy(self.rows[1]); row['fixture']['initial_memory'] = list(map(list, row['fixture']['initial_memory'])); row['fixture']['initial_memory'][-2][0] = 0xffffffe0; mutations.append(row)
        row = copy.deepcopy(self.rows[0]); row['fixture']['measure_pass'] = 1; mutations.append(row)
        row = copy.deepcopy(self.rows[0]); row['fixture']['expected_extra_regs']['b2'] ^= 1; mutations.append(row)
        row = copy.deepcopy(self.rows[0]); row['fixture']['expected_memory'][0] = (0x310, 0); mutations.append(row)
        for bad in mutations:
            with self.subTest(name=bad['name']):
                with self.assertRaises(ValueError):
                    graphics_irq_contract.validate(bad)

    def test_transfer_waiver_validates_complete_graphics_contract(self):
        bad = copy.deepcopy(self.rows[0])
        bad['program_words'][5] ^= 1
        with self.assertRaises(ValueError):
            event_contract.check_transfer_observation(bad)

    def test_complete_trace_positive_and_transport_negatives(self):
        entry = self.rows[0]
        observed = dict(start=90,end=600,clocks=510)
        lines = sample_trace(entry)
        errors, _ = graphics_irq_contract.check(entry, observed, lines)
        self.assertEqual(errors, [])

        cases = []
        bad = lines.copy(); bad[0] = 'BUS_BEGIN 100 1 00009990 7fff 0'; cases.append((bad,'data BUS transaction'))
        bad = lines.copy(); bad[2] = 'TARGET_BEGIN 102 1 00000320 7ffe 0'; cases.append((bad,'TARGET transaction 0 request data'))
        bad = lines.copy(); bad.remove('BUS_ACCEPT 122'); cases.append((bad,'request/accept/response count'))
        bad = lines.copy(); bad.extend(('BUS_BEGIN 600 1 00009990 1234 0','BUS_ACCEPT 602',
                                        'TARGET_BEGIN 602 1 00009990 1234 0',
                                        'TARGET_END 606 1 00009990 0000',
                                        'BUS_END 616 1 00009990 0000')); cases.append((bad,'unexpected data BUS transaction'))
        bad = lines.copy(); bad.extend(('BUS_BEGIN 600 0 00009990 0000 1','BUS_ACCEPT 602',
                                        'TARGET_BEGIN 602 0 00009990 0000 1',
                                        'TARGET_END 606 0 00009990 0000',
                                        'BUS_END 616 0 00009990 0000')); cases.append((bad,'outside literal program/handler image'))
        bad = lines.copy(); bad.append('BUS_ACCEPT 999'); cases.append((bad,'request/accept/response count'))
        bad = lines.copy();
        for q,line in enumerate(bad):
            if line.startswith('TARGET_BEGIN 202 '): bad[q]=line.replace('TARGET_BEGIN 202','TARGET_BEGIN 100202')
            elif line.startswith('TARGET_END 206 '): bad[q]=line.replace('TARGET_END 206','TARGET_END 100206')
            elif line=='BUS_ACCEPT 202': bad[q]='BUS_ACCEPT 100202'
        cases.append((bad,'outside its logical BUS interval'))
        bad=lines.copy();bad[-len(dict(entry['fixture']['expected_memory']))-1]='IRQ_BOUNDARY count=1 previous=0 complete=235 first=395';cases.append((bad,'precedes completion of the second vector read'))
        bad=lines.copy();bad[-len(dict(entry['fixture']['expected_memory']))-1]='IRQ_BOUNDARY count=1 previous=10 complete=245 first=405';cases.append((bad,'unordered context/first-ISR boundaries'))
        for candidate,needle in cases:
            with self.subTest(needle=needle):
                errors,_=graphics_irq_contract.check(entry,observed,candidate)
                self.assertTrue(any(needle in error for error in errors),errors)

    def test_missing_runtime_observations_reject(self):
        errors, _ = graphics_irq_contract.check(
            self.rows[0], dict(start=1000,end=1100,clocks=100), [])
        joined = '\n'.join(errors)
        self.assertIn('final pixel memory', joined)
        self.assertIn('context/first-ISR boundaries', joined)
        self.assertIn('applied interrupt/release events', joined)


if __name__ == '__main__':
    unittest.main()
