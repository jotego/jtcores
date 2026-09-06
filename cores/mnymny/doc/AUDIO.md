# 1B11142 analog audio network — sheet 2/3 (PDF page 12)

Everything below was read directly off `money_money.pdf` page 12 (local copy:
`~/develop/zaccaria-sch/money_money.pdf`; the doc/sch/ folder is untracked and
ignored on purpose). Cross-references: sheet 1/3 (melody CPU + AYs, page 11),
sheet 3/3 (speech CPU + TMS5200 + MC1408, page 13), digest in
`~/develop/zaccaria-sch/1b11142-audio.md`.

Status: connectivity fully traced. TODO markers note the two spots to
re-verify at higher zoom before coding. Nothing of this is modelled in the
core yet — the mixer is still the crude `aysum` in jtmnymny_game.v.

## Signal sources (left edge, all from sheet 1)

Each ANAL input has a 1K load to ground at entry.

| Net   | Source        | Load | Branch |
|-------|---------------|------|--------|
| ANAL1 | AY 4G ch. A   | R133 | rullante + cassa (both taps off the same node) |
| ANAL2 | AY 4G ch. B   | R46  | basso |
| ANAL3 | AY 4G ch. C   | R71  | straight path 1 (jumper) |
| ANAL6 | AY 4H ch. C   | R47  | straight path 2 (jumper) |
| ANAL4 | AY 4H ch. A   | R78  | piano |
| ANAL5 | AY 4H ch. B   | R66  | tromba (squarer + octave divider) |

NOTE: sheet-1 digest says AY 4H (melodypsg1 in MAME) outputs are ANAL4/5/6 and
AY 4G (melodypsg2) are ANAL1/2/3. In the core, `ay4g_*`/`ay4h_*` port names
follow the schematic refdes: 4G = melodypsg2 = ANAL1/2/3, 4H = melodypsg1 =
ANAL4/5/6. Keep this straight when wiring filters: the *drums/basso* come from
the PSG whose port A carries IOA0-4 (4G per core naming). Double-check against
jtmnymny_snd.v port A/B assignments when coding.

## Control lines (from the AY I/O ports, sheet 1)

| Net    | Core signal | Used by |
|--------|-------------|---------|
| IOA0-2 | `ioa[2:0]`  | LS156 4B volume ladder select (8 steps) |
| IOA3   | `ioa[3]`    | 4016 5D section pins 8/9: gates ANAL1 into the cassa branch |
| IOA4   | `ioa[4]`    | 4016 5D section pins 10/11: gates ANAL1 into the rullante branch |
| LEVEL  | `level`     | T7 BC548 base (via R45 10K): shunts/ducks the master node at P1 |
| LEVELT | `levelt`    | Tromba stage input network bias (R108/R111 8K2 node) |

Two more 4016 5D sections exist on this sheet (it is a quad switch):
- pins 3/4/5: switches C56 0.01u to ground in the ANAL3 straight path
  (tone filter on/off). TODO: control net label needs re-check at zoom —
  candidates are IOA of the second AY port or a strap.
- pins 1/2: shorts R113 1M in the tromba 5B feedback (level/timbre switch).
  TODO: same — the wire runs toward the LEVELT/IOA region; verify which.

Node "2 (SH3)": the speech/DAC audio arrives from sheet 3 into the master
summing node through R3 10K + C7 0.1u.

## The five instrument branches

All amps are LM3900 Norton (current-differencing) amplifiers, NOT voltage
op-amps: every "+" input is biased with a resistor to VCC and the transfer
functions must be derived current-mode. Sections named 5B/5C are the two
LM3900 quad packages.

### RULLANTE (snare) — ANAL1
ANAL1 -> C63 0.01u + R133 1K -> 4016 (IOA4) -> R131 150K ->
LM3900 5C inverting stage: fb R130 33K, input leg R132 1K, bias R120 47K
-> out via R124 39K to mix bus.
Character: gated wideband/high-pass-ish path; the gate IS the instrument
trigger (AY noise plays through it while IOA4 is on).

### CASSA (bass drum) — ANAL1 (same node, second tap)
ANAL1 -> 4016 (IOA3) -> LM3900 5C stage A: fb R125 560K + C62 1000p,
network R126 470K / R128 56K / R127 100K / R129 1K / 680R — a resonant
low-pass (this is the "missing cassa" MAME's netlist struggled with)
-> coupling R123 1K + C68 0.1u + C61 10u ->
LM3900 5C stage B: fb R104 120K, in R122 33K, R102/R103 10K, R84 1K5
-> out via R105 56K to mix bus.

### BASSO — ANAL2
ANAL2 -> C29 0.1u + R69 2K2 ->
5B stage: fb R98 180K + C52 0.02u, R99 47K, bias R101 4K7 / R100 1K
-> C53 0.02u + R118 33K + C54 2.2u (series RC coupling with big cap) ->
R83 2K2 -> 5C stage: fb R85 120K + C45 1000p, R86 100K, R87 33K / R88 15
-> out via R106 68K to mix bus.
Two cascaded low-pass stages: bass reinforcement.

### PIANO — ANAL4
ANAL4 -> C41 0.1u + R79 47K ->
5B stage: fb C49 0.01u + R107 100K, R93 100K, bias R92 33K / R91 12K
-> out via R90 68K to mix bus.
Single gentle low-pass / tone shaping.

### TROMBA (trumpet) — ANAL5
ANAL5 -> R67 1K -> T6 BC548 squarer (C28 1000p, R40 100K)
-> 3A LS74 divide-by-2 (clocked by the squared AY tone: OCTAVE DIVIDER)
-> 4A LS14 buffer ->
resistor network R94/R110 10K, R112/R95 100K, R108 10K x2, R111 8K2 with
LEVELT biasing the node (2-level volume for the trumpet)
-> 5B stage: fb R113 1M + C50 1000p, with a 4016 section shorting R113
(see TODO above) -> R96 4K7 -> R97 150K + C40 0.1u -> TROMBA net -> mix bus.
The digital half (squarer + LS74) is exact to implement; only the output
stage is analog.

### Straight paths — ANAL3, ANAL6
ANAL3 -> R72 10K -> R70 10K + C44 0.1 (+ C56 0.01 switchable to gnd via
4016) -> R82 10K -> jumper pad 1/2.
ANAL6 -> R48 10K + C42 0.1u -> R81 10K -> R80 10K -> same pads.
Jumper open on monymony/jackrabt per MAME ("#1 ch C disabled, open
jumper") — confirm which pad state the board uses; likely both paths
unused, i.e. these two AY channels are never heard directly.

## Mix bus, master volume, power amp (right side)

1. All branch outputs (R124 rullante, R105 cassa, R106 basso, R90 piano,
   tromba via R96/R97) plus speech (R3 from SH3) sum into one node.
2. LS156 4B + ladder R41 8K2, R42 5K6, R43 3K3, R44 1K5, R73 820R,
   R74 390R, R75 150R, R76 47R: one of eight resistors switched to ground
   on the bus node by IOA0-2 = 8-step master attenuator (log-ish steps).
3. Master LM3900 5B stage: fb R115 82K, in R116 47K + R77 10K,
   bias R117 1K / R119 4K7.
4. R114 4K7 -> P1 10K trimmer; T7 BC548 collector across the wiper node,
   base driven by LEVEL through R45 10K: AY-controlled duck/mute.
5. P1 wiper -> TDA1510 2B bridge amp (pins 1/2 in; 4/3 +12V; C9 47u,
   C6 0.22u), outputs pins 6/9 -> SPK0/SPK1 with C10/C11 100u series,
   C12/C13 0.1 + R5/R6 4.7R zobels, R8/R10 100K, R9 2K2 + C14 4.7u fb.
6. Supplies: +12 via D1 1N4004, +5/-5, C1 2200u reservoir.

## What we need to model (plan)

Target: replace `aysum` in jtmnymny_game.v with a filter section fed by the
existing per-channel outputs of jtmnymny_snd.v (ay4g_a/b/c, ay4h_a/b/c,
speech, dac) and the existing controls (ioa[4:0], level, levelt).

1. Derive each branch's transfer function with LM3900 current-mode math
   (NOT ideal-op-amp): rullante (1 stage), cassa (2 stages, resonant),
   basso (2 stages), piano (1 stage), tromba output stage (1 stage +
   the R113-short switch). Get pole/zero or biquad coefficients.
2. Bilinear-transform each to the audio sample rate and implement as
   fixed-point IIR sections (jtframe has jtframe_fir for FIR; for IIR
   check jtframe_pole / existing RC filter helpers first — several cores
   model RC low-passes already; reuse whatever exists).
3. Tromba digital half exactly: comparator on ay4h_b (schematic 4G/4H
   naming caveat above), LS74 toggle, LS14 — a square wave at half the
   channel frequency, amplitude set by levelt (2 levels).
4. Gates: ioa[3]/ioa[4] multiply rullante/cassa inputs (4016 = clean
   analog switch, model as on/off with maybe a 1-pole click filter).
5. Mix with the branch output resistor weights (R124 39K, R105 56K,
   R106 68K, R90 68K, tromba R96+R97 divider, speech R3 10K) into the
   summing node conductance-weighted.
6. LS156 attenuator: 8 gain values from the ladder + node impedance
   (compute the actual voltage division per step), indexed by ioa[2:0].
7. LEVEL duck (T7): a gain switch on the master (compute ratio from
   P1/R114/T7 saturation; on hardware it is a hard duck).
8. Straight paths ANAL3/ANAL6: leave disconnected (open jumper) unless
   hardware listening says otherwise.
9. mem.yaml audio: section: jtframe supports declaring audio channels
   with gains/filters — check jtframe/doc/audio.md for the current
   syntax and whether custom IIR modules can be referenced per channel;
   otherwise instantiate the filters in jtmnymny_game.v and feed jtframe
   one pre-mixed signal per rail as today.

## Open items / verification

- [ ] Re-check at high zoom the control nets of 4016 sections pins 3/4/5
      (ANAL3 C56) and pins 1/2 (tromba R113 short). PDF page 12, centre
      bottom and top-left area.
- [ ] Confirm 4G/4H vs melodypsg1/2 vs ANAL mapping against
      jtmnymny_snd.v before wiring (see NOTE above).
- [ ] Jumper pads 1/2 state on the real board (photo or listening test).
- [ ] LM3900 bias currents set output DC points; for AC modelling we can
      ignore DC but the 3900's single-supply clipping is asymmetric — if
      hardware recordings show clipping character, model saturation.
- [ ] Speech path level: R3 10K into the bus + P2/P3 pots on sheet 3
      (speech/DAC levels) — pots mean the "correct" balance is whatever
      the operator set; pick MAME-free defaults by listening to hw video.
- [ ] TDA1510 + speaker: decide whether to model the output coupling
      high-pass (C10/C11 into speaker impedance) — cheap and audible.
