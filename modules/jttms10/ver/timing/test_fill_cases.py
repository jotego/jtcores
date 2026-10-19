#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check FILL fixture/checker contracts without executing RTL."""
import unittest
from fill_cases import fixture, fill_cases, check_bus, transfers
from run import check, program


class FillCasesTest(unittest.TestCase):
    def test_inventory_and_literal_states(self):
        cases = list(fill_cases())
        self.assertEqual(len(cases), 320)
        self.assertEqual(len({r['name'] for r in cases}), 320)
        # Table13-5 setup4/6, Table13-6 A/G2: N1=3L+2,
        # N2=6L+2, N3=7L+2. CD adds three setup states once.
        for size in (1,2,4,8,16):
            for words, rows, linear_states in ((1,1,9),(1,2,12),(2,1,12),(2,2,18),(3,1,13),(3,2,20)):
                for xy,off in ((False,False),(False,True),(True,False),(True,True)):
                    row = fixture(size, words, rows, xy, off)
                    self.assertEqual(row['states'], linear_states+2*xy+3*off)
                    code,pc,nxt = program(row)
                    self.assertEqual(code[(pc-0x1000)//16], 0x0FE0 if xy else 0x0FC0)
                    self.assertEqual(nxt, pc+16)

    def test_longer_linear_row_targets(self):
        # Literal substitutions into Table13-6, independent of any CPU trace.
        for words,rows,states in ((1,4,18),(2,3,24),(2,4,30),(3,3,27),(4,3,33),(8,4,74)):
            for size in (1,2,4,8,16):
                for off in (False,True):
                    case=fixture(size,words,rows,False,off)
                    self.assertEqual(case['states'],states+3*off)
                    self.assertEqual(len(transfers(case)),words*rows)
                    self.assertEqual(case['expected_extra_regs']['b2'],0x6100+(rows-1)*0x100+16*words)

    def test_pattern_canaries_and_defined_registers(self):
        row = fixture(1,3,2,True,False)
        before,after = dict(row['initial_memory']),dict(row['expected_memory'])
        self.assertEqual(after, {0x60F0:before[0x60F0],0x6100:0xAA55,0x6110:0xAA55,0x6120:0xAA55,
                                 0x6130:before[0x6130],0x61F0:before[0x61F0],0x6200:0xAA55,
                                 0x6210:0xAA55,0x6220:0xAA55,0x6230:before[0x6230]})
        self.assertEqual(row['expected_extra_regs']['b2'],0x6230)
        self.assertEqual(row['expected_extra_regs']['b3'],0x100)
        self.assertEqual(row['expected_extra_regs']['b7'],0x20030)
        self.assertEqual(row['expected_extra_regs']['b9'],0x5CC3AA55)
        self.assertEqual([n for n in row['expected_extra_regs'] if n.startswith('b')], [f'b{q}' for q in range(10)])

    def test_total_timing_and_state_rejections(self):
        row = fixture(16,1,1,False,False)
        observed = dict(row['initial_all_regs'],clocks=72,start=0,end=72,paused=0,st=row['expected_st'])
        observed.update(row['expected_extra_regs'])
        self.assertEqual(check(row,observed),[])
        for field,value in (('clocks',80),('st',0),('a0',0),('b2',0),('b3',0),('b7',0),('sp',0)):
            with self.subTest(field=field):
                bad=dict(observed,**{field:value})
                self.assertTrue(check(row,bad))
        for off,wait,pause,clocks in ((False,1,7,88),(True,1,7,120)):
            row=fixture(16,1,1,False,off)
            self.assertEqual(check(row,dict(observed,clocks=clocks,paused=pause),wait,pause),[])

    def test_row_cadence_rejects_compensated_total(self):
        row=fixture(16,1,2,False,False)
        observed=dict(start=0,end=96)
        bus=['BUS_BEGIN 32 1 00006100 aa55 0','BUS_END 48 1 00006100 aaaa',
             'BUS_BEGIN 56 1 00006200 aa55 0','BUS_END 72 1 00006200 bbbb']
        self.assertEqual(check_bus(row,observed,bus,0),[])
        # Keep the overall interval, order, data and16-clock bus durations.
        # Early next-row traffic cannot be hidden by later retirement padding.
        bad=bus[:2]+['BUS_BEGIN 48 1 00006200 aa55 0','BUS_END 64 1 00006200 bbbb']
        errors=check_bus(row,observed,bad,0)
        self.assertTrue(any('row cadence' in e for e in errors))

    def test_bus_rejections(self):
        row=fixture(16,2,1,False,True)
        row.update(test_pc=0x1800,next_pc=0x1810)
        observed=dict(start=0,end=120)
        bus=['BUS_BEGIN 32 1 00006100 aa55 0','BUS_END 48 1 00006100 aaaa',
             'BUS_BEGIN 48 1 00006110 aa55 0','BUS_END 64 1 00006110 bbbb',
             'BUS_BEGIN 96 0 00001810 0000 1','BUS_END 112 0 00001810 0300']
        target=['TARGET_BEGIN 34 1 00006100 aa55 0','TARGET_END 38 1 00006100 aaaa',
                'TARGET_BEGIN 50 1 00006110 aa55 0','TARGET_END 54 1 00006110 bbbb',
                'TARGET_BEGIN 98 0 00001810 0000 1','TARGET_END 102 0 00001810 0300']
        self.assertEqual(check_bus(row,observed,bus,0),[])
        self.assertEqual(check_bus(row,observed,target+bus,0,raw=True),[])
        for index,replacement in ((0,'BUS_BEGIN 32 0 00006100 aa55 0'),
                                  (0,'BUS_BEGIN 32 1 00006110 aa55 0'),
                                  (0,'BUS_BEGIN 32 1 00006100 aa54 0'),
                                  (0,'BUS_BEGIN 32 1 00006100 aa55 1'),
                                  (1,'BUS_END 47 1 00006100 aaaa'),
                                  (2,'BUS_BEGIN 40 1 00006110 aa55 0'),
                                  (5,'BUS_END 112 0 00001810 0301')):
            bad=list(bus);bad[index]=replacement
            self.assertTrue(check_bus(row,observed,bad,0),replacement)
        self.assertTrue(check_bus(row,observed,bus[:-2],0))
        self.assertTrue(check_bus(row,dict(start=0,end=110),bus,0))
        bad=list(target);bad[0]='TARGET_BEGIN 39 1 00006100 aa55 0';bad[1]='TARGET_END 43 1 00006100 aaaa'
        self.assertTrue(check_bus(row,observed,bad+bus,0,raw=True))


if __name__ == '__main__':
    unittest.main()
