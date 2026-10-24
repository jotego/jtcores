#!/usr/bin/env python3
"""Generate deterministic timing vectors from the tracked HD6309 coverage tables."""
import argparse
import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_COVERAGE = ROOT / "coverage.md"
TARGET = 0x0140


def markdown_rows(path, start=None, stop=None):
    active = start is None
    for line in path.read_text().splitlines():
        if start and line.startswith(start):
            active = True
            continue
        if active and stop and line.startswith(stop):
            break
        if not active or not line.startswith("| "):
            continue
        c = [x.strip() for x in line.strip().strip("|").split("|")]
        yield c


def rows_from_markdown(path):
    rows = []
    for c in markdown_rows(path):
        if len(c) < 13:
            continue
        m = re.fullmatch(r"`\$([0-9A-Fa-f]{2})/\$([0-9A-Fa-f]{2})`", c[0])
        if not m:
            continue
        rows.append(dict(page=m.group(1).upper(), opcode=m.group(2).upper(), form=c[1].strip("`"),
                         mode=c[2].strip("`"), bytes=c[3], e=c[4], n=c[6], condition=c[10]))
    return rows


def indexed_rows(path):
    out = []
    for c in markdown_rows(path, "## Indexed postbyte detail", "## Remaining unverified coverage"):
        if len(c) < 6 or not c[1].startswith("`"):
            continue
        pattern = c[1].strip("`")
        vals = []
        for cell in (c[2], c[3]):
            inc, extra = (int(v.strip()) for v in cell.split("/"))
            vals.append((inc, extra))
        out.append(dict(form=c[0].strip("`"), pattern=pattern,
                        e_inc=vals[0][0], e_extra=vals[0][1],
                        n_inc=vals[1][0], n_extra=vals[1][1]))
    return out


def opcode_bytes(row):
    prefix = [] if row["page"] == "00" else [int(row["page"], 16)]
    return prefix + [int(row["opcode"], 16)]


def scalar_code(row):
    op = opcode_bytes(row)
    mode = row["mode"]
    if mode == "inherent":
        return op
    if mode == "immediate":
        size = int(row["bytes"]) - len(op)
        if size not in (1, 2):
            return None
        return op + ([1] if size == 1 else [0, 1])
    if mode == "direct":
        return op + ([1, 0] if row["form"] in {"AIM", "OIM", "EIM", "TIM"} else [0])
    if mode == "extended":
        return op + ([1, 0x20, 0] if row["form"] in {"AIM", "OIM", "EIM", "TIM"} else [0x20, 0])
    if mode == "indexed":
        if row["form"] in {"AIM", "OIM", "EIM", "TIM"}:
            return op + [1, 0x84]
        return op + [0x84]
    if mode == "immediate_postbyte":
        return op + [0, 1]
    return None


def flags_for(form, taken):
    aliases = {"BHS": "BCC", "BLO": "BCS", "LBHS": "LBCC", "LBLO": "LBCS"}
    name = aliases.get(form, form)
    def cond(cc):
        c, v, z, n = bool(cc & 1), bool(cc & 2), bool(cc & 4), bool(cc & 8)
        return {
            "BCC": not c, "BCS": c, "BHI": not c and not z, "BLS": c or z,
            "BEQ": z, "BNE": not z, "BVC": not v, "BVS": v,
            "BPL": not n, "BMI": n, "BGE": n == v, "BLT": n != v,
            "BGT": not z and n == v, "BLE": z or n != v,
        }[name.removeprefix("L")]
    for cc in range(16):
        if cond(cc) == taken:
            return cc
    raise ValueError(f"cannot produce CC for {form} taken={taken}")


def branch_cases(row, mode):
    base = int(row["e" if mode == "E" else "n"])
    form = row["form"]
    long = form.startswith("L")
    code = opcode_bytes(row)
    code += [0, 2] if long else [2]
    special = {"BRA": True, "LBRA": True, "BSR": True, "LBSR": True,
               "BRN": False, "LBRN": False}
    outcomes = [special[form]] if form in special else [False, True]
    ret = []
    for taken in outcomes:
        flags = 0 if form in special else flags_for(form, taken)
        # Atkinson note 11 says the taken-only sixth cycle applies to the 6809
        # only. Native HD6309 taken conditionals therefore use the 5-E base.
        known = True
        expected = base
        if long and taken and form not in ("LBRA", "LBSR"):
            if mode == "E":
                expected += 1
        close = TARGET + len(code) + (2 if taken else 0)
        ret.append((code, flags, expected, close, known, "taken" if taken else "not_taken"))
    return ret


POSTBYTE = {
    ",R": (0x84, []), "[,R]": (0x94, []),
    "n,R (-16..+15)": (0x01, []), "n,R (-128..+127)": (0x88, [0]),
    "[n,R]": None, "n,R": (0x89, [0, 0]),
    ",W": (0x8F, []), "[,W]": (0x90, []),
    "n,W": (0xAF, [0, 0]), "[n,W]": (0xB0, [0, 0]),
    ",W++": (0xCF, []), "[,W++]": (0xD0, []),
    ",--W": (0xEF, []), "[,--W]": (0xF0, []),
    "A,R": (0x86, []), "B,R": (0x85, []), "E,R": (0x87, []),
    "F,R": (0x8A, []), "W,R": (0x8E, []), "D,R": (0x8B, []),
    "[A,R]": (0x96, []), "[B,R]": (0x95, []), "[E,R]": (0x97, []),
    "[F,R]": (0x9A, []), "[W,R]": (0x9E, []), "[D,R]": (0x9B, []),
    ",R+": (0x80, []), ",R++": (0x81, []), "[,R++]": (0x91, []),
    ",-R": (0x82, []), ",--R": (0x83, []), "[,--R]": (0x93, []),
    "n,PCR": (0x8C, ["pcr8"]), "[n,PCR]": (0x9C, ["pcr8"]),
    "n,PCR16": (0x8D, ["pcr16"]), "[n,PCR]16": (0x9D, ["pcr16"]),
    "[n]": (0x9F, ["absolute"]),
}


def indexed_encoding(row, post):
    form, pattern = post["form"], post["pattern"]
    if pattern == "1rr11000":
        pb, extra = 0x98, [0]
    elif pattern == "1rr11001":
        pb, extra = 0x99, [0, 0]
    elif pattern == "1rrnnnnn":
        pb, extra = 0x01, []
    elif pattern == "1xx01101":
        pb, extra = 0x8d, ["pcr16"]
    elif pattern == "1xx11101":
        pb, extra = 0x9d, ["pcr16"]
    else:
        item = POSTBYTE.get(form)
        if item is None:
            raise ValueError(f"no postbyte encoding for {form}/{pattern}")
        pb, extra = item
    prefix = opcode_bytes(row)
    code = prefix[:]
    if row["form"] in {"AIM", "OIM", "EIM", "TIM"}:
        code.append(1)  # memory-immediate operand precedes the index postbyte
    code.append(pb)
    if extra == ["absolute"]:
        code.extend([0x01, 0x38]) # absolute-indirect pointer at safe data word
    elif extra == ["pcr8"]:
        pc_after = TARGET + len(code) + 1
        disp = 0x0138 - pc_after
        if not -128 <= disp <= 127:
            raise ValueError("PCR8 test displacement out of range")
        code.append(disp & 0xff)
    elif extra == ["pcr16"]:
        pc_after = TARGET + len(code) + 2
        disp = (0x0138 - pc_after) & 0xffff
        code.extend([disp >> 8, disp & 0xff])
    else:
        code.extend(extra)
    return code


def add_case(out, row, mode, code, flags, expected, expected_close, known, scenario,
             postbyte_form="", postbyte_pattern="", bucket="opcode"):
    if len(code) > 16:
        raise ValueError("instruction encoding exceeds vector width")
    out.append(dict(row=row, mode=mode, code=code, flags=flags, expected=expected,
                    close=expected_close, known=known, scenario=scenario,
                    postbyte_form=postbyte_form, postbyte_pattern=postbyte_pattern, bucket=bucket))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--coverage", type=Path, default=DEFAULT_COVERAGE)
    ap.add_argument("--vectors", type=Path, required=True)
    ap.add_argument("--excluded", type=Path, required=True)
    ap.add_argument("--cases", type=Path)
    args = ap.parse_args()
    rows = rows_from_markdown(args.coverage)
    posts = indexed_rows(args.coverage)
    eligible, excluded = [], []
    for row in rows:
        for mode in ("E", "N"):
            timing = row["e" if mode == "E" else "n"]
            key = f'{row["page"]}:{row["opcode"]} {row["form"]} {row["mode"]} {mode}'
            if row["mode"] == "relative":
                for code, flags, expected, close, known, scenario in branch_cases(row, mode):
                    add_case(eligible, row, mode, code, flags, expected, close, known, scenario)
                continue
            if row["mode"] == "register_postbyte" and row["page"] == "10" and row["form"] in {"ADCR", "ADDR", "ANDR", "CMPR", "EORR", "ORR", "SBCR", "SUBR"}:
                add_case(eligible, row, mode, opcode_bytes(row) + [0xEF], 0, int(timing),
                         TARGET + (3 if row["page"] == "10" else 2), True, "E,F", bucket="register_postbyte")
                continue
            if row["form"] in {"DIVD", "DIVQ"}:
                excluded.append((key, "operand-dependent divide timing and divide/overflow exception conditions")); continue
            if row["mode"] == "indexed":
                if not re.fullmatch(r"\d+\+?", timing):
                    excluded.append((key, "missing/conditional indexed base timing")); continue
                for post in posts:
                    code = indexed_encoding(row, post)
                    increment = post["e_inc" if mode == "E" else "n_inc"]
                    add_case(eligible, row, mode, code, 0, int(timing.rstrip("+")) + increment,
                             -1, True, "indexed", post["form"], post["pattern"], "indexed_postbyte")
                continue
            if not re.fullmatch(r"\d+", timing):
                excluded.append((key, "non-scalar timing: " + timing)); continue
            if row["mode"] in ("register_postbyte", "register_mask_postbyte") or row["form"].startswith(("JMP", "JSR", "RTI", "RTS", "SWI", "CWAI", "SYNC", "TFM", "DIVD", "DIVQ")):
                excluded.append((key, "requires specialized control/operand setup")); continue
            code = scalar_code(row)
            if code is None:
                excluded.append((key, "unsupported operand constructor: " + row["mode"])); continue
            if row["mode"] == "immediate_postbyte" and row["form"] in ("BAND", "BIAND", "BEOR", "BIEOR", "BOR", "BIOR", "LDBT", "STBT"):
                excluded.append((key, "bit-operation postbyte/data setup not represented")); continue
            add_case(eligible, row, mode, code, 0, int(timing), TARGET + len(code), True,
                     "scalar", bucket="opcode")

    args.vectors.parent.mkdir(parents=True, exist_ok=True)
    vector_path = args.vectors
    case_path = args.cases or args.vectors.with_suffix(".cases.csv")
    with vector_path.open("w") as vf, case_path.open("w", newline="") as cf:
        w = csv.writer(cf)
        w.writerow(("case_id", "bucket", "page", "opcode", "form", "addressing", "mode",
                    "expected_cycles", "oracle_known", "expected_close", "scenario", "postbyte_form", "postbyte_pattern"))
        for i, item in enumerate(eligible, 1):
            row=item["row"]; code=item["code"]+[0x12]*(16-len(item["code"]))
            vf.write(f"{i} {TARGET:04x} {item['close'] & 0xffff:04x} {item['flags']:02x} {1 if item['mode']=='N' else 0} {item['expected']} "
                     + " ".join(f"{b:02x}" for b in code) + "\n")
            w.writerow((i,item["bucket"],row["page"],row["opcode"],row["form"],row["mode"],item["mode"],
                        item["expected"],int(item["known"]),f'{item["close"] & 0xffff:04x}',item["scenario"],
                        item["postbyte_form"],item["postbyte_pattern"]))
    with args.excluded.open("w", newline="") as f:
        w=csv.writer(f); w.writerow(("case","reason")); w.writerows(excluded)
    print(f"Generated {len(eligible)} vectors: {len(posts)} indexed postbytes × {sum(r['mode']=='indexed' for r in rows)} indexed forms × 2 modes; excluded {len(excluded)} cases")


if __name__ == "__main__":
    main()
