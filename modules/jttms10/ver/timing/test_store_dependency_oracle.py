#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Instruction-word dependencies retain physical timing and ordering checks."""
import importlib.util
from pathlib import Path
import unittest

import store_dependency_oracle as oracle
from run import check_store_bus


class StoreDependencyOracleTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path=Path(__file__).resolve().parent.parent/'store_dependency/cases.py'
        spec=importlib.util.spec_from_file_location('dependency_fixture_contract_test',path)
        module=importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        cls.cases=[case for case,words in module.cases()]

    def trace(self,case,wait=0):
        leading,stores,opcode=oracle.transfers(case)
        lines=[]
        for q,(kind,address,value,iaq) in enumerate(leading+stores+[opcode]):
            start=1000+q*(16+8*wait)
            for prefix,delay,length in [('BUS',0,16+8*wait),('TARGET',2,4+8*wait)]:
                lines.extend([f'{prefix}_BEGIN {start+delay} {kind} {address:08x} {value:04x} {iaq}',
                              f'{prefix}_END {start+delay+length} {kind} {address:08x} {value:04x} {iaq}'])
        return lines

    def test_both_backends_check_every_declared_transfer(self):
        for case in self.cases:
            for wait in (0,1,3):
                lines=self.trace(case,wait)
                for raw in (False,True):
                    self.assertEqual(check_store_bus(case,dict(start=1000),lines,wait,raw=raw),[])
                    self.assertTrue(check_store_bus(case,dict(start=1000),lines[:-4],wait,raw=raw))

    def test_duration_and_dispatch_are_not_disabled_with_total_duration(self):
        case=self.cases[0];lines=self.trace(case)
        changed=list(lines);changed[1]=changed[1].replace('1016','1017')
        self.assertTrue(any('cycle duration' in e for e in check_store_bus(case,dict(start=1000),changed,0)))
        changed=list(lines)
        for q in (2,3):
            fields=changed[q].split();fields[1]=str(int(fields[1])+8);changed[q]=' '.join(fields)
        self.assertTrue(any('dispatch' in e for e in check_store_bus(case,dict(start=1000),changed,0,raw=True)))
        self.assertTrue(check_store_bus(case,dict(start=1000),[s for s in lines if s.startswith('TARGET')],0,raw=True))

    def test_relative_state_grid_is_still_required(self):
        case=self.cases[0];lines=self.trace(case)
        changed=[]
        for line in lines:
            fields=line.split();fields[1]=str(int(fields[1])+1);changed.append(' '.join(fields))
        self.assertTrue(any('machine-state grid' in e for e in check_store_bus(case,dict(start=1000),changed,0)))

    def test_dependent_opcode_cannot_precede_its_modifying_write(self):
        for case in self.cases:
            if not case['dependency_conditions']['next_opcode_modified']:continue
            leading,stores,opcode=oracle.transfers(case)
            # Keep exact transactions and physical lengths, but place the
            # opcode before the store. A memory-only checker would miss it.
            plan=leading+[opcode]+stores
            lines=[]
            for q,(kind,address,value,iaq) in enumerate(plan):
                clock=1000+16*q
                lines.extend([f'BUS_BEGIN {clock} {kind} {address:08x} {value:04x} {iaq}',
                              f'BUS_END {clock+16} {kind} {address:08x} {value:04x} {iaq}'])
            self.assertTrue(any('preceded its modifying write' in e for e in
                                check_store_bus(case,dict(start=1000),lines,0)))


if __name__=='__main__':
    unittest.main()
