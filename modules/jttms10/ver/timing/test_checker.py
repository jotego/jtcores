#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Guard against making the checker accept correct results at wrong times."""
import unittest

from oracle import multiply_states, setf_states, divide_states, immediate_states, load_states
from run import cases, check, check_bus, check_target, split_transcripts, program
from alu_cases import arithmetic
from immediate_cases import result as immediate_result, extension_words, TI_EXAMPLES
from load_cases import extract
from load_mode_cases import fixture as load_mode_fixture
from divide_cases import divide_result, TI_DIV_EXAMPLES
from scalar_cases import shift_result, TI_SLA_EXAMPLES


class TimingCheckerTest(unittest.TestCase):
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
