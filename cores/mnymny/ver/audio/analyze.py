#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
#
# 1B11142 audio network analysis for the jtmnymny core.
# Parses MAME's nl_zac1b11142.cpp (CC0, copied here), builds an exact AC
# model (MNA, ideal Norton LM3900), sweeps every branch and switch state,
# fits 192 kHz digital filters and prints jtframe-ready coefficients.
# Outputs: out/*.png Bode overlays, out/report.md

import re, sys, cmath, math
import numpy as np
from pathlib import Path

HERE = Path(__file__).parent
OUT  = HERE/"out"
FS   = 192000.0
RON4016 = 500.0   # CD4016 @5V supply
RON_TTL = 25.0    # LS156 open-collector sat
RON_SAT = 30.0    # BC548 saturated (T7 duck)
POT_POS = 0.5     # P1/P2/P3 default position

# ---------------------------------------------------------------- parser

def engval(expr):
    expr = expr.strip()
    m = re.match(r'(RES_K|RES_M|CAP_U|CAP_P|CAP_N)\(([\d.]+)\)', expr)
    if m:
        mult = {'RES_K':1e3,'RES_M':1e6,'CAP_U':1e-6,'CAP_N':1e-9,'CAP_P':1e-12}[m.group(1)]
        return float(m.group(2))*mult
    return float(expr)

class Netlist:
    def __init__(self):
        self.parent = {}          # union-find over terminal/net names
        self.R   = {}             # name -> (val, t1, t2)
        self.C   = {}
        self.POT = {}             # name -> val
        self.amps  = []           # LM3900 names
        self.cd4016 = []
        self.qbjt = {}            # name -> model
    def find(self, x):
        self.parent.setdefault(x, x)
        while self.parent[x] != x:
            self.parent[x] = self.parent[self.parent[x]]
            x = self.parent[x]
        return x
    def union(self, a, b):
        ra, rb = self.find(a), self.find(b)
        if ra != rb: self.parent[ra] = rb

def parse(path):
    txt = path.read_text()
    txt = re.sub(r'/\*.*?\*/', '', txt, flags=re.S)
    txt = re.sub(r'//.*', '', txt)
    nl = Netlist()
    for m in re.finditer(r'\bRES\((\w+),\s*([^)]+\)|[\d.]+)\)', txt):
        nl.R[m.group(1)] = engval(m.group(2))
    for m in re.finditer(r'\bCAP\((\w+),\s*([^)]+\)|[\d.]+)\)', txt):
        nl.C[m.group(1)] = engval(m.group(2))
    for m in re.finditer(r'\bPOT\((\w+),\s*([^)]+\)|[\d.]+)\)', txt):
        nl.POT[m.group(1)] = engval(m.group(2))
    for m in re.finditer(r'\bLM3900\((\w+)\)', txt):
        nl.amps.append(m.group(1))
    for m in re.finditer(r'\bCD4016_DIP\((\w+)\)', txt):
        nl.cd4016.append(m.group(1))
    for m in re.finditer(r'\bQBJT_EB\((\w+),\s*"([^"]+)"\)', txt):
        nl.qbjt[m.group(1)] = m.group(2)
    for m in re.finditer(r'\bNET_C\(([^)]+)\)', txt):
        terms = [t.strip() for t in m.group(1).split(',')]
        for t in terms[1:]:
            nl.union(terms[0], t)
    for m in re.finditer(r'\bALIAS\(([\w.]+),\s*([\w.]+)\)', txt):
        nl.union(m.group(1), m.group(2))
    return nl

# ------------------------------------------------------------- MNA solver

AC_GND = ['GND','VCC','I_P5','I_P12','I_M5','I_V0.Q',
          'I_P5.Q','I_P12.Q','I_M5.Q']
# CD4016 signal-pin pairs and their control pin
CD4016_SECTIONS = [((1,2),13), ((3,4),5), ((8,9),6), ((10,11),12)]
# 74156 as 3-to-8: C=IOA0 (pins 1,15), B=IOA1 (pin 3), A=IOA2 (pin 13)
# truth table (C,B,A) -> active-low output pin
LS156_PIN = { (0,0,0):9, (0,0,1):10, (0,1,0):11, (0,1,1):12,
              (1,0,0):7, (1,0,1):6,  (1,1,0):5,  (1,1,1):4 }
# ladder resistor on each pin (from NET_C list in the netlist)
LS156_RES = { 9:'R41', 10:'R42', 11:'R43', 12:'R44',
              7:'R73', 6:'R74', 5:'R75', 4:'R76' }

class Circuit:
    """One concrete AC configuration: switch states resolved, drives set."""
    def __init__(self, nl, ioa=0, ioa3=0, ioa4=0, sw1=0, tromba_chop=0,
                 level=0, remove_amps=(), pot=None):
        self.nl = nl
        self.remove_amps = set(remove_amps)
        self.edges = []   # (kind, val, netA, netB) kind: 'R','C'
        self.pot = pot or {}
        net = nl.find
        gnd = {net(g) for g in AC_GND if g in nl.parent}
        self.gndset = gnd
        for name, v in nl.R.items():
            self.edges.append(('R', v, net(f'{name}.1'), net(f'{name}.2')))
        for name, v in nl.C.items():
            self.edges.append(('C', v, net(f'{name}.1'), net(f'{name}.2')))
        for name, v in nl.POT.items():
            pos = self.pot.get(name, POT_POS)
            self.edges.append(('R', v*pos,     net(f'{name}.1'), net(f'{name}.2')))
            self.edges.append(('R', v*(1-pos), net(f'{name}.2'), net(f'{name}.3')))
        # 4016 sections: U5D control nets: 13=U3A.5(chop) 5=SW1 6=IOA3 12=IOA4
        st4016 = {13: tromba_chop, 5: sw1, 6: ioa3, 12: ioa4}
        for (pa, pb), ctl in CD4016_SECTIONS:
            if st4016[ctl]:
                self.edges.append(('R', RON4016, net(f'U5D.{pa}'), net(f'U5D.{pb}')))
        # LS156 ladder: ground the selected resistor's TTL pin
        c, b, a = ioa & 1, (ioa >> 1) & 1, (ioa >> 2) & 1
        pin = LS156_PIN[(c, b, a)]
        self.edges.append(('R', RON_TTL, net(f'U4B.{pin}'), 'AC_GND'))
        # T7 duck: shorts its collector node to ground when LEVEL=1
        if level:
            self.edges.append(('R', RON_SAT, net('T7.C'), 'AC_GND'))
        # collapse AC grounds
        e2 = []
        for k, v, na, nb in self.edges:
            na = 'AC_GND' if na in gnd else na
            nb = 'AC_GND' if nb in gnd else nb
            if na == nb: continue
            e2.append((k, v, na, nb))
        self.edges = e2

    def build(self, vdrive=None, idrive=None, probe='R1.1'):
        """Assemble MNA as G + s*C, RHS vector b, probe index."""
        nl = self.nl
        net = lambda t: ('AC_GND' if nl.find(t) in self.gndset else nl.find(t))
        amps = [a for a in nl.amps if a not in self.remove_amps]
        nodes = set()
        for _, _, na, nb in self.edges: nodes.update((na, nb))
        for a in amps:
            for pin in ('PLUS','MINUS','OUT'):
                nodes.add(net(f'{a}.{pin}'))
        drive_net = net(vdrive) if vdrive else None
        if drive_net: nodes.add(drive_net)
        inj_net = net(idrive) if idrive else None
        probe_net = net(probe)
        nodes.discard('AC_GND')
        # prune subnetworks with no path to ground or the drive
        adj = {}
        for _, _, na, nb in self.edges:
            adj.setdefault(na, set()).add(nb)
            adj.setdefault(nb, set()).add(na)
        for a in amps:
            p = [net(f'{a}.{x}') for x in ('PLUS','MINUS','OUT')]
            for x in p:
                adj.setdefault(x, set()).update(y for y in p if y != x)
        seen, stack = set(), ['AC_GND'] + ([drive_net] if drive_net else [])
        while stack:
            n = stack.pop()
            if n in seen: continue
            seen.add(n)
            stack.extend(adj.get(n, ()))
        nodes = sorted(n for n in nodes if n in seen)
        if probe_net not in nodes:
            raise RuntimeError(f'probe {probe} unreachable')
        idx = {n: i for i, n in enumerate(nodes)}
        N = len(nodes)
        namp = len(amps)
        M = N + 3*namp + (1 if drive_net else 0)
        G = np.zeros((M, M)); C = np.zeros((M, M)); b = np.zeros(M)
        def stampG(mat, na, nb, y):
            ia = idx.get(na, -1); ib = idx.get(nb, -1)
            if ia >= 0: mat[ia, ia] += y
            if ib >= 0: mat[ib, ib] += y
            if ia >= 0 and ib >= 0:
                mat[ia, ib] -= y; mat[ib, ia] -= y
        for k, v, na, nb in self.edges:
            if na not in idx and nb not in idx: continue
            if k == 'R': stampG(G, na, nb, 1.0/v)
            else:        stampG(C, na, nb, v)
        for ai, a in enumerate(amps):
            p, m_, o = (idx[net(f'{a}.{x}')] for x in ('PLUS','MINUS','OUT'))
            ip, im, io = N+3*ai, N+3*ai+1, N+3*ai+2
            G[p, ip] += 1       # KCL: current into amp
            G[m_, im] += 1
            G[o, io] -= 1       # amp drives node
            G[ip, p] = 1        # v(plus)=0
            G[im, m_] = 1       # v(minus)=0
            G[io, im] = 1       # mirror: I_m = I_p
            G[io, ip] = -1
        if drive_net:
            iv = M-1
            G[idx[drive_net], iv] += 1
            G[iv, idx[drive_net]] = 1
            b[iv] = 1.0
        if inj_net:
            b[idx[inj_net]] += 1.0
        return G, C, b, idx[probe_net]

    def solve(self, freqs, vdrive=None, idrive=None, probe='R1.1'):
        G, C, b, pi = self.build(vdrive, idrive, probe)
        res = np.zeros(len(freqs), dtype=complex)
        for fi, f in enumerate(freqs):
            x = np.linalg.solve(G + 2j*math.pi*f*C, b)
            res[fi] = x[pi]
        return res

# ------------------------------------------------- exact transfer function

FMAX_POLE = 1e6         # ignore poles beyond 1 MHz (parasitic of the pencil)

def exact_tf(circ, vdrive=None, idrive=None, probe='R1.1'):
    """Poles from the (G,C) pencil, residues by LS. Returns (poles, res, d)
    with H(s) = d + sum res_i/(s - p_i)."""
    import scipy.linalg as sla
    G, C, b, pi = circ.build(vdrive, idrive, probe)
    w = sla.eigvals(G, -C)
    w = w[np.isfinite(w)]
    w = w[np.abs(w) < 2*math.pi*FMAX_POLE]
    w = w[np.abs(w) > 1e-3]              # drop numerically-zero artifacts
    # dedupe (pencil can return conjugates slightly off)
    poles = []
    for p in w:
        if abs(p.imag) < 1e-6*abs(p.real): p = complex(p.real, 0.0)
        if p.imag < 0: continue          # keep upper half, mirror later
        poles.append(p)
    full = []
    for p in poles:
        full.append(p)
        if p.imag > 0: full.append(np.conj(p))
    full = np.array(full)
    # sample H exactly and solve for residues + direct term
    fs_ = np.logspace(0, 6, max(4*len(full)+8, 60))
    H = np.zeros(len(fs_), dtype=complex)
    for i, f in enumerate(fs_):
        H[i] = np.linalg.solve(G + 2j*math.pi*f*C, b)[pi]
    S = 2j*math.pi*fs_
    Amat = np.column_stack([1.0/(S-p) for p in full] + [np.ones(len(S))])
    Ar = np.vstack([Amat.real, Amat.imag])
    rr = np.concatenate([H.real, H.imag])
    sol, *_ = np.linalg.lstsq(Ar, rr, rcond=None)
    resid, d = sol[:-1], sol[-1]
    # verification + prune poles that contribute nothing in the audio band
    faud = np.logspace(1, math.log10(30000), 90)
    Saud = 2j*math.pi*faud
    Haud = np.zeros(len(faud), dtype=complex)
    for i, f in enumerate(faud):
        Haud[i] = np.linalg.solve(G + 2j*math.pi*f*C, b)[pi]
    ref = np.max(np.abs(Haud))
    keep = []
    for k, p in enumerate(full):
        term = np.max(np.abs(resid[k]/(Saud-p)))
        if term > 1e-4*ref: keep.append(k)
    full, resid = full[keep], resid[np.array(keep, dtype=int)]
    # re-solve residues on the kept set for a clean reduced model
    Amat = np.column_stack([1.0/(Saud-p) for p in full] + [np.ones(len(faud))])
    Ar = np.vstack([Amat.real, Amat.imag])
    rr = np.concatenate([Haud.real, Haud.imag])
    sol, *_ = np.linalg.lstsq(Ar, rr, rcond=None)
    resid, d = sol[:-1], sol[-1]
    Hm = Amat @ np.concatenate([resid, [d]])
    err = np.max(np.abs(20*np.log10(np.abs(Hm)+1e-15) - 20*np.log10(np.abs(Haud)+1e-15)))
    return full, resid, d, err

def tf_eval(poles, resid, d, freqs):
    S = 2j*math.pi*np.asarray(freqs)
    return d + sum(r/(S-p) for p, r in zip(poles, resid))

def bilinear_zpk(poles, resid, d, fs=FS):
    """Parallel-form bilinear transform: each term r/(s-p) -> 1st order z
    section; returns list of (b(2,), a(2,)) plus the direct gain."""
    K = 2*fs
    secs = []
    for p, r in zip(poles, resid):
        # r/(s-p) with s=K(z-1)/(z+1): r(z+1) / ((K-p)z - (K+p))
        a0 = (K - p); a1 = -(K + p)
        secs.append((np.array([r, r])/a0, np.array([1, a1/a0])))
    return secs, d

def digital_eval(secs, d, freqs, fs=FS):
    z = np.exp(2j*math.pi*np.asarray(freqs)/fs)
    H = np.full(len(z), complex(d))
    for b, a in secs:
        H = H + (b[0] + b[1]/z)/(a[0] + a[1]/z)
    return H

# ------------------------------------------------------------ z-domain fit

def fit_iir(freqs, H, nb, na, fs=FS, iters=30):
    """Sanathanan-Koerner complex LS fit of B(z)/A(z), returns (b, a)."""
    z = np.exp(2j*math.pi*np.asarray(freqs)/fs)
    W = np.ones(len(z), dtype=complex)
    b = np.zeros(nb+1); a = np.zeros(na+1); a[0] = 1
    for _ in range(iters):
        # rows: [z^-0..z^-nb, -H z^-1..-H z^-na] * [b; a1..ana] = H
        cols = [z**(-k) for k in range(nb+1)] + [-H*z**(-k) for k in range(1, na+1)]
        Ac = np.column_stack(cols) / W[:, None]
        rhs = H / W
        Ar = np.vstack([Ac.real, Ac.imag])
        rr = np.concatenate([rhs.real, rhs.imag])
        sol, *_ = np.linalg.lstsq(Ar, rr, rcond=None)
        b = sol[:nb+1]
        a = np.concatenate([[1.0], sol[nb+1:]])
        # stabilize
        if na:
            p = np.roots(a)
            p = np.where(np.abs(p) >= 1, 1/np.conj(p), p)
            a = np.real(np.poly(p))
        W = np.polyval(a[::-1], 1/z)  # 1/|A| weighting next round
    return b, a

def freqz(b, a, freqs, fs=FS):
    z = np.exp(2j*math.pi*np.asarray(freqs)/fs)
    return np.polyval(b[::-1], 1/z) / np.polyval(a[::-1], 1/z)

def pole_fc(p):
    """equivalent RC corner of a real z-pole (jtframe_pole convention)"""
    if p <= 0 or p >= 1: return None
    wc = (1-p)/(1+p)                     # bilinear inverse of a=(1-wc)/(1+wc)
    return math.atan(wc)*FS/math.pi

def jtframe_a(fc):
    """jtframe mem.yaml calc_a replica: 15-bit coefficient for corner fc"""
    wc = math.tan(math.pi*fc/FS)
    a = round((1.0-wc)/(wc+1.0)*(2**15-1))
    return max(a, 0)

# ----------------------------------------------------------------- runner

def db(x): return 20*np.log10(np.maximum(np.abs(x), 1e-15))

def main():
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt

    nl = parse(HERE/'nl_zac1b11142.cpp')
    freqs = np.logspace(math.log10(5), math.log10(80000), 400)
    report = []
    models = {}   # name -> list of (label, poles, resid, d)

    def run(name, cfg, drive, states=None, idrive=None, remove=()):
        rows = []
        for label, over in (states or [('', {})]):
            c = Circuit(nl, remove_amps=remove, **{**cfg, **over})
            H = c.solve(freqs, vdrive=None if idrive else drive, idrive=idrive)
            poles, resid, d, err = exact_tf(c, vdrive=None if idrive else drive,
                                            idrive=idrive)
            secs, dd = bilinear_zpk(poles, resid, d)
            Hd = digital_eval(secs, dd, freqs)
            rows.append((label, H, Hd, poles, resid, d, err))
            models.setdefault(name, []).append((label, poles, resid, d))
        fig, ax = plt.subplots(figsize=(9, 5))
        for label, H, Hd, poles, resid, d, err in rows:
            l, = ax.semilogx(freqs, db(H), label=f'{label or name} exact')
            ax.semilogx(freqs, db(Hd), '--', color=l.get_color(),
                        label=f'digital 192k (model err {err:.2f} dB)')
        ax.set_xlabel('Hz'); ax.set_ylabel('dB')
        ax.grid(True, which='both', alpha=.3)
        ax.legend(fontsize=8)
        ax.set_title(f'{name} -> final output node (R1)')
        fig.tight_layout(); fig.savefig(OUT/f'bode_{name}.png', dpi=110)
        plt.close(fig)
        report.append((name, rows))
        return rows

    base = dict(ioa=0, ioa3=0, ioa4=0, sw1=0, tromba_chop=0, level=0)

    run('rullante', {**base, 'ioa4': 1}, 'ANAL1')
    run('cassa',    {**base, 'ioa3': 1}, 'ANAL1')
    run('basso',    base, 'ANAL2')
    run('piano',    base, 'ANAL4')
    run('anal3',    base, 'ANAL3',
        states=[('sw1=0', {}), ('sw1=1', {'sw1': 1})])
    # tromba path: 5B1 removed, drive its OUT node, 8 ladder steps
    # volume index v = {IOA0,IOA1,IOA2} MSB-first (monotonic); the ioa arg
    # is raw ioa[2:0], i.e. v bit-reversed
    lad = [(f'vol{v}', {'ioa': ((v & 4) >> 2) | (v & 2) | ((v & 1) << 2)})
           for v in range(8)]
    run('tromba',   base, 'U5B1.OUT', states=lad, remove=('U5B1',))
    run('speech',   base, None, idrive='C31.1')
    run('dac',      base, None, idrive='T4.C')
    run('duck',     base, 'ANAL4',
        states=[('level=0', {}), ('level=1', {'level': 1})])

    # ---------------------------------------------- quantization check
    # parallel 1st-order sections, a as 0.18 unsigned, b as 18-bit signed
    # with a shared per-branch power-of-2 scale
    def quant(secs, d, nb=18):
        qs = []
        bmax = max(max(abs(b[0]), abs(b[1])) for b, a in secs) if secs else 1
        exp = max(0, math.ceil(math.log2(max(bmax, abs(d), 1e-30))))
        sc = 2.0**(nb-1-exp)
        for b, a in secs:
            qa = round(-a[1].real*(1 << nb))/(1 << nb)
            qb0 = round(b[0].real*sc)/sc
            qb1 = round(b[1].real*sc)/sc
            qs.append((np.array([qb0, qb1]), np.array([1, -qa])))
        return qs, round(d.real*sc)/sc if hasattr(d, 'real') else round(d*sc)/sc

    # ---------------------------------------------- tromba source model
    # LM3900 5B1: DC levels of the chopped-feedback stage per LEVELT
    def tromba_levels():
        VBE = 0.6; VCC5 = 5.0
        R94 = 10e3; R108 = 10e3; R109 = 10e3; R95 = 100e3
        R110 = 10e3; R111 = 8.2e3; R112 = 100e3; R113 = 1e6
        VE = VCC5*R111/(R110+R111)
        i112 = (VE-VBE)/R112
        out = {}
        for lt in (0, 1):
            if lt:
                rp = R94*R109/(R94+R109)
                VD = VCC5*R108/(R108+rp)
            else:
                rp = R108*R109/(R108+R109)
                VD = VCC5*rp/(R94+rp)
            ip = (VD-VBE)/R95
            vhi = VBE + (i112-ip)*R113
            vhi = min(max(vhi, 0.1), VCC5-1.1)   # LM3900 swing clamp
            out[lt] = (VBE, vhi)                 # (chop-on level, chop-off target)
        return out

    # LS74 Q duty from the R39/C37/LS14 clear loop
    def tromba_pulse():
        R39 = 220.0; C37 = 1e-6; tau = R39*C37
        VOH, VOL, VTP, VTM = 3.4, 0.2, 1.6, 0.8
        t_hi = tau*math.log((VOH-VTM)/(VOH-VTP))   # Q high until /CLR fires
        t_rec = tau*math.log((VTP-VOL)/(VTM-VOL))  # recovery before /CLR releases
        return t_hi, t_rec

    # ------------------------------------------------------------- report
    i1k = np.argmin(np.abs(freqs-1000))
    with open(OUT/'report.md', 'w') as f:
        f.write('# 1B11142 exact AC analysis (MNA pencil poles)\n\n')
        f.write(f'Ron4016={RON4016} ohm, TTL sink={RON_TTL} ohm, ')
        f.write(f'T7 sat={RON_SAT} ohm, pots at {POT_POS}.\n')
        f.write('Voltage-driven branches: dB rel. 1V at the AY pin. ')
        f.write('speech/dac are current-driven (dB rel. 1A - scale later).\n\n')
        for name, rows in report:
            f.write(f'## {name}\n\n')
            for label, H, Hd, poles, resid, d, err in rows:
                ipk = np.argmax(np.abs(H))
                f.write(f'- {label or "single state"}: |H(1k)|={db(H[i1k]):+.1f} dB, '
                        f'peak {db(H[ipk]):+.1f} dB @ {freqs[ipk]:.0f} Hz, '
                        f'reduced-model err {err:.3f} dB\n')
                for p in poles:
                    fp = abs(p)/2/math.pi
                    if p.imag == 0:
                        f.write(f'  - pole {fp:8.1f} Hz (real)\n')
                    elif p.imag > 0:
                        q = abs(p)/(2*abs(p.real)) if p.real != 0 else 1e9
                        f.write(f'  - pole {fp:8.1f} Hz  Q={q:.2f}\n')
            f.write('\n')

        # channel balance at each branch's own passband peak
        f.write('## Channel balance (pots at 0.5)\n\n')
        f.write('dB re full-scale source: AY branches re 1V at pin, ')
        f.write('speech re 750uA, dac re 1mA (MAME stream scales).\n\n')
        f.write('| channel | peak dB | @ Hz | 1 kHz dB |\n|---|---|---|---|\n')
        scale = {'speech': 750e-6, 'dac': 1e-3}
        for name, rows in report:
            if name == 'duck': continue
            for label, H, Hd, poles, resid, d, err in rows:
                k = 20*math.log10(scale.get(name, 1.0))
                ipk = np.argmax(np.abs(H))
                f.write(f'| {name} {label} | {db(H[ipk])+k:+.1f} | '
                        f'{freqs[ipk]:.0f} | {db(H[i1k])+k:+.1f} |\n')
        f.write('\n')

        # quantization feasibility of the parallel form at 192 kHz
        f.write('## Coefficient quantization check (parallel form, 192 kHz)\n\n')
        f.write('| branch | sections | 18-bit err dB | 24-bit err dB |\n')
        f.write('|---|---|---|---|\n')
        band = (freqs >= 20) & (freqs <= 20000)
        for name, rows in report:
            for label, H, Hd, poles, resid, d, err in rows:
                secs, dd = bilinear_zpk(poles, resid, d)
                es = []
                for nb in (18, 24):
                    qs, qd = quant(secs, dd, nb)
                    Hq = digital_eval(qs, qd, freqs)
                    es.append(np.max(np.abs(db(Hq[band]) - db(Hd[band]))))
                f.write(f'| {name} {label} | {len(secs)} | '
                        f'{es[0]:.3f} | {es[1]:.3f} |\n')
        f.write('\n')

        lv = tromba_levels()
        th, tr = tromba_pulse()
        f.write('## Tromba source model (time domain)\n\n')
        f.write(f'- Q pulse: high {th*1e6:.0f} us per T6 tone edge, ')
        f.write(f'recovery {tr*1e6:.0f} us (R39*C37 + LS14 thresholds)\n')
        f.write('- LS74 D=1 always: pulses at the TONE rate, no /2 division\n')
        f.write(f'- chop ON  (Q=1): out ~= {lv[0][0]:.2f} V, tau = Ron*C50 (~0.5 us)\n')
        f.write(f'- chop OFF (Q=0): ramps to target with tau = R113*C50 = 1 ms\n')
        f.write(f'- target LEVELT=0: {lv[0][1]:.2f} V (clips high)\n')
        f.write(f'- target LEVELT=1: {lv[1][1]:.2f} V (near low rail)\n')
        f.write('- => sawtooth-ish ramps reset by narrow pulses; amplitude\n')
        f.write('  depends on note period vs 1 ms tau; LEVELT flips loud/soft\n')
    print(f'wrote {OUT}/report.md and bode_*.png')
    if '--emit' in sys.argv:
        import emit
        emit.emit(models, freqs)

if __name__ == '__main__':
    main()
