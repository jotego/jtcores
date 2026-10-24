# Native envelope measurements

Diet Go Go direct YM2151 output, 2026-10-17. Production jt51 remains frozen at
`985a573dcfc1ff135553a39f7eae21d18ba57cbe`. No RTL or candidate patch was created.
The full audit is incomplete; implementation remains deferred under the user's
[jt51 #3 instruction](http://gitea.jotego.es/jotego/jt51/issues/3).

## Qualified acquisition and comparison

The new event workflow executes a complete initialization with all keys off,
waits 50 ms, arms the FPGA recorder, then submits a short event program through
the resident monitor. The event delays 256 CPU-loop counts, keys on C2 and
returns. Captures retain 16,384 native frames/channel, approximately 293 ms at
the nominal 55,937.5 Hz sample rate. USB/SSH timing is recorded but is not a
chip-clock key-on timestamp. Silent pretrigger samples are verified in each
attack recording rather than inferred from the host command order.

`scripts/capture-event.py` keeps one PicoROM client and the monitor lock for
the entire acquisition. It verifies device/monitor identities, generation
handshakes, remaining marker budget, capture ownership, header identity/count,
transfer SHA256 and decoder checks. Each prefix retains exact INIT/EVENT bytes,
their hashes, command replies, recorder/tool/boot identities, capture header,
host timing bounds, raw capture, decoded CSV and a success/failure manifest.
It stops rather than rerunning a failed stimulus. Output names are exclusive.

Both model wrappers now record before and throughout EVENT execution. Their
exclusive `.events.csv` files identify capture start and register-data submission
or strobe clocks. Model INIT is followed by 4096 master clocks of settling;
physical conditioning uses the separate 50 ms pause. Model delay bytecodes still
use an explicitly approximate 32 master clocks/count, so absolute onset timing
is not compared. Legacy steady recordings remain byte-identical in both models.
Event tests verify silent pretrigger, native 64-clock cadence, recording during
long bytecode delays, finite sample limits and retained later event writes.

Nine preliminary AR31/20/18 recordings at C2 MUL2 qualified pretrigger and
transient capture. The main fixtures use KC=4A, KF=0, C2 MUL8, algorithm 7,
TL=0, no LFO/noise/feedback. This even-multiplier pitch passed the independent
PG matrix: effective increment 65984, nominal carrier about 3520 Hz.

## Fixed amplitude features and limits

`host/envelope.go` projects PCM onto sine, cosine and a DC term at that fixed
carrier frequency. Its 32-sample window spans about two cycles, with an
eight-sample hop. Window duration is **0.572 ms**. Frequency and window size
are fixed across the main matrix; no per-case waveform correlation or filtering
is fitted to conceal onset differences. Linear and nonlinear synthetic attacks
with several carrier phases validate threshold durations within a window.
Wrong-carrier, unfinished, silent and missing-pretrigger inputs are qualified
separately. CSV parsing checks finite values and consecutive sample indices.

For isolated attacks, the reported feature is the interval between 10% and 90%
of the final-quarter median amplitude. A measured state requires a final-quarter
relative amplitude span at most 1% and carrier residual at most 2%. The final
level is an estimate; this relative-flatness gate does not prove the correct
absolute TL/decay level. Absolute levels are compared independently below.

The initial feature comparison uses the observed range of three physical runs,
widened by two projection-window durations for the two compared estimates.
This is a conservative windowed-feature comparison, not a confidence interval
or a sample-identity proof. At the fastest rates the observed interval is mostly
window blur around a step; sub-window attack timing remains unresolved. The
AR12 physical repeat range is wider than a window, demonstrating why one modeled
event phase is not a physical phase measurement.

Use `-curve-only` for decay/hold recordings. It retains projected level/residual
statistics and optional amplitude CSV without scoring an attack against an
inappropriate final level. Earlier exploratory hold JSON contains unused attack
fields; the hold conclusions use only amplitude curves and final-level estimates.

## AR12–31 at KS0

Twenty AR settings were independently initialized three times: **60 physical
transients**. Every accepted recording is nonzero in both signs, with verified
transfer hash, valid serial exponents and zero framing errors. Both models ran
the identical INIT/EVENT bytes. Nineteen settings are consistent within the
declared feature band; AR14 is a large mismatch.

| AR | PCB 10–90% feature range, ms | jt51, ms | Independent OPM, ms |
|---|---:|---:|---:|
| 12 | 90.684–92.439 | 90.709 | 90.730 |
| 13 | 68.321–68.401 | 68.332 | 68.351 |
| 14 | 46.012–46.055 | 0.472 | 46.026 |
| 18 | 11.308–11.424 | 11.395 | 11.363 |
| 20 | 5.636–5.701 | 5.690 | 5.616 |
| 26 | 0.844 | 0.808 | 0.839 |
| 31 | 0.458–0.502 | 0.483 | 0.467 |

AR31 and the jt51 AR14 result are steps at this resolution; the numbers near
0.5 ms describe the projection window's response, not a gradual 0.5 ms attack.
The complete table is `artifacts/envelope-native/attack-comparison.{json,csv}`.
The standalone PNG/PDF plot preserves the full sweep and an onset-aligned raw
RMS view; onset alignment illustrates shape and does not establish key-on latency.
The [attack comparison figure](http://gitea.jotego.es/attachments/022dadde-7b54-4be2-8ea6-afa84355bf90)
is attached to the issue; intervals below 0.572 ms remain window-limited.

## Confirmed instant-attack boundary

The AR14 discrepancy survives four exact fresh-process repeats, sixteen bus
phases, fifteen event delays, six additional settling lengths and three prior
voice histories. Every INIT was independently decoded to check the requested
register values. Read-only internal instrumentation produces byte-identical
output to the uninstrumented prefix.

Trace evidence identifies the current jt51 path: effective rate 30 or 31 is
shifted to 15, and the ATTACK update's comparison against literal `5'hf` sets
attenuation directly to zero at the first eligible envelope update. This is
diagnosis of existing logic, not a proposed patch or replacement architecture.

Changing AR/KS reaches this same path in four separately measured configurations:

| AR | KS | Effective rate | PCB attack feature range, ms |
|---|---:|---:|---:|
| 14 | 0 | 30 | 46.012–46.055 |
| 13 | 1 | 30 | 45.155–46.070 |
| 11 | 2 | 31 | 39.205–39.254 |
| 6 | 3 | 30 | 45.148–46.024 |

Each has three physical repetitions. The KS1–3 matrix also includes adjacent AR
controls, totaling **27 additional physical transients**. OPM retains gradual
attacks. All four production configurations take the instant internal path.
For KS2/3, subsequent unwanted decay invalidates a plateau-based jt51 duration;
the initial jump is established separately by waveform energy and internal
trace, not by forcing the analyzer to return a duration.

Detailed phase/history and source-map evidence is in
`artifacts/ar14-investigation/findings.md`, with immutable inputs, output hashes,
event clocks and selected pipeline transitions. Production files were not edited.

## Confirmed raw-zero rate/key-scale boundary

Two isolated profiles distinguish the decay stages, using AR31 and the same
qualified carrier:

- **hold-d1:** D1R=0, D1L=15, D2R=0. The high decay target keeps the observed hold
  in the first decay stage.
- **hold-d2:** D1R=31, D1L=4, D2R=0. The first decay rapidly reaches the lower
  level, then the second decay should hold.

Each profile was measured at all four KS settings, three independent
initializations each: **24 physical recordings**. The PCB holds the intended
levels, and OPM agrees. Production jt51 loses level at nonzero KS:

| KS | PCB hold-d1 level, approximately | jt51 tail | PCB hold-d2 level, approximately | jt51 tail |
|---|---:|---:|---:|---:|
| 0 | 8169.6 | 8169.5 | 2042.3 | 2042.3 |
| 1 | 8169.5 | 7995.3 | 2042.3 | 1998.7 |
| 2 | 8169.6 | 7821.0 | 2042.3 | 1955.2 |
| 3 | 8169.5 | 5907.3 | 2042.3 | 1476.7 |

Tail levels are the final-quarter projected medians. KS1's output can look flat
within that short quarter while already being about 2.13% too low; its absolute
level therefore matters. KS2/3 also fail the relative-flatness gate. Physical
repeat variation is far below these differences. The wrong level is not scored
as an altered attack duration.

Four **AR=0** negative controls, each repeated three times, produce exactly zero
PCM on both physical channels and in OPM throughout the window. Production
jt51 leaks about ±4 at KS2 and reaches about ±2208 at KS3. An otherwise matching
AR1/KS3 control produces both positive and negative audio in all three physical
runs (about ±4k), so silence is not being used as a standalone sound-path proof.
The AR0/KS0 and KS1 software outputs also remain digitally silent in this finite
window; that does not prove an infinite hold at those settings.

Read-only traces for thirteen selected cases match their uninstrumented samples
byte for byte. They show raw configured rate zero becoming effective rates
2/4/9/18 after key scaling at keycode 18. Nonzero KS then advances AR, D1R and
D2R state. At AR0/KS1 the internal change is not yet observable after Yamaha
quantization; the directly observed AR0 gaps are KS2/3.

Yamaha application notes describe rate/key-scale calculation and effective
rates 0–3 as infinite, but the reviewed pages do not explicitly state the raw-zero
override before scaling. Physical observations establish that boundary here.
Independent Nuked-OPM and MAME ymfm both preserve raw-zero inhibition. The common
rate-construction path explains why these behaviors belong in a combined gap
inventory rather than separate speculative fixes. See
`artifacts/eg-zero-rate-investigation/findings.md` for primary-page references,
independent review and selected stage-aligned traces.

## Reproduction

From this task directory, use Python with the already qualified PyUSB environment:

```
python scripts/monitor.py emit tone --output artifacts/fresh-tone.bin
go run host/envelope_programs.go -base artifacts/fresh-tone.bin -output artifacts/fresh-ar
python scripts/capture-event.py artifacts/fresh-ar/ar14-init.bin artifacts/fresh-ar/keyon.bin artifacts/fresh-ar14 --capture-id 2000
go run host/envelope.go host/tone.go -increment 65984 -window 32 -csv artifacts/fresh-ar14-amplitude.csv artifacts/fresh-ar14-0-0.csv
```

Generate a key-scale boundary with `-ks 1 -first 12 -last 14`, or isolated hold
fixtures with `-ks 3 -profile hold-d1` / `hold-d2`. Use `-first 0 -last 0` for the
AR0 control. Each destination must be new. Model commands, from the repo root
with `setprj.sh` sourced, are:

```
bash tasks/jtcores-143/ver/jt51/sim.sh --event INIT.bin EVENT.bin FRESH-jt51.csv
bash tasks/jtcores-143/ver/opm/sim.sh --event INIT.bin EVENT.bin FRESH-opm.csv
```

Use `-column left` for model CSV analysis. For hold profiles pass `-curve-only`;
their attack duration is not the scored observable. Test the analysis with:

```
go test host/envelope.go host/tone.go host/envelope_test.go
go test host/phase.go host/tone.go host/phase_test.go host/tone_test.go
```

## Evidence and remaining scope

There are **135 transport-qualified physical event captures**: nine initial
qualification recordings, 60 main attacks, 27 KS boundary attacks, 24 isolated
holds, twelve AR0 silent controls and three AR1 positive controls. Silence is
explicitly separated from the 123 nonzero recordings. All transfers and framing
checks pass; no CPU reset or dropped reply byte occurred during the campaign.

Artifacts are retained under `transient-qualification`, `transient-wrapper-check`,
`envelope-native`, `envelope-ks`, `eg-hold`, `eg-zero-attack`,
`ar14-investigation` and `eg-zero-rate-investigation`. They remain outside git.
Every campaign manifest points to the complete source programs and hashes.

The native checkpoint above predates the longer-acquisition extension below.
Still required: remaining AR/KS/KC combinations, D1R/D2R and D1L sweeps,
release/hold/retrigger/live-register behavior, and the remaining LFO/noise/
algorithm/feedback/CSM/accumulation audit. No full envelope, chip or issue
completion is claimed.

## Slow AR1–11 with stereo-frame stride

The [longer-acquisition workflow](long-acquisition.md) now retains complete
stereo pairs with a selectable stride. The new slow fixtures keep KC4A and KS0
and use MUL0, reducing the carrier to about 220 Hz without changing key-scale
contribution. An independent native physical fit confirms increment 4124.
At stride 64 the recorded rate is 874.0234375 Hz, below-Nyquist carrier advance
is 263936 per recorded sample, and window 32 spans 36.612 ms. EVENT delays 8192 CPU
loop counts before key-on; measured silent pretrigger is required rather than
assuming host ARM order establishes it. INIT remains all keys off.

All eleven slow rates were independently initialized three times: **33 further
nonzero physical transients**. AR1 records 18.74 s, AR2/3 record 9.37 s, AR4/5
record 4.69 s, and AR6–11 record 2.34 s. Each finishes with a qualified plateau;
all physical transfers, framing and CPU replies pass. Both models run the exact
stimuli and all internal clocks, while emitting indices 0,64,128,... . Every
reference CSV has the requested row count, 4096-master-clock spacing and 64 silent
pretrigger samples. The full model duration limit was not needed for this set.

| AR | PCB 10–90% feature range, ms | jt51, ms | Independent OPM, ms |
|---|---:|---:|---:|
| 1 | 4373.091–4374.338 | 4374.523 | 4373.432 |
| 2 | 2890.800–2950.006 | 2890.888 | 2889.456 |
| 3 | 2179.098–2181.384 | 2181.890 | 2180.250 |
| 4 | 1436.878–1461.057 | 1437.311 | 1438.822 |
| 5 | 1078.963–1083.231 | 1085.081 | 1083.373 |
| 6 | 723.910–728.287 | 722.988 | 723.284 |
| 7 | 541.218–544.579 | 542.894 | 543.014 |
| 8 | 361.002–362.077 | 361.036 | 361.193 |
| 9 | 271.055–272.337 | 271.342 | 271.574 |
| 10 | 181.064–183.068 | 180.959 | 181.356 |
| 11 | 136.014–137.890 | 137.513 | 137.511 |

All eleven are consistent within the observed physical range widened by two
projection windows (73.225 ms), using the same declared feature method. AR2's
59.2 ms physical repeat range illustrates envelope-phase variation at slow rates;
no cause is assigned merely from model agreement. This is a finite windowed
feature result, not sample identity, precise key-on latency or full AR/KS/KC
coverage. Together with the native AR12–31 set, all nonzero AR registers have
been measured at KS0/KC4A; AR14 remains a confirmed instant-attack mismatch.

Sources reproduce the fixtures with `host/envelope_programs.go -first 1 -last 11
-carrier divided -pretrigger 8192`. Acquisition uses `--stride 64 --words COUNT`;
both model wrappers use `--stride 64 --event INIT EVENT CSV SAMPLES`. Recorded
frame counts are 16384/8192/4096/2048 for the rate groups above. Defaults reproduce
all 21 native campaign INIT/EVENT files byte for byte. Raw data, model outputs,
source programs, commands, hashes and comparison CSV/JSON/PNG/PDF remain local
under `artifacts/envelope-slow-main`, with stimuli in
`artifacts/envelope-slow-main-v2-programs`.

The [complete AR1–31 comparison figure](http://gitea.jotego.es/attachments/1daf6ead-20bf-4a01-947b-8bf6a2bdbc78) shows the two acquisition resolutions
separately. It retains the earlier AR14 mismatch and makes no sub-window claim.

## AR0/KS1 beyond the native window

The native checkpoint only diagnosed an internal KS1/AR0 advance because its
293 ms output was still digitally silent. Longer acquisition now establishes an
observable discrepancy at this setting. Three independently initialized physical
runs at KC4A/MUL0, AR0/KS1, stride 64 retain **exactly zero PCM on both channels**
for each 18.74-second recording. A separate AR1/KS1 positive control reaches both
signs and the intended full level; its attack feature is 2889.805 ms. Negative
silence is explicitly separated from this signal-path validation.

The identical 18.74-second OPM program remains exactly zero. jt51 becomes nonzero
at retained sample 427, later spans −8176/+8160 and then decays. Because the tail
is not cleanly flat, the analyzer returns `no_clean_plateau`; no attack duration
is assigned to that invalid score. The raw PCM difference establishes the gap
without relying on a plateau fit. This extends physically observable AR0 leakage
to KS1, alongside the existing KS2/3 native results. It does not claim an infinite
duration measurement or complete reset/history coverage.

All four extra physical captures pass transfer/framing/generation checks, with
no reset or dropped reply. Exact fixtures, commands, model binaries/output hashes
and analysis are under `artifacts/envelope-slow-zero` and
`artifacts/envelope-slow-zero-programs`. The new slow measurement set therefore
contains 33 main nonzero attacks, three intentional silent controls and one
additional nonzero positive control; these 37 captures are separate from the
135-recording native checkpoint and acquisition qualification fixtures.

## KS/KC boundary and zero-rate checkpoint

The fixed matrix contains 23 main profiles and two held-carrier profiles:
**152 physical captures** (13 carrier-stage and 139 main-stage captures) and
**50 frozen stereo model outputs**. Six carrier targets independently qualify
12 latch observations at KC3E/KC41, MUL8; the main stage contributes 138 latch
observations from 69 triplicate targets. Paired/final quiet captures remain
separate from intentional silent controls. No production RTL changed.

KC3E/40/41 MUL8 use native increments 39232/41568/44032 and window 64/hop 8
(1.144 ms). KC40/MUL0 uses native 2598: stride 64/window 32 retains 166272 at
874.0234375 Hz (36.612 ms), and stride 16/window 64 retains 41568 at
3496.09375 Hz (18.306 ms). The synthetic observer qualification treats each geometry separately; the
166272 carrier uses the unchanged free-frequency PCM fit and crossing brackets,
not inverse-sine phase acceptance. Actual host bounds and stable/silent initial
support are checked independently; there is no accepted-write timestamp claim.

Representative 10–90% attack features below combine both latches and all three
physical repetitions. A dash means no eligible duration, not zero duration.

| KC / KS / AR | PCB range, ms | jt51, ms | OPM range, ms |
|---|---:|---:|---:|
| 3E / 0 / 14 | 54.397–54.450 | 54.348 | 54.304–54.323 |
| 40 / 0 / 14 | 44.893–44.953 | — | 45.740–45.757 |
| 3E / 3 / 7 | 54.316–54.431 | — | 54.304–54.323 |
| 40 / 3 / 7 | 44.958–45.040 | — | 45.740–45.757 |
| 41 / 3 / 7 | 44.973–45.766 | — | 45.699–45.732 |
| 40 / 0 / 1 | 4374.353–4378.500 | 4376.596 | 4375.082–4376.032 |
| 40 / 3 / 1 | 361.068–363.037 | — | 361.237–361.526 |

At KC40/KS0/AR14, jt51's retained numeric feature is 0.936 ms, below two native
windows; it is a window response, not a resolved attack duration. KC40/KS1/AR13
likewise retains 0.922 ms and an incorrect absolute plateau. These four model
latch observations remain comparison-ineligible. Other jt51 wrong-level or
unfinished plateaus also remain withheld. This extends observations of the
existing instant-attack/raw-zero boundaries rather than declaring a new gap.

At AR0, both KS0 and KS3 physical controls stay exactly zero on both latches
(18.74 s and 1.17 s finite records respectively), as does OPM. jt51 stays zero at
KS0 but reaches −8176/+8160 at KS3; its invalid plateau is not assigned a duration.
Matched AR1 positives reach both signs and the expected physical level, with the
qualified ranges above. These finite zero observations do not claim indefinite
silence or all reset/history behavior.

Live D1R0 at KS0–3 and D2R0 at KS3 retain physical full-level holds: final-quarter
projected median 8169.422–8169.583 PCM. OPM remains near full level; jt51 medians
at KS1/2/3 are 7994.966/7822.665/6580.038 PCM in the D1R0 controls, with the same
KS3 median in the D2R0 control. Holds receive no forced fall duration. For the
nonzero live D1R12 controls, physical 80→40 ranges at KS0/1/2/3 are
145.879–147.578, 109.797–109.886, 54.921–54.989 and 13.723–13.742 ms.
The D2R12/KS3 range is 13.702–13.746 ms. The corresponding qualified model
features lie within the frozen summed-window screens. These mean-duration
observations do not measure or erase the earlier rate12 staircase discrepancy.

The report retains **138 physical observations, 92 model observations, 46
triplicate cells and 92 comparisons**. All 48 eligible comparisons lie within the
physical min/max widened by the sum of physical/model window durations; 44 are
withheld, not passes. All 24 original model exceptions remain. The original
model audit's 30 attack qualifications are preserved; 4 model observations carry
sub-two-window/window-response labels, some already ineligible on other grounds.
No physical observation falls below that attack-resolution boundary. A numeric
legacy feature or zero default RMS never substitutes for absolute plateau quality.

The [published PNG](http://gitea.jotego.es/attachments/8f654baa-cbb6-49d9-9a9f-ea37e565f301)
and [PDF](../artifacts/envelope-ks-kc-aggregation-results-v1/figures/keyscale-boundary-v1/keyscale-boundary.pdf)
show 54 physical and 36 model selected native boundary observations. Hollow
unqualified legacy features and unresolved annotations remain visible; no phase,
gain or DC alignment was applied. PNG SHA256 is
`22137658971d1cb7519c5eeccff205b47bfd46ba08b65753d5569d96cbee2ba5`.
The PNG is published with its verified hash; the PDF and raw evidence remain
retained local artifacts.

Reproduction uses the fixed `ks-kc-main`/`ks-kc-carriers` branches of
`host/decay_programs.go`, the exact five-geometry `host/eg_features.go` frontend
and the descriptor-only Python `scripts/eg-report.py`.
The artifact implementation passes build/vet, focused tests, legacy 106 cases/
212 payloads and new 25 profiles/50 payload reproduction. ROOT-reviewed source bodies
and guards remain verbatim. Terminal-confirmed handle 83222 then ran exactly 150
same-input frontend calls and one descriptor report: all non-curve-path report
fields and all 150 whole curves match, and all six scientific report documents
are byte-identical. Independent audit rechecks 493 input/source/protected pins
and 613 output pins. No 970 grid, acquisition or chip model reran for that parity.

Evidence is retained under `artifacts/envelope-ks-kc-preparation-v1`,
`envelope-ks-kc-physical-{carrier,main}-independent-v1`,
`envelope-ks-kc-aggregation-results-v1` and
`envelope-ks-kc-source-promotion-proposal-v1/actual-parity-audit-v1`.
ROOT main review is 1b218dbd..., aggregate review 200b897f... and completed parity
handoff `15e47c66…`, with completed ROOT parity review `0072d6b4…`. Full KS/KC combinations and deferred history controls remain
outside this finite matrix; the broader EG/chip audit is still open.
