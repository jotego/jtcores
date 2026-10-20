# SPDX-License-Identifier: GPL-3.0-or-later
import copy
from pathlib import Path
import subprocess
import sys
import unittest

import check_external_reference as reference
import check_results as checker
import event_contract
import nmi_nostack_io_cases as cases
import nmi_nostack_io_contract as contract


class NoStackNMIIOContract(unittest.TestCase):
    def test_checker_loads_without_selected_checkout_on_import_path(self):
        # A copied transport supplies its schema but loads the selected checker
        # by filename. A same-named ambient fixture must not supply its oracle.
        script = '''
import importlib.util
from pathlib import Path
import sys
import types
root = Path(sys.argv[1])
schema = importlib.util.spec_from_file_location('stimulus_schema', root/'stimulus_schema.py')
module = importlib.util.module_from_spec(schema)
sys.modules[schema.name] = module
schema.loader.exec_module(module)
if sys.argv[2] == 'shadow':
    poison = types.ModuleType('nmi_nostack_io_cases')
    poison.IO_READS = ()
    sys.modules[poison.__name__] = poison
spec = importlib.util.spec_from_file_location('selected_checker', root/'check_results.py')
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)
contract = checker._event_contract._nostack_io_contract
assert len(contract.IO_READS) == 7
assert contract.IO_READS[5] == (0xc0000160, 0x2a5a, 11)
'''
        for mode in ('absent', 'shadow'):
            with self.subTest(mode=mode):
                result = subprocess.run([sys.executable, '-I', '-c', script,
                                         str(Path(checker.__file__).resolve().parent), mode],
                                        cwd='/', capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)

    @classmethod
    def setUpClass(cls):
        oracle=checker.oracle_module()
        base=dict(fixture=next(c for c in oracle.cases() if c['name']=='nop_hit'))
        cls.rows=cases.entries(base,oracle)

    def sample_trace(self, entry):
        spec,sp,status=contract.validate(entry)
        waits=entry['stimulus']['wait_states']; plan=[(0xfffffee0,0x4000,0),(0xfffffef0,0,0)]
        if not spec['handler_warm']: plan += [(0x4000+16*q,x,1) for q,x in enumerate((0x09e0,0x5678,0x1234,0x0165))]
        for a in range(0x4040,0x42c0,0x10):
            plan.append((a,entry['program_words'][(a-0x1000)//16],1))
        reads=list(contract.IO_READS)
        moves=[0x4090,0x40e0,0x4130,0x4180,0x41d0,0x4220,0x4270]
        lines=[]; t=1200
        for address,data,iaq in plan:
            for prefix,duration in (('BUS',16+8*waits),('TARGET',4+8*waits)):
                begin=f'{prefix}_BEGIN {t} 0 {address:08x} 0000 {iaq}'
                end=f'{prefix}_END {t+duration} 0 {address:08x} {data:04x}'
                lines.extend((begin,end))
            lines.append(f'BUS_ACCEPT {t+1}')
            t+=16+8*waits
            for q,move in enumerate(moves):
                if address==move:
                    a,value,dest=reads[q]; op=0x8400|(14<<5)|dest
                    lines += [f'BUS_BEGIN {t} 5 {a:08x} {op:04x} 0',f'BUS_ACCEPT {t+1}',
                              f'BUS_END {t+16} 5 {a:08x} {(value if value is not None else 0x0200):04x}']
                    t+=16
        lines += [f'MEMORY {a:08x} {v:04x}' for a,v in entry['fixture']['initial_memory']]
        first=1284+8*(3+(0 if spec['handler_warm'] else 9+4*waits))
        lines += ['HOST_ACK 1220',f'IRQ_BOUNDARY count=1 previous=1230 complete=1284 first={first}',
                  'FOLLOW clock=4000 st=00000010 a0=12345678 a1=11223344 a2=00000002 a3=%08x'%status,
                  'FOLLOW_EXTRA sp=%08x'%sp,
                  'FOLLOW_ALL a4=00004000 a5=00004050 a6=00000018 a7=00000001 a8=0000001b a9=00000014 a10=00000010 a11=00002a5a a12=00000200 a13=00000018 a14=c0000100']
        return dict(start=1000,end=1008,protocol_version=5),lines

    def test_full_inventory_and_supported_settings(self):
        self.assertEqual(len(self.rows),192)
        combos={(s['sp_offset'],s['interrupt_enable'],r['stimulus']['wait_states'],s['handler_warm'])
                for r in self.rows for s,_,_ in (contract.validate(r),)}
        self.assertEqual(combos,{(sp,ie,w,warm) for sp in range(16) for ie in (False,True)
                         for w in (0,1,3) for warm in (False,True)})
        self.assertEqual(sum(len(b['cases']) for b in reference.fixture_manifest(
            nmi_nostack_io=True,stack_offsets=[0,1,15])['batches']),36)

    def test_phase_inventory_keeps_both_masks_and_all_waits(self):
        import check_results
        oracle=check_results.oracle_module()
        base=dict(fixture=next(c for c in oracle.cases() if c['name']=='nop_hit'))
        rows=cases.entries(base,oracle,phase_sweep=True)
        self.assertEqual(len(rows),48)
        self.assertEqual({(r['external_contract']['interrupt_enable'],r['stimulus']['wait_states'],
                          r['external_contract']['assert_clock']) for r in rows},
                         {(ie,w,phase) for ie in (False,True) for w in (0,1,3) for phase in range(16,24)})

    def test_contract_rejects_settings_program_or_read_changes(self):
        row=copy.deepcopy(self.rows[0])
        for change in ('setup','sp','handler','tail','event','nmim','cpu_setup_store','following_nop'):
            bad=copy.deepcopy(row)
            if change=='setup': bad['fixture']['setup_io'][0][1]^=1
            if change=='sp': bad['external_contract']['sp_offset']=True
            if change=='handler': bad['program_words'][(0x4050-0x1000)//16+4]^=1
            if change=='tail': bad['program_words'][-1]^=1
            if change=='event': bad['external_events'][0]['argument']+=1
            if change=='nmim': bad['fixture']['conditions']['nmim']=0
            if change=='cpu_setup_store': bad['program_words'][28]^=1
            if change=='following_nop': bad['program_words'][(bad['fixture']['test_pc']-0x1000)//16+1]^=1
            with self.subTest(change=change),self.assertRaises(ValueError): contract.validate(bad)

    def test_unknown_contract_and_cpu_host_poll_claim_fail_closed(self):
        row=copy.deepcopy(self.rows[0]); row['external_contract']['kind']='scalar_nmi_nostack'
        with self.assertRaises(ValueError): event_contract.expected_pause(row)
        _,observation=contract.check(self.rows[0],{'protocol_version':5},[])
        self.assertIn('CPU-visible HSTCTLH',observation['host_readback_contract'])

    def test_raw_trace_data_ack_and_unexpected_transfer_are_checked(self):
        entry=self.rows[0]; observed,lines=self.sample_trace(entry)
        self.assertEqual(contract.check(entry,observed,lines)[0],[])
        changed=[x.replace('c0000160 2a5a','c0000160 0000') for x in lines]
        self.assertTrue(any('I/O read 5 data' in e for e in contract.check(entry,observed,changed)[0]))
        accepted=next(x for x in lines if x.startswith('BUS_ACCEPT '))
        missing=[x for x in lines if x!=accepted]
        self.assertTrue(any('acceptance' in e for e in contract.check(entry,observed,missing)[0]))
        extra=lines+['BUS_BEGIN 6000 1 00002ff0 a5a5 0','BUS_END 6016 1 00002ff0 a5a5']
        self.assertTrue(any('unexpected bus activity' in e for e in contract.check(entry,observed,extra)[0]))

    def test_target_cycles_must_remain_inside_their_bus_transfer(self):
        entry=self.rows[0]; observed,lines=self.sample_trace(entry)
        shifted=[]
        for line in lines:
            if line.startswith(('TARGET_BEGIN ','TARGET_END ')):
                fields=line.split(); fields[1]=str(int(fields[1])+100000); line=' '.join(fields)
            shifted.append(line)
        errors=contract.check(entry,observed,shifted)[0]
        self.assertTrue(any('target fetch' in e and 'outside its BUS transfer' in e for e in errors),errors)

    def test_context_cannot_complete_before_the_second_vector_read(self):
        entry=self.rows[0]; observed,lines=self.sample_trace(entry)
        changed=[line.replace('complete=1284','complete=1231').replace('first=1380','first=1327')
                 for line in lines]
        errors=contract.check(entry,observed,changed)[0]
        self.assertTrue(any('context completes before second vector read completes' in e for e in errors),errors)

    def test_timing_failures_report_expected_and_observed_inclk(self):
        entry=self.rows[0]; observed,lines=self.sample_trace(entry)
        cases=(('previous=1230','previous=1226','recognition latency expected 7..17 INCLK, observed 6 INCLK'),
               ('first=1380','first=1388','first ISR MOVI duration expected 96 INCLK, observed 104 INCLK'))
        for old,new,diagnostic in cases:
            changed=[line.replace(old,new) for line in lines]
            errors=contract.check(entry,observed,changed)[0]
            self.assertTrue(any(diagnostic in error for error in errors),errors)
        for label,diagnostic in (('BUS_END','external fetch 0 BUS duration expected 16 INCLK, observed 24 INCLK'),
                                 ('BUS_END','I/O read 0 duration expected 16 INCLK, observed 24 INCLK')):
            changed=list(lines)
            bus_rows=[i for i,line in enumerate(changed) if line.startswith(label+' ')]
            selected=bus_rows[0] if 'external fetch' in diagnostic else next(
                i for i in bus_rows if changed[i].split()[3]=='c00000b0')
            fields=changed[selected].split();fields[1]=str(int(fields[1])+8);changed[selected]=' '.join(fields)
            errors=contract.check(entry,observed,changed)[0]
            self.assertTrue(any(diagnostic in error for error in errors),errors)


if __name__=='__main__': unittest.main()
