#!/usr/bin/env python3
import sys, os

romdir, outdir = sys.argv[1], sys.argv[2]

def bitswap(v, bits):
    r = 0
    n = len(bits)
    for k, b in enumerate(bits):
        r |= ((v >> b) & 1) << (n - 1 - k)
    return r

def b(v, n):
    return (v >> n) & 1

def jt2020_addr(a):
    r = a & 0xfc00
    r |= b(a, 7) << 8 | b(a, 8) << 9
    r |= (~a & 7)
    r |= (1 - b(a, 4)) << 3 | (1 - b(a, 5)) << 4 | (1 - b(a, 9)) << 5
    r |= b(a, 3) << 6 | b(a, 6) << 7
    return r

def jt2020_data(d):
    bits = [3, 4, 2, 5, 1, 6, 0, 7]
    return sum(b(d, s) << (7 - k) for k, s in enumerate(bits))

def mame_addr(i):
    return bitswap(i, [15, 14, 13, 12, 11, 10, 8, 7, 6, 3, 9, 5, 4, 2, 1, 0]) ^ 0x3f

def mame_data(x):
    return bitswap(x, [3, 4, 2, 5, 1, 6, 0, 7])

def save(name, data, w=2):
    with open(os.path.join(outdir, name), "w") as f:
        for v in data:
            f.write("%0*x\n" % (w, v))

raw = b"".join(open(os.path.join(romdir, n), "rb").read() for n in ("7a", "7b", "7c", "7e"))
assert len(raw) == 0x8000
dec = [jt2020_data(raw[jt2020_addr(i) & 0x7fff]) for i in range(0x8000)]
save("map.hex", [jt2020_addr(i) for i in range(0x10000)], 4)
save("rom.hex", raw)
save("dec.hex", dec)

mame_dec = [mame_data(raw[mame_addr(i) & 0x7fff]) for i in range(0x8000)]
amis = sum(jt2020_addr(i) != mame_addr(i) for i in range(0x10000))
dmis = sum(dec[i] != mame_dec[i] for i in range(0x8000))
print("extra check, JT 2020 model vs MAME tpp2 decrypt: %d address and %d data mismatches" % (amis, dmis))

inv = [0] * 256
for x in range(256):
    inv[jt2020_data(x)] = x

def encrypt(plain):
    enc = [0] * 0x8000
    for i in range(0x8000):
        enc[jt2020_addr(i) & 0x7fff] = inv[plain[i]]
    return enc

def prog(main, nmi=None):
    p = [0] * 0x8000
    p[0:len(main)] = main
    if nmi:
        p[0x66:0x66 + len(nmi)] = nmi
    return encrypt(p)

LD_SP = [0x31, 0x00, 0x8f]
def ld_i(v):
    return [0x3e, v, 0xed, 0x47]
LOOP = [0x18, 0xfe]
RETN = [0xed, 0x45]

nmi_cnt = [0x3a, 0x00, 0x88, 0x3c, 0x32, 0x00, 0x88, 0xfe, 0x03, 0x28, 0x0a]
nmi_cnt += ld_i(0) + ld_i(1) + RETN
nmi_cnt += ld_i(0) + RETN
save("c_nmi.hex",  prog(LD_SP + [0xaf, 0x32, 0x00, 0x88] + ld_i(1) + LOOP, nmi_cnt))
save("c_wd.hex",   prog(LD_SP + ld_i(2) + LOOP))
save("c_wdnmi.hex",prog(LD_SP + ld_i(3) + LOOP, RETN))

io  = LD_SP + ld_i(0)
io += [0x21, 0x00, 0x8c, 0x06, 0x00, 0x7d, 0xee, 0x5a, 0x77, 0x23, 0x10, 0xf9]
for n in range(4):
    io += [0xdb, n, 0x32, n, 0x88]
io += [0x3e, 0x07, 0xd3, 0x00, 0x3e, 0x3c, 0xd3, 0x01]
io += [0x3e, 0x99, 0x32, 0x10, 0xc0, 0x3e, 0x66, 0x32, 0x20, 0xa0]
io += [0x3e, 0x77, 0x32, 0x01, 0xe0, 0x3a, 0x00, 0xe0, 0x32, 0x04, 0x88]
io += [0x3e, 0xc3, 0x32, 0x0f, 0x88]
io += LOOP
save("c_io.hex", prog(io))
print("first decrypted bytes:", " ".join("%02x" % v for v in dec[:16]))


def tnx_addr(a):
    lo = (b(a, 8) << 9) | (b(a, 7) << 8) | ((1 - b(a, 0)) << 7) | ((1 - b(a, 1)) << 6) | ((1 - b(a, 2)) << 5) \
       | ((1 - b(a, 4)) << 4) | ((1 - b(a, 5)) << 3) | ((1 - b(a, 9)) << 2) | (b(a, 3) << 1) | b(a, 6)
    return (a & 0x7c00) | lo

def rd(sub, name):
    return open(os.path.join(romdir, sub, name), "rb").read()

sets = {
    1: b"".join(rd("popeyej", "tpp1-c.2%s,2732" % c) for c in "abcdefgh"),
    2: b"".join(rd("popeyebl", n) for n in ("app_exe.3j.2764", "2.3l.2764", "3.3m.2764", "4.3p.2764")),
    3: b"".join(rd("skyskipr", "tnx1-c.2%s" % c) for c in "abcdefg") + b"\xff" * 0x1000,
}
ramap = {0: lambda a: jt2020_addr(a) & 0x7fff, 1: tnx_addr, 2: lambda a: a, 3: tnx_addr}
dswap = {0: jt2020_data, 1: jt2020_data, 2: lambda d: d, 3: jt2020_data}
decs = {0: dec}
for bd, raw_b in sets.items():
    assert len(raw_b) == 0x8000
    decs[bd] = [dswap[bd](raw_b[ramap[bd](i)]) for i in range(0x8000)]
    save("rom%d.hex" % bd, raw_b)
    save("dec%d.hex" % bd, decs[bd])
    print("board %d: decrypted 0000-0007: %s, 0066-0069: %s, byte sum %02x" % (bd,
        " ".join("%02x" % v for v in decs[bd][0:8]), " ".join("%02x" % v for v in decs[bd][0x66:0x6a]),
        sum(decs[bd]) & 0xff))

same = sum(decs[1][i] == decs[2][i] for i in range(0x8000))
print("extra check, popeyej (TPP1 rule) vs popeyebl: %d of 32768 bytes equal" % same)

def romtest(d):
    tab = d[0x76f3:0x76fb]
    return sum((sum(d[k * 0x1000:(k + 1) * 0x1000]) & 0xff) != tab[k] for k in range(8))
for bd in (1, 2):
    print("board %d: test-mode ROM test predicts %d bad chips" % (bd, romtest(decs[bd])))
save("romtest.hex", [romtest(decs[1]), romtest(decs[2])])

lo = rd("popeyebl", "1.1d.24s10")
hi = rd("popeyebl", "2.1e.24s10")
assert len(lo) == 256 and len(hi) == 256
save("blprot.hex", [((hi[i] & 15) << 4) | (lo[i] & 15) for i in range(256)])
save("blcopy.hex", list(decs[2][0x58cd:0x58eb]))

def encode(bd, plain):
    if bd == 2:
        return list(plain)
    enc = [0] * 0x8000
    for i in range(0x8000):
        enc[ramap[bd](i)] = inv[plain[i]]
    return enc

ramt  = [0x21, 0x00, 0x80, 0x11, 0x0d, 0x00]
ramt += [0x7c, 0xad, 0xee, 0x5a, 0x77, 0x19, 0x7c, 0xfe, 0x90, 0x38, 0xf5]
ramt += [0x21, 0x00, 0x80, 0x7e, 0x19, 0x7c, 0xfe, 0x90, 0x38, 0xf9]
ramt += LOOP
for bd in range(4):
    p = [0] * 0x8000
    p[0:len(ramt)] = ramt
    save("c_ram%d.hex" % bd, encode(bd, p))
save("p_ram.hex", p)

import random
random.seed(1982)
cases = []
for sh in range(1, 8):
    for _ in range(3):
        cases.append((sh, random.randrange(256), random.randrange(256), True))
for sh in (1, 2, 3):
    for k in range(4):
        cases.append((sh, random.randrange(256), random.randrange(256), k == 0))
blp = [0x31, 0x00, 0x8f]
exp = []
old = 0
for k, (sh, o, n, fresh) in enumerate(cases):
    blp += [0x3e, sh, 0x32, 0x01, 0x8f]
    if fresh:
        blp += [0x3e, o, 0x32, 0x02, 0x8f]
        old = o
    blp += [0x3e, n, 0x32, k, 0x81, 0x21, k, 0x81]
    blp += [0xcd, 0x00, 0xe0]
    blp += [0x32, k, 0x80]
    exp.append(((n << sh) | (old >> (8 - sh))) & 0xff)
    old = n
blp += [0x3a, 0x01, 0xe0, 0x32, 0x80, 0x80]
blp += LOOP
p = [0] * 0x8000
p[0:len(blp)] = blp
save("c_bl.hex", p)
save("bl_exp.hex", ([len(cases)] + exp + [0] * 64)[:64])
print("bootleg CALL E000: %d cases, expected 7K results %s" % (len(cases), " ".join("%02x" % v for v in exp)))
