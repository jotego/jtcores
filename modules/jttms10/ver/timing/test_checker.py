#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Guard against making the checker accept correct results at wrong times."""
import unittest

from oracle import multiply_states, setf_states, divide_states, immediate_states, load_states
from run import cases, check, check_bus, check_target, split_transcripts, program, measured_trace, reads
from alu_cases import arithmetic
from immediate_cases import result as immediate_result, extension_words, TI_EXAMPLES
from load_cases import extract
from load_mode_cases import fixture as load_mode_fixture
from store_cases import fixture as store_fixture,insert as store_insert
from run import check_store_bus
from store_mode_cases import literal_cases as store_literal_cases
from divide_cases import divide_result, TI_DIV_EXAMPLES
from scalar_cases import shift_result, TI_SLA_EXAMPLES
from coverage import inventory, REQUIRED
from control_cases import condition, decrement, control_states, fixture as control_fixture
from xy_cases import arithmetic as xy_arithmetic, fixture as xy_fixture, LITERALS as XY_LITERALS


class TimingCheckerTest(unittest.TestCase):
    def test_xy_literal_outputs_and_flags(self):
        for name,rows in XY_LITERALS.items():
            for source,dest,value,flags in rows:
                with self.subTest(name=name,source=source,dest=dest):
                    result,status=xy_arithmetic(name,source,dest,0xF020083F)
                    self.assertEqual((result,status),(value,(flags<<28)|0x0020083F))

    def test_xy_halves_do_not_propagate_carry_or_borrow(self):
        self.assertEqual(xy_arithmetic('ADDXY',1,0x1234FFFF,0),(0x12340000,0x80000000))
        self.assertEqual(xy_arithmetic('SUBXY',1,0x12340000,0),(0x1234FFFF,0x10000000))

    def test_xy_subtract_comparison_flags_are_signed(self):
        # SUBXY reports signed ordering even when the 16-bit difference wraps.
        self.assertEqual(xy_arithmetic('SUBXY',0x80008000,0x7FFF7FFF,0),(0xFFFFFFFF,0))
        self.assertEqual(xy_arithmetic('CMPXY',0x80008000,0x7FFF7FFF,0),(0x7FFF7FFF,0x50000000))

    def test_xy_compare_source_conflict_blocks_acceptance(self):
        row=xy_fixture('CMPXY',1,0)
        audit=inventory([row]);self.assertEqual(row['states'],3)
        self.assertFalse(audit['gate_passed'])
        self.assertEqual(audit['unresolved_source_probes'][0]['kind'],'unresolved-source-policy')
        self.assertEqual(row['source_values']['entry_cpu'],1)
        self.assertEqual(row['source_values']['summary_cpu'],3)
        self.assertEqual(row['source_values']['datasheet_cpu'],3)

    def setUp(self):
        self.case = next(c for c in cases() if c['name'] == 'mpys_fs2_positive_even_hit')
        self.observed = dict(clocks=48, start=96, end=144, paused=0, st=self.case['expected_st'],
                             **{f'a{n}': v for n, v in enumerate(self.case['expected_regs'])})

    def test_correct_math_wrong_time_fails(self):
        self.assertEqual(check(self.case, self.observed), [])
        self.observed['clocks'] = 168  # Incorrect full-width latency at FS1=2.
        self.assertTrue(any('expected 48 INCLK' in e for e in check(self.case, self.observed)))

    def test_source_field_sign_not_register_sign(self):
        # p.12-167: 5+8/2 versus 6+8/2, plus three states with CD.
        self.assertEqual(multiply_states(signed=False, fs1=8, source=0xFFFFFF01), 9)
        self.assertEqual(multiply_states(signed=False, fs1=8, source=0x00000081), 10)
        self.assertEqual(multiply_states(signed=False, fs1=8, source=0x81,
                                         cache_disabled=True), 13)

    def test_undefined_fields_rejected(self):
        for fs in (-2, 1, 3, 31, 34):
            with self.subTest(fs=fs), self.assertRaises(ValueError):
                multiply_states(signed=True, fs1=fs, source=1)
        self.assertEqual(multiply_states(signed=True, fs1=0, source=1), 21)

    def test_external_wait_cannot_be_ignored(self):
        case = dict(self.case, cache_disabled=True, states=9, next_pc=0x1230)
        self.observed['clocks'] = 72
        self.assertEqual(check(case, self.observed), [])
        self.assertTrue(check(case, self.observed, wait_states=1))
        self.observed['clocks'] = 80
        self.assertEqual(check(case, self.observed, wait_states=1), [])

    def test_bus_contract_is_independent_of_total(self):
        case = dict(self.case, cache_disabled=True, states=9, next_pc=0x1230)
        lines = ['BUS_BEGIN 144 0 00001230 0000 1', 'BUS_END 168 0 00001230 0300']
        self.assertEqual(check_bus(case, self.observed, lines, 1), [])
        # An ACK a state early must fail even if someone pads retirement.
        lines[1] = 'BUS_END 160 0 00001230 0300'
        self.assertTrue(check_bus(case, self.observed, lines, 1))
        # Likewise a cold-cache fill cannot be classified as a warm hit.
        self.assertTrue(check_bus(self.case, self.observed, lines, 0))

    def test_bus_start_cannot_be_hidden_by_total_padding(self):
        case = dict(self.case, cache_disabled=True, states=9, next_pc=0x1230)
        lines = ['BUS_BEGIN 100 0 00001230 0000 1', 'BUS_END 124 0 00001230 0300']
        self.assertTrue(any('read start' in e for e in check_bus(case, self.observed, lines, 1)))

    def test_functional_assertions_remain_active(self):
        self.observed['a0'] ^= 1
        self.assertTrue(any('A0:' in e for e in check(self.case, self.observed)))

    def test_paused_clocks_cannot_be_absorbed_by_instruction_padding(self):
        self.observed.update(paused=7, clocks=55)
        self.assertEqual(check(self.case, self.observed, pause_clocks=7), [])
        self.observed['clocks'] = 48
        self.assertTrue(check(self.case, self.observed, pause_clocks=7))

    def test_clock_paused_cpu_realigns_external_bus(self):
        case=dict(self.case,cache_disabled=True,states=9,next_pc=0x1230)
        self.observed.update(paused=7,clocks=80)
        self.assertEqual(check(case,self.observed,pause_clocks=7),[])
        self.observed['clocks']=79
        self.assertTrue(check(case,self.observed,pause_clocks=7))
        self.assertEqual(check_bus(case,self.observed,
            ['BUS_BEGIN 152 0 00001230 0000 1','BUS_END 168 0 00001230 0300'],0,7),[])

    def test_raw_target_ack_is_independent_of_ti_cycle(self):
        case=dict(self.case,cache_disabled=True,states=9,next_pc=0x1230)
        lines=['TARGET_BEGIN 144 0 00001230 0000 1','TARGET_END 156 0 00001230 0300']
        self.assertEqual(check_target(case,self.observed,lines,1),[])
        lines[1]='TARGET_END 148 0 00001230 0300'
        self.assertTrue(check_target(case,self.observed,lines,1))

    def test_cold_fixture_forces_next_subsegment(self):
        case=next(c for c in cases() if c.get('cache_miss') is True)
        words,start,following=program(case)
        self.assertEqual((start%64,following%64),(48,0))
        self.assertEqual(case['measure_pass'],0)
        self.assertEqual(case['states'],10)  # NOP1 + four reads8 + processing1.

    def test_immediate_primary_counts(self):
        self.assertEqual([immediate_states(width=w,cache_disabled=off)
                          for w in (16,32) for off in (False,True)],[2,8,3,12])
        with self.assertRaises(ValueError):immediate_states(width=8)

    def test_immediate_literal_examples(self):
        for name,width,value,before,after,flags in TI_EXAMPLES:
            with self.subTest(name=name,width=width,value=value):
                self.assertEqual(immediate_result(name,value,width,before,0xF0000810),
                                 (after,0x810 | (flags<<28)))

    def test_immediate_encoding_is_separate_from_operand_math(self):
        self.assertEqual(extension_words('SUBI',-1,16),[0])
        self.assertEqual(extension_words('CMPI',0x12345678,32),[0xA987,0xEDCB])
        self.assertEqual(extension_words('ANDI',0x12345678,32),[0xA987,0xEDCB])
        self.assertEqual(extension_words('ANDNI',0x12345678,32),[0x5678,0x1234])
        self.assertEqual(immediate_result('SUBI',-1,16,0,0x810),(1,0x40000810))

    def test_every_external_immediate_word_adds_wait(self):
        case=dict(self.case,extensions=[0x1234,0x5678],cache_disabled=True,states=12)
        self.observed.update(paused=0,clocks=120)
        self.assertEqual(check(case,self.observed,wait_states=1),[])
        self.observed['clocks']=104  # Only following opcode wait counted.
        self.assertTrue(check(case,self.observed,wait_states=1))

    def test_extension_bus_order_data_and_iaq_are_independent_of_total(self):
        case=dict(self.case,extensions=[0xA987,0xEDCB],cache_disabled=True,
                  states=12,test_pc=0x1200,next_pc=0x1230)
        lines=['BUS_BEGIN 104 0 00001210 0000 0','BUS_END 128 0 00001210 a987',
               'BUS_BEGIN 144 0 00001220 0000 0','BUS_END 168 0 00001220 edcb',
               'BUS_BEGIN 184 0 00001230 0000 1','BUS_END 208 0 00001230 0300']
        self.assertEqual(check_bus(case,self.observed,lines,1),[])
        for index,replacement in ((0,lines[0][:-1]+'1'),(1,lines[1].replace('a987','edcb')),
                                  (2,lines[2].replace('144','136'))):
            wrong=list(lines);wrong[index]=replacement
            self.assertTrue(check_bus(case,self.observed,wrong,1))

    def test_cold_extension_starts_in_absent_subsegment(self):
        variants=[c for c in cases() if c.get('cache_miss')=='extension']
        self.assertEqual(len(variants),20)
        for case in variants:
            words,start,following=program(case)
            first=case.get('miss_word',1)
            self.assertEqual(start%64,64-16*first)
            self.assertEqual((start+16*first)%64,0)
            self.assertEqual(following,start+16*(1+len(case['extensions'])))
            self.assertEqual(case['states'],10+len(case['extensions']))

    def test_load_primary_state_counts(self):
        self.assertEqual(load_states(address=0,width=16),3)
        self.assertEqual(load_states(address=15,width=16),5)
        self.assertEqual(load_states(address=15,width=32),7)
        self.assertEqual(load_states(address=0,width=5,signed=True),4)
        self.assertEqual(load_states(address=0,width=32,signed=True),5)
        self.assertEqual(load_states(address=8,width=8,signed=True,byte=True),3)
        self.assertEqual(load_states(address=9,width=8,signed=True,byte=True,cache_disabled=True),8)
        with self.assertRaises(ValueError):load_states(address=0,width=0)
        with self.assertRaises(ValueError):load_states(address=0,width=16,byte=True)

    def test_load_primary_literal_values(self):
        memory=[(0x15500,0x7770),(0x15510,0x7777)]
        self.assertEqual(extract(memory,0x15500,5,True),0xFFFFFFF0)
        self.assertEqual(extract(memory,0x15500,18,True),0xFFFF7770)
        self.assertEqual(extract(memory,0x15500,31,True),0xF7777770)
        self.assertEqual(extract(memory,0x15500,32,True),0x77777770)
        byte=[(0x5000,0xEF),(0x5010,0x89AB)]
        self.assertEqual([extract(byte,0x5000+o,8,True) for o in (0,1,8,12)],
                         [0xFFFFFFEF,0x77,0,0xFFFFFFB0])

    def test_load_reads_are_ordered_uncached_data(self):
        case=dict(self.case,cache_disabled=True,states=10,next_pc=0x1230,
                  data_load=dict(address=0x600F,width=32),
                  initial_memory=[(0x6000,0x1111),(0x6010,0x2222),(0x6020,0x3333)])
        lines=['BUS_BEGIN 96 0 00006000 0000 0','BUS_END 120 0 00006000 1111',
               'BUS_BEGIN 120 0 00006010 0000 0','BUS_END 144 0 00006010 2222',
               'BUS_BEGIN 144 0 00006020 0000 0','BUS_END 168 0 00006020 3333',
               'BUS_BEGIN 176 0 00001230 0000 1','BUS_END 200 0 00001230 0300']
        self.assertEqual(check_bus(case,self.observed,lines,1),[])
        self.observed.update(clocks=112)
        self.assertEqual(check(case,self.observed,wait_states=1),[])
        self.observed['clocks']=88  # Only opcode wait counted.
        self.assertTrue(check(case,self.observed,wait_states=1))
        wrong=list(lines);wrong[0]=wrong[0][:-1]+'1'
        self.assertTrue(check_bus(case,self.observed,wrong,1))
        warm=dict(case,cache_disabled=False,states=7)
        self.assertTrue(check_bus(warm,self.observed,[],1))
        self.assertEqual(check_bus(warm,self.observed,lines[:6],1),[])

    def test_store_extension_ti_literal_words(self):
        rows=list(store_literal_cases())
        self.assertEqual(len(rows),108)
        for row in rows:self.assertEqual(row['literal_model_memory'],row['expected_memory'],row['name'])

    def test_store_conflicting_primary_counts_remain_visible(self):
        offset=store_fixture('offset',16,0,0,True,0)
        absolute=store_fixture('absolute',16,0,0,True,0)
        self.assertEqual((offset['states'],offset['source_values']['summary_cd'],offset['source_values']['entry_typical_cd']),(10,9,7))
        self.assertEqual((absolute['states'],absolute['source_values']['summary_cd'],absolute['source_values']['entry_typical_cd']),(13,13,7))
        for row in (offset,absolute,store_fixture('absolute',8,0,0,False,0,byte=True)):
            self.assertEqual(row['timing_source_status'],'inferred-conflict-resolution')
        self.assertEqual(store_fixture('absolute',8,15,0,False,0,byte=True)['timing_source_status'],'primary-summary-consistent')
        with self.assertRaises(ValueError):store_fixture('post',8,0,0,False,0,byte=True)

    def test_full_form_coverage_cannot_waive_unresolved_timing_sources(self):
        complete=[dict(name=key,coverage_id=key,cache_disabled=False) for key in REQUIRED]
        # All forms present is still only a necessary gate, never full signoff.
        self.assertTrue(inventory(complete)['gate_passed'])
        self.assertFalse(inventory(complete)['full_isa_signoff'])
        case=store_fixture('offset',16,0,0,True,0)
        result=inventory([*complete,case])
        self.assertEqual(result['missing_forms'],[])
        self.assertFalse(result['gate_passed'])
        self.assertEqual(result['unresolved_source_probes'][0]['kind'],'unresolved-source-policy')

    def test_agreeing_ti_counts_are_a_published_target_gap(self):
        case=store_fixture('absolute',8,0,0,False,0,byte=True)
        # Relabeling a policy cannot bypass the independent numeric audit.
        case['timing_source_status']='primary-summary-consistent'
        result=inventory([case])
        gap=result['unresolved_source_probes'][0]
        self.assertEqual(gap['kind'],'agreed-published-target-gap')
        self.assertEqual((gap['source_values']['entry_typical_cpu'],gap['source_values']['summary_cpu'],gap['source_values']['policy_cpu']),(1,1,3))
        case['source_values']['datasheet_cpu']=2
        self.assertEqual(inventory([case])['unresolved_source_probes'][0]['kind'],'unresolved-source-policy')
        # An unaligned byte uses Table13-2, not the byte-aligned entry.
        unaligned=store_fixture('absolute',8,1,0,False,0,byte=True)
        self.assertIsNone(unaligned['source_values']['entry_typical_cpu'])
        self.assertEqual(inventory([unaligned])['unresolved_source_probes'][0]['kind'],'unresolved-source-policy')
        case['states']=1
        with self.assertRaisesRegex(ValueError,'source policy differs from the probe expectation'):
            inventory([case])

    def test_absolute_load_source_choice_blocks_acceptance(self):
        case=load_mode_fixture('absolute',16,0,0,False,True,0,2,0,0)
        result=inventory([case])
        self.assertEqual(len(result['unresolved_source_probes']),1)
        values=result['unresolved_source_probes'][0]['source_values']
        self.assertEqual((values['summary_cd'],values['entry_typical_cd'],values['policy_cd']),(14,15,14))
        case=load_mode_fixture('absolute',16,0,0,False,False,0,2,0,0)
        self.assertEqual(inventory([case])['unresolved_source_probes'],[])

    def test_coverage_rejects_unknown_instruction_form(self):
        with self.assertRaisesRegex(ValueError,'unknown TI coverage identifier'):
            inventory([dict(name='unknown',coverage_id='NOT_A_TI_INSTRUCTION',cache_disabled=False)])

    def test_control_condition_table_all_flags(self):
        # Bit q says the condition is true for NCZV=q, transcribed from
        # the Boolean conditions in TI pp.12-92..97, including positive.
        masks=(0xFFFF,0x0033,0xFCFC,0x0303,0x55AA,0xAA55,0xDDEE,0x2211,
               0xF0F0,0x0F0F,0xCCCC,0x3333,0xAAAA,0x5555,0xFF00,0x00FF)
        for code,mask in enumerate(masks):
            self.assertEqual(sum(int(condition(code,flags<<28))<<flags for flags in range(16)),mask)
        with self.assertRaises(ValueError):condition(16,0)

    def test_control_decrement_literal_results_and_original_z_gate(self):
        # TI pp.12-70/72/74/75 literal examples, including zero wrap.
        for before,after,taken in ((9,8,True),(1,0,False),(0,0xFFFFFFFF,True)):
            for name in ('DSJ','DSJS'):
                for flags in (0,0xF0000000):self.assertEqual(decrement(name,before,flags),(after,taken))
            for name,enabled_flags,disabled_flags in (('DSJEQ',0x20000000,0),('DSJNE',0,0x20000000)):
                self.assertEqual(decrement(name,before,enabled_flags),(after,taken))
                self.assertEqual(decrement(name,before,disabled_flags),(before,False))
        self.assertEqual(decrement('DSJS',0x80000000,0xF0000010),(0x7FFFFFFF,True))

    def test_control_primary_path_counts_and_source_conflicts(self):
        for name in ('JUMP','EXGPC'):
            self.assertEqual([control_states(name,cache_disabled=off) for off in (False,True)],[2,5])
        for name in ('DSJ','DSJEQ','DSJNE'):
            for taken,counts in ((True,(3,9)),(False,(2,8))):
                self.assertEqual(tuple(control_states(name,taken=taken,cache_disabled=off) for off in (False,True)),counts)
        self.assertEqual([control_states('DSJS',taken=x) for x in (True,False)],[2,3])
        self.assertEqual([control_states('JACC',taken=x,cache_disabled=True) for x in (True,False)],[6,7])
        for name,entry,summary,selected in (('JR_SHORT',1,2,1),('JR_LONG',4,1,2)):
            case=control_fixture(name,code=10,flags=0)
            self.assertEqual((case['states'],case['source_values']['entry_typical_cpu'],case['source_values']['summary_cpu'],case['source_values']['datasheet_cpu']),(selected,entry,summary,selected))
            self.assertEqual(len(inventory([case])['unresolved_source_probes']),1)
        self.assertEqual(control_states('JR_LONG',taken=False,cache_disabled=True),5)

    def test_control_assembled_targets_banks_sp_and_displacement_endpoints(self):
        for name in ('JUMP','EXGPC','DSJ','DSJS','JR_SHORT','JR_LONG','JACC'):
            for displacement in ((-32768,32767) if name in ('DSJ','JR_LONG') else (-8,8)):
                for bank,reg in ((0,1),(1,1),(1,15)):
                    case=control_fixture(name,bank=bank,reg=reg,displacement=displacement,low_bits=15)
                    words,pc,npc=program(case)
                    image={0x1000+16*q:word for q,word in enumerate(words)}
                    image.update(case.get('initial_memory',[]))
                    self.assertEqual(npc,(pc+16*(1+len(case['extensions'])+displacement))&0xFFFFFFFF)
                    self.assertEqual(image[npc],0x0300)
                    self.assertEqual(image[(npc+16)&0xFFFFFFFF],0x016C)
                    if name=='JACC':
                        self.assertEqual(case['extensions'][0]&15,15)
                        self.assertEqual(((case['extensions'][1]<<16)|case['extensions'][0])&0xFFFFFFF0,npc)
                    if name=='EXGPC':
                        result=case['expected_extra_regs']['sp'] if reg==15 else case['expected_extra_regs']['b1'] if bank else case['expected_regs'][reg]
                        self.assertEqual(result,pc+16)

    def test_control_word_plan_and_bus_checks_cannot_be_waived_by_total(self):
        case=control_fixture('JACC',off=True)
        words,pc,npc=program(case);case.update(test_pc=pc,next_pc=npc)
        observed=dict(start=96,end=144,clocks=48,paused=0,st=case['expected_st'],
                      **{f'a{q}':v for q,v in enumerate(case['expected_regs'])},**case['expected_extra_regs'])
        bus=[];raw=[]
        for q,(_,addr,data,iaq) in enumerate(reads(case)):
            start=96+16*q
            bus += [f'BUS_BEGIN {start} 0 {addr:08x} 0000 {iaq}',f'BUS_END {start+16} 0 {addr:08x} {data:04x}']
            raw += [f'TARGET_BEGIN {start+4} 0 {addr:08x} 0000 {iaq}',f'TARGET_END {start+8} 0 {addr:08x} {data:04x}']
        self.assertEqual(check(case,observed),[])
        self.assertEqual(check_bus(case,observed,bus,0),[])
        self.assertEqual(check_target(case,observed,raw+bus,0),[])
        wrong=list(bus);wrong[0]=wrong[0][:-1]+'1'
        self.assertTrue(check_bus(case,observed,wrong,0))
        wrong=list(bus);wrong[1]=wrong[1].replace('112','111')
        self.assertTrue(check_bus(case,observed,wrong,0))
        self.assertTrue(check_target(case,observed,raw,0))
        self.assertTrue(check_bus(case,observed,bus[:-2],0))
        observed['clocks']=72
        self.assertEqual(check(case,observed,wait_states=1),[])
        untaken=control_fixture('JACC',off=True,code=10,flags=0)
        words,pc,npc=program(untaken);untaken.update(test_pc=pc,next_pc=npc)
        self.assertEqual(reads(untaken),[(4,npc,0x0300,1)])

    def test_trace_boundary_excludes_preceding_completion_only(self):
        log='\n'.join(('BUS_END 96 0 00001000 ca80','BUS_BEGIN 96 0 00001010 0000 0',
                       'BUS_END 112 0 00001010 1234','BUS_BEGIN 128 0 00001200 0000 1',
                       'BUS_END 144 0 00001200 0300','BUS_BEGIN 144 0 00006000 0000 0',
                       'BUS_BEGIN 160 0 00001210 0000 1'))
        observed=dict(start=96,end=144)
        selected=measured_trace(log,'BUS',observed)
        self.assertEqual(selected,log.splitlines()[1:5])
        self.assertEqual(measured_trace(log,'BUS',observed,trailing=True),log.splitlines()[1:])

    def test_control_literal_return_and_following_fields(self):
        from control_cases import control_cases
        selected=[case for case in control_cases() if 'literal_return_pc' in case or 'control_follow' in case]
        self.assertEqual(len(selected),12)
        for case in selected:
            words,pc,npc=program(case)
            if 'literal_return_pc' in case:
                self.assertEqual(pc,0x2080)
                self.assertEqual(case['expected_regs'][1],0x2090)
                self.assertIn(npc,(0x1C10,0x1C50))
            elif case['control_follow']['kind']=='load':
                self.assertEqual(case['expected_follow_regs'][0],0x4B2D)
                self.assertEqual(case['expected_follow_st']&0xF0000000,0)
            else:
                self.assertEqual(dict(case['expected_follow_memory']),{0x6000:0x9B6D,0x6010:0xCDB6,0x6020:0x35C6})

    def test_high_and_wrapped_store_addresses(self):
        row=store_fixture('offset',16,0,0,False,2,base=0x80006000,displacement=-32768)
        self.assertEqual(row['regs'][0],0x8000E000)
        self.assertEqual(row['extensions'],[0x8000])
        absolute=store_fixture('absolute',16,0,1,False,2,bank=1,source=1)
        self.assertEqual(absolute['opcode'],0x0791)
        self.assertIsNone(absolute['conditions']['destination'])
        row=store_fixture('post',32,8,1,False,0,source=15,dest=15,base=0xFFFFFFF0)
        self.assertEqual(row['expected_extra_regs']['sp'],0x18)
        self.assertEqual(dict(row['expected_memory']),{0xFFFFFFF0:0xF800,0:0xFFFF,0x10:0xA5FF})

    def test_store_bit_preservation_literal(self):
        memory=[(0x6000,0x9B6D),(0x6010,0xA596),(0x6020,0x35C6)]
        self.assertEqual(store_insert(memory,0x600C,8,0xEF),[(0x6000,0xFB6D),(0x6010,0xA59E),(0x6020,0x35C6)])

    def test_store_hidden_states_primary_alignment_cases(self):
        # TI Fig13-1/Table13-2: A, B, C, D, F and G.
        for width,offset,hidden in ((16,0,1),(8,0,3),(32,0,3),(17,15,5),(2,15,7),(32,15,9)):
            for mode,cpu in (('indirect',1),('post',1),('pre',2)):
                for off in (False,True):
                    case=store_fixture(mode,width,offset,0,off,0)
                    self.assertEqual(case['hidden_states'],hidden)
                    self.assertEqual(case['states'],cpu+(hidden+3 if off else 0))

    def test_store_observer_must_include_trailing_bus_work(self):
        case=store_fixture('indirect',16,0,0,False,0)
        data=dict(case['expected_memory'])[0x6000]
        lines=[f'BUS_BEGIN 0 1 00006000 {data:04x} 0',f'BUS_END 16 1 00006000 {data:04x}']
        self.assertEqual(check_store_bus(case,{'start':0},lines,0),[])
        self.assertTrue(check_store_bus(case,{'start':0},lines[:1],0))
        wrong=lines.copy();wrong[0]=f'BUS_BEGIN 8 1 00006000 {data:04x} 0'
        self.assertTrue(check_store_bus(case,{'start':0},wrong,0))
        wrong=lines.copy();wrong[0]=f'BUS_BEGIN 0 1 00006000 {data^1:04x} 0'
        self.assertTrue(check_store_bus(case,{'start':0},wrong,0))

    def test_store_pre_alias_samples_updated_pointer(self):
        pre=store_fixture('pre',32,15,0,False,0,source=15,dest=15)
        post=store_fixture('post',32,15,0,False,0,source=15,dest=15)
        self.assertEqual(pre['data_store']['value'],0x600F)
        self.assertEqual(pre['expected_extra_regs']['sp'],0x600F)
        self.assertEqual(post['data_store']['value'],0x600F)
        self.assertEqual(post['expected_extra_regs']['sp'],0x602F)

    def test_extended_register_comparisons_cannot_be_skipped(self):
        case=dict(self.case,expected_extra_regs={'b0':1,'sp':2})
        self.observed.update(b0=1,sp=2)
        self.assertEqual(check(case,self.observed),[])
        for name in ('b0','sp'):
            wrong=dict(self.observed);wrong[name]^=1
            self.assertTrue(any(name.upper()+':' in e for e in check(case,wrong)))
            del wrong[name]
            self.assertTrue(check(case,wrong))

    def test_load_mode_primary_counts_and_absolute_discrepancy(self):
        self.assertEqual([load_states(address=0,width=16,mode=m,cache_disabled=True)
                          for m in ('indirect','post','pre','offset','absolute')],[6,6,7,11,14])
        # Table13-1 + §5.4.7 are consistent; p12-153's 5/15,7/13 conflict.
        self.assertEqual(load_states(address=0,width=32,mode='absolute',cache_disabled=True),16)
        with self.assertRaises(ValueError):load_states(address=0,width=8,byte=True,mode='post')

    def test_pointer_wrap_and_shared_sp_alias_model(self):
        memory=[(0xFFFFFFF0,0),(0,0x5A5A),(0x10,0xA5A5)]
        self.assertEqual(extract(memory,0xFFFFFFF8,32,False),0xA55A5A00)
        for bank in (0,1):
            for mode in ('post','pre'):
                row=load_mode_fixture(mode,32,8,1,False,False,bank,15,15,0,base=0xFFFFFFF0)
                self.assertEqual(row['initial_sp'],0x18 if mode=='pre' else 0xFFFFFFF8)
                self.assertEqual(row['expected_extra_regs']['sp'],0xA55A5A00)
                self.assertEqual(row['expected_st'],0x80000010)

    def test_batch_case_association(self):
        log='CASE 0\nRESULT case=0\nCASE 1\nRESULT case=1\nBATCH_DONE cases=2\n'
        chunks=split_transcripts(log,[0,1],batch=True)
        self.assertIn('RESULT case=0',chunks[0])
        self.assertNotIn('RESULT case=1',chunks[0])
        for bad in (log.replace('CASE 1','CASE 0'), log.replace('CASE 1','CASE 2')):
            with self.subTest(log=bad), self.assertRaises(ValueError):
                split_transcripts(bad,[0,1],batch=True)

    def test_batch_must_finish_every_case(self):
        for log in ('CASE 0\n', 'CASE 0\nBATCH_DONE cases=0\n',
                    'CASE 0\nBATCH_DONE cases=1\nBATCH_DONE cases=1\n'):
            with self.subTest(log=log), self.assertRaises(ValueError):
                split_transcripts(log,[0],batch=True)

    def test_ti_sla_example_vectors(self):
        # SPVU001A p.12-239: complete result and NCZV examples.
        for value,count,result,flags in TI_SLA_EXAMPLES:
            with self.subTest(value=value,count=count):
                actual,status=shift_result('SLA',value,count,0xF0000810)
                self.assertEqual((actual,status),(result,(flags<<28)|0x810))

    def test_ti_subb_examples(self):
        # SPVU001A p.12-248, literal (Rd, Rs, C, result, NCZV).
        examples = ((2,1,0,1,0), (2,1,1,0,2), (2,2,1,0xFFFFFFFF,12),
                    (0x7FFFFFFE,0xFFFFFFFE,0,0x80000000,13),
                    (0x7FFFFFFE,0xFFFFFFFE,1,0x7FFFFFFF,4),
                    (0x80000001,1,1,0x7FFFFFFF,1))
        for dest,source,carry,result,flags in examples:
            with self.subTest(dest=dest,source=source,carry=carry):
                self.assertEqual(arithmetic('SUBB',source,dest,0x810 | (carry<<30)),
                                 (result,0x810 | (flags<<28)))

    def test_ti_abs_examples(self):
        # SPVU001A p.12-35: N comes from 0-Rd, not the stored magnitude.
        examples = ((0x7FFFFFFF,0x7FFFFFFF,8), (0xFFFFFFFF,1,0),
                    (0x80000000,0x80000000,9), (0x80000001,0x7FFFFFFF,0),
                    (1,1,8), (0,0,2), (0xFFFA0011,0x5FFEF,0))
        probes = [c for c in cases() if c['coverage_id']=='ABS_R' and not c['cache_disabled']]
        for source,result,flags in examples:
            matches = [c for c in probes if c['regs'][0]==source]
            self.assertEqual(len(matches),2)
            for case in matches:
                with self.subTest(source=source,carry=bool(case['regs'][3] & (1<<30))):
                    self.assertEqual(case['expected_regs'][0],result)
                    self.assertEqual((case['expected_st']>>28) & 11,flags)
                    self.assertEqual(case['expected_st'] & (1<<30),case['regs'][3] & (1<<30))

    def test_setf_field_changes_timing(self):
        self.assertEqual(setf_states(field=0),1)
        self.assertEqual(setf_states(field=1),2)
        self.assertEqual(setf_states(field=1,cache_disabled=True),5)

    def test_rev_undefined_bits_only(self):
        case = next(c for c in cases() if c['coverage_id']=='REV_R' and not c['cache_disabled'])
        observed = dict(clocks=8,paused=0,st=case['expected_st'],
                        **{f'a{n}':v for n,v in enumerate(case['expected_regs'])})
        self.assertEqual(check(case,observed),[])
        observed['a0'] ^= 0xFFFF0007  # Undefined by TI p.12-233.
        self.assertEqual(check(case,observed),[])
        observed['a0'] ^= 8  # Defined revision bit must remain asserted.
        self.assertTrue(any('A0:' in error for error in check(case,observed)))

    def test_getpc_expected_bit_address(self):
        case = next(c for c in cases() if c['coverage_id']=='GETPC_R')
        _,start,following = program(case)
        self.assertEqual(following,start+16)
        self.assertEqual(case['expected_regs'][0],following)

    def test_ti_divide_examples(self):
        for name,paired,high,low,source,result_high,result_low,flags in TI_DIV_EXAMPLES:
            with self.subTest(name=name,paired=paired,high=high,low=low,source=source):
                result,status=divide_result(name,paired,[high,low,source,0xD0000810])
                self.assertEqual(result[:2],[result_high,result_low])
                self.assertEqual(status & 0x0FFFFFFF,0x810)
                self.assertEqual(status & (1<<30),1<<30)
                mask=11 if name=='DIVS' else 3
                self.assertEqual((status>>28)&mask,flags&mask)

    def test_divs_primary_table_minimum_both_parities(self):
        # p.12-63 explicitly prints 41/44 in BOTH columns. The secondary
        # old core's normal-odd39+one gives40, which is not this table.
        for paired in (False,True):
            for divisor in (-1,1):
                with self.subTest(paired=paired,divisor=divisor):
                    self.assertEqual(divide_states('DIVS',dividend=-(1<<31),divisor=divisor,
                                                    paired=paired),41)
                    self.assertEqual(divide_states('DIVS',dividend=-(1<<31),divisor=divisor,
                                                    paired=paired,cache_disabled=True),44)
        self.assertEqual(divide_states('DIVS',dividend=7,divisor=4),39)
        self.assertEqual(divide_states('DIVS',dividend=7,divisor=4,paired=True),40)

    def test_division_early_and_late_overflow_counts(self):
        for name,zero,normal in (('DIVS',7,39),('DIVU',5,37),('MODS',3,40),('MODU',3,35)):
            self.assertEqual(divide_states(name,dividend=7,divisor=0),zero)
            self.assertEqual(divide_states(name,dividend=7,divisor=4),normal)
        self.assertEqual(divide_states('DIVS',dividend=1<<32,divisor=1,paired=True),7)
        self.assertEqual(divide_states('DIVS',dividend=(1<<31)+1,divisor=1,paired=True),40)
        self.assertEqual(divide_states('DIVU',dividend=1<<32,divisor=1,paired=True),5)
        self.assertEqual(divide_states('MODS',dividend=-(1<<31),divisor=-1),41)
        with self.assertRaises(ValueError):
            divide_states('MODU',dividend=1,divisor=1,paired=True)


if __name__ == '__main__':
    unittest.main()
