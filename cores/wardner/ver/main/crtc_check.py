#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Marc Emmerson
# SPDX-License-Identifier: GPL-3.0-or-later
"""Derive the raster from the CRTC values the game itself programs.

The HD6845S is written once at boot through ports 00 and 02. Nothing in this
core reads those registers back - the video timing is hardcoded, as it is in
every other jtcore - so this is an independent check that the hardcoded numbers
are the ones the hardware's own software asks for.

usage: crtc_check.py [boot.log]
"""
import sys

EXPECT = {"htotal": 446, "hvisible": 320, "vtotal": 286, "vvisible": 240}

def main():
    log = sys.argv[1] if len(sys.argv) > 1 else "boot.log"
    regs, cur = {}, None
    for line in open(log):
        f = line.split()
        if len(f) < 3 or f[1] != "OUT":
            continue
        port, data = f[2].split(",")
        if port == "00":
            cur = int(data, 16)
        elif port == "02" and cur is not None:
            regs.setdefault(cur, int(data, 16))
    need = [0, 1, 4, 5, 6, 9]
    if any(r not in regs for r in need):
        raise SystemExit("crtc_check: the log does not contain a full CRTC setup")
    got = {
        "htotal":   (regs[0] + 1) * 2,              # char clock is two pixels
        "hvisible":  regs[1] * 2,
        "vtotal":   (regs[4] + 1) * (regs[9] + 1) + regs[5],
        "vvisible":  regs[6] * (regs[9] + 1),
    }
    bad = 0
    for k in EXPECT:
        ok = got[k] == EXPECT[k]
        bad += 0 if ok else 1
        print("  %-9s programmed %4d   hardcoded %4d   %s"
              % (k, got[k], EXPECT[k], "match" if ok else "MISMATCH"))
    print("crtc_check: %s" % ("PASS" if bad == 0 else "FAIL"))
    return 1 if bad else 0

sys.exit(main())
