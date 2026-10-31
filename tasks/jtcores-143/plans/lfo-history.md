# C0 LFO route isolation and selected history

Measurement work for jtcores #143. Production jt51 remains frozen at
`985a573dcfc1ff135553a39f7eae21d18ba57cbe`; the external public-API OPM model
remains at `a0ab44be60cb28b68431779829454ddf3284f272`. This campaign extends
[waveform/depth coverage](lfo-measurements.md) and [storage controls](lfo-storage.md).
It does not complete every rate, history, algorithm or combination.

## Stimuli and operator mapping

Primary [Yamaha application notes](../../../modules/jt51/doc/yamaha/ym2151_app_notes.pdf),
printed page 5 / PDF page 6, map register08 key bits to
M1,C1,M2,C2; printed16/PDF17 groups operator registers as M1,M2,C1,C2.
Both pages were visually checked. Ascending register offsets therefore use:

| Operator | Offset plus channel | Key mask OR channel |
|---|---:|---:|
| M1 |0|08|
| M2 |8|20|
| C1 |16|10|
| C2 |24|40|

Values are hexadecimal in the key-mask column. The older C2-only programs
already use40. Natural register order must not be substituted for key-bit order.

The generator creates 108 fixtures:32 zero-depth route baselines,32 AM,
32 PM and12 selected histories. Each starts from the canonical all-register
tone program, removes its original C0/C2 voice, then selects exactly one
operator/channel in ALG7, feedback0, KC4A/KF0, DT1/DT2zero, MUL0, TL0,
AR31/KS0/D1R0/D2R0/RR15. Other voices are key-off/TL127. Audio noise is off.
LFRQ=C0, waveform2, stride8,16384 retained stereo frames; nominal Fs6992.1875Hz.
The C0 nominal period is2048 retained/16384 native samples. Hz depends on the
user's3.57–3.58MHz on-pin clock measurement with 0.01 MHz tolerance.

Each baseline has initial/final AMD=PMD=0. Its three LEFT mute markers contain
ordered negative probes: nonselected-channel PMS/AMS with both depths64;
selectedAMEoff before selectedAMS1 with a different operator's AMEon; then
restoration and zero depths. Every intermediate register state was independently
checked to leave the selected output unmodulated. Whole RIGHT amplitude and
global phase observations are retained separately from the late calibration.
Late-only qualification must not conceal an earlier disturbance.

Positive routes select AMD64/AMS1/AMEon/PMS0 or PMD64/PMS4/AMoff. No route
inherits another voice's carrier calibration. Latch0 is LEFT, latch1 RIGHT;
the selected RIGHT output continues through ordinary LEFT pan markers.

## Generator and extractor qualification

Frozen artifact manifest SHA256:
`2ef172646d2625fe7e9db2955fb90d33e161baa78fdfc00e867a6aeb052d838d`.
The permanent `host/lfo_history_programs.go` reproduces all 216 original binary
payloads and every manifest field except output paths. Independent checks
cover all 224 per-channel/operator registers, globals/depth selectors, key masks,
literal event operations, safe negative-probe ordering, final states and
conservative acquisition horizons.36 malformed-base/CLI/reuse checks pass;
Go build and vet pass. Artifact generator/source hashes remain preserved.

The existing isolated extractor is unchanged. New `host/lfo_routes_test.go`
qualifies its C0 fixture settings: retained increment 32992, window 64/hop4,
pretrigger 512, expected period 2048 only checked after independent measurement.
96 independent native-integrated AM/PM fixtures vary carrier/LFO phase,
half-native-frame latch age and ideal/generic1024-step carrier precision.
All original per-observation endpoint guards pass:0.3dB AM and2cents PM;
maximum measured-period error3.520675 retained samples. Zero-depth controls
remain unresolved and wrong expected periods cannot become measurements.

Before physical positive captures, one common finite comparison screen was
frozen: each model endpoint must lie within the PCB triplicate endpoint range
widened by0.6dB AM or4cents PM, the sum of two per-observation synthetic guards.
This is a finite-grid screen, not a universal precision guarantee. Original
failures remain visible; no route-specific band is fitted. Stable pretrigger,
resolved periodic state and a measured period interval containing2048 are
separate requirements. No ideal symmetric PM depth is imposed on quantized
pitch output.

The separate129-point squared-Hann extractor also emits unaligned curves.
Its h² kernel,64/80-sample support and phase/log floors are unchanged from
the storage checkpoint. Its old AMD127 corner failures remain recorded.
The window 64 isolated and129-point projection qualifications are distinct.

## Completed route calibration

All 96 PCB baseline recordings pass hashes, framing/exponents, requested counts,
bipolar audio, three LEFT mutes, continuous RIGHT, and CPU generation/marker
continuity. All 32 routes qualify rounded retained increment 32992/native4124:

| Observation | Physical range |
|---|---|
| Whole RIGHT global fitted increment |32991.9995227–32992.0003434|
| Whole phase RMS |0.00202942–0.00204573 radians|
| Late zero-depth fitted increment |32991.9994106–32992.0005188|
| Late phase RMS |0.00202802–0.00204155 radians|
| Late projected carrier peak |8169.3851–8169.5082PCM|

Across every whole recording, including negative probes, projected amplitude
is8165.8889–8173.5329PCM; the largest within-record span is7.6440PCM,
or0.00812692dB. These are descriptive finite observations, without a new
threshold inferred from the observed values or a physical byte-identity claim.

All 64 model baselines also qualify 32992 after a derived CSV-index repair.
The original runner cropped late data without renumbering sample indices;
the strict reader correctly rejected those derived files. Original failures
remain recorded. Supplemental zero-based suffixes prove identical values,
clocks and row bounds; no raw output or model was rerun to repair indexing.
Whole-record projected amplitude spans at most0.00812692dB in jt51 and
0.04306565dB in OPM. The larger OPM value remains a separate descriptive
observation alongside the previously recorded pan-output discrepancy; no
new acceptance threshold or physical byte-identity claim is introduced.

## Completed isolated AM/PM routes

All 192 PCB positives (64 cases, three initializations each) and 128 whole-model
outputs have stable pretrigger gates, resolved periodic states, and independently
measured period intervals containing 2048 retained samples. Every physical
capture passes hashes, framing/exponents, bipolar audio, markers and continuous
CPU generations. All 256 model/route/endpoint checks pass the previously frozen
common screens; there are no excluded endpoint outliers.

| Feature | Physical minimum range | Physical maximum range | Largest model distance outside the unexpanded triplicate range |
|---|---|---|---:|
| AM attenuation, dB |0.135815–0.140620|11.805109–11.811260|0.002585 dB|
| PM pitch, cents |−24.91288 to −24.63843|22.65692–22.98771|0.222541 cents|

Independently measured point periods span 2047.785–2048.949 samples for AM and
2043.222–2051.672 for PM; all individual uncertainty intervals include 2048.
The asymmetric PM extrema are observed in both models and the PCB at this
specific quantized carrier/depth. They are not forced to ideal ±25 cents and
do not establish a new implementation gap. These results cover individual
voices and the selected inactive-gate controls; simultaneous modulated channels,
other algorithms, depths and rate settings do not inherit this qualification.

## Selected history protocol and limits

Twelve C0/C2 AM-only cases cover heldTEST02, release-null, repeated highKEYON,
repeatedTEST00, KEYOFF/rekey, matched KEYOFF/TESTreset/rekey, short reset pulse,
long reset hold, matched long null, repeated sameLFRQ=C0, repeated samewave2,
and KEYOFF-only. Repeated-write/free-running behavior is empirical where the
manual does not specify it. Explicit TEST resets are positive controls; their
output must not be forced to match a no-reset trajectory. Rekey may restart
the carrier/envelope; carrier phase alone cannot diagnose an LFO restart.

KEYOFF/rekey permits merged LEFT mute runs and intentional RIGHT silence,
requiring nonblank prefix and post-rekey audio. KEYOFF-only requires a bipolar
prefix and a quiet4096-sample tail. Held reset and final silence receive no
forced period. Ordinary cases require three LEFT mutes and continuous RIGHT.

Post selection follows each case's last intervention, including pan restore:
max(host completion upper bound, conservative manifest last-write bound)+80
support samples. At least two nominal post cycles must remain. The long hold
cannot use the old fixed5000..14000 late-fit interval. Host timestamps and LEFT
mute boundaries bound interventions; they do not identify precise bus latency.
Model API-write sidecars give model-local timing only.

Periodic comparison uses a same-device null-derived trajectory and one global
post-fitted phase, then independently checks earlier unaffected data. No
per-event fit, per-cycle warp or fitted gain is allowed. The phase search wraps
the0/period boundary;12 independent nearzero/halfcycle/wrap controls passed
with maximum phase error0.00013521cycles. This correction is separate from the
published storage report. A read-only storage sensitivity audit preserved all
published hashes/numbers and found a maximum0.03090cent change in marker RMS,
reducing the largest PM residual; its original coarse conclusion remains.

The physical-history method was frozen before its captures. Its independent
native-forward qualification has 162 cases: 36 continuous or carrier-reset-gap
controls pass the fixed 0.3 dB pre-holdout and 0.15 dB post screens; 90 large
LFO resets or ±1/8/±1/4-cycle jumps produce pre-holdout errors of 2.55–6.00 dB
despite a good post fit. Eighteen deliberately short presegments remain
unqualified, and eighteen two-sample jumps remain unresolved. These finite
controls do not establish sensitivity to every small phase change.

The first report failed JSON serialization of a NumPy boolean after processing.
Original PCM/curves, source and error hashes are retained; a supplemental report
uses native JSON scalars without rerunning the forward stimuli. An algebraically
cached phase objective agrees within 1.9e-13 in cost and 0.000018 samples in
three explicit original/cached phase checks. Held and final-quiet branch
controls separately pass without forcing a period. Long-hold duration is measured
after support exclusions; a shorter interior is reported as duration-limited.

## Completed physical history observations

All 36 recordings pass the independent raw audit and case-specific signal
checks. The null's independently measured period is 2048.699770 samples
(bounds 1984.369365–2113.030176); one common refined period, 2048.023799 samples,
remains inside those bounds and is reused throughout. All 30 running cases have
qualified pre-event holdouts; none needs the short-pre fallback.

| Cases and repetitions | Scoped observation |
|---|---|
| 21 ordinary records: null, repeated KEYON/TEST00/W2/LFRQ, KEYOFF/rekey, long null | Pre-holdout RMS 0.027969–0.116835 dB and post RMS 0.048855–0.049476 dB pass the fixed screens. |
| 9 intentional TEST-reset records | Pre-holdout mismatch 3.6292–5.17894 dB detects the changed origin while post RMS remains 0.048986–0.049476 dB. A good post fit cannot conceal these resets. |
| 3 whole-record held TEST controls | Stable held amplitude; no assigned period. |
| 3 KEYOFF-only controls | Bipolar prefix followed by exactly zero final 4096 raw PCM samples on both latches; no assigned period. |

Each long-hold interior spans 3.42428 would-be cycles after support exclusions,
with 0.004435–0.004515 dB amplitude span near 2064.49 PCM; the declared
quantization-based tolerance is approximately 0.134635 dB. The short-pulse
interior is only 0.06787–0.06836 cycles and retains that duration limit.

Repeated same LFRQ=C0 writes empirically shift both models by approximately two
retained samples. The physical record passes this finite continuity screen,
but the independent controls explicitly leave a two-sample change unresolved.
It therefore does not establish exact no-effect behavior or reject the model
prediction. No precise latency or physical sample-identity conclusion follows.
These selected observations assign no new jt51 history gap.

![Selected physical LFO history controls](http://gitea.jotego.es/attachments/353b09cb-44bf-418c-8723-872f20abd868)

The figure shows three independent PCB initializations at their original sample
indices. Shading marks observed LEFT zero runs in repetition0, including merged
silence, and does not identify precise bus-write times. Curves are nonblank
before intentional silence. PNG/PDF and exact input/plot hashes stay local.

## Reproduction and local evidence

From the task directory, with fresh output paths:

```
go run host/lfo_history_programs.go -base artifacts/fresh-tone.bin -output artifacts/fresh-history
go test host/modulation.go host/tone.go host/lfo_routes_test.go
go run host/modulation.go host/tone.go -mode am -increment 32992 -sample-rate 6992.1875 -native-stride 8 -window 64 -hop 4 -pre-end-sample 512 -start-sample POST_BOUND -expected-period 2048 -csv artifacts/fresh-isolated.csv artifacts/capture-0-1.csv
go run host/lfo_projection.go host/tone.go -csv artifacts/fresh-projection.csv artifacts/capture-0-1.csv
```

Use model column `right`; physical latch1 uses default `linear`. Output paths
are exclusive. Local evidence is under `artifacts/lfo-history`: frozen `programs/`,
`generator-validation.json`, `promoted-validation/`, `route-synthetic-qualification.log`,
`physical-baseline/`, `physical-modulation/`, `reference-pilot/`,
`reference-modulation/`, `model-modulation-score/`, `physical-history/`,
and model/provenance audits. Raw captures, plots and compiled binaries stay local.

All256 rates, wider waveform/depth/gate combinations, additional dynamic
histories, weak W3 sensitivity and full noise-sequence behavior remain open.
The slowest documented LFO cycle is about 1200 seconds, longer than the300-second
buffer. Partial advancement does not establish a full observed period.
