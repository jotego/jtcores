#!/usr/bin/env python3
"""Task-local P28 loader and live test-table uploader; requires pyusb."""
import argparse
import fcntl
import hashlib
import json
from pathlib import Path
import time
from pico_link import Pico

ROOT = Path(__file__).resolve().parents[1]
BASE = 0x3c00
NAME = 'E66550A14758A021'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['install', 'poll', 'run', 'emit', 'rearm'])
    parser.add_argument('test', nargs='?', choices=['timer-a', 'timer-b', 'clear', 'tone', 'tone-left', 'tone-right', 'silence'])
    parser.add_argument('--seconds', type=float, default=5)
    parser.add_argument('--program', type=Path, help='raw monitor bytecode instead of a built-in test')
    parser.add_argument('--until-reply', action='store_true', help='return after one complete CPU reply')
    parser.add_argument('--output', type=Path, help='fresh destination for emit or rearm report')
    args = parser.parse_args()
    if args.action == 'run' and not (args.test or args.program):
        parser.error('run requires a test')
    if args.action == 'emit':
        if not (args.test and args.output):
            parser.error('emit requires a test and --output')
        with args.output.open('xb') as output:
            output.write(make_table(args.test))
        return
    if args.action == 'rearm' and not args.output:
        parser.error('rearm requires --output REPORT.json')
    with (ROOT/'artifacts/monitor.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        pico = Pico(NAME)
        try:
            assert pico.get('build_config') == 'P28_27C512_70ns'
            assert pico.get('diag_version') == 'jtkcpu-1.6'
            if args.action == 'install':
                install(pico)
            elif args.action == 'run':
                run(pico, args.test, args.program)
            elif args.action == 'rearm':
                rearm(pico,args.output)
                return
            poll(pico, args.seconds, args.until_reply)
        finally:
            pico.close()

def install(pico):
    data = (ROOT/'artifacts/monitor.bin').read_bytes()
    assert len(data) == 65536
    pico.set('rom_enable','0')
    pico.end()
    pico.set('addr_mask','0xffff')
    pico.write(0,data)
    assert pico.read(0,len(data)) == data, 'Readback failed; ROM remains disabled'
    pico.start(BASE)
    assert pico.read(BASE,4) == b'PICO'
    save_state({'generation':0, 'pending':False, 'booted':False,
                'image_sha256':hashlib.sha256(data).hexdigest()})
    pico.set('rom_enable','1')
    print('Installed and readback-verified 65536 bytes; waiting for CPU boot.', flush=True)

def run(pico, test, program=None):
    state = load_state()
    assert state['booted'], 'No verified boot reply yet; poll after PCB power cycle'
    assert not state['pending'], 'Previous command is pending; poll before submitting'
    assert pico.read(BASE,4) == b'PICO', 'PicoROM session was lost; do not live-reload'
    assert pico.read(0x2000,2) == bytes([state['generation'],state['generation']^255])
    table = program.read_bytes() if program else make_table(test)
    if program: test = program.stem
    assert len(table) <= 8192 and table[-1] == 0
    pico.write(0x4000,table)
    assert pico.read(0x4000,len(table)) == table
    gen = (state['generation'] + 1) & 255
    state.update(generation=gen,pending=True,test=test)
    save_state(state)
    pico.write(0x2000,bytes([gen,gen^255]))
    print(f'Submitted {test}, generation {gen}, {len(table)} bytes.', flush=True)

def rearm(pico, output):
    """Renew only a verified idle reply session; never reload ROM or reset CPU."""
    state = load_state()
    assert state['booted'] and not state['pending'] and not state.get('reply_partial'), 'Monitor is not verified idle'
    window = output.with_suffix('.window.bin')
    assert not output.exists() and not window.exists(), 'Rearm outputs must be fresh'
    output.parent.mkdir(parents=True,exist_ok=True)
    report = {'state':'started','monitor_before':state}
    def save():
        temporary=output.with_suffix('.new')
        temporary.write_text(json.dumps(report,indent=2)+'\n')
        temporary.replace(output)
    with output.open('x') as f: json.dump(report,f)
    try:
        control = bytes([state['generation'],state['generation']^255])
        assert pico.read(0x2000,2) == control, 'Generation control differs'
        report['parameters_before'] = {key:pico.get(key) for key in ['rom_enable','addr_mask']}
        assert report['parameters_before']['rom_enable'] == '1', 'ROM service is not enabled'
        assert int(report['parameters_before']['addr_mask'],0) == 0xffff, 'ROM address mask differs from the qualified 64 KiB mapping'
        boot_hash = hashlib.sha256(pico.read(0,8192)).hexdigest()
        report['boot_bank_sha256'] = boot_hash
        report['unexpected_reply_before'] = pico.poll().hex()
        assert not report['unexpected_reply_before'], 'Unexpected unconsumed CPU reply'
        before = pico.events(BASE)
        report['events_before'] = before
        assert before['active'] and not before['capture_stopped'] and not before['dropped_bytes']
        time.sleep(.02)
        report['unexpected_reply_idle'] = pico.poll().hex()
        assert not report['unexpected_reply_idle'], 'CPU reply during idle qualification'
        assert pico.events(BASE) == before, 'Reply producer is not idle'
        snapshot = pico.read(BASE,1024)
        assert pico.events(BASE) == before, 'Reply producer advanced during archive'
        with window.open('xb') as f: f.write(snapshot)
        report['window_sha256'] = hashlib.sha256(snapshot).hexdigest()
        save()
        pico.end()
        pico.start(BASE)
        after = pico.events(BASE)
        report['events_after'] = after
        assert after['active'] and after['count']==0 and not after['capture_stopped'] and not after['dropped_bytes']
        assert pico.read(0x2000,2) == control, 'Generation changed during rearm'
        assert hashlib.sha256(pico.read(0,8192)).hexdigest() == boot_hash, 'Boot ROM bank changed'
        assert {key:pico.get(key) for key in report['parameters_before']} == report['parameters_before']
        report['unexpected_reply_after'] = pico.poll().hex()
        assert not report['unexpected_reply_after'], 'CPU produced an unexpected reply after rearm'
        assert load_state() == state, 'Monitor host state changed during rearm'
        report['state'] = 'complete'
        save()
        print(json.dumps({'state':'complete','archived_markers':before['count'],'generation':state['generation']}),flush=True)
    except BaseException as error:
        report.update(state='failed',error=str(error))
        save()
        raise

def make_table(test):
    def wr(reg, val): return [1,reg,val]
    if test == 'timer-a':
        return bytes(wr(0x14,0x30)+wr(0x10,255)+wr(0x11,3)+wr(0x14,5)+[2,255,255,3,0])
    if test == 'timer-b':
        return bytes(wr(0x14,0x30)+wr(0x12,255)+wr(0x14,10)+[2,255,255,3,0])
    if test == 'clear':
        return bytes(wr(0x14,0x30)+[2,255,0,3,0])
    table = []
    # Key off all channels and establish every writable operator/channel register.
    for ch in range(8): table += wr(8,ch)
    for reg in range(0x20,0x100): table += wr(reg,0)
    for reg in range(0x60,0x80): table += wr(reg,127)
    table += wr(1,0)+wr(0x14,0x30)+wr(0x0f,0)+wr(0x18,0)+wr(0x19,0)+wr(0x19,0x80)+wr(0x1b,0)
    if test.startswith('tone'):
        # Algorithm 7, both channels, only C2 audible, A4, no modulation.
        # Yamaha ACC: register20 bit6=LEFT, bit7=RIGHT.
        pan = {'tone':0xc0,'tone-left':0x40,'tone-right':0x80}[test]
        table += wr(0x20,pan|7)+wr(0x28,0x4a)+wr(0x30,0)
        table += wr(0x58,1)+wr(0x78,0)+wr(0x98,31)+wr(0xb8,0)+wr(0xd8,0)+wr(0xf8,15)
        table += wr(8,0x40)
    return bytes(table+[0])

def poll(pico, seconds, until_reply=False):
    state = load_state()
    pending = bytearray.fromhex(state.get('reply_partial',''))
    deadline = time.monotonic()+seconds
    completed = False
    while time.monotonic()<deadline:
        received = pico.poll()
        pending.extend(received)
        if received:
            state['reply_partial'] = pending.hex()
            save_state(state)
        while len(pending)>=3:
            frame = bytes(pending[:3]); del pending[:3]
            kind,gen,status = frame
            print('CPU reply:',frame.hex(),flush=True)
            assert gen == state['generation'], f'Unexpected generation: {gen}'
            if kind == 0xb0:
                assert not state['pending'], 'CPU reset during a test'
                state['booted'] = True
            else:
                assert kind == 0xd0 and state['pending'], 'Unexpected CPU reply'
                expected = {'timer-a':1,'timer-b':2,'clear':0}.get(state['test'])
                assert status != 255, 'Invalid monitor opcode'
                if expected is not None:
                    assert status & 3 == expected, f'Unexpected timer status {status:02x}'
                state.update(pending=False,last_status=status)
            state['reply_partial'] = pending.hex()
            save_state(state)
            completed = True
        if completed and until_reply:
            break
        time.sleep(.02)
    assert not pending, f'Partial CPU reply: {pending.hex()}'
    print(json.dumps({'state':state,'events':pico.events(BASE)},indent=2))
    if state['pending']:
        raise TimeoutError('Command remains pending; use poll to recover')

def load_state():
    return json.loads((ROOT/'artifacts/monitor-state.json').read_text())

def save_state(state):
    path = ROOT/'artifacts/monitor-state.json'
    temporary = path.with_suffix('.new')
    temporary.write_text(json.dumps(state,indent=2)+'\n')
    temporary.replace(path)

if __name__ == '__main__':
    main()
