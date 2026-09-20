#!/usr/bin/env python3
# Builds sdram_bank*.bin + nvram.bin for sims from the MAME finalapr set.
# Same System FL layout as ver/speedrcr, banks are 0xFF-initialized to match
# the MRA fillers (the data region is ROMREGION_ERASEFF, no ROMs).
# bank0: i960 prog @0 (LOAD32_WORD eb/ob) | data erased @0x100000
#        | rch0-1 @0x400000 | rsh @0x600000
# bank1: pcm 2MB @0 (work RAM lives at 0x400000, no preload)
# bank2: sch0-3 @0 | ssh @0x400000 | spr (128kB) @0x500000
# bank3: obj0l/0u, obj1l/1u interleaved as ROM_LOAD32_WORD
#
# --fastboot only runs the generic delay-loop shortener (no per-offset POST
# patches calibrated for this program yet). SIM ONLY.
import sys, os, tempfile, zipfile

rompath  = os.path.expanduser("~/develop/mame/roms/finalapr.zip")
c75path  = os.path.expanduser("~/develop/mame/roms/namcoc75.zip")
fastboot = "--fastboot" in sys.argv
args     = [a for a in sys.argv[1:] if not a.startswith("--")]
outdir   = args[0] if args else "."
files = {}
if rompath.endswith(".7z"):
    import py7zr
    tmpd = tempfile.mkdtemp()
    with py7zr.SevenZipFile(rompath) as z:
        z.extractall(tmpd)
    for root,_,names in os.walk(tmpd):
        for n in names:
            files[n] = open(os.path.join(root,n),"rb").read()
else:
    with zipfile.ZipFile(rompath) as z:
        for n in z.namelist():
            files[n] = z.read(n)

def get(name):
    for k in files:
        if k.lower().endswith(name.lower()): return files[k]
    raise SystemExit(f"missing {name} in {rompath}")

# i960 program, 1MB
prog = bytearray(0x100000)
eb, ob = get("flr2_mp_eb.19a"), get("flr2_mp_ob.18a")
for i in range(0, len(eb), 2):
    prog[2*i  :2*i+2] = eb[i:i+2]
    prog[2*i+2:2*i+4] = ob[i:i+2]

if fastboot:
    # generic pure-delay loops: lda <imm>,r3 / cmpdeco 0|1,r3,r3 / bl .-4
    ndel = 0
    for i in range(0, len(prog)-16, 4):
        if (prog[i:i+4] == b'\x00\x30\x18\x8c' and
            prog[i+8:i+12] in (b'\x00\xcb\x18\x5a', b'\x01\xcb\x18\x5a') and
            prog[i+12:i+16] == b'\xfc\xff\xff\x14'):
            imm = int.from_bytes(prog[i+4:i+8], "little")
            if imm > 0x1000:
                prog[i+4:i+8] = (0x100).to_bytes(4, "little")
                ndel += 1
    print(f"fastboot: {ndel} generic delay loops shortened (SIM ONLY image)")

def swab(b):
    o = bytearray(b)
    o[0::2], o[1::2] = b[1::2], b[0::2]
    return o

bank0 = bytearray(b'\xff'*0x680000)
bank0[0:0x100000] = prog
pos = 0x400000
for f in ["flr1_rch0.19j","flr1_rch1.18j"]:
    d = get(f); bank0[pos:pos+len(d)] = d; pos += 0x100000
bank0[0x600000:0x680000] = get("flr1_rsh.14k")

bank2 = bytearray(b'\xff'*0x580000)
pos = 0
for f in ["flr1_sch0.21p","flr1_sch1.20p","flr1_sch2.19p","flr1_sch3.18p"]:
    d = get(f); bank2[pos:pos+len(d)] = d; pos += 0x100000
bank2[0x400000:0x480000] = get("flr1_ssh.18u")
spr = get("flr1_spr.21l")
bank2[0x500000:0x500000+len(spr)] = spr

# C352 sample ROM, 2MB set in a 4MB bank
bank1 = bytearray(b'\xff'*0x400000)
voi = get("flr1_voi.23s")
bank1[0:len(voi)] = voi

# C75 internal BIOS, from the MAME namcoc75 device set
with zipfile.ZipFile(c75path) as z:
    c75 = z.read("c75.bin")
assert len(c75)==0x4000, "c75.bin must be 16kB"

bank3 = bytearray(0x800000)
for base, lf, uf in [(0, "flr1_obj0l.ic1", "flr1_obj0u.ic2"), (0x400000, "flr1_obj1l.ic3", "flr1_obj1u.ic4")]:
    lo, up = get(lf), get(uf)
    for i in range(0, len(lo), 2):
        o = base + i*2
        bank3[o:o+2]   = lo[i:i+2]
        bank3[o+2:o+4] = up[i:i+2]

open(os.path.join(outdir,"sdram_bank0.bin"),"wb").write(swab(bank0))
open(os.path.join(outdir,"sdram_bank2.bin"),"wb").write(swab(bank2))
open(os.path.join(outdir,"sdram_bank3.bin"),"wb").write(swab(bank3))
open(os.path.join(outdir,"sdram_bank1.bin"),"wb").write(swab(bank1))
open(os.path.join(outdir,"c75bios_lo.bin"),"wb").write(c75[0::2])
open(os.path.join(outdir,"c75bios_hi.bin"),"wb").write(c75[1::2])
# prefer a once-booted NVRAM image if available; fresh 0xFF otherwise
mamenv = os.path.expanduser("~/develop/mame/nvram/finalapr/nvram")
if os.path.exists(mamenv):
    open(os.path.join(outdir,"nvram.bin"),"wb").write(open(mamenv,"rb").read())
    print("nvram.bin taken from MAME first-boot image")
else:
    open(os.path.join(outdir,"nvram.bin"),"wb").write(bytes([0xff]*0x2000))
# jtsim downloads rom.bin over bank 0 before releasing reset; raw prog head
# makes the overwrite a no-op (see ver/speedrcr)
open(os.path.join(outdir,"rom.bin"),"wb").write(bytes(prog[:1024]))
