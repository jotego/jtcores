# Finite live-register and operator-key history measurements

This report uses reviewed input manifests and completed original outputs. No new captures, model runs, helper calls,
phase/gain alignment, numerical acceptance band or RTL change were introduced
while packaging this report. It records these two completed finite scopes;
other supplemental rate/pitch/model joins remain separate.

## Acquisition and public-output scope

The Diet Go Go/direct-YM-serial bench, resident HuC monitor and 28-pin PicoROM
remain the qualified replacement for the old X-Men/K054539 route. Native
records retain both physical latches (LEFT 0/RIGHT 1), 16384 target frames and
4096 whole-zero quiet frames. Explicit stop-CSM-first/RR15/all-keyoff cleanup
and independently recorded whole quiet precede each target; target INIT and
literal EVENT bytes are hash-bound. Software conditioning does not imply a
physical chip reset. Production JT51 remains `985a573`; frozen whole-output
JT51/OPM references remain separate implementations.

History93 uses 279 independent targets, 279 paired quiets and one final quiet:
559 captures, 558 public target streams. ROOT acquisition 63451 terminated 0 at
84/3354; descriptor extraction 85051 terminated 0 with 330 distinct helper calls
and 660 physical↔model result links. Independent audit 66940 terminated 0,
rehashing 6767 inputs / 1276 outputs and independently reconstructing all 558
whole/prefix512/post/last4096 descriptor dictionaries. The 330 calls are
102 curve-only, 48 energy and 180 controlled-sine phase; each physical call is used
for BOTH model comparisons rather than run twice. All actual horizons qualify:
post 6998–14251 leaves 2133–9386 native frames. Raw validity and feature states
remain separate from scientific agreement.

The original frozen whole-model reference has 186 audio captures (93×2) and
eight separate timer-status executions, with 220 original helper calls. Its
quiet and active OPM phase exceptions remain unchanged. The separately
completed 12 physical mid-run A/B STATUS commands are not audio captures and
are not added to this 559-capture total.

Actual physical post is
`ceil((event_host_end-arm_host_start)*56093.75)+128`, using a conservative
3.59 MHz upper bound derived from the user's on-pin 3.57–3.58 MHz measurement
and 0.01 MHz tolerance. Original nominal metadata remains
55937.5 Hz. Model post uses public-last-EVENT-write+128 instead. Neither is an
accepted internal write/scan timestamp; different CPU/model timing and finite
phase/history prevent an assertion of sample identity.

## Recorded groups and original feature states

|Group|Public streams|Whole bipolar|Whole exactzero|
|---|---:|---:|---:|
|live-routing|24|24|0|
|live-envelope|72|72|0|
|rastan-fragment|24|24|0|
|csm-complement|48|42|6|
|noise-routing|96|96|0|
|channel-pan|168|84|84|
|twochannel-start|12|12|0|
|live-global-lfo|30|18|12|
|live-pitch-complement|36|36|0|
|mixed-pairwise|48|48|0|

The 102 curve-only invocations retain 90 `curve_only` and 12 `no_signal` results
(the intentional RIGHT quiet live-LFO streams). Recorded nonquiet curves are
unaligned amplitude curves with original 65984/W32/H8 assumptions. No automatic attack/fall duration,
plateau eligibility, live-rate priority or envelope-stage conformance follows
from successful curve generation. Intentional quiet channels remain quiet
observations, never positive controls. Live D1L/AR/KS/RR/keyoff pairs, live LFO
wave/rate/common-channel pairs and matching no-ops retain their full original
history and input references.

All 96 nonquiet pan/twochannel phase fits return 0, round to 65984 and retain
phase RMS 0.00202792743–0.002052128785 rad.
The 84 exact-quiet pan streams return 1 under the unchanged guard and remain
unqualified phase features. Both latches/all pan states are preserved. This is
a stationary post-window carrier observation, not proof of accepted-write
phase, absence of every transient, or a correction of the retained active OPM
pan-reference failures.

The 48 CSM energy results are 18 finite repeated cadence, 18 no resolved energy
modulation, 6 exact quiet and 6 unqualified fast cadence. First-simultaneous,
first-running and live TL automatic profiles retain 18 period diagnostics at
511.42548–511.50406 native samples with original ±64 sample support containing 512.
P128 retains six original `unqualified_fast_energy_cadence` results despite
finite diagnostic crossings; it is not promoted to a qualified cadence. P1 auto,
P1 manual-held and live TL manual retain 18 no-resolved results. Disabled P1 retains
six quiet results. Their original numeric period field 0 is an unresolved/default
representation, not a measured zero period. Status, audio, internal key-pulse
width and physical IRQ remain different observations. These results do not
create a new gap classification or erase the existing automatic-CSM gap.

Composite ALG/noise/mixed/pitch/Rastan streams retain raw populations/RMS,
pre/post/tail and literal histories. No isolated two-level noise-clock score
or inherited 65984 single-carrier fit is applied to multicarrier/noise/musical
outputs. The 660 side-by-side records preserve each exact frozen model result,
including unqualified/quiet states, with no model-agreement requirement or
case-specific band.

## Separate mid-run timer-status observations

Four literal preload-change programs were executed three times each. LOAD stays
high across the change and explicit flag clear; the program waits 512 calibrated
CPU delay counts, reads register 03, then stops and clears with register 14=30.

|Timer|Preload change|Observed status, three independent runs|
|---|---|---|
|A|slow to fast|0, 0, 0|
|A|fast to slow|0, 0, 0|
|B|slow to fast|0, 0, 0|
|B|fast to slow|2, 2, 2|

Three separate Timer-A positive controls return 1, 1, 1. Final cleanup returns
status 0. `timer-status-v1/results.json`, `A-positive-control.json` and
`ROOT-completed-status-review.json` retain the literal programs, replies,
generation/marker chain and source hashes. The corresponding frozen model
observations also return 0/0/0/2; the models use 32 master clocks per delay count,
while the physical CPU delay calibration is approximately 37.5. Agreement of
these status bits does not establish exact timer reload cause, accepted-write
priority, overflow clock or physical IRQ behavior. These 12 STATUS commands and
four positive-control/cleanup commands are separate from audio capture totals.

## Separate operator-key histories

Six fixtures supplement the CHANNEL-start experiments without altering History93:
ALG0/7 each compare all-key no-op, staggered M1/M2/C1/C2 starts and partial
off all→C2. Public register-order M1/M2/C1/C2 has offsets 0/8/16/24 and
key bits 08/20/10/40. Distinct MUL1/2/3/4 and TL32/48/40/24 remain literal;
CSM/noise/LFO/feedback are disabled. Four EVENT masks are 78/78/78/78,
08/28/38/78, or 78/78/78/40, after 8192 counts and three 512-count intervals.
Models' 32 master/count is not asserted equal to physical CPU timing.

ROOT key37 acquisition 72114 terminated 0 at 158/3576: 18 targets with 18 paired
whole quiet and one final quiet. Original descriptor execution 91864 terminated 0
and retained 36 public-column descriptions / 72 model reference links, with ZERO
feature helpers or phase fits. Independent audit 12500 terminated 0,
rehashing 417 inputs / 40 outputs; all 36 raw dictionaries and 72 links match. All 18
actual horizons qualify, post 8100–8685 leaves 7699–8284 native frames. All 36
post streams are nonzero/bipolar. The 12 frozen whole models and their 24 public
streams were separately audited. Signed populations, level changes, return/
release tails and differing RMS remain descriptive because relative operator
phases and exact hidden history are not controlled. No per-operator phase,
gain, ideal-sum or causal routing correction is introduced.

## The exact old Rastan trace remains missing

The four History93 Rastan fixtures preserve literal selected channel 6 program
bytes, comparing conditioned versus one preceding same-program note with an
explicit monitor timing transform. They do NOT replay the exact preceding
98,880-write `rastan-ym2151.csv` music trace from jt51 #1. The retained issue,
19 comments and original public harness provide no attachment/origin/download
path or trace checksum. The source explicitly kept that input external. The
user answered the location question **“Not anymore”**, recorded verbatim in
`issue-audit/user-trace-availability.json`. Origin searching has stopped.

That exact preceding-history requirement remains UNMEASURED / INPUT-MISSING,
not a physical observability limit and not replaced by a synthesized prior
note. Its checkbox remains pending; blocked measurement rounds/parents must
not be closed as though it had run. #14 remains open for the existing six
supported implementation requirements. No additional Cartesian campaign or
implementation permission follows from these completed finite measurements.

## Reproducible evidence

Evidence paths below are relative to
`tasks/ym2151-archive-20261018/artifacts/` in the reconciliation supplement.
See [archive.md](archive.md) for the permanent archive and extraction paths.

- `remaining-history-v3/programs/cases.json`: exact 93 literal fixtures and
  `remaining-history-v3/model-proposal/completed-handoff.json`: frozen 194/220 reference outputs.
- `scores-history-v1/{observations.json,comparisons.json,pins.json,TERMINAL.json,independent-audit.json}`:
  actual 330/660 outputs, source hashes, all original failures and raw streams.
- `remaining-key-history-v1/{handoff.json,completed-model-handoff.json}`:
  exact 6 programs/literal validator, 12 models and public-input provenance.
- `scores-key-history-v1/{observations.json,comparisons.json,pins.json,TERMINAL.json,independent-audit.json}`:
  actual 36/72 raw-only descriptions and comparison references.
- `issue-audit/final-coverage-v1/TRACE-INPUT-FINDING.md` and the user's durable
  availability answer: unresolved external-input distinction.

The source/body preservation proofs, ROOT source/data bindings and independently
verified input/output hashes accompany each controller. Raw artifacts are preserved externally to permanent source. Archive verification
establishes preservation of the evidence; it does not resolve an unqualified
scientific feature or the missing original trace.
