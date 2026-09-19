# 1B11142 audio network analysis

`analyze.py` parses `nl_zac1b11142.cpp` (MAME's CC0 netlist of this exact
board, copied verbatim from `src/mame/zaccaria/`) and computes the exact AC
transfer function of every audio branch to the final output node:

- MNA with G + sC matrices; LM3900s as ideal Norton amps (v+=v-=0 AC,
  mirror constraint I- = I+); 4016/LS156/T7 as Ron switches.
- Poles = generalized eigenvalues of the (G, C) pencil — no curve fitting.
- Residues by least squares on exact samples; terms contributing <1e-4 of
  the band peak are pruned. Reduced-model error is reported per branch.
- Digital model: bilinear transform of the partial-fraction form at
  192 kHz = a parallel bank of 1st-order sections per branch.

Self-checks: stage poles land exactly on textbook corners (piano
R107*C49 = 159.2 Hz, basso R85*C45 = 1326 Hz, cassa R125*C62 = 284 Hz,
speech R49*C30 = 4130 Hz).

Run `python3 analyze.py` (numpy/scipy/matplotlib). Outputs in `out/`:
`report.md` (poles, balance table, quantization check, tromba source
model) and `bode_*.png` (exact vs digital overlay per branch and state).

Model parameters: Ron 4016 = 500R, LS156 sink = 25R, T7 sat = 30R,
P1/P2/P3 at 0.5. LS14 thresholds 1.6/0.8 V for the tromba pulse timing.
