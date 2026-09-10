#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Marc Emmerson
# SPDX-License-Identifier: GPL-3.0-or-later
"""A very small TMS320C10 assembler: enough to write protocol test programs.

Two passes over a list of (mnemonic, args) tuples with labels as bare strings
ending in ':'. Emits one hex word per line, padded to 4096 words.
"""
import sys

TWO_WORD = {"B", "CALL", "BANZ", "BV", "BIOZ", "BLZ", "BLEZ", "BGZ", "BGEZ",
            "BNZ", "BZ"}
BR_OP = {"B": 0xF900, "CALL": 0xF800, "BANZ": 0xF400, "BV": 0xF500,
         "BIOZ": 0xF600, "BLZ": 0xFA00, "BLEZ": 0xFB00, "BGZ": 0xFC00,
         "BGEZ": 0xFD00, "BNZ": 0xFE00, "BZ": 0xFF00}
SIMPLE = {"NOP": 0x7F80, "DINT": 0x7F81, "EINT": 0x7F82, "ABS": 0x7F88,
          "ZAC": 0x7F89, "ROVM": 0x7F8A, "SOVM": 0x7F8B, "CALA": 0x7F8C,
          "RET": 0x7F8D, "PAC": 0x7F8E, "APAC": 0x7F8F, "SPAC": 0x7F90,
          "PUSH": 0x7F9C, "POP": 0x7F9D}

def assemble(src, size=4096):
    # pass 1: addresses
    pc, labels = 0, {}
    for item in src:
        if isinstance(item, str) and item.endswith(":"):
            labels[item[:-1]] = pc
            continue
        m = item[0].upper()
        pc += 2 if m in TWO_WORD else 1
    # pass 2: encode
    out, pc = [], 0
    for item in src:
        if isinstance(item, str) and item.endswith(":"):
            continue
        m, a = item[0].upper(), item[1:]
        if m in BR_OP:
            tgt = labels[a[0]] if isinstance(a[0], str) else a[0]
            out += [BR_OP[m], tgt]
        elif m in SIMPLE:
            out.append(SIMPLE[m])
        elif m == "LACK":  out.append(0x7E00 | (a[0] & 0xff))
        elif m == "SACL":  out.append(0x5000 | (a[0] & 0xff))
        elif m == "SACH":  out.append(0x5800 | ((a[1] & 7) << 8) | (a[0] & 0xff))
        elif m == "LAC":   out.append(0x2000 | ((a[1] & 0xf) << 8) | (a[0] & 0xff))
        elif m == "ADD":   out.append(0x0000 | ((a[1] & 0xf) << 8) | (a[0] & 0xff))
        elif m == "SUB":   out.append(0x1000 | ((a[1] & 0xf) << 8) | (a[0] & 0xff))
        elif m == "ADDS":  out.append(0x6100 | (a[0] & 0xff))
        elif m == "SUBS":  out.append(0x6300 | (a[0] & 0xff))
        elif m == "ADDH":  out.append(0x6000 | (a[0] & 0xff))
        elif m == "ZALS":  out.append(0x6600 | (a[0] & 0xff))
        elif m == "ZALH":  out.append(0x6500 | (a[0] & 0xff))
        elif m == "AND":   out.append(0x7900 | (a[0] & 0xff))
        elif m == "OR":    out.append(0x7A00 | (a[0] & 0xff))
        elif m == "XOR":   out.append(0x7800 | (a[0] & 0xff))
        elif m == "LT":    out.append(0x6A00 | (a[0] & 0xff))
        elif m == "LTA":   out.append(0x6C00 | (a[0] & 0xff))
        elif m == "MPY":   out.append(0x6D00 | (a[0] & 0xff))
        elif m == "MPYK":  out.append(0x8000 | (a[0] & 0x1fff))
        elif m == "OUT":   out.append(0x4800 | ((a[1] & 7) << 8) | (a[0] & 0xff))
        elif m == "IN":    out.append(0x4000 | ((a[1] & 7) << 8) | (a[0] & 0xff))
        elif m == "LARK":  out.append(0x7000 | ((a[0] & 1) << 8) | (a[1] & 0xff))
        elif m == "LARP":  out.append(0x6880 | (a[0] & 1))
        elif m == "LAR":   out.append(0x3800 | ((a[0] & 1) << 8) | (a[1] & 0xff))
        elif m == "SAR":   out.append(0x3000 | ((a[0] & 1) << 8) | (a[1] & 0xff))
        elif m == "MAR":   out.append(0x6800 | (a[0] & 0xff))
        elif m == "LDPK":  out.append(0x6E00 | (a[0] & 1))
        elif m == "DMOV":  out.append(0x6900 | (a[0] & 0xff))
        elif m == "SST":   out.append(0x7C00 | (a[0] & 0xff))
        elif m == "LST":   out.append(0x7B00 | (a[0] & 0xff))
        else:
            raise SystemExit("asm32010: unknown mnemonic %r" % m)
        pc = len(out)
    if len(out) > size:
        raise SystemExit("asm32010: program too long (%d words)" % len(out))
    out += [0x7F80] * (size - len(out))      # pad with NOP
    return out

def write_hex(words, path):
    with open(path, "w") as f:
        for w in words:
            f.write("%04x\n" % (w & 0xffff))
