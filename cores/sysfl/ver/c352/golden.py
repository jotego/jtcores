#!/usr/bin/env python3
# Golden model for jt352: direct port of MAME c352.cpp (superctr's RE model)
# Generates ROM image, register write scripts and expected samples per test case
import os

BUSY=0x8000; KEYON=0x4000; KEYOFF=0x2000; LOOPTRG=0x1000; LOOPHIST=0x0800
FM=0x0400; PHASERL=0x0200; PHASEFL=0x0100; PHASEFR=0x0080; LDIR=0x0040
LINK=0x0020; NOISE=0x0010; MULAW=0x0008; FILTER=0x0004; LOOP=0x0002; REVERSE=0x0001

def s16(x):
    x &= 0xffff
    return x-0x10000 if x & 0x8000 else x

def s8(x):
    x &= 0xff
    return x-0x100 if x & 0x80 else x

# mu-law table, exact MAME generation
MULAW_T = [0]*256
j = 0
for i in range(128):
    MULAW_T[i] = s16(j << 5)
    if   i < 16:  j += 1
    elif i < 24:  j += 2
    elif i < 48:  j += 4
    elif i < 100: j += 8
    else:         j += 16
for i in range(128):
    MULAW_T[i+128] = s16((~MULAW_T[i]) & 0xffe0)

class Voice:
    def __init__(self):
        self.pos=0; self.counter=0; self.sample=0; self.last=0
        self.vol_f=0; self.vol_r=0; self.cv=[0,0,0,0]
        self.freq=0; self.flags=0
        self.bank=0; self.start=0; self.end=0; self.loop=0

class C352:
    def __init__(self, rom):
        self.v = [Voice() for _ in range(32)]
        self.rnd = 0x1234
        self.control = 0
        self.rom = rom

    def read_byte(self, pos):
        pos &= 0xfff  # 4KB synthetic image, matches TB rom model
        return self.rom[pos] if pos < len(self.rom) else 0

    def fetch(self, v):
        v.last = v.sample
        if v.flags & NOISE:
            self.rnd = ((self.rnd >> 1) ^ (0xfff6 if self.rnd & 1 else 0)) & 0xffff
            v.sample = s16(self.rnd)
        else:
            s = s8(self.read_byte(v.pos))
            v.sample = MULAW_T[s & 0xff] if v.flags & MULAW else s16(s << 8)
            pos16 = v.pos & 0xffff
            if (v.flags & LOOP) and (v.flags & REVERSE):
                if (v.flags & LDIR) and pos16 == v.loop:
                    v.flags &= ~LDIR
                elif not (v.flags & LDIR) and pos16 == v.end:
                    v.flags |= LDIR
                v.pos = (v.pos + (-1 if v.flags & LDIR else 1)) & 0xffffff
            elif pos16 == v.end:
                if (v.flags & LINK) and (v.flags & LOOP):
                    v.pos = ((v.start << 16) | v.loop) & 0xffffff
                    v.flags |= LOOPHIST
                elif v.flags & LOOP:
                    v.pos = (v.pos & 0xff0000) | v.loop
                    v.flags |= LOOPHIST
                else:
                    v.flags |= KEYOFF
                    v.flags &= ~BUSY
                    v.sample = 0
            else:
                v.pos = (v.pos + (-1 if v.flags & REVERSE else 1)) & 0xffffff

    def update(self):
        out = [0, 0, 0, 0]
        for v in self.v:
            s = 0
            if v.flags & BUSY:
                nc = v.counter + v.freq
                if nc & 0x10000:
                    self.fetch(v)
                if (nc ^ v.counter) & 0x18000:
                    for ch, tgt in enumerate([v.vol_f >> 8, v.vol_f & 0xff,
                                              v.vol_r >> 8, v.vol_r & 0xff]):
                        d = v.cv[ch] - tgt
                        if d != 0:
                            v.cv[ch] += -1 if d > 0 else 1
                v.counter = nc & 0xffff
                s = v.sample
                if not v.flags & FILTER:
                    prod = (v.counter * ((v.sample - v.last) & 0xffffffff)) & 0xffffffff
                    s = s16(v.last + (prod >> 16))
            out[0] += ((-s if v.flags & PHASEFL else s) * v.cv[0]) >> 8
            out[2] += ((-s if v.flags & PHASERL else s) * v.cv[2]) >> 8
            out[1] += ((-s if v.flags & PHASEFR else s) * v.cv[1]) >> 8
            out[3] += ((-s if v.flags & PHASEFR else s) * v.cv[3]) >> 8  # MAME quirk
        return [s16((o >> 3) & 0xffff) for o in out]

    def write(self, offset, data):
        data &= 0xffff
        if offset < 0x100:
            v = self.v[offset // 8]
            r = offset % 8
            if   r == 0: v.vol_f = data
            elif r == 1: v.vol_r = data
            elif r == 2: v.freq  = data
            elif r == 3: v.flags = data
            elif r == 4: v.bank  = data
            elif r == 5: v.start = data
            elif r == 6: v.end   = data
            elif r == 7: v.loop  = data
        elif offset == 0x200:
            self.control = data
        elif offset == 0x202:
            for v in self.v:
                if v.flags & KEYON:
                    v.pos = ((v.bank << 16) | v.start) & 0xffffff
                    v.sample = 0
                    v.last = 0
                    v.counter = 0xffff
                    v.flags |= BUSY
                    v.flags &= ~(KEYON | LOOPHIST)
                    v.cv = [0, 0, 0, 0]
                if v.flags & KEYOFF:
                    v.flags &= ~(BUSY | KEYOFF)
                    v.counter = 0xffff

# ------------------------------------------------------------------ test data
def build_rom():
    import math
    rom = bytearray(4096)
    for i in range(256):   # 0x100: linear one-shot, sine-ish
        rom[0x100+i] = int(127*math.sin(i*math.pi/32)) & 0xff
    for i in range(128):   # 0x200: mu-law source bytes
        rom[0x200+i] = (i*5 + 3) & 0xff
    for i in range(128):   # 0x280: second looped linear voice
        rom[0x280+i] = ((i*11) ^ 0x40) & 0xff
    for i in range(128):   # 0x300: reverse / ping-pong region
        rom[0x300+i] = (255 - i*2) & 0xff
    return rom

def vw(v, r, d):
    return (v*8+r, d)

CASES = {
    'linear': [   # 8-bit linear one-shot, ends with KEYOFF within the capture
        vw(0,0,0xffff), vw(0,1,0x8040), vw(0,2,0xc000), vw(0,4,0x0000),
        vw(0,5,0x0100), vw(0,6,0x01ff), vw(0,7,0x0100), vw(0,3,KEYON),
        (0x202,0xffff),
    ],
    'muloop': [   # mu-law looped voice plus a second linear looped voice
        vw(1,0,0xc0c0), vw(1,1,0x2020), vw(1,2,0x8000), vw(1,4,0x0000),
        vw(1,5,0x0200), vw(1,6,0x027f), vw(1,7,0x0220), vw(1,3,KEYON|LOOP|MULAW),
        vw(2,0,0x8080), vw(2,1,0x0000), vw(2,2,0x5555), vw(2,4,0x0000),
        vw(2,5,0x0280), vw(2,6,0x02ff), vw(2,7,0x0290), vw(2,3,KEYON|LOOP),
        (0x202,0xffff),
    ],
    'reverse': [  # one-shot played backwards, start > end
        vw(3,0,0xffff), vw(3,1,0xffff), vw(3,2,0xc000), vw(3,4,0x0000),
        vw(3,5,0x037f), vw(3,6,0x0300), vw(3,7,0x0300), vw(3,3,KEYON|REVERSE),
        (0x202,0xffff),
    ],
    'pingpong': [ # loop+reverse ping-pong with FR phase inversion
        vw(4,0,0xffff), vw(4,1,0x4040), vw(4,2,0x6000), vw(4,4,0x0000),
        vw(4,5,0x0310), vw(4,6,0x033f), vw(4,7,0x0310),
        vw(4,3,KEYON|LOOP|REVERSE|PHASEFR),
        (0x202,0xffff),
    ],
    'noise': [    # LFSR noise, seed 0x1234 as MAME reset
        vw(5,0,0xffff), vw(5,1,0xffff), vw(5,2,0x8000), vw(5,3,KEYON|NOISE),
        (0x202,0xffff),
    ],
}

NSAMPLES = 400

def main():
    here = os.path.dirname(os.path.abspath(__file__))
    rom = build_rom()
    for name, writes in CASES.items():
        d = os.path.join(here, 'cases', name)
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, 'rom.hex'), 'w') as f:
            for b in rom:
                f.write('%02x\n' % b)
        with open(os.path.join(d, 'writes.hex'), 'w') as f:
            for off, data in writes:
                f.write('%04x%04x\n' % (off, data))
            f.write('ffffffff\n')
        chip = C352(rom)
        for off, data in writes:
            chip.write(off, data)
        with open(os.path.join(d, 'expected.hex'), 'w') as f:
            for _ in range(NSAMPLES):
                o = chip.update()
                f.write('%04x\n%04x\n' % (o[0] & 0xffff, o[1] & 0xffff))
        with open(os.path.join(d, 'n.txt'), 'w') as f:
            f.write('%d\n' % NSAMPLES)
        print('generated case', name)

if __name__ == '__main__':
    main()
