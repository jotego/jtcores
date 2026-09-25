#!/usr/bin/env python3
# Builds sdram_bank*.bin + nvram.bin for sims from the MAME speedrcr set.
# bank0: i960 prog @0 (LOAD32_WORD ea4/oa4) | data @0x100000 (LOAD32_BYTE dat0-3)
#        | C75 data rom (spr) @0x300000 | roz weave (rch0-1 + rsh) @0x400000
# bank1: obj0l/0u, obj1l/1u interleaved as ROM_LOAD32_WORD
# bank2: pcm @0 (work RAM lives at 0x400000, no preload)
# bank3: scr weave (sch0-3 + ssh interleaved) @0
# nvram.bin: 8kB of 0xFF (MAME NVRAM DEFAULT_ALL_1; the game inits it on first boot)
#
# --fastboot patches the POST delay/RAM-test lengths in the prog copy so RTL
# boot sims reach the main loop in a few frames instead of >600. SIM ONLY.
import py7zr, zipfile, io, sys, os, tempfile, zipfile

rompath  = next(p for p in (os.path.expanduser("~/develop/mame/roms/speedrcr"+e)
                for e in (".7z",".zip")) if os.path.exists(p))
c75path  = os.path.expanduser("~/develop/mame/roms/namcoc75.zip")
fastboot = "--fastboot" in sys.argv
args     = [a for a in sys.argv[1:] if not a.startswith("--")]
outdir   = args[0] if args else "."
tmpd = tempfile.mkdtemp()
if rompath.endswith(".7z"):
    with py7zr.SevenZipFile(rompath) as z:
        z.extractall(tmpd)
else:
    with zipfile.ZipFile(rompath) as z:
        z.extractall(tmpd)
files = {}
for root,_,names in os.walk(tmpd):
    for n in names:
        files[n] = open(os.path.join(root,n),"rb").read()

def get(name):
    for k in files:
        if k.lower().endswith(name.lower()): return files[k]
    raise SystemExit(f"missing {name} in {rompath}")

# i960 program, 1MB
prog = bytearray(0x100000)
ea4, oa4 = get("se2_mp_ea4.19a"), get("se2_mp_oa4.18a")
for i in range(0, len(ea4), 2):
    prog[2*i  :2*i+2] = ea4[i:i+2]
    prog[2*i+2:2*i+4] = oa4[i:i+2]

if fastboot:
    # (offset, original word, patched word) - all inside POST code
    patches = [
        (0x0f50, 0x04000000, 0x00000100),  # 67M-iteration delay loop
        (0x0d40, 0x00200000, 0x00000100),  # 2M-iteration delay after each POST print
        (0x0f98, 0x0003efff, 0x000000ff),  # work RAM test length
        (0x0dac, 0x000023ff, 0x000000ff),  # vram test length
        (0x1118, 0x00003fff, 0x000000ff),  # oram test length
        (0x1148, 0x00007fff, 0x000000ff),  # rozram test length
        (0x0dc4, 0x8ca805ff, 0x8ca8007f),  # pal R test lda 0x5ff -> 0x7f
        (0x0dd8, 0x8ca805ff, 0x8ca8007f),  # pal G
        (0x0dec, 0x8ca805ff, 0x8ca8007f),  # pal B
        (0x0e00, 0x8ca805ff, 0x8ca8007f),  # c116 regs area
        # NVRAM init: 200k-iteration EEPROM write delays, one per block
        (0x1440, 0x00030d40, 0x00000010),
        (0x14e0, 0x00030d40, 0x00000010),
        (0x1530, 0x00030d40, 0x00000010),
        (0x1578, 0x00030d40, 0x00000010),
        (0x15cc, 0x00030d40, 0x00000010),
    ]
    for off, old, new in patches:
        cur = int.from_bytes(prog[off:off+4], "little")
        if cur != old:
            raise SystemExit(f"fastboot patch mismatch at {off:#x}: {cur:#x} != {old:#x}")
        prog[off:off+4] = new.to_bytes(4, "little")
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
    # NB: the game-start handshake self-paces once the C75 responds, so no
    # artificial pre-command pause is needed here. (Earlier bring-up kept one
    # at 0x97c; the instruction cache + a warm NVRAM removed the need.)
    print(f"fastboot patches applied, {ndel} generic delay loops shortened (SIM ONLY image)")

data = bytearray(0x200000)
dats = [get(f"se1_dat{i}.1{3+i}a") for i in range(4)]
for i in range(0x80000):
    for j in range(4):
        data[4*i+j] = dats[j][i]

def swab(b):
    o = bytearray(b)
    o[0::2], o[1::2] = b[1::2], b[0::2]
    return o

# ROZ texel+mask weave: 8-byte units keyed by {code[12:0],yp[3:0],xp[3:2]}
# [4 texels][mask byte code13=0][mask byte code13=1][2 pad] -> 4MB @0x400000
# one 64-bit burst returns the texel run and both mask bytes
def roz_weave(rch, rsh):
    w = bytearray(0x400000)
    for j in range(4):
        w[j::8] = rch[j::4]
    for h in (0, 8):  # the two xp[2] units of a group share the mask byte
        w[4+h::16] = rsh[0:0x40000]
        w[5+h::16] = rsh[0x40000:0x80000]
    return w

# C123 tile+mask weave: 8-byte units keyed by {code[15:0],row[2:0],col[2]}
# [4 texels][mask byte][3 pad] -> 8MB; one 64-bit burst returns a 4-texel
# run and the full row mask
def scr_weave(sch, ssh):
    w = bytearray(0x800000)
    for j in range(4):
        w[j::8] = sch[j::4]
    for h in (0, 8):  # the two col[2] units of a row share the mask byte
        w[4+h::16] = ssh
    return w

bank0 = bytearray(0x800000)
bank0[0:0x100000] = prog
bank0[0x100000:0x300000] = data
bank0[0x300000:0x380000] = get("se1_spr.21l")   # C75 external data ROM
bank0[0x400000:0x800000] = roz_weave(get("se1_rch0.19j")+get("se1_rch1.18j"),
                                     get("se1_rsh.14k"))

bank3 = scr_weave(b"".join(get(f) for f in
            ["se1_sch0.21p","se1_sch1.20p","se1_sch2.19p","se1_sch3.18p"]),
        get("se1_ssh.18u"))

# C352 sample ROM fills bank 2 (pcm bus at offset 0); nvram and comram live
# in the upper wram window (bank bytes 0x500000 / 0x580000)
bank2 = bytearray(0x600000)
bank2[0:0x400000] = get("se1_voi.23s")

# C75 internal BIOS, from the MAME namcoc75 device set
with zipfile.ZipFile(c75path) as z:
    c75 = z.read("c75.bin")
assert len(c75)==0x4000, "c75.bin must be 16kB"

bank1 = bytearray(0x800000)
for base, lf, uf in [(0, "se1obj0l.ic1", "se1obj0u.ic2"), (0x400000, "se1obj1l.ic3", "se1obj1u.ic4")]:
    lo, up = get(lf), get(uf)
    for i in range(0, len(lo), 2):
        o = base + i*2
        bank1[o:o+2]   = lo[i:i+2]
        bank1[o+2:o+4] = up[i:i+2]

# prefer a once-booted NVRAM image (MAME first-boot initialized): the game
# then loads valid settings/calibration and boots straight to attract.
# Fresh 0xFF NVRAM also works in MAME; our fresh-init path has a remaining
# divergence in the wheel-calibration defaults (see boot notes) - TODO
mamenv = os.path.expanduser("~/develop/mame/nvram/speedrcr/nvram")
nv = open(mamenv,"rb").read() if os.path.exists(mamenv) else bytes([0xff]*0x2000)
open(os.path.join(outdir,"nvram.bin"),"wb").write(nv)  # restored into the nvram BRAM at download
print("nvram.bin written" + (" from MAME first-boot image" if os.path.exists(mamenv) else " fresh 0xFF"))

open(os.path.join(outdir,"sdram_bank0.bin"),"wb").write(swab(bank0))
open(os.path.join(outdir,"sdram_bank1.bin"),"wb").write(swab(bank1))
open(os.path.join(outdir,"sdram_bank2.bin"),"wb").write(swab(bank2))
open(os.path.join(outdir,"sdram_bank3.bin"),"wb").write(swab(bank3))
# the BIOS BRAM is a 16-bit jtframe_bram_rom, simfiles are split by byte lane
open(os.path.join(outdir,"c75bios_lo.bin"),"wb").write(c75[0::2])
open(os.path.join(outdir,"c75bios_hi.bin"),"wb").write(c75[1::2])
# jtsim downloads rom.bin over bank 0 before releasing reset. The download path
# is byte-exact while the bank preload swaps 16-bit bytes, hence raw prog here
# so the overwrite is a no-op. First 8 bytes = MRA header, byte 0 flr=0
open(os.path.join(outdir,"rom.bin"),"wb").write(bytes(8)+bytes(prog[:1024]))
print("sdram banks + nvram written")
