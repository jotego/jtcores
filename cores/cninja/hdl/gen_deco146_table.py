#!/usr/bin/env python3
"""Generate jtcninja_deco146_table.hex from MAME's port146_table[] (deco146.cpp).

The DECO 104 permutation is NIBBLE-structured: MAME stores each entry as
  { src, { TOK0, TOK1, TOK2, TOK3 }, use_xor, use_nand }
where TOKp describes INPUT nibble p -> a source OUTPUT nibble (NIB0..3) rotated
by 0..3, or BLANK_ (input nibble contributes nothing). We pack that NATIVE form
directly (36 bits/entry) instead of expanding it to 16x5-bit weights (96 bits):

  [ 4: 0]  token0 : { blank[4], rot[3:2], sel[1:0] }   (input nibble 0)
  [ 9: 5]  token1                                        (input nibble 1)
  [14:10]  token2                                        (input nibble 2)
  [19:15]  token3                                        (input nibble 3)
  [20]     src_is_port
  [22:21]  src_port (0=INPUTS/A, 1=SYSTEM/B, 2=DSW/C)
  [30:23]  src_off  (rambank byte offset; rambank index = src_off>>1)
  [31]     use_xor
  [32]     use_nand
  [35:33]  0
See jtcninja_deco146.v for the matching unpack + nibble-rotate reorder().
"""
import re, os

# token name -> (output-nibble sel, rotation, blank) ; rotation r means
# weights[4p+j] = 4*sel + ((j+r) & 3)  (left-rotate the nibble by r)
def parse_tok(t):
    if t == "BLANK_":
        return 0, 0, 1
    m = re.fullmatch(r"NIB([0-3])(?:__|R([1-3]))", t)
    assert m, "bad token %r" % t
    sel = int(m.group(1))
    rot = int(m.group(2)) if m.group(2) else 0
    return sel, rot, 0

# reference weights (old expansion) for a token, to prove the packing is lossless
def tok_weights(t):
    sel, rot, blank = parse_tok(t)
    if blank:
        return [31, 31, 31, 31]
    return [4 * sel + ((j + rot) & 3) for j in range(4)]

PORT = {"INPUT_PORT_A": 0, "INPUT_PORT_B": 1, "INPUT_PORT_C": 2}

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "doc", "deco146.cpp")
OUT = os.path.join(HERE, "jtcninja_deco146_table.hex")

row = re.compile(
    r"/\*\s*0x([0-9a-fA-F]+)\s*\*/\s*\{\s*([^,]+?)\s*,\s*\{([^}]*)\}\s*,\s*(\d)\s*,\s*(\d)\s*\}")

entries = {}
for m in row.finditer(open(SRC).read()):
    off = int(m.group(1), 16)
    val = m.group(2).strip()
    toks = [t.strip() for t in m.group(3).split(",") if t.strip()]
    use_xor, use_nand = int(m.group(4)), int(m.group(5))
    assert len(toks) == 4, (off, toks)

    if val in PORT:
        is_port, port, src_off = 1, PORT[val], 0
    else:
        is_port, port, src_off = 0, 0, int(val, 16)

    word = 0
    for p, t in enumerate(toks):
        sel, rot, blank = parse_tok(t)
        field = (sel & 3) | ((rot & 3) << 2) | (blank << 4)
        word |= field << (5 * p)
    word |= is_port << 20
    word |= (port & 3) << 21
    word |= (src_off & 0xff) << 23
    word |= use_xor << 31
    word |= use_nand << 32
    entries[off >> 1] = word

assert len(entries) == 1024, "expected 1024 entries, got %d" % len(entries)
with open(OUT, "w") as f:
    for idx in range(1024):
        f.write("%09x\n" % entries[idx])   # 36 bits = 9 hex nibbles
print("wrote %s (%d entries, 36 bits each)" % (OUT, len(entries)))
