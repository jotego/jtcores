#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Marc Emmerson
# SPDX-License-Identifier: GPL-3.0-or-later
"""Make a synthetic video snapshot: random tilemaps, palette, scroll values,
banks and sprites, in the same files tb_main.v writes. Used to fuzz the RTL
against render_ref.py on cases the game may not show for a while (flips,
every priority level, overlapping sprites, scroll wrap, bank bits).

usage: gen_snap.py <out dir> <seed> [--dense]"""
import sys, os, random

def main():
    out, seed = sys.argv[1], int(sys.argv[2])
    dense = "--dense" in sys.argv
    r = random.Random(seed)
    os.makedirs(out, exist_ok=True)
    def dump(name, words):
        with open(os.path.join(out, name), "w") as f:
            f.write("".join("%04x\n" % w for w in words))
    # tilemaps: some empty cells so transparency matters
    def tmap(n, codebits, palbits, empty):
        return [0 if r.random() < empty else
                (r.getrandbits(codebits) | (r.getrandbits(palbits) << (16 - palbits)))
                for _ in range(n)]
    dump("snap_tx.hex",  tmap(0x800,  11, 5, 0.6))
    dump("snap_bg.hex",  tmap(0x2000, 12, 4, 0.0))
    dump("snap_fg.hex",  tmap(0x1000, 12, 4, 0.5))
    dump("snap_pal.hex", [r.getrandbits(15) for _ in range(0x800)])
    obj = []
    nspr = 512 if dense else r.randint(0, 120)
    for i in range(512):
        if i < nspr:
            code = r.getrandbits(11)
            attr = r.getrandbits(6) | (r.getrandbits(2) << 8) | (r.getrandbits(2) << 10)
            x = r.randint(0, 511) if r.random() < 0.9 else r.randint(0, 40)
            y = r.randint(0, 511) if r.random() < 0.9 else r.choice([0, 0x100, 15, 16, 255, 256])
            if dense:                         # pile them up so pixels overlap
                x, y = r.randint(40, 300), r.randint(20, 240)
        else:
            code, attr, x, y = 0, 0, 0, 0x100
        obj += [code, attr, x << 7, y << 7]
    dump("snap_obj.hex", obj)
    regs = {"tx_scrx": r.getrandbits(16), "tx_scry": r.getrandbits(16),
            "bg_scrx": r.getrandbits(16), "bg_scry": r.getrandbits(16),
            "fg_scrx": r.getrandbits(16), "fg_scry": r.getrandbits(16),
            "flip": r.getrandbits(1), "bg_bank": r.getrandbits(1), "fg_bank": r.getrandbits(1),
            "video_on": 1}
    with open(os.path.join(out, "snap_regs.txt"), "w") as f:
        for k, v in regs.items():
            f.write("%s=%s\n" % (k, ("0x%04x" % v) if "scr" in k else str(v)))
    print("%s: %d sprites, flip %d, scroll bg %d,%d fg %d,%d tx %d,%d banks %d/%d" % (
        out, nspr, regs["flip"], regs["bg_scrx"] & 511, regs["bg_scry"] & 511, regs["fg_scrx"] & 511,
        regs["fg_scry"] & 511, regs["tx_scrx"] & 511, regs["tx_scry"] & 255,
        regs["bg_bank"], regs["fg_bank"]))

if __name__ == "__main__":
    main()
