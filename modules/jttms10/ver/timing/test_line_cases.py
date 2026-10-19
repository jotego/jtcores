#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""LINE geometry, status, memory and bus checker anchors; no RTL execution."""
import unittest
from line_cases import fixture, line_cases, program, transfers, check_bus, xy
from mutations import correct_architecture
from run import check, movi, parse_result


class LineCasesTest(unittest.TestCase):
    def observation(self, row, **extra):
        observed = dict(row['initial_all_regs'])
        observed.update(row['expected_extra_regs'])
        observed.update(st=row['expected_st'],wvp=row['expected_wvp'],
                        clocks=row['states']*8,start=0,end=row['states']*8,paused=0)
        observed.update(extra)
        return observed

    def test_inventory_and_independent_programs(self):
        cases = list(line_cases())
        self.assertEqual(len(cases),626)
        self.assertEqual(len({x['name'] for x in cases}),626)
        for row in cases:
            words,pc,nxt = program(row,movi)
            self.assertEqual(words[(pc-0x1000)//16],row['opcode'])
            self.assertEqual(nxt,pc+16)
            self.assertLessEqual(len(row['initial_memory']),64)
            self.assertEqual(row['expected_st_mask'],0x1FFFFFFF)
            self.assertNotIn('b13',row['expected_extra_regs'])
            self.assertNotIn('b14',row['expected_extra_regs'])

    def test_tie_rules_and_pointer_writeback(self):
        zero = fixture(16,1,0,False,a=2,b=1,d=0)
        one = fixture(16,1,1,False,a=2,b=1,d=0)
        self.assertEqual((zero['expected_extra_regs']['b0'],zero['expected_extra_regs']['b2']),
                         (2,xy(17,16)))
        self.assertEqual((one['expected_extra_regs']['b0'],one['expected_extra_regs']['b2']),
                         (0xFFFFFFFE,xy(17,17)))
        self.assertEqual(zero['expected_extra_regs']['b10'],0)

    def test_literal_guide_geometry_and_119_states(self):
        row = next(r for r in line_cases() if r['name'].endswith('guide_119_hit'))
        self.assertEqual(row['states'],119)
        self.assertEqual(row['line_timing']['drawn'],23)
        self.assertEqual(row['line_timing']['outside'],0)
        self.assertEqual(row['expected_extra_regs']['b2'],0x0055001A)
        self.assertEqual(row['expected_extra_regs']['b0'],0xFFFFFFF6)
        self.assertEqual(row['expected_extra_regs']['b10'],0)

    def test_zero_count_has_no_memory_traffic(self):
        row = fixture(4,0,0,False)
        self.assertEqual((row['states'],transfers(row)),(4,[]))
        self.assertEqual(row['initial_memory'],row['expected_memory'])
        self.assertEqual(row['expected_extra_regs']['b2'],xy(16,16))

    def test_word_preservation_and_full_word_writes(self):
        row = fixture(4,2,0,False,color=4)
        old,after = dict(row['initial_memory']),dict(row['expected_memory'])
        address = row['data_line']['pixels'][0][0] & ~15
        self.assertEqual(after[address],(old[address] & ~255)|0x44)
        self.assertEqual(transfers(row),[(0,address,old[address],0),
            (1,address,(old[address] & ~15)|4,0),
            (0,address,(old[address] & ~15)|4,0),(1,address,after[address],0)])
        self.assertEqual(transfers(fixture(16,1,0,False)),[(1,0xE100,65535,0)])

    def test_window_abort_and_wvp_are_architectural(self):
        row = fixture(4,5,0,False,a=4,b=1,window=2,wstart=(20,20),wend=(21,21))
        self.assertEqual((row['states'],row['expected_wvp'],transfers(row)),(9,1,[]))
        self.assertEqual(row['expected_extra_regs']['b10'],4)
        self.assertEqual(row['initial_memory'],row['expected_memory'])
        self.assertTrue(row['expected_st'] & 0x10000000)

    def test_only_documented_undefined_status_bits_are_masked(self):
        row = fixture(4,1,0,False)
        observed = self.observation(row)
        self.assertEqual(check(row,observed),[])
        self.assertEqual(check(row,dict(observed,st=observed['st']^0xE0000000)),[])
        for key,value in [('st',observed['st']^0x10000000),('st',observed['st']^1),
                          ('wvp',1),('b0',123),('b10',1),('sp',0),('clocks',80)]:
            self.assertTrue(check(row,dict(observed,**{key:value})),(key,value))
        result = dict(row,observed=observed,observed_memory=row['expected_memory'])
        self.assertTrue(correct_architecture(result))
        self.assertFalse(correct_architecture(dict(result,observed=dict(observed,wvp=1))))
        scalar = dict(row)
        scalar.pop('expected_st_mask')
        self.assertTrue(check(scalar,dict(observed,st=observed['st']^0xE0000000)))

    def test_wait_and_pause_counts_remain_independent(self):
        for off,clocks in ((False,96),(True,128)):
            row = fixture(4,1,0,off)
            self.assertEqual(check(row,self.observation(row,clocks=clocks,paused=7),1,7),[])

    def test_bus_contract_rejects_data_order_and_time_errors(self):
        row = fixture(4,1,0,False)
        old = dict(row['initial_memory'])[0xE040]
        data = dict(row['expected_memory'])[0xE040]
        bus = [f'BUS_BEGIN 32 0 0000e040 0000 0',f'BUS_END 48 0 0000e040 {old:04x}',
               f'BUS_BEGIN 48 1 0000e040 {data:04x} 0',f'BUS_END 64 1 0000e040 0000']
        self.assertEqual(check_bus(row,dict(start=0,end=72),bus,0),[])
        for index,line in [(0,'BUS_BEGIN 32 0 0000e050 0000 0'),(1,'BUS_END 48 0 0000e040 0000'),
                           (2,'BUS_BEGIN 40 1 0000e040 0000 0'),(3,'BUS_END 63 1 0000e040 0000')]:
            bad=bus.copy();bad[index]=line
            self.assertTrue(check_bus(row,dict(start=0,end=72),bad,0))

    def test_io_observation_protocol(self):
        self.assertEqual(parse_result('RESULT case=0 st=0\nLINE_IO wvp=1\n')['wvp'],1)
        with self.assertRaises(ValueError):
            parse_result('RESULT case=0 st=0\nLINE_IO wvp=1\nLINE_IO wvp=0\n')


if __name__ == '__main__':
    unittest.main()
