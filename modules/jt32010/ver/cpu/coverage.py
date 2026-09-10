#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Marc Emmerson
# SPDX-License-Identifier: GPL-3.0-or-later
# Tally which instructions the fuzz actually executed, from a reference trace.
import sys, collections

def name(w):
    h, l = w >> 8, w & 0xff
    if   h <= 0x0f: return "ADD"
    elif h <= 0x1f: return "SUB"
    elif h <= 0x2f: return "LAC"
    elif h in (0x30,0x31): return "SAR"
    elif h in (0x38,0x39): return "LAR"
    elif 0x40 <= h <= 0x47: return "IN"
    elif 0x48 <= h <= 0x4f: return "OUT"
    elif h == 0x50: return "SACL"
    elif 0x58 <= h <= 0x5f: return "SACH"
    elif 0x80 <= h <= 0x9f: return "MPYK"
    elif h == 0x7f:
        return {0x00:"NOP",0x01:"DINT",0x02:"EINT",0x08:"ABS",0x09:"ZAC",
                0x0a:"ROVM",0x0b:"SOVM",0x0c:"CALA",0x0d:"RET",0x0e:"PAC",
                0x0f:"APAC",0x10:"SPAC",0x1c:"PUSH",0x1d:"POP"}.get(l & 0x1f,"7F?")
    return {0x60:"ADDH",0x61:"ADDS",0x62:"SUBH",0x63:"SUBS",0x64:"SUBC",
            0x65:"ZALH",0x66:"ZALS",0x67:"TBLR",0x68:"MAR",0x69:"DMOV",
            0x6a:"LT",0x6b:"LTD",0x6c:"LTA",0x6d:"MPY",0x6e:"LDPK",0x6f:"LDP",
            0x70:"LARK0",0x71:"LARK1",0x78:"XOR",0x79:"AND",0x7a:"OR",
            0x7b:"LST",0x7c:"SST",0x7d:"TBLW",0x7e:"LACK",
            0xf4:"BANZ",0xf5:"BV",0xf6:"BIOZ",0xf8:"CALL",0xf9:"BR",
            0xfa:"BLZ",0xfb:"BLEZ",0xfc:"BGZ",0xfd:"BGEZ",0xfe:"BNZ",
            0xff:"BZ"}.get(h, "ILLEGAL:%02x" % h)

ALL = ["ADD","SUB","LAC","SAR","LAR","IN","OUT","SACL","SACH","ADDH","ADDS",
       "SUBH","SUBS","SUBC","ZALH","ZALS","TBLR","MAR","DMOV","LT","LTD","LTA",
       "MPY","LDPK","LDP","LARK0","LARK1","XOR","AND","OR","LST","SST","TBLW",
       "LACK","MPYK","BANZ","BV","BIOZ","CALL","BR","BLZ","BLEZ","BGZ","BGEZ",
       "BNZ","BZ","NOP","DINT","EINT","ABS","ZAC","ROVM","SOVM","CALA","RET",
       "PAC","APAC","SPAC","PUSH","POP"]

hist  = collections.Counter()
indir = collections.Counter()
ovf   = 0
prev_ov = None
for fn in sys.argv[1:]:
    for ln in open(fn):
        f = ln.split()
        if len(f) < 8: continue
        w = int(f[1], 16)
        n = name(w)
        hist[n] += 1
        indir["ind" if (w & 0x80) else "dir"] += 1
        str_ = int(f[7], 16)
        if prev_ov is not None and not prev_ov and (str_ & 0x8000): ovf += 1
        prev_ov = bool(str_ & 0x8000)

total = sum(hist.values())
missing = [n for n in ALL if hist[n] == 0]
print("instructions executed : %d" % total)
print("distinct forms seen   : %d of %d" % (len(ALL)-len(missing), len(ALL)))
print("direct / indirect     : %d / %d" % (indir['dir'], indir['ind']))
print("overflow flag raised  : %d times" % ovf)
if missing:
    print("NOT EXERCISED        : " + ", ".join(missing))
else:
    print("every instruction form was exercised")
rare = sorted((c, n) for n, c in hist.items() if c < 200)
if rare:
    print("least exercised       : " + ", ".join("%s=%d" % (n, c) for c, n in rare[:12]))
