#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check PIXBLT fixture data, register, bus and rejection contracts."""
import copy
import sys
import unittest
from pathlib import Path
from blit_cases import MODES, blit_cases, fixture, transfers, check_bus
from run import program, check, check_observation


class BlitCasesTest(unittest.TestCase):
    def test_complete_encoding_inventory_and_programs(self):
        rows=list(blit_cases())
        self.assertEqual(len(rows),464)
        self.assertEqual(len({r['name'] for r in rows}),464)
        self.assertEqual({r['coverage_id'] for r in rows},
                         {'PIXBLT_'+m.upper() for m in MODES})
        for row in rows:
            code,pc,nxt=program(row)
            self.assertEqual(code[(pc-0x1000)//16],MODES[row['data_blit']['mode']])
            self.assertEqual(nxt,pc+16)
            self.assertLessEqual(len(row['initial_memory']),64)

    def test_independent_pixel_values_and_canaries(self):
        for size in (1,2,4,8,16):
            row=fixture('ll',size,3,2,False)
            before,after=map(dict,(row['initial_memory'],row['expected_memory']))
            for line in range(2):
                for word in range(3):
                    self.assertEqual(after[0x6000+256*line+16*word],
                                     before[0x5000+256*line+16*word])
                self.assertEqual(after[0x5FF0+256*line],before[0x5FF0+256*line])
                self.assertEqual(after[0x6030+256*line],before[0x6030+256*line])
            self.assertEqual({k:v for k,v in before.items() if k<0x6000},
                             {k:v for k,v in after.items() if k<0x6000})
        # 12-175 permits dithering: COLOR0=2468/COLOR1=ACE1 select
        # destination-aligned nibbles, with source low bits0110.
        self.assertEqual(dict(fixture('bl',4,1,1,False)['expected_memory'])[0x6000],0x2CE8)
        self.assertEqual(dict(fixture('bl',1,1,1,False)['expected_memory'])[0x6000],0xA4E8)
        self.assertEqual(dict(fixture('bl',16,1,1,False)['expected_memory'])[0x6000],0x2468)

    def test_defined_registers_and_xy_conversion(self):
        for mode in MODES:
            row=fixture(mode,16,1,2,False)
            self.assertEqual(row['expected_extra_regs']['b0'],0x5200)
            self.assertEqual(row['expected_extra_regs']['b2'],0x6200)
            self.assertEqual(row['expected_extra_regs']['b1'],0x100)
            self.assertEqual(row['expected_extra_regs']['b3'],0x100)
            self.assertEqual(row['expected_extra_regs']['b7'],0x20001)
            self.assertTrue(all('b'+str(q) not in row['expected_extra_regs'] for q in range(10,15)))

    def test_waits_pauses_and_only_defined_status_bits(self):
        for mode,off,wait,pause in (('ll',False,0,0),('bxy',True,1,7)):
            row=fixture(mode,16,1,2,off)
            count=len(transfers(row))+int(off)
            clocks=row['states']*8+8*wait*count+pause+(-pause)%8
            seen=dict(row['initial_all_regs'],clocks=clocks,paused=pause,st=row['expected_st'])
            seen.update(row['expected_extra_regs'])
            self.assertEqual(check(row,seen,wait,pause),[])
            self.assertEqual(check(row,dict(seen,st=seen['st']^0xF0000000),wait,pause),[])
            for field,value in (('clocks',clocks+8),('st',seen['st']^0x20),('b0',0),('b2',0),('sp',0)):
                self.assertTrue(check(row,dict(seen,**{field:value}),wait,pause))

    def test_word_sequence_and_compensated_row_delay_rejected(self):
        row=fixture('ll',16,1,2,False)
        plan=transfers(row)
        starts=(32,48,80,96)
        lines=[]
        for start,(kind,addr,data,iaq) in zip(starts,plan):
            lines.extend((f'BUS_BEGIN {start} {kind} {addr:08x} {data:04x} {iaq}',
                          f'BUS_END {start+16} {kind} {addr:08x} {data:04x}'))
        seen=dict(start=0,end=192)
        self.assertEqual(check_bus(row,seen,lines,0),[])
        shifted=lines[:4]+[line.replace('80 ','72 ').replace('96 ','88 ').replace('112 ','104 ')
                           for line in lines[4:]]
        self.assertTrue(any('row cadence' in e for e in check_bus(row,seen,shifted,0)))
        wrong=lines.copy();wrong[0]=wrong[0].replace('00005000','00005010')
        self.assertTrue(any('address' in e for e in check_bus(row,seen,wrong,0)))
        wrong=lines.copy();wrong[1]=wrong[1][:-4]+'ffff'
        self.assertTrue(any('response' in e for e in check_bus(row,seen,wrong,0)))
        self.assertTrue(check_bus(row,seen,lines[:-2],0))

    def test_source_buffering_is_allowed_but_unread_data_is_not(self):
        row=fixture('ll',16,2,1,False)
        canonical=transfers(row)
        # Both source reads may precede both writes. The TI table does not
        # prescribe an interleaving or a first-write phase for this domain.
        buffered=[canonical[q] for q in (0,2,1,3)]
        def trace(plan):
            lines=[]
            for q,(kind,addr,data,iaq) in enumerate(plan):
                start=32+16*q
                lines.extend((f'BUS_BEGIN {start} {kind} {addr:08x} {data:04x} {iaq}',
                              f'BUS_END {start+16} {kind} {addr:08x} {data:04x}'))
            return lines
        self.assertEqual(check_bus(row,dict(start=0,end=176),trace(buffered),0),[])
        unread=[canonical[q] for q in (1,0,2,3)]
        errors=check_bus(row,dict(start=0,end=176),trace(unread),0)
        self.assertTrue(any('before its source' in e for e in errors))

    def test_fpga_requires_v3_and_preserves_the_new_fixture(self):
        sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'fpga'))
        from check_results import require_supported, compare_reference
        row=fixture('ll',16,1,1,False)
        require_supported(row,3)
        with self.assertRaises(ValueError):
            require_supported(row,2)
        row['errors']=[]
        row['observed']=dict(clocks=144,st=row['expected_st'],paused=0,
                             **{f'a{q}':v for q,v in enumerate(row['expected_regs'])},
                             **row['expected_extra_regs'])
        other=copy.deepcopy(row);other['data_blit']['words']=2
        self.assertTrue(any('data_blit' in e for e in compare_reference([row],[other])))

    def test_shared_verdict_rejects_destination_and_neighbor_corruption(self):
        row=fixture('ll',16,1,1,False)
        code,pc,nxt=program(row)
        row.update(test_pc=pc,next_pc=nxt)
        observed=dict(row['initial_all_regs'],start=0,end=144,clocks=144,
                      paused=0,st=row['expected_st'])
        observed.update(row['expected_extra_regs'])
        bus=[]
        for q,(kind,addr,data,iaq) in enumerate(transfers(row)):
            start=32+16*q
            bus.extend((f'BUS_BEGIN {start} {kind} {addr:08x} {data:04x} {iaq}',
                        f'BUS_END {start+16} {kind} {addr:08x} {data:04x}',
                        f'TARGET_BEGIN {start} {kind} {addr:08x} {data:04x} {iaq}',
                        f'TARGET_END {start+4} {kind} {addr:08x} {data:04x}'))
        def verdict(memory):
            log='\n'.join(bus+[f'MEMORY {a:08x} {v:04x}' for a,v in memory])
            return check_observation(row,observed,check(row,observed),log)
        result=verdict(row['expected_memory'])
        self.assertEqual(result['errors'],[])
        self.assertEqual(result['observed_memory'],row['expected_memory'])
        for address in (0x5000,0x5FF0,0x6000,0x6010):
            bad=[(a,v^1 if a==address else v) for a,v in row['expected_memory']]
            self.assertIn('graphics destination or neighboring memory mismatch',verdict(bad)['errors'])


if __name__=='__main__':
    unittest.main()
