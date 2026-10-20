#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Exercise Python and native C payload preflight without MMIO or SSH."""
import copy
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest

import check_results as checker
import run_batch


class NativeSchema(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='jttms10-transport-schema-')
        cls.addClassCleanup(cls.temp.cleanup)
        cls.work = Path(cls.temp.name)
        source = Path(__file__).with_name('transport.c').resolve()
        wrapper = cls.work/'check.c'
        wrapper.write_text('''#define main transport_main
#include '''+json.dumps(str(source))+'''
#undef main
int main(int argc, char **argv) {
    if(argc!=2) return 90;
    FILE *in=fopen(argv[1], "rb");
    if(!in || fseek(in,8,SEEK_SET)) return 91;
    uint32_t fake[16]={0}, previous=1;
    fake[1]=1; regs=fake; /* busy sentinel: valid preflight stops before staging */
    int result=run_batch(in,0,&previous);
    fclose(in);
    for(unsigned i=0;i<16;i++) if(fake[i]!=(i==1 ? 1u : 0u)) return 92;
    return result;
}
''')
        cls.executable = cls.work/'check'
        subprocess.run(['cc','-std=c11','-Wall','-Wextra','-Werror','-O2',str(wrapper),
                        '-o',str(cls.executable)],check=True,capture_output=True)
        entry = checker.prepare_cases(['nop_hit'], limit=1, protocol_version=4)[0]
        entry['external_events'] = [dict(trigger=0, argument=0, control=16),
                                    dict(trigger=5, argument=1, control=0)]
        cls.good = checker.make_batches([entry], protocol_version=4)[0]

    def native(self, batch):
        words, rows = batch['program_words'], batch['descriptors']
        data = bytearray(struct.pack('<4s5I',b'JTR5',1,len(rows),len(words),4000000,0))
        for row in rows:
            data += struct.pack('<16I',*row)
        data += struct.pack(f'<{len(words)}H',*words)
        path = self.work/'payload.bin'
        path.write_bytes(data)
        return subprocess.run([str(self.executable),str(path)],capture_output=True,text=True)

    def reject(self, batch):
        with self.assertRaises(ValueError):
            run_batch.input_payload([batch],4000000)
        result = self.native(batch)
        self.assertEqual(result.returncode,2,result.stdout+result.stderr)

    def test_valid_event_payload_reaches_busy_guard_without_writes(self):
        payload = run_batch.input_payload([self.good],4000000)
        self.assertEqual(payload[:4],b'JTR5')
        result = self.native(self.good)
        self.assertEqual(result.returncode,4,result.stdout+result.stderr)
        self.assertIn('still busy',result.stderr)

    def test_event_descriptor_ranges_and_count(self):
        for index,value in ((14,17),(15,0xffffffff),(15,len(self.good['program_words'])),
                            (15,0),(14,0)):
            with self.subTest(index=index,value=value):
                batch=copy.deepcopy(self.good)
                batch['descriptors'][0][index]=value
                self.reject(batch)

    def test_event_encodings(self):
        for trigger,argument,control in ((6,0,0),(8,0,0),(0,0,64),(0,0,0x100),
                                          (2,0x1601,0),(1,0,0),(3,0,0),(4,0,0),(5,0,0)):
            with self.subTest(trigger=trigger,argument=argument,control=control):
                batch=copy.deepcopy(self.good)
                base=batch['descriptors'][0][15]
                batch['program_words'][base:base+4]=[argument&65535,argument>>16,control,trigger]
                self.reject(batch)

    def test_event_pool_cannot_alias_another_case(self):
        first=copy.deepcopy(self.good['cases'][0]);second=copy.deepcopy(first);second['id']=1
        batch=checker.make_batches([first,second],protocol_version=4)[0]
        batch['descriptors'][1][15]=batch['descriptors'][0][15]
        self.reject(batch)


if __name__ == '__main__':
    unittest.main()
