#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Check FILL fixture/checker contracts without executing RTL."""
import unittest
from fill_cases import (fixture, partial_fixture, boolean_fixture, arithmetic_word,
                        arithmetic_fixture, plane_mask_fixture, fill_cases, check_bus, transfers)
from run import check, program


class FillCasesTest(unittest.TestCase):
    def test_plane_mask_literal_timing_and_inventory(self):
        rows=[r for r in fill_cases() if r['name'].startswith('fill_plane_')]
        self.assertEqual(len(rows),5184)
        # Table13-7 G4/6/7/8, Table13-6 A for N1L1/N2L1/N1L2.
        for ppop,one,two in ((0,11,16),(10,13,20),(16,13,20),(17,14,22),(19,15,24)):
            for words,nrows,want in ((1,1,one),(2,1,two),(1,2,two)):
                for xy,off in ((False,False),(False,True),(True,False),(True,True)):
                    row=plane_mask_fixture(4,ppop,xy,off,words=words,rows=nrows)
                    self.assertEqual(row['states'],want+2*xy+3*off)
                    self.assertEqual(len(transfers(row)),(2 if ppop==0 else 3)*words*nrows)

    def test_plane_mask_literal_pixels_and_destination_preprocessing(self):
        replace=plane_mask_fixture(4,0,False,False)
        self.assertEqual(dict(replace['initial_memory'])[0x6100],0x55aa)
        self.assertEqual(dict(replace['expected_memory'])[0x6100],0xbb44)
        xor=plane_mask_fixture(4,10,False,False)
        self.assertEqual(dict(xor['expected_memory'])[0x6100],0xffee)
        add=plane_mask_fixture(4,16,False,False,sample=2)
        sub=plane_mask_fixture(4,18,False,False,sample=2)
        # Mask destination1 to0 before adding/subtracting sourceF per lane.
        self.assertEqual(dict(add['expected_memory'])[0x6100],0xffff)
        self.assertEqual(dict(sub['expected_memory'])[0x6100],0x1111)
        full=plane_mask_fixture(8,0,True,True,words=2,rows=2,pmask=65535)
        self.assertEqual(full['initial_memory'],full['expected_memory'])
        self.assertEqual(len(transfers(full)),8)  # Mask alone does not skip writes.
        for row in (replace,xor,add,sub,full):
            before,after=map(dict,(row['initial_memory'],row['expected_memory']))
            mask=row['conditions']['pmask']
            for address,value in before.items():
                self.assertEqual(after[address]&mask,value&mask)
            self.assertEqual(after[0x60f0],before[0x60f0])
            self.assertEqual(row['expected_extra_regs']['b9'],row['register_overrides']['b9'])

    def test_plane_mask_separate_processing_and_final_rmw_reads(self):
        # Figure7-6: CPU destination read, processing, then final masked RMW.
        # Replace omits the processing read; Table13-7 G4/6 matches 2/3 cycles.
        replace=plane_mask_fixture(4,0,False,False)
        xor=plane_mask_fixture(4,10,False,False)
        self.assertEqual(transfers(replace),[(0,0x6100,0x55aa,0),(1,0x6100,0xbb44,0)])
        self.assertEqual(transfers(xor),[(0,0x6100,0x55aa,0),(0,0x6100,0x55aa,0),
                                         (1,0x6100,0xffee,0)])

    def test_plane_mask_rejects_invalid_domain(self):
        for size,ppop,mask in ((1,16,65535),(2,21,65535),(4,22,0x1111),
                               (4,0,1),(8,0,0),(16,0,65536)):
            with self.assertRaises(ValueError):
                plane_mask_fixture(size,ppop,False,False,pmask=mask)

    def test_inventory_and_literal_states(self):
        cases = list(fill_cases())
        self.assertEqual(len(cases), 11372)
        self.assertEqual(len({r['name'] for r in cases}), 11372)
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

    def test_xy_conversion_and_overlapping_row_union(self):
        # Guide12-60 literal PS16 example; signed-Y/modulo32 calculation.
        guide=fixture(16,1,1,True,False,point=0x00400030,offset=0,convdp=20,pitch=0x800)
        self.assertEqual(guide['data_fill']['address'],0x20300)
        negative=fixture(16,1,1,True,False,point=0xFFFF0030,offset=0x1000,convdp=20,pitch=0x800)
        self.assertEqual(negative['data_fill']['address'],0xB00)
        # Rows overlap at6110/6120. A later row's canary must not undo a
        # pixel written by the preceding row in the final memory oracle.
        overlap=fixture(16,3,2,True,False,point=0,offset=0x6100,convdp=27,pitch=16)
        before,after=map(dict,(overlap['initial_memory'],overlap['expected_memory']))
        self.assertEqual(after,{0x60F0:before[0x60F0],0x6100:0xAA55,0x6110:0xAA55,
                                0x6120:0xAA55,0x6130:0xAA55,0x6140:before[0x6140]})

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

    def test_partial_literal_counts_and_edge_memory(self):
        # Table13-6 B/C/D, G2, L1, plus linear setup4. N3 B has
        # the printed five-state tail; C/D have different row overhead.
        for words,alignment,states in ((1,'B',10),(1,'C',9),(1,'D',9),
                (2,'B',13),(2,'C',13),(2,'D',13),
                (3,'B',17),(3,'C',15),(3,'D',15)):
            for xy,off in ((False,False),(False,True),(True,False),(True,True)):
                case=partial_fixture(4,words,alignment,xy,off)
                self.assertEqual(case['states'],states+2*xy+3*off)
                code,pc,nxt=program(case)
                self.assertEqual(code[(pc-0x1000)//16],0x0FE0 if xy else 0x0FC0)
                self.assertEqual(nxt,pc+16)
        for alignment,expected in (
                ('B',[(1,0x6100,0xAA55,0),(0,0x6110,0x55AA,0),(1,0x6110,0x5A55,0)]),
                ('C',[(0,0x6100,0x55AA,0),(1,0x6100,0xAA5A,0),(1,0x6110,0xAA55,0)]),
                ('D',[(0,0x6100,0x55AA,0),(1,0x6100,0xAA5A,0),
                      (0,0x6110,0x55AA,0),(1,0x6110,0x5A55,0)])):
            case=partial_fixture(4,2,alignment,False,False)
            self.assertEqual(transfers(case),expected)
            before,after=map(dict,(case['initial_memory'],case['expected_memory']))
            for address in (0x60F0,0x6120):
                self.assertEqual(after[address],before[address])
        short=partial_fixture(4,1,'D',False,False)
        self.assertEqual(transfers(short),[(0,0x6100,0x55AA,0),(1,0x6100,0x5A5A,0)])
        with self.assertRaises(ValueError):
            partial_fixture(8,1,'D',False,False)

    def test_partial_bus_rejects_lost_edges_and_extra_pixel_transfers(self):
        case=partial_fixture(4,1,'D',False,False)
        observed=dict(start=0,end=72)
        bus=['BUS_BEGIN 24 0 00006100 0000 0','BUS_END 40 0 00006100 55aa',
             'BUS_BEGIN 40 1 00006100 5a5a 0','BUS_END 56 1 00006100 55aa']
        self.assertEqual(check_bus(case,observed,bus,0),[])
        bad=list(bus);bad[2]='BUS_BEGIN 40 1 00006100 aa55 0'
        self.assertTrue(check_bus(case,observed,bad,0))
        bad=list(bus);bad[1]='BUS_END 40 0 00006100 55ab'
        self.assertTrue(check_bus(case,observed,bad,0))
        self.assertTrue(check_bus(case,observed,bus+bus,0))

    def test_multirow_partial_literal_states_and_registers(self):
        # Literal L=2/4 substitutions in Table13-6 with G=2, linear setup4.
        # The N>=3 B five-state tail occurs once for the whole rectangle.
        for words,alignment,l2,l4 in ((1,'B',14,22),(1,'C',13,21),(1,'D',13,21),
                (2,'B',20,34),(2,'C',20,34),(2,'D',21,37),
                (3,'B',25,41),(3,'C',24,42),(3,'D',25,45)):
            for rows,states in ((2,l2),(4,l4)):
                for xy,off in ((False,False),(False,True),(True,False),(True,True)):
                    case=partial_fixture(4,words,alignment,xy,off,rows=rows)
                    self.assertEqual(case['states'],states+2*xy+3*off)
                    self.assertEqual(case['initial_all_regs']['b7'],(rows<<16)|case['conditions']['width'])
                    self.assertEqual(case['expected_extra_regs']['b2'],
                        case['data_fill']['address']+(rows-1)*0x100+case['conditions']['width']*4)
                    code,pc,nxt=program(case)
                    self.assertEqual(code[(pc-0x1000)//16],0x0FE0 if xy else 0x0FC0)
                    self.assertEqual(nxt,pc+16)

    def test_multirow_partial_memory_and_ordered_rmw(self):
        case=partial_fixture(4,2,'D',False,False,rows=2)
        before,after=map(dict,(case['initial_memory'],case['expected_memory']))
        self.assertEqual(case['expected_extra_regs']['b2'],0x621c)
        self.assertEqual(transfers(case),[
            (0,0x6100,0x55aa,0),(1,0x6100,0xaa5a,0),
            (0,0x6110,0x55aa,0),(1,0x6110,0x5a55,0),
            (0,0x6200,0x55aa,0),(1,0x6200,0xaa5a,0),
            (0,0x6210,0x55aa,0),(1,0x6210,0x5a55,0)])
        self.assertEqual({a:v for a,v in after.items() if a in (0x6100,0x6110,0x6200,0x6210)},
                         {0x6100:0xaa5a,0x6110:0x5a55,0x6200:0xaa5a,0x6210:0x5a55})
        for address in (0x60f0,0x6120,0x61f0,0x6220):
            self.assertEqual(after[address],before[address])
        bus=[]
        for q,(kind,address,data,iaq) in enumerate(transfers(case)):
            clock=24+q*16
            bus.extend((f'BUS_BEGIN {clock} {kind} {address:08x} {data if kind else 0:04x} {iaq}',
                        f'BUS_END {clock+16} {kind} {address:08x} {data:04x}'))
        observed=dict(start=0,end=168)
        self.assertEqual(check_bus(case,observed,bus,0),[])
        self.assertTrue(check_bus(case,observed,bus[:8],0))
        self.assertTrue(check_bus(case,observed,bus[8:]+bus[:8],0))

    def test_boolean_literal_states_and_inventory(self):
        rows=[r for r in fill_cases() if r['name'].startswith('fill_boolean_')]
        self.assertEqual(len(rows),1800)
        for size in (1,2,4,8,16):
            for ppop in range(1,16):
                for xy,off in ((False,False),(False,True),(True,False),(True,True)):
                    row=boolean_fixture(size,ppop,xy,off)
                    # Linear setup4 + A/N1 transfer (1+G4)+2 = 11.
                    self.assertEqual(row['states'],11+2*xy+3*off)
                    self.assertEqual(row['conditions']['width'],16//size)
                    self.assertEqual(row['control'],ppop<<10)
                    self.assertEqual(row['fill_timing']['word_states'],4)
                    self.assertEqual(row['expected_extra_regs']['b2'],0x6110)
                    code,pc,nxt=program(row)
                    self.assertEqual(code[(pc-0x1000)//16],0x0FE0 if xy else 0x0FC0)
                    self.assertEqual(nxt,pc+16)
        for ppop in (0,16,21):
            with self.assertRaises(ValueError):boolean_fixture(4,ppop,False,False)

    def test_boolean_literal_pixels_and_canaries(self):
        # COLOR1 AA55 and old word A497; literal Table7-1 substitutions.
        for ppop,want in ((1,0xA015),(3,0),(6,0x5B68),(9,0xA497),
                          (10,0x0EC2),(12,0xFFFF),(15,0x55AA)):
            for size in (1,2,4,8,16):
                case=boolean_fixture(size,ppop,False,False)
                before,after=map(dict,(case['initial_memory'],case['expected_memory']))
                self.assertEqual(before[0x6100],0xA497)
                self.assertEqual(after[0x6100],want)
                self.assertEqual(after[0x60F0],before[0x60F0])
                self.assertEqual(after[0x6110],before[0x6110])
                self.assertEqual(transfers(case),[(0,0x6100,0xA497,0),(1,0x6100,want,0)])

    def test_boolean_multiword_row_boundaries(self):
        # Literal Table13-6 A coefficients: N1=5, N2=10, N3=13;
        # each has a two-state final tail, plus linear setup4 / XY6.
        for words,rows,states in ((2,1,16),(3,1,19),(1,2,16),(2,2,26),(3,3,45)):
            for size in (1,2,4,8,16):
                for xy in (False,True):
                    case=boolean_fixture(size,10,xy,False,words=words,rows=rows)
                    self.assertEqual(case['states'],states+2*xy)
                    self.assertEqual(case['expected_extra_regs']['b2'],0x6100+(rows-1)*0x100+words*16)
                    before,after=map(dict,(case['initial_memory'],case['expected_memory']))
                    plan=transfers(case)
                    self.assertEqual(len(plan),2*words*rows)
                    for row in range(rows):
                        for word in range(words):
                            address=0x6100+row*0x100+word*16
                            # PPOP10 XOR; independent literal whole-word result.
                            self.assertEqual(after[address],before[address]^0xAA55)
                            q=2*(row*words+word)
                            self.assertEqual(plan[q:q+2],[(0,address,before[address],0),(1,address,after[address],0)])
                        for address in (0x60F0+row*0x100,0x6100+row*0x100+words*16):
                            self.assertEqual(after[address],before[address])

    def test_boolean_word_bus_and_timing_rejections(self):
        case=boolean_fixture(4,10,False,False)
        observed=dict(start=0,end=88)
        bus=['BUS_BEGIN 32 0 00006100 0000 0','BUS_END 48 0 00006100 a497',
             'BUS_BEGIN 48 1 00006100 0ec2 0','BUS_END 64 1 00006100 a497']
        self.assertEqual(check_bus(case,observed,bus,0),[])
        self.assertTrue(check_bus(case,observed,bus[2:],0))
        self.assertTrue(check_bus(case,observed,bus+bus,0))
        wrong=list(bus);wrong[2]='BUS_BEGIN 48 1 00006100 aa55 0'
        self.assertTrue(check_bus(case,observed,wrong,0))
        wrong=list(bus);wrong[1]='BUS_END 48 0 00006100 a496'
        self.assertTrue(check_bus(case,observed,wrong,0))
        state=dict(case['initial_all_regs'],clocks=88,start=0,end=88,paused=0,st=case['expected_st'])
        state.update(case['expected_extra_regs'])
        self.assertEqual(check(case,state),[])
        self.assertTrue(check(case,dict(state,clocks=96,end=96)))

    def test_arithmetic_literals_and_pixel_carry_isolation(self):
        for ppop,want in ((16,0),(17,0xffff),(18,0xeeee),(19,0xeeee),
                          (20,0xffff),(21,0x1111)):
            self.assertEqual(arithmetic_word(ppop,0x1111,0xffff,4),want)
        for ppop,want in ((16,0x1111),(17,0x1111),(18,0xffff),(19,0),
                          (20,0x1111),(21,0)):
            self.assertEqual(arithmetic_word(ppop,0x1111,0,4),want)
        for ppop,want in ((16,0xf4fa),(17,0xfffa),(18,0xb050),
                          (19,0x0050),(20,0xaaa5),(21,0x5a55)):
            self.assertEqual(arithmetic_word(ppop,0xaa55,0x5aa5,4),want)
        self.assertEqual(arithmetic_word(16,0xff01,0x01ff,8),0)
        self.assertEqual(arithmetic_word(16,0xff01,0x01ff,16),0x0100)
        for size,ppop in ((1,16),(2,19),(3,20),(4,15),(16,22)):
            with self.assertRaises(ValueError):
                arithmetic_word(ppop,0,0,size)

    def test_arithmetic_table_states_and_inventory(self):
        rows=[r for r in fill_cases() if r['name'].startswith('fill_arithmetic_')]
        self.assertEqual(len(rows),1728)
        self.assertEqual({r['conditions']['ppop'] for r in rows},set(range(16,22)))
        self.assertEqual({r['conditions']['size'] for r in rows},{4,8,16})
        # Table13-7 literal G, Table13-6 A/N1,N2,N3 and repeated rows.
        for ppop,g in ((16,4),(17,5),(18,5),(19,6),(20,5),(21,5)):
            for words,nrows,states in ((1,1,7+g),(2,1,8+2*g),
                                      (3,1,7+3*g),(3,3,9+9*g)):
                for xy,off in ((False,False),(False,True),(True,False),(True,True)):
                    case=arithmetic_fixture(4,ppop,xy,off,words=words,rows=nrows)
                    self.assertEqual(case['states'],states+2*xy+3*off)
                    self.assertEqual(case['fill_timing']['word_states'],g)
                    self.assertEqual(len(transfers(case)),2*words*nrows)
                    code,pc,nxt=program(case)
                    self.assertEqual(code[(pc-0x1000)//16],0x0fe0 if xy else 0x0fc0)
                    self.assertEqual(nxt,pc+16)

    def test_arithmetic_canaries_and_bus_failures(self):
        case=arithmetic_fixture(4,16,False,False,sample=1)
        before,after=map(dict,(case['initial_memory'],case['expected_memory']))
        self.assertEqual(before[0x6100],0xffff)
        self.assertEqual(after[0x6100],0)
        for address in (0x60f0,0x6110):
            self.assertEqual(after[address],before[address])
        self.assertEqual(case['initial_all_regs']['b9'],0x11111111)
        self.assertEqual(case['expected_extra_regs']['b9'],0x11111111)
        self.assertEqual(transfers(case),[(0,0x6100,0xffff,0),(1,0x6100,0,0)])
        observed=dict(start=0,end=88)
        bus=['BUS_BEGIN 32 0 00006100 0000 0','BUS_END 48 0 00006100 ffff',
             'BUS_BEGIN 48 1 00006100 0000 0','BUS_END 64 1 00006100 ffff']
        self.assertEqual(check_bus(case,observed,bus,0),[])
        wrong=bus.copy();wrong[2]='BUS_BEGIN 48 1 00006100 1110 0'
        self.assertTrue(check_bus(case,observed,wrong,0))
        self.assertTrue(check_bus(case,observed,bus+bus,0))


if __name__ == '__main__':
    unittest.main()
