# YM2151 audio-noise measurements

Measurement work for jtcores #143. Production jt51 remains frozen at
`985a573dcfc1ff135553a39f7eae21d18ba57cbe`; external OPM remains unchanged at
`a0ab44be60cb28b68431779829454ddf3284f272`. LFO waveform 3 and audio-noise
register 0F are separate mechanisms. This report concerns the latter.

## Primary interface and acquisition scope

The [Yamaha application notes](../../../modules/jt51/doc/yamaha/ym2151_app_notes.pdf),
printed page 10 / PDF page 11, section 2.1.5, identify register 0F bit 7 as NE and bits 4:0 as
NFRQ. Noise replaces slot 32, C2 of zero-based channel 7; the slot/register
figures on printed page 16 / PDF page 17 were visually checked. Its own envelope still
controls the output, but the normal logarithmic amplitude conversion is
bypassed. Normal sine-path TL attenuation must not become a noise-gain oracle.

The primary gives approximately 3.5–111.9 kHz and a nominal 17-bit sequence period
of 1.17–37.5 seconds. Its denominator notation does not unambiguously map the raw
five-bit code in this scan. Reference interfaces motivate candidate divisor
`D=32-code`, or `D/2` native sample intervals per update opportunity. This is
a hypothesis for sampled-output tests, not an independently established
internal counter implementation. At the highest codes, native PCM cannot
observe every possible hidden update.

Each recording retains 16384 consecutive stereo frames at stride 1, approximately
0.292898 seconds with nominal Fs 55937.5 Hz. The user's 3.57–3.58 MHz on-pin master
measurement has 0.01 MHz tolerance; sample-domain timing is primary. None of
these short native records establishes a full noise period, seed, polynomial
or physical/model sequence identity. There is no additional decimation filter.

The 48 target profiles include all 32 NFRQ codes, three NEoff codes, five
other-channel/operator isolation controls, four TL controls, never-keyed,
KEYOFF, finite AR24, and NEoff/on/off. Other voices are off, both LFO depths
and all AMS/PMS/AME are zero, ALG7/feedback 0, KC4A/KF0, DT1/DT2 zero, MUL0,
AR31/KS0/D1R0/D2R0/RR15 except the declared control. Ordinary sine controls
use separately qualified native increment 4124; noise amplitude is measured.
Key masks follow the primary offset mapping 08/20/10/40 for M1/M2/C1/C2.

## Conditioning and reproducible programs

Every target has an independent cleanup and quiet capture. The order matters:
NEoff first, all 32 E0..FF=0F writes before all 8 key-off writes, then at least
0.5 seconds measured by the host monotonic clock after the successful reply.
At least 4096 consecutive exact-zero native PCM samples on both latches must
be captured before full target INIT. Old RR0 envelopes and keyed TL127 noise
must not be assumed silent. NEon never-keyed/KEYOFF residual floors are a
separate measurement and do not relax the NEoff cleanup requirement.

Twelve adverse preflight captures qualify this wait: all 32 held RR0 operators
and NEon/TL127 held RR0, each observed before and after cleanup, three repeats.
Every held record has both signs on both outputs; all six cleaned records
are zero throughout. The shortest measured cleanup wait is 0.500137945 seconds.
Hashes, framing/exponents, counts and continuous generations/markers pass.

`host/noise_programs.go` creates separate physical INIT and model INIT. Model
INIT includes the same cleanup and 1790016 master-clock finite wait; it is not
a substitute for physical host-wait/quiet qualification. All 144 target program
payloads, eight preflight payloads and cleanup reproduce byte-for-byte, 153 in
total. Independent literal/full-register/key/control checks and four CLI
negatives pass. The original frozen manifest is
`5b9a8fe47a70a6b7650c902ac3685a2752a2ed61d6150feed2bea93a37e8ff3c`.

Physical capture used a frozen timestamp-instrumented artifact snapshot.
The permanent `scripts/capture-event.py` now has the identical capture-function
AST: it records its own source hash, successful INIT-reply monotonic time and
the measured settle interval before arming. Artifact-directory import/root
resolution is the only surrounding difference. Original metadata and hashes
are preserved; no earlier capture is relabelled as using the promoted source.

## Output descriptors, screens and limits

The frozen native scorer uses two-level support `max(2 PCM,0.001*span)`, requires
span 32 PCM, at least 32 samples in each population, at least 32 sign changes and
no samples outside that support. Silence, stuck output, low level, insufficient
transitions and nonstationary output retain separate states. Changing envelopes
are not forced through a steady classifier. Raw unique levels/counts/extrema
are retained even when a clock or two-level-rate score is unresolved.

Compatible update lattices are inferred from observed sign changes on the
first half, then evaluated with the same phase residue on the held-out half.
All compatible divisors/residues and contradictions are retained. An unchanged
sign does not prove no update. The coarsest compatible lattice is descriptive;
codes 30/31 do not identify one versus multiple hidden updates per native sample.
Run histograms, sign balance, correlations, mean/RMS and transition fractions
have no per-code stochastic or IID pass band fitted to the PCB.

Low/high model levels are compared independently against physical triplicate
ranges widened by the model support plus the largest physical support, using
one common formula. This is a finite quantization/method screen, not universal
analog accuracy. Low-level clock ambiguity does not erase a directly observable
PCM-level disagreement. Both model comparisons retain their own outliers.
Ordinary sine controls require nonblank output, fitted increment rounding 4124
and phase RMS below 0.01 rad; their amplitudes remain descriptive.

Actual final EVENT writes use a conservative live upper bound:
`ceil((event_host_end-arm_host_start)*55937.5)+128`. At least 1024 native frames
must remain. Empty EVENT cases use 128..16384 after settled INIT. Guaranteed
prefix 128..512 is a limited descriptor/control, not a full short-window clock
qualification. KEYOFF/attack final 4096 windows must follow the final-write guard;
their raw floor or changing envelope is retained. No final upper bound is used
as a pretrigger or middle-state boundary.

For NEoff/on/off, an additive diagnostic classifies every disjoint 1024-sample
block. At least two adjacent steady-noise blocks with consistent levels,
between a qualified initial sine and final sine, identify an **observed stable
noise interior**. All block states remain visible. It establishes neither exact
write latency, the entire bus-defined middle interval, absence of boundary
glitches nor short-window recovery of an internal noise clock.

## Independent qualification and source validation

1152 generic Bernoulli-held native fixtures cover all 32 candidate divisors,
four phase entries, three seeds and three amplitudes with DC/quantization.
The true candidate remains compatible; all 72 D1/D2 cases retain ambiguity.
Biased, silent, stuck, sine, mixed, changing-gain and low-level controls have
explicit states. Nine malformed CSV/CLI/bounds checks reject. These independent
signals contain no imported chip taps, seed or random-state algorithm.

The observed-interior diagnostic has 54 independent tone→generic-noise→tone
controls varying transition boundaries and carrier/noise phases; all select
an interior patch. Twelve all-sine/stuck/mixed/changing-gain controls select
none. All 1056 block classifications are retained. The limited prefix and final
sine fits also pass. These are finite listed scenarios, not a universal
classifier or bus-timing qualification.

Promoted generator/scorer bodies differ from the frozen originals only in
their comments, and the strict tone CSV reader is identical. The promoted
1152-fixture and control reports reproduce exactly. Tests write into temporary
directories by default; optional `JT143_NOISE_QUALIFICATION_DIR` must designate
a fresh existing directory for durable qualification reports. Go build/tests/vet
and capture-script syntax/import/help/AST-equivalence checks pass.

## Physical results and retained endpoint limits

The initial campaign contains 300 native recordings: 144 targets, 144 immediately
paired cleanup observations and 12 adverse preflight records. All transfer/input
hashes, framing/exponents, counts, CPU generations and live timing gates pass.
Every paired cleanup record is zero throughout on both outputs; the shortest
measured wait is 0.500067091 seconds. The smallest actual post-EVENT horizon
after the fixed guard is 5113 native frames.

| Observation | Scoped result |
|---|---|
| All 32 codes × 3 repetitions × 2 outputs | All 192 steady observations have levels −2044/+2040 PCM. Candidate D=32−code remains compatible; the coarsest compatible value agrees for codes 00..1D. Codes 1E/1F remain ambiguous at native rate. |
| NEoff and channel/operator isolation | All 90 segment/output sine fits round to increment 4124; phase RMS 0.001854–0.002125 rad. |
| TL16/32/64 | Levels −1788/+1784, −1532/+1528 and −1018/+1016 PCM, matching both models within the fixed screen. |
| Keyed TL127 | Levels −9/+8 PCM; observable low-level positive, not silence. Its clock/gain classification remains unresolved. |
| Finite AR24 | Guaranteed off prefix is zero; evolving attack is excluded; final 4096 frames reach full steady noise levels. No attack-time equivalence claim. |
| NEoff/on/off | All six output observations identify a stable noise interior between qualified sine controls. All fixed block states, including boundary failures, remain retained. |

There are 328 frozen endpoint comparisons: 314 inside the common screen, six
outside and eight unqualified. All six outside comparisons are OPM's −8 lower
floor against physical 0 in the never-keyed, released and AR24 pre-key conditions,
on both outputs. The eight unqualified entries are the short KEYOFF-prefix
noise descriptors, which have insufficient transition coverage; they are not
relabelled as passing. KEYOFF INIT is byte-identical to the full steady noise 0F
positive INIT, SHA a73965e1ac5d6f42aa09c4bcc2f53a11351ef7c366b4c12c5094bfc18d236b63.
Its three full steady counterparts establish the initial positive path separately,
without claiming recovery of a clock from the short KEYOFF prefix.

## Off-state observation and independent input-pin proof

Physical NEon never-keyed output is zero for all 16384 frames on both latches,
in three initializations. KEYOFF final 4096 and the guaranteed AR24 pre-key
prefix are also zero. Frozen public jt51 output instead contains −1/0 PCM;
OPM contains −8/0 PCM. Both models retain their never-keyed floor in every
4096-frame quarter. Host wrappers pass their public low-resolution/DAC values
unchanged; full-resolution jt51 auxiliary outputs are not accepted as PCB data.

The declared tiny-level pair screen is 4 PCM: jt51's −1 lies inside it and is
not called a failed numerical screen. It is still a directly observed difference
from the PCB's exact-zero state. OPM's −8 exceeds the unchanged screen. This
is a scoped digital output-floor observation, without an internal cause,
inferred constant, proposed RTL fix or broad noise correctness conclusion.

Focused validation adds 18 native recordings and 45 input-pin recordings:
never-keyed, KEYOFF and keyed TL127, each with three independent INITs and
its own cleanup capture. Mode 1 samples the SO/SH input pins at 100 MHz. The Go
alternating-strobe/bit-center decoder and an independent Python integer decoder
agree on every word; all transfer/native-input hashes and framing/center-stability
checks pass. Known-word/latch/inversion controls and an injected unstable-center
negative qualify the independent decoder. No physical/model sequence alignment
is used.

Each latch's raw never-keyed sample set has 215 words and its KEYOFF set 213,
all `0x3004`: exponent 1, biased mantissa 512, exact 0 PCM. Matched NEoff raw controls
also contain 0. The keyed TL127 positive has 214/213 words across the latches,
resolving −9/+8 PCM with exponent 1 and biased mantissas 503/520. This demonstrates
low-bit visibility alongside the silent controls. Unspecified raw low bits are
preserved rather than normalized away. Model −1 and −8 are representable at
this format's 1-PCM resolution; actual physical words, not representability alone,
establish the zero observation.

The raw audit originally demanded both signs in every approximately 18-word
positive snapshot. That was too strict for a held random bit. The supplemental
audit preserves the failed report/source, permits either sign in an individual
snapshot, and requires both signs across the declared positive aggregate.
All words and the frozen comparison method remain unchanged.

Ten additional frozen-model outputs test finite warm history and longer settling.
Both models first produce the held-noise positive, then exact zero in the matched
NEoff cleanup companion. After that same held→cleanup→wait prefix, a full
never-keyed INIT still produces jt51 −1/0 and OPM −8/0. An independent cold
never-keyed control with four additional seconds of settling retains the same
floors in every 4096-frame quarter. Warm KEYOFF controls retain those respective
floors in the final 4096 frames. The explicit cleanup wait is 1790016 master
clocks, followed by 1048576 clocks corresponding to a 16384-frame quiet
observation; target settling adds 179008 clocks. Public bus/busy clocks and the
wrapper's additional 4096-clock settle are recorded separately.

These controls narrow the tested startup/history explanation without equating
hidden states or physical write latency. The quiet companion observes the same
prefix independently; no continuous observation of its entire dwell is claimed.
The initial 104 model outputs plus these ten controls give 114 reference outputs.
The original 328 endpoint comparisons and their fixed screens remain unchanged.
Exact payloads, waits, quarter counts and hashes are in the local
`physical-method/model-warm-controls/REPORT.md` and `validation.json`.

The read-only MAME/ymfm review predicts zero for an off envelope; this is
source-based inference, not a third executed capture or borrowed implementation.
Its source hashes/citations and the public-output quantization boundaries are
preserved with the local evidence. Production jt51 and external OPM are unchanged.

![Native noise controls and off-state levels](http://gitea.jotego.es/attachments/dc23b48e-b89b-460b-9e47-c91a84c04b93)

The figure uses original native sample indices and the right output; both
outputs are independently audited. Grey shading is the unchanged 4-PCM screen,
not exact equality. PNG/PDF, input hashes and plot source remain local.

## Reproduction and local evidence

From the task directory, with fresh output paths:

```
go run host/noise_programs.go -output artifacts/fresh-noise-programs
go test host/noise_score.go host/tone.go host/noise_score_test.go
go run host/noise_score.go host/tone.go -column linear -start-sample 128 artifacts/capture-0-1.csv
```

Use model column `right` or `left`; physical latch 1/0 has column `linear`.
Raw audits and source/input/output hashes are under `artifacts/audio-noise`,
particularly `programs-v2/`, `physical-preflight/`, `physical-matrix/`,
`physical-floor-pins/`, `reference-matrix/`, `reference-preflight/`,
`physical-method/` and `promoted-validation/`. Total physical scope is 318 native
stereo recordings and 45 raw-pin recordings; the 318 comprise 144 targets,
144 per-target quiet captures, 12 adverse preflight and 18 focused controls.
Compiled binaries, raw captures and plots stay
local. Other envelope/TL codes, LFO coupling, algorithms, simultaneous mixes,
full sequence periods, reset seeds and dynamic frequency histories remain
separate coverage.
