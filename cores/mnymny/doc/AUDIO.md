# 1B11142 analog audio network — sheet 2/3 (PDF page 12)

Traced from `money_money.pdf` page 12 (local copy: `~/develop/zaccaria-sch/`;
untracked on purpose) and cross-checked against MAME's netlist model
`src/mame/zaccaria/nl_zac1b11142.cpp` (local tree `~/develop/mame`), which is a
complete machine-readable transcription of this sheet plus the speech/DAC
output stages of sheet 3. Where the two disagreed, the netlist won (it encodes
board-level fixes noted below). Both earlier TODOs are resolved by the netlist.

Status: connectivity settled. Analysis tooling in `ver/audio/` computes the
transfer functions and the digital-model coefficients from this data.

## Signal sources (left edge, all from sheet 1)

Each ANAL input has a 1K load to ground at entry.

| Net   | Source        | MAME device | Load | Branch |
|-------|---------------|-------------|------|--------|
| ANAL1 | AY 4G ch. A   | melodypsg1  | R133 | rullante + cassa (both taps off the same node) |
| ANAL2 | AY 4G ch. B   | melodypsg1  | R46  | basso |
| ANAL3 | AY 4G ch. C   | melodypsg1  | R71  | straight path, CONNECTED, SW1-switchable filter |
| ANAL4 | AY 4H ch. A   | melodypsg2  | R78  | piano |
| ANAL5 | AY 4H ch. B   | melodypsg2  | R66  | tromba (squarer + octave divider) |
| ANAL6 | AY 4H ch. C   | melodypsg2  | R47  | open jumper — never heard |

RESOLVED: MAME `zaccaria_a.cpp` routes melodypsg1 ch 0-2 to ANAL1/2/3 and
melodypsg1 port A to IOA0-4, i.e. 4G = melodypsg1. `jtmnymny_snd.v` matches
(u_ay4g outputs ay4g_a/b/c and drives `ioa`; u_ay4h drives
`level/levelt/sw1`). No wiring change needed.

## Control lines

| Net    | Core signal | Source          | Used by |
|--------|-------------|-----------------|---------|
| IOA0-2 | `ioa[2:0]`  | AY 4G port A    | LS156 4B ladder: TROMBA mix volume, 8 steps (NOT a master volume) |
| IOA3   | `ioa[3]`    | AY 4G port A    | 4016 5D pins 8/9: gates ANAL1 into the cassa branch |
| IOA4   | `ioa[4]`    | AY 4G port A    | 4016 5D pins 10/11: gates ANAL1 into the rullante branch |
| LEVEL  | `level`     | AY 4H port A b0 | T7 BC548 base via R68 10K: ducks the P1 node through R45 10K |
| LEVELT | `levelt`    | AY 4H port A b1 | tromba 5B1 bias (R109 10K into the R94/R108/R95 node): 2-level amplitude |
| SW1    | `sw1`       | AY 4H port B b0 | 4016 5D pins 3/4/5: switches C56 0.01u to ground in the ANAL3 path (netlist: "connection not shown on the schematic") |

Remaining 4016 5D section, pins 1/2/13: shorts R113 1M in the tromba 5B1
feedback, control pin 13 driven by U3A.5 — the LS74 divider's own Q. The
feedback is chopped at the note rate; see TROMBA below.

Component-value fixes encoded in the netlist (board vs schematic):
- R121 680R — schematic mislabels it "R128" (the cassa branch has both)
- R88 15K — schematic prints "15"
- C52, C53 22n — schematic prints "0,02u", not an E-series value
- BC548C for T6/T7

## The instrument branches

All amps are LM3900 Norton (current-differencing), NOT voltage op-amps:
"+" inputs are current-mirror diodes biased from VCC; derive transfer
functions current-mode. 5B/5C are the two LM3900 quad packages.

### RULLANTE (snare) — ANAL1
ANAL1 -> C63 0.01u -> 4016 (IOA4) -> R132 1K to gnd, R131 150K ->
LM3900 5C1 inverting: fb R130 33K, bias R120 47K (+)
-> out via R124 39K to node A.
Gated wideband path; the gate IS the trigger (AY noise plays through
while IOA4 is on). C63 into ~151K gives a ~105 Hz high-pass.

### CASSA (bass drum) — ANAL1 (same node, second tap)
ANAL1 -> 4016 (IOA3) -> R129 1K to gnd, R128 56K ->
LM3900 5C2: fb R125 560K + C62 1000p, input node also sees R126 470K
from VCC and R127 100K to gnd, bias R121 680R (+) — resonant low-pass
(the branch MAME's team fought to get right)
-> R123 1K -> C61 10u to gnd + C68 0.1u series -> R122 33K ->
LM3900 5C3: fb R104 120K, bias R102/R103 10K from VCC, R84 1K5
-> out via R105 56K to node A.

### BASSO — ANAL2
ANAL2 -> C29 0.1u -> R69 2K2 ->
5B4: fb R98 180K + C52 22n, bias R99 47K/R101 4K7/R100 1K
-> C53 22n -> R118 33K + C54 2.2u to gnd -> R83 2K2 ->
5C4: fb R85 120K + C45 1000p, bias R86 100K/R87 33K/R88 15K
-> out via R106 68K to node A.
Two cascaded low-passes with interstage RC shaping.

### PIANO — ANAL4
ANAL4 -> C41 0.1u -> R79 47K ->
5B2: fb C49 0.01u + R107 100K, bias R93 100K/R92 33K/R91 12K
-> out via R90 68K to node A.
Single low-pass.

### ANAL3 straight path — CONNECTED
ANAL3 -> R72 10K -> node with R70 10K and 4016 (SW1) switching C56 0.01u
to gnd -> C44 0.1u -> R82 10K -> node A.
Passive; SW1 adds the extra pole (tone control). This is a real sixth
voice, the exact `rc_en` pattern.

### ANAL6 — open jumper, not connected (netlist comments at least one
board has no link). Ignore.

### TROMBA (trumpet) — ANAL5, digital + switched-gain stage
Digital half:
ANAL5 -> R67 1K -> T6 BC548C squarer (C28 1000p, R40 100K, R64 4K7 pull) ->
U3A LS74 CLK; D/PRE pulled up via R65; Q (U3A.5) -> R39 220R -> C37 1u +
LS14 U4A1 in; U4A1 out -> /CLR. Q also drives 4016 pin 13.
The R39/C37/LS14//CLR loop makes Q a ~81 us pulse per T6 tone edge
(ver/audio numbers): D=1 always, so there is NO /2 division — pulses at
the tone rate. Q's pulse closes the 4016 across R113, resetting the 5B1
ramp: the tromba is a sawtooth-ish wave, tau = R113*C50 = 1 ms.

Analog half — NO signal input at all:
5B1 has DC bias only: "+" via R95 100K from the R94 10K(VCC)/R108 10K(gnd)
/R109 10K(LEVELT) node; "-" via R112 100K from R110 10K(VCC)/R111 8K2(gnd).
Feedback = R113 1M + C50 1000p, with the 4016 section (pins 1/2) across
it, chopped by Q. Output toggles between two DC levels:
  - switch on:  fb ~ Ron(4016), out ~ low level, tau = Ron*C50 (~us)
  - switch off: fb = 1M, out = high level, tau = R113*C50 ~ 1 ms
i.e. an asymmetric shark-fin square at half the T6 rate; LEVELT moves the
"+" bias current = two amplitudes. Exactly synthesizable: two-level
waveform + per-state one-pole slew.
-> out via R96 4K7 to node B.

## Mix topology (two nodes, then output sum — NOT one bus)

Node A: RULLANTE (R124 39K) + CASSA (R105 56K) + BASSO (R106 68K) +
PIANO (R90 68K) + ANAL3 path (R82 10K) + C40 0.1u (to node B via R97)
+ R77 10K -> 5B3 "+" (current mirror = AC ground).

Node B: TROMBA (via R96 4K7 from 5B1 out) + R97 150K (to C40/node A) +
LS156 4B ladder: one of R41 8K2 / R42 5K6 / R43 3K3 / R44 1K5 / R73 820R /
R74 390R / R75 150R / R76 47R switched to gnd by IOA0-2.
The ladder divides against R96 => 8 tromba volume steps, measured -35.3
to -67.6 dB end-to-end (ver/audio). Step index = {IOA0,IOA1,IOA2} read
MSB-first (bit-reversed ioa[2:0]), monotonic in that order. It barely
loads node A (through 150K). It is the TROMBA volume.

Master 5B3: gain = R115 82K / R77 10K from node A ("-" bias R116 47K from
R119 4K7/R117 1K divider) -> R114 4K7 -> P1 10K trimmer. T7 collector via
R45 10K across the P1 top node, base from LEVEL via R68 10K. Measured
(ver/audio): LEVEL=1 lowers the music mix by only 2.3 dB — a subtle duck,
not a mute; speech/DAC unaffected.

Output node (drives TDA1510, R1 100K to ~6V rail):
  - music:  P1 wiper -> R3 10K + C7 0.1u
  - speech: 5D4 out  -> R11 2K2 -> P2 10K pot -> R4 10K + C8 0.1u
  - DAC:    T4 stage -> R16 2K2 -> P3 10K pot -> R18 10K + C21 0.1u
Three symmetric 10K + 0.1u summing paths; P2/P3 are operator pots.

Speech stage (sheet 3, netlist `zac1b11142_schematics_speech`):
TMS5200 current out into C31 0.22u / R63 2K2 -> R62 220K -> C33 470p ->
R61 860K -> 5D4: fb R49 820K + C30 47p, bias R50 820K. Band-pass-ish:
~390 Hz high-pass, ~4.1 kHz low-pass.

DAC stage (sheet 3, netlist `zac1b11142_schematics_dac`): MC1408 current
out -> T4 2N4401 common-base (R13 3M3 to -5V, R15 3K3 load, R17 3K3,
C20 0.01u) -> R16 2K2 -> P3.

## What we model (plan)

Settled by the ver/audio analysis (all branch responses are smooth
real-pole shelving; no complex resonances anywhere):

1. `jtmnymny_mixer.v` implements each branch as a parallel bank of
   1st-order sections (y = a*y + b0*x + b1*x'), coefficients from
   analyze.py, 24-bit (18-bit shows up to 4 dB error on cassa/tromba;
   24-bit is <0.14 dB everywhere that matters). One time-multiplexed MAC
   serves all ~50 sections at 192 kHz. Branch inputs: ioa[3]/ioa[4]
   gated ANAL1, plus the tromba generator (pulse-reset ramp, LEVELT
   levels 0.6-3.9 V / 0.6-0.1 V, ladder gain by bit-reversed ioa[2:0]).
   LEVEL applies the measured -2.3 dB duck to the music sum.
2. mem.yaml `audio:` gets three pre-shaped channels - music, speech,
   dac - rsum 10k each (the three real 10K summing paths into R1);
   jtframe provides the 192 kHz cen, global pole, volume, peak/vu.
   Balance between the three comes from the analysis table (P2/P3 pot
   positions are free parameters, default 0.5 like MAME).
3. Sim-only per-branch mutes in the mixer for verification against
   MAME netlist WAV captures.

## Open items / verification

- [ ] Run `ver/audio/` analysis; review Bode plots per branch; freeze the
      digital approximation (which poles, where the biquad is, per-step
      gains).
- [ ] LM3900 single-supply clipping is asymmetric; if hardware recordings
      show clipping character, add saturation to the branch models.
- [ ] Speech/DAC balance: P2/P3 are operator pots; pick defaults by
      listening to hardware videos (MAME defaults both to 50%).
- [ ] Decide whether to model the TDA1510/speaker coupling high-pass
      (C10/C11 100u into speaker) — cheap and audible.
- [ ] Reference audio: MAME netlist WAV captures (attract + .inp scenes),
      then sim-core.sh audio compare.
- [ ] Speech cut short vs MAME: intro sentence truncated when the music
      starts ("you can go and ll…" instead of "…look for the money") and
      the capture cry says "help" once instead of "help help". Suspect
      TMS5200 /READY-INT timing or talk-status seen by the speech CPU
      (we stop or let it stop earlier than real hw). Investigate against
      MAME tms5220.cpp state machine.
