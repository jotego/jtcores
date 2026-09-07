# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Emit jtmnymny_mixer hardware artifacts from the analyze.py models:
#   out/mixer_coeffs.hex  - packed section table for $readmemh
#   out/mixer_params.vh   - tromba/duck/ladder/format localparams
#   out/emit.md           - formats, ranges, per-section table
#   out/stim.hex, out/golden.hex - bit-true vectors for the Verilog TB
# The bittrue() function is the reference implementation of the mixer.

import math
import numpy as np
from pathlib import Path

HERE = Path(__file__).parent
OUT = HERE/'out'
FS = 192000.0

# engine input channels
CH = ['rullante', 'cassa', 'basso', 'piano', 'anal3a', 'anal3b',
      'tromba', 'speech', 'dac']
OUTSEL = {'music': 0, 'speech': 1, 'dac': 2}

# physical full scale of each source in the units of its H(s) drive
# (V for voltage-driven branches, A for current-driven), i.e. the value
# an engine input of +32767 represents
AY_FS = 0.92          # V, AY on 1k load
SRC_FS = {'rullante': AY_FS, 'cassa': AY_FS, 'basso': AY_FS,
          'piano': AY_FS, 'anal3a': AY_FS, 'anal3b': AY_FS,
          'tromba': 3.3,  # V, 5B1 ramp swing (levelt=0)
          'speech': 750e-6, 'dac': 1e-3}

OUT_FS = 2.0          # V at the R1 node represented by +-32767 out
BSH = 26              # b coefficients stored as b*2^BSH (int24)
                      # Y state grid: out_counts * 2^BSH, 48-bit

# tromba generator constants
TONE_TH   = 166       # ay4h_b code above which T6 conducts (0.6V/0.92V)
PULSE_TK  = 16        # Q high ticks (81 us)
RECOV_TK  = 36        # /CLR recovery ticks (186 us)
KRAMP     = 340       # (1-exp(-1/(fs*1ms))) in Q0.16
TGT_LOUD  = 32767     # levelt=0 ramp target (3.9V, 3.3V above chop level)
TGT_SOFT  = -4965     # levelt=1 target (0.1V = -0.5V from chop level)

def sat(v, bits):
    m = 1 << (bits-1)
    return max(-m, min(m-1, v))

def build_sections(models):
    """Fold source/output scaling into bilinear sections. Returns list of
    dicts {ch, out, a, b0, b1} in float, plus ladder/duck gains."""
    from analyze import bilinear_zpk, tf_eval
    branch_map = [   # (model name, label, in channel, out channel)
        ('rullante', '',      'rullante', 'music'),
        ('cassa',    '',      'cassa',    'music'),
        ('basso',    '',      'basso',    'music'),
        ('piano',    '',      'piano',    'music'),
        ('anal3',    'sw1=0', 'anal3a',   'music'),
        ('anal3',    'sw1=1', 'anal3b',   'music'),
        ('tromba',   'vol0',  'tromba',   'music'),
        ('speech',   '',      'speech',   'speech'),
        ('dac',      '',      'dac',      'dac'),
    ]
    sections = []
    for name, label, ch, outch in branch_map:
        entry = [m for m in models[name] if m[0] == label]
        assert entry, f'{name} {label} missing'
        _, poles, resid, d = entry[0]
        secs, dd = bilinear_zpk(poles, resid, d)
        k = SRC_FS[ch]/OUT_FS
        for b, a in secs:
            sections.append(dict(ch=ch, out=outch,
                                 a=-a[1].real, b0=b[0].real*k, b1=b[1].real*k))
        dr = dd.real if hasattr(dd, 'real') else dd
        if abs(dr*k) > 2**-24:
            sections.append(dict(ch=ch, out=outch, a=0.0, b0=dr*k, b1=0.0))
    # tromba ladder: gain of each vol step relative to vol0, at 1 kHz
    ref = None
    ladder = []
    for label, poles, resid, d in models['tromba']:
        h = abs(tf_eval(poles, resid, d, [1000.0])[0])
        if ref is None: ref = h
        ladder.append(h/ref)
    # duck: level=1 vs level=0 broadband ratio (flat, checked in report)
    lv = {lb: (p, r, d) for lb, p, r, d in models['duck']}
    h0 = abs(tf_eval(*lv['level=0'], [1000.0])[0])
    h1 = abs(tf_eval(*lv['level=1'], [1000.0])[0])
    return sections, ladder, h1/h0

def quantize(sections):
    bmax = max(max(abs(s['b0']), abs(s['b1'])) for s in sections)
    assert bmax*(1 << BSH) < (1 << 23), f'b overflow: bmax={bmax:.4f}'
    q = []
    for s in sections:
        q.append(dict(ch=s['ch'], out=s['out'],
                      a=int(round(s['a']*(1 << 24))),
                      b0=int(round(s['b0']*(1 << BSH))),
                      b1=int(round(s['b1']*(1 << BSH)))))
        assert 0 <= q[-1]['a'] < (1 << 24)
    return q

# ------------------------------------------------------- bit-true mixer

class BitTrue:
    """Reference mixer. Inputs per tick: ay codes (8b), speech (s14),
    dac (8b), ioa[4:0], level, levelt, sw1. Outputs: 3x int16."""
    def __init__(self, qsec, ladder_q, duck_q):
        self.qsec = qsec
        self.ladder_q = ladder_q      # 8 x Q0.15
        self.duck_q = duck_q          # Q0.15
        self.Y = [0]*len(qsec)
        self.x1 = {c: 0 for c in CH}
        self.v = 0                    # tromba ramp
        self.sat_events = 0
        self.tone1 = 0
        self.ph = 0                   # tromba FSM phase counter
        self.state = 0                # 0 idle, 1 pulse, 2 recovery

    def tick(self, ay4g_a, ay4g_b, ay4g_c, ay4h_a, ay4h_b,
             speech, dac, ioa, level, levelt, sw1):
        # tromba generator
        tone = 1 if ay4h_b > TONE_TH else 0
        if self.state == 0:
            if tone and not self.tone1:
                self.state, self.ph = 1, PULSE_TK
        elif self.state == 1:
            self.ph -= 1
            if self.ph == 0: self.state, self.ph = 2, RECOV_TK
        else:
            self.ph -= 1
            if self.ph == 0: self.state = 0
        self.tone1 = tone
        if self.state == 1:
            self.v = 0
        else:
            tgt = TGT_SOFT if levelt else TGT_LOUD
            self.v = sat(self.v + (((tgt - self.v)*KRAMP) >> 16), 16)
        vol = ((ioa & 1) << 2) | (ioa & 2) | ((ioa >> 2) & 1)  # bit-reverse
        x = self._xmap(ay4g_a, ay4g_b, ay4g_c, ay4h_a, speech, dac,
                       ioa, sw1, vol)
        return self.tick_raw(x, level)

    def _xmap(self, ay4g_a, ay4g_b, ay4g_c, ay4h_a, speech, dac,
              ioa, sw1, vol):
        return {
            'rullante': (ay4g_a << 7) if (ioa >> 4) & 1 else 0,
            'cassa':    (ay4g_a << 7) if (ioa >> 3) & 1 else 0,
            'basso':    ay4g_b << 7,
            'piano':    ay4h_a << 7,
            'anal3a':   0 if sw1 else (ay4g_c << 7),
            'anal3b':   (ay4g_c << 7) if sw1 else 0,
            'tromba':   sat((self.v*self.ladder_q[vol]) >> 15, 16),
            'speech':   sat(speech << 2, 16),
            'dac':      dac << 7,
        }

    def tick_raw(self, x, level):
        acc = {'music': 0, 'speech': 0, 'dac': 0}
        for i, s in enumerate(self.qsec):
            xi, x1i = x[s['ch']], self.x1[s['ch']]
            y = ((s['a']*self.Y[i]) >> 24) + s['b0']*xi + s['b1']*x1i
            if y != sat(y, 48): self.sat_events += 1
            y = sat(y, 48)
            self.Y[i] = y
            acc[s['out']] += y
        for c in CH:
            self.x1[c] = x[c]
        om = sat(acc['music'] >> BSH, 17)
        om = sat((om*self.duck_q) >> 15, 16) if level else sat(om, 16)
        return (om, sat(acc['speech'] >> BSH, 16), sat(acc['dac'] >> BSH, 16))

# ------------------------------------------------------------ stimulus

def stimulus():
    """Exercises every channel: tones, gates, tromba notes, controls.
    Returns list of input tuples (one per 192kHz tick)."""
    T = int(0.40*FS)
    stim = []
    for n in range(T):
        t = n/FS
        ay4g_a = ay4g_b = ay4g_c = ay4h_a = ay4h_b = 0
        speech = dac = 0
        ioa, level, levelt, sw1 = 0, 0, 0, 0
        sq = lambda f, amp=222: amp if (int(2*f*t) & 1) == 0 else 0
        if t < 0.06:                     # piano tone
            ay4h_a = sq(440)
        elif t < 0.12:                   # basso tone
            ay4g_b = sq(110)
        elif t < 0.18:                   # drums: noise-ish + gates
            ay4g_a = (n*2654435761) >> 24 & 0xff
            ioa |= 0x10 if t < 0.15 else 0x08
        elif t < 0.24:                   # anal3, sw1 flips mid-way
            ay4g_c = sq(880)
            sw1 = 1 if t >= 0.21 else 0
        elif t < 0.32:                   # tromba notes, levelt/vol change
            ay4h_b = sq(330, 255)
            levelt = 1 if t >= 0.28 else 0
            ioa |= 0x1 if t >= 0.30 else 0  # vol step
        elif t < 0.36:                   # speech burst + duck
            speech = int(6000*math.sin(2*math.pi*300*t))
            level = 1
        else:                            # dac ramp
            dac = (n >> 4) & 0xff
        stim.append((ay4g_a, ay4g_b, ay4g_c, ay4h_a, ay4h_b,
                     speech, dac, ioa, level, levelt, sw1))
    return stim

def pack_stim(s):
    ay4g_a, ay4g_b, ay4g_c, ay4h_a, ay4h_b, speech, dac, ioa, level, levelt, sw1 = s
    w = (ay4g_a | (ay4g_b << 8) | (ay4g_c << 16) | (ay4h_a << 24)
         | (ay4h_b << 32) | ((speech & 0x3fff) << 40) | (dac << 54)
         | (ioa << 62) | (level << 67) | (levelt << 68) | (sw1 << 69))
    return f'{w:018X}'

def emit(models, freqs):
    sections, ladder, duck = build_sections(models)
    qsec = quantize(sections)
    ladder_q = [min(int(round(g*(1 << 15))), 32767) for g in ladder]
    duck_q = int(round(duck*(1 << 15)))

    # verify quantized bit-true frequency response vs float model per branch
    # (impulse through the integer engine, FFT) - light check: impulse energy
    bt = BitTrue(qsec, ladder_q, duck_q)

    HDL = HERE.parent.parent/'hdl'
    with open(HDL/'jtmnymny_coeffs.hex', 'w') as f:
        for s in qsec:
            w = (CH.index(s['ch']) | (OUTSEL[s['out']] << 4)
                 | ((s['a'] & 0xffffff) << 6)
                 | ((s['b0'] & 0xffffff) << 30)
                 | ((s['b1'] & 0xffffff) << 54))
            f.write(f'{w:020X}\n')
        for _ in range(len(qsec), 80):
            f.write('0'*20 + '\n')

    with open(HDL/'jtmnymny_params.vh', 'w') as f:
        f.write('// generated by ver/audio/emit.py - do not edit\n')
        f.write(f'localparam SECTIONS  = {len(qsec)};\n')
        f.write(f'localparam BSH       = {BSH};\n')
        f.write(f'localparam TONE_TH   = 8\'d{TONE_TH};\n')
        f.write(f'localparam PULSE_TK  = 6\'d{PULSE_TK};\n')
        f.write(f'localparam RECOV_TK  = 6\'d{RECOV_TK};\n')
        f.write(f'localparam KRAMP     = 17\'d{KRAMP};\n')
        f.write(f'localparam signed [16:0] TGT_LOUD = 17\'sd{TGT_LOUD};\n')
        f.write(f'localparam signed [16:0] TGT_SOFT = -17\'sd{-TGT_SOFT};\n')
        f.write(f'localparam [15:0] DUCK_G = 16\'d{duck_q};\n')
        lad = ','.join(f'16\'d{v}' for v in reversed(ladder_q))
        f.write(f'localparam [8*16-1:0] LADDER = {{{lad}}};\n')

    # integer-engine response vs exact analog curve, per channel:
    # full-scale white noise drive, cross-spectral H estimate
    from analyze import tf_eval
    import scipy.signal as ss
    branch_of = {'rullante': ('rullante', ''), 'cassa': ('cassa', ''),
                 'basso': ('basso', ''), 'piano': ('piano', ''),
                 'anal3a': ('anal3', 'sw1=0'), 'anal3b': ('anal3', 'sw1=1'),
                 'tromba': ('tromba', 'vol0'), 'speech': ('speech', ''),
                 'dac': ('dac', '')}

    def run_noise(ch, n):
        """vectorized integer engine, single channel driven, others 0"""
        rng = np.random.RandomState(1)
        x = rng.randint(-32768, 32768, size=n).astype(np.int64)
        idx = [i for i, q in enumerate(qsec) if q['ch'] == ch]
        a = np.array([qsec[i]['a'] for i in idx], dtype=np.int64)
        b0 = np.array([qsec[i]['b0'] for i in idx], dtype=np.int64)
        b1 = np.array([qsec[i]['b1'] for i in idx], dtype=np.int64)
        Y = np.zeros(len(idx), np.int64)
        out = np.empty(n, np.int64)
        x1 = np.int64(0)
        lim = np.int64(1) << 47
        for t in range(n):
            xa = x[t]
            Yhi = Y >> 24
            Ylo = Y & 0xFFFFFF
            Y = a*Yhi + ((a*Ylo) >> 24) + b0*xa + b1*x1
            np.clip(Y, -lim, lim-1, out=Y)
            out[t] = Y.sum() >> BSH
            x1 = xa
        return x.astype(float), out.astype(float)

    # equivalence: vectorized == scalar reference on a short run
    ch0 = 'cassa'
    xs, os_ = run_noise(ch0, 2000)
    eng = BitTrue(qsec, ladder_q, duck_q)
    for t in range(2000):
        x = {c: 0 for c in CH}
        x[ch0] = int(xs[t])
        m, _, _ = eng.tick_raw(x, 0)
        assert m == int(os_[t]), f'vector/scalar mismatch at tick {t}'

    NN = 1 << 18
    verify = []
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(9, 6))
    for ch in CH:
        x, y = run_noise(ch, NN)
        f_, Pxx = ss.welch(x, fs=FS, nperseg=1 << 14)
        _, Pxy = ss.csd(x, y, fs=FS, nperseg=1 << 14)
        Hm = Pxy/Pxx
        name, label = branch_of[ch]
        _, poles, resid, d = [m for m in models[name] if m[0] == label][0]
        Hx = tf_eval(poles, resid, d, f_[1:])*SRC_FS[ch]/OUT_FS
        mag = np.abs(Hx)
        good = (f_[1:] >= 20) & (f_[1:] <= 20000) & (mag > mag.max()/10**(50/20))
        e = np.max(np.abs(20*np.log10(np.abs(Hm[1:][good])+1e-12)
                          - 20*np.log10(mag[good])))
        verify.append((ch, e))
        l, = ax.semilogx(f_[1:][good], 20*np.log10(mag[good]),
                         label=f'{ch} exact')
        ax.semilogx(f_[1:][good], 20*np.log10(np.abs(Hm[1:][good])+1e-12),
                    '--', color=l.get_color())
    ax.grid(True, which='both', alpha=.3); ax.legend(fontsize=7)
    ax.set_xlabel('Hz'); ax.set_ylabel('dB (out counts / in counts)')
    ax.set_title('bit-true integer engine (dashed) vs exact analog')
    fig.tight_layout(); fig.savefig(OUT/'bittrue_verify.png', dpi=110)
    plt.close(fig)

    stim = stimulus()
    with open(OUT/'stim.hex', 'w') as fs_, open(OUT/'golden.hex', 'w') as fg:
        for s in stim:
            fs_.write(pack_stim(s) + '\n')
            m, sp, dc = bt.tick(*s)
            fg.write(f'{((m & 0xffff) | ((sp & 0xffff) << 16) | ((dc & 0xffff) << 32)):012X}\n')

    with open(OUT/'emit.md', 'w') as f:
        f.write('# mixer emission\n\n')
        f.write(f'- {len(qsec)} sections, a Q0.24, b Q0.{BSH} (int24), '
                f'state 48-bit on 2^-{BSH} grid, OUT_FS = {OUT_FS} V\n')
        f.write(f'- bit-true run saturation events: {bt.sat_events}\n')
        f.write(f'- duck gain {duck:.4f} ({duck_q} Q0.15)\n')
        f.write(f'- ladder Q0.15: {ladder_q}\n')
        bmax = max(max(abs(s['b0']), abs(s['b1'])) for s in sections)
        f.write(f'- max |b| = {bmax:.5f}\n\n')
        f.write('| # | ch | out | a | b0 | b1 |\n|---|---|---|---|---|---|\n')
        for i, s in enumerate(qsec):
            f.write(f'| {i} | {s["ch"]} | {s["out"]} | {s["a"]:06X} | '
                    f'{s["b0"] & 0xffffff:06X} | {s["b1"] & 0xffffff:06X} |\n')
        f.write('\n## bit-true engine vs exact analog\n')
        f.write('(white-noise cross-spectrum, 20 Hz - 20 kHz, ')
        f.write('within 50 dB of each branch peak)\n\n')
        for ch, e in verify:
            f.write(f'- {ch}: max err {e:.3f} dB\n')
        f.write(f'\nstim/golden: {len(stim)} ticks (0.40 s)\n')
    print(f'emitted {len(qsec)} sections; wrote hdl/jtmnymny_coeffs.hex, '
          f'hdl/jtmnymny_params.vh, stim/golden vectors, emit.md')
