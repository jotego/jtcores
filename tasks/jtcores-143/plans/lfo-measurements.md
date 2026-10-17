# LFO measurement method and coverage

Work in progress for [jtcores #143](http://gitea.jotego.es/jotego/jtcores/issues/143).
Production jt51 remains frozen at 985a573; measurements precede combined
implementation work. LFO qualification does not close the other subsystem gaps.

## Primary evidence and observable quantities

Yamaha's application notes, `modules/jt51/doc/yamaha/ym2151_app_notes.pdf`,
printed/PDF pages 11/12, 12/13, 18/19, 20/21 and 21/22 define the waveforms,
TEST hold/reset bit, PM sensitivities, AM sensitivities and frequency table.
The waveform and register figures were visually inspected. Only register 01
values 02/00 are used; the remaining TEST bits invoke unqualified test modes.
Register 19 bit 7 selects distinct PMD/AMD storage: every complete INIT explicitly
clears both and later sets both desired depths. Channel PMS/AMS and operator
AME are independently controlled. LFO noise waveform W3 is distinct from the
channel 7/C2 audio-noise generator, which remains disabled.

For master clock Fm, native Fs=Fm/64. With H=LFRQ>>4 and L=LFRQ&15, the primary
frequency table is described by

```
f_LFO = Fs * (16+L) * 2^H / 2^30
native_frames_per_cycle = 2^30 / ((16+L)*2^H)
```

Primary comparisons use periods in recorded/native sample units; absolute Hz
uses nominal 3.58 MHz. The user's 0.01 MHz measurement tolerance does not support
an arbitrarily precise absolute clock claim. At E0 the documented nominal
period is exactly 4096 native frames, or 2048 recorded frames at stride 2.
The minimum rate 00 has a period of about 1200 seconds. A single 300-second buffer
cannot establish its full period; slow partial slopes/step cadence and a directly
observed complete cycle must remain different claims.

## Frozen waveform and gating pilots

Fourteen complete programs establish a single C2 voice: KC4A, AR31, KS0,
D1R0/D2R0, TL0, algorithm 7, both pans, no feedback/audio-noise. All INITs have
the same register-write count and hold TEST01=02 before setting rate E0, both
depths and waveform, then key on. EVENT waits 8192 CPU-loop counts and releases
TEST with 01=00. The held initial AM output can be attenuated; it is not assumed
to be full level. Baseline amplitude must come from an independent gate/control
or the already qualified unmodulated carrier.

- AM W0–3: AMD64, AMS1, AME1, PMD0/PMS0.
- Three W2 AM gates independently select AMD0, AMS0 or AME0.
- PM W0–3: PMD64, PMS4, AMD0/AMS0/AME0.
- Two W2 PM gates independently select PMD0 or PMS0.
- W2 with both depths 64, AMS1/AME1 and PMS4 checks combined activity after the
  separate extraction assumptions are qualified.

The original native/MUL8 v1 inputs and 28 model outputs are retained. The first
physical v1 capture passes transfer/framing/audio checks but is excluded from
rate scoring: conservative host arm-start/event-complete bounds leave fewer
than two periods. This is a coverage limitation, not corrupt acquisition. Its
prefix and failed horizon qualification remain under `artifacts/lfo-pilots`.

The extended v2 pilots retain the full TEST-held delay and use MUL4/stride 2 for
W0/1/2, gates and combined modulation. This carrier is independently qualified;
native increment 32992 becomes recorded increment 65984, and the record spans
about 586 ms. W3 retains MUL8/stride 1 and native sampling. Sampling selects whole
stereo pairs with no antialias filter; noise sequence/statistics are not inferred
from decimated data. Each manifest gives the actual sample rate, carrier,
window, stride, frame count, ordered register writes and input hashes.

Host timing gives conservative analysis bounds, not chip timestamps. The end
of EVENT precedes `event_host_end`; capture starts after `arm_host_start`.
Their elapsed interval times nominal recorded Fs, plus a documented guard,
therefore defines an upper bound for a post-event analysis start. Model event
sidecars bound their own public data-write submission independently. Exact
absolute onset and register-latch latency are unqualified across devices.

## Extraction and acceptance limits

AM-only output supports the fixed known-carrier sine/cosine/DC projection.
Attenuation is logarithmic in positive projected amplitude. Quantized zero gets
an explicit missing/bounded log value, never an infinite measured attenuation.
Window/hop, actual recorded sample rate and residuals accompany the curve.
Fast waveform edges smear within the declared projection window.

PM-only output has a separately qualified constant amplitude and supports
positive unwrapped phase followed by local frequency/cents estimation. A global
constant-sine fit is reserved for disabled controls; it must not force changing
pitch to appear constant. Combined AM/PM cannot use a constant-amplitude inverse
sine without separate qualification. Noise has activity/distribution evidence
rather than a forced periodic-rate score or an assumed seed-aligned sequence.

Synthetic fixtures must exercise independently integrated phase, amplitude
laws, carrier phases, quantization, waveform transitions and intentionally wrong
or unmodulated inputs. An expected LFO rate may validate a measured period but
must not silently become the returned measurement. Insufficient cycles, depth
below resolution and invalid carrier assumptions remain explicit unscored
states. Cross-device shape comparison permits only one documented cycle phase
alignment, with no nonlinear time warps or independent alignment around events.

## Remaining LFO scope

Beyond the E0 depth/gate matrix, [C0 storage controls](lfo-storage.md) and
[selected C0 route/history tests](lfo-history.md), cover every rate code with
explicit finite/full-cycle limits, wider combinations of channel/operator
settings, further storage histories, and reset/hold/free-run writes during
operation. Weak W3 resolution remains a
separate limitation. W3 requires native sampling, repeated histories
and statistics qualified against the disabled path. Key-on alone must not be
assumed to restart the global LFO. The broader plan and public-API reference
review remain local in `artifacts/lfo-plan/findings.md`.

## Completed E0 pilot evidence

The v2 manifest SHA256 is
`f261b7fffa5695adabf9a2cf6920d28faa4b992ba01c7cb19265f6561b83847b`.
All 42 physical recordings (fourteen cases, three independent INITs each) pass
input/transfer hashes, requested frame counts, framing, exponents, bipolar audio
and continuous generation/reply checks. Markers advance from 2208 to 2460;
a subsequent silence command completes at generation 84/marker 2463. Idle-only
rearm archives those 2463 markers before the larger depth campaign, retaining
ROM hash, enable/mask, generation and monitor state without reset.

Both whole-chip models execute the exact 28 INIT/EVENT inputs and every internal
clock. Counts, 64*stride master-clock cadence, input/executable/CSV/sidecar hashes,
TEST-release event and pre/post nonzero audio pass. The five disabled gates have
identical stereo audio within each model; no cross-device sample identity is
claimed. Native W3 outputs are byte-identical between v1 and v2 references.

`host/modulation.go`, linked with `host/tone.go`, implements isolated AM/PM
extraction. Example for a stride 2 deterministic physical pilot:

```
go run host/modulation.go host/tone.go -mode pm -increment 65984 -sample-rate 27968.75 -native-stride 2 -window 32 -hop 4 -pre-end-sample 512 -start-sample POST_BOUND -expected-period 2048 -csv artifacts/fresh-pm-curve.csv artifacts/capture-0-0.csv
go test host/modulation.go host/tone.go host/modulation_test.go
```

The upper bound for guaranteed held data is independent from the lower bound
for guaranteed post-event data. `-pre-end-sample 512` stays well before the 8192
loop-count release in these fixtures. Default 0 leaves pretrigger quality
unevaluated. Data between that prefix and the conservative post-event bound
are not labelled held. Noise uses its native metadata and `-waveform noise`,
with no expected-period argument. Combined AM/PM is explicitly unqualified by
this isolated-mode tool.

| Scored state | Physical recordings | Reference outputs |
|---|---:|---:|
| Independently measured deterministic period |18|12|
| Disabled gate, no resolved modulation |15|10|
| Native noise activity/features only, no period score |6|4|
| Combined modulation retained but unqualified |3|2|

The 39 isolated physical pretrigger gates are stable. The fifteen disabled
physical recordings also fit an unbroken global carrier at increment 65984,
phase RMS approximately 0.002034 rad. These positive nonblank controls distinguish
zero modulation from a silent or disconnected signal path.

Measured deterministic physical periods span 2046.374–2048.843 retained samples,
with expected 2048 inside each reported estimator band; native normalization
is included. AM covers approximately 0–12 dB. PM saw/triangle span approximately
−25..+23 cents, and square approximately ±25.7 cents for this PMD64/PMS4 condition.
These endpoints retain discrete pitch quantization, projection-window bias and
repeat spread; they do not establish every depth/sensitivity setting.

The Go qualification covers 384 independently integrated-phase PM fixtures
(288 periodic, 96 noise; eight depths 5..800 cents, four carrier phases and three
LFO phases), plus 36 AM fixtures and 36 weak/no-modulation controls. Accepted reconstructed PM phase differs from
its known integrated truth by less than 0.005 rad after one constant origin.
Tests also cover no signal/modulation, insufficient cycles, a wrong/harmonic
expected rate, amplitude/carrier/alias violations, combined-mode rejection,
malformed/nonconsecutive data, quantized-zero logarithms, exclusive CSV output
and the independent pre/post bounds. Wrong expected periods do not become
returned measurements. Build, tests and vet pass.
The original pilot validation retains its 336-case snapshot; the later test-only
800-cent extension and weak controls are recorded separately in
`artifacts/lfo-depth-pm/comparison/tracked-qualification.json`. The deployed
analyzer source and executable stay unchanged through both matrices.

A separate artifact-only AM check qualifies fourteen independent PCM controls
and analyzes eighteen physical/twelve model traces. Direct midpoint crossings,
with declared hysteresis/refractory bounds and no frequency search, recover
physical periods 2046.888–2048.867 samples. It reproduces the gate/no-modulation
classification and demonstrates why smoothed saw/triangle endpoints differ
from a true 12 dB mathematical range. This is an independent method cross-check,
not a second vote substituting for the physical observations.

Shape comparisons use a single cycle-phase offset with no gain/vertical offset
or per-cycle time warp. They remain descriptive: Go fixed-bin RMS differences
reach 0.0903 dB for AM and 1.119 cents for PM, with a larger 7.65 cent saw-edge maximum.
Finite-window edge smoothing and unaligned discrete updates are retained; no
acceptance threshold is inferred from those chosen pilot residuals. No LFO
production defect is assigned from this limited E0 pilot.

Exact records and commands remain local under `artifacts/lfo-pilots` and
`artifacts/lfo-analyzer`: `physical-v2/qualification.json`,
`reference-v2/{reference.json,audit.json}`, `am-independent/summary.md`,
`results-v2.json` and `validation.json`. Sources and baseline stimuli are frozen
separately from generated captures and processing artifacts.

## Joint moderate-depth observability

`host/joint_modulation.go` supplies a separate qualified method for the combined
W2/E0 pilot. It uses a fixed 128-sample Hann-weighted sine/cosine/DC least-squares
projection, hop 8, at the known recorded increment 65984. Amplitude gives dB;
one unwrapped carrier-relative phase gives local cents through a fixed central
difference with half span 16 retained samples. Raw curves are unaligned and no
expected period is fitted. AM support is 128 samples; PM support is 160.

The 144 independently integrated synthetic triangle/control cases cover combined
12 dB/±25 cents, pure AM, pure PM and no modulation, four carrier phases, three LFO
phases, three DC values and a conservative 16-unit PCM quantum. Four unquantized
and four square-step controls, low-amplitude phase gaps and malformed inputs
are also checked. Full-window maximum error is 0.2841 dB/1.5417 cents at turns;
more than 96 samples from turns it is 0.0522 dB/0.1624 cents. These are qualification
grid observations, not universal analytic error bounds.

Pure-control cross-talk screening limits 0.25 cent false PM/0.12 dB false AM were
fixed before physical analysis. The synthetic maxima are 0.12590 cent/0.07283 dB;
retained physical/model pure controls reach 0.23385 cent/0.07430 dB. All fifteen
selected W2 records (combined plus matching pure controls across PCB/models)
have valid joint features with no high-residual window-limited points.

All three combined physical recordings and both models retain simultaneous
AM/PM: combined observed AM extrema 0.1737–11.7739 dB and PM approximately
−24.1949..+22.4714 cents. Thus AMD remains observable when PMD is subsequently
written in this INIT ordering. [Separate C0 controls](lfo-storage.md) now cover
reverse ordering and selected dynamic storage writes; other waveforms/depths
and histories remain open. Phase is absent below 512 PCM,
logarithm absent below 64 PCM, and derivatives cannot cross invalid segments.
High carrier residual marks a window-limited neighborhood. The original
moderate-depth qualification is not extended to deep/weak cases by those flags.

Source/executable hashes, synthetic proof and all fifteen exact commands are in
`artifacts/lfo-analyzer/joint/{validation.json,results.json}`. Go tests/vet pass.

## E0 AM depth, sensitivity and AME matrix

The 128 settings cover W0–3 × AMD{0,1,2,63,64,126,127} × AMS0–3 with AME1
(112), plus all waves/sensitivities with AMD127/AME0 (16). Exact manifest SHA256:
`cc8e9f2654c8a5d23d312b2ed896e366ca53932c4c92230be8d1506a88e35e42`.
All 384 physical captures and 256 complete whole-output references have matching
input/output hashes, valid metadata/cadence, clean framing/exponents and bipolar
nonblank whole/post-event signals. Generations/replies stay continuous; the
physical marker recorder advances 0→2304, followed by a successful silence command.

| Observation | Physical captures | Model outputs |
|---|---:|---:|
| Disabled AM, no resolved modulation |168|112|
| Deterministic period independently measured |144|96|
| Native W3 finite noise features, no period claim |48|32|
| Deep attenuation, quantization-limited |24|16|

All 128 cases have the same observation-state classification across the three
PCB repetitions and both models. All 240 resolved deterministic period estimates
contain the documented E0 period within independently measured window/crossing
bands. These are finite feature bands, not statistical confidence intervals.

The deterministic linear-amplitude endpoint screen has 384 model-endpoint checks
against physical triplicate ranges. Its common per-wave allowance comes from
288 independently quantized synthetic phase/depth cases plus decoded-quantum
LS propagation. For decoded PCM quantum q and the fixed projection dual, amplitude
error uses `q*sum(hypot(dual_sin,dual_cos))`; the vector-dual sum is 2.000047.
The physical range is widened by twice that error and a single synthetic phase
spread per waveform (ceil 64/2/5 PCM for W0/1/2). All 384 checks fit those declared
screening bounds; no per-case tolerance is fitted. The phase grid is finite and
this consistency does not establish exact waveform conformance.

Yamaha Fig 2.15's AMS1:2:4 attenuation scaling has 30 finite W1 checks consistent
within propagated decoded-quantum bounds. Six deep zero-pretrigger comparisons
remain censored. At AMD127, physical held estimates are 23.80349–23.81077 dB for
AMS1 and 47.76651–47.77151 dB for AMS2, with raw extrema −528..526 and −34..34 PCM.
AMS3 has exact-zero held PCM and receives no logarithmic gain or infinite-dB
claim. All later active captures contain nonzero transients of both signs.

There are 360 stable physical initial gates plus 24 absent/exact-zero pretriggers;
each model has 120 stable plus 8 absent/exact-zero. For deep W1, positive log
samples are transition-window remnants: apparent maxima 26–36 dB are not the
actual attenuation depth. Raw zero fractions and projection amplitudes remain
available; W3 distributions are unaligned finite observations, not seed or full
noise-conformance claims. No candidate LFO discrepancy is flagged by this matrix.

Evidence: `artifacts/lfo-depth-am/physical/{physical.json,qualification.json}`,
`reference/{reference.json,audit.json}`, and `comparison/comparison.md`/JSON.

## E0 PM depth and sensitivity matrix

The 224 settings cover W0–3 × PMD{0,1,2,63,64,126,127} × PMS0–7 with
AMD0/AMS0/AME0. Manifest SHA256:
`f8d8b2cf80ac0ba03aff74ab1ac691ef3891a10417754313a152108d7b58a453`.
All 448 whole-model outputs pass independent counts/cadence/input/output hashes,
range and 112 disabled-carrier gate audits. All 672 physical captures pass the
independent input/transfer/count/frame/exponent/generation audit and contain
bipolar, nonblank whole/post-event audio. Their reset-held gates are stable;
the 168 disabled-path controls also pass a global unbroken carrier fit.
The fresh verified-idle session archived 2364 previous reply markers without
changing generation 104, ROM bytes/enable/mask or resident CPU state. The batch
ends at marker 4032; silence succeeds at generation 169/marker 4035, followed by
another verified-idle archive for the next campaign.

| Observation | Physical captures | Model outputs |
|---|---:|---:|
| No resolved modulation |298|198|
| Deterministic period independently measured |279|186|
| Native W3 finite noise features, no period claim |95|64|

All 672 deterministic model endpoint checks fit the common screen below, and
all 465 resolved PCB/model period bounds contain documented E0 recorded 2048/
native 4096. Of 224 complete settings, 223 have matching observation states across
the three physical repeats and both models. One weak-noise case is retained as
a resolution-boundary review, not a forced pass or a confirmed production gap.

Depth scoring retains the frozen isolated extractor. A separately frozen common
6-cent deterministic endpoint screen comes solely from an independent 1152-case
synthetic phase/depth grid through ±800 cents, including 96 at 800. The largest
synthetic endpoint phase spread is 4.7461 cents; the two-observation zero-control
floor is 0.8977 cents. Each component is rounded up once, giving 5+1 cents, before
physical metadata/samples are read. This is a finite-grid screening allowance,
not a universal error bound or a fitted per-case tolerance.

Weak modulation is separately characterized with 672 independent synthetic
controls at 0/.02/.1/.5/1/2.5/5 cents, four waveforms, four carrier phases, three
LFO phases and ideal/generic-1024-step phase precision. Zero/.02/.1 remain
unresolved; .5–2.5 can have waveform/phase-dependent classifications. Five-cent
deterministic controls are fully detected. No universal sub-cent leakage bound
is inferred. In both models, selected PMD1 saw/triangle outputs are byte-identical
to their disabled controls even at PMS6/7, while square/noise differ; weak
waveform quantization cannot be replaced by an assumed smooth modulation law.

Specifically, W3/PMD1/PMS6 has physical post-event P95−P05 spans 1.99672/2.03338/
1.99245 cents, but its independently measured activity floors are 1.79820/1.16093/
2.12056. The third recording therefore remains `no_resolved_modulation`; the
other two and both models report `noise_features_only`. The underlying spans
are close, but the finite pretrigger-jitter floors differ. No floor, state,
stimulus or tolerance is changed after seeing that result. W3 endpoints and
distributions remain unaligned finite observations, without a seed/period claim.

One documentation discrepancy has independent physical evidence. Primary
Fig 2.8 (printed 18/PDF 19) lists nominal PMS7 ±700 cents. At PMD127/W1, guarded
raw PCM rising-zero-crossing intervals yield physical half-spans 793.81608–
793.82891 cents, compared with both models approximately 793.828. PMS6 gives
396.07092–396.07677 physical cents, versus approximately 396.08 in the models.
These frequency estimates use at least ten crossings in long plateau interiors,
with 32-frame edge guards; local phase extraction only locates the square
plateaus. They independently corroborate the phase estimator and do not use its
inverse-sine reconstruction to measure frequency. The approximate 700 printed
value is a documentation/measurement difference, not a jt51 defect. Scope remains
this KC/carrier/full-depth condition; the exact pitch steps are retained.

Evidence: `artifacts/lfo-depth-pm/reference/{reference.json,audit.json}`,
`comparison/{screen-config.json,weak-synthetic/qualification.json,independent-square.json}`,
`physical/{physical.json,qualification.json}`, and `comparison/comparison.md`/
JSON. No candidate jt51 LFO defect is assigned from this finite campaign.

The [deterministic waveform figure](http://gitea.jotego.es/attachments/beb825f2-5752-49a4-ac05-9d213a0ba4a8)
uses the original pilot, a single measured crossing origin per recording and
fixed period bins. Repeat ranges are descriptive; native W3 is intentionally
absent from this deterministic plot.

## Output-visible markers and corrected pan labels

Direct visual inspection of primary section 2.1.8 ACC (printed 14/PDF 15)
establishes register 20 bit6=LEFT and bit7=RIGHT. Figure 2.17 (printed 21/PDF 22)
also labels SH1 RIGHT and SH2 LEFT. The physical pan controls map latch0 to LEFT
and latch1 to RIGHT. Earlier helper/artifact human names were reversed; the
original files and hashes remain intact. The corrected built-in pan programs
have regression coverage, and canonical both-pan bytes remain unchanged.

`host/lfo_marker_programs.go` generates three C0/W2 fixtures: constant carrier,
isolated AM and isolated PM. These use native increment 4124, stride 8, retained
increment 32992, nominal recorded Fs 6992.1875 and 16384 stereo frames. Following
TEST release, EVENT clears/restores bit6 three times using 87/C7, with delay
counts 1024/2048/1024 for the muted intervals. Bit7 stays enabled. A matched
control removes only the pan writes and preserves every delay; model comparisons
use identical within-column capture clocks, without event-by-event alignment.

All nine physical recordings pass the independent input/transfer/frame/exponent/
generation audit. Left/latch0 has exactly three long exact-zero runs; right/
latch1 has none. The short/long marker durations are 75–76/150–151 retained
samples. Constant right phase fits span increments 32992.000026–32992.000280,
RMS 0.0020324–0.0020451 rad across the complete record. These demonstrate finite
constant-carrier continuity through the markers, not physical sample identity.

All twelve model marked/control runs pass transport/cadence/range audits.
Both models place the three zero runs in CSV left and the continuous path in
CSV right. jt51's right samples and extracted curves equal its no-pan controls.
OPM instead changes 228–232 right samples only while left is muted, with maximum
240 PCM and whole-record difference RMS 10.23–12.13 PCM. The OPM API-to-CSV channel
mapping is correct; differing serial latch ages alone do not explain this
within-column marked/control difference. No external model, wrapper or RTL was
patched, and OPM is explicitly marked mismatch for strict sample isolation.
Physical modulated continuity has a separately qualified diagnostic. A fixed
33-point harmonic-polynomial carrier residual uses truly interior marker
samples. A separate 129-point Hann projection predicts the early marker region
from one eight-harmonic trajectory fitted only to late samples 5000..14000;
samples 3000..4800 are held out. Its period search 1900..2200 is an exploratory
coherent fit, not the crossing-based rate acceptance used for the E0 matrices.
There is no per-event phase fit, waveform stretching or cycle warping.

Physical interior residual RMS is 15.79–16.75 PCM for AM and 11.36–12.05 PCM for
PM, versus OPM marked 76.71/87.33 and no-pan 19.35/14.56. Independent synthetic
gain/phase/corruption controls resolve 1 dB, 0.01 rad and marker-only 240 PCM errors.
Pasting the actual OPM error sequence into physical recordings, unstretched at
three fixed integer shifts, raises residuals to 73.74–77.13/84.17–87.76 PCM.
The physical data show no counterpart at that size/pattern class. PM marker
phase RMS 0.00053–0.00062 rad is comparable to its held-out 0.00064–0.00066 rad.
AM has a larger early residual, up to 0.160 dB, so exact shape identity is unclaimed.
The projection overlaps the short mute boundaries; the raw interior diagnostic
and sensitivity controls are necessary alongside the smooth trajectory.

No physical same-clock no-pan counterfactual exists. Small coupling, other
waveforms/rates/channels and the cause inside OPM remain unestablished. These
finite continuity observations do not establish physical byte identity or a
universal minimum detectable disturbance.

Evidence is retained under `artifacts/lfo-markers`: `generator-validation.json`,
`physical/{physical.json,qualification.json}`, `reference/proof.json`,
`reference/continuous-isolation-review.json`, `pan-labels-and-api.md`, and
`continuity-review/{summary.md,synthetic-qualification.json,opm-difference-injection.json}`.
