#!/usr/bin/env python3
"""Generate, run, and check the HD6309 opcode/indexed timing matrix."""
import argparse
import csv
import hashlib
import os
import re
import subprocess
import tempfile
from collections import defaultdict, Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent


def combined_status(values):
    if "X" in values:
        return "X"
    if "U" in values:
        return "U"
    return "P"


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--coverage", type=Path, default=HERE.parent / "coverage.md")
    ap.add_argument("--keep", type=Path, help="directory to preserve vectors, results, and exclusions")
    args = ap.parse_args()
    jtframe = os.environ.get("JTFRAME")
    if not jtframe:
        raise SystemExit("JTFRAME is unset; run through sweep/run.sh")
    work_ctx = tempfile.TemporaryDirectory(prefix="hd6309-sweep-") if not args.keep else None
    work = Path(args.keep).resolve() if args.keep else Path(work_ctx.name)
    work.mkdir(parents=True, exist_ok=True)
    vectors, excluded = work / "vectors.txt", work / "excluded.csv"
    cases, results = work / "vectors.cases.csv", work / "results.csv"
    subprocess.run(["python3", str(HERE / "generate.py"), "--coverage", str(args.coverage),
                    "--vectors", str(vectors), "--excluded", str(excluded)], check=True)
    image = work / "sim"
    sources = [str(Path(jtframe) / "hdl/cpu/mc6809i.v"),
               str(Path(jtframe) / "hdl/cpu/jtframe_hd6309_arith.v"), str(HERE / "test.v")]
    source_hashes = {Path(source).name: sha256(Path(source)) for source in sources}
    directed_test_hash = sha256(HERE.parent / "test.v")
    subprocess.run(["iverilog", "-g2012", "-s", "mc6809_batch_tb", "-Pmc6809_batch_tb.HD_MODE=1",
                    "-o", str(image), *sources], check=True)
    subprocess.run(["vvp", str(image), f"+vectors={vectors}", f"+results={results}"], check=True)

    metadata = {}
    with cases.open(newline="") as f:
        for row in csv.DictReader(f):
            metadata[row["case_id"]] = row
    actual = {}
    mismatch_rows = []
    counts = Counter()
    failure_kinds = Counter()
    with results.open(newline="") as f:
        for result in csv.DictReader(f):
            case_id = result["case_id"]
            meta = metadata[case_id]
            good = result["status"] == "ok"
            expected_close = int(meta["expected_close"], 16)
            if expected_close != 0xffff and int(result["closing_pc"], 16) != expected_close:
                good = False
            known = meta["oracle_known"] == "1"
            if known and int(result["e_cycles"]) != int(meta["expected_cycles"]):
                good = False
            status = "X" if not good else ("P" if known else "U")
            actual[case_id] = status
            counts[status] += 1
            if status == "X":
                if result["status"] != "ok":
                    kind = "watchdog/dispatch"
                elif known and int(result["e_cycles"]) != int(meta["expected_cycles"]):
                    kind = "cycle"
                else:
                    kind = "flow"
                failure_kinds[kind] += 1
                mismatch_rows.append((meta, result))

    opcode_outcomes = defaultdict(list)
    postbyte_outcomes = defaultdict(list)
    with cases.open(newline="") as f:
        for row in csv.DictReader(f):
            status = actual[row["case_id"]]
            if row["bucket"] == "indexed_postbyte":
                key = (row["postbyte_form"], row["postbyte_pattern"], row["mode"])
                postbyte_outcomes[key].append(status)
            key = (row["page"], row["opcode"], row["form"], row["addressing"], row["mode"])
            opcode_outcomes[key].append(status)

    coverage_lines = []
    in_index = False
    for line in args.coverage.read_text().splitlines():
        if line.startswith("## Indexed postbyte detail"):
            in_index = True
        elif in_index and line.startswith("## "):
            in_index = False
        if line.startswith("| `$") and line.count("|") >= 12:
            cells = [x.strip() for x in line.strip().strip("|").split("|")]
            match = re.fullmatch(r"`\$([0-9A-F]{2})/\$([0-9A-F]{2})`", cells[0])
            key = (match.group(1), match.group(2), cells[1].strip("`"), cells[2].strip("`")) if match else None
            cells[8:10] = ["U", "U"]
            if key:
                for col, mode in ((8, "E"), (9, "N")):
                    values = opcode_outcomes.get((*key, mode), [])
                    if values:
                        cells[col] = combined_status(values)
            line = "| " + " | ".join(cells) + " |"
        elif in_index and line.startswith("| ") and line.count("|") >= 7:
            cells = [x.strip() for x in line.strip().strip("|").split("|")]
            if len(cells) >= 8 and cells[1].startswith("`") and cells[0] != "Postbyte form":
                form, pattern = cells[0].strip("`"), cells[1].strip("`")
                cells[5:7] = ["U", "U"]
                for col, mode in ((5, "E"), (6, "N")):
                    values = postbyte_outcomes.get((form, pattern, mode), [])
                    if values:
                        cells[col] = combined_status(values)
                line = "| " + " | ".join(cells) + " |"
        coverage_lines.append(line)
    exclusions = sum(1 for _ in excluded.open()) - 1
    index = next((i for i, line in enumerate(coverage_lines) if line.startswith("## Latest expanded sweep")), None)
    if index is None:
        index = next((i for i, line in enumerate(coverage_lines) if line.startswith("## Remaining unverified coverage")), len(coverage_lines))
        coverage_lines[index:index] = ["## Latest expanded sweep", ""]
    end = next((i for i in range(index + 1, len(coverage_lines)) if coverage_lines[i].startswith("## ")), len(coverage_lines))
    snapshot = [
        "## Latest expanded sweep",
        "",
        f"This snapshot contains {sum(counts.values())} vectors: P={counts['P']}, X={counts['X']}, U={counts['U']}; {exclusions} vectors excluded for specialized or unsupported setup.",
        f"CPU `mc6809i.v` SHA256 `{source_hashes['mc6809i.v']}`; helper `jtframe_hd6309_arith.v` SHA256 `{source_hashes['jtframe_hd6309_arith.v']}`; sweep testbench SHA256 `{source_hashes['test.v']}`; directed testbench SHA256 `{directed_test_hash}`.",
        "The vector and result CSV files are preserved with `--keep` for reproduction. The sweep checks timing and selected flow endpoints only; functional and bus evidence remains in the directed simunit.",
        "",
    ]
    coverage_lines[index:end] = snapshot
    args.coverage.write_text("\n".join(coverage_lines) + "\n")

    print(f"Sweep cases: {sum(counts.values())}; P={counts['P']} X={counts['X']} unresolved={counts['U']}")
    if counts["X"]:
        print("Failure classes: " + ", ".join(f"{k}={failure_kinds[k]}" for k in ("watchdog/dispatch", "cycle", "flow") if failure_kinds[k]))
    print(f"Exclusions: {exclusions}")
    print("Source SHA256: " + ", ".join(f"{name}={digest}" for name, digest in source_hashes.items()))
    print(f"Directed testbench SHA256: {directed_test_hash}")
    if args.keep:
        print(f"Artifacts: {work}")
    if mismatch_rows:
        for meta, result in mismatch_rows[:30]:
            print(f"FAIL {result['status']} {meta['page']}/{meta['opcode']} {meta['form']} {meta['addressing']} {meta['mode']} {meta['scenario']}: "
                  f"measured {result['e_cycles']} expected {meta['expected_cycles']} closing PC {result['closing_pc']} expected {meta['expected_close']}")
        raise SystemExit(1)
    if work_ctx:
        work_ctx.cleanup()


if __name__ == "__main__":
    main()
