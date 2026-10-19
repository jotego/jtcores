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
from coordinate_cases import point_code, linear, fixture as coordinate_fixture, CPW_EXAMPLES, CV_EXAMPLES
from run import parse_result
from copy_cases import (alignment as copy_alignment,counts as copy_counts,fixture as copy_fixture,
    literal_cases as copy_literals,transactions as copy_transactions)
from pointer_copy_cases import literal_cases as pointer_copy_literals, pointer_copy_cases
from copy_extension_cases import literal_cases as copy_extension_literals, copy_extension_cases
from copy_pair_cases import literal_cases as copy_pair_literals, copy_pair_cases
from emu_cases import emu_cases
from stack_cases import popst_fixture, stack_cases
from return_cases import rets_fixture, return_cases
from interrupt_return_cases import reti_fixture, interrupt_return_cases
from push_cases import push_fixture,push_cases
from call_cases import call_fixture,call_cases
from store_cases import transactions as store_transfers
from mutations import correct_architecture


class TimingCheckerTest(unittest.TestCase):
    def test_call_primary_cpu_hidden_and_cd_counts(self):
        # Literal entry counts12-48/49/50, aligned then nonaligned.
        for form,cpu,hidden,cd in [('CALL_R',3,(3,9),(9,15)),('CALLA',4,(2,8),(15,21)),('CALLR',3,(2,8),(11,17))]:
            for index,offset in enumerate((0,15)):
                for off in (False,True):
                    row=call_fixture(form,off,offset)
                    self.assertEqual(row['states'],cd[index] if off else cpu)
                    self.assertEqual(row['hidden_states'],hidden[index])
                    self.assertEqual(row['data_store']['write_start']+2*len(store_transfers(row)),cpu+hidden[index])

    def test_call_return_pc_width_alignment_and_msw_first(self):
        for form,length in [('CALL_R',1),('CALLA',3),('CALLR',2)]:
            row=call_fixture(form,False,0,low=15)
            _,start,target=program(row);saved=start+16*length
            self.assertEqual(target,0x3000)
            self.assertEqual(extract(row['expected_memory'],0x6000,32,False),saved)
            self.assertEqual(store_transfers(row),[(1,0x6010,saved>>16,0),(1,0x6000,saved&0xFFFF,0)])
            self.assertEqual(row['expected_st'],row['regs'][3])
            self.assertEqual(row['expected_extra_regs']['sp'],0x6000)

    def test_call_sp_target_uses_original_sp(self):
        for bank in (0,1):
            row=call_fixture('CALL_R',False,bank=bank,reg=15)
            _,_,target=program(row)
            self.assertEqual(target,0x6020)
            self.assertEqual(row['expected_extra_regs']['sp'],0x6000)

    def test_callr_signed_displacement_endpoints(self):
        for displacement,encoded in [(-32768,0x8000),(-1,0xFFFF),(32767,0x7FFF)]:
            # -1 targets the offset word itself, so use it only to check the
            # independent word encoding here; executable fixtures avoid it.
            row=call_fixture('CALLR',False,displacement=displacement)
            if displacement==-1:
                with self.assertRaises(ValueError):program(row)
                self.assertEqual(row['extensions'],[encoded])
            else:
                _,start,target=program(row)
                self.assertEqual(row['extensions'],[encoded])
                self.assertEqual(target,(start+32+16*displacement)&0xFFFFFFFF)

    def test_call_stimuli_fit_sparse_memory_and_warm_cache(self):
        rows=list(call_cases());self.assertEqual(len(rows),1306)
        self.assertEqual(len({row['name'] for row in rows}),1306)
        for row in rows:
            program(row)  # Includes explicit sparse-limit/cache-tag guards.
            self.assertLessEqual(len(row['initial_memory']),16)
            self.assertEqual(row['data_store']['width'],32)
            self.assertEqual(row['expected_st'],row['regs'][3])
        row=call_fixture('CALL_R',False,offset=15,target=0x6010)
        with self.assertRaises(ValueError):program(row)

    def test_pushst_primary_cpu_hidden_and_cd_counts(self):
        for offset,hidden,cd in [(0,3,8),(15,8,13)]:
            for off in (False,True):
                row=push_fixture('counts',off,offset)
                self.assertEqual(row['states'],cd if off else 2)
                self.assertEqual(row['hidden_states'],hidden)
                self.assertEqual(row['data_store']['write_start']+2*len(store_transfers(row)),2+hidden)
                self.assertEqual(row['expected_extra_regs']['sp'],row['initial_sp']-32)

    def test_pushst_full_status_ignores_field_definitions(self):
        rows=list(push_cases());self.assertEqual(len(rows),1522)
        self.assertEqual(len({r['name'] for r in rows}),1522)
        for row in rows:
            self.assertEqual(row['regs'],row['expected_regs'])
            self.assertEqual(row['expected_st'],row['regs'][3])
            self.assertEqual(row['data_store']['width'],32)
            self.assertEqual(row['data_store']['value'],row['expected_st'])
            self.assertEqual(extract(row['expected_memory'],row['data_store']['address'],32,False),row['expected_st'])
            self.assertEqual(row['expected_extra_regs']['sp'],(row['initial_sp']-32)&0xFFFFFFFF)

    def test_pushst_numeric_words_follow_explicit_sp_minus32_semantics(self):
        row=push_fixture('numeric',False,address=0x0FF00000)
        self.assertEqual(row['initial_sp'],0x0FF00020)
        self.assertEqual(row['expected_memory'][:2],[(0x0FF00000,0x10),(0x0FF00010,0xC000)])

    def test_pushst_waits_are_hidden_on_hit_and_charged_on_cd(self):
        for off,offset,clocks in [(False,0,23),(False,15,23),(True,0,96),(True,15,160)]:
            row=push_fixture('wait',off,offset)
            obs=dict(clocks=clocks,paused=7,st=row['expected_st'],**row['expected_extra_regs'])
            obs.update({'a'+str(q):v for q,v in enumerate(row['expected_regs'])})
            self.assertEqual(check(row,obs,1,7),[])
            obs['clocks']+=8;self.assertTrue(check(row,obs,1,7))

    def test_pushst_correct_hidden_memory_cannot_hide_early_aligned_writes(self):
        row=push_fixture('bus',False);row.update(test_pc=0x1000,next_pc=0x1010)
        obs=dict(start=0,end=16,clocks=16)
        trace=['BUS_BEGIN 8 1 00006010 c000 0','BUS_END 24 1 00006010 c000',
               'BUS_BEGIN 24 1 00006000 0010 0','BUS_END 40 1 00006000 0010']
        self.assertEqual(check_store_bus(row,obs,trace,0),[])
        ascending=['BUS_BEGIN 8 1 00006000 0010 0','BUS_END 24 1 00006000 0010',
                   'BUS_BEGIN 24 1 00006010 c000 0','BUS_END 40 1 00006010 c000']
        self.assertTrue(check_store_bus(row,obs,ascending,0))
        bad=[x.replace('BEGIN 8','BEGIN 0').replace('END 24','END 16').replace('BEGIN 24','BEGIN 16').replace('END 40','END 32') for x in trace]
        self.assertTrue(check_store_bus(row,obs,bad,0))

    def test_pushst_wrapped_input_preserves_reset_before_writes(self):
        row=push_fixture('wrap',False,address=0xFFFFFFF8)
        self.assertEqual(dict(row['initial_memory'])[0xFFFFFFF0],0)
        self.assertEqual(row['initial_sp'],0x18)
        self.assertNotEqual(dict(row['expected_memory'])[0xFFFFFFF0],0)

    def test_reti_literal_stack_status_pc_and_sp(self):
        row=reti_fixture('guide',False,address=0x0CCC0000,target=0x0044FFF0,restored=0xC0000010)
        self.assertEqual(row['initial_memory'],[(0x0CCC0000,0x10),(0x0CCC0010,0xC000),(0x0CCC0020,0xFFF0),(0x0CCC0030,0x44)])
        self.assertEqual(row['expected_st'],0xC0000010)
        self.assertEqual(row['expected_extra_regs']['sp'],0x0CCC0040)
        self.assertEqual(row['stack_control_flow']['target'],0x0044FFF0)

    def test_reti_independent_full_width_pops_reread_shared_word(self):
        row=reti_fixture('unaligned',False,15);program(row)
        plan=reads(row)
        self.assertEqual([a for _,a,_,_ in plan],[0x5000,0x5010,0x5020,0x5020,0x5030,0x5040])
        self.assertEqual(row['states'],15)
        self.assertEqual(reti_fixture('aligned',True)['states'],14)
        self.assertEqual(reti_fixture('unaligned',True,15)['states'],18)

    def test_reti_waits_count_each_popped_field_not_unique_words(self):
        for offset,clocks in [(0,128),(15,176)]:
            row=reti_fixture('wait',False,offset)
            obs=dict(clocks=clocks,paused=7,st=row['expected_st'],**row['expected_extra_regs'])
            obs.update({'a'+str(q):v for q,v in enumerate(row['expected_regs'])})
            self.assertEqual(check(row,obs,1,7),[])
            obs['clocks']-=8;self.assertTrue(check(row,obs,1,7))

    def test_reti_reset_vector_and_pbx_exclusions_are_explicit(self):
        with self.assertRaises(ValueError):reti_fixture('bad',False,address=0xFFFFFFD0,target=0x10000)
        with self.assertRaises(ValueError):reti_fixture('bad',False,restored=0x02000810)
        row=reti_fixture('wrap',False,address=0xFFFFFFD0,target=0x10000,restored=0x10000810)
        self.assertEqual(dict(row['initial_memory'])[0xFFFFFFE0],0x1000)
        self.assertEqual(dict(row['initial_memory'])[0xFFFFFFF0],0)

    def test_reti_inventory_restores_full_status_and_preserves_registers(self):
        rows=list(interrupt_return_cases());self.assertEqual(len(rows),1412)
        self.assertEqual(len({r['name'] for r in rows}),1412)
        for row in rows:
            self.assertEqual(row['regs'],row['expected_regs'])
            self.assertEqual(row['expected_st'],extract(row['initial_memory'],row['initial_sp'],32,False))
            pc=extract(row['initial_memory'],(row['initial_sp']+32)&0xFFFFFFFF,32,False)&~15
            self.assertEqual(row['stack_control_flow']['target'],pc)
            self.assertEqual(row['expected_extra_regs']['sp'],(row['initial_sp']+64)&0xFFFFFFFF)
            self.assertFalse(row['conditions']['pbx'])

    def test_rets_literal_arguments_and_saved_pc(self):
        for n,sp in [(0,0x0FF00020),(1,0x0FF00030),(2,0x0FF00040),(16,0x0FF00120),(31,0x0FF00210)]:
            row=rets_fixture('guide',False,n=n,address=0x0FF00000,target=0x1FFF0)
            self.assertEqual(row['initial_memory'],[(0x0FF00000,0xFFF0),(0x0FF00010,1)])
            self.assertEqual(row['expected_extra_regs']['sp'],sp)
            self.assertEqual(row['stack_control_flow']['target'],0x1FFF0)
        with self.assertRaises(ValueError):rets_fixture('bad',False,n=32)

    def test_rets_primary_counts_ignore_field_size_and_preserve_status(self):
        rows=list(return_cases());self.assertEqual(len(rows),1488)
        self.assertEqual(len({r['name'] for r in rows}),1488)
        for row in rows:
            sp=row['initial_sp'];n=row['opcode']&31
            self.assertEqual(row['states'],7+2*bool(sp&15)+3*row['cache_disabled'])
            self.assertEqual(row['data_load']['width'],32)
            self.assertEqual(row['expected_st'],row['regs'][3])
            self.assertEqual(row['regs'],row['expected_regs'])
            self.assertEqual(row['expected_extra_regs']['sp'],(sp+32+16*n)&0xFFFFFFFF)
            pc=extract(row['initial_memory'],sp,32,False)&~15
            self.assertEqual(row['stack_control_flow']['target'],pc)

    def test_rets_warm_target_and_following_bank_are_real_program_words(self):
        rows=[r for r in return_cases() if 'control_follow' in r]
        self.assertEqual(len(rows),48)
        for row in rows:
            words,start,target=program(row)
            self.assertEqual(words[(target-0x1000)//16],row['expected_next_opcode'])
            self.assertEqual(words[(target-0x1000)//16+2],0x016C)
            self.assertEqual(words[(start-0x1000)//16],row['opcode'])
            self.assertEqual(row['follow_pc'],target+16)
            self.assertEqual(program(row),(words,start,target))
        sparse=rets_fixture('sparse',False,target=0x80010000)
        words,start,target=program(sparse)
        self.assertEqual(dict(sparse['initial_memory'])[target],0x0300)
        self.assertEqual(dict(sparse['initial_memory'])[target+16],0x016C)
        self.assertEqual(program(sparse),(words,start,target))

    def test_rets_full_pc_and_sp_wrap_preserve_low_bit_rule(self):
        for low in range(16):
            row=rets_fixture('low',False,n=31,target=0xFFFF1800,low=low)
            self.assertEqual(row['stack_control_flow']['target'],0xFFFF1800)
        wrapped=rets_fixture('wrap',False,n=31,address=0xFFFFFFF0,target=0x10000)
        self.assertEqual(wrapped['expected_extra_regs']['sp'],0x200)
        self.assertEqual(wrapped['stack_control_flow']['target'],0x10000)

    def test_rets_wrong_timing_rejected_with_correct_target_and_state(self):
        for offset,clocks in [(0,80),(15,104)]:
            row=rets_fixture('model',False,offset)
            obs=dict(clocks=clocks,paused=7,st=row['expected_st'],**row['expected_extra_regs'])
            obs.update({'a'+str(q):v for q,v in enumerate(row['expected_regs'])})
            self.assertEqual(check(row,obs,1,7),[])
            obs['clocks']-=8;self.assertTrue(check(row,obs,1,7))

    def test_popst_primary_counts_and_full_stack_status(self):
        for off in (False,True):
            aligned=popst_fixture('model',off,loaded=0xC0000010,address=0x0FF00000)
            unaligned=popst_fixture('model',off,15,loaded=0x60000810)
            self.assertEqual(aligned['states'],11 if off else 8)
            self.assertEqual(unaligned['states'],13 if off else 10)
            self.assertEqual(aligned['expected_st'],0xC0000010)
            self.assertEqual(aligned['expected_extra_regs']['sp'],0x0FF00020)
            self.assertEqual(aligned['initial_memory'],[(0x0FF00000,0x10),(0x0FF00010,0xC000)])
            self.assertEqual(aligned['regs'],aligned['expected_regs'])

    def test_popst_width_ignores_both_original_field_definitions(self):
        rows=list(stack_cases());self.assertEqual(len(rows),806)
        self.assertEqual(len({r['name'] for r in rows}),806)
        for r in rows:
            self.assertEqual(r['data_load']['width'],32)
            self.assertEqual(r['expected_st'],extract(r['initial_memory'],r['initial_sp'],32,False))
            self.assertEqual(r['expected_extra_regs']['sp'],(r['initial_sp']+32)&0xFFFFFFFF)
            self.assertEqual(r['initial_memory'],r['expected_memory'])

    def test_popst_waits_charge_all_stack_words_and_realign_pause(self):
        for offset,clocks in [(0,88),(15,112)]:
            row=popst_fixture('model',False,offset)
            obs=dict(clocks=clocks,paused=7,st=row['expected_st'],**row['expected_extra_regs'])
            obs.update({'a'+str(q):v for q,v in enumerate(row['expected_regs'])})
            self.assertEqual(check(row,obs,1,7),[])
            obs['clocks']-=8;self.assertTrue(check(row,obs,1,7))

    def test_popst_source_window_does_not_hide_a_gap_between_stack_words(self):
        row=popst_fixture('model',False);row.update(test_pc=0x1000,next_pc=0x1010)
        obs=dict(start=0,end=64,clocks=64)
        trace=['BUS_BEGIN 0 0 00005000 0000 0','BUS_END 16 0 00005000 0810',
               'BUS_BEGIN 16 0 00005010 0000 0','BUS_END 32 0 00005010 0000']
        self.assertEqual(check_bus(row,obs,trace,0),[])
        bad=[s.replace('BEGIN 16','BEGIN 24').replace('END 32','END 40') for s in trace]
        self.assertTrue(any('not consecutive' in e for e in check_bus(row,obs,bad,0)))

    def test_timing_mutation_cannot_pass_with_an_incorrect_following_instruction(self):
        row=dict(expected_regs=[1,2,3,4],expected_st=0x10,
                 expected_follow_regs=[1,9,3,4],expected_follow_st=0x10,
                 observed=dict(a0=1,a1=2,a2=3,a3=4,st=0x10),
                 observed_follow=dict(a0=1,a1=9,a2=3,a3=4,st=0x10))
        self.assertTrue(correct_architecture(row))
        row['observed_follow']['a1']=0
        self.assertFalse(correct_architecture(row))
        row['observed_follow']['a1']=9
        row['expected_follow_extra_regs']={'sp':0x5000};row['observed_follow']['sp']=0x5000
        self.assertTrue(correct_architecture(row))
        row['observed_follow']['sp']=0x4000
        self.assertFalse(correct_architecture(row))

    def test_emu_run_keeps_primary_count_alternatives(self):
        rows=list(emu_cases());self.assertEqual(len(rows),296)
        self.assertEqual(len({r['name'] for r in rows}),296)
        for r in rows:
            self.assertEqual(r['states'],9 if r['cache_disabled'] else 6)
            self.assertEqual(r['source_values']['entry_cpu'],8)
            self.assertEqual(r['source_values']['entry_cd'],11)
            self.assertEqual(r['source_values']['datasheet_cpu'],6)
        audit=inventory(rows,accept_project_choices=True)
        self.assertEqual(len(audit['project_source_choices']),296)
        self.assertEqual(audit['unresolved_source_probes'],[])
        self.assertEqual(len(inventory(rows)['unresolved_source_probes']),296)

    def test_emu_run_nop_preserves_full_state_and_ignored_fields(self):
        rows=list(emu_cases())
        for row in rows:
            self.assertEqual(row['opcode'],0x0100)
            self.assertEqual(row['regs'],row['expected_regs'])
            self.assertEqual(row['expected_st'],row['regs'][3])
            self.assertEqual(row['initial_sp'],row['expected_extra_regs']['sp'])
            for q,v in row['initial_b_regs'].items():self.assertEqual(v,row['expected_extra_regs']['b'+str(q)])
            self.assertTrue(row['conditions']['run'])
        self.assertEqual({r['conditions']['opcode_offset'] for r in rows if '_phase_' in r['name']},{0,1,2,3})

    def test_emu_correct_nop_at_wrong_time_is_rejected(self):
        row=next(r for r in emu_cases() if not r['cache_disabled'])
        obs=dict(clocks=48,paused=0,st=row['expected_st'],**row['expected_extra_regs'])
        obs.update({'a'+str(q):v for q,v in enumerate(row['expected_regs'])})
        self.assertEqual(check(row,obs),[])
        obs['clocks']=40;self.assertTrue(check(row,obs))

    def test_two_address_copy_primary_equation_and_printed_alternatives(self):
        self.assertEqual(copy_counts(0,0,16,mode='offset_offset')[:3],(5,1,15))
        self.assertEqual(copy_counts(0,0,32,mode='absolute_absolute')[:3],(9,3,27))
        self.assertEqual(copy_counts(0,0,16,mode='absolute_absolute')[4],dict(
            summary_cpu=7,summary_cd=23,policy_cpu=7,policy_cd=23,entry_typical_cpu=7,entry_typical_cd=12))
        self.assertEqual(copy_counts(0,0,8,byte=True,mode='offset_offset')[4],dict(
            summary_cpu=5,summary_cd=7,policy_cpu=5,policy_cd=17,entry_typical_cpu=5,entry_typical_cd=9))
        self.assertEqual(copy_counts(0,0,8,byte=True,mode='absolute_absolute')[4],dict(
            summary_cpu=7,summary_cd=7,policy_cpu=7,policy_cd=25,entry_typical_cpu=7,entry_typical_cd=25))

    def test_two_address_absolute_encoding_changes_no_register(self):
        for byte,opcode in [(False,0x07C0),(True,0x0340)]:
            row=copy_fixture(8 if byte else 32,0,0,1,False,0,byte=byte,mode='absolute_absolute',
                             bank=1,source=15,dest=15,source_address=0xF0005000,destination_address=0xE0006000)
            self.assertEqual(row['opcode'],opcode)
            self.assertEqual(row['extensions'],[0x5000,0xF000,0x6000,0xE000])
            self.assertEqual(row['regs'],row['expected_regs'])
            self.assertEqual(row['initial_sp'],row['expected_extra_regs']['sp'])
            for q,v in row['initial_b_regs'].items():self.assertEqual(v,row['expected_extra_regs']['b'+str(q)])
            self.assertIsNone(row['conditions']['source_register'])
            self.assertIsNone(row['conditions']['destination_register'])

    def test_two_address_offset_alias_has_two_independent_displacements(self):
        row=copy_fixture(16,0,0,1,False,0,mode='offset_offset',bank=1,source=15,dest=15,
                         destination_address=0x8000,displacement=-32768,destination_displacement=32767)
        self.assertEqual(row['opcode'],0xBBFF)
        self.assertEqual(row['extensions'],[0x8000,0x7FFF])
        self.assertEqual(row['data_copy']['source'],0xFFFF8001)
        self.assertEqual(row['data_copy']['destination'],0x8000)
        self.assertEqual(row['initial_sp'],row['expected_extra_regs']['sp'])

    def test_two_address_literal_results_anchor_signed_operand_endpoints(self):
        rows=list(copy_pair_literals());self.assertEqual(len(rows),154)
        for row in rows:
            self.assertEqual(row['literal_model_memory'],row['expected_memory'],row['name'])
        sample=next(r for r in rows if 'guide_byte_so-32768_do32767' in r['name'] and r['conditions']['bank']==0)
        self.assertEqual(sample['regs'][0],0x18000)
        self.assertEqual(sample['regs'][1],0x9001)
        self.assertEqual(sample['extensions'],[0x8000,0x7FFF])

    def test_two_address_copy_waits_charge_every_operand_and_transfer(self):
        row=copy_fixture(16,0,0,0,True,0,mode='absolute_absolute')
        obs=dict(clocks=240,paused=0,st=row['expected_st'],**row['expected_extra_regs'])
        obs.update({'a'+str(q):v for q,v in enumerate(row['expected_regs'])})
        # 23 states plus seven external waits: four operands/read/write/fetch.
        self.assertEqual(check(row,obs,1),[])
        obs['clocks']=232;self.assertTrue(check(row,obs,1))

    def test_two_address_copy_cold_all_four_operand_positions(self):
        rows=list(copy_pair_cases())
        self.assertEqual(len({r['name'] for r in rows}),len(rows))
        cold=[r for r in rows if r.get('cache_miss')=='copy_extension']
        self.assertEqual({r['miss_word'] for r in cold if r['conditions']['mode']=='absolute_absolute'},{1,2,3,4})
        for row in cold:
            self.assertEqual(row['measure_pass'],0)
            self.assertEqual(row['memory_before_measured'],row['initial_memory'])
            self.assertEqual(row['states'],row['data_copy']['cpu']+9+(9+row['data_copy']['hidden'] if row.get('next_opcode_miss') else 0))

    def test_two_address_cold_fifth_word_waits_for_hidden_writes(self):
        row=next(r for r in copy_pair_cases() if r.get('next_opcode_miss') and
                 r['data_copy']['width']==16 and r['data_copy']['source']&15==0)
        self.assertEqual(row['states'],7+1+18)
        obs=dict(clocks=288,paused=0,st=row['expected_st'],**row['expected_extra_regs'])
        obs.update({'a'+str(q):v for q,v in enumerate(row['expected_regs'])})
        # Source/write plus eight fill words all charge a wait.
        self.assertEqual(check(row,obs,1),[])
        obs['clocks']=280;self.assertTrue(check(row,obs,1))

    def test_two_address_copy_project_choices_keep_known_targets_open(self):
        audit=inventory(copy_pair_cases(),accept_project_choices=True)
        self.assertEqual(audit['unresolved_source_probes'],[])
        self.assertTrue(audit['project_source_choices'])
        strict=inventory(copy_pair_cases())
        self.assertEqual(len(strict['unresolved_source_probes']),len(audit['project_source_choices']))
        self.assertFalse(audit['full_isa_signoff'])

    def test_source_extension_copy_entry_counts_and_alternatives(self):
        self.assertEqual(copy_counts(0,0,16,mode='offset_post')[:3],(5,1,12))
        self.assertEqual(copy_counts(0,0,16,mode='absolute_post')[:3],(5,1,15))
        self.assertEqual(copy_counts(0,0,32,mode='offset_post')[:3],(7,3,16))
        self.assertEqual(copy_counts(0,0,32,mode='absolute_post')[:3],(7,3,19))
        self.assertEqual(copy_counts(0,0,32,mode='offset_post')[4],dict(
            summary_cpu=7,summary_cd=13,policy_cpu=7,policy_cd=16,entry_typical_cpu=7,entry_typical_cd=16))
        self.assertEqual(copy_counts(15,1,18,mode='absolute_post')[4],dict(
            summary_cpu=7,summary_cd=25,policy_cpu=9,policy_cd=25,entry_typical_cpu=None,entry_typical_cd=None))

    def test_source_extension_copy_absolute_encoding_has_no_source_register(self):
        row=copy_fixture(16,0,0,1,False,0,mode='absolute_post',bank=1,source=2,dest=15,source_address=0xF0005000)
        self.assertEqual(row['opcode'],0xD61F)
        self.assertEqual(row['extensions'],[0x5000,0xF000])
        self.assertEqual(row['initial_b_regs'][2],row['expected_extra_regs']['b2'])
        self.assertEqual(row['expected_extra_regs']['sp'],0x6010)

    def test_source_extension_copy_alias_uses_offset_before_increment(self):
        row=copy_fixture(16,0,0,0,False,0,mode='offset_post',source=0,dest=0,
                         source_address=0x5000,destination_address=0x5000,displacement=17)
        self.assertEqual(row['regs'][0],0x5000)
        self.assertEqual(row['data_copy']['source'],0x5011)
        self.assertEqual(row['data_copy']['destination'],0x5000)
        self.assertEqual(row['expected_regs'][0],0x5010)
        self.assertEqual(row['extensions'],[17])

    def test_source_extension_copy_literals_match_bit_model(self):
        rows=list(copy_extension_literals());self.assertEqual(len(rows),52)
        for row in rows:
            self.assertEqual(row['literal_model_memory'],row['expected_memory'],row['name'])
            self.assertIn('inconsistent',row['literal_source_notes'])

    def test_source_extension_copy_waits_include_operand_words(self):
        row=copy_fixture(16,0,0,0,True,0,mode='offset_post')
        obs=dict(clocks=128,paused=0,st=row['expected_st'],**row['expected_extra_regs'])
        obs.update({'a'+str(q):v for q,v in enumerate(row['expected_regs'])})
        self.assertEqual(check(row,obs,1),[])
        obs['clocks']=120
        self.assertTrue(check(row,obs,1))

    def test_source_extension_copy_source_choices_are_explicit(self):
        rows=list(copy_extension_cases())
        audit=inventory(rows,accept_project_choices=True)
        self.assertEqual(audit['unresolved_source_probes'],[])
        self.assertTrue(audit['project_source_choices'])
        self.assertTrue(inventory(rows)['unresolved_source_probes'])
        for row in rows:
            if row.get('cache_miss')=='copy_extension':
                self.assertEqual(row['measure_pass'],0)
                self.assertEqual(row['memory_before_measured'],row['initial_memory'])

    def test_pointer_copy_literal_memory_examples(self):
        rows=list(pointer_copy_literals());self.assertEqual(len(rows),104)
        # Hand-transcribed After A0/A1 columns, p.12-142, independent of
        # the fixture's general pointer-update calculation.
        post_after=((0x15501,0x1553E),(0x1550A,0x1553D),(0x15514,0x15549),
                    (0x15520,0x15543),(0x15517,0x15539),(0x1551E,0x15547),
                    (0x1551B,0x15547),(0x1552C,0x15556),(0x1552F,0x1554B),
                    (0x1552F,0x1554F),(0x15530,0x1555C),(0x15530,0x1555F),
                    (0x15520,0x15550))
        for row in rows:
            self.assertEqual(row['literal_model_memory'],row['expected_memory'],row['name'])
            if row['conditions']['mode']=='post':
                q=int(row['name'].split('guide_field')[1].split('_')[0])
                pair=tuple(row['expected_extra_regs']['b'+str(r)] for r in (0,1)) if row['conditions']['bank'] else tuple(row['expected_regs'][:2])
                self.assertEqual(pair,post_after[q],row['name'])

    def test_pointer_copy_alias_updates_twice_in_order(self):
        for mode,src,dst,result in [('post',0x5000,0x5010,0x5020),('pre',0x5000,0x4FF0,0x4FF0)]:
            for bank,reg in [(0,0),(1,0),(0,15),(1,15)]:
                row=copy_fixture(16,0,0,0,False,0,source_address=0x5000,destination_address=0x5000,
                                 mode=mode,bank=bank,source=reg,dest=reg)
                self.assertEqual((row['data_copy']['source'],row['data_copy']['destination']),(src,dst))
                self.assertEqual(row['expected_extra_regs']['sp'] if reg==15 else
                                 row['expected_extra_regs']['b0'] if bank else row['expected_regs'][0],result)

    def test_pointer_copy_primary_counts_and_alternatives(self):
        self.assertEqual(copy_counts(0,0,16,mode='post')[:4],(4,0,7,1))
        self.assertEqual(copy_counts(0,0,16,mode='pre')[:4],(4,1,8,1))
        self.assertEqual(copy_counts(15,15,32,mode='post')[:4],(10,8,21,13))
        self.assertEqual(copy_counts(15,15,32,mode='pre')[:4],(10,9,22,13))
        self.assertEqual(copy_counts(15,1,18,mode='post')[4],dict(summary_cpu=6,summary_cd=17,policy_cpu=8,policy_cd=17))
        self.assertEqual(copy_counts(1,1,16,mode='pre')[4],dict(summary_cpu=6,summary_cd=15,policy_cpu=6,policy_cd=16))

    def test_pointer_copy_project_choices_remain_explicit(self):
        audit=inventory(pointer_copy_cases(),accept_project_choices=True)
        self.assertFalse(audit['full_isa_signoff'])
        self.assertEqual(audit['unresolved_source_probes'],[])
        self.assertTrue(audit['project_source_choices'])
        self.assertTrue(inventory(pointer_copy_cases())['unresolved_source_probes'])

    def test_pointer_copy_write_overlap_is_independent_of_cpu_retirement(self):
        row=copy_fixture(16,0,0,0,False,0,mode='post')
        self.assertEqual(row['states'],4)
        self.assertEqual(row['data_copy']['write_start'],2)
        reads,writes=copy_transactions(row)
        obs=dict(start=0,end=32,clocks=32,paused=0)
        trace=['BUS_BEGIN 0 0 00005000 %04x 0'%reads[0][2],
               'BUS_END 16 0 00005000 %04x'%reads[0][2],
               'BUS_BEGIN 16 1 00006000 %04x 0'%writes[0][2],
               'BUS_END 32 1 00006000 %04x'%writes[0][2]]
        self.assertEqual(check_store_bus(row,obs,trace,0),[])
        late=[s.replace('16 1','24 1').replace('32 1','40 1') for s in trace]
        self.assertTrue(check_store_bus(row,obs,late,0))

    def test_copy_alignment_classes(self):
        rows=[(0,16,'A'),(0,8,'B'),(4,8,'B'),(0,32,'C'),
              (15,17,'D'),(0,17,'E'),(7,16,'F'),(15,18,'G')]
        for address,width,expected in rows:self.assertEqual(copy_alignment(address,width),expected)
        with self.assertRaises(ValueError):copy_alignment(0,33)

    def test_copy_literal_memory_examples(self):
        rows=list(copy_literals());self.assertEqual(len(rows),116)
        for row in rows:self.assertEqual(row['literal_model_memory'],row['expected_memory'],row['name'])

    def test_copy_overlap_models_each_warm_pass(self):
        row=copy_fixture(32,0,0,0,False,3,source_address=0x5007,destination_address=0x5008)
        image=sum(value<<(address-0x5000) for address,value in row['initial_memory'])
        mask=(1<<32)-1
        for key in ('memory_before_measured','expected_memory'):
            value=(image>>7)&mask
            image=(image&~(mask<<8))|(value<<8)
            self.assertEqual(sum(value<<(address-0x5000) for address,value in row[key]),image)
        self.assertNotEqual(row['memory_before_measured'],row['expected_memory'])

    def test_copy_byte_has_no_field_encoding_bit(self):
        row=copy_fixture(8,0,0,1,True,0,byte=True)
        self.assertEqual(row['opcode']&0xFE00,0x9C00)

    def test_copy_wrapped_source_preserves_initial_reset_vector(self):
        row=copy_fixture(32,0,0,1,False,0,source_address=0xFFFFFFF8,
                         destination_address=0x8000600F)
        self.assertEqual(dict(row['initial_memory'])[0xFFFFFFF0],0)
        reads,_=copy_transactions(row)
        self.assertEqual([item[1] for item in reads],[0xFFFFFFF0,0,16])

    def test_copy_primary_counts_retain_discrepancies(self):
        self.assertEqual(copy_counts(0,0,16)[:4],(3,1,7,1))
        self.assertEqual(copy_counts(1,0,16)[:4],(5,1,9,4))
        self.assertEqual(copy_counts(15,1,32)[:4],(9,9,21,13))
        self.assertEqual(copy_counts(15,1,18)[:4],(7,7,17,12))
        self.assertEqual(copy_counts(15,1,18)[4]['summary_cpu'],5)
        self.assertEqual(copy_counts(0,0,8,byte=True)[4]['summary_cd'],7)

    def test_copy_waits_charge_source_and_keep_trailing_writes_hidden(self):
        row=copy_fixture(16,0,0,0,False,0)
        observed=dict(start=0,end=40,clocks=40,paused=7,st=row['expected_st'],
                      **{f'a{q}':v for q,v in enumerate(row['expected_regs'])},
                      **row['expected_extra_regs'])
        self.assertEqual(check(row,observed,1,7),[])
        observed['clocks']=48;observed['end']=48
        self.assertTrue(check(row,observed,1,7))

    def copy_trace(self):
        row=copy_fixture(16,0,0,0,False,0)
        row.update(test_pc=0x1000,next_pc=0x1010)
        reads,writes=copy_transactions(row)
        trace=[]
        for offset,(kind,address,data,iaq) in zip((0,16),reads+writes):
            trace += [f'BUS_BEGIN {96+offset} {kind} {address:08x} {data:04x} {iaq}',
                      f'BUS_END {112+offset} {kind} {address:08x} {data:04x}']
        return row,dict(start=96,end=120,clocks=24),trace

    def test_copy_padded_duration_cannot_hide_short_bus_cycle(self):
        row,observed,trace=self.copy_trace()
        self.assertEqual(check_store_bus(row,observed,trace,0),[])
        trace[1]=trace[1].replace('112','111',1)
        self.assertTrue(any('duration' in e for e in check_store_bus(row,observed,trace,0)))

    def test_copy_padded_duration_cannot_hide_serialized_write(self):
        row,observed,trace=self.copy_trace()
        trace[2]=trace[2].replace('112','120',1);trace[3]=trace[3].replace('128','136',1)
        self.assertTrue(any('start' in e for e in check_store_bus(row,observed,trace,0)))

    def test_copy_dependency_includes_the_source_read_wait(self):
        row=copy_fixture(16,0,0,0,False,0)
        row.update(test_pc=0x1000,next_pc=0x1010,follow_delay=0)
        reads,writes=copy_transactions(row)
        destination=row['data_copy']['destination']
        plan=reads+writes+[(0,destination,dict(row['expected_memory'])[destination],0)]
        trace=[]
        for start,(kind,address,data,iaq) in zip((8,32,56),plan):
            trace += [f'BUS_BEGIN {start} {kind} {address:08x} {data:04x} {iaq}',
                      f'BUS_END {start+24} {kind} {address:08x} {data:04x}']
        observed=dict(start=0,end=40,clocks=40)
        self.assertEqual(check_store_bus(row,observed,trace,1,7),[])
        trace[4]=trace[4].replace('56','48',1);trace[5]=trace[5].replace('80','72',1)
        self.assertTrue(any('start' in e for e in check_store_bus(row,observed,trace,1,7)))

    def test_copy_project_source_policy_keeps_byte_targets_open(self):
        from copy_cases import copy_cases
        audit=inventory(copy_cases(),accept_project_choices=True)
        self.assertEqual(len(audit['project_source_choices']),100)
        self.assertEqual(len(audit['unresolved_source_probes']),332)
        self.assertEqual(sum(row['kind']=='agreed-published-target-gap'
            for row in audit['unresolved_source_probes']),18)
        self.assertEqual({row['identifier'] for row in audit['unresolved_source_probes']},{'MOVB_IND_IND'})

    def test_project_choice_is_explicit_and_keeps_all_sources(self):
        row=xy_fixture('CMPXY',1,2)
        audit=inventory([row],accept_project_choices=True)
        self.assertEqual(audit['unresolved_source_probes'],[])
        choice=audit['project_source_choices'][0]
        self.assertEqual(choice['source_values'],row['source_values'])
        self.assertFalse(choice['project_choice']['official_ti_resolution'])
        self.assertEqual(choice['project_choice']['authority'],'project-owner-2026-10-18')

    def test_project_choice_does_not_establish_full_signoff(self):
        complete=[dict(name=key,coverage_id=key,cache_disabled=False) for key in REQUIRED]
        row=store_fixture('offset',16,0,0,True,0)
        audit=inventory([*complete,row],accept_project_choices=True)
        self.assertTrue(audit['gate_passed'])
        self.assertFalse(audit['full_isa_signoff'])
        self.assertEqual(len(audit['project_source_choices']),1)

    def test_project_choices_do_not_waive_agreed_targets(self):
        row=store_fixture('absolute',8,0,0,False,0,byte=True)
        audit=inventory([row],accept_project_choices=True)
        self.assertEqual(audit['project_source_choices'],[])
        self.assertEqual(audit['unresolved_source_probes'][0]['kind'],'agreed-published-target-gap')

    def test_project_choices_do_not_waive_absolute_byte_extrapolations(self):
        row=store_fixture('absolute',8,1,0,True,0,byte=True)
        audit=inventory([row],accept_project_choices=True)
        self.assertEqual(audit['project_source_choices'],[])
        self.assertEqual(len(audit['unresolved_source_probes']),1)

    def test_new_source_alternative_cannot_inherit_project_choice(self):
        row=xy_fixture('CMPXY',1,2)
        row['source_values']['entry_cpu']=2
        audit=inventory([row],accept_project_choices=True)
        self.assertEqual(audit['project_source_choices'],[])
        self.assertEqual(len(audit['unresolved_source_probes']),1)

    def test_project_choice_cannot_move_to_another_form(self):
        row=xy_fixture('CMPXY',1,2);row['coverage_id']='ADDXY_RR'
        audit=inventory([row],accept_project_choices=True)
        self.assertEqual(audit['project_source_choices'],[])
        self.assertEqual(len(audit['unresolved_source_probes']),1)

    def test_changed_expectation_cannot_inherit_project_choice(self):
        row=xy_fixture('CMPXY',1,2)
        row['states']=2;row['source_values']['policy_cpu']=2
        audit=inventory([row],accept_project_choices=True)
        self.assertEqual(audit['project_source_choices'],[])
        self.assertEqual(len(audit['unresolved_source_probes']),1)

    def test_conversion_project_choice_preserves_printed_results(self):
        row=coordinate_fixture('CVXYL',0x400030,size=4)
        audit=inventory([row],accept_project_choices=True)
        self.assertEqual(audit['unresolved_source_probes'],[])
        choice=audit['project_source_choices'][0]
        self.assertEqual(choice['kind'],'unresolved-behavior-source')
        self.assertEqual(choice['source_values']['entry_example_result'],0x20000)
        self.assertEqual(choice['source_values']['formula_result'],0x200C0)

    def test_project_choice_still_audits_actual_expected_result(self):
        row=coordinate_fixture('CVXYL',0x400030,size=4)
        row['expected_regs'][0]^=1
        with self.assertRaisesRegex(ValueError,'source result policy differs'):
            inventory([row],accept_project_choices=True)

    def test_project_choice_inventory_leaves_absolute_byte_open(self):
        # Preserve the independently audited coordinate-stage inventory;
        # later families have their own source-policy checks below.
        audit=inventory((row for row in cases() if 'data_copy' not in row and row['coverage_id']!='EMU'),accept_project_choices=True)
        self.assertEqual(len(audit['project_source_choices']),3520)
        self.assertEqual(len(audit['unresolved_source_probes']),116)
        self.assertEqual({r['identifier'] for r in audit['unresolved_source_probes']},{'MOVB_R_ABS'})
        self.assertEqual(sum(r['kind']=='agreed-published-target-gap' for r in audit['unresolved_source_probes']),27)
        self.assertFalse(audit['gate_passed'])

    def test_point_code_literal_examples(self):
        for point,value in CPW_EXAMPLES:
            self.assertEqual(point_code(point,0x50005,0xA000A),value)

    def test_point_code_signed_limits(self):
        self.assertEqual(point_code(0x7FFF8000,0,0x7FFF7FFF),0x20)
        self.assertEqual(point_code(0x80007FFF,0,0x7FFF7FFF),0x80)
        with self.assertRaises(ValueError):point_code(0,0x80000000,0x7FFF7FFF)

    def test_conversion_literal_examples_preserve_discrepancies(self):
        actual=[linear(pt,offset,size,conv) for pt,offset,size,conv,_ in CV_EXAMPLES]
        self.assertEqual([q for q,(a,row) in enumerate(zip(actual,CV_EXAMPLES)) if a!=row[-1]],[2,3,4,8])
        self.assertEqual([actual[q] for q in [2,3,4,8]],[0x200C0,0x280C0,0x0F0200C0,0x10030])
        for q in [0,1,5,6,7]:self.assertEqual(actual[q],CV_EXAMPLES[q][-1])

    def test_conversion_pitch_and_or_before_offset(self):
        for conv in range(32):self.assertEqual(linear(0x10000,0,1,conv),1<<(31-conv))
        self.assertEqual(linear(0x10001,0,1,31),1)
        self.assertEqual(linear(0x10001,0xFFFFFFFF,1,31),0)
        self.assertEqual(linear(0x80007FFF,0x30,16,28),0x20)

    def test_behavior_source_conflict_blocks_acceptance(self):
        row=coordinate_fixture('CVXYL',0x400030,size=4)
        result=inventory([row]);self.assertFalse(result['gate_passed'])
        self.assertEqual(result['unresolved_source_probes'][0]['kind'],'unresolved-behavior-source')
        self.assertEqual(row['source_values']['entry_cpu'],row['source_values']['policy_cpu'])

    def test_behavior_source_conflict_cannot_hide_behind_status(self):
        row=coordinate_fixture('CVXYL',0x400030,size=4)
        row['timing_source_status']='primary-summary-consistent';del row['source_conflict_kind']
        self.assertEqual(inventory([row])['unresolved_source_probes'][0]['kind'],'unresolved-behavior-source')

    def test_result_source_policy_must_match_fixture(self):
        row=coordinate_fixture('CVXYL',0x400030,size=4)
        row['source_values']['policy_result']=0x1234
        with self.assertRaisesRegex(ValueError,'source result policy differs'):inventory([row])

    def test_implicit_register_observation_protocol(self):
        log='RESULT case=0 clocks=8 start=100 end=108 paused=0 st=810 a0=1 a1=2 a2=3 a3=4\n'
        extra='IMPLICIT b4=12345678 b5=00050005 b6=000a000a\n'
        result=parse_result(log+extra);self.assertEqual(result['b4'],0x12345678)
        self.assertEqual(result['b6'],0xA000A)
        with self.assertRaisesRegex(ValueError,'duplicate implicit-register'):parse_result(log+extra+extra)

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
