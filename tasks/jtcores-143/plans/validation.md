# YM2151 PCB validation

Issue: http://gitea.jotego.es/jotego/jtcores/issues/143

Full objective: validate jt51 against the Diet Go Go YM2151, including timers,
phase generation, envelope generation, LFO and other observable subsystems.
Bring-up alone does not complete this issue.

1. Establish PicoROM P28 programming, readback and a reset-free sound CPU monitor.
2. Establish Chameleon96 programming, finite raw capture and verified transfer.
3. Qualify serial bit timing, word framing, data polarity and channel mapping with
   silence, a nonzero tone and independent left/right controls. Preserve raw data.
4. Extend capture to long decoded measurements without PC transfer stalls.
5. Apply identical register programs to hardware and jt51. Compare timer periods
   and flags; PG key codes/fractions/multipliers/detune; EG rates/levels/key scaling;
   LFO waveforms/rates/AM/PM; noise, algorithms, feedback, clipping and reset state.
6. Investigate discrepancies and consolidate the gap inventory before proposing
   implementation work, following the user's earlier jt51 #3 instruction.
7. Commit/push reproducible source and measurement documentation; retain raw data
   locally, report exact validated coverage and close only after the full audit.

## Final finite reconciliation (2026-10-18)

[Reconciliation](reconciliation.md) supersedes the earlier checkpoint schedules
below. The supplement completes1067 physical targets/2145 captures,908 pitch/level
models,186 history audio models/eight timer runs,12 key-history models and492
LFO models. All raw observations and saved numerical results have separate audits.
The final1524-row LFO export/audit preserves268 physical partial,242 periodic,
six unresolved active observations and24 controls; each model retains252/228/4/8.
All52 new fast OPM RIGHT results remain conditional on their original carrier.

The original43 issue requests are preserved: five superseded setup items, six
qualified replacement setup items,28 bounded scientific items, three missing
exact-history items and one blocked completion condition. The original Rastan
trace is unavailable; distilled programs do not replace it. The six confirmed
requirements in [gaps.md](gaps.md) remain unchanged. No RTL fixes were started.
See [all-code LFO](lfo-all-codes.md), [pitch/level](pitch-supplement.md),
[live/key histories](history-measurements.md) and [archive](archive.md).
Full Cartesian combinations, full slowest periods and hidden accepted-write/IRQ
phase remain outside the bounded observations; none is a passing default.

## Initial evidence (2026-10-17)

- Branch `jtcores-143`, unrelated user module changes untouched.
- PicoROM `E66550A14758A021`: P28_27C512_70ns. Initial image was 64 KiB of FF.
  Backed up before changes. Built/installed existing diagnostic firmware from
  PicoROM commit c2fa947d8c1ca8a1e7cb0b9b4b4dcd331aff5fff for the P28 target.
  Device reports diagnostic version jtkcpu-1.6 and correct P28 configuration.
- Monitor copies itself to sound RAM after a stack-free test of all 8 KiB RAM.
  MPR1=F8 (RAM), MPR2=88 (YM2151), MPR3=01 (ROM control/comms), MPR4=02
  (ROM command table). Host writes/verifies table before generation/complement.
- Assembled monitor passes MAME HuC6280 execution, both RAM patterns, boot frame,
  timer A overflow, flag reset and two successive command generations. MAME's
  register writes are checked, not merely the assembly syntax.
- Physical CPU boot frame B0 00 00 arrived immediately after verified upload.
  No requested PCB power cycle was necessary; this accidental initial entry is
  not a guarantee that arbitrary future ROM installs can start without reset.
- Physical live replies: D0 01 01 (timer A), D0 02 00 (clear), D0 03 02 (timer B),
  D0 04 00 (tone), D0 05 00 (silence). Communication event records contain exactly
  these responses, no dropped bytes and no second boot frame.
- Chameleon USB SSH at 192.168.96.96 works with retained host pin. Linux boot ID
  3e876240-d0e5-41cf-b52d-9c2d2a303a0c unchanged during FPGA runtime programming.
  Existing protocol 960102 capture image loaded; PRNG all 32768 words verified.
  Initial, tone and silence raw files have matching HPS/PC SHA256.
- Raw bits 0/1 are staggered periodic pulses (about 55.94 kHz each), bit 2 changes
  with tone, bit 3 is static. Provisional SH/SH/SO identity inferred from signals;
  user confirmed the open-drain inverting adapter; post-reset pan controls now
  qualify latch0 as register20 bit6 and latch1 as bit7. Primary Yamaha ACC notes
  identify these as left/right respectively; earlier human test labels were
  reversed and are corrected without renaming the original artifacts.
- At this initial milestone, timers had functional flag smoke tests only, not
  period comparison against jt51, and raw audio was not yet qualified as decoded
  samples. Later decoder and phase milestones qualify the audio path below.

## Decoder milestone

- Added standalone task-local Yamaha sampler and mode 3, protocol 960103. It
  estimates bit centers from alternating SH boundaries; no fourth clock wire is
  required for the current harness. Full serial words and their dummy bits survive.
- Synthetic simunit covers packing, both channels, fractional 55/56-clock cells,
  inversion, reset/clear and malformed/missing strobes. Capture-control simunit
  covers all original PRNG/raw/PCM modes and new Yamaha acquisition/readout.
- Saved silence/tone/high/mid/mid2 raw traces replayed through RTL match every word
  from the independent Go decoder. External-file replay is now a standalone
  Verilator flow (not a CI simunit); the current high recording passes it too.
- Final Quartus build: 328 ALMs, 539 registers, 64 M10Ks, worst setup +1.873 ns,
  worst hold +0.122 ns; unconstrained clocks/input/output paths all zero. Only
  warning is subscription-only LogicLock. RBF SHA256:
  bd58fbab75d092d721452b9ff23203a098e362032ca5dd1b052de8532fc14a2b.
- Runtime-loaded successfully without changing HPS boot ID. Tools are isolated
  under `/home/root/jtcores143`, firmware named c96-yamaha; original runtime
  capture app and images preserved. Full 32768-word PRNG regression passed.
- A mode-3 physical capture has 16384 samples/channel, no framing errors and
  valid exponent fields; both channels swing -8176..8160. This capture used
  pre-reset register state and KC=00. Latest interval yields ~17.28 Hz.
- Same full tone program produces ~440 Hz in MAME and jt51 (jt51 at commit
  985a573dcfc1ff135553a39f7eae21d18ba57cbe), with native sample cadence 64 clocks.
  Physical short captures at KC=4A/4C looked unexpectedly slow, while KC=7C gave
  ~3729.84 Hz. Do not classify this as a jt51 mismatch yet: establish a known
  YM reset state and use long captures first. This has now been done: see the
  post-reset milestone below. The old bounded boot poll has finished.

## Post-reset phase milestone

- User power-cycled the PCB; fresh monitor boot frame `B0 2A 00` received.
  Chameleon96 and PicoROM remained running. All 17 original cases repeat.
- User reports master clock 32.22 MHz / 9, nominal sample rate 55,937.5 Hz;
  on-pin frequency 3.57–3.58 MHz with 0.01 MHz tolerance. Raw SH timing agrees.
- 243 independent full programs cover KC, KF, DT1, DT2 and multiplier/base
  interactions. jt51 and an independent external Nuked-OPM oracle agree in
  every case. The PCB has 129 matches and 114 effective increments lower by 8192.
- The complete pattern fits a missing bit-13 contribution when MUL bit0 is set;
  it is not a general mask after multiplication. Do not emulate this in jt51
  without separating chip behavior from control/capture setup.
- Accepted captures have verified transfer hashes, zero framing errors, nonzero
  samples of both signs and low sine-fit residual. Two failing framing captures
  are retained and excluded; the transient disturbance remains unexplained.
- Independent pan-only programs qualify stereo ownership and exact controlled
  silence. See [phase-measurements.md](phase-measurements.md) for exact coverage,
  inference limits, waveform-fit method and local evidence locations.

## Timer status and coarse period milestone

- All sixteen register-14 control combinations measured three times: physical
  results and independent OPM agree in all 48 observations; production jt51
  disagrees in seven combinations because it records disabled overflow flags.
- Fourteen physical state-sequence observations confirm sticky flags across
  disabling/stopping, with explicit clear required. Physical IRQ is unobserved;
  independent models also expose a related IRQ persistence difference in jt51.
- Standalone public-port probe reports eight expected assertion failures on
  the unchanged baseline. Counter/reload/clear/CEN/ZERO and period checks pass.
  It is deliberately not registered as a passing CI test.
- Ten timer preload settings have guarded clear/overflow bounds, each repeated
  five times: all 100 physical observations pass. First-overflow phase remains
  uncertain; no cycle-accurate period equivalence is claimed.
- The actual assembled monitor's delay was calibrated in MAME CPU execution.
  The new generator reproduces all flag and guarded-period program bytes.
  See [timer-measurements.md](timer-measurements.md). Production jt51 remains at
  985a573; no RTL or candidate patch was created.

## Native envelope milestone

- Event captures retain silent pretrigger and attacks; model wrappers record
  during event instructions and export write/capture clock sidecars. Legacy
  steady model outputs remain byte-identical. Host timing is not a chip timestamp.
- AR12–31 at KS0 measured three times, 60 captures. One clear attack gap at
  effective rates 30/31 survives independent phase/settling/history controls.
  Three additional KS boundary groups add 27 physical captures.
- Isolated D1 and D2 zero-rate hold fixtures at all KS add 24 captures; physical
  levels hold while production loses level at nonzero KS. AR0 controls add 12
  silent captures, contrasted with 3 nonzero AR1/KS3 controls. Production leaks
  quantized AR0 output at KS2/3. Internal traces diagnose the shared rate path.
- Nine initial qualification captures bring total to 135 event recordings;
  all hashes/framing/reply checks pass. Twelve intentional silent controls are
  kept separate from 123 nonzero transients. No reset or dropped byte observed.
- Fixed carrier projection and synthetic linear/nonlinear attack tests qualify
  feature extraction, with explicit 0.572 ms window resolution. This does not
  validate sub-window onset timing or full sample identity.
- See [envelope-measurements.md](envelope-measurements.md) and the central
  [gap inventory](gaps.md). Longer acquisition, remaining EG stages/boundaries
  and LFO/noise/algorithm/CSM/output tests remain. Production is still frozen.

## Stereo-stride acquisition and slow attack checkpoint

Protocol 104/C96CAP04 extends finite mode 3 captures by selecting complete stereo
pairs at strides 1..1024 while preserving framing checks. Previous files retain
their native-rate semantics. Hardware, model subsampling, offline metadata,
PRNG/raw/PCM regression and 100 MHz timing are qualified in
[long-acquisition.md](long-acquisition.md). Full 300-second acquisition is not
claimed from the shorter 37.5-second qualification run.

AR1–11 at KC4A/KS0 now have 33 additional physical captures and 22 matched model
references with complete plateaus, nonzero audio, verified transfer/framing
and declared 36.61 ms projection resolution. Together with the earlier native
sweep, all nonzero AR register values have finite windowed feature evidence;
AR14 remains a gap. Full envelope stages/keyscale/history and the rest of the
chip audit remain outstanding.

The longer AR0/KS1 extension adds three 18.74-second silent physical controls and
one nonzero AR1/KS1 control. OPM stays exactly silent; jt51 reaches nearly full
level then decays, so its attack score is deliberately rejected. This confirms
the previously internal-only KS1 AR0 gap in observable output. All 37 new slow
captures have valid framing, verified transfers and expected CPU generations.

## Decay, level and finite history checkpoint

All sixteen D1L settings have three physical recordings each (48), with 32
reference outputs. Levels 0–14 agree within 0.546 PCM units in projected tail
median. D1L15 gives exact-zero physical/OPM tails after nonzero transients;
production jt51 retains approximately ±31 PCM. Primary Yamaha Fig 2.13 specifies
nominal 93 dB for 15. Quantized zero does not measure that analog endpoint directly.
This adds a confirmed production gap, recorded in [envelope-stages.md](envelope-stages.md).

D1R/D2R0–31, RR0–15 and selected configured-key-on complements add 270 physical
recordings and 180 references. All acquisition/input hashes, framing, exponents,
requested counts, nonzero audio and continuous CPU generations pass. Fixed
windowed features retain 15 resolution-limited cases and 2 unresolved peaks;
2 finite holds are explicitly bounded. 69 baseline features agree within the
physical repeat range plus two windows. Two fixed-phase rate12 outliers have
overlapping ranges in a wider reference starting-phase study, so no additional
timing defect is inferred from that baseline alone. Scope remains KC4A/KS0.

A separate output-level diagnostic does confirm a granularity gap at rate12:
all six D1/D2 physical captures and independent OPM resolve approximately
0.09375 dB attenuation steps, while frozen jt51 resolves approximately
0.1875 dB. Forty-eight staircase/carrier-phase/window qualifications and 420
reanalyses retain this distinction without rounding to an assumed step grid.
This is a scoped output-granularity result, not a constant-period timing defect
or an all-rate conformance claim. No production fix is proposed in this checkpoint.

Sixteen stage-write/key-history cases add 48 physical recordings and 32 references.
Inactive writes and repeated key events have compatible finite behavior, with
active/opposite-edge controls. Held repeated-key-on retains global sine phase;
release comparison adds early 99→80/99→40 features so a concealed early reset is
not masked by an unchanged 80→40 interval. The repeated attack key-on occurs early;
later mid-attack/retrigger cases remain outstanding. Full details, numerical
bounds, model CPU-delay limits and local evidence locations are in the stage report.

This checkpoint adds 366 physical recordings and 244 baseline reference outputs,
with additional phase/projection controls retained separately. No reset
or dropped reply occurs. A qualified idle-only PicoROM recorder rearm archives
the finite session before exhaustion and preserves ROM/control state; guard tests
reject uncertain CPU state and unqualified ROM enable/masks. The physical monitor
remains resident and the PCB is quiet. Production jt51 stays frozen at 985a573;
no candidate RTL patch has been created. LFO, noise, algorithms/feedback, CSM,
remaining EG KS/KC/history combinations and output mixing/clipping remain open.

## LFO waveform, depth and marker checkpoint

The E0 pilots add 42 physical captures and 28 whole-model outputs. Independent
crossing methods measure deterministic periods near the documented 4096 native
frames. Native W3 is retained as finite noise features without a periodic or
seed-aligned sequence claim. The moderate W2 combined pilot has a separately
qualified joint estimator with explicit projection bias and cross-talk limits.

The 128-setting AMD/AMS/AME matrix adds 384 physical captures and 256 references.
All input/transfer hashes, framing, exponents, bipolar whole/post-event audio and
continuous CPU generations pass. Observation states agree across the triplicates
and both models. All 240 resolved deterministic period estimates contain the
documented period within their measured bands. All 384 deterministic endpoint
checks fit common per-wave screening bounds derived from independent synthetic
phase controls and decoded-quantum propagation. Deep attenuation includes exact
zero held samples, which do not support a logarithmic endpoint measurement.

Primary ACC notes correct the earlier human stereo names: register20 bit6 is
left, bit7 is right, hence latch0 is left and latch1 is right for this wiring.
The old artifact filenames and bytes remain unchanged. The built-in pan labels
and documentation are corrected; canonical both-pan programs are byte-identical.

Nine physical pan-marker controls pass independent acquisition audits and show
exactly three left mute pulses, with the right output continuous. Constant right
phase fits retain increment 32992 and approximately 0.00203–0.00205 rad RMS
through the markers. This is a finite continuity control, not a sample-identity
proof for arbitrary modulated output. OPM's opposite-pan write changes some
continuous samples, and the reference mismatch is retained rather than patched.
Separate synthetic/injected-error-qualified physical diagnostics find no
counterpart at that error size/pattern class. They retain an approximately
0.160 dB early AM prediction residual and make no physical byte-identity claim.

The PMD/PMS matrix has 224 settings, 672 physical captures and 448 model outputs;
all acquisition/hash/framing/generation and nonblank audio audits pass. All 672
deterministic endpoint checks fit the frozen finite-grid screen, and all 465
resolved period estimates contain E0 within measured bounds. Of 224 settings,
223 have matching observation states; one W3/PMD1/PMS6 repeat remains unresolved
at its measured pretrigger-jitter floor. Its approximately 2-cent span agrees
closely with the other repeats but stays below its 2.12-cent floor; the original
state and review remain. A guarded raw-zero-crossing measurement independently
confirms full-depth square half-span approximately 794 cents, matching both
models despite the primary printed nominal 700. No jt51 LFO defect is assigned.

This checkpoint adds 1107 physical captures and 744 whole-model outputs,
including the marker controls. Source/generator reproduction, negative-input
guards, Go tests/vet, pan/rearm regression and independent data audits pass.
Remaining LFO rates, storage order/dynamic writes, channel/operator isolation and
hold/reset/free-run/key-on history remain open. Full methods, exact evidence
paths and resolution limits are in [lfo-measurements.md](lfo-measurements.md).
Production jt51 stays frozen at 985a573, with no candidate implementation patch.

## C0 LFO storage checkpoint

Eight additional fixtures have 24 independently initialized physical captures
and 16 whole-model outputs, all with verified raw/input hashes, framing,
exponents, counts, bipolar signals, markers and continuous generations. The
physical session ends with successful silence at generation 218/marker 147.

Opposite-selector writes retain the active AM or PM trajectory; own-depth
positives change it and return to 64. Reversed final AMD/PMD INIT order retains
the same moderate combined output, with AM and PM constrained to one shared
global phase shift. Templates come from same-device nulls and fit only late
data after every intervention. No event-by-event fitting or time warping is used.

A new fixed 129-point squared-Hann Go extractor reproduces all 36 synthetic,
16 model and 24 physical feature curves numerically, without origin/gain/time
adjustments. Tracked independent native-rate tests preserve the original six
AMD127 sharp-corner failures (max 0.37423 dB exceeds 0.3 dB); deep precise extrema
and instantaneous transitions remain unqualified. Moderate combined and isolated
PM127 guards pass. This adds no production gap and does not establish complete
LFO history/isolation or physical sample identity.

Generator reproduction/36 rejection checks and Go build/tests/vet pass. The
earlier 128-point joint tool and production RTL remain unchanged. Exact stimuli,
qualification boundaries, results and evidence are in [lfo-storage.md](lfo-storage.md).

## C0 LFO route and selected history checkpoint

324 physical recordings and 216 frozen whole-model outputs extend the earlier
LFO work: 96 physical route baselines, 192 AM/PM positives and 36 selected history
records. All raw hashes, framing/exponents, requested counts, bipolar prefixes
or explicit quiet tails, marker policies and CPU generations pass. The PCB is
quiet with its resident RAM monitor ready; no reset/reload was required.

All 32 single-voice channel/operator routes independently qualify native4124 /
retained32992. Whole baseline phase and amplitude observations retain the
negative probes; late carrier fits cannot conceal an earlier gate disturbance.
Primary offset/key-mask mapping is explicit: M1/M2/C1/C2 offsets0/8/16/24 use
masks08/20/10/40. The generator reproduces all216 frozen payloads; independent
full-register/literal-event/safe-order checks and36 rejection cases pass.

The unchanged window64 isolated extractor has96 new native-integrated controls.
All192 positive captures and128 models have stable pretrigger, resolved periods
and independent period bands including2048. All256 endpoint checks fit the
predeclared common0.6dB AM /4cent PM screens; largest model distances beyond the
unexpanded physical triplicate range are0.002585dB and0.222541cent respectively.
These are finite features at the specified carrier/depth/rate, not universal
accuracy, ideal symmetric pitch, simultaneous-voice or sample-identity claims.

A separate162-case native-forward history qualification detects large resets
with withheld pre-event data despite good post fits; short presegments remain
unqualified and two-sample changes unresolved. All21 ordinary physical history
records pass fixed pre/post screens; all nine intentional TEST resets are
independently detected. Three whole holds and three KEYOFF-only quiet tails get
no forced period. Long-hold interiors cover3.42428 would-be cycles; short holds
retain their duration limit. SameLFRQ exact no-effect behavior remains unresolved.
The wrapped phase optimizer and its algebraic cache preserve original processing
failure evidence and explicit equivalence checks; no data or method band was
rewritten to force a pass.

Go tests/build/vet,216-payload reproduction, synthetic controls and independent
raw/feature audits pass within the declared scope. Source and full numerical
bounds are in [lfo-history.md](lfo-history.md); artifacts remain local. Production
jt51 remains985a573, with no candidate fix or new combined implementation issue.
Remaining LFO rates/wider combinations, audio noise, algorithms/feedback, CSM,
EG KS/KC/history and mixing/clipping are still open. Audio-noise models and
independent scorer/stimuli are prepared separately; no physical noise claim is
included in this checkpoint.

## Native audio-noise checkpoint

318 native stereo recordings and 45 raw SO/SH pin recordings cover the 32-code
matrix and selected NE/channel/operator/TL/EG controls: 144 targets, 144 paired
cleanup observations, 12 adverse preflight and 18 focused floor/positive controls.
114 frozen-model outputs comprise 96 matrix, eight preflight and ten additional
warm/long-settle controls. The latter preserve both off-state model floors after
the listed cleanup/quiet dwell and four-second settling; NEoff companions are
exact zero. No universal initialization-history or internal-cause claim follows.
All capture/input hashes, framing/exponents, counts, monitor generations and
measured quiet waits pass. The board is quiet; production jt51 remains frozen.

Every target starts after NEoff, all 32 RR15 writes before all eight KEYOFF
writes, at least 0.5 seconds measured after reply, and an independent native
quiet capture. All 144 main cleanup recordings are zero throughout on both
outputs; shortest measured wait 0.500067091 seconds. The actual final-event bound
plus 128 leaves at least 5113 frames. All 192 rate observations retain stationary
levels −2044/+2040 and compatible candidate D=32−code. Coarsest agrees for
00..1D; 1E/1F remain ambiguous about hidden clocks. All 90 sine/isolation fits
qualify increment 4124. Levels/TL and finite AR24/NE-roundtrip observations retain
explicit limits rather than a universal waveform claim.

The fixed comparison retains 328 endpoint states: 314 inside, six outside and
eight unqualified. The six outliers are OPM's tiny off-floor −8 versus physical
0; the short KEYOFF prefixes remain unqualified. jt51 −1 is inside the 4-PCM
endpoint screen but still differs directly from the PCB's exact-zero state.
Never-keyed whole records, KEYOFF final 4096 and guaranteed pre-AR24 segments
are physical 0. Independent raw Go and integer-Python bit-center decoders agree
on all 45 raw recordings. Actual zero words are 0x3004/exponent 1/mantissa 512;
the keyed TL127 positive resolves −9/+8 via exponent 1/mantissas 503/520 and
demonstrates low-bit visibility. No model prediction replaces the physical words.
Public-output quantization/history boundaries and MAME source-only inference
remain explicit; no internal cause, constant or candidate RTL patch is inferred.

The promoted generator reproduces 153 binary payloads, including model/physical
INITs, preflight and cleanup; four CLI negatives pass. Promoted 1152-fixture and
control reports match originals exactly. Nine CSV/CLI/bounds checks, 54 positive
and 12 negative observed-region controls, native/raw independent audits,
build/test/vet and capture-script syntax/import/AST-equivalence checks pass
within scope. The new capture metadata measures settle time and records script
provenance. Full numerical bounds and evidence are in
[noise-measurements.md](noise-measurements.md). Artifacts remain local.
Algorithms/feedback, CSM, remaining LFO rates/wider EG KS/KC/history and output
mixing/clipping are still open. Full noise periods, seeds and arbitrary
noise/LFO/envelope combinations are not claimed.

## Algorithms, feedback and output-phase checkpoint

229 native profiles each have three independently initialized targets and three
paired cleanup recordings:1374 matrix records, all raw/input/transfer/CSV hashes,
framing/exponents, ordered unique coverage and generation/reply chains audited.
All687 paired quiet recordings are entirely zero. Targets contribute1092 bipolar
and282 exact-quiet latch observations matching the primary output-state policies.
Two final native quiet captures and36 jointly keyed phase controls are separate
from that matrix.458 frozen whole-model outputs retain their own native64-clock
cadence and hashes; all2748 physical target-latch/model comparisons preserve
absolute gain/DC and a single training-selected global phase with early holdout.
High-feedback residuals are not forced periodic, and the2/17PCM synthetic method
screens are not physical chip tolerances.

The phase controls retain a positive approximately one-native-sample M2/C1/C2
family relative to M1, across both exposure orders/preheats/repetitions, with
supported free sine fits and stable return to M1. A separately audited192-record
public timing grid covers64 actual JT strobe residues and32 genuine even OPM API
presentations, each with a matched exact-quiet leak control. The positive PCB
family is absent from those fixed model protocols. Physical accepted writes and
internal scheduling remain unobserved; no phase correction is fed into complex
waveforms and no causal RTL gap follows automatically.

An export failure at record1020 came from a full Chameleon `/tmp`. Original
failed metadata and truncated bytes remain intact; the same retained DONE
buffer was independently recovered and accepted before the remaining258 records
continued.3463 archived exports retain identical hashes. No capture retake,
register-program resubmission, ROM reload or reset occurred. Both idle recorder
rearms retain complete archives and continuous generation/image evidence.

Reproducible Go stimuli/observers and primary graph fixture retain724 original
payload bytes and seven original qualification reports exactly. The free-sine Go
calculation numerically reproduces all60 original physical fits. Independent
native-integrated synthetic controls, CLI rejection checks, tests/build/vet and
fresh-build default/public-phase wrapper compatibility pass within scope.
Full details are in [algorithm-measurements.md](algorithm-measurements.md).
Production jt51 remains985a573, with no candidate fix or new implementation issue.
CSM, mixing/clipping, remaining LFO rates, broader EG KS/KC/history and wider noise
coupling remain outstanding; physical IRQ and accepted bus/internal phase are
unobserved. This checkpoint does not close the issue.

## Finite CSM checkpoint

544 physical recordings comprise12 adverse cleanup preflight,98 selected
pilot/history/AR30 recordings and434 route recordings. The latter count includes
432 matrix captures and TWO separate final quiet controls.212 stereo model CSVs
retain original long/short EVENT variants and preflight references; generation
counts are separate from physical/model coverage. All raw/input/transfer/CSV
hashes, framing/exponents, reply chains, measured cleanup waits and actual target
horizons pass. The CSM-specific cleanup disables CSM/stops timers FIRST before
RR15/KEYOFF; every paired/final quiet is zero throughout on both outputs.

All32 manual routes independently qualify192 native65984 carrier fits and
crossing checks; all48 same-channel background output observations are entire
zero. All192 automatic route outputs resolve finite repeated energy cadence,
511.425483052–511.504054612 native samples, with every unchanged support interval
including512. Matching frozen jt51 outputs remain quiet; all192 OPM comparisons
resolve repetition with overlapping support. This confirms a configured
automatic-output gap across the measured routes. Selected256/1024/AR30 controls,
held-manual continuity and stop/disable tails retain their separate finite scope.
No exact attack shape, hidden pulse width, internal cause, simultaneous internal
all-slot key claim, accepted write phase or physical IRQ result follows.

The two route stages use separate raw and feature gates, with all gates true
and no issues. The idle-only reply recorder rearm preserves generation/image,
ROM bank and mapping, without PCB reset/reload. Four original Go CLI bodies,
318 binary payload paths, common cleanup copy and both original energy reports
reproduce unchanged; converter/parser/exclusivity checks, builds/tests/vet and
independent raw/feature audits pass. The energy method preserves13 unresolved
positive controls and its finite±64 support rather than adopting a chip tolerance.
Full methods/provenance/commands: [csm-measurements.md](csm-measurements.md).
Production jt51 remains985a573; no implementation patch or new combined issue.

Mixing/clipping is being measured separately. Remaining LFO rates, broader EG
KS/KC/history, wider noise coupling and CSM fast/first-key/mixed-mask corners
remain open; this checkpoint does not close the full audit.


## Static output mixing checkpoint

63 profiles cover48 contributor/TL sums, nine pan and six split-output settings.
189 targets and189 paired cleanup captures give378 matrix recordings, plus TWO
campaign-final quiets=380. One earlier first-quiet path-ownership failure was
independently reconciled without a retake and remains outside the campaigns,
giving381 physical captures including recovery. All192 quiets are entire zero
on both outputs. Both acquisition and independent audit stages terminated0;
raw hashes/framing/exponents/reply chains and760 campaign output descriptors
and primary populations pass. All378 target-latch states match the pan policy:
342 bipolar and36 intentional zero. Model agreement is not a raw gate.

126 frozen model recordings and756 target-latch comparisons preserve absolute
PCM/populations/RMS/endpoints/jumps/quarters, with no phase/gain/DC correction.
The pilot reaches−32768/+32704 and N32/TL0 has1538–1560 jumps>=4096 per record;
unknown voice phases and latch ages prevent exact sum closure or an internal
clipping/wrapping diagnosis. Common-held-history stimuli are prepared separately,
not included as measured coverage. Source promotion preserves four original
CLI bodies,130 catalog files and21 complete same-input descriptor reports;
103 finite qualification trials, literal/parser/CLI negatives, builds/tests/vet
pass. Relocated executable/path identities are retained honestly.

The relative-output-path failure, corrected absolute boundary, recovered first
quiet and both campaign-final quiets are preserved distinctly. No PCB reboot or
ROM reload was needed; final actual monitor state43/3732 is quiet/idle. Full
methods/provenance are in [mixing-measurements.md](mixing-measurements.md).
Production jt51 remains985a573. Remaining LFO rates, broader EG KS/KC/history,
wider noise coupling, CSM corners and common-held-history overload analysis stay
open. No candidate RTL change or new combined implementation issue is included.

## Common-held-history output checkpoint

Six profiles cover N32/N1 held-key TL32→0/32/40→32 trajectories, with identical
LEFT pan markers and continuous RIGHT observation. Three independent
initializations give18 targets/18 paired quiet plus one final quiet=37 native
captures. All19 entire quiets are zero on both outputs. Independent raw-word,
CSV, framing/exponent, transfer/input identity and ordered reply audits pass;
all18 geometries,18 actual same-repetition reference links and57 permitted
free-frequency diagnostics resolve. No N32/TL0 middle fit is allowed.

Original early low predictions are checked on withheld and return samples.
No-op residuals remain descriptive baselines, and matched N1 TL0/TL32 gains
16.014150–16.014700 define only a conditional scalar coordinate. N32 TL40
transfers0.499274–0.499294 agree descriptively with N1 transfers0.499286–0.499293;
they do not prove uniform high-level gain for every voice. The N32/TL0 output
retains RMS27801.387–27913.611PCM,204–206 jumps>=4096 over2187–2188 samples,
compared with frozen jt51/OPM RMS31866.748/27187.713 over1810/1813 samples.
Distinct duration, voice phases and bus/key-on history remain explicit.

The adapter, generic observation support/null/injected-error controls and exact
host-ceiling binding tests were frozen before analysis. All294912 full physical
curve rows match original RIGHT samples; final ROOT review verifies100 handoff
pins. The packaging-only24→18 reference-count correction and read-only precheck
error are preserved without feature rerun. Capture/audit/features each completed
once; no retake, reboot, ROM/FPGA reload, new tolerance or production edit.
Final quiet state is117/222. Full method/results/provenance are in
[mixing-history.md](mixing-history.md). Remaining LFO rates, broader EG KS/KC,
noise coupling and CSM corners remain open. No internal overload cause or exact
ideal-sum conformance result follows.

The promoted source reproduces20 catalog files, all1323 generic observations
and eight curves, and all41 adapter synthetic observations byte-for-byte.
Existing12 model/18 physical extractions reproduce30 exact curves and complete
reports with only executable-hash/curve-path provenance changes. Four runtime
adapter source files are exact; generic numerical helpers, method JSON and
existing fitter remain unchanged. Builds, explicit Go tests/vet, literal
catalog/parser/CLI and exclusive-output checks pass; no new model or capture is
part of promotion verification.

## Finite fast-LFO rate checkpoint

Twelve original W0 AM profiles cover C0/CF/D0/DF/E0/E1/E7/E8/EE/EF/F0/FF, plus
a separate AMD0 carrier. Target stride4/window16/hop4 retains native65984 as
263936. Independent generic qualification precedes model/physical data:3456
positives,48 wrong-rate,48 carrier/null and eight adverse/alias controls retain
all original guards/states. The new predeclared endpoint-span diagnostic leaves
the published coarse median/bands unchanged, including ten wrong-rate examples
that remain coarse-periodic but fail the fine screen. Native-before-decimation
provenance and independent carrier/crossing qualification remain necessary.

All26 frozen stereo model outputs have exact256-masterclock cadence and valid
public output geometry; all48 AM fine diagnostics pass. OPM RIGHT carrier
relative RMS0.004425788>.003 remains unqualified, so its12 AM results remain
conditional. Physical controls independently qualify all six carriers before
ROOT authorizes the rate stage. Carrier7 plus AM73 makes80 physical captures,
39 targets and41 entire-zero quiets including two separate final quiets.
All raw, measured-wait/status/horizon conditioning and feature gates pass.

All72 physical AM observations retain coarse periodic state and qualify under
the unchanged fine1%/propagated-bound screen; maximum absolute endpoint-span
error0.097709%, maximum bound0.585938%. Actual posts1971–2785 retain at least
three nominal cycles plus40 samples. The first512 actual stable/bipolar baseline
is delay-derived, not an exact TEST-release timestamp. Raw validity never
depends on model agreement. Source/CSV/word/reply/transfer identities and all150
AM output/71 source pins pass ROOT review. Original optional-field summary error
is preserved without scorer rerun. Final quiet monitor state21/702; no reset,
reload, retake or retry. Full results/provenance: [lfo-rates.md](lfo-rates.md).
Other rates, slow staircase timing and the approximately1200s slowest complete
period remain outside this finite batch; no exact hidden-counter claim follows.

Six promoted source files preserve the four runtime bodies, original generic
grid and unchanged exporter. The full scientific report digest matches after
only48 declared CSV output-root substitutions. All26 payloads and complete
literal register/manifest checks reproduce; original20 generator and6/24 scorer
CLI controls, exclusive-report-root refusal, builds/four vet groups and focused
tests pass. All130 existing model/physical scorer JSONs and curves reproduce
byte-for-byte, including the known OPM RIGHT carrier failure. No new model or
capture is part of relocation validation.

## Finite EG KS/KC checkpoint

The 23 main/two-carrier matrix adds 152 physical captures and 50 frozen model outputs,
including independent new-carrier qualification and intentional silent AR0
controls with nonzero AR1 positives. The descriptor report preserves 138 physical/
92 model observations, 46 triplicate cells and 92 comparisons: 48 eligible within the
original summed-window bounds, 44 withheld and all 24 original model exceptions.
Four model attack observations remain sub-two-window responses rather than
resolved durations; existing wrong-level/unfinished states remain ineligible.
Representative KC/KS, AR0–1 and live zero/nonzero-rate ranges are in the
[envelope report](envelope-measurements.md#kskc-boundary-and-zero-rate-checkpoint).

The reproducible source tools reproduce 212 legacy and 50 new payloads, preserve
all numerical bodies/guards, and pass build/vet/focused controls. Actual
managed handle 83222 returned 0 after 150 retained same-input frontend calls plus
one descriptor aggregation. All 150 curves and six scientific documents are
byte-identical; metadata identities are checked separately. The read-only audit
verifies 493 input/source/protected and 613 output pins. No additional acquisition,
model run or broad qualification sweep was used. This checkpoint does not close full EG, deferred history or remaining
subsystem coverage, and assigns no new gap classification.

## Finite noise, split-CSM and low-LFO complements

See [audit-complements.md](audit-complements.md) for all eleven literal profiles,
clock domains, numerical limitations and portable14-file reproduction commands.

- All70 physical captures are independently reviewed:33 targets and37 whole-zero
  quiets, including four separate final quiets. Nine additional CSM STATUS queries
  are separate from target EVENTs. The complete chain is69/1614→218/2061,
  149 generations/447 marker bytes; no extra profiles count as coverage.
- Noise25 retains24 original feature reports. N0/N1 preserve two-level sampled
  histories; N2 is no-resolved energy modulation (default period0 is not measured).
  N3 retains finite cadence with original±64-native-sample support, not a sequence
  polynomial/internal-clock or new-gap claim.
- CSM19 retains18 energy reports, three C2 LEFT whole-record phase guards and
  all six manual/null controls. All nine separate STATUS replies are1; write-only
  capture completions are0. Whole-zero C2 RIGHT PCM retains actual3000..3004 low
  raw bits. C3 RIGHT and C4 both outputs resolve original cadence supporting512.
- L2 seven-capture stage independently qualifies all six own165888 carriers,
  actual stride1024 geometry/conditioning and stable pre128 gates before low-main.
  Its six same-input promoted-source report/curve comparisons are reviewed.
- Low-main19 retains18 applicable original report/curve pairs: six L0 coarse
  periods support1024 retained samples, while all six original fine screens stay
  unqualified at approximately2.34375% propagated bound. Six L1 partial-only
  changes are about−0.56625..−0.56747dB; six L3 results have no resolved modulation.
  All L1/L3 periods remain null. No partial-to-fullcycle/hidden-update inference.
- Original182 numerical configurations and11 CPU/11 virtual lifecycle profiles
  remain unchanged. Diagnostic-only drift/phase-jump and alias limits remain;
  these are finite qualifications, not universal anomaly detection.
- All22 public models/cadences/horizons complete. Both OPM C2/C3 manual phase
  exit1 results remain conditional. All48 model22 and66 physical outer same-input source comparisons are reviewed,
  preserving69 physical primitives/36 curves, including the final18 low-main
  reports/curves and all original fine/partial limitations.
- The bounded measurement complement set and its source parity are complete;
  reviewed source tools accompany this checkpoint. The existing six confirmed gaps stay
  combined. FullCartesian, P128/P1, precise first-load and all256 full LFO periods
  remain unmeasured, without implying a passing default or a new RTL fix.

## Recorded bounded subsystem coverage

This table records the scoped Diet Go Go direct-serial campaigns. Counts identify
their own milestone groups; the complements row is separate from the earlier
baseline campaigns. Production jt51 remains unchanged. This is finite evidence,
not exhaustive validation or closure of jtcores #143 or the older X-Men rounds.

| Subsystem | Completed direct evidence | Remaining limit |
|---|---|---|
| Capture/transport | Independent raw/RTL decode, complete stereo pairing, inversion/pan controls, transfer hashes, framing/exponent checks, CAP04 stride1–1024, finite timeout/ownership checks | Digital observations do not establish analog margins; host timestamps are bounds, not accepted chip-write phase. |
| Phase/frequency | 243 reset-conditioned KC/KF/DT1/DT2/MUL programs; nonzero bipolar captures and own-fit quality | 114 effective increments differ by8192 in a partial-product pattern. Chip/control cause unclassified; no blanket correction. |
| Timers | All16 control modes×3,14 state observations,100 guarded period observations at10 preloads | Physical IRQ pin unobserved; first-overflow phase bounded. Seven production flag-control modes disagree. |
| Attack | AR1–31 at scoped KC/KS, AR0 negatives/AR1 positives, effective30/31 boundary controls | Projection resolution limits fastest attacks; exact key-on latency/full parameter Cartesian product unmeasured. |
| Decay/sustain/release | All16 D1L, D1R/D2R0–31, RR0–15, configured-key-on companions and selected active/history controls | Some peaks/durations unresolved or phase/window limited; the rate12 step-size gap is scoped. |
| EG KS/KC extension | 152 physical captures,50 frozen models;23 main profiles plus2 held carriers;48 eligible duration comparisons inside original bounds,44 withheld | Original model exceptions retained. This extends boundaries/zero-rate controls, not exhaustive EG history. |
| LFO depths/waves | All4 waves,128 AMD/AMS/AME and224 PMD/PMS cases; deterministic period/endpoint screens and scoped combined W2 | Weak W3 PM activity and six deep-AM synthetic corner failures retained; no noise period/seed claim. |
| LFO routing/history/storage | All32 own-calibrated routes, selected reset/hold/key/free-run controls,8 storage/order fixtures | Wider simultaneous combinations and two-sample changes remain unresolved. |
| Fast LFO rate selection |12 C0..FF boundary rates,80 physical captures,26 frozen models;all72 physical AM diagnostics qualify | OPM RIGHT carrier exception makes12 model AM results conditional; no all256-rate claim. |
| Noise | All32 codes,selected NE/operator/TL/envelope controls,45 independent raw-pin records | Highest-rate hidden updates and seed/full sequence unmeasured. Small off-envelope output floor difference remains unclassified. |
| Algorithms/feedback |229 profiles×3 targets with paired quiets,458 models,2748 comparisons;36 physical joint-key phase controls and192 public timing-grid models | High feedback not forced periodic; synthetic method screens are not chip tolerances. Joint-key relative phase remains unclassified. |
| CSM |544 physical captures,212 stereo models;all32 routes with192 manual calibrations,48 quiet backgrounds,192 nonzero automatic observations | Production automatic output is quiet at these settings. Exact pulse width, attack shape, hidden simultaneous-key timing and IRQ remain unobserved. |
| Mixing/stereo |63 static contributor/TL/pan/split profiles,381 captures including recovery,126 models;6 common-held-history profiles,37 captures,12 models | No exact latent sum, individual-phase closure or clipping/wrapping mechanism inferred. |
| Finite noise/CSM/low-LFO complements | Eleven profiles, 70 physical captures (33 targets/37 quiets), nine separate STATUS reads and 22 frozen models; reviewed physical source parity: 66 outer/69 primitive results/36 curves; separate model parity: 48 analyses | Six L0 coarse periods retain unqualified fine screens (~2.34375% propagated bound); L1/L3 periods remain null. Two OPM manual phase-fit exceptions remain. No partial-to-full-cycle, hidden-update or all256-rate claim. |

The completed complements comprise four noise history/coupling profiles, three
split manual/automatic CSM controls and four slow-LFO/control profiles. Their
70 captures, nine separate STATUS commands and exact source parity are reviewed.
Rate60 permits only the retained coarse-cycle diagnostic; rate00 is partial
advancement with no period extrapolation. Its roughly 1200-second slowest cycle
exceeds a single 300-second buffer. P128/P1, precise first-load, full parameter
Cartesian products and wider histories remain outside these finite observations.

Six physically supported production requirements are consolidated separately:
timer flag creation enable, non-instant effective AR30/31, configured raw-zero
rate inhibition after key scaling, D1L15 tail, scoped rate12 D1/D2 granularity
and automatic CSM public output. Odd-MUL pitch, joint-key phase, high-level
mixing, the small NE-on floor and reference carrier/pan exceptions retain their
separate unresolved classifications. No model voting or passing quiet/transport
control establishes full chip conformance. Implementation review follows the
user's [jt51 #3 instruction](http://gitea.jotego.es/jotego/jt51/issues/3); the
[measurement issue](http://gitea.jotego.es/jotego/jtcores/issues/143) remains open.
