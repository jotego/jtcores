# Decay, sustain level and release measurements

Work in progress for jtcores #143. Production jt51 remains frozen at 985a573;
implementation is deferred until the measurement gaps are consolidated.

## All sixteen D1L settings

Each complete INIT clears all channel keys and establishes every operator and
channel register. The isolated C2 uses AR31, D1R31, D2R0, RR15, KS0, KC4A, MUL8,
TL0, algorithm 7, no LFO/noise/feedback and both pan outputs. EVENT delays 256 CPU
loop counts, keys on C2 and returns. The native 16,384-frame/channel capture spans
about 293 ms. All sixteen D1L values were independently initialized three times.

All 48 physical recordings have valid framing/exponents, matching HPS/PC SHA256,
expected CPU generations and nonzero transients of both signs. Each tail is the
last quarter of its recording. Projection at the fixed qualified increment 65984
uses 32 samples and an eight-sample hop. Tail medians summarize those fixed
windows; raw tail PCM extrema/nonzero counts and absolute residuals are retained.
For very low levels the attack analyzer's minimum-amplitude gate makes relative
quality fields inapplicable. Missing/zero defaults are never treated as proof of
quality. The level comparison uses absolute tail observations instead.

| D1L | PCB median projected tail amplitude | jt51 | Independent OPM |
|---|---:|---:|---:|
| 0 | 8168.904 | 8169.450 | 8169.443 |
| 1 | 5776.999 | 5777.287 | 5777.266 |
| 2 | 4084.482 | 4084.719 | 4084.715 |
| 3 | 2888.596 | 2888.617 | 2888.602 |
| 4 | 2042.181 | 2042.327 | 2042.325 |
| 5 | 1444.157 | 1444.211 | 1444.204 |
| 6 | 1020.798 | 1020.855 | 1020.869 |
| 7 | 721.704 | 721.777 | 721.776 |
| 8 | 510.087 | 510.115 | 510.111 |
| 9 | 360.614 | 360.618 | 360.617 |
| 10 | 254.706 | 254.714 | 254.712 |
| 11 | 179.952 | 179.962 | 179.959 |
| 12 | 126.986 | 126.987 | 126.986 |
| 13 | 89.687 | 89.694 | 89.697 |
| 14 | 63.157 | 63.157 | 63.150 |
| 15 | 0.000 | 31.221 | 0.000 |

Levels 0–14 agree with both models to within 0.546 PCM units in projected median
amplitude. This is a measured finite-tail agreement; it does not establish all
D1L transitions or key-scale/history combinations.

At **D1L15**, all three physical tails contain exactly zero PCM on both channels;
OPM also has exactly zero tail. jt51 instead retains approximately −31..+31 PCM,
with projected median 31.221. These silent tails follow independently captured
nonzero transients, including nearby D1L14 controls. Silence is not used as a
standalone audio-path validation.

Yamaha application notes, printed page 20 / PDF page 21, Fig 2.13, assign ordinary
D1L bit weights 24/12/6/3 dB and add 48 dB when all four bits are 1: nominal 93 dB for
D1L15. The scan was inspected visually. This is in
`modules/jt51/doc/yamaha/ym2151_app_notes.pdf`; output quantization prevents a
direct physical measurement of the exact 93 dB endpoint from the zero PCM tail.
The physical result nevertheless clearly contradicts jt51's nonzero residual.

Read-only production source inspection identifies `jt51_eg.v`'s special branch
at line 145: it assigns `d1level_II=5'h10` (16 blocks, nominal 48 dB). The independent
OPM trace reaches envelope level 992 (31 blocks) and enters the second-decay state.
Its instrumented output is byte-identical to the frozen uninstrumented oracle.
This records an existing production gap; no replacement logic or patch is made.

The [level comparison figure](http://gitea.jotego.es/attachments/c91abe6a-d826-4c2c-8ef6-4e1e2180b49c)
retains the zero-tail limit explicitly rather than plotting a finite measured
attenuation for zero PCM.

Fixtures are reproduced by `host/decay_programs.go -profile d1l`, using the
canonical tone base and a fresh output directory. Exact bytes, stimulus/output
hashes, commands and per-run statistics remain local under
`artifacts/envelope-d1l-programs` and `artifacts/envelope-d1l`. Model references
contain 32 complete outputs. `artifacts/decay-spec/state-qualification.json`
retains stage observations and byte-identity checks.

## Falling stages: complete finite rate sweep

D1R/D2R sweeps begin from a verified stable initial level, then change the active
stage's rate after the recorder is armed. Release tests key off an established
voice. Complementary configured-key-on fixtures check representative rates by
starting from silence rather than relying only on live-write behavior.

`host/decay.go` reads the fixed amplitude-curve CSV. Its main feature is the
interval from 80% to 40% of the verified initial amplitude. The first four curve
points must have the independently qualified level, relative span at most 1% and
relative carrier residual at most 2%. That residual gate applies only to the
initial stable level. During the active fall, residuals are reported rather
than gated: amplitude variation inside a window can produce valid values above
2%, including roughly 7% in the release references. A feature below two projection windows is
explicitly window-limited. A finite unchanged level is `held_in_window`; a curve
without both crossings is incomplete and receives no duration. Tail silence or
a finished decay is not required to measure this interior interval.

For configured-key-on complements, `-keyon` requires silent pretrigger and uses
the independently qualified full level. Falling crossings are searched after
the projected peak; a peak below 80% of full scale is unresolved and receives no
fall duration. Initial-plateau quality is explicitly inapplicable in this mode.
It is not inferred from zero-valued relative statistics. Known carrier and
waveform-fit provenance must accompany every result.

Synthetic tests cover held, incomplete, wrong-level, noisy-initial, instant,
exponential and configured-key-on curves, including malformed/nonfinite inputs.
An end-to-end sine/projection qualification covers 24 live transitions and 12
configured-key-on transitions across several carrier phases. Resolved synthetic
exponential durations stay within one projection window of their analytic value;
fast unresolved cases retain their limits rather than receiving a passing score.

The completed batch has **270 physical recordings**, ninety cases independently
initialized three times. All transfer/input hashes, framing, exponents, requested
frame counts, CPU generations and reply counts pass. Every recording contains
nonzero PCM of both signs on both channels. No reset, dropped reply or unexpected
generation occurs. Marker count advances continuously from 294 to 1914.

| Profile | Cases | Physical recordings | Reference outputs |
|---|---:|---:|---:|
| D1R0–31 | 32 | 96 | 64 |
| D2R0–31 | 32 | 96 | 64 |
| RR0–15 | 16 | 48 | 32 |
| Configured D1R/D2R key-on complements at 1/8/16/24/31 | 10 | 30 | 20 |

All cases use KC4A/KS0. Native acquisition uses the qualified MUL8 carrier;
stride16/64 cases use qualified MUL0. The nominal sample rate is 55937.5/stride.
Each curve uses 32 retained samples: 0.572, 9.153 or 36.612 ms per projection
window. The manifest's individual horizon is retained; this is not a fixed
293 ms recording for slow rates. D1R1 requires 16384 frames at stride64: shorter
pilot horizons did not contain both thresholds. CPU delays and startup origins
remain approximate in the models, so comparison excludes absolute onset time.

The physical scorer classifies 217 recordings as measured, 41 as window-limited,
six as finite holds and six as unresolved peaks. Both models execute
all clocks and the same exact register bytes. D1 and D2 rate zero hold within
the finite window. Rates 1–25 resolve the interior feature; rate26 straddles the
two-window classification boundary, so it remains resolution-limited for the
cross-device comparison. Rates27–31 are unresolved in time. RR0–12 resolve;
RR13–15 are window-limited. Configured-key-on rate31 has no resolved full-level
peak in either model or the PCB and receives no falling duration.

Compare the physical triplicate range widened by two projection windows. This
is a declared feature band, not a confidence interval or full sample-identity
test. The baseline comparison has 69 consistent windowed features, two finite
holds, fifteen resolution-limited cases, two unresolved peaks and two rate12
outliers. The latter are retained for phase/threshold investigation rather than
classified as additional production defects. Do not silently widen individual
bands. A wider reference starting-phase study already shows overlapping ranges;
the fixed-phase baseline alone is insufficient to infer a timing defect.

### Starting phase and an independently observed step-size gap

For rate12, the original physical D1 feature is 145.872–147.614 ms and D2 is
145.929–147.610 ms; the fixed jt51 reference is 144.162 ms. A narrow delay grid
does not cover the full envelope counter phase. The wider, independently chosen
grid `256+251*i`, i=0..15, spans about 1882 native samples. In both D1 and D2,
jt51 then spans 144.143–147.599 ms and OPM 145.843–147.605 ms. These ranges
overlap the PCB. The original comparison bands remain unchanged; this is a
separate phase-sensitivity qualification, not an adjusted passing threshold.

All 128 narrow/wide whole-output reference variants retain exact inputs and
hashes. Window/hop alternatives have 72 synthetic qualifications. On the real
rate12 data, changes among windows24/32/48/64 at hop4 shift the interior feature
by at most 0.049 ms; hop variants at window32 shift it by at most 0.048 ms.
Common ±0.5% amplitude-threshold scaling can move some crossings by one envelope
step, confirming that finite crossing features depend on discrete phase.

The same native recordings expose a **separate output-granularity gap** that
the average feature can conceal:

| Source, D1/D2 rate12 at KC4A/KS0 | Median attenuation step across analysis variants, dB | Stable plateaus in the selected amplitude range |
|---|---:|---:|
| PCB, all six physical captures | 0.093349–0.094489 | 74–75 |
| Independent OPM, varied starting phase | 0.093098–0.094468 | 74–75 |
| Frozen jt51, varied starting phase | 0.187409–0.188738 | 37 |

This is measured from output, without rounding to an assumed attenuation grid.
Use amplitudes from 38% to 85% of the qualified initial level. A plateau has
less than 0.015 dB variation across a neighborhood spanning at least sixteen
native samples; adjacent flat groups are separated by more than 0.03 dB, and
each group must retain at least two projected points. Differences between
successive median flat levels give the step estimate. Constant gain cancels in
the attenuation ratio; explicit ±0.5% scaling checks preserve the result.

Forty-eight independent staircase/carrier-phase/window qualifications recover
both 0.09375 and 0.1875 dB steps within 0.003 dB. The real-data study comprises
420 projections: all six physical captures and sixteen wider starting phases
per stage/model, each with six window/hop settings. These are reanalyses of the
retained recordings, not additional physical captures. Plateaus remain clearly
resolved, and near-zero quantized tails are excluded from the calculation.

Read-only inspection is consistent with the output observation: the existing
default `DECAY_SUM` branch in `jt51_eg.v` adds two envelope units for a step.
This does not prescribe a one-line replacement, because counter cadence and
the rest of the architecture must be considered together in later combined
implementation work. No production code was modified. The confirmed claim is
limited to the measured rate12/KC4A/KS0 D1/D2 granularity, not every envelope rate.

Evidence is in `artifacts/envelope-fall/comparison-phase*`,
`comparison-projection*` and `comparison-step-diagnostics.json`; commands,
synthetic inputs, input/output hashes and individual diagnostics are retained.

Exact frozen manifest SHA256:
`acd033393b64e6ed8b163c1d287520fbc68c9b137f50e697aee330c9eb9595b3`.
Local evidence is `artifacts/envelope-decay-programs-v2/cases.json`,
`artifacts/envelope-fall/physical.json`, `qualification.json`, and the
`reference-d12`/`reference-rest` directories. The independent audit checks all
270 transfers, input bytes, finite metadata and continuous generations.

LFO, noise, algorithms/feedback, CSM, remaining envelope history/key-scaling and
output mixing/clipping remain outstanding. These finite rate features do not
establish full envelope conformance.

## Finite stage writes and key history

Sixteen native-rate cases, each independently initialized three times, add
**48 physical recordings** and 32 reference outputs. Exact input/capture hashes,
frame counts, exponents, framing, consecutive generations and reply counts pass
for every recording. Each contains both PCM signs on both channels. Markers
advance continuously from 1914 to 2202, without reset or dropped reply. The final
attack/key-off positive control leaves the PCB quiet and the RAM monitor ready.

The fixed manifest SHA256 is
`27fb4d6482ce351b93d3031ffcf08707d644b44fedfdcf54195929956a0a59eb`.
`host/history_programs.go` reproduces all 32 INIT/EVENT payloads exactly. Local
evidence is under `artifacts/envelope-history`: `reference.json`,
`reference-summary.md`, `physical/physical.json`, `physical/qualification.json`
and `physical/summary.json` retain individual commands, results and limits.

| Intervention | Physical observation | Interpretation and limit |
|---|---|---|
| Write D2R31 while D1R0 holds; write D1R1 while D2R0 holds | Full-level tails, approximately 8169 PCM; continuous global phase fit | Selected inactive-stage writes do not disturb the finite held output. Both models are sample-identical to their own baselines. |
| Write the active D1R/D2R31 | Nonzero fall followed by exact-zero tail | Positive controls prove the rate-write path acts. Fast fall is window-limited. jt51's D1 tail reproduces the separately measured D1L15 residue. |
| D1R31 or D2R31 write during RR6 release; repeat key-off during release | Interior and early-release features remain within the baseline repeat range plus two windows | Stage isolation is consistent for these selected histories; no absolute write latency claim. |
| Repeat an already-high key-on on the held voice | Full-level tail; whole-capture fitted increment rounds to 65984 | Global phase RMS stays 0.002034 radians, the same as controls. No independently realigned post-event phase is permitted; no observed carrier restart. |
| Key off the held voice | Nonzero fall to exact-zero tail | Opposite-edge positive control. Fast release timing remains unresolved. |
| Key on again during release, with AR31 | Full-level tail restored, approximately 8169 PCM | New off-to-on edge positively changes the path. Deliberately interrupted release has no complete decay score. |
| Repeat high key-on early in an AR12 attack | 10–90% feature 92.383–92.529 ms versus baseline 90.688–92.381 ms | Within baseline variation plus two windows; models are identical to their own single-key baselines. Repeat occurs early, near 1–2 PCM in the models; later mid-attack histories are unmeasured. |
| Key off early in AR12 attack | Nonzero transient followed by exact-zero tail | Opposite-edge control; no attack duration assigned to an interrupted attack. |

The fifteen held/baseline/inactive-write/repeated-key recordings all retain an
unbroken global sine fit at increment 65984, with phase RMS
0.002033859–0.002034071 radians. Their projected tail medians span
8168.889–8170.090 PCM. This tests both level and carrier continuity; allowing
each side its own phase origin could hide a restart.

Release comparison supplements 80%→40% with ordered first99%→80% and
first99%→40% downward crossings of the independently qualified initial level.
An intervention before the 80% crossing could reset the envelope yet leave the
80%→40% duration unchanged. Synthetic reset-up and pause/restart controls at
12 ms demonstrate that limitation: the interior feature remains unchanged,
while both early/full features change by about 12 ms. A pure whole-trajectory
onset translation remains invariant, as required by unqualified absolute latency.

| RR6 history | first99%→80%, ms | 80%→40%, ms | first99%→40%, ms |
|---|---:|---:|---:|
| Baseline | 34.033–34.153 | 109.771–109.847 | 143.878–143.966 |
| D1R write | 33.785–34.110 | 109.794–109.919 | 143.704–143.969 |
| D2R write | 33.674–34.115 | 109.861–109.884 | 143.550–143.976 |
| Repeated key-off | 33.088–34.085 | 109.808–109.905 | 142.896–143.990 |

Every intervention's feature range lies inside the physical baseline range
widened by two native projection windows (1.144 ms). Baseline model durations
are 33.208/109.835/143.043 ms for jt51 and 34.162/109.800/143.962 ms for OPM;
all lie in those baseline feature bands. After alignment only on the first99%
crossing, normalized curve differences across all physical intervention/baseline
pairs stay below 1.133% of initial level. This is a measured bound with discrete
envelope-step phase variation, not proof of sample identity. The synthetic
12 ms resets exceed 4% and are detected by the added features.

Physical and model CPU delays differ, and serial latch ages/startup origins are
not synchronized. Release tail amplitude at a common recording index therefore
is not a settled-level comparison. Active-fall carrier residuals and step-phase
uncertainty remain explicit; a measured duration alone is not a waveform-quality
pass. Remaining key-scale/KC combinations, later retriggers and CSM are outside
these selected history observations.
