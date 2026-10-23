# Algorithms, feedback and jointly keyed output phase

Measurement work for [jtcores #143](http://gitea.jotego.es/jotego/jtcores/issues/143).
Production jt51 is unchanged at `985a573dcfc1ff135553a39f7eae21d18ba57cbe`;
the independent whole-output reference is Nuked-OPM
`a0ab44be60cb28b68431779829454ddf3284f272`. No reference arithmetic or
feedback recurrence was imported into the stimulus or analysis tools.

The 229-profile physical matrix and separate phase controls are complete.
Each profile has three independently initialized targets and three paired
quiet recordings. All 229 profiles have completed on both frozen models.
Physical/model waveform differences
remain observations with explicit relative-phase uncertainty, not new RTL fixes.

## Primary stimulus and coverage

The Yamaha application notes specify CON/FL at printed7/PDF8, the eight graphs
in Fig2.9 and nominal feedback settings in Fig2.10 at printed18/PDF19. The
nominal feedback table is OFF, pi/16, pi/8, pi/4, pi/2, pi, 2pi, 4pi; these
labels are not a reference digital recurrence. Primary KEYON and operator
register order differ: offsets0/8/16/24 for M1/M2/C1/C2 use masks08/20/10/40.
ACC at printed14/PDF15 assigns bit6 LEFT and bit7 RIGHT. Actual latch0/latch1
therefore map to left/right. The primary graph transcription is preserved as
source fixture `host/testdata/algorithm-graphs.json` and as original evidence
under `artifacts/algorithms-feedback`; the source fixture is not measured data.

`host/algorithm_programs.go` emits the following 229 unique profiles:

| Group | Profiles | Scope |
|---|---:|---|
| Tagged all-operator | 64 | All eight ALG times all eight FB settings |
| Single operator | 32 | Each operator alone, each ALG, FB0 |
| Feedback isolation | 28 | Each operator alone, ALG7, FB1..7 |
| Remaining subsets | 88 | All remaining key masks, each ALG, FB0 |
| Static stereo | 9 | Pan00/40/80, ALG0/4/7, all keyed, FB0 |
| Full-level feedback | 8 | M1 alone at TL0, ALG7, FB0..7 |

Together the first, second and fourth groups include all16 key masks times
all8 ALG at FB0. Default TL tags are M1=32, M2=48, C1=40, C2=24. All voices
use KC4A/KF0, DT1/DT2zero, MUL0, AR31/KS0 and held D1R0/D2R0/D1L0. Only
channel0 is audible; TEST/noise/LFO/CSM/timers and every other channel/operator
register are explicit. Native increment4124 was independently qualified by
the earlier carrier measurements. Full-level M1 stress is a separate group.
High feedback receives no assumed period.

Every target uses a complete register initialization and empty EVENT00.
The physical cleanup first disables noise, writes every RR15 before all8
KEYOFFs, waits a measured >=0.5 seconds after the reply, and captures independent
native quiet on both outputs before target INIT. Target INIT contains the
8192-count CPU preheat plus an observed post-reply settling interval. Model
INIT deliberately contains an explicit1790016-master-clock cleanup dwell and
262144-master-clock preheat. CPU delay counts are not equated to model clocks.
This cleanup was qualified for the pre-CSM campaign only: after active CSM,
use the separately qualified stop-CSM-first cleanup instead.

All targets and paired quiet recordings have16384 stereo frames, native stride1,
about0.293s at nominal55937.5Hz. The user's on-pin3.57..3.58MHz measurement
with0.01MHz tolerance supports nominal3580000Hz; sample-domain observations
remain primary. Both capture and independent raw decoders correct the
open-drain inverter polarity. No anti-alias filter is introduced.

## Absolute output descriptors and finite qualification

`host/algorithm_score.go` projects public PCM onto fixed sine/cosine harmonics
plus DC, with H64 at native4124/2^20. Training is samples8192..16384; earlier
holdout1024..5120 is never used to select the phase origin. An analytic
finite-window Gram matrix retains nonorthogonal-window effects. Preserve
absolute DC, amplitudes, powers, RMS, residual, own holdout prediction and
unaligned prediction curves. A projection does not prove periodicity; intrinsic
native aliases and high-feedback aperiodic output remain possible.

A model comparison permits one shared global phase origin fitted on training
and checked unchanged on holdout. Gain and DC correction, per-operator or
per-harmonic phases, cycle alignment, per-window timing and phase-exposure
correction are excluded. Quiet output has null phase support. Numerically
equivalent origins remain explicit. Supported harmonic phase invariants require
both amplitudes>=32PCM; absent support is null, never a zero phase or pass.

Original qualification includes96 known multiharmonic signals (maximum
coefficient error0.813768PCM, own holdout4.64005PCM),12 independently
Bessel-checked nonlinear signals,12 one-origin positives and four gain/DC/
harmonic/pre-event-phase negatives. Eight primary-graph mathematical toys
separate tagged graphs while equal-operator ALG2/3 are intentionally degenerate;
their arbitrary toy gain12 is not a YM2151 oracle. Symmetry, subharmonics,
drift, irregular waveforms and low signal controls preserve unresolved states.
Of60 low-level sine tests,56 qualify and four amplitude128/Q16 cases remain
resolution-limited. A deliberately wrong3900 increment is measured as3900.
Twelve malformed CLI/CSV/bounds/reused-output cases reject.

The2PCM coefficient and17PCM holdout screens are finite synthetic method guards.
They are not chip-conformance bands. A real capture outside either synthetic
screen must not automatically become a production defect. Original model
ALG0..6 differences of5.43974..29.49478PCM survive the single global origin;
they are retained unchanged despite later phase diagnostics.

## Jointly keyed phase controls

The separate `host/algorithm_phase_programs.go` fixtures jointly key all4
operators, keep them keyed in ALG7/FB0, and expose one TL0 operator at a time
while the others remain TL127. Forward and reverse sequences both return to
M1. Four LEFT mute markers bracket mute-old-before-unmute-new transitions;
RIGHT retains one continuous sample timeline. Exclude each complete marker
and128 retained samples on either side. A brief intentional zero/tiny interval
inside a marker is not an unbroken audible carrier. TL127 leak is measured
separately instead of assumed zero. The known OPM dynamic-pan difference
remains a caveat, and LEFT is not substituted for the RIGHT phase reference.

`host/algorithm_phase.go` fits sine/cos/DC at recorded increment32992, stride8,
to supported exposure interiors of at least1000 samples. Independent96
native-integrated synthetic controls include both orders, global phase, latch
age, generic phase/PCM quantization and tiny inactive leakage. The fixed0.001rad
relative-phase screen passes (maximum error0.000261072rad); intentional0.01rad
M1-return changes are detected. Quiet/short signals remain unobservable.

The physical campaign contains36 records: two distinct preheats8192/16384
counts times forward/reverse/leak times three repetitions, each preceded by
independent quiet. Model-only prefix0/1 probes are not duplicate physical
coverage. All18 cleanup records are entirely zero; all6 leak records are zero.
All12 exposures retain valid interiors, minimum1537 points, and actual host
final-event upper-bound+128 leaves at least6248 retained samples. All60 free
sine fits support32992 (range32991.962508..32992.035244), maximum relative RMS
0.001479; maximum M1-return difference4.189023e-5rad.

PCB M2/C1/C2 phases relative to initial M1 are consistently positive
0.0245232..0.0248068rad across both orders, preheats and repetitions. One native
sample at increment4124 is0.02471147rad, or one eighth of a stride8 retained
sample. Original model families are zero/negative. These are output phases;
accepted physical key-on bus phase and internal phase/mixing state are unobserved.
No relative phases are fitted away in the complex algorithm comparisons.

`host/sine_fit.go` and `host/sine_frequency.go` independently measure free sine
frequency from positive crossings followed by sine/cos/DC least squares. No
expected frequency is an input. The Go calculation numerically reproduces all60
original Python physical fits: maximum increment difference9.863e-7 and phase
difference2.793e-8rad. The original physical analysis remains the frozen Python
result. Independent36 ordinary tones and96 native-integrated records/480 fits
preserve the existing0.1-increment/0.003-relative-RMS method screens; maximum
integrated increment error0.039490, relative RMS0.002657. These are analyzer
checks, not widened physical bands or evidence of internal phase state.

## Public key-on timing grid

Isolated diagnostic wrappers add only public key-on timing and bus/API logs.
The completed192-record grid includes64 JT public data-strobe assertion residues
and32 genuine even OPM API-presentation residues, each with a matching TL127
leak recording. OPM's existing two-master-clock API cadence is preserved; no
fictitious64-phase coverage is inferred. All96 exposures pass the unchanged
frequency/residual/M1-return screens; all96 leak records are entirely zero.
Maximum M1-return difference is0.00009898rad.

For the fixed forward/preheat8192 protocol, descriptive native-sample offsets
of `(M2,C1,C2)` relative to initial M1 are:

| JT public data-assertion residues | Observed family |
|---|---|
| 1..16 | (0,0,0) |
| 17..32 | (-1,0,0) |
| 33..48 | (-1,-1,0) |
| 49..63 and0 | (-1,-1,-1) |

All32 OPM API presentations give(0,0,0). Maximum deviation from these rounded
descriptive families is0.00015443rad. Both baseline wrappers present at24;
requesting24 adds zero clocks and reproduces baseline CSV bytes. Flag-off
forward and native ALG0 DAC CSV/EVENT sidecars are byte-identical in both
models; nine malformed phase arguments reject before creating outputs.

The positive physical family is absent from this model protocol scan. Public
strobe/API timestamps are not internal acceptance timestamps, and this grid
does not cover arbitrary strobe widths or histories. In JT logs `cen_p1` records
the parity scheduled for the upcoming evaluated edge, not an independently
sampled previous pin. No numerical guard depends on that logged field. The
result narrows a public protocol experiment; it does not identify a causal RTL
gap or justify correcting original complex waveforms.

## Native pilot and full-model checkpoint

The16-profile pilot contains all-keyed ALG0..7/FB0 and M1-only ALG7/FB0..7,
three targets each with paired quiet:96 records. All48 targets are bipolar
on both outputs; all48 cleanup records are entirely zero. Minimum cleanup
wait0.500034s. Every raw header, word, CSV, transfer/input hash and reply chain
was independently audited. A separate final quiet recording is outside the
matrix count.

The192 pilot output/model pairs retain M1 feedback coefficient residuals
approximately0.052..0.081PCM for both models. Complex ALG0..6 residuals are
JT3.408..11.373 and OPM2.957..24.980PCM; ALG7 JT0.520..0.580 and
OPM0.953..0.975PCM. Relative-operator-phase ambiguity remains explicit; these
are absolute output descriptors, not a retuned band or conformance verdict.
The pilot analysis policy was frozen before analysis while acquisition was
already running; the mathematical kernel and synthetic qualification predate
all physical algorithm data. An earlier mutable partial-manifest hash caveat
is preserved. Later partial audits snapshot immutable bytes before parsing.

All229 profiles completed both models:458 native outputs/7,503,872 frames,
including32 immutable pilot outputs and426 new outputs. Independent audit
checks64-clock cadence and every input/executable/CSV/curve hash. Each model
has364 bipolar and94 exact-quiet latch observations, with no primary output-state
policy mismatch. High/full-level feedback can have large own fixed-frequency
projection residuals (up to5770.6PCM across the models); no periodic waveform
is forced onto those records.

## Completed physical matrix and export recovery

The immutable16-profile pilot contributes96 recordings; the remaining213
profiles contribute1278. Together these are687 target recordings and687
paired quiet recordings,1374 matrix records. The two additional final cleanup
recordings are separate from the matrix, as are the36 phase-control records.
Every matrix capture has16384 stereo frames. Independent audits check exact
ordered unique profile/repetition/kind coverage, input/capture/CSV hashes,
all raw words and valid exponents, framing, boot/image/tool identity, measured
settling and the generation/reply-marker chain. All687 paired quiet recordings
are entirely zero on both outputs. Targets contribute1092 bipolar and282
exact-quiet latch observations, with no primary routing/output-state mismatch.
All2748 target-latch/model pairs retain their unchanged absolute descriptors
and one-origin diagnostics; this is not full waveform conformance.

The complete group ranges retain the following PCM-domain observations. Zero
endpoints include intentional quiet. None of these ranges defines a passband.

| Group | Physical own projection RMS | JT coefficient RMS difference | OPM coefficient RMS difference |
|---|---:|---:|---:|
| Tagged all-operator | 1.874..4.342 | 0.481..11.698 | 0.422..26.902 |
| Single operator | 0..1.437 | 0..0.128 | 0..0.419 |
| Feedback isolation | 0.322..1.437 | 0.015..0.131 | 0.015..0.419 |
| Remaining subsets | 0..3.216 | 0..6.129 | 0..22.722 |
| Static stereo | 0..2.716 | 0..11.374 | 0..9.934 |
| Full-level feedback | 11.446..5829.643 | 0.495..853.070 | 0.496..853.842 |

The large full-level feedback residuals are retained unresolved measurements
for both references. Their fixed-frequency basis can leave substantial output
unexplained. No origin, gain, per-operator correction or case-specific tolerance
is introduced to force periodicity or infer an internal feedback defect.

The initial managed acquisition stopped after1019 complete records because
Chameleon's249.6MiB `/tmp` filled during export of capture21019. The FPGA still
held that complete DONE buffer. All3463 task export files were moved to
persistent storage with identical before/after hashes. The truncated61440-byte
export and original failed metadata remain intact. A fresh export of the SAME
buffer has65616 bytes, valid framing, and matches every byte of the truncated
prefix. Independent audit accepted that transfer recovery before appending it
once as record1020. No retake, register-program resubmission, capture arm, ROM
reload or reset occurred. A separately reviewed continuation captured the
remaining258 records with unchanged acquisition and analysis policies.

Two idle-only reply-recorder rearms archive3990/3996 markers and preserve
generations19/71, ROM mapping, image and boot bank. The final matrix ends at
generation231/480 markers; the separate final16384-frame quiet recording ends
at233/486 and is entirely zero on both outputs. These are checkpoint values,
not a promise of current board state after subsequent campaigns.

Permanent task wrappers now expose optional `--public-bus` and `--keyon-phase`
diagnostics. Omitting both preserves the original timing and output files.
An independent fresh-build audit covers28 captures,36 malformed/duplicate/odd/
overflow argument rejections and14 shell syntax/forwarding checks. Default
forward/ALG0/steady outputs and selected public-phase forward/leak outputs
match frozen originals byte-for-byte, including EVENT sidecars. Twenty public
bus logs match semantically; only the promoted JT header explicitly names the
scheduled parity `cen_p1_scheduled`. Frozen campaign executables and their
original snapshots are unchanged.

## Reproduction and local provenance

Run from `tasks/jtcores-143`, always using fresh output paths:

```
go run host/algorithm_programs.go -output artifacts/fresh-algorithms
go run host/algorithm_phase_programs.go -output artifacts/fresh-phase -preheat 8192
go test host/algorithm_score.go host/tone.go host/algorithm_score_test.go
go test host/sine_fit.go host/sine_fit_test.go
go test host/algorithm_phase.go host/tone.go host/sine_fit.go host/algorithm_phase_test.go host/algorithm_frequency_test.go
go run host/algorithm_score.go host/tone.go -column linear -reference MODEL.csv -model-column right INPUT.csv
go run host/algorithm_phase.go host/tone.go -column linear -marker-csv LEFT.csv -marker-column linear RIGHT.csv
go run host/sine_frequency.go host/sine_fit.go host/tone.go -column linear INPUT.csv
```

Explicit source lists are required because these standalone CLIs each have
their own main. Tests normally use temporary output roots; optional durable
qualification environment variables require fresh exclusive directories.
Source promotion preserves724 original program payloads and seven synthetic
reports byte-for-byte. Build/tests/vet and independent literal validators pass.

Local artifacts under `artifacts/algorithms-feedback/` include:

- `physical-phase/physical.json`, SHA `d1601054b47f336198fb0ffb8b3d090f2701b4c52e51c84185987b9386479e51`;
  independent phase audit SHA `4489354a837f1b7c7b690553f0f98da5b49f1d94af2e89a2e15ab04f4949ba29`.
- `physical-pilot/physical.json`, SHA `4408afacbd130fcf60af7c9eeaabf426bb8399e2434e00c5e38a2b21e6346ee2`;
  independent audit SHA `fdf5b756a4a75de7f982bfa11bfa35614915ae6a6859385ccfde9544c57147bd`.
- `reference-full/reference.json`, SHA `6c8e4cd09e8a8f98a3fcb43b2cbd9cc40ceb6669abc3bf1e686e310fa613a297`;
  `independent-integrity.json` and unchanged one-origin comparisons.
- `phase-boundary/independent-grid-audit.json`, SHA `725e9274ad47c3d5798f41d61639ad6dcbf66e5444dd479d2529b1c41bee41da`;
  `terminal-summary.json`, default byte-identity proofs and actual public logs.
- `promoted-validation/root-validation.json`, `sine-source-validation.json`,
  `sine-numerical-reproduction.json` and retained original failures/controls.
- `physical-full-additional/physical.json`, SHA `8b5f721bf708ba2aae6979df162d5b9b939eb7cac0c4e6cdf8cfcd64b76b2671`;
  `full-comparison/audit.json`, ordered coverage, unchanged descriptor files and
  both idle-rearm archives. The final quiet proof is in `physical-full-additional/terminal.json`.
- Combined `full-comparison/summary.json`, SHA `1ac246d2b8d9fa83c31e0c51fecf79548973fb3ea445772d96c3545ac8810c47`,
  and `group-ranges.json` retain every triplicate/latch/model range and limitation.
- `export-recovery-21019/independent-audit.json`, original failure/truncated file,
  same-buffer acceptance and AST/order/marker review of the continuation.
- `promoted-wrapper-validation/` contains source/build/default/grid compatibility
  proofs; `figures-phase-grid/` preserves uncorrected plotted phase values and
  both input-audit hashes.

Raw recordings, binaries, generated curves/manifests and compilation directories
remain local artifacts. Accepted physical write timing and the relative-output
phase difference remain unresolved. CSM, accumulation/clipping and broader
subsystem coverage are still outstanding at this checkpoint. This document
does not close #143.
