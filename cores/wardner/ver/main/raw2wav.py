#!/usr/bin/env python3
"""Wrap the boot bench's snd.raw in a WAV header so it can be listened to.

tb_main writes one signed 16-bit little-endian sample per YM3812 output
strobe. The bench runs the board 2.381 times fast, but that only compresses
wall-clock time: the sample sequence is the board's, so the right playback
rate is the chip's own 3.5 MHz / 72 = 48611 Hz and the result plays at the
correct pitch and duration.

  raw2wav.py snd.raw snd.wav [rate]
"""
import sys, wave

src = sys.argv[1] if len(sys.argv) > 1 else "snd.raw"
dst = sys.argv[2] if len(sys.argv) > 2 else "snd.wav"
rate = int(sys.argv[3]) if len(sys.argv) > 3 else 48611

data = open(src, "rb").read()
data = data[: len(data) & ~1]
w = wave.open(dst, "wb")
w.setnchannels(1)
w.setsampwidth(2)
w.setframerate(rate)
w.writeframes(data)
w.close()
print("wrote %s: %d samples, %.2f s at %d Hz" % (dst, len(data)//2, len(data)/2/rate, rate))
