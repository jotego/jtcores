#!/usr/bin/env python3
# Circular x/y-shift correlation between the sim frame and the MAME reference
import sys
from PIL import Image
import numpy as np

ref = np.asarray(Image.open(sys.argv[1]).convert("L"), dtype=float)
sim = np.asarray(Image.open(sys.argv[2]).convert("L"), dtype=float)
ref -= ref.mean(); sim -= sim.mean()

def best_shift(a, b, axis):
    fa, fb = np.fft.fft(a, axis=axis), np.fft.fft(b, axis=axis)
    corr = np.fft.ifft(fa * np.conj(fb), axis=axis).real.sum(axis=1-axis)
    return int(np.argmax(corr)), corr

sx, cx = best_shift(ref, sim, 1)
sy, cy = best_shift(ref, sim, 0)
W, H = ref.shape[1], ref.shape[0]
fmt = lambda s, n: s if s <= n//2 else s-n
print(f"x shift (sim must move by): {fmt(sx,W)} px   y shift: {fmt(sy,H)} px")
top5x = np.argsort(cx)[::-1][:5]
print("top x candidates:", [(fmt(int(i),W), round(float(cx[i]/cx.max()),3)) for i in top5x])
