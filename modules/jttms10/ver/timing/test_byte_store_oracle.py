#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Pin published CD counts and reject wrong timing or unsafe posted traffic."""
import unittest

import byte_store_oracle as oracle
from store_cases import fixture
from copy_cases import fixture as copy_fixture
from run import check, program, check_store_bus


class ByteStoreOracleTest(unittest.TestCase):
    def absolute(self,offset=0):
        case=fixture('absolute',8,offset,0,True,0,byte=True)
        _,case['test_pc'],case['next_pc']=program(case)
        return case

    def observation(self,case,wait=0,pause=0):
        return dict(start=1000,end=1000+8*(case['states']+oracle.wait_count(case)*wait)
                    +pause+(-pause)%8,
            clocks=8*(case['states']+oracle.wait_count(case)*wait)+pause+(-pause)%8,
            paused=pause,st=case['expected_st'],**case['expected_extra_regs'],
            **{f'a{q}':v for q,v in enumerate(case['expected_regs'])})

    def trace(self,case,starts,wait=0):
        lines=[]
        for state,(kind,address,data,iaq) in zip(starts,oracle.transfers(case)):
            b=1000+state*8
            for prefix,delay,length in [('BUS',0,16+8*wait),('TARGET',2,4+8*wait)]:
                lines.extend([f'{prefix}_BEGIN {b+delay} {kind} {address:08x} {data:04x} {iaq}',
                              f'{prefix}_END {b+delay+length} {kind} {address:08x} {data:04x} {iaq}'])
        return lines

    def test_literal_counts_every_byte_alignment(self):
        for offset in range(16):
            case=self.absolute(offset)
            self.assertEqual(case['states'],7 if offset<=8 else 13)
            self.assertEqual(case['drain_instructions'],-2)
            self.assertEqual(case['source_values']['policy_cd'],case['source_values']['summary_cd'])
            self.assertEqual(oracle.wait_count(case),3 if offset<=8 else 5)
        for source in range(9):
            for dest in range(9):
                case=copy_fixture(8,source,dest,0,True,0,byte=True)
                self.assertEqual(case['states'],7)
                self.assertEqual(oracle.wait_count(case),2)

    def test_other_modes_and_dependency_cases_keep_their_oracle(self):
        for mode in ('indirect','offset'):
            self.assertFalse(oracle.supported(fixture(mode,8,0,0,True,0,byte=True)))
        self.assertFalse(oracle.supported(fixture('absolute',8,0,0,False,0,byte=True)))
        self.assertFalse(oracle.supported(fixture('absolute',16,0,0,True,0)))
        self.assertFalse(oracle.supported(copy_fixture(8,9,0,0,True,0,byte=True)))
        case=self.absolute();case['dependency_conditions']={}
        self.assertFalse(oracle.supported(case))

    def test_waits_pauses_architecture_and_wrong_instruction_duration(self):
        for offset in (0,8,9,15):
            case=self.absolute(offset)
            for wait,pause in ((0,0),(1,0),(3,0),(1,1),(1,7)):
                observed=self.observation(case,wait,pause)
                self.assertEqual(check(case,observed,wait,pause),[])
                for field in ('clocks','paused','a0','b0','sp','st'):
                    mutant=dict(observed);mutant[field]^=1
                    self.assertTrue(check(case,mutant,wait,pause),field)
                # Counting waits on hidden writes against the completed
                # instruction is wrong even when architecture is unchanged.
                if wait:
                    mutant=dict(observed);mutant['clocks']+=16*wait
                    self.assertTrue(check(case,mutant,wait,pause))

    def test_complete_rmw_pairs_and_opcode_order(self):
        case=self.absolute();obs=self.observation(case)
        lines=self.trace(case,[0,2,4,6,8])
        for raw in (False,True):
            self.assertEqual(check_store_bus(case,obs,lines,0,raw=raw),[])
        # A correct memory result cannot excuse the old operand/RMW/opcode
        # ordering, a split pair, duplicate fetch, or a corrupt payload.
        for index,replacement in [(0,lines[8]),(8,lines[12]),(12,lines[16])]:
            mutant=list(lines);mutant[index]=replacement
            self.assertTrue(check_store_bus(case,obs,mutant,0))
        for prefix in ('BUS','TARGET'):
            mutant=[s.replace(' 0300 ',' 0301 ') if s.startswith(prefix+'_END ') else s for s in lines]
            self.assertTrue(check_store_bus(case,obs,mutant,0,raw=prefix=='TARGET'))
        mutant=lines+lines[8:12]
        self.assertTrue(check_store_bus(case,obs,mutant,0))

    def test_crossed_byte_retains_both_pairs(self):
        case=self.absolute(15);obs=self.observation(case)
        lines=self.trace(case,[0,2,5,7,10,12,14])
        self.assertEqual(check_store_bus(case,obs,lines,0),[])
        self.assertEqual(check_store_bus(case,obs,lines,0,raw=True),[])
        self.assertTrue(check_store_bus(case,obs,lines[:-4],0))

    def test_bus_duration_dispatch_and_hidden_drain_bounds(self):
        case=self.absolute();obs=self.observation(case)
        lines=self.trace(case,[0,2,4,6,8])
        mutant=list(lines);mutant[1]=mutant[1].replace('1016','1017')
        self.assertTrue(check_store_bus(case,obs,mutant,0))
        late=self.trace(case,[0,2,4,7,9])
        self.assertTrue(check_store_bus(case,obs,late,0))
        shifted=[s.replace('TARGET_BEGIN 1002','TARGET_BEGIN 1007') for s in lines]
        self.assertTrue(check_store_bus(case,obs,shifted,0,raw=True))
        self.assertTrue(check_store_bus(case,obs,[s for s in lines if not s.startswith('BUS')],0,raw=True))


if __name__=='__main__':
    unittest.main()
