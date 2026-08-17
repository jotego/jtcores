#!/usr/bin/env python3
"""Prove a regression sim produced sound after the coin.

Reads test.wav from the sim dir and the coin frame from the sim log, then
checks that the WINDOW frames after the coin contain audio that is both
non-zero and non-constant. Exit 0 = pass, 1 = fail, 2 = could not evaluate.

    ./check_audio.py [simlog] [--window 30] [--wav test.wav]
"""
import re, sys, wave, argparse
import numpy as np

ap = argparse.ArgumentParser()
ap.add_argument("log", nargs="?", default="sim.log")
ap.add_argument("--wav", default="test.wav")
ap.add_argument("--window", type=int, default=30, help="frames after coin")
ap.add_argument("--fps", type=float, default=57.44)
a = ap.parse_args()

try:
    m = re.search(r"coin inserted \(cabinet input frame (\d+)\)", open(a.log).read())
except OSError:
    print(f"cannot read {a.log}"); sys.exit(2)
if not m:
    print("no 'coin inserted' line in the log - was a .cab passed?"); sys.exit(2)
coin = int(m.group(1))

try:
    w = wave.open(a.wav)
except (OSError, wave.Error) as e:
    print(f"cannot read {a.wav}: {e} (sim still running, or run without audio?)"); sys.exit(2)
fr = w.getframerate(); ch = w.getnchannels()
d = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").reshape(-1, ch)
s0 = int(coin / a.fps * fr); s1 = int((coin + a.window) / a.fps * fr)
seg = d[s0:s1]
if len(seg) == 0:
    print(f"wav too short: ends at {len(d)/fr:.1f}s, coin at {coin/a.fps:.1f}s"); sys.exit(2)

nz  = int((seg != 0).sum())
std = float(seg.std())
peak= int(np.abs(seg).max())
ok  = nz > 0 and std > 1.0
print(f"coin frame {coin}: {a.window} frames after -> "
      f"nonzero={nz}/{seg.size} peak={peak} std={std:.1f} -> {'PASS' if ok else 'FAIL'}")
sys.exit(0 if ok else 1)
