#!/usr/bin/env python3
"""Idle-safe literal history chunks; expanded timing, never continuous MAME replay."""
from pathlib import Path
import argparse,contextlib,csv,fcntl,hashlib,importlib.util,json,sys,time
TASK_ROOT=Path(__file__).resolve().parents[1]
MAX_WRITES=2000000
def require(value,message):
    if not value:raise ValueError(message)
def digest(data):return hashlib.sha256(data).hexdigest()
def file_hash(path):return digest(Path(path).read_bytes())
def read_json(path):return json.loads(Path(path).read_text())
def save(path,value):
    temporary=path.with_name(path.name+'.tmp')
    temporary.write_text(json.dumps(value,indent=2,allow_nan=False)+'\n');temporary.replace(path)
def isolated_root(path):
    root=Path(path).resolve()
    require(root==TASK_ROOT or TASK_ROOT in root.parents,'state root must be inside new jt51-13 task')
    return root
def decode(data):
    require(0<len(data)<=8192,'program must contain 1..8192 bytes');position=0;writes=[];delays=[]
    while position<len(data):
        op=data[position];position+=1
        if op==0:
            require(position==len(data),'trailing bytes after END');return writes,delays
        if op in(1,2):
            require(position+2<=len(data),'truncated operand');a,b=data[position:position+2];position+=2
            if op==1:writes.append([a,b])
            else:delays.append(a+256*b)
        else:require(op==3,'unknown monitor opcode')
    raise ValueError('missing END')
def load_history(path):
    path=Path(path).resolve();entries=[];total=0
    with path.open(newline='')as stream:
        reader=csv.reader(stream,delimiter='\t');require(next(reader,None)==['program','gap_before_master_clocks'],'history TSV header')
        for row in reader:
            require(len(row)==2 and row[1].isascii()and row[1].isdigit(),'history TSV row/gap')
            program=Path(row[0]);require(program.is_absolute(),'history program paths must be absolute');gap=int(row[1]);require(gap<=0xffffffffffffffff,'gap overflow');data=program.read_bytes();writes,delays=decode(data);total+=len(writes);require(total<=MAX_WRITES,'history exceeds 2000000 writes')
            entries.append({'index':len(entries),'program':str(program),'sha256':digest(data),'bytes':len(data),'write_count':len(writes),'delay_counts':delays,'gap_before_master_clocks':gap})
    return {'path':str(path),'sha256':file_hash(path),'chunks':entries,'write_count':total}
def adopt(snapshot,state_root):
    root=isolated_root(state_root);state=read_json(snapshot);require(state.get('booted')is True and state.get('pending')is False and not state.get('reply_partial'),'snapshot is not host-verified idle');require(type(state.get('generation'))is int and 0<=state['generation']<=255,'snapshot generation');folder=root/'artifacts';folder.mkdir(parents=True,exist_ok=True)
    with(folder/'monitor-state.json').open('x')as stream:json.dump(state,stream,indent=2);stream.write('\n')
    with(folder/'monitor-state-adoption.json').open('x')as stream:json.dump({'source':str(Path(snapshot).resolve()),'source_sha256':file_hash(snapshot),'state_sha256':file_hash(folder/'monitor-state.json'),'live_board_not_yet_verified':True},stream,indent=2);stream.write('\n')
def load_monitor():
    sys.path.insert(0,str(Path(__file__).resolve().parent))
    spec=importlib.util.spec_from_file_location('jt51_13_monitor',Path(__file__).with_name('monitor.py'));module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
class TimedPico:
    def __init__(self,pico,clock):self.pico=pico;self.clock=clock;self.calls=[]
    def __getattr__(self,name):return getattr(self.pico,name)
    def write(self,offset,data):
        entry={'kind':'ROM_API_write','offset':offset,'length':len(data),'data_sha256':digest(data),'host_start':self.clock.monotonic()};self.calls.append(entry)
        try:return self.pico.write(offset,data)
        finally:entry['host_end']=self.clock.monotonic()
    def read(self,offset,length):
        entry={'kind':'ROM_API_read','offset':offset,'length':length,'host_start':self.clock.monotonic()};self.calls.append(entry)
        try:return self.pico.read(offset,length)
        finally:entry['host_end']=self.clock.monotonic()
def execute(history,state_root,output,binding,monitor,pico,clock=time):
    root=isolated_root(state_root);output=Path(output).resolve();require(TASK_ROOT in output.parents,'output must be inside new task');chunks_dir=output.with_name(output.name+'.chunks');require(not output.exists()and not chunks_dir.exists(),'fresh report/chunk paths required');require(binding.get('authorized_by')=='/root'and binding.get('authorize_history_once')is True,'actual ROOT execution binding');require(binding.get('history_sha256')==history['sha256']and binding.get('frontend_sha256')==file_hash(__file__),'history/frontend execution binding')
    monitor.ROOT=root;state=monitor.load_state();require(state.get('booted')is True and state.get('pending')is False and not state.get('reply_partial'),'monitor state not idle');require(file_hash(root/'artifacts/monitor-state.json')==binding['initial_state_sha256'],'initial state identity');require(state['generation']==binding['initial_generation'],'initial generation');require(type(binding['reserve_markers'])is int and binding['reserve_markers']>=0,'marker reserve');require(file_hash(history['path'])==history['sha256'],'history changed before execution')
    output.parent.mkdir(parents=True,exist_ok=True);chunks_dir.mkdir();report={'state':'started','history':history,'clock_hz':3580000,'binding':binding,'state_before':state,'chunks':[],'timing_scope':'Expanded timing: host upload/generation/reply bounds and Pico completion markers; not accepted YM write timestamps or continuous MAME timing'}
    with output.open('x')as stream:json.dump(report,stream,indent=2);stream.write('\n')
    measured=TimedPico(pico,clock)
    try:
        require(pico.get('build_config')=='P28_27C512_70ns'and pico.get('diag_version')=='jtkcpu-1.6','P28/protocol identity');require(pico.get('rom_enable')=='1'and int(pico.get('addr_mask'),0)==0xffff,'ROM service geometry');require(pico.read(monitor.BASE,4)==b'PICO','Pico session missing');require(pico.read(0x2000,2)==bytes([state['generation'],state['generation']^255]),'live generation pair');boot=digest(pico.read(0,8192));require(boot==binding['expected_boot_bank_sha256'],'boot bank identity');require(not pico.poll(),'unexpected pending reply');before=pico.events(monitor.BASE);require(before['active']and not before['dropped_bytes']and not before['capture_stopped'],'reply recorder identity');require(before['count']==binding['initial_markers'],'initial marker identity');require(before['count']+3*len(history['chunks'])+binding['reserve_markers']<4096,'reply recorder capacity');clock.sleep(.02);require(not pico.poll()and pico.events(monitor.BASE)==before,'reply producer not idle');report['events_before']=before;save(output,report)
        for item in history['chunks']:
            require(file_hash(item['program'])==item['sha256'],'chunk changed before upload');data=Path(item['program']).read_bytes();program=chunks_dir/(f"{item['index']:04d}.bin")
            with program.open('xb')as stream:stream.write(data)
            row={'index':item['index'],'program':str(program),'sha256':item['sha256'],'declared_gap_before_master_clocks':item['gap_before_master_clocks'],'events_before':pico.events(monitor.BASE),'api_calls':[]};report['chunks'].append(row);gap_start=clock.monotonic();clock.sleep(item['gap_before_master_clocks']/3580000);row.update(gap_host_start=gap_start,gap_host_end=clock.monotonic(),submit_host_start=clock.monotonic());start_calls=len(measured.calls);save(output,report)
            log=chunks_dir/(f"{item['index']:04d}.log")
            try:
                with log.open('x')as stream,contextlib.redirect_stdout(stream):
                    monitor.run(measured,None,program);row['submit_host_end']=clock.monotonic();row['reply_host_start']=clock.monotonic();monitor.poll(measured,5,True);row['reply_host_end']=clock.monotonic()
            finally:row['api_calls']=measured.calls[start_calls:];row['monitor_state_after']=monitor.load_state();row['events_after']=pico.events(monitor.BASE);save(output,report)
            require(not row['monitor_state_after']['pending']and not row['monitor_state_after'].get('reply_partial'),'chunk reply incomplete');require(row['events_after']['count']==row['events_before']['count']+3 and not row['events_after']['dropped_bytes']and not row['events_after']['capture_stopped'],'chunk marker chain');row['reply_log_sha256']=file_hash(log);save(output,report)
        require(digest(pico.read(0,8192))==boot,'boot bank changed');require(file_hash(history['path'])==history['sha256'],'history changed after execution');report.update(state='complete',state_after=monitor.load_state(),events_after=pico.events(monitor.BASE),boot_bank_sha256=boot);save(output,report);return report
    except BaseException as error:
        report.update(state='failed',error=repr(error),state_after=monitor.load_state(),api_calls=measured.calls);save(output,report);raise
def main():
    parser=argparse.ArgumentParser(description=__doc__);mode=parser.add_mutually_exclusive_group(required=True);mode.add_argument('--validate',action='store_true');mode.add_argument('--adopt-state',type=Path);mode.add_argument('--execute',action='store_true');parser.add_argument('--history',type=Path);parser.add_argument('--state-root',type=Path,default=TASK_ROOT);parser.add_argument('--output',type=Path);parser.add_argument('--ROOT-binding',type=Path);args=parser.parse_args();root=isolated_root(args.state_root)
    if args.adopt_state:adopt(args.adopt_state,root);return
    require(args.history is not None,'--history required');history=load_history(args.history)
    if args.validate:print(json.dumps(history,indent=2));return
    require(args.output is not None and args.ROOT_binding is not None,'execution needs fresh output and ROOT binding');binding=read_json(args.ROOT_binding);require(binding.get('authorized_by')=='/root'and binding.get('authorize_history_once')is True and binding.get('frontend_sha256')==file_hash(__file__)and binding.get('history_sha256')==history['sha256'],'ROOT binding before USB');output=args.output.resolve();require(TASK_ROOT in output.parents and not output.exists()and not output.with_name(output.name+'.chunks').exists(),'fresh new-task output required before USB');state_path=root/'artifacts/monitor-state.json';state=read_json(state_path);require(state.get('booted')is True and state.get('pending')is False and not state.get('reply_partial'),'idle host state required before USB');require(file_hash(state_path)==binding['initial_state_sha256']and state['generation']==binding['initial_generation'],'state binding before USB');monitor=load_monitor();root.joinpath('artifacts').mkdir(parents=True,exist_ok=True)
    with(root/'artifacts/monitor.lock').open('w')as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB);pico=monitor.Pico(monitor.NAME)
        try:execute(history,root,args.output,binding,monitor,pico)
        finally:pico.close()
if __name__=='__main__':main()
