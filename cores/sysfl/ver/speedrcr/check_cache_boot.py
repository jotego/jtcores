#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 30-10-2026
import argparse
import json
import re
from pathlib import Path
from statistics import mean

parser = argparse.ArgumentParser()
parser.add_argument("log", type=Path)
parser.add_argument("--start", type=int, default=1073)
parser.add_argument("--frames", type=int, default=2001)
args = parser.parse_args()
text = args.log.read_text(errors="replace")
rows = {}
for line in text.splitlines():
    if not line.startswith("CACHESTAT "):
        continue
    row = {key: int(value, 16 if key == "pc" else 10)
           for key, value in re.findall(r"(\w+)=([0-9a-f]+)", line)}
    if len(row) == 13 and "frame" in row:
        rows[row["frame"]] = row
window = [rows[frame] for frame in range(args.start, args.frames) if frame in rows]
rate = float(Path("framerate").read_text())
changed = sorted(int(match.group(1)) for path in Path("frames").glob("frame_*.png")
                 if (match := re.fullmatch(r"frame_(\d+)\.png", path.name))
                 and args.start <= int(match.group(1)) < args.frames)
expected = args.frames - args.start
complete = len(window) == expected and expected > 1
single_step = complete and all(b["gameframe"] == a["gameframe"] + 1
                              for a, b in zip(window, window[1:]))
rendered = len(changed) == expected
errors = bool(re.search(r"ERROR:|HALTED|FATAL:|%Error|^FAIL", text, re.M))
report = {
    "pass": complete and single_step and rendered and not errors,
    "first_frame": args.start,
    "last_frame": args.frames - 1,
    "samples": len(window),
    "expected_samples": expected,
    "video_hz": rate,
    "one_game_update_per_video_frame": single_step,
    "changed_video_frames": len(changed),
    "rendered_fps": rate * len(changed) / expected if expected else 0,
    "coin_pulses": text.count("coin inserted"),
    "errors": errors,
}
if window:
    report.update({
        "first_gameframe": window[0]["gameframe"],
        "last_gameframe": window[-1]["gameframe"],
        "mean_idle_percent": 100 * mean(row["idle"] / row["cen"] for row in window),
        "min_idle_cen": min(row["idle"] for row in window),
        "mean_cache_misses": mean(row["misses"] for row in window),
        "mean_mdwait_cen": mean(row["mdwait"] for row in window),
    })
Path("reports").mkdir(exist_ok=True)
output = Path("reports") / (args.log.stem + ".json")
output.write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
print(f"Report: {output.resolve()}")
raise SystemExit(0 if report["pass"] else 1)
