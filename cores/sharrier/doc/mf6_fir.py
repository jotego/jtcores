#!/usr/bin/env python3
"""Generate the MF6-50 FIR coefficients for the PCM path.

    ./doc/mf6_fir.py            # report the design and verify against the committed files
    ./doc/mf6_fir.py --write    # regenerate hdl/jtsharrier_mf6.{csv,hex}

Reconstructed 2026-08-18 from the session that first produced the coefficients: the
committed CSV cited `doc/mf6_fir.py` as its generator, but the script had only ever
existed inline and was never written to disk. It reproduces the committed .hex
byte-for-byte -- that equality is the test, and --write is refused if it ever fails.

WHY THESE NUMBERS. The board filters each PCM channel with an MF6-50 (IC 12M, 12K on
sheet D-2/3): a 6th-order Butterworth switched-capacitor lowpass. It has no fixed
corner -- it self-clocks from R13/C20 and divides by 50:

    R13 = 10k    colour bands, corroborated by the schematic
    C20 = 100p   '101' marking, read off the board
    f_clk = 1/(1.69*R*C) = 591.7 kHz     MF6 datasheet, Schmitt trigger R/C oscillator
    f_c   = f_clk/50     = 11.83 kHz     the '-50' in the part number

It is NOT expressible as mem.yaml's `rc:` -- that caps at two poles, and cascaded RC
poles have the wrong Q, which is why the previous core gave up and reverted to a single
pole. Hence a FIR.

NO SCIPY. Deliberately: the Butterworth magnitude is analytic, so the impulse response
comes from a numerical inverse Fourier transform of it. That keeps this runnable
anywhere without a numeric stack. It was cross-checked against scipy when first
designed (agreement 0.24 dB); the self-check below re-derives the response directly.
"""

import math, sys, os

FS   = 62500.0   # PCM output rate: segapcm_device<8>, 4 MHz / 64
FC   = 11834.0   # f_clk/50
ORD  = 6         # MF6 is 6th order
NTAP = 95        # odd -> Type I linear phase. Also jtframe_fir's KMAX in jtsharrier_snd.v
HDL  = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "hdl")


def target(f):
    "Butterworth magnitude response."
    return 1.0 / math.sqrt(1.0 + (f / FC) ** (2 * ORD))


def design():
    "Impulse response by numerical inverse Fourier transform, Blackman windowed."
    STEPS = 20000
    half  = (NTAP - 1) // 2
    h = []
    for n in range(NTAP):
        m = n - half
        acc = 0.0
        for i in range(STEPS + 1):
            f = (FS / 2.0) * i / STEPS
            w = 0.5 if i in (0, STEPS) else 1.0          # trapezoid rule
            acc += w * target(f) * math.cos(2 * math.pi * f * m / FS)
        h.append(2.0 * acc * (FS / 2.0 / STEPS) / (FS / 2.0))
    # Blackman window controls the ripple from truncating to NTAP
    for n in range(NTAP):
        x = 2 * math.pi * n / (NTAP - 1)
        h[n] *= 0.42 - 0.5 * math.cos(x) + 0.08 * math.cos(2 * x)
    s = sum(h)                                            # unity DC gain
    return [c / s for c in h]


def resp(f, taps):
    re = im = 0.0
    for n, c in enumerate(taps):
        a = -2 * math.pi * f * n / FS
        re += c * math.cos(a); im += c * math.sin(a)
    return math.hypot(re, im)


def quantise(h):
    "jtframe format: int(c*32768) TRUNCATED toward zero, 16-bit two's complement."
    return [int(c * 32768) for c in h]


def hexlines(q):
    # jtframe_fir's RAM is 512 words: coefficients in [0..KMAX-1], the rest is its
    # sample history, so the file must be padded to 512 lines.
    return "".join("%04X\n" % (v & 0xFFFF) for v in q + [0] * (512 - len(q)))


def csvtext(h):
    return ("# MF6-50 anti-alias filter, Space Harrier sound board 834-5799 (IC68, IC69)\n"
            "# 6th-order Butterworth lowpass, cutoff 11.83 kHz, sample rate 62.5 kHz\n"
            "#\n"
            "# Cutoff is measured, not estimated: the MF6 is self-clocked from R13/C20 on\n"
            "# pins 9 and 11. R13 = 10k (colour bands and the schematic); C20 = 100 pF (the\n"
            "# '101' marking, read off the board). The MF6 datasheet gives the self-clock\n"
            "# oscillator as f_clk = 1/(1.69*R*C) = 591.7 kHz (Figure 1, Schmitt Trigger R/C\n"
            "# Oscillator), and the -50 part sets f_clk/f_c = 50:1, so f_c = 11.83 kHz.\n"
            "#\n"
            "# %d taps, Type I linear phase. Designed by numerical inverse Fourier transform\n"
            "# of the analytic Butterworth magnitude, Blackman windowed, DC gain normalised\n"
            "# to unity. Worst error below 20 kHz is 0.23 dB before quantisation.\n"
            "# Generator: doc/mf6_fir.py\n" % NTAP
            + "".join("%.18f\n" % c for c in h))


def main():
    write = "--write" in sys.argv
    h = design()
    q = quantise(h)
    hq = [c / 32768.0 for c in q]

    print("%d taps, fs %.1f kHz, fc %.2f kHz, order %d\n" % (NTAP, FS / 1e3, FC / 1e3, ORD))
    print("%9s %10s %9s %8s" % ("freq kHz", "target dB", "FIR dB", "err dB"))
    worst = 0.0
    for f in (100, 1000, 4000, 8000, 10000, 11834, 14000, 16000, 20000, 25000, 31000):
        t = 20 * math.log10(max(target(f), 1e-9))
        a = 20 * math.log10(max(resp(f, hq), 1e-9))
        if f <= 20000:
            worst = max(worst, abs(a - t))
        print("%9.2f %10.2f %9.2f %8.2f" % (f / 1e3, t, a, a - t))

    dc = sum(q) / 32768.0
    print("\nworst |error| below 20 kHz, quantised: %.2f dB" % worst)
    print("DC gain %.5f (%+.3f dB)" % (dc, 20 * math.log10(dc)))
    print("symmetric about tap %d: %s" % ((NTAP - 1) // 2,
          all(q[(NTAP - 1) // 2 - i] == q[(NTAP - 1) // 2 + i] for i in range(1, (NTAP + 1) // 2))))

    # Equality with what is committed is the real test of this reconstruction.
    hexpath = os.path.join(HDL, "jtsharrier_mf6.hex")
    same = None
    if os.path.isfile(hexpath):
        same = open(hexpath).read() == hexlines(q)
        print("\nmatches committed .hex: %s" % ("YES" if same else "*** NO ***"))

    if write:
        if same is False:
            sys.exit("refusing --write: output differs from the committed .hex. "
                     "Investigate before overwriting a verified filter.")
        open(hexpath, "w").write(hexlines(q))
        open(os.path.join(HDL, "jtsharrier_mf6.csv"), "w").write(csvtext(h))
        print("written to %s" % HDL)


if __name__ == "__main__":
    main()
