#!/usr/bin/env python3
# Assemble dump.bin per scene in the core ioctl order (see ver/game/dump2bin.sh):
# nvram 8k | vram 64k | rozram 128k | oram 128k | rpal 8k | gpal 8k | bpal 8k |
# rest: scrctl 0x40 + rozctl 0x20 + c116 regs 0x10 + sprbank 4
import sys, os, glob

for d in sorted(glob.glob("burst_*")):
    if not os.path.isdir(d): continue
    def rd(n): return open(os.path.join(d,n),"rb").read()
    pal  = rd("pal.bin")
    rpal = b"".join(pal[b*0x2000        : b*0x2000+0x0800] for b in range(4))
    gpal = b"".join(pal[b*0x2000+0x0800 : b*0x2000+0x1000] for b in range(4))
    bpal = b"".join(pal[b*0x2000+0x1000 : b*0x2000+0x1800] for b in range(4))
    c116 = pal[0x1800:0x1810]
    nv   = rd("nvram.bin") if os.path.exists(os.path.join(d,"nvram.bin")) else bytes(0x2000)
    out  = nv + rd("vram.bin") + rd("rozram.bin") + rd("oram.bin") + rpal + gpal + bpal
    out += rd("scrctl.bin") + rd("rozctl.bin") + c116 + rd("regs.bin")
    open(os.path.join(d,"dump.bin"),"wb").write(out)
    print(f"{d}: {len(out)} bytes")
