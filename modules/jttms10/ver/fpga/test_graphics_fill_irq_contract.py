# SPDX-License-Identifier: GPL-3.0-or-later
"""Host tests for literal native FILL interrupt fixtures and full bus checks."""
import copy
import contextlib
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import check_results
import check_graphics_fill_irq_mutations as mutations
import event_contract
import graphics_fill_irq_cases
import graphics_fill_irq_contract as contract


def trace(entry):
    engine,interrupt=contract.validate(entry)
    checkpoint=2
    event_after=2 if engine=='xy' else 1
    vector=0xffffffc0 if interrupt=='lint1' else 0xfffffee0
    memory=dict(entry['fixture']['expected_memory'])
    data=[(1,a,d) for a,d in contract.FILL_WRITES[:checkpoint]]
    data += [(1,a,memory[a]) for a in (0x2ff0,0x2fe0,0x2fd0,0x2fc0)]
    data += [(0,vector,0x4000),(0,vector+16,0)]
    data += [(0,a,memory[a]) for a in (0x2fc0,0x2fd0,0x2fe0,0x2ff0)]
    data += [(1,a,d) for a,d in contract.FILL_WRITES[checkpoint:]]
    lines=[]
    for q,(we,address,value) in enumerate(data):
        start=100+16*q; ack=start+2; target_end=ack+4; bus_end=start+16
        lines += [f'BUS_BEGIN {start} {we} {address:08x} {value:04x} 0',
                  f'BUS_ACCEPT {ack}',
                  f'TARGET_BEGIN {ack} {we} {address:08x} {value:04x} 0',
                  f'TARGET_END {target_end} {we} {address:08x} {value:04x}',
                  f'BUS_END {bus_end} {we} {address:08x} {value:04x}']
    request=107 if engine=='l' else 123
    context_request=request+1 if interrupt=='nmi' else request
    complete=max(100+16*7+16,context_request+135)
    first=complete+160
    if interrupt=='nmi':
        lines += [f'STIMULUS {request} 0 1 {event_after:08x} 0110',
                  f'HOST_ACK {request+1}',
                  f'STIMULUS {request+3} 1 5 00000001 0000']
        first=complete+160
    else:
        lines += [f'STIMULUS {request} 0 1 {event_after:08x} 0001',
                  'STIMULUS 350 1 1 00000005 0000']
    lines.append(f'IRQ_BOUNDARY count=1 previous=0 complete={complete} first={first}')
    lines.extend(f'MEMORY {a:08x} {v:04x}' for a,v in entry['fixture']['expected_memory'])
    return lines


class GraphicsFillIRQContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows=graphics_fill_irq_cases.entries(check_results.oracle_module())

    def test_four_literal_fill_programs_validate_and_select_strict_dispatch(self):
        self.assertEqual([contract.validate(x) for x in self.rows],
                         [('l','lint1'),('l','nmi'),('xy','lint1'),('xy','nmi')])
        for row in self.rows:
            self.assertEqual(event_contract.expected_pause(row),0)
            self.assertFalse(event_contract.check_duration(row))
            self.assertFalse(event_contract.check_transfer_observation(row))
        self.assertTrue(event_contract.check_duration({'fixture':{'name':'ordinary'}}))
        self.assertTrue(event_contract.check_transfer_observation({'fixture':{'name':'ordinary'}}))

    def test_default_mutation_dispatch_includes_checkpoint_timing(self):
        temp=Path('/tmp/graphics-fill-mutation-dispatch-test')
        with patch.object(mutations.tempfile,'TemporaryDirectory',
                          return_value=contextlib.nullcontext(str(temp))), \
             patch.object(mutations,'run_mutation') as run_mutation, \
             patch.object(mutations,'run_overlong_checkpoint_mutation') as run_timing, \
             patch.object(sys,'argv',[str(mutations.__file__)]):
            mutations.main()
        self.assertEqual([call.args[0] for call in run_mutation.call_args_list],
                         list(mutations.MUTATIONS))
        run_timing.assert_called_once_with(temp,temp/mutations.MUTATIONS[0][0])

    def test_manifest_json_roundtrip_preserves_literal_memory_contract(self):
        for entry in self.rows:
            with self.subTest(name=entry['name']):
                self.assertEqual(contract.validate(json.loads(json.dumps(entry))),
                                 contract.validate(entry))

    def test_literal_setup_program_frame_and_checkpoint_tampering_fail(self):
        edits=[]
        row=copy.deepcopy(self.rows[0]);row['program_words'][8]^=1;edits.append(row)
        row=copy.deepcopy(self.rows[0]);row['fixture']['register_overrides']['sp']=0x2ff0;edits.append(row)
        row=copy.deepcopy(self.rows[2]);row['fixture']['setup_io']=list(map(list,row['fixture']['setup_io']));row['fixture']['setup_io'][0][1]=8;edits.append(row)
        row=copy.deepcopy(self.rows[0]);row['test_pc']+=16;edits.append(row)
        row=copy.deepcopy(self.rows[1]);row['external_events'][0]['argument']=2;edits.append(row)
        row=copy.deepcopy(self.rows[2]);row['fixture']['expected_extra_regs']['b2']^=1;edits.append(row)
        row=copy.deepcopy(self.rows[1]);row['fixture']['expected_memory'][5]=(0x2fd0,0xf000);edits.append(row)
        for bad in edits:
            with self.subTest(name=bad['name']):
                with self.assertRaises(ValueError): contract.validate(bad)

    def test_full_data_stream_and_target_acknowledgements(self):
        for entry in self.rows:
            observed=dict(start=90,end=900,clocks=810)
            lines=trace(entry)
            errors,observation=contract.check(entry,observed,lines)
            self.assertEqual(errors,[],entry['name'])
            self.assertEqual(observation['engine'],entry['external_contract']['engine'])
            negatives=[]
            bad=lines.copy();bad[0]='BUS_BEGIN 100 1 00009990 aa55 0';negatives.append((bad,'order/kind/address'))
            bad=lines.copy();bad[2]=bad[2].replace('aa55','aa54');negatives.append((bad,'request association/data'))
            bad=lines.copy();bad.remove('BUS_ACCEPT 102');negatives.append((bad,'count differs'))
            bad=lines.copy();bad[3]=bad[3].replace('TARGET_END 106','TARGET_END 100106');bad[1]='BUS_ACCEPT 100102';bad[2]=bad[2].replace('TARGET_BEGIN 102','TARGET_BEGIN 100102');negatives.append((bad,'TARGET transaction'))
            bad=lines.copy();bad[4]=bad[4].replace('BUS_END 116','BUS_END 100116');negatives.append((bad,'BUS transaction'))
            bad=lines.copy();bad[-len(dict(entry['fixture']['expected_memory']))-1]= 'IRQ_BOUNDARY count=1 previous=0 complete=150 first=310';negatives.append((bad,'context completion precedes'))
            for candidate,needle in negatives:
                with self.subTest(case=entry['name'],needle=needle):
                    errors,_=contract.check(entry,observed,candidate)
                    self.assertTrue(any(needle in error for error in errors),errors)

    def test_timing_envelope_and_unexpected_traffic_reject(self):
        entry=self.rows[0];observed=dict(start=90,end=900,clocks=810);lines=trace(entry)
        bad=lines.copy()
        idx=next(i for i,x in enumerate(bad) if x.startswith('IRQ_BOUNDARY '))
        bad[idx]='IRQ_BOUNDARY count=1 previous=0 complete=500 first=660'
        errors,_=contract.check(entry,observed,bad)
        self.assertTrue(any('recognition plus context' in x for x in errors),errors)
        bad=lines.copy();bad.extend(('BUS_BEGIN 800 1 00009990 1234 0','BUS_ACCEPT 802',
            'TARGET_BEGIN 802 1 00009990 1234 0','TARGET_END 806 1 00009990 1234',
            'BUS_END 816 1 00009990 1234'))
        errors,_=contract.check(entry,observed,bad)
        self.assertTrue(any('unexpected data BUS transaction' in x for x in errors),errors)

    def test_overlong_fill_checkpoint_interval_is_rejected(self):
        entry=self.rows[0]
        lines=trace(entry)
        shifted=[]
        bus_index=-1
        for line in lines:
            fields=line.split()
            if fields[0]=='BUS_BEGIN':
                bus_index+=1
            if fields[0] in {'BUS_BEGIN','BUS_ACCEPT','BUS_END','TARGET_BEGIN','TARGET_END'} and bus_index>=1:
                fields[1]=str(int(fields[1])+200)
                line=' '.join(fields)
            elif fields[0]=='STIMULUS' and len(fields)>1 and fields[2]=='1':
                fields[1]=str(int(fields[1])+200)
                line=' '.join(fields)
            elif fields[0]=='IRQ_BOUNDARY':
                fields=[item.split('=',1)[0]+'='+str(int(item.split('=',1)[1])+200)
                        if item.startswith(('complete=','first=')) else item for item in fields]
                line=' '.join(fields)
            shifted.append(line)
        observed=dict(start=90,end=1100,clocks=1010)
        errors,_=contract.check(entry,observed,shifted)
        self.assertTrue(any('FILL request to selected word/row checkpoint: expected 0..161 INCLK, observed 225' in x
                            for x in errors),errors)

    def test_missing_observations_reject(self):
        errors,_=contract.check(self.rows[0],dict(start=100,end=200,clocks=100),[])
        self.assertTrue(any('memory' in x for x in errors),errors)
        self.assertTrue(any('boundaries' in x for x in errors),errors)
        self.assertTrue(any('events' in x for x in errors),errors)


if __name__=='__main__':
    unittest.main()
