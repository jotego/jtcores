"""Offline lifecycle tests use the copied monitor body and no USB endpoint."""
from pathlib import Path
import copy,hashlib,importlib.util,json,sys,tempfile,types,unittest
import history_frontend as h
class Clock:
    def __init__(self):self.now=10.0
    def monotonic(self):self.now+=.001;return self.now
    def sleep(self,duration):self.now+=duration
class Pico:
    def __init__(self,generation=254,markers=10):
        self.mem=bytearray(65536);self.mem[:8192]=bytes([93])*8192;self.mem[0x3c00:0x3c04]=b'PICO';self.mem[0x2000:0x2002]=bytes([generation,generation^255]);self.count=markers;self.reply=b'';self.submitted=[];self.bad_reply=False;self.bad_readback=False;self.calls=[]
    def get(self,name):return {'build_config':'P28_27C512_70ns','diag_version':'jtkcpu-1.6','rom_enable':'1','addr_mask':'0xffff'}[name]
    def read(self,offset,length):
        b=bytes(self.mem[offset:offset+length]);return b'X'+b[1:]if self.bad_readback and offset==0x4000 else b
    def write(self,offset,data):
        self.calls.append((offset,len(data)));self.mem[offset:offset+len(data)]=data
        if offset==0x2000:
            gen=data[0];self.submitted.append(gen);self.count+=3;self.reply=bytes([0xd0,(gen+1)&255 if self.bad_reply else gen,0])
    def poll(self):r=self.reply;self.reply=b'';return r
    def events(self,base):return {'active':True,'count':self.count,'capture_stopped':False,'dropped_bytes':0,'events':[{'sequence':self.count-1,'time_us':self.count*10,'address':'0x3f00'}]}
def monitor(clock):
    stub=types.ModuleType('pico_link');stub.Pico=Pico;previous=sys.modules.get('pico_link');sys.modules['pico_link']=stub
    try:
        spec=importlib.util.spec_from_file_location('offline_monitor',Path(h.__file__).with_name('monitor.py'));module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    finally:
        if previous is None:sys.modules.pop('pico_link',None)
        else:sys.modules['pico_link']=previous
    module.time=clock;return module
class Lifecycle(unittest.TestCase):
    def setUp(self):
        base=h.TASK_ROOT/'artifacts/frontend-validation-v1';base.mkdir(parents=True,exist_ok=True);self.tmp=tempfile.TemporaryDirectory(dir=base);self.root=Path(self.tmp.name);(self.root/'artifacts').mkdir();self.state={'generation':254,'pending':False,'booted':True,'image_sha256':'a'*64};self.sp=self.root/'artifacts/monitor-state.json';self.sp.write_text(json.dumps(self.state));self.program=self.root/'chunk.bin';self.program.write_bytes(bytes([1,0x1b,0x40,2,7,0,3,0]));self.tsv=self.root/'history.tsv';self.tsv.write_text('program\tgap_before_master_clocks\n'+str(self.program)+'\t3580\n'+str(self.program)+'\t0\n');self.clock=Clock();self.pico=Pico();self.mon=monitor(self.clock);self.history=h.load_history(self.tsv);self.report=self.root/'result.json';self.binding={'authorized_by':'/root','authorize_history_once':True,'frontend_sha256':h.file_hash(h.__file__),'history_sha256':self.history['sha256'],'initial_state_sha256':h.file_hash(self.sp),'initial_generation':254,'initial_markers':10,'expected_boot_bank_sha256':h.digest(self.pico.read(0,8192)),'reserve_markers':6}
    def tearDown(self):self.tmp.cleanup()
    def execute(self):return h.execute(self.history,self.root,self.report,self.binding,self.mon,self.pico,self.clock)
    def test_success_keeps_state_and_wraps_generation(self):
        r=self.execute();self.assertEqual(r['state'],'complete');self.assertEqual(self.pico.submitted,[255,0]);self.assertEqual(r['state_after']['generation'],0);self.assertFalse(r['state_after']['pending']);self.assertEqual(r['events_after']['count'],16);self.assertEqual(len(r['chunks']),2);self.assertGreaterEqual(r['chunks'][0]['gap_host_end']-r['chunks'][0]['gap_host_start'],.001);self.assertEqual([v['offset']for v in r['chunks'][0]['api_calls']],[0x3c00,0x2000,0x4000,0x4000,0x2000]);self.assertEqual(self.pico.mem[:8192],bytes([93])*8192)
    def test_wrong_reply_stops_without_next_submission(self):
        self.pico.bad_reply=True
        with self.assertRaises(AssertionError):self.execute()
        self.assertEqual(self.pico.submitted,[255]);self.assertTrue(json.loads(self.sp.read_text())['pending']);self.assertEqual(json.loads(self.report.read_text())['state'],'failed')
    def test_readback_error_does_not_commit_generation(self):
        self.pico.bad_readback=True
        with self.assertRaises(AssertionError):self.execute()
        self.assertEqual(self.pico.submitted,[]);self.assertFalse(json.loads(self.sp.read_text())['pending'])
    def test_boot_identity_failure_no_table_write(self):
        self.binding['expected_boot_bank_sha256']='0'*64
        with self.assertRaises(ValueError):self.execute()
        self.assertEqual(self.pico.calls,[])
    def test_marker_budget_failure_no_table_write(self):
        self.pico.count=4090;self.binding['initial_markers']=4090
        with self.assertRaises(ValueError):self.execute()
        self.assertEqual(self.pico.calls,[])
    def test_changed_chunk_failure_no_table_write(self):
        self.program.write_bytes(b'\0')
        with self.assertRaises(ValueError):self.execute()
        self.assertEqual(self.pico.calls,[])
    def test_old_state_root_rejected(self):
        with self.assertRaises(ValueError):h.isolated_root(h.TASK_ROOT.parent/'jtcores-143')
    def test_truncated_unknown_and_trailing_rejected(self):
        for b in(b'',b'\1',b'\1\10',b'\2\1',b'\4\0',b'\0\0',b'\3'):
            with self.subTest(b=b),self.assertRaises(ValueError):h.decode(b)
    def test_header_only_fresh_control(self):
        self.tsv.write_text('program\tgap_before_master_clocks\n');p=h.load_history(self.tsv);self.assertEqual(p['write_count'],0);self.assertEqual(p['chunks'],[])
    def test_whole_input_write_bound(self):
        self.program.write_bytes(bytes([1,27,64])*2730+b'\0');self.tsv.write_text('program\tgap_before_master_clocks\n'+(str(self.program)+'\t0\n')*733)
        with self.assertRaises(ValueError):h.load_history(self.tsv)
    def test_adoption_is_exclusive_and_offline(self):
        target=self.root/'adopt';h.adopt(self.sp,target);self.assertEqual(json.loads((target/'artifacts/monitor-state.json').read_text()),self.state)
        with self.assertRaises(FileExistsError):h.adopt(self.sp,target)
if __name__=='__main__':unittest.main()
