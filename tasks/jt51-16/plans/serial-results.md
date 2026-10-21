# JT51 #16 — existing-interface continuation, 2026-10-19

The CPU bus and existing inverted SO/SH1/SH2 capture wiring are sufficient for
this investigation. Additional package probes, another chip and a repeated
master-clock measurement are optional diagnostics. Earlier statements making
those prerequisites are withdrawn. The measured clock agrees with 32.22 MHz/9.

The resident monitor, FPGA configuration and CPU reset state were preserved.
Ten fresh readiness/pan/quiet captures qualified the interface. HPS boot ID is
`3e876240-d0e5-41cf-b52d-9c2d2a303a0c`, capture protocol `0x960104`, inversion 15,
LEFT latch0 and RIGHT latch1. New captures use fresh IDs and independently
checked transfer hashes, literal programs, raw16/PCM conversion, exponents,
monitor generation/reply chains and boot/tool identities. Prior sealed cases
remain unchanged.

## Held-note pitch

A frozen eleven-record C2 chain uses one full initialization per repetition.
Later records change only KC/MUL, retaining key/envelope/pan history. Three
independent repetitions yield 33 targets and three full stereo quiets. ROOT's
separate 36-record acquisition audit passes. Both latches pass the fixed
zero-crossing and Hann-FFT observer; maximum crossing error is0.017261 native
increments under the prospective 0.5 bound. Every quiet is exactly zero.

| Control | Physical increment | JT51 increment (e868 and fe6cad3) |
|---|---:|---:|
| KC49/MUL2 initial and return |15568|15568|
| KC4A/MUL1, either order, redundant writes and return |56|8248|
| KC4A/MUL0 |4124|4124|
| KC4A/MUL2 |16496|16496|
| KC4A/MUL3 |16552|24744|
| KC49/MUL1 return |7784|7784|

An independent audit binds all 243 earlier pitch cases to original CAP words
and rechecks FFT/crossing estimates. Eighteen very slow cases lack two rising
crossings and are explicitly ineligible for that estimator; all 243 qualify the
independent FFT bound. All literal programs select the intended registers.
The identical continuous public history qualifies the same observer while
retaining the differing ordinary-product frequencies.

This establishes a repeatable bench output relation, without claiming
normal YM2151 behavior or multiplier gate topology. The descriptive relation
subtracts 8192 for nonzero odd MUL when a pre-multiply base bit 13 is set. The earlier matrix includes 64 KF codes, eight
DT1 codes and four DT2 codes, but its DT1 values do not cross the bit boundary.
Two boundary-detune tests distinguish selection before versus after DT1; an
M1 mirror checks the operator generalization.
Those controls all pass in three repetitions on both outputs and select
the post-DT1 condition. An isolated candidate reproduces all 243 cases and
passes 542 composed public checks, but is rejected as a production correction:
Yamaha application notes page 7 explicitly specify 440.0Hz for the exact
KC4A/MUL1/DT1=DT2=PMS=KF=0 fixture at 3.579545MHz. Current JT51 produces
439.943Hz and passes a new five-check documentary regression; the experimental
patch fails four checks. Twelve direct mode1 SO/SH captures, independently
bit-center decoded, confirm that the near-static target is actually present
on the serial pins while 830/1310Hz positives and exact-zero quiets qualify.
Thus a mode3 export artifact alone cannot explain it. Chip identity/fault,
undocumented state and bench/control explanations remain unresolved; none
justifies changing global production pitch arithmetic to this one bench.
The experimental source, successes, documentary conflict and rejected
generality are archived explicitly. No additional bus probes or second chip
are required to record this finite disposition.

## Joint-key phase

The frozen new protocol keeps channel1 M1 continuously running on RIGHT before
channel0 is keyed. LEFT exposes channel0 operators on one uninterrupted capture
timeline. Subtracting the simultaneous RIGHT differential and initial M1
cancels constant latch age; no per-operator alignment or gain is fitted.
Three repetitions cover joint delay counts 0/1/2/3, reverse exposure, serial
cumulative forward/reverse keys and a LEFT leak control. The deterministic
CPU delays are history perturbations, not internal acceptance timestamps.

All 24 targets and 24 paired whole-record quiets pass ROOT's raw acquisition
audit. All 24 frozen observers qualify:15 joint controls reproduce approximately
+1 native sample for M2 relative to M1, with C1/C2 near zero; six serial controls
retain their measured key-order-dependent phases; three leak controls have
exact-zero LEFT and a bipolar RIGHT reference. The reference continuity and
M1 return pass the unchanged 0.001rad screen; carrier residuals pass0.003.

The older control round contains 12 qualified non-leak stereo target pairs
plus leak/quiet controls. Its previously scored RIGHT path retains the
approximately+1-for-all-three result. Re-reading LEFT from those same CAP
records reproduces the new (+1,0,0) pattern. Thus the apparent change between
protocols is explained by the output side, without invoking changed key
history. The absolute ordinal calendar and independent Go/Python fits remain
qualified. C1/C2 differ between sides by approximately one native sample
relative to M1, while M2 does not. This directly narrows the discrepancy to
stereo output assembly/timing; it does not justify an operator-reset patch.

Current-source public running-reference preflights qualify all eight profiles.
A separate bounded public diagnostic qualifies 72 target-KEY pulse cases
(widths1/2/3/4/8/16 at 12 boundary residues),24 delta-evaluation-order checks,
six leak controls and two baseline-identity captures. It yields only zero or
negative-prefix relative families, with no measured positive family. Default
wrapper PCM/events/bus logs remain byte-identical. Delta-order controls do not
constitute electrical half-cycle tests. No alternative enable ratio or
exhaustive electrical waveform coverage is claimed. The observer was frozen
before applying either model or physical targets.

The phase output discrepancy remains reproducible and depends on stereo
output assembly. An isolated accumulator candidate reproduces both stereo
families without changing PG/reset timing and passes the 37-check stereo
regression; baseline fails the two expected C1/C2 checks. However 96 saved
active-noise captures require exact zero-lag LEFT=RIGHT, whereas that first
candidate delays LEFT noise. It is rejected despite passing405 legacy checks.
A second provisional candidate supplies shared noise, but is also rejected:
saved C2/channel7 sine and NE roundtrip records require the same zero-lag
stereo age. A special noise-only exception is therefore unsupported.

A prospectively frozen reanalysis of all 96 saved LFO-baseline captures
provides the full32-route map, with three repetitions per operator/channel.
Every record passes the fixed2048-point observer and ROOT raw/input audit.
The final 2048 original samples are 14336..16383, with 128-point guards leaving
original 14464..16255; no alternate slice or fitted origin is selected.
The map is M1/all channels and M2/ch0–6 at age0; M2/ch7, C1/all channels
and C2/ch0–6 at age−1; C2/ch7 at age0. All 48 delayed records are within
−1.00349..−0.99413 native samples; worst relative RMS is0.001481 and
early/late differential change 0.000260rad. The map matches the declared
16-slot region exactly.

This places the accumulation boundaries one synthesis slot earlier than
the first candidate assumed: accumulator cycles31 for LEFT and 15 for RIGHT.
The published correction [fe6cad3](http://gitea.jotego.es/jotego/jt51/commit/fe6cad32067277418483c0694a781ff9ef78fb8b) uses those two complete windows with the original noise
substitution, requiring no special noise bypass or operator phase change. It
is merged to local master and verified on private tea/master and tea/jt51-16.
The frozen candidate passes all 405 legacy public checks in 14 groups, seven
phase controls and three native noise profiles. Each noise profile is bipolar
and has 16128/16128 same-ordinal LEFT/RIGHT matches. Standalone lint passes.
The permanent full32-route regression passes 183 checks, including23 analytic
controls. Baseline 01110fd fails only the 16 delayed age checks; both rejected
provisional candidates fail only the two channel7 age checks. The main
integrated checkout separately passes 160 route,23 observer and five nominal
pitch checks. Full dispatch has 593 checks, verified in composed groups with
identical legacy bodies, rather than one monolithic run. The complete map was already archived, so no new hardware mapping
campaign was needed. There is no supported arbitrary phase patch. Exact accepted-write timing is a conclusion
limit, not a requirement for more instrumentation. Rastan remains last.

## Consumer validation

Full-tree lint completed 98 logs with 12 skips. Its 19 diagnostic lines, including
repetitions, are exactly identical to the prior baseline: four pre-existing failing
cores and warnings in two other cores. No new diagnostic names JT51. Exit1
is retained rather than reported as a clean full-tree pass. The installed
Verilator 5.018 needs a process-local compatibility wrapper that removes only
the unsupported `--quiet-stats` argument. Initial wrapper-free attempts failed
at that tool option and are preserved separately. Contra compilation with
the corrected wrapper completes with exit0, zero errors/398 warnings,11534ALMs
and 62RAM blocks. Reported minimum setup/hold slack is3.305/0.250ns; all
reported summary slacks are positive. The final image is
`release/mister/jtcontra.rbf`,2581832 bytes, SHA256
`78c1188278471a52df6cac3b304386293ba2b783de629fe861e56ce928d34382`.
The complete log, summaries, reports, image and before/after source-byte pins
are archived. Generated version metadata predates the final source commit;
the actual RTL bytes are identical to the published correction.

## Evidence

New task session:
`/nobackup/tasks/jt51-16/round3-20261019-serial-controls/`.
The separate Drive case is
`/gdrive/jotego/reverse/YM2151/2026-10-19-jt51-16-serial-controls/`.
The completed case includes all raw captures, literal programs, frozen methods,
failed attempts, rejected hypotheses, public source and validation/build proof.
Every archive has per-member reread verification. The final source-validation
archive has 486 verified members, SHA256
`12820961c234d7954206a7e47563ef22bb584b245480ab50fad68292644ef0c9`.
Its initial verifier assumed regular files; an independent corrected verifier
checks the six tracked symlinks and their resolved contents without changing
the archive. No earlier sealed archive is modified.
