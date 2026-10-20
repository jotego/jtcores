#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Reject stale RMW reads and wrong dependent-load timing with correct memory."""
import importlib.util
from pathlib import Path
import sys
import unittest

import byte_store_event_oracle as oracle


def fixtures():
    path=Path(__file__).resolve().parent.parent/'store_dependency/byte_events_cases.py'
    spec=importlib.util.spec_from_file_location('byte_event_fixture_tests',path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module


class ByteStoreEventOracleTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        module=fixtures()
        cls.following=[c for c,w in module.following_cases()]
        cls.hold=[c for c,w in module.hold_cases()]

    def trace(self,case,*,following=False,restart=False):
        # One-word absolute store, literal fixture contents, with all physical
        # transfers. A synthetic HOLD lies after the read at state6; restart
        # inserts a new read at state9, keeping the final write unchanged.
        address=0x6000;old=0x9b6d;new=0x9b00
        self.assertEqual(dict(case['expected_memory'])[address],new)
        plan=[(0,case['test_pc']+16,0x6000,0),(0,case['test_pc']+32,0,0),
              (0,case['next_pc'],case['expected_next_opcode'],1),
              (0,address,old,0)]
        starts=[0,2,4,6]
        if restart:plan.append((0,address,old,0));starts.append(9)
        plan.append((1,address,new,0));starts.append(11 if restart else 9)
        if following:
            starts=[0,2,4,6,8,10,12]
            plan+=[(0,address,new,0),(0,case['next_pc']+16,0x0300,1)]
        result=[]
        for state,(kind,address,value,iaq) in zip(starts,plan):
            for prefix,offset,length in [('BUS',0,16),('TARGET',2,4)]:
                clock=1000+state*8+offset
                result.extend([f'{prefix}_BEGIN {clock} {kind} {address:08x} {value:04x} {iaq}',
                               f'{prefix}_END {clock+length} {kind} {address:08x} {value:04x} {iaq}'])
        return result

    def test_independent_following_counts_with_wait_overlap(self):
        # Literals from Table13-1/2/4 plus the documented hidden-pair policy,
        # independently enumerated for B/F absolute and B/B,B/F copies.
        counts={(False,0):[(128,216),(184,296),(296,456)],
                (False,15):[(192,280),(272,384),(432,592)],
                (True,0):[(128,216),(176,288),(272,432)],
                (True,15):[(168,264),(240,360),(384,552)]}
        for case in self.following:
            copy='data_copy' in case;offset=case['data_store']['address']&15
            key=(copy,0 if offset<=8 else 15)
            delay=case['byte_store_event']['delay']
            for index,wait in enumerate((0,1,3)):
                expected=counts[key][index][int(delay!=0)]
                self.assertEqual(oracle.following_clocks(case,wait),expected)
            for pause in (1,7):
                self.assertEqual(oracle.following_clocks(case,1,pause),counts[key][1][int(delay!=0)]+8)

    def test_first_pass_images_and_complete_following_state(self):
        for case in self.following+self.hold:
            self.assertEqual(case['measure_pass'],0)
            if 'data_copy' in case:self.assertEqual(case['memory_before_measured'],case['initial_memory'])
        case=self.following[0]
        lines=self.trace(case,following=True)
        lines += [f'MEMORY {a:08x} {v:04x}' for a,v in case['expected_memory']]
        fields={f'a{q}':v for q,v in enumerate(case['expected_follow_regs'])}
        fields['st']=case['expected_follow_st']
        lines += ['FOLLOW clock=1128 '+' '.join(f'{k}={v:08x}' for k,v in fields.items()),
                  'FOLLOW_EXTRA '+' '.join(f'{k}={v:08x}' for k,v in case['expected_follow_extra_regs'].items())]
        text='\n'.join(lines)
        self.assertEqual(oracle.check_observation(case,dict(start=1000),text,0)['errors'],[])
        for old,new in [('clock=1128','clock=1136'),('a1=00000000','a1=00000001'),
                        ('st='+f'{case["expected_follow_st"]:08x}','st=00000000'),
                        ('FOLLOW_EXTRA','MISSING_EXTRA')]:
            self.assertNotEqual(old,new);self.assertIn(old,text)
            self.assertTrue(oracle.check_observation(case,dict(start=1000),text.replace(old,new),0)['errors'])

    def test_granted_hold_requires_fresh_read_even_if_memory_is_correct(self):
        case=self.hold[0];edges=[(1067,1),(1071,0)]
        stale=self.trace(case)
        valid=self.trace(case,restart=True)
        for raw in (False,True):
            self.assertEqual(oracle.check_bus(case,dict(start=1000),valid,0,raw=raw,hold_edges=edges),[])
            errors=oracle.check_bus(case,dict(start=1000),stale,0,raw=raw,hold_edges=edges)
            self.assertTrue(any('stale read across HOLD' in e for e in errors))
            self.assertTrue(oracle.check_bus(case,dict(start=1000),valid,0,raw=raw))

    def test_hold_cannot_grant_over_or_launch_a_physical_cycle(self):
        case=self.hold[0];lines=self.trace(case,restart=True)
        for edges in ([(1051,1),(1055,0)],[(1071,1),(1081,0)]):
            for raw in (False,True):
                self.assertTrue(oracle.check_bus(case,dict(start=1000),lines,0,raw=raw,hold_edges=edges))

    def test_decode_and_load_opcode_must_precede_dependent_work(self):
        case=self.following[0];lines=self.trace(case,following=True)
        for raw in (False,True):
            self.assertTrue(any('primary decode' in e for e in oracle.check_bus(
                case,dict(start=1000,end=1037),lines,0,raw=raw)))
        # Move the load's opcode until after the data read without changing
        # any transaction payload or the final architectural snapshot.
        blocks=[lines[q:q+4] for q in range(0,len(lines),4)]
        opcode=blocks.pop(2);blocks.insert(5,opcode)
        changed=[]
        for q,block in enumerate(blocks):
            for line in block:
                parts=line.split();parts[1]=str(1000+16*q+(2 if parts[0].startswith('TARGET') else 0)+(4 if parts[0]=='TARGET_END' else 16 if parts[0]=='BUS_END' else 0));changed.append(' '.join(parts))
        for raw in (False,True):
            self.assertTrue(any('load opcode' in e for e in oracle.check_bus(case,dict(start=1000),changed,0,raw=raw)))

    def test_following_data_cannot_precede_modifying_write(self):
        case=self.following[0];lines=self.trace(case,following=True)
        # Swap entire allocations, preserving counts/data/final memory.
        blocks=[lines[q:q+4] for q in range(0,len(lines),4)]
        blocks[4],blocks[5]=blocks[5],blocks[4]
        changed=[]
        for q,block in enumerate(blocks):
            for line in block:
                parts=line.split();parts[1]=str(1000+16*q+(2 if parts[0].startswith('TARGET') else 0)+(4 if parts[0]=='TARGET_END' else 16 if parts[0]=='BUS_END' else 0));changed.append(' '.join(parts))
        for raw in (False,True):
            self.assertTrue(oracle.check_bus(case,dict(start=1000),changed,0,raw=raw))

    def test_complete_bus_timing_readiness_and_register_snapshot_are_required(self):
        case=self.following[0];lines=self.trace(case,following=True)
        self.assertEqual(oracle.check_bus(case,dict(start=1000),lines,0),[])
        self.assertEqual(oracle.check_bus(case,dict(start=1000),lines,0,raw=True),[])
        for raw in (False,True):
            self.assertTrue(oracle.check_bus(case,dict(start=1000),lines[:-4],0,raw=raw))
            prefix='TARGET' if raw else 'BUS'
            changed=[s.replace('0300','0301') if s.startswith(prefix+'_END ') else s for s in lines]
            self.assertTrue(oracle.check_bus(case,dict(start=1000),changed,0,raw=raw))
            changed=list(lines);index=3 if raw else 1
            parts=changed[index].split();parts[1]=str(int(parts[1])+1);changed[index]=' '.join(parts)
            self.assertTrue(oracle.check_bus(case,dict(start=1000),changed,0,raw=raw))
        self.assertTrue(oracle.check_bus(case,dict(start=1000),[s for s in lines if s.startswith('TARGET')],0,raw=True))

    def test_reference_hold_phase_release_and_counters_are_independent(self):
        directory=Path(__file__).resolve().parent.parent/'store_dependency'
        spec=importlib.util.spec_from_file_location('byte_event_reference_checker_test',directory/'check_byte_events.py')
        module=importlib.util.module_from_spec(spec)
        previous=list(sys.path)
        try:
            sys.path.insert(0,str(directory));spec.loader.exec_module(module)
        finally:sys.path[:]=previous
        text=('STIMULUS 1001 0 0 00000000 0004\nHOLD_ACK 1004 1\n'
              'STIMULUS 1007 1 4 00000003 0000\nHOLD_ACK 1008 0\n'
              'EXTERNAL_RESULT configured=2 applied=2 writes=0 holds=4 hosts=0 issued=0 error=0 last=6 paused=0')
        self.assertEqual(module.check_reference_events(text,dict(start=1000),0),[])
        for old,new in [('1001','1002'),('1007','1006'),('applied=2','applied=1'),
                        ('error=0','error=1'),('holds=4','holds=3'),('00000003','00000002')]:
            self.assertTrue(module.check_reference_events(text.replace(old,new),dict(start=1000),0))


if __name__=='__main__':
    unittest.main()
