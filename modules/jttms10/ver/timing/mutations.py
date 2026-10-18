#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Demonstrate rejection of timing bugs while arithmetic/state remain correct.

Mutations operate only on fresh temporary copies. Positive controls must
pass first. Syntax errors, missing results and functional failures do not
count as successful detection of a timing regression.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
MODULE = HERE.parents[1]


def run_case(work, name, case, extra=(), mutated=False, event_error=None):
    report = work / (name+'.json')
    command = [sys.executable,str(HERE / 'run.py'),'--case',case,'--report',str(report),*extra]
    result = subprocess.run(command,capture_output=True,text=True,timeout=60)
    if not report.exists():
        raise RuntimeError(f'{name}: no report\n{result.stdout}{result.stderr}')
    data = json.loads(report.read_text())
    if len(data['cases']) != 1:
        raise RuntimeError(f'{name}: expected exactly one probe')
    row = data['cases'][0]
    observed = row['observed']
    if event_error is not None:
        if result.returncode!=1 or not row['errors'] or event_error not in result.stdout+result.stderr:
            raise RuntimeError(f'{name}: expected event contract was not rejected\n{result.stdout}{result.stderr}')
        print(f'{name}: PASS (event contract violation rejected)')
        return data
    if observed is None or observed['st'] != row['expected_st'] or any(
            observed[f'a{q}'] != value for q,value in enumerate(row['expected_regs'])) or any(observed.get(n)!=v for n,v in row.get('expected_extra_regs',{}).items()) or ('expected_memory' in row and sorted(row.get('observed_memory',[]))!=sorted(row['expected_memory'])):
        raise RuntimeError(f'{name}: functional failure is not a timing-only mutation\n{result.stdout}{result.stderr}')
    expected_exit = int(mutated)
    if result.returncode != expected_exit or bool(row['errors']) != mutated:
        raise RuntimeError(f'{name}: unexpected detection result (exit={result.returncode})\n{result.stdout}{result.stderr}')
    print(f'{name}: PASS (' + ('timing regression rejected; architectural state correct)' if mutated else 'positive control)'))
    return data


def replace_once(path, old, new):
    source = path.read_text()
    if source.count(old) != 1:
        raise RuntimeError(f'mutation site changed: {path.name}: {old!r}')
    path.write_text(source.replace(old,new))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report',type=Path)
    args = parser.parse_args()
    evidence = {}
    with tempfile.TemporaryDirectory(prefix='jttms10-timing-mutations-') as temp:
        work = Path(temp)
        case = 'mpys_fs2_positive_even_hit'
        evidence['fs_control'] = run_case(work,'fs_control',case)
        evidence['cen_control'] = run_case(work,'cen_control',case,['--pause-clocks','7'])
        evidence['wait_control'] = run_case(work,'wait_control','nop_off',['--wait-states','1'])
        setf_case = 'scalar_setf_f1_fs1_fe0_hit'
        evidence['setf_control'] = run_case(work,'setf_control',setf_case)
        min_case = 'divs_odd_boundary_43_hit'
        zero_case = 'divu_odd_boundary_0_hit'
        evidence['div_min_control'] = run_case(work,'div_min_control',min_case)
        evidence['div_zero_control'] = run_case(work,'div_zero_control',zero_case)
        evidence['bus_min_control'] = run_case(work,'bus_min_control','nop_off')
        miss_case = 'nop_next_subsegment_miss_00000810'
        evidence['miss_control'] = run_case(work,'miss_control',miss_case)
        immediate_case='immediate_addi_16_p0_c0_hit'
        immediate_off='immediate_addi_32_p0_c0_off'
        immediate_miss='immediate_addi_32_extension_miss'
        evidence['immediate_control']=run_case(work,'immediate_control',immediate_case)
        evidence['extension_control']=run_case(work,'extension_control',immediate_off)
        evidence['extension_miss_control']=run_case(work,'extension_miss_control',immediate_miss)
        load_case='load_move_f0_w16_o0_s0_hit'
        load_sign='load_move_f1_w8_o15_s1_off'
        load_full='load_move_f0_w32_o0_s1_hit'
        load_pause='load_move_f0_w32_o15_s1_off'
        load_data='load_move_f0_w32_o15_s0_hit'
        evidence['load_control']=run_case(work,'load_control',load_case)
        evidence['load_sign_control']=run_case(work,'load_sign_control',load_sign,['--wait-states','1'])
        evidence['load_full_control']=run_case(work,'load_full_control',load_full)
        evidence['load_pause_control']=run_case(work,'load_pause_control',load_pause,['--wait-states','1','--pause-clocks','1'])
        evidence['load_data_control']=run_case(work,'load_data_control',load_data)
        pre_case='loadmode_move_pre_phase_r1_off'
        offset_case='loadmode_move_offset_w1_o0_f0_s0_r0_2_0_q0_hit'
        first_word_case='loadmode_move_offset_phase_r1_off'
        second_word_case='loadmode_move_absolute_phase_cold2_w16_o0_r0'
        evidence['pre_mode_control']=run_case(work,'pre_mode_control',pre_case,['--wait-states','1'])
        evidence['offset_mode_control']=run_case(work,'offset_mode_control',offset_case)
        evidence['first_word_control']=run_case(work,'first_word_control',first_word_case,['--wait-states','1','--pause-clocks','1'])
        evidence['second_word_control']=run_case(work,'second_word_control',second_word_case,['--wait-states','1','--pause-clocks','1'])




        flat = work / 'flat-width-hdl'
        shutil.copytree(MODULE / 'hdl',flat)
        replace_once(flat / 'jttms10.v',"6'd5+multiply_half","6'd21")
        evidence['wrong_fs1_latency'] = run_case(work,'wrong_fs1_latency',case,
                                                ['--rtl-dir',str(flat)],mutated=True)

        field = work / 'wrong-setf-hdl'
        shutil.copytree(MODULE / 'hdl',field)
        replace_once(field / 'jttms10.v',
                     "(decode_setf && decode_opcode[9]) ? 6'd2 : 6'd1",
                     "1'b0 ? 6'd2 : 6'd1")
        evidence['wrong_setf_field_latency'] = run_case(work,'wrong_setf_field_latency',setf_case,
                                                      ['--rtl-dir',str(field)],mutated=True)

        minimum = work / 'wrong-div-minimum-hdl'
        shutil.copytree(MODULE / 'hdl',minimum)
        replace_once(minimum / 'jttms10.v',
                     "(div_mod || div_pair ? 16'd1 : 16'd2)","16'd1")
        evidence['wrong_divs_odd_minimum'] = run_case(work,'wrong_divs_odd_minimum',min_case,
                                                    ['--rtl-dir',str(minimum)],mutated=True)

        early = work / 'wrong-div-early-hdl'
        shutil.copytree(MODULE / 'hdl',early)
        replace_once(early / 'jttms10.v',"time_left<=time_left-div_cut_clocks-16'd1;",
                     "time_left<=time_left-16'd1;")
        evidence['wrong_div_early_exit'] = run_case(work,'wrong_div_early_exit',zero_case,
                                                  ['--rtl-dir',str(early)],mutated=True)

        minimum_bus = work / 'short-bus-cycle-hdl'
        shutil.copytree(MODULE / 'hdl',minimum_bus)
        replace_once(minimum_bus / 'jttms10_bus_timer.v',
                     'assign ack=active && left==0 && (io || external_done);',
                     'assign ack=active && left<=STATE_CLKS && (io || external_done);')
        evidence['short_bus_cycle'] = run_case(work,'short_bus_cycle','nop_off',
                                              ['--rtl-dir',str(minimum_bus)],mutated=True)

        q1 = work / 'late-ready-sample-hdl'
        shutil.copytree(MODULE / 'hdl',q1)
        replace_once(q1 / 'jttms10_bus_timer.v','SAMPLE_LEFT_I=3*CLKS_PER_STATE/4;',
                     'SAMPLE_LEFT_I=0;')
        evidence['ready_sample_at_end'] = run_case(work,'ready_sample_at_end','nop_off',
            ['--rtl-dir',str(q1),'--wait-states','1'],mutated=True)

        miss = work / 'missing-miss-processing-hdl'
        shutil.copytree(MODULE / 'hdl',miss)
        replace_once(miss / 'jttms10.v',
                     "fetch_wait<=mem_cached ? 16'd0 : CLKS_PER_STATE[15:0]-16'd2;",
                     "fetch_wait<=control[15] ? CLKS_PER_STATE[15:0]-16'd2 : 16'd0;")
        evidence['missing_miss_processing'] = run_case(work,'missing_miss_processing',miss_case,
                                                     ['--rtl-dir',str(miss)],mutated=True)

        immediate = work / 'wrong-immediate-budget-hdl'
        shutil.copytree(MODULE / 'hdl',immediate)
        replace_once(immediate / 'jttms10.v','decode_btstr || decode_immediate_word ||',
                     'decode_btstr ||')
        evidence['wrong_immediate_word_budget']=run_case(work,'wrong_immediate_word_budget',immediate_case,
                                                      ['--rtl-dir',str(immediate)],mutated=True)

        extension = work / 'missing-extension-processing-hdl'
        shutil.copytree(MODULE / 'hdl',extension)
        replace_once(extension / 'jttms10.v','if(mem_req && mem_ack && (fetch || imm))',
                     'if(mem_req && mem_ack && fetch)')
        evidence['missing_extension_processing']=run_case(work,'missing_extension_processing',immediate_off,
                                                        ['--rtl-dir',str(extension)],mutated=True)

        tail = work / 'missing-extension-miss-tail-hdl'
        shutil.copytree(MODULE / 'hdl',tail)
        replace_once(tail / 'jttms10.v',"time_left<=immediate_tail_clocks-16'd2;",'time_left<=time_left;')
        evidence['missing_extension_miss_tail']=run_case(work,'missing_extension_miss_tail',immediate_miss,
                                                      ['--rtl-dir',str(tail)],mutated=True)

        iaq = work / 'wrong-extension-iaq-hdl'
        shutil.copytree(MODULE / 'hdl',iaq)
        replace_once(iaq / 'jttms10.v','assign mem_iaq = fetch && !early_load && !early_store;','assign mem_iaq = (fetch || imm) && !early_load && !early_store;')
        evidence['wrong_extension_iaq']=run_case(work,'wrong_extension_iaq',immediate_off,
                                              ['--rtl-dir',str(iaq)],mutated=True)

        late_load=work / 'late-indirect-load-hdl'
        shutil.copytree(MODULE / 'hdl',late_load)
        replace_once(late_load / 'jttms10_bus.v','queued_cpu || cpu_seen || word_early','queued_cpu || cpu_seen')
        evidence['late_indirect_load']=run_case(work,'late_indirect_load',load_case,
                                              ['--rtl-dir',str(late_load)],mutated=True)

        sign_wait=work / 'load-wait-consumes-work-hdl'
        shutil.copytree(MODULE / 'hdl',sign_wait)
        replace_once(sign_wait / 'jttms10.v',"time_left<=load_finish_clocks-16'd3;",'time_left<=time_left;')
        evidence['load_wait_consumes_sign_state']=run_case(work,'load_wait_consumes_sign_state',load_sign,
            ['--rtl-dir',str(sign_wait),'--wait-states','1'],mutated=True)

        full=work / 'full-width-sign-penalty-hdl'
        shutil.copytree(MODULE / 'hdl',full)
        replace_once(full / 'jttms10.v',"field_signed && !byte_op && field_size!=6'd32",'field_signed && !byte_op')
        evidence['wrong_full_width_sign_penalty']=run_case(work,'wrong_full_width_sign_penalty',load_full,
                                                         ['--rtl-dir',str(full)],mutated=True)

        pause=work / 'load-absorbs-substate-pause-hdl'
        shutil.copytree(MODULE / 'hdl',pause)
        replace_once(pause / 'jttms10_word.v','early_data_q && data_owner && (slot_eligible || slot_phase==0);',
                     'early_data_q && data_owner;')
        evidence['load_absorbs_substate_pause']=run_case(work,'load_absorbs_substate_pause',load_pause,
            ['--rtl-dir',str(pause),'--wait-states','1','--pause-clocks','1'],mutated=True)

        cached_data=work / 'incorrectly-cached-data-hdl'
        shutil.copytree(MODULE / 'hdl',cached_data)
        path=cached_data/'jttms10_word.v'
        replace_once(path,'.c_req(field_req && program_read)', '.c_req((field_req && program_read) || (data_owner && field_word_req && !field_word_we))')
        replace_once(path,'.c_addr(field_addr)', '.c_addr(program_read ? field_addr : field_word_addr)')
        replace_once(path,'word_req=data_owner ? field_word_req && !data_word_ack : cache_word_req', 'word_req=data_owner && field_word_we ? field_word_req && !data_word_ack : cache_word_req')
        replace_once(path,'word_addr=data_owner ? field_word_addr : cache_word_addr', 'word_addr=data_owner && field_word_we ? field_word_addr : cache_word_addr')
        replace_once(path,'cache_word_ack=word_ack && !data_owner', 'cache_word_ack=word_ack && (!data_owner || !field_word_we)')
        replace_once(path,'data_word_ack<=word_ack && data_owner;', 'data_word_ack<=data_owner && !field_word_we ? cache_ack : word_ack && data_owner;')
        replace_once(path,'if(word_ack && data_owner) data_word_rdata<=word_rdata;', 'if(data_owner && !field_word_we) data_word_rdata<=cache_rdata; else if(word_ack && data_owner) data_word_rdata<=word_rdata;')
        evidence['incorrectly_cached_data_reads']=run_case(work,'incorrectly_cached_data_reads',load_data,
                                                         ['--rtl-dir',str(cached_data)],mutated=True)

        pre_mode=work / 'wrong-pre-load-lead-hdl'
        shutil.copytree(MODULE/'hdl',pre_mode)
        replace_once(pre_mode/'jttms10.v','decode_load_pre || decode_store_pre ? LOAD_PRE : (decode_load_extension || decode_store_extension) ?',
                     'decode_load_pre || decode_store_pre ? LOAD_LEAD : (decode_load_extension || decode_store_extension) ?')
        evidence['wrong_predecrement_lead']=run_case(work,'wrong_predecrement_lead',pre_case,
            ['--rtl-dir',str(pre_mode),'--wait-states','1'],mutated=True)

        offset_mode=work / 'wrong-offset-load-lead-hdl'
        shutil.copytree(MODULE/'hdl',offset_mode)
        replace_once(offset_mode/'jttms10.v',"(decode_load_extension || decode_store_extension) ? LOAD_LEAD : {LOAD_IW{1'b0}}",
                     "(decode_load_extension || decode_store_extension) ? LOAD_LEAD+LOAD_PRE : {LOAD_IW{1'b0}}")
        evidence['wrong_offset_lead']=run_case(work,'wrong_offset_lead',offset_case,
                                            ['--rtl-dir',str(offset_mode)],mutated=True)

        first_word=work / 'early-first-address-word-hdl'
        shutil.copytree(MODULE/'hdl',first_word)
        replace_once(first_word/'jttms10.v',"load_issue_left>LOAD_FIRST_LIMIT","1'b0")
        evidence['early_first_address_word']=run_case(work,'early_first_address_word',first_word_case,
            ['--rtl-dir',str(first_word),'--wait-states','1','--pause-clocks','1'],mutated=True)

        second_word=work / 'early-second-address-word-hdl'
        shutil.copytree(MODULE/'hdl',second_word)
        replace_once(second_word/'jttms10.v',"load_issue_left>LOAD_NEXT_LIMIT","1'b0")
        evidence['early_second_address_word']=run_case(work,'early_second_address_word',second_word_case,
            ['--rtl-dir',str(second_word),'--wait-states','1','--pause-clocks','1'],mutated=True)

        store_case='store_move_indirect_w32_o15_f0_r0_2_0_q1054_hit'
        evidence['store_control']=run_case(work,'store_control',store_case)
        for name,old,new in (
            ('blocking_store',"if(field_post) begin post_busy<=1;post_ack<=1;end", "if(1'b0) begin post_busy<=1;post_ack<=1;end"),
            ('no_cached_write_overlap','.c_req(field_req && program_read)', '.c_req(field_req && program_read && !data_owner)'),
            ('lost_hidden_pending','assign word_pending=field_req || data_owner;', 'assign word_pending=field_req;')):
            mutant=work/name;shutil.copytree(MODULE/'hdl',mutant)
            replace_once(mutant/'jttms10_word.v',old,new)
            evidence[name]=run_case(work,name,store_case,['--rtl-dir',str(mutant)],mutated=True,
                event_error='pending field lost while physical work remains' if name=='lost_hidden_pending' else None)

        store_address_case='storemode_move_offset_phase_r1_off'
        store_fill_case='storemode_move_absolute_phase_cold2_hit'
        evidence['store_address_control']=run_case(work,'store_address_control',store_address_case,['--wait-states','1','--pause-clocks','1'])
        evidence['store_fill_control']=run_case(work,'store_fill_control',store_fill_case,['--wait-states','1','--pause-clocks','1'])
        for name,case,old,new in (
            ('unpaced_store_address',store_address_case,'!((load_pending || store_pending) && imm &&','!(load_pending && imm &&'),
            ('lost_store_fill_work',store_fill_case,"time_left<=immediate_tail_clocks-16'd2;",'time_left<=time_left;')):
            mutant=work/name;shutil.copytree(MODULE/'hdl',mutant)
            replace_once(mutant/'jttms10.v',old,new)
            evidence[name]=run_case(work,name,case,['--rtl-dir',str(mutant),'--wait-states','1','--pause-clocks','1'],mutated=True)

        cen = work / 'ignores-cen-hdl'
        shutil.copytree(MODULE / 'hdl',cen)
        replace_once(cen / 'jttms10.v','if(cen) begin',"if(1'b1) begin")
        evidence['absorbed_cen_pause'] = run_case(work,'absorbed_cen_pause',case,
            ['--rtl-dir',str(cen),'--pause-clocks','7'],mutated=True)

        bench = work / 'ignores-wait.sv'
        shutil.copyfile(HERE / 'test.sv',bench)
        replace_once(bench,'delay_clocks=4+extra_wait;','delay_clocks=4;')
        evidence['omitted_target_wait'] = run_case(work,'omitted_target_wait','nop_off',
            ['--bench',str(bench),'--wait-states','1'],mutated=True)

        prime = work / 'primes-while-paused-hdl'
        shutil.copytree(MODULE / 'hdl',prime)
        replace_once(prime / 'jttms10_ctrl.v','else if(!cen && enable) begin','else if(!cen) begin')
        evidence['sequencer_advances_during_pause'] = run_case(work,'sequencer_advances_during_pause',case,
            ['--rtl-dir',str(prime),'--pause-clocks','7'],mutated=True,
            event_error='instruction sequencer advanced while CEN paused')
    if args.report:
        args.report.parent.mkdir(parents=True,exist_ok=True)
        args.report.write_text(json.dumps(evidence,indent=2)+'\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
