#!/usr/bin/env python3
"""Normalize T80 suite CSVs and compare public replay output samples."""

import argparse
import csv
import hashlib
import json
import random
import sys
from pathlib import Path

INPUTS = ["RESET_n", "CEN", "WAIT_n", "INT_n", "NMI_n", "BUSRQ_n", "OUT0", "DI"]


def expand_hex_digit(digit):
    if digit in "xz":
        return digit.upper() * 4
    return f"{int(digit, 16):04b}"


def make_parser():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    prep = sub.add_parser("prepare")
    prep.add_argument("--out", required=True, type=Path)
    prep.add_argument("--seed", type=lambda x: int(x, 0), default=150)
    prep.add_argument("--cycles", type=int, default=2000)
    prep.add_argument("--trace", action="append", default=[])
    cmp = sub.add_parser("compare")
    cmp.add_argument("--run", required=True, type=Path)
    cmp.add_argument("--checked", required=True, type=Path)
    cmp.add_argument("--fresh", required=True, type=Path)
    cmp.add_argument("--native", required=True, type=Path)
    neg = sub.add_parser("negative")
    neg.add_argument("--run", required=True, type=Path)
    neg.add_argument("--reference", required=True, type=Path)
    neg.add_argument("--mutant", required=True, type=Path)
    return parser


def parse_logic(text, width, source, rownum):
    value = text.strip()
    if len(value) != width or any(ch not in "01" for ch in value):
        raise ValueError(f"{source}:{rownum}: expected {width} defined logic bits, got {value!r}")
    return value


def read_traces(paths):
    all_rows = []
    names = []
    for trace_path in paths:
        path = Path(trace_path)
        with path.open(newline="") as stream:
            reader = csv.DictReader(stream)
            if not reader.fieldnames:
                raise ValueError(f"{path}: empty trace")
            missing = [field for field in INPUTS if field not in reader.fieldnames]
            if missing:
                raise ValueError(f"{path}: trace lacks columns {missing}")
            before = len(all_rows)
            cen_edges = 0
            reset_intervals = 0
            reset_low = False
            for rownum, row in enumerate(reader, start=2):
                bits = "".join(parse_logic(row[name], 1, path, rownum) for name in INPUTS[:7])
                cen_edges += bits[1] == "1"
                if bits[0] == "0" and not reset_low:
                    reset_intervals += 1
                reset_low = bits[0] == "0"
                di = row["DI"].strip().lower().removeprefix("0x")
                if len(di) == 0 or len(di) > 2:
                    raise ValueError(f"{path}:{rownum}: DI must fit in one byte, got {row['DI']!r}")
                di = di.zfill(2)
                if any(ch not in "0123456789abcdefxz" for ch in di):
                    raise ValueError(f"{path}:{rownum}: invalid four-state DI {row['DI']!r}")
                # High byte is DI; bits [7:1] are the seven scalar inputs.
                low = int(bits, 2) << 1
                all_rows.append("".join(expand_hex_digit(ch) for ch in di) + f"{low:08b}")
            names.append({"path": str(path.resolve()), "first_row": before,
                          "last_row": len(all_rows) - 1, "rows": len(all_rows) - before,
                          "cen_edges": cen_edges, "reset_intervals": reset_intervals,
                          "header": reader.fieldnames,
                          "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    return all_rows, names


def stress_rows(seed, cycles):
    if cycles < 16:
        raise ValueError("stress --cycles must be at least 16")
    rng = random.Random(seed)
    rows = []
    for i in range(cycles):
        reset_n = 0 if i < 8 or i in (cycles // 2, cycles // 2 + 1) else 1
        cen = 1 if i < 12 or i in (cycles // 2, cycles // 2 + 1) else (0 if i % 19 in (5, 6, 7) or i % 53 == 0 else 1)
        wait_n = 0 if i % 31 in (11, 12) else 1
        int_n = 0 if i % 211 in (47, 48, 49) else 1
        nmi_n = 0 if i % 307 == 89 else 1
        busrq_n = 0 if i % 173 in (131, 132, 133, 134) else 1
        out0 = (i // 7) & 1
        # Keep CPU instruction fetches deterministic but vary the byte stream
        # among ordinary defined operations; random opcodes can enter prefix
        # corner cases outside the intended equivalence stimulus.
        di = (0x00, 0x3E, 0xA5, 0xC6, 0x18, 0x01)[(i // 4 + rng.randrange(6)) % 6]
        low = (reset_n << 7) | (cen << 6) | (wait_n << 5) | (int_n << 4) | (nmi_n << 3) | (busrq_n << 2) | (out0 << 1)
        rows.append(f"{di:08b}{low:08b}")
    return rows


def prepare(args):
    args.out.mkdir(parents=True, exist_ok=True)
    if args.trace:
        rows, sources = read_traces(args.trace)
        mode = "trace replay"
    else:
        rows = stress_rows(args.seed, args.cycles)
        sources = []
        mode = "seeded deterministic stress"
    if not rows:
        raise ValueError("no replay rows")
    cen_edges = sum(word[9] == "1" for word in rows)
    reset_index = next((i for i, word in enumerate(rows) if word[8] == "0"), None)
    if reset_index is None:
        raise ValueError("trace has no sampled active reset; refusing to compare unknown startup state")
    with (args.out / "vectors.bin").open("w") as out:
        for word in rows:
            out.write(f"{word}\n")
    (args.out / "row_count.txt").write_text(f"{len(rows)}\n")
    meta = {"mode": mode, "seed": args.seed if not args.trace else None,
            "rows": len(rows), "reset_first_row": reset_index,
            "masked_startup_rows": reset_index + 1,
            "cen_edges": cen_edges, "trace_file_count": len(sources),
            "source_traces": sources,
            "observation": "Each row is driven at falling edge; outputs sampled +1 ns after falling and rising edges.",
            "outputs": "Controls strict after reset startup; unknown address/data bits masked only while their bus field is inactive. See comparison.json for exact policy and counts."}
    (args.out / "replay.json").write_text(json.dumps(meta, indent=2) + "\n")
    print(f"prepared {len(rows)} input rows from {mode}; startup rows masked: {reset_index + 1}")


def read_output(path, expected_rows=None):
    records = []
    with path.open() as stream:
        for line_no, line in enumerate(stream, 1):
            parts = line.strip().split(",")
            if len(parts) != 3:
                raise ValueError(f"{path}:{line_no}: malformed output row")
            index = int(parts[0])
            phase = parts[1].strip().lower()
            bits = parts[2].strip().upper()
            if phase not in ("fall", "rise") or len(bits) != 32:
                raise ValueError(f"{path}:{line_no}: malformed output sample")
            if any(bit not in "01XUZ" for bit in bits):
                raise ValueError(f"{path}:{line_no}: invalid output logic value")
            records.append((index, phase, bits))
    if not records:
        raise ValueError(f"{path}: no output samples")
    if expected_rows is not None and len(records) != 2 * expected_rows:
        raise ValueError(f"{path}: expected {2 * expected_rows} output samples, got {len(records)}")
    for position, (index, phase, _) in enumerate(records):
        expected = (position // 2, "fall" if position % 2 == 0 else "rise")
        if (index, phase) != expected:
            raise ValueError(f"{path}: output sample {position} has key {(index, phase)}, expected {expected}")
    return records


def read_vectors(path):
    return [line.strip() for line in path.read_text().splitlines()]


def with_window(result, left, right, vectors):
    divergence = result.get("first_divergence")
    if divergence is not None and vectors is not None:
        row = divergence["row"]
        left_rows, right_rows = read_output(left), read_output(right)
        lo, hi = max(0, row - 2), min(len(vectors), row + 3)
        result["trace_window"] = [
            {"row": index, "input_vector": vectors[index],
             "left": {phase: bits for i, phase, bits in left_rows if i == index},
             "right": {phase: bits for i, phase, bits in right_rows if i == index}}
            for index in range(lo, hi)
        ]
    return result


def compare_pair(left, right, mask_rows, label, vectors=None):
    try:
        expected_rows = len(vectors) if vectors is not None else None
        a, b = read_output(left, expected_rows), read_output(right, expected_rows)
    except ValueError as error:
        return {"pair": label, "pass": False, "reason": str(error)}
    if len(a) != len(b):
        return {"pair": label, "pass": False, "reason": f"sample count differs: {len(a)} vs {len(b)}"}
    compared = 0
    masked_dout_bits = 0
    masked_addr_bits = 0
    for lhs, rhs in zip(a, b):
        if lhs[:2] != rhs[:2]:
            return {"pair": label, "pass": False, "reason": f"sample key differs: {lhs[:2]} vs {rhs[:2]}"}
        if lhs[0] < mask_rows:
            continue
        compared += 1
        # The wrapper exposes the address only while a memory/I/O access owns
        # the bus. DOUT is specified only during an active write. Output bits
        # [0:8] are controls, [8:24] address, [24:32] DOUT.
        controls_l, controls_r = lhs[2][:8], rhs[2][:8]
        if any(bit in "XUZ" for bit in controls_l + controls_r) or controls_l != controls_r:
            return with_window({"pair": label, "pass": False, "compared_samples": compared,
                    "masked_dout_bits": masked_dout_bits,
                    "first_divergence": {"row": lhs[0], "phase": lhs[1],
                                         "left": lhs[2], "right": rhs[2],
                                         "undefined_or_mismatched_control": True}}, left, right, vectors)
        # MREQ_n/IORQ_n both inactive means the address bus has no selected
        # target. BUSAK_n low means the CPU has granted the external bus.
        # Preserve equality checks on any known address/data bits even then.
        addr_idle = (controls_l[1] == "1" and controls_l[2] == "1") or controls_l[7] == "0"
        data_idle = controls_l[4] == "1"
        lhs_addr, rhs_addr = list(lhs[2][8:24]), list(rhs[2][8:24])
        lhs_data, rhs_data = list(lhs[2][24:]), list(rhs[2][24:])
        masked_addr = set()
        masked_data = set()
        if addr_idle:
            masked_addr = {i for i, (x, y) in enumerate(zip(lhs_addr, rhs_addr))
                           if x in "XUZ" or y in "XUZ"}
            masked_addr_bits += len(masked_addr)
        if data_idle:
            masked_data = {i for i, (x, y) in enumerate(zip(lhs_data, rhs_data))
                           if x in "XUZ" or y in "XUZ"}
            masked_dout_bits += len(masked_data)
        for i in masked_addr:
            lhs_addr[i] = rhs_addr[i] = "?"
        for i in masked_data:
            lhs_data[i] = rhs_data[i] = "?"
        lhs_addr, rhs_addr = "".join(lhs_addr), "".join(rhs_addr)
        lhs_data, rhs_data = "".join(lhs_data), "".join(rhs_data)
        lhs_bits = controls_l + lhs_addr + lhs_data
        rhs_bits = controls_r + rhs_addr + rhs_data
        allowed_unknown = {8 + i for i in masked_addr}
        allowed_unknown.update(24 + i for i in masked_data)
        undefined = next((i for offset, bit in enumerate(lhs_bits + rhs_bits)
                          for i in (offset % 32,) if bit in "XUZ" and i not in allowed_unknown), None)
        if undefined is not None or lhs_bits != rhs_bits:
            return with_window({"pair": label, "pass": False, "compared_samples": compared,
                    "masked_dout_bits": masked_dout_bits,
                    "masked_address_bits": masked_addr_bits,
                    "first_divergence": {"row": lhs[0], "phase": lhs[1],
                                         "left": lhs[2], "right": rhs[2],
                                         "undefined_bit": undefined}}, left, right, vectors)
    if compared == 0:
        return {"pair": label, "pass": False, "reason": "no samples remain after reset startup masking"}
    return {"pair": label, "pass": True, "compared_samples": compared,
            "masked_dout_bits": masked_dout_bits,
            "masked_address_bits": masked_addr_bits}


def compare(args):
    run = args.run
    meta = json.loads((run / "replay.json").read_text())
    mask_rows = meta["masked_startup_rows"]
    vectors = read_vectors(run / "vectors.bin")
    pairs = [compare_pair(args.native, args.checked, mask_rows, "native VHDL vs checked-in Verilog", vectors),
             compare_pair(args.fresh, args.checked, mask_rows, "fresh GHDL Verilog vs checked-in Verilog", vectors),
             compare_pair(args.native, args.fresh, mask_rows, "native VHDL vs fresh GHDL Verilog", vectors)]
    result = {"rows": meta["rows"], "masked_startup_rows": mask_rows,
              "cen_edges": meta["cen_edges"], "trace_file_count": meta["trace_file_count"],
              "source_traces": meta["source_traces"],
              "compared_cycles": max(0, meta["rows"] - mask_rows),
              "compared_samples_per_pair": 2 * max(0, meta["rows"] - mask_rows),
              "mask_policy": "Controls strict. Address/data bits are masked individually only when the field is inactive (A: MREQ_n=IORQ_n=1 or BUSAK_n=0; DOUT: WR_n=1) and either side is X/U/Z. Defined bits still compare; X/U/Z in active or otherwise unmasked outputs fail.",
              "pairs": pairs}
    (run / "comparison.json").write_text(json.dumps(result, indent=2) + "\n")
    for pair in pairs:
        if pair["pass"]:
            print(f"PASS {pair['pair']}: {pair['compared_samples']} samples; masked undefined bits A={pair['masked_address_bits']}, DOUT={pair['masked_dout_bits']}")
        else:
            print(f"FAIL {pair['pair']}: {pair.get('reason', pair.get('first_divergence'))}")
    print(f"rows={result['rows']} reset-startup-masked={mask_rows} compared-cycles={result['compared_cycles']}")
    if not all(pair["pass"] for pair in pairs):
        sys.exit(1)


def negative_control(args):
    meta = json.loads((args.run / "replay.json").read_text())
    result = compare_pair(args.reference, args.mutant, meta["masked_startup_rows"],
                         "checked-in Verilog vs M1_n inversion mutant",
                         read_vectors(args.run / "vectors.bin"))
    caught = not result["pass"] and "first_divergence" in result
    # A common-mode capture failure must not turn three matching empty or
    # truncated streams into evidence of equivalence.
    reference_lines = args.reference.read_text().splitlines(keepends=True)
    malformed = {"empty": [], "truncated": reference_lines[:-1],
                 "reordered": reference_lines[1:2] + reference_lines[:1] + reference_lines[2:]}
    capture_checks = []
    for name, lines in malformed.items():
        path = args.run / "negative-control" / f"{name}.csv"
        path.write_text("".join(lines))
        check = compare_pair(path, path, meta["masked_startup_rows"], name,
                             read_vectors(args.run / "vectors.bin"))
        capture_checks.append({"mutation": name, "caught": not check["pass"],
                               "comparison": check})
    report = {"mutation": "invert the public M1_n output assignment in a temporary copy",
              "caught": caught, "comparison": result, "capture_checks": capture_checks}
    (args.run / "negative-control.json").write_text(json.dumps(report, indent=2) + "\n")
    if not caught or not all(check["caught"] for check in capture_checks):
        print("FAIL negative control: output mutation was not detected")
        sys.exit(1)
    print(f"PASS negative control caught at row {result['first_divergence']['row']} {result['first_divergence']['phase']}")
    print("PASS capture controls rejected empty, truncated, and reordered matching streams")


def main():
    args = make_parser().parse_args()
    if args.command == "prepare":
        prepare(args)
    elif args.command == "compare":
        compare(args)
    else:
        negative_control(args)


if __name__ == "__main__":
    main()
