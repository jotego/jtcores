"""Small task-local USB client for PicoROM's existing packet protocol."""
import struct
import time
import usb.core
import usb.util

class Pico:
    def __init__(self, name='VENDETTA'):
        devices = usb.core.find(find_all=True, idVendor=0x2e8a, idProduct=0x000a)
        self.dev = next((d for d in devices if d.serial_number.endswith(':'+name)), None)
        if self.dev is None:
            raise RuntimeError(f'PicoROM {name} not found')
        usb.util.claim_interface(self.dev, 0)
        self.received = bytearray()
        self.drain()

    def close(self):
        usb.util.release_interface(self.dev, 0)
        usb.util.dispose_resources(self.dev)

    def send(self, kind, payload=b''):
        assert len(payload) <= 36
        self.dev.write(0x01, bytes([kind,len(payload)])+payload, timeout=1000)

    def receive(self, timeout=1000):
        b=bytes(self.dev.read(0x81,64,timeout=timeout))
        if len(b)<2 or len(b)!=b[1]+2:
            raise RuntimeError(f'Malformed packet {b.hex()}')
        if b[0]==254:
            raise RuntimeError(f'Firmware error {b[2:]!r}')
        return b[0],b[2:]

    def drain(self):
        result=[]
        while True:
            try: result.append(self.receive(5))
            except usb.core.USBTimeoutError: return result

    def expect(self, kind):
        for _ in range(32):
            k,data=self.receive()
            if k==kind: return data
            if k==255: continue
            if k==82:
                self.received.extend(data)
                continue
            raise RuntimeError(f'Expected packet {kind}, got {k}: {data!r}')
        raise RuntimeError('Too many unsolicited packets')

    def get(self, name):
        self.send(21,name.encode()+b'\0')
        return self.expect(22).decode()

    def set(self, name, value):
        self.send(20,f'{name},{value}'.encode()+b'\0')
        return self.expect(22).decode()

    def read(self, offset, length):
        data=bytearray()
        while len(data)<length:
            pos=offset+len(data)
            n=min(32,length-len(data))
            self.send(7,struct.pack('<IB',pos,n))
            b=self.expect(8)
            if len(b)!=n+4 or struct.unpack_from('<I',b)[0]!=pos:
                raise RuntimeError('Readback offset/length mismatch')
            data.extend(b[4:])
        return bytes(data)

    def write(self, offset, data):
        for i in range(0,len(data),32):
            self.send(6,struct.pack('<I',offset+i)+data[i:i+32])
        # A request/response fence ensures all earlier writes were processed.
        self.get('status')

    def start(self, base=0x1c00):
        assert base % 1024 == 0
        self.send(80,struct.pack('<I',base))
        k,b=self.receive()
        if k!=255: raise RuntimeError(f'Comms start response {k}: {b!r}')

    def end(self):
        self.send(81)
        k,b=self.receive()
        if k!=255: raise RuntimeError(f'Comms end response {k}: {b!r}')

    def poll(self):
        # The firmware emits outgoing bytes only after a CommsData request.
        # A following parameter reply fences the optional data response.
        first = len(self.received)
        self.send(82)
        self.get('status')
        return bytes(self.received[first:])

    def events(self, base=0x1c00):
        # Retry if the producer advanced while the USB snapshot was read.
        for _ in range(20):
            b=self.read(base,0x200)
            if b[:4]!=b'PICO':
                return {'magic':b[:4].hex(),'active':False,'events':[]}
            count=struct.unpack_from('<I',b,32)[0]
            if self.read(base+32,4)!=b[32:36]: continue
            events=[]
            for i in range(max(0,count-31),count):
                address,timestamp=struct.unpack_from('<II',b,0x104+(i%31)*8)
                events.append({'sequence':i,'address':hex(address),'time_us':timestamp})
            return {'magic':b[:4].decode(errors='replace'),'active':struct.unpack_from('<I',b,4)[0],
                    'count':count,'dropped_bytes':struct.unpack_from('<I',b,36)[0],
                    'last_event_us':struct.unpack_from('<I',b,40)[0],
                    'capture_stopped':bool(struct.unpack_from('<I',b,44)[0]), 'events':events}
        raise RuntimeError('No stable event snapshot')

if __name__=='__main__':
    import json
    p=Pico()
    try:
        print(json.dumps({k:p.get(k) for k in ['name','build_config','diag_version','rom_enable','addr_mask']},indent=2))
        print(json.dumps(p.events(),indent=2))
    finally: p.close()
