#!/usr/bin/env python3
"""Generate the reproducible, manually auditable timing vector inventory."""

import csv
from pathlib import Path

HERE = Path(__file__).resolve().parent
rows = []


def add(name, code, cycles, source, group="fixed"):
    code = tuple(code)
    if not 1 <= len(code) <= 4:
        raise ValueError((name, code))
    rows.append((len(rows), name, " ".join(f"{b:02X}" for b in code), cycles, group, source, code))


# Zilog UM008011-0816 instruction reference. The source column names the
# printed page containing the timing entry; pages 42-55 provide opcode maps.
# These vectors use register-indirect addresses initialized by the testbench.
for dst in range(8):
    for src in range(8):
        op = 0x40 | (dst << 3) | src
        if op == 0x76:  # HALT uses its own repeated-fetch observation.
            continue
        page = "p. 79" if dst == 6 else ("p. 74" if src == 6 else "p. 71")
        add(f"LD r{dst},r{src}", [op], 7 if 6 in (dst, src) else 4, page)

for r in range(8):
    op = 0x06 | (r << 3)
    add(f"LD r{r},n", [op, 0xA5], 10 if r == 6 else 7, "pp. 72, 85")

for op, name, cycles, page in [
    (0x02, "LD (BC),A", 7, "p. 91"), (0x12, "LD (DE),A", 7, "p. 92"),
    (0x0A, "LD A,(BC)", 7, "p. 88"), (0x1A, "LD A,(DE)", 7, "p. 89"),
    (0x22, "LD (nn),HL", 16, "p. 107"), (0x2A, "LD HL,(nn)", 16, "p. 102"),
    (0x32, "LD (nn),A", 13, "p. 93"), (0x3A, "LD A,(nn)", 13, "p. 90"),
]:
    code = [op, 0x00, 0x52] if op in (0x22, 0x2A, 0x32, 0x3A) else [op]
    add(name, code, cycles, page)

for pair, page in enumerate(("p. 99", "p. 99", "p. 99", "p. 99")):
    add(f"LD rp{pair},nn", [0x01 | (pair << 4), 0x34, 0x12], 10, page)
for op, name in ((0x09, "BC"), (0x19, "DE"), (0x29, "HL"), (0x39, "SP")):
    add(f"ADD HL,{name}", [op], 11, "p. 188")

for op in (0x03, 0x13, 0x23, 0x33, 0x0B, 0x1B, 0x2B, 0x3B):
    add(f"INC/DEC rp ${op:02X}", [op], 6, "pp. 198-203")
for op in (0x04, 0x0C, 0x14, 0x1C, 0x24, 0x2C, 0x3C,
           0x05, 0x0D, 0x15, 0x1D, 0x25, 0x2D, 0x3D):
    add(f"INC/DEC r ${op:02X}", [op], 4, "pp. 165-170")
for op in (0x34, 0x35):
    add(f"INC/DEC (HL) ${op:02X}", [op], 11, "pp. 167,170")

for alu in range(8):
    alu_page = (145, 151, 153, 155, 157, 161, 159, 163)[alu]
    for r in range(8):
        page = (148 if alu == 0 else alu_page) if r == 6 else alu_page
        add(f"ALU{alu} r{r}", [0x80 | (alu << 3) | r], 7 if r == 6 else 4, f"p. {page}")
    immediate_page = 147 if alu == 0 else alu_page
    add(f"ALU{alu} n", [0xC6 | (alu << 3), 0x5A], 7, f"p. {immediate_page}")

# Fixed base instructions that do not alter the fetch path. Conditional and
# unconditional flow instructions are exercised separately with all outcomes.
for op, name, cycles, page in [
    (0x00, "NOP", 4, "p. 180"), (0x07, "RLCA", 4, "p. 205"),
    (0x0F, "RRCA", 4, "p. 209"), (0x17, "RLA", 4, "p. 207"),
    (0x1F, "RRA", 4, "p. 211"), (0x27, "DAA", 4, "p. 173"),
    (0x2F, "CPL", 4, "p. 175"), (0x37, "SCF", 4, "p. 179"),
    (0x3F, "CCF", 4, "p. 178"), (0x08, "EX AF,AF'", 4, "p. 125"),
    (0xD9, "EXX", 4, "p. 126"), (0xEB, "EX DE,HL", 4, "p. 124"),
    (0xF3, "DI", 4, "p. 182"), (0xFB, "EI", 4, "p. 183"),
    (0xE3, "EX (SP),HL", 19, "p. 127"), (0xF9, "LD SP,HL", 6, "p. 112"),
    (0xE9, "JP (HL)", 4, "p. 275"),
]:
    if op == 0xE9:
        continue  # memory/flow forms are measured in directed cases below
    add(name, [op], cycles, page)

for op, name, cycles, page in [
    (0xC5, "PUSH BC", 11, "p. 115"), (0xD5, "PUSH DE", 11, "p. 115"),
    (0xE5, "PUSH HL", 11, "p. 115"), (0xF5, "PUSH AF", 11, "p. 115"),
    (0xC1, "POP BC", 10, "p. 119"), (0xD1, "POP DE", 10, "p. 119"),
    (0xE1, "POP HL", 10, "p. 119"), (0xF1, "POP AF", 10, "p. 119"),
    (0xD3, "OUT (n),A", 11, "p. 306"), (0xDB, "IN A,(n)", 11, "p. 295"),
]:
    code = [op, 0x02] if op in (0xD3, 0xDB) else [op]
    add(name, code, cycles, page, "directed" if op in (0xC1, 0xD1, 0xE1, 0xF1, 0xE3) else "fixed")
add("HALT", [0x76], 4, "p. 181", "halt")

# Unconditional control-transfer instructions and every documented condition
# outcome are executed by the directed control-flow matrix.
for op, name, cycles, page in ((0xC3, "JP nn", 10, "p. 262"),
                               (0xCD, "CALL nn", 17, "p. 281"),
                               (0xC9, "RET", 10, "p. 285"),
                               (0xE9, "JP (HL)", 4, "p. 275")):
    add(name, [op, 0x30, 0x00] if op in (0xC3, 0xCD) else [op], cycles, page, "flow")
add("JR e", [0x18, 0x1E], 12, "p. 265", "flow")
for rst in range(8):
    add(f"RST ${rst*8:02X}", [0xC7+(rst<<3)], 11, "p. 292", "flow")
for family, base, page in (("JR", 0x20, "pp. 267-273"),
                           ("JP", 0xC2, "p. 263"),
                           ("CALL", 0xC4, "p. 283"),
                           ("RET", 0xC0, "p. 286")):
    conditions = range(4) if family == "JR" else range(8)
    for cc in conditions:
        for taken in (0, 1):
            op = base + (cc << 3)
            if family == "JR":
                code = [op, 0x1E]
                cycles = 12 if taken else 7
            elif family == "JP":
                code = [op, 0x30, 0x00]
                cycles = 10
            elif family == "CALL":
                code = [op, 0x30, 0x00]
                cycles = 17 if taken else 10
            else:
                code = [op]
                cycles = 11 if taken else 5
            add(f"{family} cc{cc} taken={taken}", code, cycles, page, "branch")
for initial_b, taken, cycles in ((0, 1, 13), (1, 0, 8), (2, 1, 13)):
    add(f"DJNZ B={initial_b}", [0x10, 0x0E], cycles, "p. 278", "djnz")

# CB page: UM0080 pp. 218-257. All 256 documented register/memory encodings.
for op in range(256):
    family, reg = op >> 6, op & 7
    cycles = 12 if family == 1 and reg == 6 else (15 if reg == 6 else 8)
    # SLL is a silicon extension and absent from Zilog's documented set.
    group = "alias" if family == 0 and (op >> 3) & 7 == 6 else "cb"
    source = "undocumented SLL" if group == "alias" else "UM0080 instruction reference"
    add(f"CB ${op:02X}", [0xCB, op], cycles, source if group == "alias" else "pp. 213-259", group)

# ED documented operations; aliases and undefined ED slots are listed in a
# separate manifest section by the directed audit, not silently treated as
# documented Zilog encodings.
for op in (0x40, 0x48, 0x50, 0x58, 0x60, 0x68, 0x70, 0x78):
    group = "alias" if op == 0x70 else "fixed"
    add(f"IN r,(C) ${op:02X}", [0xED, op], 12,
        "undocumented IN (C)" if group == "alias" else "p. 296", group)
for op in (0x41, 0x49, 0x51, 0x59, 0x61, 0x69, 0x71, 0x79):
    group = "alias" if op == 0x71 else "fixed"
    add(f"OUT (C),r ${op:02X}", [0xED, op], 12,
        "undocumented OUT (C),0" if group == "alias" else "p. 307", group)
for op in (0x42, 0x52, 0x62, 0x72, 0x4A, 0x5A, 0x6A, 0x7A):
    add(f"ADC/SBC HL,rp ${op:02X}", [0xED, op], 15, "pp. 190-192")
for op in (0x43, 0x53, 0x63, 0x73, 0x4B, 0x5B, 0x6B, 0x7B):
    add(f"LD (nn)/rr ${op:02X}", [0xED, op, 0x00, 0x52], 20, "pp. 103-108")
for op, name, cycles, page in [
    (0x44, "NEG", 8, "p. 176"), (0x45, "RETN", 14, "p. 290"),
    (0x4D, "RETI", 14, "p. 288"), (0x46, "IM 0", 8, "p. 184"),
    (0x56, "IM 1", 8, "p. 185"), (0x5E, "IM 2", 8, "p. 186"),
    (0x47, "LD I,A", 9, "p. 96"), (0x4F, "LD R,A", 9, "p. 97"),
    (0x57, "LD A,I", 9, "p. 94"), (0x5F, "LD A,R", 9, "p. 95"),
    (0x67, "RRD", 18, "p. 240"), (0x6F, "RLD", 18, "p. 238"),
    (0xA0, "LDI", 16, "p. 130"), (0xA8, "LDD", 16, "p. 134"),
    (0xA1, "CPI", 16, "p. 138"), (0xA9, "CPD", 16, "p. 141"),
    (0xA2, "INI", 16, "p. 298"), (0xAA, "IND", 16, "p. 302"),
    (0xA3, "OUTI", 16, "p. 309"), (0xAB, "OUTD", 16, "p. 313"),
]:
    # RETN/RETI and the single-iteration block primitives need a prepared
    # stack/counter and are recorded but run by directed stateful cases.
    group = "directed" if op in (0x45, 0x4D, 0xA0, 0xA8, 0xA1, 0xA9, 0xA2, 0xAA, 0xA3, 0xAB) else "fixed"
    add(name, [0xED, op], cycles, page, group)

# Indexed-CB forms: UM0080 pp. 217-257 documents the IX/IY displacement
# operations. BIT only reads memory; rotate/shift/RES/SET also write it.
for prefix, index in ((0xDD, "IX"), (0xFD, "IY")):
    for op in range(256):
        group, reg = op >> 6, op & 7
        cycles = 20 if group == 1 else 23
        # Documented indexed-CB operations target memory; register copies on
        # rotate/RES/SET are undocumented, and BIT's low field is ignored.
        documented = reg == 6 and op != 0x36  # SLL remains undocumented
        if group == 0:
            pages = ((217,219),(224,226),(221,223),(227,229),
                     (230,232),(233,235),(0,0),(236,237))[(op >> 3) & 7]
            source = f"pp. {pages[0]}-{pages[1]}" if documented else "undocumented indexed SLL"
        elif group == 1:
            source = "p. 247 (IX) / p. 249 (IY)"
        elif group == 2:
            source = "pp. 259-260"
        else:
            source = "p. 255 (IX) / p. 257 (IY)"
        add(f"{index}CB ${op:02X}", [prefix, 0xCB, 0x10, op], cycles,
            source if documented else "undocumented indexed-CB alias",
            "indexed_cb" if documented else "alias")

# Prefix forms documented by UM0080's IX/IY instruction entries and tables.
for prefix, index in ((0xDD, "IX"), (0xFD, "IY")):
    for op in (0x21, 0x22, 0x2A):
        if op == 0x21:
            add(f"LD {index},nn", [prefix, op, 0x34, 0x12], 14, "pp. 100-106")
        elif op == 0x22:
            add(f"LD (nn),{index}", [prefix, op, 0x00, 0x52], 20, "pp. 110-111")
        else:
            add(f"LD {index},(nn)", [prefix, op, 0x00, 0x52], 20, "pp. 105-106")
    for op, cycles, page in ((0x23, 10, "p. 199"), (0x2B, 10, "p. 202"),
                             (0x09, 15, "p. 194"), (0x19, 15, "p. 194"),
                             (0x29, 15, "p. 194"), (0x39, 15, "p. 194"),
                             (0xE5, 15, "p. 117"), (0xE1, 14, "p. 121"),
                             (0xE9, 8, "p. 276"), (0xF9, 10, "p. 113"),
                             (0xE3, 23, "p. 128")):
        if index == "IY":
            page = {0x23:"p. 200",0x2B:"p. 203",0x09:"p. 196",0x19:"p. 196",
                    0x29:"p. 196",0x39:"p. 196",0xE5:"p. 118",0xE1:"p. 122",
                    0xE9:"p. 277",0xF9:"p. 114",0xE3:"p. 129"}[op]
        add(f"{index} form ${op:02X}", [prefix, op], cycles, page,
            "directed" if op in (0xE9, 0xE3) else "fixed")
    for op in range(0x40, 0x80):
        dst, src = (op >> 3) & 7, op & 7
        if op == 0x76:
            continue
        if 6 in (dst, src):
            cycles = 19
            code = [prefix, op, 0x10]
        else:
            cycles = 8
            code = [prefix, op]
        # Only the documented indexed-memory substitutions remain IX/IY
        # instructions here. All register-register forms are ignored-prefix
        # aliases in Zilog's documented inventory.
        documented = 6 in (dst, src)
        group = "fixed" if documented else "alias"
        if not documented:
            source = "undocumented ignored-prefix register form"
        elif src == 6:
            source = "p. 75 (IX) / p. 77 (IY)"
        else:
            source = "p. 81 (IX) / p. 83 (IY)"
        add(f"{index} LD ${op:02X}", code, cycles, source, group)
    for op in range(0x80, 0xC0):
        src = op & 7
        if src == 6:
            add(f"{index} ALU ${op:02X}", [prefix, op, 0x10], 19, "pp. 149-164")
        elif src in (4, 5):
            add(f"{index} ALU ${op:02X}", [prefix, op], 8,
                "undocumented IXH/IXL arithmetic form", "alias")
        else:
            add(f"{index} ALU alias ${op:02X}", [prefix, op], 8, "ignored-prefix alias", "alias")
    for op, cycles in ((0x24, 8), (0x25, 8), (0x2C, 8), (0x2D, 8),
                       (0x26, 11), (0x2E, 11), (0x34, 23), (0x35, 23)):
        code = [prefix, op, 0x10] if op in (0x34, 0x35) else ([prefix, op, 0x5A] if op in (0x26, 0x2E) else [prefix, op])
        group = "alias" if op in (0x24,0x25,0x2c,0x2d,0x26,0x2e) else "fixed"
        if op == 0x34:
            page = "p. 168" if index == "IX" else "p. 169"
        elif op == 0x35:
            page = "p. 170"
        elif op == 0x23:
            page = "p. 199" if index == "IX" else "p. 200"
        else:
            page = "p. 202" if index == "IX" else "p. 203"
        add(f"{index} INC/DEC ${op:02X}", code, cycles,
            "undocumented IXH/IXL form" if group == "alias" else page, group)
    add(f"LD ({index}+d),n", [prefix, 0x36, 0x10, 0x5A], 19,
        "p. 86" if index == "IX" else "p. 87")

# Repeating instruction forms: the complete finish/continue paths are a
# separate directed state machine so each case asserts post-state too.
for op, name, terminal, repeat in (
    (0xB0, "LDIR", 16, 21), (0xB8, "LDDR", 16, 21),
    (0xB1, "CPIR", 16, 21), (0xB9, "CPDR", 16, 21),
    (0xB2, "INIR", 16, 21), (0xBA, "INDR", 16, 21),
    (0xB3, "OTIR", 16, 21), (0xBB, "OTDR", 16, 21),
):
    page = {0xB0:132,0xB8:136,0xB1:139,0xB9:142,0xB2:300,0xBA:304,0xB3:311,0xBB:315}[op]
    add(f"{name} terminal", [0xED, op], terminal, f"p. {page}", "repeat")
    add(f"{name} continue", [0xED, op], repeat, f"p. {page}", "repeat")
for op, name in ((0xB1, "CPIR"), (0xB9, "CPDR")):
    add(f"{name} equality exit", [0xED, op], 16, "p. 139" if op == 0xB1 else "p. 142", "repeat")

for op, name in ((0xA0, "LDI"), (0xA8, "LDD"), (0xA1, "CPI"),
                 (0xA9, "CPD"), (0xA2, "INI"), (0xAA, "IND"),
                 (0xA3, "OUTI"), (0xAB, "OUTD")):
    add(name, [0xED, op], 16, "pp. 130-315", "single_block")

with (HERE / "manifest.csv").open("w", newline="") as f:
    w = csv.writer(f)
    w.writerow(("case_id", "instruction", "bytes", "tstates", "run_group",
                "oracle_status", "UM0080 printed page or alias rationale"))
    for case_id, name, encoded, cycles, group, source, _ in rows:
        status = "undocumented/alias supplemental" if group == "alias" else "documented"
        w.writerow((case_id, name, encoded, cycles, group, status, source))

with (HERE / "vectors.hex").open("w") as f:
    words = []
    vector_count = 0
    alias_count = 0
    for _, name, _, cycles, group, _, code in rows:
        directed_vector = group == "directed" and name not in (
            "RETN", "RETI", "JP (HL)", "IX form $E9", "IY form $E9")
        if group not in ("fixed", "alias", "cb", "indexed_cb") and not directed_vector:
            continue
        vector_count += 1
        alias_count += group == "alias"
        padded = list(code) + [0] * (4 - len(code))
        words.extend((len(code), cycles, *padded))
    words.append(0)
    words.extend([0] * (8192 - len(words)))
    for value in words:
        f.write(f"{value:02X}\n")

print(f"{vector_count} executed vector encodings ({vector_count-alias_count} documented, {alias_count} alias); {len(rows)} manifest rows")
