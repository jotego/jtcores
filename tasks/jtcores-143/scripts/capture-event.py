#!/usr/bin/env python3
"""Capture a preconditioned YM event with one serialized PicoROM USB client."""
import argparse
import contextlib
import fcntl
import hashlib
import json
from pathlib import Path
import re
import shlex
import struct
import subprocess
import time
import monitor
from pico_link import Pico

ROOT = Path(__file__).resolve().parents[1]
SSH_CONFIG = Path.home()/'jtcores/tasks/SiliconRE-5/scripts/ssh-config'
CAPTURE = '/home/root/jtcores143/c96-capture'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('init', type=Path)
    parser.add_argument('event', type=Path)
    parser.add_argument('prefix', type=Path, help='fresh artifact filename prefix')
    parser.add_argument('--capture-id', type=int, required=True)
    parser.add_argument('--stride', type=int, default=1, help='retain every Nth native stereo frame (v104 only)')
    parser.add_argument('--words', type=int, default=32768, help='even captured word count, 4096..32768')
    parser.add_argument('--settle', type=float, default=.05, help='conditioning pause after INIT, seconds')
    parser.add_argument('--ssh-config', type=Path, default=SSH_CONFIG)
    args = parser.parse_args()
    if not 0 <= args.capture_id <= 0xffffff or not 0 <= args.settle <= 10:
        parser.error('invalid capture ID or settling interval')
    if not 1 <= args.stride <= 1024 or not 4096 <= args.words <= 32768 or args.words%2:
        parser.error('invalid stereo stride or word count')
    args.prefix = args.prefix.resolve()
    args.prefix.parent.mkdir(parents=True, exist_ok=True)
    capture_event(args)

def capture_event(args):
    prefix = args.prefix
    def artifact(suffix): return prefix.with_name(prefix.name+suffix)
    # Preflight all output names before any hardware action.
    suffixes = ['.json','.init.bin','.event.bin','.init.log','.event.log','.transfer.log','.cap','-0-0.csv','-0-1.csv']
    assert not any(artifact(s).exists() for s in suffixes), 'Output prefix already exists'
    init, event = args.init.read_bytes(), args.event.read_bytes()
    assert all(0 < len(data) <= 8192 and data[-1] == 0 for data in [init,event])
    for suffix,data in [('.init.bin',init),('.event.bin',event)]:
        with artifact(suffix).open('xb') as f: f.write(data)
    report = {'state':'started','capture_id':args.capture_id,'settle_seconds':args.settle,
              'capture_script_sha256':digest(Path(__file__).read_bytes()),
              'init_sha256':digest(init),'event_sha256':digest(event),
              'nominal_master_clock_hz':3580000,'nominal_sample_rate_hz':55937.5/args.stride,
              'stereo_stride':args.stride,'requested_words':args.words,
              'timing_limit':'ARM and USB timestamps are host bounds, not chip-clock event timestamps'}
    def save():
        temporary=artifact('.json.tmp')
        temporary.write_text(json.dumps(report,indent=2)+'\n')
        temporary.replace(artifact('.json'))
    save()
    remote = '/tmp/jt143-event-'+str(args.capture_id)+'-'+digest(str(prefix).encode())[:12]+'.cap'
    armed = False
    try:
        with (ROOT/'artifacts/monitor.lock').open('w') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
            pico = Pico(monitor.NAME)
            try:
                assert pico.get('build_config') == 'P28_27C512_70ns'
                assert pico.get('diag_version') == 'jtkcpu-1.6'
                state = monitor.load_state()
                assert state['booted'] and not state['pending'] and not state.get('reply_partial')
                events = pico.events(monitor.BASE)
                assert not events['dropped_bytes'] and not events['capture_stopped']
                assert events['count']+6 < 4096, 'Rearm a verified idle session before marker exhaustion'
                report.update(monitor_state_before=state,events_before=events)
                report['probe'] = ssh(args,CAPTURE+' probe')
                protocol = int(re.search(r'protocol=(0x[0-9a-f]+) capacity=32768',report['probe'])[1],16)
                assert protocol in (0x960103,0x960104), 'Expected qualified Yamaha recorder'
                assert protocol == 0x960104 or args.stride == 1, 'Old recorder does not implement stride'
                report['chameleon_boot_id'] = ssh(args,'cat /proc/sys/kernel/random/boot_id').strip()
                report['hps_tool_sha256'] = ssh(args,'sha256sum '+CAPTURE).split()[0]
                report['configuration'] = ssh(args,CAPTURE+' configure 3 15 0')
                submit(pico,artifact('.init.bin'),artifact('.init.log'))
                report['init_reply_host_monotonic'] = time.monotonic()
                time.sleep(args.settle)
                report['settle_wait_seconds_lower_bound'] = time.monotonic()-report['init_reply_host_monotonic']
                assert report['settle_wait_seconds_lower_bound'] >= args.settle
                report['arm_host_start'] = time.monotonic()
                arm = ssh(args,f'{CAPTURE} arm 1 {args.words} {args.stride} {args.capture_id} && {CAPTURE} status')
                armed = True
                report['arm_host_end'] = time.monotonic()
                assert f'id={args.capture_id}' in arm and 'status=0x1 ' in arm, arm
                report['event_host_start'] = time.monotonic()
                submit(pico,artifact('.event.bin'),artifact('.event.log'))
                report['event_host_end'] = time.monotonic()
                duration = args.words/2*args.stride/55937.5
                deadline = report['arm_host_end']+duration*1.01+2
                while True:
                    status = ssh(args,CAPTURE+' status')
                    assert f'id={args.capture_id}' in status, 'Capture ownership changed'
                    if 'status=0x1 ' not in status: break
                    assert time.monotonic() < deadline, 'Capture did not finish in its duration bound'
                    time.sleep(max(.05,min(.5,duration/100)))
                armed = False
                transfer = ssh(args,CAPTURE+' export '+shlex.quote(remote)+' && sha256sum '+shlex.quote(remote))
                artifact('.transfer.log').write_text(arm+status+transfer)
                subprocess.run(['scp','-O','-F',str(args.ssh_config),'chameleon96-usb:'+remote,str(artifact('.cap'))],check=True)
                data = artifact('.cap').read_bytes()
                checksum = digest(data)
                assert re.search(r'^'+checksum+r'\s+'+re.escape(remote)+r'$',transfer,re.M), 'Transfer hash mismatch'
                header = struct.unpack_from('<18I',data,8)
                magic = b'C96CAP04' if protocol == 0x960104 else b'C96CAP03'
                assert data[:8] == magic and header[7] == args.capture_id and header[3] == args.words and header[5] == args.stride
                analysis = json.loads(subprocess.check_output(['go','run',str(ROOT/'host/analyze.go'),'-csv',str(prefix),str(artifact('.cap'))],text=True))
                report.update(state='complete',capture_sha256=checksum,capture_header=list(header),analysis=analysis,
                              monitor_state_after=monitor.load_state(),events_after=pico.events(monitor.BASE))
                assert not report['events_after']['dropped_bytes']
                save()
                print(json.dumps({'prefix':str(prefix),'state':report['state'],'sha256':checksum}))
            finally: pico.close()
    except BaseException as error:
        report.update(state='failed',error=str(error))
        save()
        if armed:
            try:
                status = ssh(args,CAPTURE+' status')
                if f'id={args.capture_id}' in status: report['failure_stop'] = ssh(args,CAPTURE+' stop')
            finally: save()
        raise

def digest(data): return hashlib.sha256(data).hexdigest()

def ssh(args,command):
    return subprocess.check_output(['ssh','-F',str(args.ssh_config),'chameleon96-usb',command],text=True,timeout=10)

def submit(pico,program,log):
    with log.open('x') as f,contextlib.redirect_stdout(f):
        monitor.run(pico,None,program)
        monitor.poll(pico,5,True)

if __name__ == '__main__': main()
